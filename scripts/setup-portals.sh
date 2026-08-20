#!/usr/bin/env bash
# Wire xdg-desktop-portal to this compositor, then bounce the backends.
# Save-as / open-file in Vesktop, Chrome, Firefox go through FileChooser:
# xdg-desktop-portal-hyprland does not implement it, so GTK (and KDE if
# it can see WAYLAND_DISPLAY) have to be in the preferred list.
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
SRC="$ROOT/theme/xdg-desktop-portal"

mkdir -p "$CONF"
install -m644 "$SRC/hyprland-portals.conf" "$CONF/hyprland-portals.conf"
install -m644 "$SRC/portals.conf" "$CONF/portals.conf"

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd --all
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment \
        WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP \
        XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE \
        QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME 2>/dev/null || true

    for u in \
        xdg-desktop-portal-hyprland \
        plasma-xdg-desktop-portal-kde \
        xdg-desktop-portal-gtk \
        xdg-desktop-portal
    do
        systemctl --user reset-failed "$u.service" 2>/dev/null || true
    done

    # Backends first so the front-end sees them when it comes back.
    systemctl --user restart xdg-desktop-portal-gtk.service 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal-hyprland.service 2>/dev/null || true
    systemctl --user restart plasma-xdg-desktop-portal-kde.service 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
fi
