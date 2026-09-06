pragma Singleton

import QtQuick
import Quickshell

// Search index for settings, shared by the settings panel and Essential Search.
//
// It doubles the page structure: without it, finding a setting means already
// knowing which page it lives on. The list is kept by hand rather than
// inferred from pages, because a setting is searched with the user's words
// ("night brightness") and not its exact label.
//
// `key` must match the `key` set on the targeted SettingRow, otherwise the
// result leads to the right page but highlights no row.
Singleton {
    id: root

    readonly property int pageLook: 0
    readonly property int pagePanel: 1
    readonly property int pageEssential: 2
    readonly property int pageWidgets: 3
    readonly property int pageDock: 4
    readonly property int pageNet: 5
    readonly property int pageGame: 6
    readonly property int pageAbout: 7

    readonly property var entries: [
        // ── Appearance ────────────────────────────────────────────────
        { key: "scale",      label: "Interface size",   page: 0, words: "scale zoom size dpi big small" },
        { key: "accent",     label: "Accent colour",    page: 0, words: "colour color red theme" },
        { key: "wallpaper",  label: "Wallpaper image",  page: 0, words: "background picture desktop image" },
        { key: "wallpaperDraw", label: "Wallpaper drawn by the shell", page: 0, words: "background swww hyprpaper" },
        { key: "wallpaperSet",  label: "Nothing dot-matrix wallpaper", page: 0, words: "background dots anime manga bundled shipped" },
        { key: "wallpaperFormat", label: "Wallpaper format",  page: 0, words: "background aspect ratio 16 10 9 screen shape" },

        // ── Interface ─────────────────────────────────────────────────
        { key: "workspaces",      label: "Workspaces in bar",  page: 1, words: "workspace desktop bar" },
        { key: "workspaceStyle",  label: "Workspace numbering", page: 1, words: "roman japanese arabic numbers" },
        { key: "workspaceCount",  label: "Workspace count",    page: 1, words: "how many workspaces" },
        { key: "workspaceGrid",   label: "Overview grid",      page: 1, words: "rows columns grid overview preview" },
        { key: "workspaceScale",  label: "Overview thumbnail size", page: 1, words: "grid preview scale thumbnail" },
        { key: "tray",            label: "System tray",        page: 1, words: "tray icons background apps" },
        { key: "battery",         label: "Battery in bar",     page: 1, words: "battery power percent" },
        { key: "barCpu",          label: "CPU in bar",         page: 1, words: "cpu usage percent bar" },
        { key: "barRam",          label: "RAM in bar",         page: 1, words: "ram memory percent bar" },
        { key: "barGpu",          label: "GPU in bar",         page: 1, words: "gpu usage percent bar" },
        { key: "barTemp",         label: "Temperature in bar", page: 1, words: "temp temperature cpu bar" },
        { key: "notifications",   label: "Notifications",      page: 1, words: "notify popup alert" },
        { key: "notificationTimeout", label: "Notification duration", page: 1, words: "notify timeout seconds dismiss" },
        { key: "osd",             label: "Volume and brightness overlays", page: 1, words: "osd bubble volume brightness mute charge glyph" },
        { key: "night",           label: "Night light schedule", page: 1, words: "night blue light warm hyprsunset evening" },
        { key: "nightTemp",       label: "Colour temperature", page: 1, words: "kelvin warm night light" },
        { key: "weather",         label: "Weather",            page: 1, words: "weather wttr forecast" },
        { key: "weatherCity",     label: "Weather city",       page: 1, words: "weather city location" },

        // ── Essential ─────────────────────────────────────────────────
        { key: "essential",       label: "Essential Space", page: 2, words: "essential space note clip snip ocr record song voice mic key" },
        { key: "essentialSide",   label: "Essential shelf", page: 2, words: "essential side left right shelf pane panel" },
        { key: "essentialSearch", label: "Essential Search", page: 2, words: "essential search launcher ask gemini captures settings super" },
        { key: "mind",            label: "Mind",            page: 2, words: "mind ollama gemini ai stub essential" },
        { key: "geminiKey",       label: "Gemini API key",  page: 2, words: "gemini api key google ai studio mind" },
        { key: "lockScreen",      label: "Lock screen",     page: 1, words: "lock screen hyprlock password shell session logout reboot" },
        { key: "idleDim",         label: "Dim the screen when idle", page: 1, words: "idle dim brightness timeout hypridle sleep away darker" },
        { key: "idleLock",        label: "Lock when idle",   page: 1, words: "idle lock timeout hypridle away automatic" },
        { key: "idleOff",         label: "Screens off when idle", page: 1, words: "idle dpms screen off timeout hypridle blank sleep standby" },
        { key: "idleSuspend",     label: "Suspend when idle", page: 1, words: "idle suspend sleep timeout hypridle power" },
        { key: "appsKey",         label: "Essential Apps button in the bar", page: 2, words: "essential apps bar button clock key icon" },
        { key: "deskApps",        label: "Apps on the desktop", page: 2, words: "essential apps widget desktop generated pin right column playground" },
        { key: "appsLibrary",     label: "Essential Apps library", page: 2, words: "essential apps library mini app create prompt generate widget" },

        // ── Widgets ───────────────────────────────────────────────────

        // ── Dock ──────────────────────────────────────────────────────
        { key: "dockShow",     label: "Show dock",         page: 3, words: "dock bottom launcher bar" },
        { key: "dockAutoHide", label: "Dock auto hide",    page: 3, words: "dock hide reveal edge" },
        { key: "dockDelay",    label: "Dock hide delay",   page: 3, words: "dock delay milliseconds" },
        { key: "dockApps",     label: "Dock applications", page: 3, words: "dock apps pinned favourites" },
        { key: "terminal",     label: "Terminal",          page: 3, words: "terminal kitty console shell" },
        { key: "fileManager",  label: "File manager",      page: 3, words: "files dolphin nautilus explorer" },
        { key: "launcher",     label: "External launcher", page: 3, words: "launcher rofi wofi run" },

        // ── Network ───────────────────────────────────────────────────
        { key: "wifi",      label: "Wi-Fi",     page: 4, words: "wifi wireless network internet password" },
        { key: "bluetooth", label: "Bluetooth", page: 4, words: "bluetooth bt headset pair" },

        // ── Game ──────────────────────────────────────────────────────
        { key: "gameMode",        label: "Game mode",           page: 5, words: "game gaming performance" },
        { key: "gameNoAnimations", label: "Disable animations in game", page: 5, words: "game animation latency" },
        { key: "gameNoBlur",      label: "Disable blur in game", page: 5, words: "game blur gpu" },
        { key: "gameNoShadow",    label: "Disable shadows in game", page: 5, words: "game shadow gpu" },
        { key: "gameTearing",     label: "Allow tearing",       page: 5, words: "game tearing vsync latency" },
        { key: "gameInhibitIdle", label: "Keep screen awake in game", page: 5, words: "game idle sleep lock" },
        { key: "gameHideShell",   label: "Hide the shell in game", page: 5, words: "game bar dock hide fullscreen" },
        { key: "gameUnfocusedFps", label: "Unfocused frame rate", page: 5, words: "game fps background alt tab" },
        { key: "gameFpsLimit",    label: "Frame rate limit",    page: 5, words: "game fps cap mangohud limit" },
        { key: "crosshair",       label: "Crosshair",           page: 5, words: "crosshair aim reticle overlay" },
        { key: "crosshairStyle",  label: "Crosshair shape",     page: 5, words: "crosshair cross dot circle" },
        { key: "crosshairSize",   label: "Crosshair size",      page: 5, words: "crosshair size aim" },
        { key: "crosshairColor",  label: "Crosshair colour",    page: 5, words: "crosshair colour green" },
        { key: "gameWidgets",     label: "Game overlay widgets", page: 5, words: "game widget overlay fps clock" },

        // ── System ────────────────────────────────────────────────────
        { key: "versions",  label: "Versions",         page: 6, words: "version hyprland quickshell about" },
        { key: "configFile", label: "Configuration file", page: 6, words: "config json path file" },
        { key: "reloadShell", label: "Reload the shell", page: 6, words: "reload restart quickshell" },
        { key: "reset",     label: "Reset settings",   page: 6, words: "reset default factory erase" }
    ]

    // Filter on the label and keywords; every word of the query must
    // appear somewhere.
    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const parts = q.split(/\s+/);
        const words = parts.filter(p => p.length > 2);
        const use = words.length > 0 ? words : parts;
        return root.entries.filter(e => {
            const hay = (e.label + " " + e.words).toLowerCase();
            return use.every(p => hay.includes(p));
        });
    }
}
