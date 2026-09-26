"""Modèles de données partagés par le core."""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass, field

# Alphabet des identifiants YouTube (11 caractères en pratique ; on reste
# souple sur la longueur pour les identifiants de test et de playlist).
_VIDEO_ID = re.compile(r"[A-Za-z0-9_-]{1,64}")


@dataclass(slots=True)
class TrackRef:
    """Référence légère à une piste, sans URL de flux.

    C'est ce que contiennent la file d'attente, les playlists et la
    bibliothèque : résoudre l'URL de flux coûte un appel réseau et expire
    au bout de quelques heures, donc on ne le fait qu'au dernier moment.
    """

    video_id: str
    title: str = "Sans titre"
    artist: str = ""
    duration: float = 0.0
    thumbnail: str | None = None
    album: str | None = None

    @property
    def label(self) -> str:
        return f"{self.artist} — {self.title}" if self.artist else self.title

    @property
    def url(self) -> str:
        return f"https://www.youtube.com/watch?v={self.video_id}"

    def as_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "TrackRef":
        """Reconstruit une piste depuis un JSON non fiable (réglages).

        L'identifiant finit dans une URL et un nom de fichier : on n'accepte
        que l'alphabet des identifiants YouTube. Les autres champs sont
        convertis au bon type, ou abandonnés.
        """
        video_id = data.get("video_id")
        if not isinstance(video_id, str) or not _VIDEO_ID.fullmatch(video_id):
            raise ValueError("Identifiant de vidéo invalide")
        fields: dict = {"video_id": video_id}
        for key in ("title", "artist", "thumbnail", "album"):
            value = data.get(key)
            if isinstance(value, str):
                fields[key] = value[:500]
        duration = data.get("duration")
        if isinstance(duration, (int, float)) and not isinstance(duration, bool) \
                and 0 <= duration < 1e6:
            fields["duration"] = float(duration)
        return cls(**fields)


@dataclass(slots=True)
class Track:
    """Une piste résolue, prête à être lue."""

    video_id: str
    title: str
    artist: str
    duration: float
    stream_url: str
    webpage_url: str
    thumbnail: str | None = None
    album: str | None = None
    http_headers: dict[str, str] = field(default_factory=dict)
    # Vrai si le flux vient d'un fichier téléchargé localement.
    is_local: bool = False

    @property
    def label(self) -> str:
        return f"{self.artist} — {self.title}" if self.artist else self.title

    def to_ref(self) -> TrackRef:
        return TrackRef(
            video_id=self.video_id,
            title=self.title,
            artist=self.artist,
            duration=self.duration,
            thumbnail=self.thumbnail,
            album=self.album,
        )


@dataclass(slots=True)
class Segment:
    """Un segment SponsorBlock, en secondes."""

    start: float
    end: float
    category: str
    uuid: str = ""

    @property
    def length(self) -> float:
        return max(0.0, self.end - self.start)

    def contains(self, position: float, margin: float = 0.0) -> bool:
        return self.start - margin <= position < self.end


_HASHTAGS = re.compile(r"(?:\s+#\w+)+\s*$", re.UNICODE)


def display_title(title: str, artist: str = "") -> str:
    """Titre sans le bruit des téléversements YouTube, pour l'affichage.

    « Vialice - Two Drugs » par Vialice → « Two Drugs » ;
    « Code Red #underground #newmusic » → « Code Red ».
    La donnée stockée n'est jamais modifiée.
    """
    text = (title or "").strip()
    text = _HASHTAGS.sub("", text).strip() or text
    name = (artist or "").strip()
    if name:
        for sep in (" - ", " – ", " — "):
            prefix = name + sep
            if text.lower().startswith(prefix.lower()) and len(text) > len(prefix):
                text = text[len(prefix):].strip()
                break
    return text or (title or "")

