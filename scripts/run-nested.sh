#!/usr/bin/env bash
# Start a NESTED Hyprland "Nothing" session inside your current session.
# It opens as a plain window: your current config is never read.
#
# Known limit: your host compositor captures SUPER+... shortcuts before
# they reach this window. See the message below.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
LOG="${XDG_RUNTIME_DIR:-/tmp}/nothing-nested.log"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "You need to be in a Wayland session for nesting." >&2
    echo "From a TTY, use scripts/nothing-session.sh instead" >&2
    exit 1
fi

unset HYPRLAND_INSTANCE_SIGNATURE HYPRLAND_CMD

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export NOTHING_ROOT="$ROOT"

cat <<MSG
Nested Hyprland
  config : $ROOT/hypr/hyprland.lua
  log    : $LOG

WARNING: SUPER+... shortcuts are captured by your host compositor
before they reach this window. To test them here, add once and for
all to your current config (~/.config/hypr/custom/keybinds.lua):

    dofile(os.getenv("HOME") .. "/hypr_nothing/hypr/passthrough.lua")

then SUPER+ALT+P to switch the keyboard to the nested window, and the
same combo to switch back.

For a full real environment: sudo ./scripts/install-session.sh

MSG

exec Hyprland -c "$ROOT/hypr/hyprland.lua" 2>&1 | tee "$LOG"
