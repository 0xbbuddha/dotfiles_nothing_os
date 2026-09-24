"""Client InnerTube (API interne de YouTube), sans compte.

Pourquoi ce module en plus de `ytmusicapi` : sans session Google, le client
YouTube Music ne renvoie rien (accueil, recherche et radio vides). Le client
WEB, lui, répond normalement — c'est la source des recommandations anonymes.

Ces recommandations reposent entièrement sur `visitorData` : l'identifiant de
visiteur que YouTube attache à un historique de navigation sans compte. Il est
donc conservé entre les lancements — un nouvel identifiant à chaque démarrage
donnerait un profil vierge, et donc un accueil vide.
"""

from __future__ import annotations

import json
import logging
import re
import threading
import time
import urllib.error
import urllib.request

from .models import TrackRef
from .net import read_capped, urlopen_checked

log = logging.getLogger(__name__)

WEB_HOST = "https://www.youtube.com"
USER_AGENT = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")

# Flux d'accueil recommandé pour un visiteur non connecté.
BROWSE_HOME = "FEwhat_to_watch"
# Un identifiant de visiteur se périme ; on le rafraîchit régulièrement.
VISITOR_MAX_AGE = 30 * 86400

_RE_API_KEY = re.compile(r'"INNERTUBE_API_KEY":"([^"]+)"')
_RE_CLIENT_VERSION = re.compile(r'"INNERTUBE_CLIENT_VERSION":"([^"]+)"')
_RE_VISITOR = re.compile(r'"visitorData":"([^"]+)"')


def _text(node) -> str:
    """Extrait le texte d'un nœud InnerTube (`simpleText` ou `runs`)."""
    if isinstance(node, str):
        return node
    if not isinstance(node, dict):
        return ""
    if "simpleText" in node:
        return str(node["simpleText"])
    runs = node.get("runs")
    if isinstance(runs, list):
        return "".join(str(r.get("text", "")) for r in runs if isinstance(r, dict))
    return ""


def _duration(node) -> float:
    raw = _text(node).strip()
    if not raw:
        return 0.0
    parts = raw.split(":")
    try:
        numbers = [int(p) for p in parts]
    except ValueError:
        return 0.0
    seconds = 0.0
    for number in numbers:
        seconds = seconds * 60 + number
    return seconds


def _thumbnail(node) -> str | None:
    thumbs = (node or {}).get("thumbnails")
    if not isinstance(thumbs, list) or not thumbs:
        return None
    best = max(thumbs, key=lambda t: (t.get("width") or 0) if isinstance(t, dict) else 0)
    return best.get("url") if isinstance(best, dict) else None


def _ref_from_renderer(renderer: dict) -> TrackRef | None:
    video_id = renderer.get("videoId")
    if not isinstance(video_id, str) or len(video_id) != 11:
        return None
    # Le nom de l'auteur change de clé selon le type de bloc.
    artist = ""
    for key in ("longBylineText", "shortBylineText", "ownerText", "subtitle"):
        artist = _text(renderer.get(key))
        if artist:
            break
    return TrackRef(
        video_id=video_id,
        title=_text(renderer.get("title")) or "Sans titre",
        artist=artist.split(" • ")[0].strip(),
        duration=_duration(renderer.get("lengthText")),
        thumbnail=_thumbnail(renderer.get("thumbnail")),
    )


def _first_badge_text(node) -> str:
    """Texte du badge de miniature — c'est là que vit la durée."""
    if isinstance(node, dict):
        badge = node.get("thumbnailBadgeViewModel")
        if isinstance(badge, dict) and badge.get("text"):
            return str(badge["text"])
        for value in node.values():
            found = _first_badge_text(value)
            if found:
                return found
    elif isinstance(node, list):
        for value in node:
            found = _first_badge_text(value)
            if found:
                return found
    return ""


def _lockup_thumbnail(node) -> str | None:
    sources = (((node or {}).get("contentImage") or {})
               .get("thumbnailViewModel") or {}).get("image") or {}
    items = sources.get("sources")
    if not isinstance(items, list) or not items:
        return None
    best = max(items, key=lambda s: (s.get("width") or 0) if isinstance(s, dict) else 0)
    return best.get("url") if isinstance(best, dict) else None


def _ref_from_lockup(block: dict) -> TrackRef | None:
    """Convertit un `lockupViewModel`, le format des suggestions depuis 2025.

    YouTube a remplacé `compactVideoRenderer` par ces vues : mêmes données,
    arborescence entièrement différente.
    """
    video_id = block.get("contentId")
    if not isinstance(video_id, str) or len(video_id) != 11:
        return None
    # Le même bloc sert aux playlists et aux chaînes : on ne garde que les vidéos.
    content_type = block.get("contentType") or ""
    if content_type and "VIDEO" not in content_type:
        return None

    meta = (block.get("metadata") or {}).get("lockupMetadataViewModel") or {}
    title = ((meta.get("title") or {}).get("content")) or "Sans titre"

    artist = ""
    rows = (((meta.get("metadata") or {}).get("contentMetadataViewModel") or {})
            .get("metadataRows")) or []
    # La première ligne porte le nom de la chaîne ; les suivantes, vues et date.
    for row in rows:
        parts = (row or {}).get("metadataParts") or []
        for part in parts:
            text = ((part or {}).get("text") or {}).get("content")
            if text:
                artist = str(text)
                break
        if artist:
            break

    return TrackRef(
        video_id=video_id,
        title=str(title),
        artist=artist,
        duration=_duration(_first_badge_text(block)),
        thumbnail=_lockup_thumbnail(block),
    )


# Blocs porteurs d'une vidéo jouable, tous formats de réponse confondus.
_VIDEO_RENDERERS = (
    "compactVideoRenderer",     # colonne « à suivre »
    "videoRenderer",            # résultats de recherche
    "gridVideoRenderer",        # grilles
    "playlistPanelVideoRenderer",  # file de lecture / radio
    "endScreenVideoRenderer",   # écran de fin — repli si les vues changent encore
)


# Blocs publicitaires : ils embarquent un `lockupViewModel` de vidéo
# ordinaire, sans titre. Sans ce filtre, la pub sortait en tête de recherche.
_AD_RENDERERS = frozenset({
    "adSlotRenderer",
    "searchPyvRenderer",
    "promotedSparklesWebRenderer",
    "promotedVideoRenderer",
    "compactPromotedVideoRenderer",
    "inFeedAdLayoutRenderer",
    "adSlotAndLayoutRenderer",
})


def extract_refs(node, seen: set[str] | None = None) -> list[TrackRef]:
    """Parcourt une réponse InnerTube et en tire les pistes, sans doublon."""
    if seen is None:
        seen = set()
    found: list[TrackRef] = []
    if isinstance(node, dict):
        if not _AD_RENDERERS.isdisjoint(node):
            node = {k: v for k, v in node.items() if k not in _AD_RENDERERS}
        lockup = node.get("lockupViewModel")
        if isinstance(lockup, dict):
            ref = _ref_from_lockup(lockup)
            if ref is not None and ref.video_id not in seen:
                seen.add(ref.video_id)
                found.append(ref)
        for name in _VIDEO_RENDERERS:
            renderer = node.get(name)
            if isinstance(renderer, dict):
                ref = _ref_from_renderer(renderer)
                if ref is not None and ref.video_id not in seen:
                    seen.add(ref.video_id)
                    found.append(ref)
        for value in node.values():
            found.extend(extract_refs(value, seen))
    elif isinstance(node, list):
        for value in node:
            found.extend(extract_refs(value, seen))
    return found


class InnerTubeError(RuntimeError):
    pass


class InnerTube:
    """Accès direct à l'API interne de YouTube, en visiteur anonyme."""

    def __init__(self, cookies=None, settings=None,
                 language: str = "fr", region: str = "FR",
                 timeout: float = 20.0) -> None:
        self._cookies = cookies
        self._settings = settings
        self._language = language
        self._region = region
        self._timeout = timeout
        self._lock = threading.Lock()
        self._api_key: str | None = None
        self._client_version: str | None = None
        self._visitor: str | None = None
        self._failed_until = 0.0

    # ---- Identité de visiteur -------------------------------------------

    @property
    def visitor_data(self) -> str | None:
        return self._visitor

    def _stored_visitor(self) -> str | None:
        if self._settings is None:
            return None
        stored = self._settings.get("visitor_data")
        issued = self._settings.get("visitor_data_at") or 0
        if stored and (time.time() - float(issued)) < VISITOR_MAX_AGE:
            return str(stored)
        return None

    def _remember_visitor(self, visitor: str) -> None:
        self._visitor = visitor
        if self._settings is not None:
            self._settings.set("visitor_data", visitor)
            self._settings.set("visitor_data_at", time.time())
            self._settings.save()

    # ---- Amorçage --------------------------------------------------------

    def _fetch(self, url: str) -> str:
        headers = {
            "User-Agent": USER_AGENT,
            "Accept-Language": f"{self._language}-{self._region},{self._language};q=0.9",
        }
        # Les cookies de visiteur portent l'historique qui personnalise l'accueil.
        if self._cookies is not None:
            try:
                header = self._cookies.cookie_header()
            except Exception:
                header = None
            if header:
                headers["Cookie"] = header
        request = urllib.request.Request(url, headers=headers)
        with urlopen_checked(request, self._timeout, ("youtube.com",)) as response:
            return read_capped(response).decode("utf-8", "replace")

    def _ensure_ready(self) -> bool:
        with self._lock:
            if self._api_key and self._client_version and self._visitor:
                return True
            if time.time() < self._failed_until:
                return False
            try:
                html = self._fetch(WEB_HOST + "/")
            except Exception as exc:
                log.warning("Amorçage InnerTube impossible: %s", exc)
                self._failed_until = time.time() + 60
                return False

            key = _RE_API_KEY.search(html)
            version = _RE_CLIENT_VERSION.search(html)
            if not key or not version:
                log.warning("Amorçage InnerTube : page inattendue")
                self._failed_until = time.time() + 300
                return False
            self._api_key = key.group(1)
            self._client_version = version.group(1)

            # Un identifiant déjà connu prime : c'est lui qui porte l'historique.
            visitor = self._stored_visitor()
            if not visitor:
                found = _RE_VISITOR.search(html)
                if not found:
                    self._failed_until = time.time() + 300
                    return False
                visitor = found.group(1)
            self._remember_visitor(visitor)
            return True

    # ---- Appels ----------------------------------------------------------

    def _call(self, endpoint: str, payload: dict) -> dict | None:
        if not self._ensure_ready():
            return None
        body = {
            "context": {
                "client": {
                    "clientName": "WEB",
                    "clientVersion": self._client_version,
                    "hl": self._language,
                    "gl": self._region,
                    "visitorData": self._visitor,
                }
            }
        }
        body.update(payload)
        headers = {
            "User-Agent": USER_AGENT,
            "Content-Type": "application/json",
            "X-Goog-Visitor-Id": self._visitor or "",
            "Origin": WEB_HOST,
            "Referer": WEB_HOST + "/",
        }
        if self._cookies is not None:
            try:
                cookie_header = self._cookies.cookie_header()
            except Exception:
                cookie_header = None
            if cookie_header:
                headers["Cookie"] = cookie_header

        url = f"{WEB_HOST}/youtubei/v1/{endpoint}?key={self._api_key}&prettyPrint=false"
        request = urllib.request.Request(url, data=json.dumps(body).encode("utf-8"),
                                         method="POST", headers=headers)
        try:
            with urlopen_checked(request, self._timeout, ("youtube.com",)) as response:
                return json.loads(read_capped(response).decode("utf-8", "replace"))
        except urllib.error.HTTPError as exc:
            log.info("InnerTube %s : HTTP %s", endpoint, exc.code)
            if exc.code in (400, 403):
                # Session probablement périmée : on réamorcera au prochain appel.
                with self._lock:
                    self._api_key = self._client_version = None
        except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as exc:
            log.info("InnerTube %s indisponible: %s", endpoint, exc)
        return None

    # ---- Recommandations -------------------------------------------------

    def related(self, video_id: str, limit: int = 25) -> list[TrackRef]:
        """Pistes suggérées à la suite d'une vidéo. Marche sans compte."""
        data = self._call("next", {"videoId": video_id})
        if data is None:
            return []
        refs = [r for r in extract_refs(data) if r.video_id != video_id]
        return refs[:limit]

    def home(self, limit: int = 40) -> list[TrackRef]:
        """Accueil personnalisé du visiteur.

        Vide tant que l'identifiant de visiteur n'a pas d'historique : il se
        garnit à mesure que l'app est utilisée, ou tout de suite si des
        cookies de visiteur ont été importés.
        """
        data = self._call("browse", {"browseId": BROWSE_HOME})
        return extract_refs(data)[:limit] if data else []

    def search(self, query: str, limit: int = 25) -> list[TrackRef]:
        data = self._call("search", {"query": query})
        return extract_refs(data)[:limit] if data else []

    def video_length(self, video_id: str) -> float | None:
        """Durée d'une vidéo via `player`. Le flux peut être refusé
        (UNPLAYABLE sans PO Token) : `videoDetails` reste renseigné."""
        data = self._call("player", {"videoId": video_id})
        details = (data or {}).get("videoDetails") or {}
        try:
            seconds = float(details.get("lengthSeconds") or 0)
        except (TypeError, ValueError):
            return None
        return seconds if seconds > 0 else None

    def diagnose(self) -> dict:
        """État de l'accès anonyme, pour le diagnostic."""
        ready = self._ensure_ready()
        return {
            "ready": ready,
            "client_version": self._client_version,
            "visitor": (self._visitor[:16] + "…") if self._visitor else None,
            "visitor_persisted": bool(self._stored_visitor()),
            "cookies": bool(self._cookies is not None
                            and self._cookies.cookie_header()),
        }
