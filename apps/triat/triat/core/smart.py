"""Smart playlists : playlists calculées par règles (screens.md §8).

Rien n'est stocké : chaque ouverture relit la bibliothèque. Les règles
restent volontairement simples et lisibles, affichées telles quelles.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Callable

from .models import TrackRef

DAY = 86400.0


@dataclass(frozen=True)
class SmartPlaylist:
    key: str
    name: str
    rule: str                      # affichée en mono sous le nom
    fetch: Callable[[], list[TrackRef]]


def smart_playlists(library, downloads=None, now: float | None = None,
                    limit: int = 500) -> list[SmartPlaylist]:
    """Les quatre smart playlists de la maquette, dans l'ordre."""
    moment = time.time() if now is None else now

    def on_repeat() -> list[TrackRef]:
        return library.top_tracks(limit=limit, since=moment - 30 * DAY)

    def never_played() -> list[TrackRef]:
        return library.unplayed(limit=limit, owned=True)

    def recently_added() -> list[TrackRef]:
        return library.added_since(moment - 14 * DAY, limit=limit, owned=True)

    def offline() -> list[TrackRef]:
        if downloads is None:
            return []
        return [ref for ref in library.all_tracks(limit=5000)
                if downloads.local_path(ref) is not None][:limit]

    return [
        SmartPlaylist("repeat", "En boucle", "écoutes · 30 j", on_repeat),
        SmartPlaylist("unplayed", "Jamais écoutés", "ajoutés · lectures = 0", never_played),
        SmartPlaylist("recent", "Récemment ajoutés", "ajout < 14 j", recently_added),
        SmartPlaylist("offline", "Hors-ligne", "téléchargé = vrai", offline),
    ]
