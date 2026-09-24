"""Spectre audio en direct, lu depuis cava.

cava capture la sortie son du système (PipeWire/Pulse) et écrit, en mode
brut, une ligne de hauteurs de barres par image. On ne le lance que pendant
l'écran Immersion : hors de là, aucun processus, aucun coût.

Absent du système → `available` est faux et l'écran reste statique.
"""

from __future__ import annotations

import atexit
import logging
import shutil
import subprocess
import threading

from gi.repository import GLib

from .paths import runtime_dir

log = logging.getLogger(__name__)

BARS = 24
FRAMERATE = 30
MAX_RANGE = 100

CONFIG = f"""
[general]
bars = {BARS}
framerate = {FRAMERATE}
autosens = 1

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = {MAX_RANGE}
bar_delimiter = 59
frame_delimiter = 10
channels = mono

[smoothing]
noise_reduction = 70
"""


def parse_frame(line: str) -> list[float] | None:
    """« 12;40;0; » → [0.12, 0.4, 0.0]. Ligne incomplète → None."""
    parts = [p for p in line.strip().split(";") if p != ""]
    if len(parts) != BARS:
        return None
    try:
        return [max(0.0, min(1.0, int(p) / MAX_RANGE)) for p in parts]
    except ValueError:
        return None


# Processus cava vivants, arrêtés à la sortie normale de Python même si
# l'écran Immersion n'a pas été refermé proprement.
_LIVE: set = set()


@atexit.register
def _stop_all() -> None:
    for proc in list(_LIVE):
        try:
            proc.terminate()
        except OSError:
            pass


class Spectrum:
    def __init__(self) -> None:
        self._proc: subprocess.Popen | None = None
        self._callback = None
        self._pending = False
        self._latest: list[float] | None = None

    @property
    def available(self) -> bool:
        return shutil.which("cava") is not None

    @property
    def running(self) -> bool:
        return self._proc is not None and self._proc.poll() is None

    def start(self, callback) -> bool:
        """`callback(levels)` est appelé dans le thread principal."""
        if self.running:
            self._callback = callback
            return True
        binary = shutil.which("cava")
        if binary is None:
            return False
        config = runtime_dir() / "cava.conf"
        config.write_text(CONFIG, encoding="utf-8")
        command = [binary, "-p", str(config)]
        # Si Triat meurt sans prévenir (plantage, kill -9), le noyau tue cava
        # avec lui : sinon il continuerait d'écouter la sortie son du système.
        setpriv = shutil.which("setpriv")
        if setpriv is not None:
            command = [setpriv, "--pdeathsig", "TERM", "--", *command]
        try:
            self._proc = subprocess.Popen(
                command, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                text=True, bufsize=1)
        except OSError as exc:
            log.info("cava ne démarre pas : %s", exc)
            self._proc = None
            return False
        _LIVE.add(self._proc)
        self._callback = callback
        threading.Thread(target=self._read, args=(self._proc,),
                         daemon=True).start()
        return True

    def stop(self) -> None:
        proc, self._proc = self._proc, None
        if proc is not None:
            _LIVE.discard(proc)
        self._callback = None
        if proc is None:
            return
        proc.terminate()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()

    def _read(self, proc: subprocess.Popen) -> None:
        for line in proc.stdout:
            levels = parse_frame(line)
            if levels is None:
                continue
            self._latest = levels
            # Une seule image en attente : si l'UI prend du retard, on
            # saute des images au lieu d'empiler des appels.
            if not self._pending:
                self._pending = True
                GLib.idle_add(self._deliver)

    def _deliver(self) -> bool:
        self._pending = False
        if self._callback is not None and self._latest is not None:
            self._callback(self._latest)
        return GLib.SOURCE_REMOVE
