"""Scrobbling ListenBrainz (TODO §4.13).

ListenBrainz plutôt que Last.fm : l'API est ouverte, un simple jeton
utilisateur suffit, et les données restent exportables. Le jeton est traité
comme un secret — trousseau système, jamais en clair.

Les envois sont différés et non bloquants : une panne du service ne doit
jamais gêner la lecture.
"""

from __future__ import annotations

import json
import logging
import threading
import time
import urllib.error
import urllib.request

import keyring
import keyring.errors

from .net import USER_AGENT_FALLBACK, read_capped, urlopen_checked

log = logging.getLogger(__name__)

API = "https://api.listenbrainz.org/1"
KEYRING_SERVICE = "triat"
KEYRING_KEY = "listenbrainz-token"
TIMEOUT = 10.0

# Règles ListenBrainz : une écoute compte au-delà de 4 minutes ou de la
# moitié de la piste, et une piste de moins de 30 s ne compte pas.
MIN_TRACK_SECONDS = 30.0
HALF_OR_FOUR_MINUTES = 240.0


class ScrobbleError(RuntimeError):
    pass


def should_submit(played: float, duration: float) -> bool:
    """Vrai si l'écoute mérite d'être déclarée."""
    if duration and duration < MIN_TRACK_SECONDS:
        return False
    if played < 30.0:
        return False
    if not duration:
        return played >= HALF_OR_FOUR_MINUTES
    return played >= min(duration / 2, HALF_OR_FOUR_MINUTES)


class Scrobbler:
    """Client ListenBrainz. Ne lève jamais pendant la lecture."""

    def __init__(self, settings=None) -> None:
        self._settings = settings

    # ---- Jeton -----------------------------------------------------------

    @property
    def token(self) -> str | None:
        try:
            return keyring.get_password(KEYRING_SERVICE, KEYRING_KEY)
        except Exception as exc:
            log.warning("Jeton ListenBrainz illisible : %s", exc)
            return None

    @property
    def enabled(self) -> bool:
        if self._settings is not None and not self._settings.get("scrobble_enabled"):
            return False
        return bool(self.token)

    def set_token(self, token: str) -> str:
        """Enregistre le jeton après l'avoir validé. Renvoie le nom d'utilisateur."""
        token = (token or "").strip()
        if not token:
            raise ScrobbleError("Jeton vide")
        name = self.validate(token)
        try:
            keyring.set_password(KEYRING_SERVICE, KEYRING_KEY, token)
        except Exception as exc:
            raise ScrobbleError(f"Écriture dans le trousseau impossible : {exc}") from exc
        if self._settings is not None:
            self._settings.set("scrobble_user", name)
            self._settings.set("scrobble_enabled", True)
            self._settings.save()
        return name

    def clear(self) -> None:
        try:
            keyring.delete_password(KEYRING_SERVICE, KEYRING_KEY)
        except keyring.errors.PasswordDeleteError:
            pass
        except Exception as exc:
            log.warning("Suppression du jeton impossible : %s", exc)
        if self._settings is not None:
            self._settings.set("scrobble_user", "")
            self._settings.set("scrobble_enabled", False)
            self._settings.save()

    def validate(self, token: str) -> str:
        """Vérifie le jeton et renvoie le nom d'utilisateur associé."""
        request = urllib.request.Request(
            f"{API}/validate-token",
            headers={"Authorization": f"Token {token}",
                     "User-Agent": USER_AGENT_FALLBACK})
        try:
            with urlopen_checked(request, TIMEOUT, ("listenbrainz.org",)) as response:
                payload = json.loads(read_capped(response).decode("utf-8", "replace"))
        except urllib.error.HTTPError as exc:
            raise ScrobbleError(
                "Jeton refusé" if exc.code in (401, 403)
                else f"ListenBrainz a répondu {exc.code}") from exc
        except Exception as exc:
            raise ScrobbleError(f"ListenBrainz injoignable : {exc}") from exc
        if not payload.get("valid"):
            raise ScrobbleError("Jeton refusé")
        return payload.get("user_name") or "inconnu"

    # ---- Envois ----------------------------------------------------------

    @staticmethod
    def _metadata(ref) -> dict:
        data = {
            "artist_name": (ref.artist or "").strip() or "Inconnu",
            "track_name": (ref.title or "").strip() or "Inconnu",
        }
        if getattr(ref, "album", None):
            data["release_name"] = ref.album
        data["additional_info"] = {
            "media_player": "Triat",
            "submission_client": "Triat",
            "music_service": "youtube.com",
            "origin_url": ref.url,
        }
        return data

    def _post(self, body: dict) -> None:
        token = self.token
        if not token:
            return
        request = urllib.request.Request(
            f"{API}/submit-listens",
            data=json.dumps(body).encode("utf-8"),
            method="POST",
            headers={"Authorization": f"Token {token}",
                     "Content-Type": "application/json",
                     "User-Agent": USER_AGENT_FALLBACK})
        try:
            with urlopen_checked(request, TIMEOUT, ("listenbrainz.org",)) as response:
                response.read(1024)
        except Exception as exc:
            log.info("Envoi ListenBrainz échoué : %s", exc)

    def _post_async(self, body: dict) -> None:
        threading.Thread(target=self._post, args=(body,), daemon=True).start()

    def now_playing(self, ref) -> None:
        """Signale la piste en cours, sans l'enregistrer."""
        if not self.enabled or ref is None:
            return
        self._post_async({
            "listen_type": "playing_now",
            "payload": [{"track_metadata": self._metadata(ref)}],
        })

    def submit(self, ref, played: float, duration: float) -> bool:
        """Déclare une écoute terminée. Renvoie False si elle ne compte pas."""
        if not self.enabled or ref is None:
            return False
        if not should_submit(played, duration or getattr(ref, "duration", 0)):
            return False
        self._post_async({
            "listen_type": "single",
            "payload": [{
                "listened_at": int(time.time()),
                "track_metadata": self._metadata(ref),
            }],
        })
        return True
