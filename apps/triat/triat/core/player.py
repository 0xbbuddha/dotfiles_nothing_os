"""Moteur de lecture : wrapper libmpv exposé en objet GObject.

libmpv émet ses événements depuis ses propres threads. Tout est renvoyé
vers le thread principal GLib avant d'atteindre l'UI.
"""

from __future__ import annotations

import logging

import mpv
from gi.repository import GLib, GObject

from .equalizer import build_filter
from .models import Track
from .net import sanitize_headers

log = logging.getLogger(__name__)

NORMALISE_FILTER = "dynaudnorm=g=5:f=250:r=0.9:p=0.5"


class Player(GObject.Object):
    """Lecteur audio. L'UI ne parle qu'à cet objet, jamais à mpv."""

    __gsignals__ = {
        # nouvel état : "idle" | "loading" | "playing" | "paused"
        "state-changed": (GObject.SignalFlags.RUN_FIRST, None, (str,)),
        "position-changed": (GObject.SignalFlags.RUN_FIRST, None, (float,)),
        "duration-changed": (GObject.SignalFlags.RUN_FIRST, None, (float,)),
        "track-changed": (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        "eof": (GObject.SignalFlags.RUN_FIRST, None, ()),
        "error": (GObject.SignalFlags.RUN_FIRST, None, (str,)),
        "video-error": (GObject.SignalFlags.RUN_FIRST, None, (str,)),
    }

    def __init__(self) -> None:
        super().__init__()
        self._track: Track | None = None
        self._state = "idle"
        self._duration = 0.0
        self._position = 0.0
        # Vrai pendant un seek initié par l'UI, pour ne pas renvoyer
        # la position à l'UI et faire sauter le curseur.
        self._seeking = False
        self._normalise = False
        self._eq_filter = ""
        # Clip demandé : (video_id, url). Greffé dès que le fichier est chargé.
        self._video: tuple[str, str] | None = None
        self._video_attached = False
        self._loaded = False
        self._render = None

        self._mpv = mpv.MPV(
            # Pas de vidéo par défaut. Le clip de l'écran Immersion est greffé
            # à la demande (`set_video`) et dessiné par l'API de rendu : mpv
            # n'ouvre jamais sa propre fenêtre.
            vid="no",
            vo="libmpv",
            hwdec="auto-safe",
            audio_display="no",
            ytdl=False,               # on résout nous-mêmes avec yt-dlp
            idle=True,
            terminal=False,
            keep_open="no",
            cache=True,
            demuxer_max_bytes="64MiB",
            gapless_audio="yes",
            audio_client_name="Triat",
        )

        self._last_sent_position: float | None = None
        self._mpv.observe_property("time-pos", self._on_time_pos)
        self._mpv.observe_property("duration", self._on_duration)
        self._mpv.observe_property("core-idle", self._on_core_idle)
        self._mpv.observe_property("pause", self._on_pause)

        @self._mpv.event_callback("file-loaded")
        def _on_file_loaded(_event) -> None:
            GLib.idle_add(self._on_loaded)

        @self._mpv.event_callback("end-file")
        def _on_end_file(event) -> None:
            reason = getattr(event.data, "reason", None)
            reason = getattr(reason, "value", reason)
            if reason in ("eof", 0):
                GLib.idle_add(self._emit_eof)
            elif reason in ("error", 4):
                GLib.idle_add(self._emit_error, "Échec de lecture du flux")

    # ---- API publique -------------------------------------------------

    @property
    def track(self) -> Track | None:
        return self._track

    @property
    def state(self) -> str:
        return self._state

    @property
    def duration(self) -> float:
        return self._duration

    @property
    def position_hint(self) -> float:
        """Dernière position connue. Approximative entre deux notifications."""
        return self._position

    def play_track(self, track: Track) -> None:
        self._track = track
        self._duration = track.duration
        self._position = 0.0
        self._set_state("loading")
        self._loaded = False
        self._video_attached = False
        self.emit("track-changed", track)
        self.emit("duration-changed", track.duration)

        # Les URL googlevideo exigent les en-têtes fournis par yt-dlp.
        # L'affectation est inconditionnelle : sans cela, les en-têtes de la
        # piste précédente — qui peuvent porter un Cookie — seraient envoyés
        # au serveur de la suivante.
        self._mpv.http_header_fields = sanitize_headers(track.http_headers)
        # `video-add … select` a pu fixer `vid` sur un numéro de piste : il
        # s'appliquerait au fichier suivant.
        self._mpv.vid = "no"

        try:
            self._mpv.play(track.stream_url)
            self._mpv.pause = False
        except Exception as exc:
            log.exception("mpv.play a échoué")
            self._emit_error(str(exc))

    # ---- Vidéo (écran Immersion) -------------------------------------

    def set_video(self, video_id: str, url: str) -> None:
        """Ajoute l'image du clip à la piste en cours, sans couper l'audio."""
        self._video = (video_id, url)
        self._attach_video()

    def clear_video(self) -> None:
        self._video = None
        if not self._video_attached:
            return
        self._video_attached = False
        try:
            for track in self._mpv.track_list or []:
                if track.get("type") == "video" and track.get("external"):
                    self._mpv.command("video-remove", track["id"])
            self._mpv.vid = "no"
        except Exception as exc:
            log.debug("Retrait de la vidéo : %s", exc)

    def _on_loaded(self) -> bool:
        self._loaded = True
        self._attach_video()
        return GLib.SOURCE_REMOVE

    def _attach_video(self) -> None:
        if (self._video is None or self._video_attached or not self._loaded
                or self._track is None
                or self._track.video_id != self._video[0]):
            return
        try:
            self._mpv.command("video-add", self._video[1], "select")
            self._video_attached = True
            # Une piste d'image greffée en cours de lecture reste figée :
            # mpv ne l'aligne pas seul sur l'audio (`vo-configured` reste
            # faux, écran noir). Un seek exact sur la position courante
            # resynchronise les deux flux ; l'audio ne fait qu'un micro-saut.
            position = self._mpv.time_pos or 0.0
            if position > 0.5:
                self._mpv.command("seek", position, "absolute", "exact")
        except Exception as exc:
            log.warning("Ajout du clip impossible : %s", exc)
            GLib.idle_add(self._emit_error_soft, "Clip illisible")

    def _emit_error_soft(self, message: str) -> bool:
        self.emit("video-error", message)
        return GLib.SOURCE_REMOVE

    def video_info(self) -> dict:
        """Dimensions et codec réellement décodés, pour la pilule de format."""
        try:
            params = self._mpv.video_params or {}
            return {"width": params.get("w") or 0,
                    "height": params.get("h") or 0,
                    "codec": self._mpv.video_format or "",
                    "hwdec": self._mpv.hwdec_current or ""}
        except Exception:
            return {}

    def create_render_context(self, get_proc_address):
        """Contexte OpenGL de mpv. À appeler avec le contexte GL courant."""
        self._render = mpv.MpvRenderContext(
            self._mpv, "opengl",
            opengl_init_params={"get_proc_address": get_proc_address})
        return self._render

    def free_render_context(self) -> None:
        """Libère le contexte, obligatoirement avant la fin de mpv."""
        if self._render is None:
            return
        self.clear_video()
        try:
            self._render.free()
        except Exception as exc:
            log.debug("Libération du rendu : %s", exc)
        self._render = None

    def toggle_pause(self) -> None:
        if self._state == "idle":
            return
        self._mpv.pause = not self._mpv.pause

    def stop(self) -> None:
        self._mpv.command("stop")
        self._track = None
        self._duration = 0.0
        self._position = 0.0
        self._set_state("idle")
        self.emit("position-changed", 0.0)

    def seek(self, seconds: float) -> None:
        if self._state == "idle":
            return
        self._seeking = True
        self._position = seconds
        try:
            self._mpv.seek(seconds, reference="absolute")
        except Exception as exc:
            log.warning("seek échoué: %s", exc)
        finally:
            self._seeking = False

    def set_volume(self, value: float) -> None:
        """Volume 0-100."""
        self._mpv.volume = max(0.0, min(100.0, value))

    def set_normalisation(self, enabled: bool) -> None:
        """Égalise le volume perçu entre les pistes.

        `dynaudnorm` agit en direct, sans analyse préalable du fichier —
        ce qu'on ne peut pas faire sur un flux.
        """
        self._normalise = enabled
        self._apply_filters()

    def set_equalizer(self, gains) -> None:
        """Gains des 10 bandes en dB ; `None` ou tout à zéro le désactive."""
        self._eq_filter = build_filter(gains) if gains else ""
        self._apply_filters()

    def _apply_filters(self) -> None:
        # L'égaliseur passe avant la normalisation : dynaudnorm rattrape
        # ainsi le niveau global que la pré-atténuation a fait perdre.
        chain = [f for f in (self._eq_filter,
                             NORMALISE_FILTER if self._normalise else "") if f]
        try:
            self._mpv.af = ",".join(chain)
        except Exception as exc:
            log.info("Filtres audio refusés (%s) : %s", chain, exc)

    def set_speed(self, speed: float) -> None:
        """Vitesse 0.5-2.0, hauteur préservée."""
        try:
            self._mpv.speed = max(0.5, min(2.0, speed))
        except Exception as exc:
            log.info("Changement de vitesse impossible : %s", exc)

    def shutdown(self) -> None:
        self.free_render_context()
        try:
            self._mpv.terminate()
        except Exception:
            pass

    # ---- Callbacks mpv (threads mpv) ----------------------------------

    # mpv signale la position en continu, depuis son propre thread. Relayer
    # chaque valeur inondait la boucle GTK d'appels (deux barres de 180
    # points, les paroles, les libellés) : on n'en garde que 5 par seconde,
    # et toujours un recul (saut arrière, nouvelle piste).
    POSITION_STEP = 0.2

    def _on_time_pos(self, _name: str, value: float | None) -> None:
        if value is None or self._seeking:
            return
        value = float(value)
        last = self._last_sent_position
        if last is not None and 0.0 <= value - last < self.POSITION_STEP:
            return
        self._last_sent_position = value
        GLib.idle_add(self._emit_position, value)

    def _on_duration(self, _name: str, value: float | None) -> None:
        if value:
            GLib.idle_add(self._emit_duration, float(value))

    def _on_core_idle(self, _name: str, value: bool | None) -> None:
        # core-idle passe à False dès que la lecture démarre vraiment.
        if value is False and self._state == "loading":
            GLib.idle_add(self._set_state, "playing")

    def _on_pause(self, _name: str, value: bool | None) -> None:
        if value is None or self._state in ("idle", "loading"):
            return
        GLib.idle_add(self._set_state, "paused" if value else "playing")

    # ---- Émission côté thread principal -------------------------------

    def _set_state(self, state: str) -> bool:
        if state != self._state:
            self._state = state
            self.emit("state-changed", state)
        return GLib.SOURCE_REMOVE

    def _emit_position(self, value: float) -> bool:
        self._position = value
        self.emit("position-changed", value)
        return GLib.SOURCE_REMOVE

    def _emit_duration(self, value: float) -> bool:
        self._duration = value
        self.emit("duration-changed", value)
        return GLib.SOURCE_REMOVE

    def _emit_eof(self) -> bool:
        self._set_state("idle")
        self.emit("eof")
        return GLib.SOURCE_REMOVE

    def _emit_error(self, message: str) -> bool:
        self._set_state("idle")
        self.emit("error", message)
        return GLib.SOURCE_REMOVE
