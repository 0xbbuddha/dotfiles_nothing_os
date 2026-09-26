"""Moteur de recommandation.

Quatre niveaux, du meilleur au plus dégradé :
1. YouTube Music — le meilleur pour de la musique, mais muet sans cookies,
2. InnerTube client WEB — les recommandations anonymes, liées à
   l'identifiant de visiteur : c'est ce qui marche sans compte,
3. co-occurrence dans l'historique local — hors ligne, sans rien,
4. les plus écoutées, pour ne jamais rendre une page vide.
"""

from __future__ import annotations

import logging
from collections.abc import Iterable, Sequence

from .models import TrackRef

log = logging.getLogger(__name__)


def _dedupe(refs: Iterable[TrackRef], exclude: set[str]) -> list[TrackRef]:
    seen = set(exclude)
    unique = []
    for ref in refs:
        if ref.video_id and ref.video_id not in seen:
            seen.add(ref.video_id)
            unique.append(ref)
    return unique


class Recommender:
    def __init__(self, library, ytmusic=None, extractor=None,
                 innertube=None) -> None:
        self._library = library
        self._ytmusic = ytmusic
        self._extractor = extractor
        self._innertube = innertube

    # ---- Recherche -----------------------------------------------------

    def search(self, query: str, limit: int = 25) -> list[TrackRef]:
        """YouTube Music d'abord, yt-dlp en repli. Bloquant."""
        query = query.strip()
        if not query:
            return []
        if self._ytmusic is not None:
            refs = self._ytmusic.search_tracks(query, limit=limit)
            if refs:
                self._remember(refs)
                return refs
        if self._innertube is not None:
            refs = self._innertube.search(query, limit=limit)
            if refs:
                self._remember(refs)
                return refs
        if self._extractor is not None:
            refs = self._extractor.search(query, limit=limit)
            self._remember(refs)
            return refs
        return []

    # ---- Radio / lecture automatique -----------------------------------

    def radio_for(self, ref: TrackRef, limit: int = 25,
                  exclude: Sequence[str] = ()) -> list[TrackRef]:
        """Suite de lecture à partir d'une piste. Bloquant."""
        excluded = set(exclude) | {ref.video_id}

        if self._ytmusic is not None:
            remote = self._ytmusic.radio(ref.video_id, limit=limit)
            remote = _dedupe(remote, excluded)
            if remote:
                self._remember(remote)
                return remote[:limit]

        # InnerTube WEB : la seule source de recommandations qui réponde
        # vraiment sans compte (le client YouTube Music, lui, renvoie vide).
        if self._innertube is not None:
            anonymous = _dedupe(self._innertube.related(ref.video_id, limit=limit),
                                excluded)
            if anonymous:
                self._remember(anonymous)
                return anonymous[:limit]

        local = _dedupe(self._library.co_played(ref.video_id, limit=limit), excluded)
        if local:
            log.info("Radio locale (co-écoute) pour %s", ref.video_id)
            return local[:limit]

        fallback = _dedupe(self._library.top_tracks(limit=limit * 2), excluded)
        if fallback:
            log.info("Radio de repli : les plus écoutées")
        return fallback[:limit]

    # ---- Page d'accueil -------------------------------------------------

    def home_sections(self) -> list[dict]:
        """Sections d'accueil. Les sections locales sont toujours présentes."""
        sections: list[dict] = []

        if self._ytmusic is not None:
            try:
                sections.extend(self._ytmusic.home())
            except Exception as exc:
                log.info("Accueil YouTube Music indisponible: %s", exc)

        if not sections and self._innertube is not None:
            anonymous = self._innertube.home()
            if anonymous:
                self._remember(anonymous)
                sections.append({"title": "Recommandé pour vous",
                                 "tracks": anonymous, "source": "innertube"})

        recent = self._library.recent(limit=20)
        if recent:
            sections.append({"title": "Écouté récemment", "tracks": recent,
                             "source": "local"})
        favorites = self._library.list_favorites(limit=20)
        if favorites:
            sections.append({"title": "Vos favoris", "tracks": favorites,
                             "source": "local"})
        top = self._library.top_tracks(limit=20)
        if top:
            sections.append({"title": "Les plus écoutés", "tracks": top,
                             "source": "local"})
        return sections

    # ---- Interne -------------------------------------------------------

    def _remember(self, refs: Sequence[TrackRef]) -> None:
        """Alimente la bibliothèque locale pour la recherche hors ligne."""
        try:
            self._library.upsert_many(refs)
        except Exception as exc:
            log.warning("Mémorisation locale impossible: %s", exc)
