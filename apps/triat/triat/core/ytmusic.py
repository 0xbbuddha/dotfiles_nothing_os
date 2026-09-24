"""Accès à YouTube Music (InnerTube) via ytmusicapi.

Sans cookies, l'API publique est très dégradée : la recherche ne renvoie
guère que des playlists sans `videoId`, la radio ne renvoie que la piste
de départ et les classements cassent au parsing. Toutes les méthodes
renvoient donc des listes vides plutôt que de lever, et le moteur de
recommandation sait retomber sur autre chose.
"""

from __future__ import annotations

import logging
import threading

from .models import TrackRef

log = logging.getLogger(__name__)

# Types d'items de recherche qui correspondent à des pistes jouables.
PLAYABLE_TYPES = ("song", "video")


def parse_length(value) -> float:
    """Accepte 213, "3:33" ou "1:02:05" et renvoie des secondes."""
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    parts = str(value).strip().split(":")
    try:
        numbers = [int(p) for p in parts]
    except ValueError:
        return 0.0
    seconds = 0.0
    for number in numbers:
        seconds = seconds * 60 + number
    return seconds


def _best_thumbnail(item: dict) -> str | None:
    thumbs = item.get("thumbnails") or item.get("thumbnail") or []
    if isinstance(thumbs, dict):
        thumbs = thumbs.get("thumbnails") or []
    if not isinstance(thumbs, list) or not thumbs:
        return None
    best = max(thumbs, key=lambda t: (t.get("width") or 0) * (t.get("height") or 0)
               if isinstance(t, dict) else 0)
    return best.get("url") if isinstance(best, dict) else None


def _join_artists(item: dict) -> str:
    artists = item.get("artists")
    if isinstance(artists, list):
        names = [a.get("name") for a in artists
                 if isinstance(a, dict) and a.get("name")]
        if names:
            return ", ".join(names)
    for key in ("author", "artist", "uploader"):
        value = item.get(key)
        if isinstance(value, str) and value:
            return value
        if isinstance(value, dict) and value.get("name"):
            return value["name"]
    return ""


def _album_name(item: dict) -> str | None:
    album = item.get("album")
    if isinstance(album, dict):
        return album.get("name")
    if isinstance(album, str):
        return album
    return None


def ref_from_item(item) -> TrackRef | None:
    """Convertit un item ytmusicapi en TrackRef, ou None s'il n'est pas jouable."""
    if not isinstance(item, dict):
        return None
    video_id = item.get("videoId")
    if not video_id:
        return None
    return TrackRef(
        video_id=video_id,
        title=item.get("title") or "Sans titre",
        artist=_join_artists(item),
        duration=parse_length(item.get("duration_seconds") or item.get("length")),
        thumbnail=_best_thumbnail(item),
        album=_album_name(item),
    )


def refs_from_items(items) -> list[TrackRef]:
    if not isinstance(items, (list, tuple)):
        return []
    refs = []
    for item in items:
        ref = ref_from_item(item)
        if ref is not None:
            refs.append(ref)
    return refs


class YTMusicService:
    """Façade sur ytmusicapi. Ne lève jamais : renvoie vide en cas d'échec.

    L'instance ytmusicapi est créée paresseusement et reconstruite quand
    les cookies changent.
    """

    def __init__(self, cookies=None, language: str = "fr") -> None:
        self._cookies = cookies
        self._language = language
        self._client = None
        self._authenticated = False
        self._lock = threading.Lock()
        self._failed = False

    # ---- Cycle de vie --------------------------------------------------

    def invalidate(self) -> None:
        """À appeler quand les cookies changent."""
        with self._lock:
            self._client = None
            self._authenticated = False
            self._failed = False

    @property
    def authenticated(self) -> bool:
        self._ensure_client()
        return self._authenticated

    @property
    def available(self) -> bool:
        self._ensure_client()
        return self._client is not None

    def _ensure_client(self):
        with self._lock:
            if self._client is not None or self._failed:
                return self._client
            try:
                from ytmusicapi import YTMusic
            except ImportError:
                log.warning("ytmusicapi absent")
                self._failed = True
                return None

            header = None
            authorization = None
            if self._cookies is not None:
                try:
                    header = self._cookies.cookie_header()
                    authorization = self._cookies.authorization_header()
                except Exception as exc:
                    log.warning("Cookies illisibles pour YouTube Music: %s", exc)

            try:
                # ytmusicapi ne reconnaît le mode « navigateur » que si un
                # en-tête Authorization porte un SAPISIDHASH. Sans cookie de
                # session, il prendrait nos en-têtes pour un jeton OAuth et
                # refuserait de démarrer : on reste alors anonyme.
                if header and authorization:
                    import json

                    from .innertube import USER_AGENT

                    self._client = YTMusic(json.dumps({
                        "Cookie": header,
                        "Authorization": authorization,
                        "User-Agent": USER_AGENT,
                        "Accept-Language": f"{self._language},en;q=0.9",
                        "X-Goog-AuthUser": "0",
                        "Origin": "https://music.youtube.com",
                    }), language=self._language)
                    self._authenticated = True
                else:
                    if header and not authorization:
                        log.info("Cookies sans session Google : "
                                 "YouTube Music reste en mode anonyme")
                    self._client = YTMusic(language=self._language)
                    self._authenticated = False
            except Exception as exc:
                log.warning("Initialisation YouTube Music impossible: %s", exc)
                self._failed = True
                self._client = None
            return self._client

    def _call(self, method: str, *args, **kwargs):
        """Appelle une méthode ytmusicapi en absorbant toute erreur."""
        client = self._ensure_client()
        if client is None:
            return None
        try:
            return getattr(client, method)(*args, **kwargs)
        except Exception as exc:
            log.info("YouTube Music: %s a échoué (%s)", method, exc)
            return None

    # ---- Recherche -----------------------------------------------------

    def search_tracks(self, query: str, limit: int = 25) -> list[TrackRef]:
        result = self._call("search", query, filter="songs", limit=limit)
        refs = refs_from_items(result)
        if refs:
            return refs
        # Le filtre "songs" rend souvent vide en anonyme : on retente large
        # et on ne garde que ce qui est jouable.
        result = self._call("search", query, limit=limit)
        if not isinstance(result, list):
            return []
        playable = [i for i in result
                    if isinstance(i, dict)
                    and i.get("resultType") in PLAYABLE_TYPES]
        return refs_from_items(playable)

    def search_raw(self, query: str, filter_: str | None = None,
                   limit: int = 25) -> list[dict]:
        """Résultats bruts (albums, artistes, playlists) pour les vues de navigation."""
        result = self._call("search", query, filter=filter_, limit=limit)
        return result if isinstance(result, list) else []

    def suggestions(self, query: str) -> list[str]:
        result = self._call("get_search_suggestions", query)
        return [s for s in (result or []) if isinstance(s, str)]

    # ---- Recommandations -----------------------------------------------

    def radio(self, video_id: str, limit: int = 25) -> list[TrackRef]:
        """File de lecture infinie autour d'une piste."""
        result = self._call("get_watch_playlist", videoId=video_id,
                            radio=True, limit=limit)
        if not isinstance(result, dict):
            return []
        refs = refs_from_items(result.get("tracks"))
        # La première piste est celle de départ : on ne la reproposera pas.
        return [r for r in refs if r.video_id != video_id]

    def home(self, limit: int = 6) -> list[dict]:
        """Sections de la page d'accueil : [{'title': ..., 'tracks': [...]}]."""
        result = self._call("get_home", limit=limit)
        sections = []
        for section in result or []:
            if not isinstance(section, dict):
                continue
            tracks = refs_from_items(section.get("contents"))
            if tracks:
                sections.append({"title": section.get("title") or "", "tracks": tracks})
        return sections

    # ---- Navigation ----------------------------------------------------

    def album(self, browse_id: str) -> list[TrackRef]:
        result = self._call("get_album", browse_id)
        if not isinstance(result, dict):
            return []
        return refs_from_items(result.get("tracks"))

    def playlist(self, playlist_id: str, limit: int = 200) -> list[TrackRef]:
        result = self._call("get_playlist", playlist_id, limit=limit)
        if not isinstance(result, dict):
            return []
        return refs_from_items(result.get("tracks"))

    def artist_top_songs(self, channel_id: str) -> list[TrackRef]:
        result = self._call("get_artist", channel_id)
        if not isinstance(result, dict):
            return []
        songs = result.get("songs")
        if isinstance(songs, dict):
            return refs_from_items(songs.get("results"))
        return []

    # ---- Compte (nécessite des cookies) --------------------------------

    def liked_songs(self, limit: int = 200) -> list[TrackRef]:
        if not self.authenticated:
            return []
        result = self._call("get_liked_songs", limit=limit)
        if not isinstance(result, dict):
            return []
        return refs_from_items(result.get("tracks"))

    def library_playlists(self, limit: int = 100) -> list[dict]:
        if not self.authenticated:
            return []
        result = self._call("get_library_playlists", limit=limit)
        return result if isinstance(result, list) else []

    def history(self) -> list[TrackRef]:
        if not self.authenticated:
            return []
        return refs_from_items(self._call("get_history"))
