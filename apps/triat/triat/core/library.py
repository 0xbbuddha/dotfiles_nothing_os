"""Bibliothèque locale : SQLite + recherche plein texte FTS5.

Toutes les méthodes sont utilisables depuis n'importe quel thread : une
seule connexion protégée par un verrou, en mode WAL.
"""

from __future__ import annotations

import logging
import sqlite3
import threading
import time
from pathlib import Path
from collections.abc import Iterable, Sequence

from .models import Segment, TrackRef
from .paths import db_path

log = logging.getLogger(__name__)

SCHEMA_VERSION = 1

SCHEMA = """
CREATE TABLE IF NOT EXISTS tracks (
    video_id   TEXT PRIMARY KEY,
    title      TEXT NOT NULL DEFAULT '',
    artist     TEXT NOT NULL DEFAULT '',
    album      TEXT,
    duration   REAL NOT NULL DEFAULT 0,
    thumbnail  TEXT,
    added_at   REAL NOT NULL,
    play_count INTEGER NOT NULL DEFAULT 0,
    last_played REAL
);

CREATE TABLE IF NOT EXISTS favorites (
    video_id TEXT PRIMARY KEY REFERENCES tracks(video_id) ON DELETE CASCADE,
    added_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS playlists (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    remote_id  TEXT,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS playlist_items (
    playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    position    INTEGER NOT NULL,
    video_id    TEXT NOT NULL REFERENCES tracks(video_id) ON DELETE CASCADE,
    PRIMARY KEY (playlist_id, position)
);

CREATE TABLE IF NOT EXISTS history (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    video_id  TEXT NOT NULL,
    played_at REAL NOT NULL,
    seconds   REAL NOT NULL DEFAULT 0,
    completed INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_history_played_at ON history(played_at DESC);
CREATE INDEX IF NOT EXISTS idx_history_video ON history(video_id);

CREATE TABLE IF NOT EXISTS segments (
    video_id   TEXT NOT NULL,
    uuid       TEXT NOT NULL,
    category   TEXT NOT NULL,
    start_s    REAL NOT NULL,
    end_s      REAL NOT NULL,
    PRIMARY KEY (video_id, uuid)
);

-- Une ligne par vidéo interrogée, y compris celles sans aucun segment :
-- sinon on réinterroge l'API à chaque lecture d'une piste sans segment.
CREATE TABLE IF NOT EXISTS segment_fetches (
    video_id   TEXT PRIMARY KEY,
    fetched_at REAL NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS tracks_fts USING fts5(
    title, artist, album,
    content='tracks', content_rowid='rowid', tokenize='unicode61'
);

CREATE TRIGGER IF NOT EXISTS tracks_ai AFTER INSERT ON tracks BEGIN
    INSERT INTO tracks_fts(rowid, title, artist, album)
    VALUES (new.rowid, new.title, new.artist, coalesce(new.album, ''));
END;
CREATE TRIGGER IF NOT EXISTS tracks_ad AFTER DELETE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album)
    VALUES ('delete', old.rowid, old.title, old.artist, coalesce(old.album, ''));
END;
CREATE TRIGGER IF NOT EXISTS tracks_au AFTER UPDATE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album)
    VALUES ('delete', old.rowid, old.title, old.artist, coalesce(old.album, ''));
    INSERT INTO tracks_fts(rowid, title, artist, album)
    VALUES (new.rowid, new.title, new.artist, coalesce(new.album, ''));
END;
"""


# Piste « à soi » : rangée dans une playlist, en favori, ou déjà écoutée.
# Le reste de `tracks` n'est que le cache des recherches et des radios.
_OWNED = """(EXISTS (SELECT 1 FROM playlist_items o WHERE o.video_id = {t}.video_id)
    OR EXISTS (SELECT 1 FROM favorites o WHERE o.video_id = {t}.video_id)
    OR {t}.play_count > 0)"""


def _row_to_ref(row: sqlite3.Row) -> TrackRef:
    return TrackRef(
        video_id=row["video_id"],
        title=row["title"],
        artist=row["artist"],
        duration=row["duration"],
        thumbnail=row["thumbnail"],
        album=row["album"],
    )


class Library:
    def __init__(self, path=None) -> None:
        self._path = str(path or db_path())
        self._lock = threading.RLock()
        try:
            self._open()
        except sqlite3.DatabaseError as exc:
            # Fichier abîmé (coupure pendant une écriture, disque plein) :
            # on le met de côté, récupérable, plutôt que de ne plus démarrer.
            self._quarantine(exc)
            self._open()

    def _open(self) -> None:
        self._db = sqlite3.connect(self._path, check_same_thread=False)
        self._db.row_factory = sqlite3.Row
        try:
            self._db.execute("PRAGMA journal_mode=WAL")
            self._db.execute("PRAGMA foreign_keys=ON")
            self._db.execute("PRAGMA synchronous=NORMAL")
            self._migrate()
        except sqlite3.DatabaseError:
            self._db.close()
            raise

    def _quarantine(self, exc: Exception) -> None:
        if self._path == ":memory:":
            raise exc
        stamp = time.strftime("%Y%m%d-%H%M%S")
        for suffix in ("", "-wal", "-shm"):
            source = Path(self._path + suffix)
            if source.exists():
                source.rename(f"{self._path}.corrompue-{stamp}{suffix}")
        log.error("Bibliothèque illisible (%s) : mise de côté en "
                  "%s.corrompue-%s, nouvelle base créée", exc, self._path, stamp)

    def close(self) -> None:
        with self._lock:
            self._db.close()

    # ---- Schéma --------------------------------------------------------

    def _migrate(self) -> None:
        with self._lock:
            self._db.executescript(SCHEMA)
            self._db.execute(
                "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)"
            )
            row = self._db.execute("SELECT version FROM schema_version").fetchone()
            if row is None:
                self._db.execute("INSERT INTO schema_version VALUES (?)", (SCHEMA_VERSION,))
            elif row["version"] > SCHEMA_VERSION:
                log.warning(
                    "Base écrite par une version plus récente (%s > %s)",
                    row["version"], SCHEMA_VERSION,
                )
            self._db.commit()

    # ---- Pistes --------------------------------------------------------

    def upsert_track(self, ref: TrackRef) -> None:
        """Enregistre ou rafraîchit une piste sans toucher aux compteurs."""
        if not ref.video_id:
            return
        with self._lock:
            self._db.execute(
                """
                INSERT INTO tracks (video_id, title, artist, album, duration,
                                    thumbnail, added_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(video_id) DO UPDATE SET
                    title     = excluded.title,
                    artist    = excluded.artist,
                    album     = coalesce(excluded.album, tracks.album),
                    duration  = CASE WHEN excluded.duration > 0
                                     THEN excluded.duration ELSE tracks.duration END,
                    thumbnail = coalesce(excluded.thumbnail, tracks.thumbnail)
                """,
                (ref.video_id, ref.title, ref.artist, ref.album,
                 ref.duration, ref.thumbnail, time.time()),
            )
            self._db.commit()

    def upsert_many(self, refs: Iterable[TrackRef]) -> None:
        for ref in refs:
            self.upsert_track(ref)

    def get_track(self, video_id: str) -> TrackRef | None:
        with self._lock:
            row = self._db.execute(
                "SELECT * FROM tracks WHERE video_id = ?", (video_id,)
            ).fetchone()
        return _row_to_ref(row) if row else None

    def search(self, query: str, limit: int = 50) -> list[TrackRef]:
        """Recherche plein texte locale. Chaque mot devient un préfixe."""
        terms = [t for t in query.replace('"', " ").split() if t]
        if not terms:
            return []
        match = " ".join(f'"{t}"*' for t in terms)
        with self._lock:
            try:
                rows = self._db.execute(
                    """
                    SELECT t.* FROM tracks_fts f
                    JOIN tracks t ON t.rowid = f.rowid
                    WHERE tracks_fts MATCH ?
                    ORDER BY rank LIMIT ?
                    """,
                    (match, limit),
                ).fetchall()
            except sqlite3.OperationalError as exc:
                # Une saisie exotique peut produire une requête FTS invalide :
                # aucun résultat vaut mieux qu'une fenêtre qui tombe.
                log.info("Requête de recherche rejetée par FTS5: %s", exc)
                return []
        return [_row_to_ref(r) for r in rows]

    def tracks_by_artist(self, artist: str, limit: int = 200) -> list[TrackRef]:
        """Pistes d'un artiste déjà connues localement.

        Comparaison insensible à la casse et aux espaces : les métadonnées
        YouTube ne sont pas normalisées.
        """
        needle = (artist or "").strip().lower()
        if not needle:
            return []
        with self._lock:
            rows = self._db.execute(
                """
                SELECT * FROM tracks
                WHERE lower(trim(artist)) = ?
                ORDER BY play_count DESC, title
                LIMIT ?
                """,
                (needle, limit),
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def all_tracks(self, limit: int = 2000) -> list[TrackRef]:
        with self._lock:
            rows = self._db.execute(
                "SELECT * FROM tracks ORDER BY added_at LIMIT ?", (limit,)
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def added_since(self, since: float, limit: int = 500,
                    owned: bool = False) -> list[TrackRef]:
        """Pistes entrées dans la bibliothèque après `since`, récentes d'abord."""
        mine = " AND " + _OWNED.format(t="tracks") if owned else ""
        with self._lock:
            rows = self._db.execute(
                "SELECT * FROM tracks WHERE added_at >= ?" + mine +
                " ORDER BY added_at DESC LIMIT ?", (since, limit)
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def missing_duration(self, limit: int = 500) -> list[str]:
        """Identifiants des pistes sans durée connue."""
        with self._lock:
            rows = self._db.execute(
                "SELECT video_id FROM tracks WHERE duration <= 0"
                " ORDER BY added_at DESC LIMIT ?", (limit,)
            ).fetchall()
        return [r["video_id"] for r in rows]

    def set_duration(self, video_id: str, seconds: float) -> None:
        with self._lock:
            self._db.execute(
                "UPDATE tracks SET duration = ? WHERE video_id = ? AND duration <= 0",
                (float(seconds), video_id))
            self._db.commit()

    def unplayed(self, limit: int = 500, owned: bool = False) -> list[TrackRef]:
        mine = " AND " + _OWNED.format(t="tracks") if owned else ""
        with self._lock:
            rows = self._db.execute(
                "SELECT * FROM tracks WHERE play_count = 0" + mine +
                " ORDER BY added_at DESC LIMIT ?", (limit,)
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def playlist_neighbours(self, video_ids: Sequence[str], radius: int = 3,
                            limit: int = 100) -> list[TrackRef]:
        """Pistes rangées à moins de `radius` places de celles données, dans
        n'importe quelle playlist. L'ordre choisi par l'utilisateur est un
        bon indice de parenté : on l'exploite pour les mixes."""
        ids = list(dict.fromkeys(video_ids))
        if not ids:
            return []
        marks = ",".join("?" * len(ids))
        with self._lock:
            rows = self._db.execute(
                f"""
                SELECT t.*, MIN(ABS(n.position - p.position)) AS gap
                FROM playlist_items p
                JOIN playlist_items n ON n.playlist_id = p.playlist_id
                     AND ABS(n.position - p.position) BETWEEN 1 AND ?
                JOIN tracks t ON t.video_id = n.video_id
                WHERE p.video_id IN ({marks}) AND n.video_id NOT IN ({marks})
                GROUP BY t.video_id ORDER BY gap, t.title LIMIT ?
                """,
                (radius, *ids, *ids, limit),
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def artists(self, limit: int = 200, owned: bool = False) -> list[tuple[str, int]]:
        """Artistes de la bibliothèque, avec leur nombre de pistes."""
        mine = " AND " + _OWNED.format(t="tracks") if owned else ""
        with self._lock:
            rows = self._db.execute(
                """
                SELECT artist, COUNT(*) AS n FROM tracks
                WHERE trim(artist) != ''""" + mine + """
                GROUP BY lower(trim(artist))
                ORDER BY n DESC, artist
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [(r["artist"], r["n"]) for r in rows]

    # ---- Favoris -------------------------------------------------------

    def is_favorite(self, video_id: str) -> bool:
        with self._lock:
            return self._db.execute(
                "SELECT 1 FROM favorites WHERE video_id = ?", (video_id,)
            ).fetchone() is not None

    def set_favorite(self, ref: TrackRef, favorite: bool) -> None:
        self.upsert_track(ref)
        with self._lock:
            if favorite:
                self._db.execute(
                    "INSERT OR IGNORE INTO favorites VALUES (?, ?)",
                    (ref.video_id, time.time()),
                )
            else:
                self._db.execute(
                    "DELETE FROM favorites WHERE video_id = ?", (ref.video_id,)
                )
            self._db.commit()

    def toggle_favorite(self, ref: TrackRef) -> bool:
        new_state = not self.is_favorite(ref.video_id)
        self.set_favorite(ref, new_state)
        return new_state

    def list_favorites(self, limit: int = 500) -> list[TrackRef]:
        with self._lock:
            rows = self._db.execute(
                """
                SELECT t.* FROM favorites f
                JOIN tracks t ON t.video_id = f.video_id
                ORDER BY f.added_at DESC LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    # ---- Playlists -----------------------------------------------------

    def create_playlist(self, name: str, remote_id: str | None = None) -> int:
        now = time.time()
        with self._lock:
            cur = self._db.execute(
                "INSERT INTO playlists (name, remote_id, created_at, updated_at)"
                " VALUES (?, ?, ?, ?)",
                (name, remote_id, now, now),
            )
            self._db.commit()
            return int(cur.lastrowid)

    def rename_playlist(self, playlist_id: int, name: str) -> None:
        with self._lock:
            self._db.execute(
                "UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?",
                (name, time.time(), playlist_id),
            )
            self._db.commit()

    def delete_playlist(self, playlist_id: int) -> None:
        with self._lock:
            self._db.execute("DELETE FROM playlists WHERE id = ?", (playlist_id,))
            self._db.commit()

    def list_playlists(self) -> list[dict]:
        with self._lock:
            rows = self._db.execute(
                """
                SELECT p.*, (SELECT COUNT(*) FROM playlist_items i
                             WHERE i.playlist_id = p.id) AS item_count,
                       (SELECT COALESCE(SUM(t.duration), 0)
                        FROM playlist_items i JOIN tracks t
                             ON t.video_id = i.video_id
                        WHERE i.playlist_id = p.id) AS total_duration,
                       (SELECT COUNT(*) FROM playlist_items i JOIN tracks t
                             ON t.video_id = i.video_id
                        WHERE i.playlist_id = p.id AND t.duration > 0)
                        AS known_durations
                FROM playlists p ORDER BY p.updated_at DESC
                """
            ).fetchall()
        return [dict(r) for r in rows]

    def add_to_playlist(self, playlist_id: int, refs: Sequence[TrackRef]) -> int:
        """Ajoute à la fin. Renvoie le nombre de pistes réellement ajoutées."""
        if not refs:
            return 0
        self.upsert_many(refs)
        with self._lock:
            row = self._db.execute(
                "SELECT coalesce(MAX(position), -1) AS m FROM playlist_items"
                " WHERE playlist_id = ?",
                (playlist_id,),
            ).fetchone()
            position = int(row["m"]) + 1
            added = 0
            for ref in refs:
                self._db.execute(
                    "INSERT INTO playlist_items (playlist_id, position, video_id)"
                    " VALUES (?, ?, ?)",
                    (playlist_id, position, ref.video_id),
                )
                position += 1
                added += 1
            self._db.execute(
                "UPDATE playlists SET updated_at = ? WHERE id = ?",
                (time.time(), playlist_id),
            )
            self._db.commit()
        return added

    def playlist_items(self, playlist_id: int) -> list[TrackRef]:
        with self._lock:
            rows = self._db.execute(
                """
                SELECT t.* FROM playlist_items i
                JOIN tracks t ON t.video_id = i.video_id
                WHERE i.playlist_id = ? ORDER BY i.position
                """,
                (playlist_id,),
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def set_playlist_order(self, playlist_id: int, video_ids: Sequence[str]) -> None:
        """Réécrit l'ordre complet d'une playlist (drag & drop)."""
        with self._lock:
            self._db.execute(
                "DELETE FROM playlist_items WHERE playlist_id = ?", (playlist_id,)
            )
            self._db.executemany(
                "INSERT INTO playlist_items (playlist_id, position, video_id)"
                " VALUES (?, ?, ?)",
                [(playlist_id, i, vid) for i, vid in enumerate(video_ids)],
            )
            self._db.execute(
                "UPDATE playlists SET updated_at = ? WHERE id = ?",
                (time.time(), playlist_id),
            )
            self._db.commit()

    # ---- Historique ----------------------------------------------------

    def record_play(self, ref: TrackRef, seconds: float, completed: bool) -> None:
        self.upsert_track(ref)
        now = time.time()
        with self._lock:
            self._db.execute(
                "INSERT INTO history (video_id, played_at, seconds, completed)"
                " VALUES (?, ?, ?, ?)",
                (ref.video_id, now, seconds, int(completed)),
            )
            self._db.execute(
                "UPDATE tracks SET play_count = play_count + 1, last_played = ?"
                " WHERE video_id = ?",
                (now, ref.video_id),
            )
            self._db.commit()

    def recent(self, limit: int = 50) -> list[TrackRef]:
        """Pistes récemment jouées, dédoublonnées."""
        with self._lock:
            rows = self._db.execute(
                """
                SELECT t.*, MAX(h.played_at) AS last
                FROM history h JOIN tracks t ON t.video_id = h.video_id
                GROUP BY h.video_id ORDER BY last DESC LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def top_tracks(self, limit: int = 50, since: float | None = None) -> list[TrackRef]:
        with self._lock:
            if since is None:
                rows = self._db.execute(
                    "SELECT * FROM tracks WHERE play_count > 0"
                    " ORDER BY play_count DESC, last_played DESC LIMIT ?",
                    (limit,),
                ).fetchall()
            else:
                rows = self._db.execute(
                    """
                    SELECT t.*, COUNT(*) AS plays
                    FROM history h JOIN tracks t ON t.video_id = h.video_id
                    WHERE h.played_at >= ?
                    GROUP BY h.video_id ORDER BY plays DESC LIMIT ?
                    """,
                    (since, limit),
                ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def co_played(self, video_id: str, window: float = 1800.0,
                  limit: int = 25) -> list[TrackRef]:
        """Pistes souvent écoutées autour de celle-ci.

        Base de la recommandation locale : pas de modèle, juste de la
        co-occurrence dans une fenêtre temporelle. Marche hors ligne et
        sans compte Google.
        """
        with self._lock:
            rows = self._db.execute(
                """
                SELECT t.*, COUNT(*) AS score
                FROM history a
                JOIN history b
                  ON b.video_id != a.video_id
                 AND abs(b.played_at - a.played_at) <= ?
                JOIN tracks t ON t.video_id = b.video_id
                WHERE a.video_id = ?
                GROUP BY b.video_id
                ORDER BY score DESC, t.play_count DESC
                LIMIT ?
                """,
                (window, video_id, limit),
            ).fetchall()
        return [_row_to_ref(r) for r in rows]

    def clear_history(self) -> None:
        with self._lock:
            self._db.execute("DELETE FROM history")
            self._db.execute("UPDATE tracks SET play_count = 0, last_played = NULL")
            self._db.commit()

    # ---- Cache SponsorBlock -------------------------------------------

    def cache_segments(self, video_id: str, segments: Sequence[Segment]) -> None:
        with self._lock:
            self._db.execute("DELETE FROM segments WHERE video_id = ?", (video_id,))
            self._db.executemany(
                "INSERT OR REPLACE INTO segments"
                " (video_id, uuid, category, start_s, end_s) VALUES (?, ?, ?, ?, ?)",
                [(video_id, s.uuid or f"{s.category}:{s.start}", s.category,
                  s.start, s.end) for s in segments],
            )
            self._db.execute(
                "INSERT OR REPLACE INTO segment_fetches VALUES (?, ?)",
                (video_id, time.time()),
            )
            self._db.commit()

    def cached_segments(self, video_id: str, max_age: float = 7 * 86400
                        ) -> list[Segment] | None:
        """None = jamais interrogé ou cache périmé. Liste vide = pas de segment."""
        with self._lock:
            row = self._db.execute(
                "SELECT fetched_at FROM segment_fetches WHERE video_id = ?",
                (video_id,),
            ).fetchone()
            if row is None or (time.time() - row["fetched_at"]) > max_age:
                return None
            rows = self._db.execute(
                "SELECT * FROM segments WHERE video_id = ? ORDER BY start_s",
                (video_id,),
            ).fetchall()
        return [Segment(start=r["start_s"], end=r["end_s"],
                        category=r["category"], uuid=r["uuid"]) for r in rows]

    # ---- Maintenance ---------------------------------------------------

    def wipe(self) -> None:
        """Efface toutes les données utilisateur (bouton « effacer mes données »)."""
        with self._lock:
            for table in ("history", "playlist_items", "playlists", "favorites",
                          "segments", "segment_fetches", "tracks"):
                self._db.execute(f"DELETE FROM {table}")
            self._db.execute("INSERT INTO tracks_fts(tracks_fts) VALUES ('rebuild')")
            self._db.commit()
            self._db.execute("VACUUM")

    def stats(self) -> dict:
        with self._lock:
            row = self._db.execute(
                """
                SELECT (SELECT COUNT(*) FROM tracks)     AS tracks,
                       (SELECT COUNT(*) FROM favorites)  AS favorites,
                       (SELECT COUNT(*) FROM playlists)  AS playlists,
                       (SELECT COUNT(*) FROM history)    AS plays,
                       (SELECT coalesce(SUM(seconds), 0) FROM history) AS seconds
                """
            ).fetchone()
        return dict(row)
