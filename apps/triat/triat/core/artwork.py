"""Récupération et cache des pochettes.

Les images viennent d'URL fournies par les API YouTube : chacune passe par
`safe_media_url()` avant d'être demandée (docs/security/ §6). Le
téléchargement est bloquant — à appeler depuis un thread.
"""

from __future__ import annotations

import hashlib
import logging
import os
import tempfile
import urllib.request
from pathlib import Path

from .net import MEDIA_HOST_SUFFIXES, USER_AGENT_FALLBACK, UnsafeURL, safe_media_url, urlopen_checked
from .paths import cache_dir

log = logging.getLogger(__name__)

MAX_BYTES = 4 * 1024 * 1024      # une pochette raisonnable
TIMEOUT = 12.0


def covers_dir() -> Path:
    path = cache_dir() / "covers"
    path.mkdir(parents=True, exist_ok=True)
    return path


def cache_path(url: str) -> Path:
    """Chemin de cache déterminé par l'URL, jamais par un nom fourni."""
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:32]
    return covers_dir() / f"{digest}.img"


def fetch(url: str) -> Path | None:
    """Télécharge une pochette si besoin et renvoie son chemin local.

    Renvoie None si l'URL est refusée ou le téléchargement échoue : une
    pochette manquante n'est jamais une erreur bloquante.
    """
    if not url:
        return None
    try:
        safe_media_url(url)
    except UnsafeURL as exc:
        log.info("Pochette refusée : %s", exc)
        return None

    path = cache_path(url)
    if path.exists() and path.stat().st_size > 0:
        return path

    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT_FALLBACK})
    try:
        with urlopen_checked(request, TIMEOUT, MEDIA_HOST_SUFFIXES) as response:
            data = response.read(MAX_BYTES + 1)
    except Exception as exc:
        log.debug("Pochette indisponible (%s) : %s", url[:60], exc)
        return None
    if not data or len(data) > MAX_BYTES or not looks_like_image(data):
        return None

    # Écriture atomique dans un fichier temporaire propre à cet appel : la
    # pochette et la matrice de points demandent souvent la même image en
    # même temps, un nom partagé mélangerait les deux écritures.
    try:
        fd, temporary = tempfile.mkstemp(dir=path.parent, suffix=".part")
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
        if not image_is_sane(temporary):
            os.unlink(temporary)
            return None
        os.replace(temporary, path)
    except OSError as exc:
        log.debug("Cache de pochette impossible : %s", exc)
        return None
    _maybe_prune()
    return path


# Signatures des formats servis par YouTube (JPEG, PNG, WebP).
_MAGIC = (b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n")


def looks_like_image(data: bytes) -> bool:
    return data.startswith(_MAGIC) or (data[:4] == b"RIFF"
                                       and data[8:12] == b"WEBP")


# Au-delà, une image de 4 Mo peut se décompresser en plusieurs Go de
# pixels (« bombe de décompression ») : on lit l'en-tête avant de décoder.
MAX_SIDE = 4096


def image_is_sane(path) -> bool:
    try:
        import gi
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
        info = GdkPixbuf.Pixbuf.get_file_info(str(path))
    except Exception as exc:
        log.debug("En-tête d'image illisible : %s", exc)
        return False
    if info is None or info[0] is None:
        return False
    _format, width, height = info
    return 0 < width <= MAX_SIDE and 0 < height <= MAX_SIDE


# Plafond du cache ; au-delà on retire les pochettes les moins récentes.
CACHE_LIMIT = 200 * 1024 * 1024
_PRUNE_EVERY = 50
_writes = 0


def _maybe_prune() -> None:
    global _writes
    _writes += 1
    if _writes % _PRUNE_EVERY:
        return
    prune(CACHE_LIMIT)


def prune(limit: int) -> int:
    """Ramène le cache sous `limit` octets. Renvoie le nombre de fichiers retirés."""
    try:
        files = [(f.stat().st_atime, f.stat().st_size, f)
                 for f in covers_dir().glob("*.img")]
    except OSError:
        return 0
    total = sum(size for _t, size, _f in files)
    removed = 0
    for _atime, size, f in sorted(files):
        if total <= limit:
            break
        f.unlink(missing_ok=True)
        total -= size
        removed += 1
    return removed


def cache_size() -> int:
    """Octets occupés par les pochettes en cache."""
    try:
        return sum(f.stat().st_size for f in covers_dir().glob("*.img"))
    except OSError:
        return 0


def clear_cache() -> None:
    for f in covers_dir().glob("*.img"):
        f.unlink(missing_ok=True)
