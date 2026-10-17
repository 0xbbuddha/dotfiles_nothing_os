"""Patch de la barre Quickshell (packaging/nothing-os/quickshell)."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "packaging/nothing-os/quickshell/install_bar.py"

REGISTRY = '''    readonly property var all: [
        { id: "apps", label: "Essential Apps" },
        { id: "clock",      label: "Clock" },
    ]
'''
SLOT = '''    readonly property bool applies: {
        case "essential": return Config.essentialEnabled;
    }
    function part() {
        case "essential":  return essentialPart;
    }
    // ── Clock ─────
'''


def load(tmp_path):
    spec = importlib.util.spec_from_file_location("install_bar", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    shell = tmp_path / "nothing"
    (shell / "components/bar").mkdir(parents=True)
    (shell / "components/BarRegistry.qml").write_text(REGISTRY)
    (shell / "components/bar/BarSlot.qml").write_text(SLOT)
    config = tmp_path / "config.json"
    config.write_text(json.dumps({"barCentre": ["apps", "clock"], "barLeft": []}))
    module.SHELL, module.CONFIG = shell, config
    return module, shell, config


def test_install_is_idempotent_and_removable(tmp_path):
    module, shell, config = load(tmp_path)
    module.install()
    module.install()
    slot = (shell / "components/bar/BarSlot.qml").read_text()
    assert slot.count("triatPart") == 2          # aiguillage + composant
    assert (shell / "components/BarRegistry.qml").read_text().count('id: "triat"') == 1
    assert json.loads(config.read_text())["barCentre"] == ["apps", "clock", "triat"]
    assert (shell / "components/bar/TriatBarItem.qml").exists()

    module.remove()
    assert (shell / "components/bar/BarSlot.qml").read_text() == SLOT
    assert (shell / "components/BarRegistry.qml").read_text() == REGISTRY
    assert json.loads(config.read_text())["barCentre"] == ["apps", "clock"]
    assert not (shell / "components/bar/TriatBarItem.qml").exists()


def test_desktop_entry_launches_triat():
    entry = (ROOT / "packaging/flatpak/org.triat.Triat.desktop").read_text()
    assert "Exec=triat %U" in entry and "StartupWMClass=org.triat.Triat" in entry
    assert (ROOT / "data/icons/hicolor/scalable/apps/org.triat.Triat.svg").exists()


def test_mpris_bus_matches_bar_and_keybinds():
    from triat.services import mpris
    assert mpris.BUS_NAME == "org.mpris.MediaPlayer2.triat"
    qml = (ROOT / "packaging/nothing-os/quickshell/TriatBarItem.qml").read_text()
    assert "MediaPlayer2.triat" in qml
    lua = (ROOT / "packaging/nothing-os/triat.lua").read_text()
    assert "--player=triat" in lua and "rien" not in lua.replace("sans rien", "")


def test_focus_needs_hyprland(monkeypatch):
    from triat.core import desktop
    monkeypatch.delenv("HYPRLAND_INSTANCE_SIGNATURE", raising=False)
    assert desktop.focus_under_hyprland("org.triat.Triat") is False


class _Win:
    def __init__(self):
        self.visible = True

    def set_visible(self, value):
        self.visible = value

    def close_immersion(self):
        pass


class _Eng:
    def __init__(self, current):
        self.current = current
        self.saved = False
        self.stopped = False

    def save_state(self):
        self.saved = True

    def shutdown(self):
        self.stopped = True


def test_closing_the_window_keeps_music_playing():
    from triat.app import TriatApp
    app = TriatApp()
    win, eng = _Win(), _Eng(current=object())
    app._window, app._engine = win, eng
    assert app._on_close(win) is True           # fermeture interceptée
    assert win.visible is False and eng.saved and not eng.stopped


def test_closing_with_nothing_loaded_quits():
    from triat.app import TriatApp
    app = TriatApp()
    win, eng = _Win(), _Eng(current=None)
    app._window, app._engine = win, eng
    assert app._on_close(win) is False
    assert eng.stopped
