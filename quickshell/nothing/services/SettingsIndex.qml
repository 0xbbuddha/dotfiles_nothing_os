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

    // Named rather than counted on: Bar, Windows and Screen used to be one
    // page ("Interface", 777 lines of it) split by hand into three, and a
    // fourth split here would only have to renumber these eight lines
    // instead of every literal below.
    readonly property int pageLook: 0
    readonly property int pageBar: 1
    readonly property int pageWindows: 2
    readonly property int pageScreen: 3
    readonly property int pageEssential: 4
    readonly property int pageDock: 5
    readonly property int pageNet: 6
    readonly property int pageGame: 7
    readonly property int pageAbout: 8

    readonly property var entries: [
        // ── Appearance ────────────────────────────────────────────────
        { key: "theme",      label: "Light or dark",    page: root.pageLook, words: "theme dark light appearance colour scheme", icon: "󰝨" },
        { key: "scale",      label: "Interface size",   page: root.pageLook, words: "scale zoom size dpi big small", icon: "󰫰" },
        { key: "accent",     label: "Accent colour",    page: root.pageLook, words: "colour color red theme", icon: "󰝥" },
        { key: "wallpaper",  label: "Wallpaper image",  page: root.pageLook, words: "background picture desktop image", icon: "󰋊" },
        { key: "wallpaperDraw", label: "Wallpaper drawn by the shell", page: root.pageLook, words: "background swww hyprpaper", icon: "󰋊" },
        { key: "wallpaperSet",  label: "Nothing dot-matrix wallpaper", page: root.pageLook, words: "background dots anime manga bundled shipped", icon: "󰋊" },
        { key: "wallpaperFormat", label: "Wallpaper format",  page: root.pageLook, words: "background aspect ratio 16 10 9 screen shape", icon: "󰕴" },
        { key: "spotifyTheme", label: "Nothing theme for Spotify", page: root.pageLook, words: "spotify spicetify music theme green player apply patch", icon: "󰓇" },
        { key: "vesktopTheme", label: "Nothing theme for Vesktop", page: root.pageLook, words: "vesktop discord vencord theme quickcss apply", icon: "󰙯" },

        // ── Bar ───────────────────────────────────────────────────────
        { key: "barLayout",       label: "Bar layout",         page: root.pageBar, words: "bar navbar island left centre right order move drag clock workspaces tray reorder customise", icon: "󰌉" },
        { key: "barRadius",       label: "Bar corner radius",  page: root.pageBar, words: "bar navbar rounded square corners pill radius round edges shape", icon: "󰑙" },
        { key: "tray",            label: "System tray",        page: root.pageBar, words: "tray icons background apps", icon: "󰕢" },
        { key: "battery",         label: "Battery in bar",     page: root.pageBar, words: "battery power percent", icon: "󰁹" },
        { key: "barCpu",          label: "CPU in bar",         page: root.pageBar, words: "cpu usage percent bar", icon: "󰻠" },
        { key: "barRam",          label: "RAM in bar",         page: root.pageBar, words: "ram memory percent bar", icon: "󰍛" },
        { key: "barGpu",          label: "GPU in bar",         page: root.pageBar, words: "gpu usage percent bar", icon: "󰢮" },
        { key: "barTemp",         label: "Temperature in bar", page: root.pageBar, words: "temp temperature cpu bar", icon: "󰔐" },

        // ── Windows ───────────────────────────────────────────────────
        { key: "windowLayout", label: "Window layout",  page: root.pageWindows, words: "layout tiling scrolling essential dwindle niri paperwm columns tape shelf windows arrange", icon: "󰜨" },
        { key: "scrollColumnWidth", label: "Column width", page: root.pageWindows, words: "scrolling column width tape size", icon: "󰡎" },
        { key: "scrollFocusFit",    label: "Following the focus", page: root.pageWindows, words: "scrolling focus fit centre center column", icon: "󰋱" },
        { key: "scrollDirection",   label: "New windows appear",  page: root.pageWindows, words: "scrolling direction right left up down tape", icon: "󰁔" },
        { key: "scrollFullscreenOne", label: "One window fills the screen", page: root.pageWindows, words: "scrolling fullscreen single column width", icon: "󰊓" },
        { key: "scrollFollowFocus", label: "Scroll to the focused window", page: root.pageWindows, words: "scrolling follow focus automatic move tape", icon: "󰆾" },
        { key: "shelfSide", label: "Shelf side",  page: root.pageWindows, words: "essential layout shelf side left right parked windows", icon: "󰕰" },
        { key: "mainWidth", label: "Main pane",   page: root.pageWindows, words: "essential layout main pane width share front window", icon: "󰡎" },
        { key: "ccTiles",   label: "Control centre tiles", page: root.pageWindows, words: "control centre center cc tile toggle quick settings panel wifi bluetooth warp sound light notify game record microphone theme dock customise order drag reorder", icon: "󰘮" },
        { key: "ccColumns", label: "Tiles per row",        page: root.pageWindows, words: "control centre grid columns width tiles per row", icon: "󰕳" },
        { key: "ccFooter",  label: "Control centre buttons", page: root.pageWindows, words: "control centre footer buttons square lock reload power settings shortcuts screenshot displays", icon: "󱊨" },
        { key: "ccSections", label: "Control centre blocks", page: root.pageWindows, words: "control centre calendar media updates system stats caffeine block hide show", icon: "󰕪" },
        { key: "workspaces",      label: "Workspaces in bar",  page: root.pageWindows, words: "workspace desktop bar", icon: "󰖰" },
        { key: "workspaceStyle",  label: "Workspace numbering", page: root.pageWindows, words: "roman japanese arabic numbers", icon: "󰭺" },
        { key: "workspaceCount",  label: "Workspace count",    page: root.pageWindows, words: "how many workspaces", icon: "󰭺" },
        { key: "workspaceGrid",   label: "Overview grid",      page: root.pageWindows, words: "rows columns grid overview preview", icon: "󰋉" },
        { key: "workspaceScale",  label: "Overview thumbnail size", page: root.pageWindows, words: "grid preview scale thumbnail", icon: "󰫰" },

        // ── Screen ────────────────────────────────────────────────────
        { key: "notifications",   label: "Notifications",      page: root.pageScreen, words: "notify popup alert", icon: "󰂚" },
        { key: "notificationTimeout", label: "Notification duration", page: root.pageScreen, words: "notify timeout seconds dismiss", icon: "󰥔" },
        { key: "osd",             label: "Volume and brightness overlays", page: root.pageScreen, words: "osd bubble volume brightness mute charge glyph", icon: "󰕾" },
        { key: "night",           label: "Night light schedule", page: root.pageScreen, words: "night blue light warm hyprsunset evening", icon: "󰖔" },
        { key: "nightTemp",       label: "Colour temperature", page: root.pageScreen, words: "kelvin warm night light", icon: "󰖔" },
        { key: "weather",         label: "Weather",            page: root.pageScreen, words: "weather wttr forecast", icon: "󰖐" },
        { key: "weatherCity",     label: "Weather city",       page: root.pageScreen, words: "weather city location", icon: "󰙀" },
        { key: "idleDim",         label: "Dim the screen when idle", page: root.pageScreen, words: "idle dim brightness timeout hypridle sleep away darker", icon: "󰂽" },
        { key: "idleLock",        label: "Lock when idle",   page: root.pageScreen, words: "idle lock timeout hypridle away automatic", icon: "󰌾" },
        { key: "idleOff",         label: "Screens off when idle", page: root.pageScreen, words: "idle dpms screen off timeout hypridle blank sleep standby", icon: "󰍹" },
        { key: "idleSuspend",     label: "Suspend when idle", page: root.pageScreen, words: "idle suspend sleep timeout hypridle power", icon: "󰤄" },
        { key: "lockBackground",  label: "Lock screen background", page: root.pageScreen, words: "lock screen password wallpaper black background session logout reboot", icon: "󰌾" },

        // ── Essential ─────────────────────────────────────────────────
        { key: "essential",       label: "Essential Space", page: root.pageEssential, words: "essential space note clip snip ocr record song voice mic key", icon: "󰋖" },
        { key: "essentialSide",   label: "Essential shelf", page: root.pageEssential, words: "essential side left right shelf pane panel", icon: "󰘌" },
        { key: "essentialSearch", label: "Essential Search", page: root.pageEssential, words: "essential search launcher ask gemini captures settings super", icon: "󰍉" },
        { key: "mind",            label: "Mind",            page: root.pageEssential, words: "mind ollama gemini ai stub essential", icon: "󰍜" },
        { key: "geminiKey",       label: "Gemini API key",  page: root.pageEssential, words: "gemini api key google ai studio mind", icon: "󰌆" },
        { key: "appsKey",         label: "Essential Apps button in the bar", page: root.pageEssential, words: "essential apps bar button clock key icon", icon: "󰀻" },
        { key: "deskApps",        label: "Apps on the desktop", page: root.pageEssential, words: "essential apps widget desktop generated pin right column playground", icon: "󰀻" },
        { key: "appsLibrary",     label: "Essential Apps library", page: root.pageEssential, words: "essential apps library mini app create prompt generate widget", icon: "󰋉" },

        // ── Dock ──────────────────────────────────────────────────────
        { key: "dockShow",     label: "Show dock",         page: root.pageDock, words: "dock bottom launcher bar", icon: "󰌉" },
        { key: "dockAutoHide", label: "Dock auto hide",    page: root.pageDock, words: "dock hide reveal edge", icon: "󰍴" },
        { key: "dockDelay",    label: "Dock hide delay",   page: root.pageDock, words: "dock delay milliseconds", icon: "󰥔" },
        { key: "dockApps",     label: "Dock applications", page: root.pageDock, words: "dock apps pinned favourites order drag reorder", icon: "󰀻" },
        { key: "terminal",     label: "Terminal",          page: root.pageDock, words: "terminal kitty console shell", icon: "󰆍" },
        { key: "fileManager",  label: "File manager",      page: root.pageDock, words: "files dolphin nautilus explorer", icon: "󰉖" },
        { key: "launcher",     label: "External launcher", page: root.pageDock, words: "launcher rofi wofi run", icon: "󰍉" },

        // ── Network ───────────────────────────────────────────────────
        { key: "wifiAdd", label: "Add a hidden network", page: root.pageNet, words: "wifi hidden ssid manual add join network password", icon: "󰜄" },
        { key: "wifi",      label: "Wi-Fi",     page: root.pageNet, words: "wifi wireless network internet password", icon: "󰖩" },
        { key: "bluetooth", label: "Bluetooth", page: root.pageNet, words: "bluetooth bt headset pair", icon: "󰂯" },

        // ── Game ──────────────────────────────────────────────────────
        { key: "gameMode",        label: "Game mode",           page: root.pageGame, words: "game gaming performance" },
        { key: "gameNoAnimations", label: "Disable animations in game", page: root.pageGame, words: "game animation latency" },
        { key: "gameNoBlur",      label: "Disable blur in game", page: root.pageGame, words: "game blur gpu" },
        { key: "gameNoShadow",    label: "Disable shadows in game", page: root.pageGame, words: "game shadow gpu" },
        { key: "gameTearing",     label: "Allow tearing",       page: root.pageGame, words: "game tearing vsync latency" },
        { key: "gameInhibitIdle", label: "Keep screen awake in game", page: root.pageGame, words: "game idle sleep lock" },
        { key: "gameHideShell",   label: "Hide the shell in game", page: root.pageGame, words: "game bar dock hide fullscreen" },
        { key: "gameUnfocusedFps", label: "Unfocused frame rate", page: root.pageGame, words: "game fps background alt tab" },
        { key: "gameFpsLimit",    label: "Frame rate limit",    page: root.pageGame, words: "game fps cap mangohud limit" },
        { key: "crosshair",       label: "Crosshair",           page: root.pageGame, words: "crosshair aim reticle overlay" },
        { key: "crosshairStyle",  label: "Crosshair shape",     page: root.pageGame, words: "crosshair cross dot circle" },
        { key: "crosshairSize",   label: "Crosshair size",      page: root.pageGame, words: "crosshair size aim" },
        { key: "crosshairColor",  label: "Crosshair colour",    page: root.pageGame, words: "crosshair colour green" },
        { key: "gameWidgets",     label: "Game overlay widgets", page: root.pageGame, words: "game widget overlay fps clock" },

        // ── System ────────────────────────────────────────────────────
        { key: "versions",  label: "Versions",         page: root.pageAbout, words: "version hyprland quickshell about" },
        { key: "configFile", label: "Configuration file", page: root.pageAbout, words: "config json path file" },
        { key: "reloadShell", label: "Reload the shell", page: root.pageAbout, words: "reload restart quickshell" },
        { key: "reset",     label: "Reset settings",   page: root.pageAbout, words: "reset default factory erase" }
    ]

    // Filter on the label and keywords; every word of the query must
    // appear somewhere.
    // The glyph for a section, looked up by its title.
    readonly property var sectionIcons: ({
        "Theme": "󰝨",
        "Scale": "󰫰",
        "Accent": "󰝥",
        "Wallpaper": "󰋊",
        "Spotify": "󰓇",
        "Bar": "󰌉",
        "Indicators": "󰕢",
        "Windows": "󰜨",
        "Control centre": "󰘮",
        "Workspaces": "󰖰",
        "Overview grid": "󰋉",
        "On-screen feedback": "󰕾",
        "Night light": "󰖔",
        "Weather": "󰖐",
        "Idle": "󰤄",
        "Lock": "󰌾",
        "Space": "󰋖",
        "Search": "󰍉",
        "Mind": "󰍜",
        "Apps": "󰀻",
        "Add an app": "󰜄",
        "Dock applications": "󰀻",
        "Default programs": "󰆍",
        "Files": "󰉖",
        "Behaviour": "󰍴",
        "Wi-Fi": "󰖩",
        "Bluetooth": "󰂯",
        "Game mode": "󰊗",
        "Overlay widgets": "󰋉",
        "Crosshair": "󰗠",
        "Versions": "󰖩",
        "Maintenance": "󰒓"
    })

    function sectionIcon(title: string): string {
        return root.sectionIcons[title] ?? "";
    }

    // The glyph for a row, looked up by the key it already declares.
    function iconFor(key: string): string {
        return root.entries.find(e => e.key === key)?.icon ?? "";
    }

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
