"""Résolution d'une URL YouTube vers un flux audio direct.

Bloquant par construction : toujours appeler depuis un thread worker,
jamais depuis le thread UI.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import yt_dlp

from .models import Track, TrackRef
from .net import UnsafeURL, check_url, safe_media_url

log = logging.getLogger(__name__)

# Opus d'abord (meilleur rapport qualité/débit), m4a en repli.
FORMAT_SELECTOR = "bestaudio[acodec=opus]/bestaudio[ext=m4a]/bestaudio/best"

# YouTube coupe régulièrement l'accès à certains clients InnerTube. Plutôt
# qu'un seul chemin qui casse, on essaie plusieurs profils dans l'ordre :
# le client par défaut de yt-dlp, puis deux replis connus pour tenir.
# `None` laisse yt-dlp choisir.
CLIENT_FALLBACKS: tuple[str | None, ...] = (None, "web_safari", "mweb", "tv")

# Messages qui signalent un blocage côté YouTube plutôt qu'une piste morte.
_RETRYABLE = (
    "no video formats found",
    "the page needs to be reloaded",
    "sign in to confirm",
    "requires a po token",
    "player response",
    "failed to extract",
)


def is_retryable(message: str) -> bool:
    """Vrai si l'erreur vient d'un blocage, pas d'une vidéo indisponible."""
    lowered = (message or "").lower()
    return any(marker in lowered for marker in _RETRYABLE)

class _QuietLogger:
    """yt-dlp écrit ses erreurs sur stderr même en mode silencieux.

    Comme l'échec d'un client est attendu (on en essaie plusieurs), on
    redirige sa sortie vers notre journal plutôt que vers le terminal.
    """

    def debug(self, message: str) -> None: ...
    def info(self, message: str) -> None: ...

    def warning(self, message: str) -> None:
        log.debug("yt-dlp: %s", message)

    def error(self, message: str) -> None:
        log.debug("yt-dlp: %s", str(message).splitlines()[0][:120])


BASE_OPTS: dict = {
    "format": FORMAT_SELECTOR,
    "quiet": True,
    "no_warnings": True,
    "noplaylist": True,
    "noprogress": True,
    "logger": _QuietLogger(),
    "skip_download": True,
    # On ne veut que l'audio : inutile de faire résoudre les formats vidéo.
    "extract_flat": False,
}


YOUTUBE_HOSTS = ("youtube.com", "youtu.be", "youtube-nocookie.com")


class ExtractionError(RuntimeError):
    pass


# Hauteur maximale du clip selon la qualité réglée (screens.md §6).
VIDEO_HEIGHTS = {"low": 480, "normal": 720, "high": 1080, "max": 1440}


def video_selector(max_height: int) -> str:
    """VP9 d'abord (décodé partout, bon rendement), H.264 en repli, AV1 en
    dernier : son décodage logiciel est lourd sans accélération."""
    h = int(max_height)
    return (f"bestvideo[height<={h}][vcodec^=vp9]/"
            f"bestvideo[height<={h}][vcodec^=avc1]/"
            f"bestvideo[height<={h}]/bestvideo")


def codec_name(vcodec: str) -> str:
    lowered = vcodec.lower()
    for prefix, name in (("vp09", "VP9"), ("vp9", "VP9"), ("avc1", "H.264"),
                         ("av01", "AV1"), ("hev", "HEVC"), ("hvc", "HEVC")):
        if lowered.startswith(prefix):
            return name
    return vcodec.split(".", 1)[0].upper()


@dataclass(slots=True)
class VideoStream:
    video_id: str
    url: str
    width: int = 0
    height: int = 0
    codec: str = ""
    fps: float = 0.0

    @property
    def label(self) -> str:
        """« 1080p · VP9 », pour la pilule de format."""
        parts = [f"{self.height}p" if self.height else "",
                 self.codec]
        return " · ".join(p for p in parts if p)


class Extractor:
    def __init__(self, cookies=None) -> None:
        """`cookies` : un CookieManager, ou None pour un accès anonyme."""
        self._cookies = cookies

    @property
    def _opts(self) -> dict:
        """Options yt-dlp fraîches : les cookies peuvent changer à chaud."""
        opts = dict(BASE_OPTS)
        if self._cookies is not None:
            opts.update(self._cookies.ytdlp_opts())
        return opts

    def search(self, query: str, limit: int = 20) -> list[TrackRef]:
        """Recherche YouTube via yt-dlp. Repli quand YouTube Music est muet.

        Utilise `extract_flat` : une seule requête, pas de résolution de
        flux pour chaque résultat.
        """
        query = query.strip()
        if not query:
            return []
        opts = self._opts | {"extract_flat": "in_playlist", "skip_download": True}
        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                info = ydl.extract_info(f"ytsearch{int(limit)}:{query}", download=False)
        except yt_dlp.utils.DownloadError as exc:
            log.warning("Recherche yt-dlp échouée: %s", exc)
            return []
        refs = []
        for entry in (info or {}).get("entries") or []:
            if not isinstance(entry, dict) or not entry.get("id"):
                continue
            refs.append(TrackRef(
                video_id=entry["id"],
                title=entry.get("title") or "Sans titre",
                artist=entry.get("uploader") or entry.get("channel") or "",
                duration=float(entry.get("duration") or 0.0),
                thumbnail=(entry.get("thumbnails") or [{}])[-1].get("url")
                if entry.get("thumbnails") else None,
            ))
        return refs

    def resolve(self, url: str) -> Track:
        """URL ou terme de recherche -> Track. Bloquant."""
        query = url.strip()
        if not query:
            raise ExtractionError("Requête vide")
        # Une URL est validée avant d'atteindre yt-dlp : ses extracteurs
        # acceptent des schémas locaux qui n'ont rien à faire ici.
        if "://" in query.split("?", 1)[0]:
            try:
                # YouTube seulement : yt-dlp embarque ~1 800 extracteurs, et
                # MPRIS OpenUri permet à tout processus local d'en soumettre.
                check_url(query, allow_hosts=YOUTUBE_HOSTS)
            except UnsafeURL as exc:
                raise ExtractionError(str(exc)) from exc
        elif not query.startswith("ytsearch"):
            # Pas une URL -> recherche YouTube, premier résultat.
            query = f"ytsearch1:{query}"

        info = self._extract(query)
        if info is None:
            raise ExtractionError("Aucun résultat")
        # ytsearch renvoie une playlist d'un élément.
        if info.get("_type") == "playlist":
            entries = info.get("entries") or []
            if not entries:
                raise ExtractionError("Aucun résultat")
            info = entries[0]

        return self._to_track(info)

    def _extract(self, query: str, extra: dict | None = None) -> dict:
        """extract_info en essayant les clients YouTube dans l'ordre."""
        last_error = ""
        for client in CLIENT_FALLBACKS:
            options = self._opts | (extra or {})
            if client is not None:
                options = options | {
                    "extractor_args": {"youtube": {"player_client": [client]}}}
            try:
                with yt_dlp.YoutubeDL(options) as ydl:
                    return ydl.extract_info(query, download=False)
            except yt_dlp.utils.DownloadError as exc:
                last_error = str(exc)
                if not is_retryable(last_error):
                    raise ExtractionError(last_error) from exc
                log.info("Client %s refusé, essai suivant",
                         client or "par défaut")
        raise ExtractionError(last_error or "Aucun client YouTube n'a répondu")

    def resolve_video(self, url: str, max_height: int = 1080) -> VideoStream:
        """Flux vidéo seul d'un clip, pour l'écran Immersion. Bloquant.

        Vidéo sans audio : l'audio en cours continue dans la même instance
        mpv, on ne fait qu'y greffer une piste d'image.
        """
        try:
            check_url(url, allow_hosts=YOUTUBE_HOSTS)
        except UnsafeURL as exc:
            raise ExtractionError(str(exc)) from exc
        info = self._extract(url, {"format": video_selector(max_height)})
        stream = info.get("url")
        fmt = info
        if not stream:
            for candidate in info.get("requested_formats") or \
                    info.get("requested_downloads") or []:
                if candidate.get("url"):
                    stream, fmt = candidate["url"], candidate
                    break
        if not stream:
            raise ExtractionError("Aucun flux vidéo pour ce titre")
        # Le flux part tel quel à mpv, avec les en-têtes de la piste : il doit
        # venir des serveurs vidéo de Google, rien d'autre.
        try:
            safe_media_url(stream)
        except UnsafeURL as exc:
            raise ExtractionError(str(exc)) from exc
        return VideoStream(
            video_id=info.get("id") or "",
            url=stream,
            width=int(fmt.get("width") or 0),
            height=int(fmt.get("height") or 0),
            codec=codec_name(fmt.get("vcodec") or ""),
            fps=float(fmt.get("fps") or 0.0),
        )

    @staticmethod
    def _to_track(info: dict) -> Track:
        stream_url = info.get("url")
        headers: dict[str, str] = dict(info.get("http_headers") or {})

        # Selon le format sélectionné, l'URL directe peut n'être que dans
        # `requested_downloads` ou dans la liste de formats.
        if not stream_url:
            for candidate in (info.get("requested_downloads") or []):
                if candidate.get("url"):
                    stream_url = candidate["url"]
                    headers = dict(candidate.get("http_headers") or headers)
                    break
        if not stream_url:
            raise ExtractionError("Aucun flux audio trouvé pour cette vidéo")

        thumbs = info.get("thumbnails") or []
        thumbnail = info.get("thumbnail")
        if thumbs:
            # La plus grande miniatures disponible.
            best = max(thumbs, key=lambda t: (t.get("width") or 0) * (t.get("height") or 0))
            thumbnail = best.get("url") or thumbnail

        return Track(
            video_id=info.get("id") or "",
            title=info.get("track") or info.get("title") or "Sans titre",
            artist=info.get("artist") or info.get("uploader") or "",
            duration=float(info.get("duration") or 0.0),
            stream_url=stream_url,
            webpage_url=info.get("webpage_url") or "",
            thumbnail=thumbnail,
            album=info.get("album"),
            http_headers=headers,
        )
