#!/usr/bin/env bash
# Restore files installed by scripts/install-config.sh.
set -euo pipefail

restore() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target"
        echo "  removed $target"
    fi
    local last
    last="$(ls -1d "$target".bak-* 2>/dev/null | sort | tail -1 || true)"
    if [[ -n "$last" ]]; then
        mv "$last" "$target"
        echo "  restored <- $last"
    fi
}

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

echo "-> Restore ~/.config copies"
restore "$CONF/kitty"
restore "$CONF/mpv"
restore "$CONF/fontconfig"
restore "$CONF/fastfetch"
restore "$CONF/starship.toml"
restore "$CONF/fish/conf.d/nothing.fish"
# Only written when the user had none, so restoring means removing ours.
restore "$CONF/fish/config.fish"
restore "$CONF/quickshell/nothing"
restore "$CONF/scripts"
restore "$CONF/theme"
restore "$CONF/hypr/hypridle.conf"
restore "$CONF/hypr/hyprlock.conf"
restore "$CONF/hypr/lockstatus.sh"
restore "$CONF/hypr/passthrough.lua"
restore "$CONF/hypr/wallpaper.png"
restore "$CONF/hypr/hyprland.lua"
restore "$CONF/hypr/hyprland"
restore "$CONF/hypr/hyprland.conf"
restore "$DATA/applications/nothing-x.desktop"
restore "$DATA/icons/hicolor/scalable/apps/nothing-x.svg"

echo "Left in place: $CONF/hypr/custom.lua"
echo "Done."
