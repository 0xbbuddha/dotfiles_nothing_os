#!/usr/bin/env bash
# Apply the Nothing theme to Qt/KDE apps (Dolphin, Kate, Ark…)
# and GTK 3/4. Always backs up what already exists.
#
#   ./scripts/apply-app-theme.sh            install
#   ./scripts/apply-app-theme.sh --revert   restore the last backup
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

backup() {
    [[ -e "$1" || -L "$1" ]] || return 0
    cp -a "$1" "$1.bak-$STAMP"
    echo "    backed up → $(basename "$1").bak-$STAMP"
}

revert() {
    local target="$1" last
    last="$(ls -1d "$target".bak-* 2>/dev/null | sort | tail -1 || true)"
    if [[ -n "$last" ]]; then
        rm -rf "$target"
        mv "$last" "$target"
        echo "    restored ← $(basename "$last")"
    else
        echo "    no backup for $target"
    fi
}

if [[ "${1:-}" == "--revert" ]]; then
    echo "→ Restore"
    revert "$CONF/kdeglobals"
    revert "$CONF/darklyrc"
    revert "$CONF/gtk-3.0/settings.ini"
    revert "$CONF/gtk-3.0/gtk.css"
    revert "$CONF/gtk-4.0/settings.ini"
    revert "$CONF/gtk-4.0/gtk.css"
    revert "$CONF/xdg-desktop-portal/hyprland-portals.conf"
    revert "$CONF/xdg-desktop-portal/portals.conf"
    rm -f "$DATA/color-schemes/Nothing.colors"
    echo "Done. Restart the affected apps."
    exit 0
fi

echo "→ Nothing icons"
bash "$ROOT/scripts/apply-icon-theme.sh" Nothing
echo "    $DATA/icons/Nothing"

echo "→ Qt / KDE (Dolphin & co)"
mkdir -p "$DATA/color-schemes"
install -m644 "$ROOT/theme/kde/color-schemes/Nothing.colors" "$DATA/color-schemes/Nothing.colors"
echo "    $DATA/color-schemes/Nothing.colors"
backup "$CONF/kdeglobals"
install -m644 "$ROOT/theme/kde/kdeglobals" "$CONF/kdeglobals"
echo "    $CONF/kdeglobals"
backup "$CONF/darklyrc"
install -m644 "$ROOT/theme/kde/darklyrc" "$CONF/darklyrc"
echo "    $CONF/darklyrc"

if command -v kwriteconfig6 >/dev/null 2>&1; then
    echo "→ Dolphin"
    kwriteconfig6 --file dolphinrc --group General --key GlobalViewProps true
    kwriteconfig6 --file dolphinrc --group General --key ShowFullPath true
    kwriteconfig6 --file dolphinrc --group General --key ShowStatusBar FullWidth
    kwriteconfig6 --file dolphinrc --group MainWindow --key MenuBar Disabled
    kwriteconfig6 --file dolphinrc --group IconsMode --key IconSize 96
    kwriteconfig6 --file dolphinrc --group IconsMode --key PreviewSize 128
    kwriteconfig6 --file dolphinrc --group PlacesPanel --key IconSize 28
    kwriteconfig6 --file dolphinrc --group DetailsMode --key PreviewSize 22
    kwriteconfig6 --file dolphinrc --group InformationPanel --key previewsShown true
    kwriteconfig6 --file dolphinrc --group InformationPanel --key showHovered true
    plugins="$(kreadconfig6 --file dolphinrc --group PreviewSettings --key Plugins 2>/dev/null || true)"
    if [[ -n "$plugins" ]]; then
        plugins="${plugins//directorythumbnail,/}"
        plugins="${plugins//,directorythumbnail/}"
        kwriteconfig6 --file dolphinrc --group PreviewSettings --key Plugins "$plugins"
    fi
    echo "    $CONF/dolphinrc"
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
fi

echo "→ GTK 3 and 4"
for v in 3.0 4.0; do
    mkdir -p "$CONF/gtk-$v"
    backup "$CONF/gtk-$v/settings.ini"
    backup "$CONF/gtk-$v/gtk.css"
    install -m644 "$ROOT/theme/gtk/gtk-$v/settings.ini" "$CONF/gtk-$v/settings.ini"
    install -m644 "$ROOT/theme/gtk/gtk-$v/gtk.css" "$CONF/gtk-$v/gtk.css"
    echo "    $CONF/gtk-$v/"
done

echo "→ File picker portals (Save As in browsers, Vesktop…)"
mkdir -p "$CONF/xdg-desktop-portal"
backup "$CONF/xdg-desktop-portal/hyprland-portals.conf"
backup "$CONF/xdg-desktop-portal/portals.conf"
install -m644 "$ROOT/theme/xdg-desktop-portal/hyprland-portals.conf" \
    "$CONF/xdg-desktop-portal/hyprland-portals.conf"
install -m644 "$ROOT/theme/xdg-desktop-portal/portals.conf" \
    "$CONF/xdg-desktop-portal/portals.conf"
echo "    $CONF/xdg-desktop-portal/"
bash "$ROOT/scripts/setup-portals.sh"

# Modern GTK apps also read these keys via the portal.
if command -v gsettings >/dev/null 2>&1; then
    echo "→ GNOME preferences (portal)"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Nothing' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Inter Variable 10' 2>/dev/null || true
fi

cat <<'MSG'

Done. Restart Dolphin: squircle grid, glass sidebar, black background.

To undo: ./scripts/apply-app-theme.sh --revert
MSG
