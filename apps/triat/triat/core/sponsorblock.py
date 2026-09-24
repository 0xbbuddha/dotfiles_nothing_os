"""Client SponsorBlock et moteur de saut.

Vie privée : l'API est interrogée par préfixe de hachage — on envoie les
4 premiers caractères du SHA-256 de l'ID de vidéo, jamais l'ID lui-même.
Le serveur renvoie toutes les vidéos partageant ce préfixe et le filtrage
final se fait en local.
"""

from __future__ import annotations

import hashlib
import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Sequence

from .models import Segment
from .net import read_capped, urlopen_checked

log = logging.getLogger(__name__)

API_BASE = "https://sponsor.ajay.app/api/skipSegments"
USER_AGENT = "Triat/0.1 (+lecteur de musique de bureau)"
HASH_PREFIX_LEN = 4

# Catégories connues du service. L'ordre sert d'ordre d'affichage.
CATEGORIES = (
    "music_offtopic",   # section non musicale d'un clip — la plus utile ici
    "sponsor",
    "selfpromo",
    "interaction",
    "intro",
    "outro",
    "preview",
    "filler",
)

SKIP = "skip"
ASK = "ask"
IGNORE = "ignore"

# Garde-fous contre les données aberrantes de la base communautaire.
MIN_SEGMENT_LENGTH = 0.8      # sauter moins d'une seconde ne vaut rien
MAX_COVERAGE_RATIO = 0.9      # un segment couvrant ~toute la piste est suspect


def video_hash_prefix(video_id: str, length: int = HASH_PREFIX_LEN) -> str:
    return hashlib.sha256(video_id.encode("utf-8")).hexdigest()[:length]


def merge_overlapping(segments: Sequence[Segment]) -> list[Segment]:
    """Fusionne les segments qui se chevauchent ou se touchent.

    La base contient souvent plusieurs soumissions pour un même passage ;
    sans fusion on enchaîne deux sauts sur la même zone.
    """
    ordered = sorted(segments, key=lambda s: (s.start, s.end))
    merged: list[Segment] = []
    for seg in ordered:
        if merged and seg.start <= merged[-1].end + 0.1:
            last = merged[-1]
            if seg.end > last.end:
                # On garde la catégorie du segment qui commence en premier.
                merged[-1] = Segment(last.start, seg.end, last.category, last.uuid)
        else:
            merged.append(seg)
    return merged


def sanitize(segments: Sequence[Segment], duration: float) -> list[Segment]:
    """Écarte les segments trop courts ou manifestement faux."""
    kept = []
    for seg in segments:
        if seg.length < MIN_SEGMENT_LENGTH:
            continue
        if duration > 0 and seg.length > duration * MAX_COVERAGE_RATIO:
            log.debug("Segment ignoré (couvre %.0f%% de la piste)",
                      100 * seg.length / duration)
            continue
        if seg.start < 0 or seg.end <= seg.start:
            continue
        kept.append(seg)
    return merge_overlapping(kept)


class SponsorBlockClient:
    """Accès réseau + cache. Les appels réseau sont bloquants."""

    def __init__(self, library=None, timeout: float = 8.0,
                 api_base: str = API_BASE) -> None:
        self._library = library
        self._timeout = timeout
        self._api_base = api_base

    def fetch(self, video_id: str, categories: Sequence[str]) -> list[Segment]:
        """Interroge l'API. Renvoie une liste (vide si rien). Bloquant."""
        if not video_id or not categories:
            return []
        params = urllib.parse.urlencode({
            "categories": json.dumps(list(categories)),
            "actionTypes": json.dumps(["skip"]),
        })
        url = f"{self._api_base}/{video_hash_prefix(video_id)}?{params}"
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urlopen_checked(request, self._timeout) as response:
                payload = json.loads(read_capped(response).decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return []   # aucune vidéo de ce préfixe n'a de segment
            log.warning("SponsorBlock HTTP %s", exc.code)
            raise
        except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as exc:
            log.warning("SponsorBlock injoignable: %s", exc)
            raise
        return self._parse(payload, video_id)

    @staticmethod
    def _parse(payload, video_id: str) -> list[Segment]:
        if not isinstance(payload, list):
            return []
        segments: list[Segment] = []
        for entry in payload:
            if not isinstance(entry, dict) or entry.get("videoID") != video_id:
                continue
            for raw in entry.get("segments") or []:
                try:
                    start, end = raw["segment"]
                    segments.append(Segment(
                        start=float(start), end=float(end),
                        category=str(raw.get("category", "")),
                        uuid=str(raw.get("UUID", "")),
                    ))
                except (KeyError, TypeError, ValueError):
                    continue
        return segments

    def segments_for(self, video_id: str, categories: Sequence[str],
                     duration: float = 0.0) -> list[Segment]:
        """Cache d'abord, réseau ensuite. Ne lève jamais."""
        if self._library is not None:
            cached = self._library.cached_segments(video_id)
            if cached is not None:
                return sanitize(cached, duration)
        try:
            fetched = self.fetch(video_id, categories)
        except Exception:
            return []
        if self._library is not None:
            # On mémorise aussi l'absence de segment, pour ne pas réinterroger.
            self._library.cache_segments(video_id, fetched)
        return sanitize(fetched, duration)


class SkipPlanner:
    """Décide, à une position donnée, s'il faut sauter. Sans réseau ni état global."""

    def __init__(self, segments: Sequence[Segment],
                 policies: dict[str, str] | None = None) -> None:
        self._segments = list(segments)
        self._policies = dict(policies or {})
        # Segments que l'utilisateur a explicitement annulés : on ne les
        # repropose plus pour cette lecture.
        self._disabled: set[str] = set()
        self.skipped_seconds = 0.0

    @property
    def segments(self) -> list[Segment]:
        return list(self._segments)

    def policy_for(self, category: str) -> str:
        return self._policies.get(category, IGNORE)

    def disable(self, segment: Segment) -> None:
        """L'utilisateur a annulé ce saut : ne plus le proposer."""
        self._disabled.add(self._key(segment))

    def segment_at(self, position: float) -> Segment | None:
        """Segment actionnable contenant `position`, ou None."""
        for seg in self._segments:
            if self._key(seg) in self._disabled:
                continue
            if self.policy_for(seg.category) == IGNORE:
                continue
            if seg.contains(position):
                return seg
        return None

    def target_for(self, segment: Segment, duration: float = 0.0) -> float:
        """Position vers laquelle sauter, en enchaînant les segments collés."""
        target = segment.end
        advanced = True
        while advanced:
            advanced = False
            for seg in self._segments:
                if (self.policy_for(seg.category) != IGNORE
                        and self._key(seg) not in self._disabled
                        and seg.start <= target + 0.1 < seg.end):
                    target = seg.end
                    advanced = True
        if duration > 0:
            target = min(target, duration)
        return target

    def note_skip(self, seconds: float) -> None:
        self.skipped_seconds += max(0.0, seconds)

    @staticmethod
    def _key(segment: Segment) -> str:
        return segment.uuid or f"{segment.category}:{segment.start:.3f}"
