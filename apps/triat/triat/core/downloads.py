"""Téléchargements hors-ligne (TODO §4.9).

yt-dlp extrait l'audio, ffmpeg pose les tags et la pochette. Les segments
SponsorBlock peuvent être retirés du fichier produit, pour obtenir une
piste propre plutôt qu'une vidéo avec son intro parlée.
"""

from __future__ import annotations

import logging
import re
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

import yt_dlp

from .models import TrackRef
from .paths import downloads_dir

log = logging.getLogger(__name__)

FORMATS = {
    "opus": ("bestaudio[acodec=opus]/bestaudio/best", "opus"),
    "m4a": ("bestaudio[ext=m4a]/bestaudio/best", "m4a"),
    "mp3": ("bestaudio/best", "mp3"),
}
QUALITY_BITRATE = {"low": "96", "normal": "128", "high": "192", "max": "0"}

# Caractères interdits ou pénibles dans un nom de fichier.
_UNSAFE = re.compile(r'[<>:"/\\|?*\x00-\x1f]')

PENDING, RUNNING, DONE, FAILED, CANCELLED = (
    "pending", "running", "done", "failed", "cancelled")


def safe_name(value: str, fallback: str = "Inconnu") -> str:
    """Nom de fichier sûr : ni séparateur, ni caractère de contrôle."""
    cleaned = _UNSAFE.sub("", (value or "").strip())
    cleaned = cleaned.strip(". ")          # pas de nom caché ni de point final
    return cleaned[:80] or fallback


@dataclass
class Task:
    """Une piste à télécharger."""

    ref: TrackRef
    state: str = PENDING
    progress: float = 0.0          # 0..1
    path: Path | None = None
    error: str = ""
    started_at: float = field(default_factory=time.time)

    @property
    def label(self) -> str:
        return self.ref.label


class DownloadManager:
    """File de téléchargement, un élément à la fois.

    Séquentiel volontairement : plusieurs extractions simultanées font
    réagir YouTube par du throttling.
    """

    def __init__(self, engine=None, settings=None, library=None,
                 sponsorblock=None) -> None:
        self._settings = settings
        self._library = library
        self._sponsorblock = sponsorblock
        self._queue: list[Task] = []
        self._lock = threading.Lock()
        self._worker: threading.Thread | None = None
        self._cancel = threading.Event()
        self._paused = threading.Event()
        self.on_change = None          # callback(task) depuis un thread

    # ---- File ------------------------------------------------------------

    @property
    def tasks(self) -> list[Task]:
        with self._lock:
            return list(self._queue)

    @property
    def active(self) -> Task | None:
        return next((t for t in self.tasks if t.state == RUNNING), None)

    def add(self, refs) -> int:
        """Ajoute des pistes, en ignorant celles déjà présentes ou faites."""
        added = 0
        with self._lock:
            known = {t.ref.video_id for t in self._queue
                     if t.state in (PENDING, RUNNING, DONE)}
            for ref in refs:
                if ref.video_id in known:
                    continue
                if self.local_path(ref) is not None:
                    continue
                self._queue.append(Task(ref=ref))
                known.add(ref.video_id)
                added += 1
        if added:
            self._ensure_worker()
        return added

    def cancel(self, video_id: str) -> None:
        with self._lock:
            for task in self._queue:
                if task.ref.video_id == video_id and task.state == PENDING:
                    task.state = CANCELLED
                elif task.ref.video_id == video_id and task.state == RUNNING:
                    self._cancel.set()

    def clear_finished(self) -> None:
        with self._lock:
            self._queue = [t for t in self._queue
                           if t.state in (PENDING, RUNNING)]

    def pause(self) -> None:
        self._paused.set()

    def resume(self) -> None:
        self._paused.clear()
        self._ensure_worker()

    @property
    def paused(self) -> bool:
        return self._paused.is_set()

    # ---- Fichiers --------------------------------------------------------

    def target_dir(self, ref: TrackRef) -> Path:
        """Dossier de destination : Artiste/Album, ou Artiste seul."""
        root = downloads_dir()
        artist = safe_name(ref.artist, "Artiste inconnu")
        album = safe_name(ref.album or "", "")
        return root / artist / album if album else root / artist

    def local_path(self, ref: TrackRef) -> Path | None:
        """Fichier déjà téléchargé pour cette piste, s'il existe."""
        folder = self.target_dir(ref)
        if not folder.is_dir():
            return None
        stem = safe_name(ref.title, ref.video_id)
        for extension in ("opus", "m4a", "mp3", "webm", "ogg"):
            candidate = folder / f"{stem}.{extension}"
            if candidate.exists() and candidate.stat().st_size > 0:
                return candidate
        return None

    # ---- Exécution -------------------------------------------------------

    def _ensure_worker(self) -> None:
        if self._worker is not None and self._worker.is_alive():
            return
        self._worker = threading.Thread(target=self._run, daemon=True)
        self._worker.start()

    def _notify(self, task: Task) -> None:
        if self.on_change is not None:
            try:
                self.on_change(task)
            except Exception as exc:
                log.debug("Notification de téléchargement : %s", exc)

    def _next_task(self) -> Task | None:
        with self._lock:
            return next((t for t in self._queue if t.state == PENDING), None)

    def _run(self) -> None:
        while not self._paused.is_set():
            task = self._next_task()
            if task is None:
                return
            task.state = RUNNING
            task.progress = 0.0
            self._cancel.clear()
            self._notify(task)
            try:
                path = self._download(task)
            except Exception as exc:
                task.state = CANCELLED if self._cancel.is_set() else FAILED
                task.error = str(exc).strip().splitlines()[0] if str(exc) else ""
                log.info("Téléchargement échoué (%s) : %s",
                         task.ref.video_id, task.error)
            else:
                task.state = DONE
                task.path = path
                task.progress = 1.0
            self._notify(task)

    def _options(self, task: Task) -> dict:
        settings = self._settings
        fmt = (settings.get("download_format") if settings else None) or "opus"
        selector, extension = FORMATS.get(fmt, FORMATS["opus"])
        quality = (settings.get("audio_quality") if settings else None) or "high"

        folder = self.target_dir(task.ref)
        folder.mkdir(parents=True, exist_ok=True)
        stem = safe_name(task.ref.title, task.ref.video_id)

        postprocessors = [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": extension,
            "preferredquality": QUALITY_BITRATE.get(quality, "192"),
        }, {"key": "FFmpegMetadata", "add_metadata": True}]
        # La pochette ne s'embarque proprement que dans certains conteneurs.
        if extension in ("m4a", "mp3"):
            postprocessors.append({"key": "EmbedThumbnail"})

        options = {
            "format": selector,
            # `outtmpl` est un gabarit : un « % » du titre serait interprété
            # (« 50%(id)s off » → « 50abc off ») et le fichier introuvable.
            "outtmpl": str(folder / f"{stem}".replace("%", "%%")) + ".%(ext)s",
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
            # `quiet` ne suffit pas : la barre de progression du
            # téléchargeur écrit malgré tout sur la sortie standard.
            "noprogress": True,
            "consoletitle": False,
            "writethumbnail": extension in ("m4a", "mp3"),
            "postprocessors": postprocessors,
            "progress_hooks": [lambda d: self._on_progress(task, d)],
            # Jamais de téléchargeur externe : une CVE 2026 y fuite les
            # cookies vers des hôtes tiers (docs/security/).
            "external_downloader": None,
        }
        if settings is not None and settings.get("download_cut_sponsorblock", True):
            options["postprocessors"] = [{
                "key": "SponsorBlock",
                "categories": ["music_offtopic", "sponsor", "selfpromo", "intro",
                               "outro", "interaction", "preview"],
            }, {
                "key": "ModifyChapters",
                "remove_sponsor_segments": ["music_offtopic", "sponsor",
                                            "selfpromo", "intro", "outro",
                                            "interaction", "preview"],
            }] + options["postprocessors"]
        return options

    def _on_progress(self, task: Task, data: dict) -> None:
        if self._cancel.is_set():
            raise yt_dlp.utils.DownloadError("Annulé")
        if data.get("status") == "downloading":
            total = data.get("total_bytes") or data.get("total_bytes_estimate")
            done = data.get("downloaded_bytes") or 0
            if total:
                task.progress = min(0.99, done / total)
                self._notify(task)
        elif data.get("status") == "finished":
            task.progress = 0.99
            self._notify(task)

    def _download(self, task: Task) -> Path:
        options = self._options(task)
        if self._cookies_opts():
            options.update(self._cookies_opts())
        with yt_dlp.YoutubeDL(options) as ydl:
            ydl.extract_info(task.ref.url, download=True)
        path = self.local_path(task.ref)
        if path is None:
            raise RuntimeError("Fichier introuvable après téléchargement")
        if self._library is not None:
            self._library.upsert_track(task.ref)
        return path

    def _cookies_opts(self) -> dict:
        engine_cookies = getattr(self, "_cookie_manager", None)
        if engine_cookies is None:
            return {}
        try:
            return engine_cookies.ytdlp_opts()
        except Exception:
            return {}

    def attach_cookies(self, cookie_manager) -> None:
        self._cookie_manager = cookie_manager
