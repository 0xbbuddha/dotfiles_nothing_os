"""Réglages persistants, sauvegardés en JSON de façon atomique."""

from __future__ import annotations

import json
import logging
import os
import threading
from typing import Any

from .paths import config_dir

log = logging.getLogger(__name__)

DEFAULTS: dict[str, Any] = {
    "volume": 85.0,
    "repeat": "off",              # off | all | one
    "shuffle": False,
    "autoplay_radio": True,       # enchaîner sur une radio quand la file se vide
    "audio_quality": "high",      # low | normal | high | max
    "sponsorblock_enabled": True,
    "sponsorblock_categories": {
        "music_offtopic": "skip",
        "sponsor": "skip",
        "selfpromo": "skip",
        "interaction": "skip",
        "intro": "ask",
        "outro": "skip",
        "preview": "ignore",
        "filler": "ignore",
    },
    "scrobble_after_ratio": 0.5,  # part de la piste écoutée avant historisation
    "private_session": False,
    "last_queue": [],
    "last_index": 0,
    "last_position": 0.0,
    "cookie_source": None,        # None | {"kind": "file"|"browser", ...}
    # Accorde l'accent à celui du bureau Nothing OS quand il est détecté.
    "follow_desktop_accent": True,
    "scrobble_enabled": False,   # ListenBrainz
    "scrobble_user": "",
    "normalise_volume": True,    # égalise le volume perçu entre pistes
    "onboarding_done": False,    # écran de bienvenue déjà passé
    "download_format": "opus",          # opus | m4a | mp3
    "download_cut_sponsorblock": True,  # retirer les segments du fichier
    "immersion_mode": "clip",   # clip | glyph
    "search_history": [],       # dernières requêtes, la plus récente d'abord
    "eq_enabled": False,
    "eq_gains": [0.0] * 10,      # dB par bande, voir core/equalizer.py
}


# Valeurs permises pour les réglages à choix fermé.
CHOICES: dict[str, tuple] = {
    "repeat": ("off", "all", "one"),
    "audio_quality": ("low", "normal", "high", "max"),
    "download_format": ("opus", "m4a", "mp3"),
    "immersion_mode": ("clip", "glyph"),
}
RANGES: dict[str, tuple[float, float]] = {
    "volume": (0.0, 100.0),
    "scrobble_after_ratio": (0.0, 1.0),
    "last_position": (0.0, 1e7),
}
POLICIES = ("skip", "ask", "ignore")


def _valid(key: str, value: Any) -> bool:
    """Vrai si `value` a le type et la plage attendus pour `key`.

    Le fichier est éditable à la main et peut être tronqué par un disque
    plein : une valeur aberrante ne doit jamais empêcher le démarrage.
    """
    default = DEFAULTS[key]
    if key in CHOICES:
        return value in CHOICES[key]
    if key == "cookie_source":
        return value is None or isinstance(value, dict)
    if isinstance(default, bool):
        return isinstance(value, bool)
    if isinstance(default, (int, float)):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return False
        if value != value:                      # NaN
            return False
        low, high = RANGES.get(key, (float("-inf"), float("inf")))
        return low <= value <= high
    return isinstance(value, type(default))


class Settings:
    def __init__(self, path=None) -> None:
        self._path = path or (config_dir() / "settings.json")
        self._lock = threading.Lock()
        self._data: dict[str, Any] = dict(DEFAULTS)
        self.load()

    def load(self) -> None:
        try:
            raw = self._path.read_text(encoding="utf-8")
        except FileNotFoundError:
            return
        except OSError as exc:
            log.warning("Lecture des réglages impossible: %s", exc)
            return
        try:
            stored = json.loads(raw)
        except json.JSONDecodeError as exc:
            log.warning("Réglages corrompus, valeurs par défaut utilisées: %s", exc)
            return
        if not isinstance(stored, dict):
            log.warning("Réglages illisibles, valeurs par défaut utilisées")
            return
        # Une clé inconnue d'une version future survit ; une clé connue mais
        # invalide retombe sur sa valeur par défaut, sans bloquer le reste.
        merged = dict(DEFAULTS)
        for key, value in stored.items():
            if key not in DEFAULTS:
                merged[key] = value
            elif _valid(key, value):
                merged[key] = value
            else:
                log.warning("Réglage « %s » invalide, valeur par défaut", key)
        cats = dict(DEFAULTS["sponsorblock_categories"])
        stored_cats = stored.get("sponsorblock_categories")
        if isinstance(stored_cats, dict):
            cats.update({k: v for k, v in stored_cats.items()
                         if isinstance(k, str) and v in POLICIES})
        merged["sponsorblock_categories"] = cats
        self._data = merged

    def save(self) -> None:
        with self._lock:
            tmp = self._path.with_suffix(".json.tmp")
            payload = json.dumps(self._data, indent=2, ensure_ascii=False)
            try:
                tmp.write_text(payload, encoding="utf-8")
                tmp.chmod(0o600)
                os.replace(tmp, self._path)   # atomique
            except OSError as exc:
                log.warning("Écriture des réglages impossible: %s", exc)

    def get(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, DEFAULTS.get(key, default))

    def set(self, key: str, value: Any) -> None:
        self._data[key] = value

    def update(self, **kwargs: Any) -> None:
        self._data.update(kwargs)

    def as_dict(self) -> dict[str, Any]:
        return dict(self._data)
