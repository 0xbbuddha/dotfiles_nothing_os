"""Journalisation : console + fichier tournant, exceptions non gérées.

Lancé depuis Hyprland, Triat n'a pas de terminal : sans fichier, un
plantage ne laisse aucune trace. Le fichier vit dans l'état XDG, en 0600,
et ne contient jamais d'URL de flux ni de cookie (règle de l'audit).
"""

from __future__ import annotations

import logging
import logging.handlers
import os
import sys
import threading

from .paths import state_dir

FORMAT = "%(asctime)s %(levelname)-7s %(name)s: %(message)s"
MAX_BYTES = 1024 * 1024
BACKUPS = 3

log = logging.getLogger("triat")
_done = False


def setup(level: int = logging.INFO, to_file: bool = True) -> None:
    global _done
    if _done:
        return
    _done = True
    root = logging.getLogger()
    root.setLevel(level)
    console = logging.StreamHandler()
    console.setFormatter(logging.Formatter(FORMAT))
    root.addHandler(console)
    if to_file:
        try:
            path = state_dir() / "triat.log"
            handler = logging.handlers.RotatingFileHandler(
                path, maxBytes=MAX_BYTES, backupCount=BACKUPS,
                encoding="utf-8")
            os.chmod(path, 0o600)
            handler.setFormatter(logging.Formatter(FORMAT))
            root.addHandler(handler)
        except OSError as exc:
            log.warning("Journal fichier indisponible : %s", exc)
    _install_hooks()


def _install_hooks() -> None:
    previous = sys.excepthook

    def excepthook(kind, value, traceback) -> None:
        # PyGObject passe aussi par ici pour une exception levée dans un
        # rappel GTK : elle est journalisée, l'application continue.
        if issubclass(kind, KeyboardInterrupt):
            previous(kind, value, traceback)
            return
        log.critical("Exception non gérée", exc_info=(kind, value, traceback))

    def thread_hook(args) -> None:
        if args.exc_type is SystemExit:
            return
        log.critical("Exception dans le thread %s",
                     getattr(args.thread, "name", "?"),
                     exc_info=(args.exc_type, args.exc_value,
                               args.exc_traceback))

    sys.excepthook = excepthook
    threading.excepthook = thread_hook
