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
        { key: "iconTheme",  label: "App icons",        page: 0, words: "icons theme nothing qogir breeze papirus squircle" },
        { key: "wallpaper",  label: "Wallpaper image",  page: 0, words: "background picture desktop image" },
        { key: "wallpaperDraw", label: "Wallpaper drawn by the shell", page: 0, words: "background swww hyprpaper" },

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

        // ── Widgets ───────────────────────────────────────────────────
        { key: "widgets",       label: "Desktop widgets",    page: 3, words: "widget clock date media calendar" },
        { key: "widgetsShown",  label: "Show desktop widgets", page: 3, words: "widget hide desktop column" },
        { key: "glyphEnabled",  label: "Glyph Matrix",        page: 3, words: "glyph matrix disc nothing phone toy" },
        { key: "glyphSize",     label: "Glyph Matrix size",   page: 3, words: "glyph size diameter disc" },
        { key: "glyphAbove",    label: "Glyph Matrix above windows", page: 3, words: "glyph layer overlay desktop" },
        { key: "glyphPos",      label: "Glyph Matrix position", page: 3, words: "glyph move drag recenter" },
        { key: "glyphToys",     label: "Glyph Matrix toys",   page: 3, words: "glyph clock battery dice timer visualizer cava pendulum counter" },

        // ── Dock ──────────────────────────────────────────────────────
        { key: "dockShow",     label: "Show dock",         page: 4, words: "dock bottom launcher bar" },
        { key: "dockAutoHide", label: "Dock auto hide",    page: 4, words: "dock hide reveal edge" },
        { key: "dockDelay",    label: "Dock hide delay",   page: 4, words: "dock delay milliseconds" },
        { key: "dockApps",     label: "Dock applications", page: 4, words: "dock apps pinned favourites" },
        { key: "terminal",     label: "Terminal",          page: 4, words: "terminal kitty console shell" },
        { key: "fileManager",  label: "File manager",      page: 4, words: "files dolphin nautilus explorer" },
        { key: "launcher",     label: "External launcher", page: 4, words: "launcher rofi wofi run" },

        // ── Network ───────────────────────────────────────────────────
        { key: "wifi",      label: "Wi-Fi",     page: 5, words: "wifi wireless network internet password mot passe" },
        { key: "bluetooth", label: "Bluetooth", page: 5, words: "bluetooth bt headset pair" },

        // ── Game ──────────────────────────────────────────────────────
        { key: "gameMode",        label: "Game mode",           page: 6, words: "game gaming performance" },
        { key: "gameNoAnimations", label: "Disable animations in game", page: 6, words: "game animation latency" },
        { key: "gameNoBlur",      label: "Disable blur in game", page: 6, words: "game blur gpu" },
        { key: "gameNoShadow",    label: "Disable shadows in game", page: 6, words: "game shadow gpu" },
        { key: "gameTearing",     label: "Allow tearing",       page: 6, words: "game tearing vsync latency" },
        { key: "gameInhibitIdle", label: "Keep screen awake in game", page: 6, words: "game idle sleep lock" },
        { key: "gameHideShell",   label: "Hide the shell in game", page: 6, words: "game bar dock hide fullscreen" },
        { key: "gameUnfocusedFps", label: "Unfocused frame rate", page: 6, words: "game fps background alt tab" },
        { key: "gameFpsLimit",    label: "Frame rate limit",    page: 6, words: "game fps cap mangohud limit" },
        { key: "crosshair",       label: "Crosshair",           page: 6, words: "crosshair aim reticle overlay" },
        { key: "crosshairStyle",  label: "Crosshair shape",     page: 6, words: "crosshair cross dot circle" },
        { key: "crosshairSize",   label: "Crosshair size",      page: 6, words: "crosshair size aim" },
        { key: "crosshairColor",  label: "Crosshair colour",    page: 6, words: "crosshair colour green" },
        { key: "gameWidgets",     label: "Game overlay widgets", page: 6, words: "game widget overlay fps clock" },

        // ── System ────────────────────────────────────────────────────
        { key: "versions",  label: "Versions",         page: 7, words: "version hyprland quickshell about" },
        { key: "configFile", label: "Configuration file", page: 7, words: "config json path file" },
        { key: "reloadShell", label: "Reload the shell", page: 7, words: "reload restart quickshell" },
        { key: "reset",     label: "Reset settings",   page: 7, words: "reset default factory erase" }
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
