"""Garde-fous réseau.

Les URL manipulées par Triat viennent de réponses d'API (InnerTube, yt-dlp,
SponsorBlock) ou d'une saisie utilisateur. `urllib` accepte des schémas que
l'on ne veut jamais suivre — `file://` lit un fichier local, `ftp://` sort du
périmètre — et une redirection peut viser une adresse interne. Tout ce qui
part sur le réseau passe donc par ici.
"""

from __future__ import annotations

import contextvars
import ipaddress
import re
import socket
import threading
import urllib.error
import urllib.parse
import urllib.request

# Seuls schémas autorisés pour une ressource distante.
SAFE_SCHEMES = ("https", "http")

# Un en-tête HTTP ne doit jamais contenir de saut de ligne : ce serait une
# injection d'en-tête (CWE-113).
_HEADER_FORBIDDEN = re.compile(r"[\r\n\x00]")

# Domaines dont Triat accepte de lire un flux ou une image.
MEDIA_HOST_SUFFIXES = (
    "youtube.com", "youtu.be", "ytimg.com", "ggpht.com",
    "googlevideo.com", "googleusercontent.com", "google.com",
)


class UnsafeURL(ValueError):
    pass


# Noms d'hôtes qui désignent la machine elle-même ou le réseau local.
# `ipaddress` ne les reconnaît pas : ce sont des noms, pas des adresses.
LOCAL_HOSTNAMES = ("localhost", "localhost.localdomain", "ip6-localhost",
                   "ip6-loopback")
LOCAL_SUFFIXES = (".localhost", ".local", ".internal", ".home.arpa")


def _host_is_private(host: str) -> bool:
    """Vrai si l'hôte désigne une adresse locale ou privée."""
    host = host.strip().rstrip(".").lower()
    if host in LOCAL_HOSTNAMES or host.endswith(LOCAL_SUFFIXES):
        return True
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return False
    return (address.is_private or address.is_loopback or address.is_link_local
            or address.is_reserved or address.is_multicast
            or address.is_unspecified)


def check_url(url: str, *, allow_hosts: tuple[str, ...] | None = None,
              block_private: bool = True) -> str:
    """Valide une URL distante, ou lève `UnsafeURL`.

    `allow_hosts` : suffixes de domaine autorisés (None = tous).
    """
    if not isinstance(url, str) or not url:
        raise UnsafeURL("URL vide")
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme.lower() not in SAFE_SCHEMES:
        raise UnsafeURL(f"Schéma refusé : {parsed.scheme or '(aucun)'}")
    host = (parsed.hostname or "").lower()
    if not host:
        raise UnsafeURL("Hôte absent")
    if block_private and _host_is_private(host):
        raise UnsafeURL(f"Adresse interne refusée : {host}")
    if allow_hosts is not None:
        if not any(host == suffix or host.endswith("." + suffix)
                   for suffix in allow_hosts):
            raise UnsafeURL(f"Domaine hors périmètre : {host}")
    return url


def is_safe_url(url: str, **kwargs) -> bool:
    try:
        check_url(url, **kwargs)
    except UnsafeURL:
        return False
    return True


def safe_media_url(url: str) -> str:
    """Valide une URL de média ou d'image issue des API YouTube."""
    return check_url(url, allow_hosts=MEDIA_HOST_SUFFIXES)


def sanitize_headers(headers: dict) -> list[str]:
    """Transforme un dict d'en-têtes en liste `Nom: valeur` pour mpv.

    Toute entrée contenant un saut de ligne est écartée : passée telle
    quelle à mpv, elle permettrait d'injecter des en-têtes arbitraires.
    """
    fields: list[str] = []
    for name, value in (headers or {}).items():
        name, value = str(name), str(value)
        if _HEADER_FORBIDDEN.search(name) or _HEADER_FORBIDDEN.search(value):
            continue
        if not name.strip():
            continue
        fields.append(f"{name}: {value}")
    return fields


def resolve_is_public(host: str) -> bool:
    """Résout un nom et vérifie qu'aucune adresse n'est privée.

    Coûteux (appel DNS) : réservé aux URL d'origine inconnue.
    """
    try:
        infos = socket.getaddrinfo(host, None)
    except OSError:
        return False
    return all(not _host_is_private(info[4][0]) for info in infos)


# Une réponse d'API légitime tient largement dedans ; au-delà, on coupe
# plutôt que de remplir la mémoire avec ce qu'un serveur nous envoie.
# En-tête envoyé quand aucun n'est fourni par ailleurs.
USER_AGENT_FALLBACK = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                       "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")

MAX_RESPONSE_BYTES = 8 * 1024 * 1024


class ResponseTooLarge(ValueError):
    pass


def read_capped(response, limit: int = MAX_RESPONSE_BYTES) -> bytes:
    """Lit une réponse HTTP en refusant de dépasser `limit` octets."""
    data = response.read(limit + 1)
    if len(data) > limit:
        raise ResponseTooLarge(
            f"Réponse tronquée : plus de {limit} octets")
    return data


# ---- Ouverture d'URL avec redirections contrôlées --------------------------

# En-têtes qui ne doivent jamais suivre une redirection vers un autre hôte.
_SECRET_HEADERS = ("cookie", "authorization")


class RedirectRefused(urllib.error.URLError):
    """Redirection vers une destination refusée. Sous-classe de URLError :
    les appelants qui gèrent déjà les erreurs réseau la gèrent aussi."""


# Domaines autorisés pour la requête en cours, lus par le gestionnaire de
# redirections. Une variable de contexte : chaque thread a la sienne.
_ALLOWED: contextvars.ContextVar = contextvars.ContextVar(
    "triat_allowed_hosts", default=None)
_OPENER_READY = False
_OPENER_LOCK = threading.Lock()


class _CheckedRedirect(urllib.request.HTTPRedirectHandler):
    """Revalide chaque saut de redirection.

    `urllib` suit les redirections sans repasser par `check_url`, et
    recopie les en-têtes de la requête — `Cookie` compris — même quand la
    destination change de domaine.
    """

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        newurl = urllib.parse.urljoin(req.full_url, newurl)
        try:
            check_url(newurl, allow_hosts=_ALLOWED.get())
        except UnsafeURL as exc:
            raise RedirectRefused(f"Redirection refusée : {exc}") from exc
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is None:
            return None
        old_host = (urllib.parse.urlsplit(req.full_url).hostname or "").lower()
        new_host = (urllib.parse.urlsplit(newurl).hostname or "").lower()
        if old_host != new_host:
            for name in list(new.headers):
                if name.lower() in _SECRET_HEADERS:
                    del new.headers[name]
            for name in list(new.unredirected_hdrs):
                if name.lower() in _SECRET_HEADERS:
                    del new.unredirected_hdrs[name]
        return new


def _install_opener() -> None:
    """Remplace l'ouvreur global d'urllib, une fois. Seul le code de Triat
    s'en sert : yt-dlp et mpv ont leur propre pile réseau."""
    global _OPENER_READY
    with _OPENER_LOCK:
        if not _OPENER_READY:
            urllib.request.install_opener(
                urllib.request.build_opener(_CheckedRedirect()))
            _OPENER_READY = True


def urlopen_checked(request, timeout: float,
                    allow_hosts: tuple[str, ...] | None = None):
    """`urlopen` qui valide l'URL de départ et chaque redirection."""
    url = request.full_url if isinstance(request, urllib.request.Request) \
        else request
    try:
        check_url(url, allow_hosts=allow_hosts)
    except UnsafeURL as exc:
        raise RedirectRefused(str(exc)) from exc
    _install_opener()
    token = _ALLOWED.set(allow_hosts)
    try:
        return urllib.request.urlopen(request, timeout=timeout)
    finally:
        _ALLOWED.reset(token)
