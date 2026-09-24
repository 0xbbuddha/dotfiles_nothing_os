"""Mixes de l'accueil, fabriqués depuis la bibliothèque locale.

Aucun appel réseau : l'accueil s'affiche instantanément et hors ligne.
Chaque mix est tiré avec une graine qui dépend du jour, donc stable
toute la journée et renouvelé le lendemain.
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import random
from dataclasses import dataclass, field

from .models import TrackRef

MIX_SIZE = 30
ARTIST_MIXES = 4
# Un artiste en dessous de ce nombre de pistes ne fait pas un mix crédible.
MIN_ARTIST_TRACKS = 4


@dataclass(slots=True)
class Mix:
    key: str
    title: str
    refs: list[TrackRef] = field(default_factory=list)
    # Nourrit le motif de points de la vignette : un mix garde son visage.
    seed: int = 0

    @property
    def subtitle(self) -> str:
        """« 30 titres, avec Vialice, LEDOUBLE et Luther »."""
        names: list[str] = []
        for ref in self.refs:
            artist = (ref.artist or "").strip()
            if artist and artist not in names:
                names.append(artist)
            if len(names) == 3:
                break
        count = f"{len(self.refs)} titre{'s' if len(self.refs) > 1 else ''}"
        if not names:
            return count
        joined = names[0] if len(names) == 1 else (
            ", ".join(names[:-1]) + " et " + names[-1])
        return f"{count}, avec {joined}"


def _seed(*parts: str) -> int:
    digest = hashlib.sha256("|".join(parts).encode()).digest()
    return int.from_bytes(digest[:8], "big")


def _unique(refs, exclude: set[str] | None = None) -> list[TrackRef]:
    seen = set(exclude or ())
    out = []
    for ref in refs:
        if ref.video_id and ref.video_id not in seen:
            seen.add(ref.video_id)
            out.append(ref)
    return out


def build_mixes(library, today: _dt.date | None = None) -> list[Mix]:
    day = (today or _dt.date.today()).isoformat()
    mixes: list[Mix] = []
    everything = library.all_tracks()
    if not everything:
        return mixes

    # --- Mix du jour : ce qu'on aime d'abord, complété par tout le reste ---
    seed = _seed("jour", day)
    rng = random.Random(seed)
    loved = _unique(library.list_favorites(limit=200)
                    + library.top_tracks(limit=100))
    rest = [r for r in everything if r not in loved]
    rng.shuffle(loved)
    rng.shuffle(rest)
    # Deux tiers de valeurs sûres au plus, le reste pour la surprise.
    head = loved[: MIX_SIZE * 2 // 3]
    daily = _unique(head + rest)[:MIX_SIZE]
    rng.shuffle(daily)
    mixes.append(Mix("daily", "Mix du jour", daily, seed))

    # --- Un mix par artiste phare, élargi par le voisinage en playlist ---
    for artist, count in library.artists(limit=ARTIST_MIXES * 3, owned=True):
        if count < MIN_ARTIST_TRACKS or len(mixes) > ARTIST_MIXES:
            break
        seed = _seed("artiste", artist.lower(), day)
        rng = random.Random(seed)
        own = library.tracks_by_artist(artist)
        near = library.playlist_neighbours([r.video_id for r in own])
        rng.shuffle(own)
        # Moitié artiste, moitié voisins : sinon c'est une discographie.
        picked = _unique(own[: MIX_SIZE // 2] + near)[:MIX_SIZE]
        if len(picked) < MIN_ARTIST_TRACKS * 2:
            continue
        first, others = picked[0], picked[1:]
        rng.shuffle(others)
        mixes.append(Mix(f"artist:{artist.lower()}", f"Mix {artist}",
                         [first] + others, seed))

    # --- À découvrir : jamais écouté ---
    fresh = library.unplayed(owned=True)
    if len(fresh) >= MIN_ARTIST_TRACKS * 2:
        seed = _seed("decouvrir", day)
        rng = random.Random(seed)
        rng.shuffle(fresh)
        mixes.append(Mix("fresh", "À découvrir", fresh[:MIX_SIZE], seed))
    return mixes
