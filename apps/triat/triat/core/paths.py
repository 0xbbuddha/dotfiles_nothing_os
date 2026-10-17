"""Emplacements XDG de l'application."""

from __future__ import annotations

import os
from pathlib import Path

APP_NAME = "triat"
LEGACY_APP_NAMES = ("rien", "musicapp")   # noms précédents du paquet


def _xdg(var: str, default: Path) -> Path:
    raw = os.environ.get(var)
    base = Path(raw) if raw else default
    path = base / APP_NAME
    # L'application s'appelait « musicapp » : on récupère les données
    # existantes plutôt que de repartir d'une bibliothèque vide.
    if not path.exists():
        for previous in LEGACY_APP_NAMES:
            legacy = base / previous
            if legacy.is_dir():
                try:
                    legacy.rename(path)
                except OSError:
                    pass
                break
    return path


def data_dir() -> Path:
    path = _xdg("XDG_DATA_HOME", Path.home() / ".local" / "share")
    path.mkdir(parents=True, exist_ok=True)
    path.chmod(0o700)
    return path


def config_dir() -> Path:
    path = _xdg("XDG_CONFIG_HOME", Path.home() / ".config")
    path.mkdir(parents=True, exist_ok=True)
    path.chmod(0o700)
    return path


def cache_dir() -> Path:
    path = _xdg("XDG_CACHE_HOME", Path.home() / ".cache")
    path.mkdir(parents=True, exist_ok=True)
    return path


def state_dir() -> Path:
    """Journaux : ni configuration ni cache (spécification XDG)."""
    path = _xdg("XDG_STATE_HOME", Path.home() / ".local" / "state")
    path.mkdir(parents=True, exist_ok=True)
    path.chmod(0o700)
    return path


def runtime_dir() -> Path:
    """Tmpfs en RAM, effacé à la déconnexion. Pour les secrets déchiffrés."""
    raw = os.environ.get("XDG_RUNTIME_DIR")
    base = Path(raw) if raw else cache_dir()
    path = base / APP_NAME
    path.mkdir(parents=True, exist_ok=True)
    path.chmod(0o700)
    return path


def db_path() -> Path:
    return data_dir() / "library.db"


def downloads_dir() -> Path:
    raw = os.environ.get("XDG_MUSIC_DIR")
    base = Path(raw) if raw else Path.home() / "Musique"
    return base / "Triat"
