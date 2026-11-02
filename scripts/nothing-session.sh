#!/usr/bin/env bash
# Start a REAL Hyprland "Nothing" session (not nested).
# Used by the SDDM session and by launching from a TTY.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
# Hyprland 0.57 asks rtkit for realtime, which caps its main thread at
# 200 ms of CPU: one longer frame and the kernel SIGKILLs it (no coredump,
# restart in safe mode). This is the switch gainRealTime() reads to skip it.
# shortcut: remove once hyprwm/Hyprland#16737 (RT watchdog) ships.
export HYPRLAND_NO_RT=1

unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
CONF_LUA="$CONF/hypr/hyprland.lua"
# Marker that this hyprland.lua is ours (ii also has hyprland/variables.lua).
INSTALLED=false
if [[ -f "$CONF_LUA" && -f "$CONF/hypr/hyprland/animations.lua" ]] \
    && grep -q 'require("hyprland.variables")' "$CONF_LUA"; then
    INSTALLED=true
fi

CMD=(Hyprland)
if command -v start-hyprland >/dev/null 2>&1; then
    CMD=(start-hyprland --)
fi

if [[ "$INSTALLED" == true ]]; then
    export NOTHING_ROOT="$CONF"
    exec "${CMD[@]}" "$@"
else
    # Another rice already owns ~/.config/hypr/hyprland.lua: stay on the clone.
    export NOTHING_ROOT="$ROOT"
    exec "${CMD[@]}" -c "$ROOT/hypr/hyprland.lua" "$@"
fi
