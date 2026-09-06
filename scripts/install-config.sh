#!/usr/bin/env bash
# Copy the rice into ~/.config (real files, no symlinks).
# What was already there is moved to *.bak-<stamp>.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STAMP="$(date +%Y%m%d-%H%M%S)"

backup() {
    [[ -e "$1" || -L "$1" ]] || return 0
    mv "$1" "$1.bak-$STAMP"
    echo "  backed up -> $1.bak-$STAMP"
}

copy_file() {
    local src=$1 dest=$2
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    cp -a "$src" "$dest"
    echo "  $dest"
}

copy_tree() {
    local src=$1 dest=$2
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$src/" "$dest/"
    else
        cp -a "$src"/. "$dest"/
    fi
    echo "  $dest/"
}

echo "-> ~/.config/quickshell/nothing"
copy_tree "$ROOT/quickshell/nothing" "$CONF/quickshell/nothing"

echo "-> ~/.config/scripts"
copy_tree "$ROOT/scripts" "$CONF/scripts"

echo "-> ~/.config/theme"
copy_tree "$ROOT/theme" "$CONF/theme"

# Desktop entries and their icons go in one file at a time, never as a
# tree: $DATA/applications holds every other launcher entry on the machine
# and replacing the directory would take them with it.
echo "-> $DATA/applications"
for d in "$ROOT"/applications/*.desktop; do
    [[ -e "$d" ]] || continue
    copy_file "$d" "$DATA/applications/$(basename "$d")"
done
for i in "$ROOT"/icons/hicolor/scalable/apps/*.svg; do
    [[ -e "$i" ]] || continue
    copy_file "$i" "$DATA/icons/hicolor/scalable/apps/$(basename "$i")"
done
command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$DATA/applications" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 \
    && gtk-update-icon-cache -f "$DATA/icons/hicolor" >/dev/null 2>&1 || true

echo "-> ~/.config/kitty"
copy_tree "$ROOT/config/kitty" "$CONF/kitty"

echo "-> ~/.config/mpv"
copy_tree "$ROOT/config/mpv" "$CONF/mpv"

echo "-> ~/.config/fontconfig"
copy_tree "$ROOT/config/fontconfig" "$CONF/fontconfig"

echo "-> ~/.config/fastfetch"
copy_tree "$ROOT/config/fastfetch" "$CONF/fastfetch"

echo "-> ~/.config/starship.toml"
copy_file "$ROOT/config/starship.toml" "$CONF/starship.toml"

echo "-> ~/.config/fish"
mkdir -p "$CONF/fish/conf.d" "$CONF/fish/functions"
copy_file "$ROOT/config/fish/conf.d/nothing.fish" "$CONF/fish/conf.d/nothing.fish"
# Autoloaded by name, so it works without touching an existing config.fish.
copy_file "$ROOT/config/fish/functions/fastfetch.fish" "$CONF/fish/functions/fastfetch.fish"
if [[ ! -e "$CONF/fish/config.fish" ]]; then
    copy_file "$ROOT/config/fish/config.fish" "$CONF/fish/config.fish"
else
    echo "  kept existing $CONF/fish/config.fish"
fi

echo "-> ~/.config/hypr"
mkdir -p "$CONF/hypr"
backup "$CONF/hypr/hyprland.conf"
copy_file "$ROOT/hypr/hyprland.lua"     "$CONF/hypr/hyprland.lua"
copy_tree "$ROOT/hypr/hyprland"         "$CONF/hypr/hyprland"
copy_file "$ROOT/hypr/hypridle.conf"    "$CONF/hypr/hypridle.conf"
copy_file "$ROOT/hypr/hyprlock.conf"    "$CONF/hypr/hyprlock.conf"
copy_file "$ROOT/hypr/lockstatus.sh"    "$CONF/hypr/lockstatus.sh"
copy_file "$ROOT/hypr/passthrough.lua"  "$CONF/hypr/passthrough.lua"
copy_file "$ROOT/hypr/wallpaper.png"    "$CONF/hypr/wallpaper.png"
# The dot-matrix pair, one frame per screen shape. Settings picks between
# them by name, so both have to be there.
copy_tree "$ROOT/hypr/wallpapers"       "$CONF/hypr/wallpapers"

if [[ ! -e "$CONF/hypr/custom.lua" ]]; then
    if [[ -f "$ROOT/hypr/custom.lua" ]]; then
        cp -a "$ROOT/hypr/custom.lua" "$CONF/hypr/custom.lua"
    else
        cp -a "$ROOT/hypr/custom.lua.example" "$CONF/hypr/custom.lua"
    fi
    echo "  $CONF/hypr/custom.lua"
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || -d /run/user/${UID:-$(id -u)}/hypr ]]; then
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        HIS="$(ls -1 /run/user/${UID:-$(id -u)}/hypr 2>/dev/null | head -1 || true)"
        [[ -n "$HIS" ]] && export HYPRLAND_INSTANCE_SIGNATURE="$HIS"
    fi
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl reload >/dev/null 2>&1; then
        echo "Reloaded the running Hyprland config."
    fi
fi

echo "Done. Live config is under ~/.config (copies). Re-run ./install --files after a git pull."
echo "To undo: ./install --uninstall"
