"""Doubles de test : un lecteur et un extracteur sans mpv ni réseau."""

from __future__ import annotations

from gi.repository import GObject

from triat.core.models import Track, TrackRef


class FakePlayer(GObject.Object):
    """Reproduit l'interface publique de Player, sans libmpv."""

    __gsignals__ = {
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
        self.state = "idle"
        self.duration = 0.0
        self.position_hint = 0.0
        self.track = None
        self.seeks: list[float] = []
        self.played: list[Track] = []
        self.stopped = 0
        self.volume = 0.0
        self.normalisation = False
        self.equalizer = None
        self.video: tuple[str, str] | None = None
        self.speed = 1.0

    def play_track(self, track: Track) -> None:
        self.track = track
        self.played.append(track)
        self.duration = track.duration
        self.position_hint = 0.0
        self.state = "playing"
        self.emit("state-changed", "playing")

    def toggle_pause(self) -> None:
        self.state = "paused" if self.state == "playing" else "playing"
        self.emit("state-changed", self.state)

    def stop(self) -> None:
        self.stopped += 1
        self.state = "idle"
        self.position_hint = 0.0
        self.emit("state-changed", "idle")

    def seek(self, seconds: float) -> None:
        self.seeks.append(seconds)
        self.position_hint = seconds

    def set_volume(self, value: float) -> None:
        self.volume = value

    def set_normalisation(self, enabled: bool) -> None:
        self.normalisation = enabled

    def set_video(self, video_id: str, url: str) -> None:
        self.video = (video_id, url)

    def clear_video(self) -> None:
        self.video = None

    def set_equalizer(self, gains) -> None:
        self.equalizer = tuple(gains) if gains else None

    def set_speed(self, speed: float) -> None:
        self.speed = speed

    def shutdown(self) -> None: ...

    # -- pilotage du test --
    def advance(self, position: float) -> None:
        self.position_hint = position
        self.emit("position-changed", position)

    def finish(self) -> None:
        self.state = "idle"
        self.emit("eof")


class FakeExtractor:
    """Résout instantanément, sans réseau."""

    def __init__(self, fail_ids: set[str] | None = None) -> None:
        self.fail_ids = fail_ids or set()
        self.resolved: list[str] = []
        self.no_video_ids: set[str] = set()
        self.video_heights: list[int] = []

    def resolve(self, url: str) -> Track:
        video_id = url.rsplit("v=", 1)[-1]
        self.resolved.append(video_id)
        if video_id in self.fail_ids:
            raise RuntimeError(f"ERROR: {video_id} indisponible")
        return Track(
            video_id=video_id,
            title=f"Titre {video_id}",
            artist="Artiste",
            duration=200.0,
            stream_url=f"https://exemple.invalide/{video_id}.webm",
            webpage_url=url,
        )

    def resolve_video(self, url: str, max_height: int = 1080):
        from triat.core.extractor import VideoStream
        video_id = url.rsplit("v=", 1)[-1]
        self.video_heights.append(max_height)
        if video_id in self.fail_ids or video_id in self.no_video_ids:
            raise RuntimeError("pas de clip")
        return VideoStream(video_id, f"https://exemple.invalide/{video_id}.vp9",
                           1920, 1080, "VP9", 25.0)

    def search(self, query: str, limit: int = 20) -> list[TrackRef]:
        return [TrackRef(f"s{i}", f"Résultat {i} pour {query}") for i in range(3)]


class FakeSponsorBlock:
    def __init__(self, segments=None) -> None:
        self._segments = segments or []
        self.calls: list[str] = []

    def segments_for(self, video_id: str, categories, duration=0.0):
        self.calls.append(video_id)
        return list(self._segments)


class FakeRecommender:
    def __init__(self, radio=None, results=None) -> None:
        self._radio = radio or []
        self._results = results or []

    def search(self, query: str, limit: int = 25):
        return list(self._results)

    def radio_for(self, ref, limit=25, exclude=()):
        return [r for r in self._radio if r.video_id not in set(exclude)]


class FakeCookies:
    """CookieManager minimal : aucune session."""

    def __init__(self, present: bool = False, authenticated: bool = False) -> None:
        from triat.core.auth import CookieStatus

        self._status = CookieStatus(present=present, authenticated=authenticated)

    def status(self):
        return self._status

    def cookie_header(self):
        return None

    def authorization_header(self, origin: str = ""):
        return None

    def ytdlp_opts(self):
        return {}

    def release(self) -> None: ...


class FakeInnerTube:
    def related(self, video_id: str, limit: int = 25):
        return []

    def home(self, limit: int = 40):
        return []

    def search(self, query: str, limit: int = 25):
        return []

    def video_length(self, video_id: str):
        return getattr(self, "lengths", {}).get(video_id)


class FakeDownloads:
    """Gestionnaire de téléchargements inerte."""

    def local_path(self, _ref):
        return None

    def add(self, _refs) -> int:
        return 0

    def attach_cookies(self, _manager) -> None: ...
