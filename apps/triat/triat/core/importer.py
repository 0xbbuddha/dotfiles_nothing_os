"""Import de playlists depuis un fichier.

Formats acceptés : liste d'URL YouTube (une par ligne), M3U/M3U8, ou
identifiants bruts. Les commentaires et lignes vides sont ignorés.

Les métadonnées sont récupérées par **oEmbed** plutôt que par yt-dlp :
l'endpoint est public, sans clé ni quota, et répond en ~0,2 s — contre
plusieurs secondes pour une extraction complète. Sur 200 pistes, c'est la
différence entre cinq secondes et sept minutes. L'URL de flux, elle, reste
résolue au dernier moment par le moteur.
"""

from __future__ import annotations

import csv
import io
import json
import logging
import os
import re
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .models import TrackRef
from .net import check_url, urlopen_checked

log = logging.getLogger(__name__)

OEMBED_URL = "https://www.youtube.com/oembed"
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) Triat/0.1"
MAX_WORKERS = 8
TIMEOUT = 10.0

# Un identifiant de vidéo YouTube : 11 caractères de l'alphabet base64url.
_ID = r"[A-Za-z0-9_-]{11}"
_ID_PATTERNS = (
    re.compile(rf"[?&]v=({_ID})"),
    re.compile(rf"youtu\.be/({_ID})"),
    re.compile(rf"/shorts/({_ID})"),
    re.compile(rf"/embed/({_ID})"),
    re.compile(rf"/live/({_ID})"),
)
_BARE_ID = re.compile(rf"^({_ID})$")

# Mentions que les chaînes collent aux titres et qui n'apportent rien.
_NOISE = re.compile(
    r"""\s*[\(\[]\s*(?:
        official\s*(?:music\s*)?(?:video|audio|visualizer|lyric\s*video)?
      | clip\s*officiel | video\s*officielle? | audio\s*officiel
      | lyrics? (?:\s*video)? | paroles
      | hd | hq | 4k | full\s*hd | remaster(?:ed)?(?:\s*\d{4})?
      | visuali[sz]er | mv | m/v
    )\s*[\)\]]""",
    re.IGNORECASE | re.VERBOSE,
)
_TRAILING = re.compile(r"\s*[-–—]\s*(?:official\s*video|clip\s*officiel)\s*$",
                       re.IGNORECASE)


class ImportError_(ValueError):
    """Erreur d'import lisible par l'utilisateur."""


def extract_video_id(line: str) -> str | None:
    """Tire un identifiant de vidéo d'une ligne, ou None."""
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    for pattern in _ID_PATTERNS:
        found = pattern.search(line)
        if found:
            return found.group(1)
    bare = _BARE_ID.match(line)
    return bare.group(1) if bare else None


def clean_title(raw: str) -> str:
    """Retire les mentions parasites d'un titre YouTube."""
    cleaned = _NOISE.sub("", raw or "")
    cleaned = _TRAILING.sub("", cleaned)
    cleaned = re.sub(r"\s{2,}", " ", cleaned)
    return cleaned.strip(" -–—|") or (raw or "").strip()


def split_artist_title(title: str, channel: str) -> tuple[str, str]:
    """Sépare « Artiste - Titre », en repli sur le nom de la chaîne.

    Les chaînes « Topic » de YouTube portent le nom de l'artiste suivi de
    « - Topic » : on le nettoie aussi.
    """
    channel = re.sub(r"\s*-\s*Topic\s*$", "", channel or "").strip()
    cleaned = clean_title(title)

    for separator in (" - ", " – ", " — ", " | "):
        if separator in cleaned:
            left, right = cleaned.split(separator, 1)
            left, right = left.strip(), right.strip()
            if not (left and right):
                continue
            # « Titre - Artiste » existe aussi : si le côté droit est le nom
            # de la chaîne, c'est lui l'artiste, pas le côté gauche.
            normalise = lambda value: re.sub(r"\W+", "", value).lower()
            if channel and normalise(right) == normalise(channel):
                return right, left
            return left, right
    return (channel, cleaned) if channel else ("", cleaned)


def parse_playlist_file(path: str | Path) -> list[str]:
    """Lit un fichier et renvoie les identifiants, sans doublon, dans l'ordre."""
    file_path = Path(path).expanduser()
    try:
        text = file_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        raise ImportError_(f"Lecture impossible : {exc.strerror}") from exc

    seen: set[str] = set()
    ids: list[str] = []
    for line in text.splitlines():
        video_id = extract_video_id(line)
        if video_id and video_id not in seen:
            seen.add(video_id)
            ids.append(video_id)
    if not ids:
        raise ImportError_(
            "Aucune vidéo trouvée. Attendu : une URL YouTube par ligne, "
            "un fichier M3U, ou des identifiants de vidéo.")
    return ids


def fetch_metadata(video_id: str, timeout: float = TIMEOUT) -> TrackRef:
    """Interroge oEmbed pour une vidéo. Ne lève jamais.

    En cas d'échec, renvoie un TrackRef minimal : une piste sans titre
    reste jouable, et le moteur complétera à la lecture.
    """
    watch = f"https://www.youtube.com/watch?v={video_id}"
    query = urllib.parse.urlencode({"format": "json", "url": watch})
    try:
        check_url(f"{OEMBED_URL}?{query}")
        request = urllib.request.Request(
            f"{OEMBED_URL}?{query}", headers={"User-Agent": USER_AGENT})
        with urlopen_checked(request, timeout, ("youtube.com",)) as response:
            payload = json.loads(response.read(64 * 1024).decode("utf-8", "replace"))
    except Exception as exc:
        log.debug("oEmbed indisponible pour %s : %s", video_id, exc)
        return TrackRef(video_id=video_id, title=video_id)

    artist, title = split_artist_title(
        payload.get("title") or "", payload.get("author_name") or "")
    return TrackRef(
        video_id=video_id,
        title=title or video_id,
        artist=artist,
        thumbnail=payload.get("thumbnail_url"),
    )


def resolve_all(video_ids, progress=None, workers: int = MAX_WORKERS
                ) -> list[TrackRef]:
    """Récupère les métadonnées en parallèle, en conservant l'ordre.

    `progress(faits, total)` est appelé depuis les threads de travail :
    l'appelant doit repasser par la boucle principale avant de toucher
    à l'interface.
    """
    video_ids = list(video_ids)
    total = len(video_ids)
    done = 0
    refs: list[TrackRef] = []
    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        for ref in pool.map(fetch_metadata, video_ids):
            refs.append(ref)
            done += 1
            if progress is not None:
                progress(done, total)
    return refs


def default_playlist_name(path: str | Path) -> str:
    """Nom lisible tiré du nom de fichier."""
    stem = Path(path).stem.replace("_", " ").replace("-", " ")
    stem = re.sub(r"\b\d+\s*tracks?\b", "", stem, flags=re.IGNORECASE)
    stem = re.sub(r"\s{2,}", " ", stem).strip()
    return stem.title() or "Playlist importée"


def import_playlist(path: str | Path, library, name: str | None = None,
                    progress=None) -> tuple[int, str, list[TrackRef]]:
    """Importe un fichier en playlist locale.

    Renvoie (identifiant de playlist, nom, pistes). Bloquant.
    """
    ids = parse_playlist_file(path)
    refs = resolve_all(ids, progress=progress)
    playlist_name = (name or "").strip() or default_playlist_name(path)
    playlist_id = library.create_playlist(playlist_name)
    library.add_to_playlist(playlist_id, refs)
    log.info("Playlist « %s » importée : %d pistes", playlist_name, len(refs))
    return playlist_id, playlist_name, refs


# ---- Export ---------------------------------------------------------------

EXPORT_FORMATS = ("m3u8", "txt", "json", "csv")


def export_playlist(refs, path, fmt: str | None = None) -> Path:
    """Écrit une playlist sur disque.

    Le format est déduit de l'extension quand il n'est pas donné. L'écriture
    est atomique : un fichier existant n'est remplacé qu'une fois le nouveau
    complet.
    """
    target = Path(path).expanduser()
    fmt = (fmt or target.suffix.lstrip(".") or "m3u8").lower()
    if fmt not in EXPORT_FORMATS:
        raise ImportError_(
            f"Format inconnu : {fmt}. Attendu : {', '.join(EXPORT_FORMATS)}")

    refs = list(refs)
    if fmt == "m3u8":
        lines = ["#EXTM3U"]
        for ref in refs:
            duration = int(ref.duration) if ref.duration else -1
            artist = ref.artist or ""
            lines.append(f"#EXTINF:{duration},"
                         + (f"{artist} - {ref.title}" if artist else ref.title))
            lines.append(ref.url)
        body = "\n".join(lines) + "\n"
    elif fmt == "txt":
        body = "\n".join(ref.url for ref in refs) + "\n"
    elif fmt == "json":
        body = json.dumps([ref.as_dict() for ref in refs],
                          indent=2, ensure_ascii=False) + "\n"
    else:   # csv
        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(["title", "artist", "album", "duration", "url"])
        for ref in refs:
            writer.writerow([ref.title, ref.artist, ref.album or "",
                             int(ref.duration or 0), ref.url])
        body = buffer.getvalue()

    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".part")
    temporary.write_text(body, encoding="utf-8")
    os.replace(temporary, target)
    log.info("Playlist exportée : %s (%d pistes)", target.name, len(refs))
    return target
