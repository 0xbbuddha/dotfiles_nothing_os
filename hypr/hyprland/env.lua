-- Environment. Aligns with the illogical-impulse configuration, which
-- has the merit of being proven on this machine.

-- Repo root, for children that need it without being able to deduce it
-- (hypr/hypridle.conf finds the hyprlock config there). Launch scripts
-- already set it; this covers a Hyprland started by hand.
hl.env("NOTHING_ROOT", ROOT)

hl.env("XCURSOR_THEME", cursorTheme)
hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_SIZE", cursorSize)

-- Qt: native Wayland with X11 fallback, and reads ~/.config/kdeglobals
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- GTK and browsers
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Games and Java
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Desktop name: xdg-desktop-portal picks hyprland-portals.conf from it.
-- Session scripts already export these; this covers a Hyprland started by hand.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- KDE application menus
hl.env("XDG_MENU_PREFIX", "plasma-")
hl.env("GTK_THEME", "adw-gtk3-dark")

-- Flatpak applications visible to the launcher
local dataDirs = os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
hl.env("XDG_DATA_DIRS",
    os.getenv("HOME") .. "/.local/share/flatpak/exports/share:"
    .. "/var/lib/flatpak/exports/share:" .. dataDirs)
