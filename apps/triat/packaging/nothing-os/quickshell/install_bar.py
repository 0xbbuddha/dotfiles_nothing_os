#!/usr/bin/env python3
"""Ajoute Triat à la barre Quickshell des dotfiles Nothing OS.

Idempotent : relancé, il ne change rien. Chaque fichier modifié est
sauvegardé en .bak-<date>. `--remove` retire ce qui a été posé.

  - components/bar/TriatBarItem.qml   le module (copié tel quel)
  - components/BarRegistry.qml        une entrée « triat » au catalogue
  - components/bar/BarSlot.qml        deux lignes dans les aiguillages
  - ~/.config/nothing/config.json     « triat » dans l'îlot central
"""

from __future__ import annotations

import json
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SHELL = Path.home() / ".config/quickshell/nothing"
CONFIG = Path.home() / ".config/nothing/config.json"
STAMP = time.strftime("%Y%m%d-%H%M%S")

REGISTRY_ANCHOR = '        { id: "clock",'
REGISTRY_ENTRY = (
    '        { id: "triat",      label: "Triat",       icon: "󰝚", zone: "centre",\n'
    '          hint: "Lecteur Triat : ouvrir, pause, suivante", wide: true },\n'
)
APPLIES_ANCHOR = '        case "essential": return Config.essentialEnabled;\n'
APPLIES_LINE = '        case "triat":     return true;\n'
PART_ANCHOR = '        case "essential":  return essentialPart;\n'
PART_LINE = '        case "triat":      return triatPart;\n'
COMPONENT_ANCHOR = "    // ── Clock ─"
COMPONENT = (
    "    // ── Triat ─────────────────────────────────────────────────────────\n"
    "    // Lecteur Triat (TriatBarItem.qml, posé par son script d'installation).\n"
    "    Component {\n"
    "        id: triatPart\n"
    "        TriatBarItem {}\n"
    "    }\n\n"
)


def info(text: str) -> None:
    print(f"  {text}")


def backup(path: Path) -> None:
    if path.exists():
        shutil.copy2(path, path.with_name(f"{path.name}.bak-{STAMP}"))


def insert_before(text: str, anchor: str, addition: str) -> str:
    index = text.find(anchor)
    if index < 0:
        raise SystemExit(f"repère introuvable : {anchor.strip()!r} — "
                         "les dotfiles ont changé, ajout manuel nécessaire")
    return text[:index] + addition + text[index:]


def insert_after(text: str, anchor: str, addition: str) -> str:
    index = text.find(anchor)
    if index < 0:
        raise SystemExit(f"repère introuvable : {anchor.strip()!r}")
    end = index + len(anchor)
    return text[:end] + addition + text[end:]


def install() -> None:
    if not SHELL.is_dir():
        info(f"Quickshell absent ({SHELL}) : barre ignorée")
        return
    target = SHELL / "components/bar/TriatBarItem.qml"
    shutil.copy2(HERE / "TriatBarItem.qml", target)
    info(f"module : {target}")

    registry = SHELL / "components/BarRegistry.qml"
    text = registry.read_text()
    if 'id: "triat"' not in text:
        backup(registry)
        registry.write_text(insert_before(text, REGISTRY_ANCHOR, REGISTRY_ENTRY))
        info("catalogue : entrée « triat » ajoutée")

    slot = SHELL / "components/bar/BarSlot.qml"
    text = slot.read_text()
    if "triatPart" not in text:
        backup(slot)
        text = insert_after(text, APPLIES_ANCHOR, APPLIES_LINE)
        text = insert_after(text, PART_ANCHOR, PART_LINE)
        text = insert_before(text, COMPONENT_ANCHOR, COMPONENT)
        slot.write_text(text)
        info("BarSlot : module branché")

    if CONFIG.exists():
        data = json.loads(CONFIG.read_text())
        zones = [data.get(k) or [] for k in ("barLeft", "barCentre", "barRight")]
        if not any("triat" in zone for zone in zones):
            backup(CONFIG)
            centre = list(data.get("barCentre") or [])
            # Juste après l'horloge : le centre de l'îlot reste lisible.
            at = centre.index("clock") + 1 if "clock" in centre else len(centre)
            centre.insert(at, "triat")
            data["barCentre"] = centre
            CONFIG.write_text(json.dumps(data, ensure_ascii=False, indent=4) + "\n")
            info("barre : « triat » placé dans l'îlot central")


def remove() -> None:
    target = SHELL / "components/bar/TriatBarItem.qml"
    for path, lines in (
        (SHELL / "components/BarRegistry.qml", [REGISTRY_ENTRY]),
        (SHELL / "components/bar/BarSlot.qml", [APPLIES_LINE, PART_LINE, COMPONENT]),
    ):
        if path.exists():
            text = path.read_text()
            new = text
            for line in lines:
                new = new.replace(line, "")
            if new != text:
                backup(path)
                path.write_text(new)
    if CONFIG.exists():
        data = json.loads(CONFIG.read_text())
        changed = False
        for key in ("barLeft", "barCentre", "barRight"):
            if "triat" in (data.get(key) or []):
                data[key] = [i for i in data[key] if i != "triat"]
                changed = True
        if changed:
            backup(CONFIG)
            CONFIG.write_text(json.dumps(data, ensure_ascii=False, indent=4) + "\n")
    target.unlink(missing_ok=True)
    info("barre : Triat retiré")


if __name__ == "__main__":
    remove() if "--remove" in sys.argv[1:] else install()
