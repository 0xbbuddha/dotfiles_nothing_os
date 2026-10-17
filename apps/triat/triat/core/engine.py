"""Moteur : orchestre file d'attente, extraction, lecture, SponsorBlock,
bibliothèque et recommandations.

C'est la seule façade dont l'UI a besoin. Tout le travail bloquant part
dans des threads ; tous les signaux sont émis sur le thread principal.
"""

from __future__ import annotations

import logging
import threading

from gi.repository import GLib, GObject

from .auth import CookieManager
from .extractor import VIDEO_HEIGHTS, ExtractionError, Extractor
from .innertube import InnerTube
from .downloads import DownloadManager
from .equalizer import clamp_gains
from .library import Library
from .lyrics import LyricsService
from .models import Segment, Track, TrackRef
from .player import Player
from .queue import Queue
from .recommend import Recommender
from . import search_results
from .scrobble import Scrobbler
from .settings import Settings
from .sponsorblock import ASK, SKIP, SkipPlanner, SponsorBlockClient
from .ytmusic import YTMusicService

log = logging.getLogger(__name__)

# En dessous de ce seuil, « précédent » rembobine au lieu de changer de piste.
RESTART_THRESHOLD = 3.0
# Marge avant la fin d'une piste pour déclencher la radio automatique.
AUTOPLAY_REFILL = 2


class Engine(GObject.Object):
    __gsignals__ = {
        "state-changed": (GObject.SignalFlags.RUN_FIRST, None, (str,)),
        "position-changed": (GObject.SignalFlags.RUN_FIRST, None, (float,)),
        "duration-changed": (GObject.SignalFlags.RUN_FIRST, None, (float,)),
        "track-changed": (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        "queue-changed": (GObject.SignalFlags.RUN_FIRST, None, ()),
        "busy": (GObject.SignalFlags.RUN_FIRST, None, (bool,)),
        "error": (GObject.SignalFlags.RUN_FIRST, None, (str,)),
        # Segment, secondes gagnées
        "segment-skipped": (GObject.SignalFlags.RUN_FIRST, None, (object, float)),
        # Segment dont la politique est « demander »
        "segment-pending": (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        # Clip de l'écran Immersion : "off" | "loading" | "ready" |
        # "unavailable", et le VideoStream quand il est prêt.
        "video-changed": (GObject.SignalFlags.RUN_FIRST, None, (str, object)),
        # Métadonnées de la bibliothèque complétées en arrière-plan
        "library-changed": (GObject.SignalFlags.RUN_FIRST, None, ()),
    }

    def __init__(self, settings: Settings | None = None,
                 library: Library | None = None,
                 player=None, extractor=None, ytmusic=None,
                 recommender=None, sponsorblock=None, cookies=None,
                 innertube=None) -> None:
        """Les dépendances sont injectables pour les tests ; par défaut
        l'Engine construit la chaîne réelle."""
        super().__init__()
        self.settings = settings or Settings()
        # Bilan SponsorBlock depuis le lancement (Réglages › SponsorBlock).
        self.session_skips = {"seconds": 0.0, "segments": 0, "tracks": set()}
        self.state = "idle"             # dernier état du lecteur
        self.library = library or Library()
        self.cookies = cookies or CookieManager(self.settings)
        self.extractor = extractor or Extractor(self.cookies)
        self.ytmusic = ytmusic or YTMusicService(self.cookies)
        self.innertube = innertube or InnerTube(self.cookies, self.settings)
        self.recommender = recommender or Recommender(
            self.library, self.ytmusic, self.extractor, self.innertube)
        self.sponsorblock = sponsorblock or SponsorBlockClient(self.library)
        self.lyrics = LyricsService(self.library)
        self.scrobbler = Scrobbler(self.settings)
        self.downloads = DownloadManager(self, self.settings, self.library,
                                         self.sponsorblock)
        self.downloads.attach_cookies(self.cookies)
        self.player = player or Player()
        self.queue = Queue()

        self._planner: SkipPlanner | None = None
        self._pending_asked: set[str] = set()
        self._load_token = 0
        self._current_ref: TrackRef | None = None
        self._max_position = 0.0
        self._recorded = False
        self._refilling = False
        self._busy = False
        # URL de flux déjà résolue pour la piste suivante, afin d'enchaîner
        # sans le temps mort d'un appel réseau.
        self._prefetched: tuple[str, Track] | None = None
        self._prefetching = False
        self._video_wanted = False
        self._video_state = "off"

        self.queue.repeat = self.settings.get("repeat")
        self.queue._shuffle = bool(self.settings.get("shuffle"))
        self.player.set_volume(float(self.settings.get("volume")))
        self.player.set_normalisation(bool(self.settings.get("normalise_volume")))
        self._apply_equalizer()

        self.queue.connect("current-changed", self._on_queue_current)
        self.queue.connect("changed", self._on_queue_changed)
        self.player.connect("state-changed", self._on_player_state)
        self.player.connect("position-changed", self._on_player_position)
        self.player.connect("duration-changed",
                            lambda _p, v: self.emit("duration-changed", v))
        self.player.connect("eof", self._on_player_eof)
        self.player.connect("error", self._on_player_error)
        self.player.connect("video-error", lambda _p, _m:
                            self._set_video_state("unavailable"))

    def _on_queue_changed(self, _queue) -> None:
        # L'anticipation ne vaut plus si la suite a changé.
        upcoming = self.queue.upcoming
        if not upcoming or (self._prefetched is not None
                            and self._prefetched[0] != upcoming[0].video_id):
            self._prefetched = None
        self.emit("queue-changed")

    def set_normalisation(self, enabled: bool) -> None:
        self.settings.set("normalise_volume", enabled)
        self.settings.save()
        self.player.set_normalisation(enabled)

    @property
    def equalizer(self) -> tuple[bool, tuple[float, ...]]:
        return (bool(self.settings.get("eq_enabled")),
                clamp_gains(self.settings.get("eq_gains")))

    def set_equalizer(self, enabled: bool | None = None,
                      gains=None) -> None:
        """Change l'état et/ou les gains, sauvegarde, applique en direct."""
        if enabled is not None:
            self.settings.set("eq_enabled", bool(enabled))
        if gains is not None:
            self.settings.set("eq_gains", list(clamp_gains(gains)))
        self.settings.save()
        self._apply_equalizer()

    def _apply_equalizer(self) -> None:
        enabled, gains = self.equalizer
        self.player.set_equalizer(gains if enabled else None)

    # ---- Clip vidéo (écran Immersion) -----------------------------------

    @property
    def video_state(self) -> str:
        return self._video_state

    def set_video_mode(self, enabled: bool) -> None:
        """Active le clip pour la piste en cours et toutes les suivantes."""
        if enabled == self._video_wanted:
            return
        self._video_wanted = enabled
        if not enabled:
            self.player.clear_video()
            self._set_video_state("off")
        elif self._current_ref is not None and self.player.state != "idle":
            self._load_video(self._current_ref, self._load_token)

    def _load_video(self, ref: TrackRef, token: int) -> None:
        self._set_video_state("loading")
        height = VIDEO_HEIGHTS.get(self.settings.get("audio_quality"), 1080)

        def worker() -> None:
            try:
                stream = self.extractor.resolve_video(ref.url, height)
            except Exception as exc:
                log.info("Clip indisponible pour %s : %s", ref.video_id, exc)
                stream = None
            GLib.idle_add(self._video_ready, ref.video_id, stream, token)

        threading.Thread(target=worker, daemon=True).start()

    def _video_ready(self, video_id: str, stream, token: int) -> bool:
        if token != self._load_token or not self._video_wanted:
            return GLib.SOURCE_REMOVE
        if stream is None:
            self._set_video_state("unavailable")
            return GLib.SOURCE_REMOVE
        self.player.set_video(video_id, stream.url)
        self._set_video_state("ready", stream)
        return GLib.SOURCE_REMOVE

    def _set_video_state(self, state: str, stream=None) -> None:
        self._video_state = state
        self.emit("video-changed", state, stream)

    # ---- Commandes de lecture ------------------------------------------

    def play_query(self, query: str) -> None:
        """Recherche puis lecture. Retourne immédiatement."""
        query = query.strip()
        if not query:
            return
        self._set_busy(True)
        threading.Thread(target=self._search_worker, args=(query,),
                         daemon=True).start()

    def _search_worker(self, query: str) -> None:
        try:
            # Une URL directe se joue telle quelle, sans passer par la recherche.
            if query.startswith(("http://", "https://")):
                track = self.extractor.resolve(query)
                refs = [track.to_ref()]
            else:
                refs = self.recommender.search(query, limit=25)
        except ExtractionError as exc:
            GLib.idle_add(self._fail, str(exc))
            return
        except Exception as exc:
            log.exception("Recherche impossible")
            GLib.idle_add(self._fail, str(exc))
            return
        if not refs:
            GLib.idle_add(self._fail, "Aucun résultat")
            return
        GLib.idle_add(self._start_with, refs)

    def _start_with(self, refs: list[TrackRef]) -> bool:
        self._set_busy(False)
        self.play_refs(refs, start=0)
        return GLib.SOURCE_REMOVE

    def start_radio(self) -> None:
        """Relance une radio à partir de la dernière piste connue."""
        ref = self._current_ref or (self.library.recent(limit=1) or [None])[0]
        if ref is None:
            self.emit("error", "Écoutez d'abord une piste pour lancer une radio")
            return
        # `_try_autoplay` part de la piste courante : on la pose si la file
        # est vide mais que l'historique nous donne un point de départ.
        if self._current_ref is None:
            self._current_ref = ref
        self._try_autoplay()

    def search_async(self, query: str, callback) -> None:
        """Recherche en arrière-plan. `callback(refs, erreur)` sur le thread UI."""
        query = query.strip()
        if not query:
            return
        self._set_busy(True)

        def worker() -> None:
            try:
                if query.startswith(("http://", "https://")):
                    refs = [self.extractor.resolve(query).to_ref()]
                else:
                    refs = self.recommender.search(query, limit=40)
            except Exception as exc:
                message = str(exc).strip().splitlines()[0] if str(exc) else "Erreur"
                GLib.idle_add(self._search_done, callback, [], message)
                return
            GLib.idle_add(self._search_done, callback, refs, None)

        threading.Thread(target=worker, daemon=True).start()

    def search_all_async(self, query: str, callback) -> None:
        """Recherche complète : pistes YouTube, correspondances locales,
        artistes et playlists. `callback(SearchResults, erreur)`."""
        query = query.strip()
        if not query:
            return
        self._set_busy(True)

        def worker() -> None:
            local = self.library.search(query, limit=20)
            playlists = self.library.list_playlists()
            error = None
            try:
                if query.startswith(("http://", "https://")):
                    remote = [self.extractor.resolve(query).to_ref()]
                else:
                    remote = self.recommender.search(query, limit=40)
            except Exception as exc:
                remote = []
                error = str(exc).strip().splitlines()[0] if str(exc) else "Erreur"
            results = search_results.build(query, remote, local, playlists)
            # Hors ligne, les pistes locales suffisent : pas d'erreur à montrer.
            if results.tracks:
                error = None
            GLib.idle_add(self._search_done, callback, results, error)

        threading.Thread(target=worker, daemon=True).start()

    def _search_done(self, callback, refs, error) -> bool:
        self._set_busy(False)
        callback(refs, error)
        return GLib.SOURCE_REMOVE

    def play_refs(self, refs, start: int = 0) -> None:
        """Remplace la file et lance la lecture."""
        self.library.upsert_many(refs)
        self.queue.set_items(refs, start=start)

    def enqueue(self, refs, next_up: bool = False) -> None:
        self.library.upsert_many(refs)
        if next_up:
            self.queue.insert_next(refs)
        else:
            self.queue.append(refs)

    def toggle_pause(self) -> None:
        # Piste restaurée au démarrage mais pas encore ouverte : « lecture »
        # doit la lancer (touche média, barre, bouton Reprendre), pas
        # basculer la pause d'un lecteur vide.
        if self.player.state == "idle" and self.queue.current is not None:
            self.resume()
            return
        self.player.toggle_pause()

    def stop(self) -> None:
        self._flush_history(completed=False)
        self.player.stop()
        self._planner = None
        self._current_ref = None

    def next(self) -> None:
        self._flush_history(completed=False)
        if self.queue.next(manual=True) is None:
            self._try_autoplay()

    def previous(self) -> None:
        # Un « précédent » en cours de piste rembobine, comme partout ailleurs.
        if self._max_position > RESTART_THRESHOLD and self.player.state != "idle":
            self.player.seek(0.0)
            return
        self._flush_history(completed=False)
        self.queue.previous()

    def jump_to(self, index: int) -> None:
        self._flush_history(completed=False)
        self.queue.jump_to(index)

    def seek(self, seconds: float) -> None:
        self.player.seek(seconds)

    def set_volume(self, value: float) -> None:
        self.player.set_volume(value)
        self.settings.set("volume", value)

    @property
    def shuffle(self) -> bool:
        return self.queue.shuffle

    @shuffle.setter
    def shuffle(self, value: bool) -> None:
        self.queue.shuffle = value
        self.settings.set("shuffle", value)

    @property
    def repeat(self) -> str:
        return self.queue.repeat

    @repeat.setter
    def repeat(self, mode: str) -> None:
        self.queue.repeat = mode
        self.settings.set("repeat", mode)

    @property
    def current(self) -> TrackRef | None:
        return self._current_ref

    # ---- Favoris --------------------------------------------------------

    def toggle_favorite(self) -> bool:
        if self._current_ref is None:
            return False
        return self.library.toggle_favorite(self._current_ref)

    def is_favorite(self) -> bool:
        return (self._current_ref is not None
                and self.library.is_favorite(self._current_ref.video_id))

    # ---- SponsorBlock ---------------------------------------------------

    def skip_segment(self, segment: Segment) -> None:
        """Saut demandé explicitement (politique « demander »)."""
        self._perform_skip(segment)

    def cancel_segment(self, segment: Segment) -> None:
        """L'utilisateur annule : revenir au début et ne plus proposer."""
        if self._planner is not None:
            self._planner.disable(segment)
        self.player.seek(segment.start)

    # ---- Chargement d'une piste -----------------------------------------

    def _on_queue_current(self, _queue: Queue, ref: TrackRef | None) -> None:
        self._flush_history(completed=False)
        if ref is None:
            self.player.stop()
            self._current_ref = None
            self.emit("track-changed", None)
            return

        self._load_token += 1
        token = self._load_token
        self._current_ref = ref
        self._planner = None
        self._pending_asked.clear()
        self._max_position = 0.0
        self._recorded = False

        # L'UI affiche la piste immédiatement, avant même la résolution réseau.
        self.emit("track-changed", ref)
        self._set_busy(True)
        threading.Thread(target=self._resolve_worker, args=(ref, token),
                         daemon=True).start()
        threading.Thread(target=self._segments_worker, args=(ref, token),
                         daemon=True).start()

    def _take_prefetched(self, ref: TrackRef) -> Track | None:
        """Récupère la résolution anticipée de cette piste, si elle existe."""
        if self._prefetched is not None and self._prefetched[0] == ref.video_id:
            track = self._prefetched[1]
            self._prefetched = None
            return track
        return None

    def _prefetch_next(self) -> None:
        """Résout la piste suivante pendant que la courante joue."""
        if self._prefetching:
            return
        upcoming = self.queue.upcoming
        if not upcoming:
            return
        target = upcoming[0]
        if self._prefetched is not None and self._prefetched[0] == target.video_id:
            return
        if self.downloads.local_path(target) is not None:
            return          # déjà hors ligne, rien à anticiper
        self._prefetching = True

        def worker() -> None:
            try:
                track = self.extractor.resolve(target.url)
            except Exception as exc:
                log.debug("Préchargement impossible : %s", exc)
                track = None
            GLib.idle_add(self._prefetch_done, target.video_id, track)

        threading.Thread(target=worker, daemon=True).start()

    def _prefetch_done(self, video_id: str, track) -> bool:
        self._prefetching = False
        if track is not None:
            self._prefetched = (video_id, track)
        return GLib.SOURCE_REMOVE

    def _resolve_worker(self, ref: TrackRef, token: int) -> None:
        # Piste déjà résolue par anticipation : on enchaîne sans attendre.
        anticipated = self._take_prefetched(ref)
        if anticipated is not None:
            GLib.idle_add(self._resolve_done, anticipated, token)
            return
        # Un fichier téléchargé évite la résolution réseau et fonctionne
        # hors ligne.
        local = self.downloads.local_path(ref)
        if local is not None:
            GLib.idle_add(self._resolve_done, Track(
                video_id=ref.video_id, title=ref.title, artist=ref.artist,
                duration=ref.duration, stream_url=local.as_uri(),
                webpage_url=ref.url, thumbnail=ref.thumbnail,
                album=ref.album, is_local=True), token)
            return
        try:
            track = self.extractor.resolve(ref.url)
        except Exception as exc:
            GLib.idle_add(self._resolve_failed, ref, token, str(exc))
            return
        GLib.idle_add(self._resolve_done, track, token)

    def _resolve_done(self, track: Track, token: int) -> bool:
        # Une piste plus récente a été demandée pendant la résolution.
        if token != self._load_token:
            return GLib.SOURCE_REMOVE
        self._set_busy(False)
        # yt-dlp connaît mieux les métadonnées que la recherche : on affine.
        enriched = track.to_ref()
        if self._current_ref is not None:
            previous = self._current_ref
            if not enriched.thumbnail:
                enriched.thumbnail = previous.thumbnail
            self._current_ref = enriched
            self.library.upsert_track(enriched)
            # La piste a déjà été annoncée avant la résolution : on ne
            # réémet que si yt-dlp a réellement corrigé quelque chose.
            if enriched != previous:
                self.emit("track-changed", enriched)
        self.player.play_track(track)
        if self._video_wanted:
            self._load_video(track.to_ref(), token)
        try:
            self.scrobbler.now_playing(enriched if self._current_ref else None)
        except Exception as exc:
            log.debug("Signalement d'écoute impossible : %s", exc)
        # La suivante se prépare pendant que celle-ci joue.
        GLib.timeout_add_seconds(3, lambda: (self._prefetch_next(), False)[1])
        return GLib.SOURCE_REMOVE

    def _resolve_failed(self, ref: TrackRef, token: int, message: str) -> bool:
        if token != self._load_token:
            return GLib.SOURCE_REMOVE
        self._set_busy(False)
        first_line = message.strip().splitlines()[0] if message.strip() else message
        self.emit("error", f"« {ref.title} » illisible : {first_line}")
        # Une piste morte ne doit pas bloquer la file.
        if self.queue.has_next:
            GLib.timeout_add(600, lambda: (self.queue.next(), False)[1])
        return GLib.SOURCE_REMOVE

    def _segments_worker(self, ref: TrackRef, token: int) -> None:
        if not self.settings.get("sponsorblock_enabled"):
            return
        policies = self.settings.get("sponsorblock_categories") or {}
        wanted = [cat for cat, action in policies.items() if action != "ignore"]
        if not wanted:
            return
        segments = self.sponsorblock.segments_for(ref.video_id, wanted, ref.duration)
        GLib.idle_add(self._segments_ready, segments, policies, token)

    def _segments_ready(self, segments, policies: dict, token: int) -> bool:
        if token != self._load_token:
            return GLib.SOURCE_REMOVE
        self._planner = SkipPlanner(segments, policies)
        if segments:
            log.info("SponsorBlock : %d segment(s) pour %s",
                     len(segments), self._current_ref.video_id if self._current_ref else "?")
        return GLib.SOURCE_REMOVE

    # ---- Réactions au lecteur -------------------------------------------

    def _on_player_state(self, _player: Player, state: str) -> None:
        self.state = state
        self.emit("state-changed", state)

    def _on_player_position(self, _player: Player, position: float) -> None:
        self._max_position = max(self._max_position, position)
        self.emit("position-changed", position)

        if self._planner is not None:
            segment = self._planner.segment_at(position)
            if segment is not None:
                policy = self._planner.policy_for(segment.category)
                if policy == SKIP:
                    self._perform_skip(segment)
                elif policy == ASK:
                    key = segment.uuid or f"{segment.category}:{segment.start}"
                    if key not in self._pending_asked:
                        self._pending_asked.add(key)
                        self.emit("segment-pending", segment)

        # Préparer la suite avant la fin, pour enchaîner sans trou.
        if (self.settings.get("autoplay_radio")
                and not self.queue.has_next
                and len(self.queue.upcoming) < AUTOPLAY_REFILL
                and self.player.duration > 0
                and position > self.player.duration - 30):
            self._try_autoplay()

    def _perform_skip(self, segment: Segment) -> None:
        if self._planner is None:
            return
        target = self._planner.target_for(segment, self.player.duration)
        gained = max(0.0, target - self.player.position_hint)
        self._planner.disable(segment)          # ne pas resauter le même passage
        self._planner.note_skip(gained)
        self.session_skips["seconds"] += gained
        self.session_skips["segments"] += 1
        if self._current_ref is not None:
            self.session_skips["tracks"].add(self._current_ref.video_id)
        self.player.seek(target)
        self.emit("segment-skipped", segment, gained)

    def _on_player_eof(self, _player: Player) -> None:
        self._flush_history(completed=True)
        if self.queue.next() is None:
            self._try_autoplay()

    def _on_player_error(self, _player: Player, message: str) -> None:
        self.emit("error", message)
        if self.queue.has_next:
            self.queue.next()

    # ---- Radio automatique ----------------------------------------------

    def _try_autoplay(self) -> None:
        if not self.settings.get("autoplay_radio") or self._refilling:
            return
        ref = self._current_ref
        if ref is None:
            return
        self._refilling = True
        threading.Thread(target=self._autoplay_worker, args=(ref,),
                         daemon=True).start()

    def _autoplay_worker(self, ref: TrackRef) -> None:
        try:
            exclude = [t.video_id for t in self.queue.items]
            refs = self.recommender.radio_for(ref, limit=20, exclude=exclude)
        except Exception as exc:
            log.warning("Radio automatique impossible: %s", exc)
            refs = []
        GLib.idle_add(self._autoplay_ready, refs)

    def _autoplay_ready(self, refs) -> bool:
        self._refilling = False
        if not refs:
            return GLib.SOURCE_REMOVE
        was_idle = self.player.state == "idle"
        self.enqueue(refs)
        if was_idle:
            self.queue.next()
        return GLib.SOURCE_REMOVE

    # ---- Historique ------------------------------------------------------

    def _flush_history(self, completed: bool) -> None:
        """Enregistre l'écoute en cours si elle a duré assez longtemps."""
        ref = self._current_ref
        if ref is None or self._recorded or self.settings.get("private_session"):
            return
        played = self._max_position
        duration = self.player.duration or ref.duration
        ratio = float(self.settings.get("scrobble_after_ratio") or 0.5)
        long_enough = played >= 30.0 or (duration > 0 and played >= duration * ratio)
        if not long_enough:
            return
        self._recorded = True
        try:
            self.library.record_play(ref, played, completed)
        except Exception as exc:
            log.warning("Historique non enregistré: %s", exc)
        # Déclaration ListenBrainz, en arrière-plan et sans jamais bloquer.
        try:
            self.scrobbler.submit(ref, played, duration)
        except Exception as exc:
            log.debug("Scrobble impossible : %s", exc)

    # ---- État persistant -------------------------------------------------

    def save_state(self) -> None:
        snapshot = self.queue.snapshot()
        self.settings.update(
            last_queue=snapshot["items"],
            last_index=snapshot["index"],
            last_position=self._max_position,
            repeat=snapshot["repeat"],
            shuffle=snapshot["shuffle"],
        )
        self.settings.save()

    def backfill_durations_async(self, workers: int = 3) -> None:
        """Complète en arrière-plan les durées manquantes (imports oEmbed).

        Une seule passe à la fois ; une vidéo en échec n'est pas réessayée
        pendant la session.
        """
        if getattr(self, "_backfilling", False) or self.innertube is None:
            return
        failed = self.__dict__.setdefault("_duration_failures", set())
        todo = [v for v in self.library.missing_duration() if v not in failed]
        if not todo:
            return
        self._backfilling = True
        lock = threading.Lock()
        done = [0]

        def worker() -> None:
            while True:
                with lock:
                    if not todo:
                        return
                    video_id = todo.pop()
                try:
                    seconds = self.innertube.video_length(video_id)
                except Exception:
                    seconds = None
                if seconds:
                    self.library.set_duration(video_id, seconds)
                    with lock:
                        done[0] += 1
                else:
                    failed.add(video_id)

        def run() -> None:
            threads = [threading.Thread(target=worker, daemon=True)
                       for _ in range(max(1, workers))]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            self._backfilling = False
            log.info("Durées complétées : %d", done[0])
            if done[0]:
                GLib.idle_add(lambda: (self.emit("library-changed"), False)[1])

        threading.Thread(target=run, daemon=True).start()

    def restore_state(self) -> bool:
        """Recharge la file précédente sans lancer la lecture.

        Renvoie True si quelque chose a été restauré.
        """
        items = self.settings.get("last_queue") or []
        if not items:
            return False
        restored = []
        for data in items:
            if not isinstance(data, dict):
                continue
            try:
                restored.append(TrackRef.from_dict(data))
            except (ValueError, TypeError):
                continue
        self.queue._items = restored
        if not self.queue._items:
            return False
        index = self.settings.get("last_index") or 0
        index = max(0, min(int(index), len(self.queue._items) - 1))
        self.queue._build_order_from(index)
        self._current_ref = self.queue.current
        self.emit("queue-changed")
        self.emit("track-changed", self._current_ref)
        return True

    def resume(self) -> None:
        """Reprend la piste restaurée là où elle s'était arrêtée."""
        ref = self.queue.current
        if ref is None:
            return
        position = float(self.settings.get("last_position") or 0.0)
        self._on_queue_current(self.queue, ref)
        if position > RESTART_THRESHOLD:
            def seek_when_ready() -> bool:
                if self.player.state in ("playing", "paused"):
                    self.player.seek(position)
                    return False
                return True   # réessayer au prochain tick
            GLib.timeout_add(300, seek_when_ready)

    def shutdown(self) -> None:
        self._flush_history(completed=False)
        self.save_state()
        self.player.shutdown()
        self.library.close()
        # Le fichier de cookies en clair ne survit pas à la session.
        try:
            self.cookies.release()
        except Exception as exc:
            log.debug("Nettoyage des cookies: %s", exc)

    # ---- Divers ----------------------------------------------------------

    def _set_busy(self, busy: bool) -> None:
        if busy != self._busy:
            self._busy = busy
            self.emit("busy", busy)

    def _fail(self, message: str) -> bool:
        self._set_busy(False)
        first_line = message.strip().splitlines()[0] if message.strip() else message
        self.emit("error", first_line)
        return GLib.SOURCE_REMOVE
