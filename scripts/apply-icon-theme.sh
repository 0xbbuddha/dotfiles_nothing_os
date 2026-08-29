#!/usr/bin/env bash
# Install the Nothing icon theme and apply it to GTK / KDE / the GNOME
# portal.
#
# The theme covers the file manager only: folders, file types and toolbar
# glyphs. Application icons are inherited from Qogir-Dark, so no icon is
# ever generated per application.
#
#   ./scripts/apply-icon-theme.sh [ThemeName]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME="${1:-Nothing}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

install_nothing() {
    local dest="$DATA/icons/Nothing"
    # Old shortcut to Qogir: vendor logos, not Nothing OS.
    if [[ -L "$dest" ]]; then
        rm -f "$dest"
    fi
    mkdir -p "$dest"
    install -m644 "$ROOT/theme/icons/Nothing/index.theme" "$dest/index.theme"
    python3 "$ROOT/scripts/build-nothing-icons.py" "$dest"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f "$dest" >/dev/null 2>&1 || true
    fi
}

set_ini() {
    local file="$1" key="$2" value="$3"
    mkdir -p "$(dirname "$file")"
    if [[ -f "$file" ]] && grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    elif [[ -f "$file" ]]; then
        printf '%s=%s\n' "$key" "$value" >> "$file"
    fi
}

if [[ "$THEME" == "Nothing" ]]; then
    install_nothing
fi

# GTK 3 / 4
for v in 3.0 4.0; do
    ini="$CONF/gtk-$v/settings.ini"
    mkdir -p "$CONF/gtk-$v"
    if [[ ! -f "$ini" ]]; then
        printf '[Settings]\ngtk-icon-theme-name=%s\n' "$THEME" > "$ini"
    else
        set_ini "$ini" gtk-icon-theme-name "$THEME"
    fi
done

# KDE / Qt
mkdir -p "$CONF"
if [[ -f "$CONF/kdeglobals" ]]; then
    if grep -q '^\[Icons\]' "$CONF/kdeglobals"; then
        awk -v t="$THEME" '
            BEGIN { inicons=0 }
            /^\[Icons\]/ { inicons=1; print; next }
            /^\[/ { inicons=0 }
            inicons && /^Theme=/ { print "Theme=" t; next }
            { print }
        ' "$CONF/kdeglobals" > "$CONF/kdeglobals.tmp"
        mv "$CONF/kdeglobals.tmp" "$CONF/kdeglobals"
    else
        printf '\n[Icons]\nTheme=%s\n' "$THEME" >> "$CONF/kdeglobals"
    fi
else
    printf '[Icons]\nTheme=%s\n' "$THEME" > "$CONF/kdeglobals"
fi

for qtct in qt5ct qt6ct; do
    ini="$CONF/$qtct/$qtct.conf"
    if [[ -f "$ini" ]]; then
        if grep -q '^icon_theme=' "$ini"; then
            sed -i "s|^icon_theme=.*|icon_theme=$THEME|" "$ini"
        elif grep -q '^\[Appearance\]' "$ini"; then
            sed -i "/^\[Appearance\]/a icon_theme=$THEME" "$ini"
        fi
    fi
done

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "$THEME" 2>/dev/null || true
fi
