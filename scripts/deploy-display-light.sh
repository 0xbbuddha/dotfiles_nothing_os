#!/usr/bin/env bash
# Targeted deploy of the SUPER+P Light page (monitor brightness over DDC/CI,
# night light, software dim), Settings > Input and Sound, the Power /
# Displays sections of Settings > Screen and settings backups, into an already installed Nothing rice.
#
# Unlike install-config.sh this replaces no directory: it copies the dozen
# files the feature touches, one by one, after copying each one it would
# overwrite into a dated backup folder, and writes a rollback script there.
# custom.lua, displays.lua, monitors and everything else you changed by
# hand are not touched. No sudo, no packages, no session changes.
#
#   scripts/deploy-display-light.sh            # check, back up, copy
#   scripts/deploy-display-light.sh --dry-run  # say what it would do
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/nothing/backups/display-light-$STAMP"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

QS="$CONF/quickshell/nothing"
HY="$CONF/hypr/hyprland"

# repo path -> installed path
FILES=(
    "quickshell/nothing/services/Ddc.qml:$QS/services/Ddc.qml"
    "quickshell/nothing/services/NightLight.qml:$QS/services/NightLight.qml"
    "quickshell/nothing/services/Displays.qml:$QS/services/Displays.qml"
    "quickshell/nothing/services/Shortcuts.qml:$QS/services/Shortcuts.qml"
    "quickshell/nothing/modules/DisplayLight.qml:$QS/modules/DisplayLight.qml"
    "quickshell/nothing/modules/DisplayPanel.qml:$QS/modules/DisplayPanel.qml"
    "quickshell/nothing/modules/SettingsPageScreen.qml:$QS/modules/SettingsPageScreen.qml"
    "quickshell/nothing/Config.qml:$QS/Config.qml"
    "quickshell/nothing/GlobalState.qml:$QS/GlobalState.qml"
    "quickshell/nothing/shell.qml:$QS/shell.qml"
    "hypr/hyprland/keybinds.lua:$HY/keybinds.lua"
    "quickshell/nothing/services/Input.qml:$QS/services/Input.qml"
    "quickshell/nothing/services/PowerProfile.qml:$QS/services/PowerProfile.qml"
    "quickshell/nothing/services/SettingsIndex.qml:$QS/services/SettingsIndex.qml"
    "quickshell/nothing/modules/SettingsPageInput.qml:$QS/modules/SettingsPageInput.qml"
    "quickshell/nothing/modules/Settings.qml:$QS/modules/Settings.qml"
    "hypr/hyprland/general.lua:$HY/general.lua"
    "quickshell/nothing/services/Audio.qml:$QS/services/Audio.qml"
    "quickshell/nothing/services/ConfigBackup.qml:$QS/services/ConfigBackup.qml"
    "quickshell/nothing/components/SinkList.qml:$QS/components/SinkList.qml"
    "quickshell/nothing/modules/SettingsPageSound.qml:$QS/modules/SettingsPageSound.qml"
    "quickshell/nothing/modules/SettingsPageAbout.qml:$QS/modules/SettingsPageAbout.qml"
    "quickshell/nothing/services/Autostart.qml:$QS/services/Autostart.qml"
    "quickshell/nothing/components/CcRegistry.qml:$QS/components/CcRegistry.qml"
    "quickshell/nothing/components/cc/CcTile.qml:$QS/components/cc/CcTile.qml"
    "quickshell/nothing/components/BarRegistry.qml:$QS/components/BarRegistry.qml"
    "quickshell/nothing/components/bar/BarSlot.qml:$QS/components/bar/BarSlot.qml"
    "quickshell/nothing/services/MimeDefaults.qml:$QS/services/MimeDefaults.qml"
    "quickshell/nothing/services/Drives.qml:$QS/services/Drives.qml"
    "quickshell/nothing/services/Processes.qml:$QS/services/Processes.qml"
    "quickshell/nothing/services/Search.qml:$QS/services/Search.qml"
    "quickshell/nothing/modules/SettingsPageProcesses.qml:$QS/modules/SettingsPageProcesses.qml"
    "quickshell/nothing/modules/SettingsPageDock.qml:$QS/modules/SettingsPageDock.qml"
    "quickshell/nothing/modules/ControlCenter.qml:$QS/modules/ControlCenter.qml"
    "quickshell/nothing/services/AudioRoutes.qml:$QS/services/AudioRoutes.qml"
    "quickshell/nothing/components/AppMixer.qml:$QS/components/AppMixer.qml"
    "quickshell/nothing/modules/Screensaver.qml:$QS/modules/Screensaver.qml"
    "quickshell/nothing/services/Idle.qml:$QS/services/Idle.qml"
    "quickshell/nothing/services/Phone.qml:$QS/services/Phone.qml"
    "quickshell/nothing/modules/SettingsPageNet.qml:$QS/modules/SettingsPageNet.qml"
    "scripts/mime-defaults.py:$CONF/scripts/mime-defaults.py"
    "scripts/open-default.sh:$CONF/scripts/open-default.sh"
    "scripts/procs.py:$CONF/scripts/procs.py"
)

say() { printf '%s\n' "$*"; }
die() { printf 'deploy-display-light: %s\n' "$*" >&2; exit 1; }

# ── Is Nothing the rice actually in use? ─────────────────────────────
[[ -d "$QS" ]] || die "$QS does not exist: Nothing is not installed here. Use ./install (read it first)."
[[ -L "$QS" ]] && die "$QS is a symlink to $(readlink -f "$QS"); update that checkout instead."
[[ -f "$CONF/hypr/hyprland.lua" ]] || die "$CONF/hypr/hyprland.lua missing: Hyprland is not on this rice's Lua config."
if pgrep -af 'q(uick)?s(hell)? .*quickshell/nothing' >/dev/null 2>&1; then
    say "Nothing shell is running: $(pgrep -af 'q(uick)?s(hell)? .*quickshell/nothing' | head -1)"
else
    say "warning: no running Nothing shell found; files are copied, nothing is started."
fi

# An installed file that differs from the repo's *previous* version was
# edited by hand. Overwriting it would lose that, so stop and say so.
BASE="$(git -C "$ROOT" merge-base HEAD origin/main 2>/dev/null || git -C "$ROOT" rev-list --max-parents=0 HEAD | tail -1)"
edited=()
for pair in "${FILES[@]}"; do
    src=${pair%%:*}; dst=${pair#*:}
    [[ -f "$dst" ]] || continue
    if old="$(git -C "$ROOT" show "$BASE:$src" 2>/dev/null)"; then
        if ! diff -q <(printf '%s\n' "$old") "$dst" >/dev/null 2>&1 \
           && ! diff -q "$ROOT/$src" "$dst" >/dev/null 2>&1; then
            edited+=("$dst")
        fi
    fi
done
if (( ${#edited[@]} )); then
    say "These installed files differ from the upstream version they would replace:"
    printf '  %s\n' "${edited[@]}"
    say "(edited by hand, or installed from another revision). They are still backed up,"
    say "but review them: diff <file> against $ROOT before going on."
    [[ "${FORCE:-0}" == 1 ]] || die "stopping. Re-run with FORCE=1 once reviewed."
fi

# ── SUPER+ALT+B must be free ──────────────────────────────────────────
if command -v hyprctl >/dev/null 2>&1 && hyprctl -j binds >/dev/null 2>&1; then
    # modmask 72 = SUPER(64) + ALT(8)
    hit="$(hyprctl -j binds | python3 -c '
import json,sys
for b in json.load(sys.stdin):
    if b.get("modmask")==72 and b.get("key","").lower()=="b":
        print(b.get("dispatcher",""), b.get("arg",""))' || true)"
    if [[ -n "$hit" && "$hit" != *nightlight* ]]; then
        die "SUPER+ALT+B is already bound ($hit). Change the new bind in hypr/hyprland/keybinds.lua first."
    fi
fi

# ── Back up, then copy ────────────────────────────────────────────────
(( DRY )) && say "dry run: nothing is written"
(( DRY )) || mkdir -p "$BACKUP"
ROLLBACK="$BACKUP/rollback.sh"
(( DRY )) || { printf '#!/usr/bin/env bash\n# Undo deploy-display-light.sh of %s\nset -e\n' "$STAMP" > "$ROLLBACK"; }

for pair in "${FILES[@]}"; do
    src=${pair%%:*}; dst=${pair#*:}
    [[ -f "$ROOT/$src" ]] || die "missing in repo: $src"
    if [[ -f "$dst" ]] && diff -q "$ROOT/$src" "$dst" >/dev/null 2>&1; then
        say "  same     $dst"
        continue
    fi
    if (( DRY )); then
        say "  would copy $src -> $dst"
        continue
    fi
    rel="${dst#$CONF/}"
    if [[ -f "$dst" ]]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$dst" "$BACKUP/$rel"
        printf 'cp -a %q %q\n' "$BACKUP/$rel" "$dst" >> "$ROLLBACK"
    else
        printf 'rm -f %q\n' "$dst" >> "$ROLLBACK"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$ROOT/$src" "$dst.tmp-$STAMP" && mv "$dst.tmp-$STAMP" "$dst"
    say "  updated  $dst"
done

if (( ! DRY )); then
    # config.json is not touched: the new keys take their defaults (all off)
    # until changed in the panel. A copy is kept anyway.
    [[ -f "$CONF/nothing/config.json" ]] && cp -a "$CONF/nothing/config.json" "$BACKUP/config.json"
    chmod +x "$ROLLBACK"
    say ""
    say "Backup and rollback: $BACKUP"
    say "  undo with: $ROLLBACK"
    say "Quickshell reloads the shell on its own when its files change."
    say "Hyprland picks up keybinds.lua on its next config reload (hyprctl reload)."
fi
