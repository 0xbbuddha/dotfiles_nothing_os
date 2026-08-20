pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings persisted in ~/.config/nothing/config.json.
// Everything editable from the settings panel lives here.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.config/nothing`
    readonly property string path: `${root.dir}/config.json`

    // false until config.json has been read: otherwise adapterUpdated
    // would write defaults over the user's settings.
    property bool ready: false

    // ── Appearance ────────────────────────────────────────────────────
    property alias scale: a.scale
    property alias accent: a.accent
    property alias iconTheme: a.iconTheme
    property alias drawWallpaper: a.drawWallpaper
    property alias wallpaper: a.wallpaper

    // ── Shown elements ────────────────────────────────────────────────
    property alias showDock: a.showDock
    property alias showDesktopWidgets: a.showDesktopWidgets
    property alias showTray: a.showTray
    property alias showBattery: a.showBattery
    property alias showWorkspaces: a.showWorkspaces
    property alias barShowCpu: a.barShowCpu
    property alias barShowRam: a.barShowRam
    property alias barShowGpu: a.barShowGpu
    property alias barShowTemp: a.barShowTemp

    // ── Behaviour ─────────────────────────────────────────────────────
    property alias notificationsEnabled: a.notificationsEnabled
    property alias notificationTimeout: a.notificationTimeout
    property alias osdEnabled: a.osdEnabled
    property alias essentialEnabled: a.essentialEnabled
    property alias essentialSide: a.essentialSide
    property alias mindBackend: a.mindBackend

    // ── Weather ───────────────────────────────────────────────────────
    property alias weatherEnabled: a.weatherEnabled
    property alias weatherCity: a.weatherCity

    // ── Programs ──────────────────────────────────────────────────────
    property alias terminal: a.terminal
    property alias launcher: a.launcher
    property alias fileManager: a.fileManager

    // ── Dock ──────────────────────────────────────────────────────────
    property alias dockApps: a.dockApps

    // ── Dock and workspaces ───────────────────────────────────────────
    property alias dockAutoHide: a.dockAutoHide
    property alias dockHideDelay: a.dockHideDelay
    property alias workspaceCount: a.workspaceCount
    property alias workspaceStyle: a.workspaceStyle
    property alias workspaceRows: a.workspaceRows
    property alias workspaceCols: a.workspaceCols
    property alias workspaceScale: a.workspaceScale

    // ── Light ─────────────────────────────────────────────────────────
    property alias nightAutomatic: a.nightAutomatic
    property alias nightFrom: a.nightFrom
    property alias nightTo: a.nightTo
    property alias nightTemperature: a.nightTemperature

    // ── Game mode ─────────────────────────────────────────────────────
    property alias gameMode: a.gameMode
    property alias gameNoAnimations: a.gameNoAnimations
    property alias gameNoBlur: a.gameNoBlur
    property alias gameNoShadow: a.gameNoShadow
    property alias gameTearing: a.gameTearing
    property alias gameInhibitIdle: a.gameInhibitIdle
    property alias gameHideShell: a.gameHideShell
    property alias gameUnfocusedFps: a.gameUnfocusedFps
    property alias gameFpsLimit: a.gameFpsLimit

    property alias crosshair: a.crosshair
    property alias crosshairStyle: a.crosshairStyle
    property alias crosshairSize: a.crosshairSize
    property alias crosshairThickness: a.crosshairThickness
    property alias crosshairGap: a.crosshairGap
    property alias crosshairColor: a.crosshairColor
    property alias crosshairOutline: a.crosshairOutline
    property alias gameNotes: a.gameNotes
    property alias gameWidgets: a.gameWidgets
    property alias gameImage: a.gameImage

    // ── Game bar widgets ──────────────────────────────────────────────
    function gameWidget(id: string): var {
        return (a.gameWidgets ?? []).find(w => w.id === id) ?? null;
    }

    function gameWidgetEnabled(id: string): bool {
        return root.gameWidget(id) !== null;
    }

    function addGameWidget(id: string, x: real, y: real, w: real, h: real, monitor: string): void {
        if (root.gameWidgetEnabled(id)) return;
        a.gameWidgets = a.gameWidgets.concat([{
            id: id, x: x, y: y, w: w, h: h,
            pinned: false, clickthrough: false,
            monitor: monitor ?? "",
            opacity: 1
        }]);
        root.save();
    }

    function removeGameWidget(id: string): void {
        a.gameWidgets = a.gameWidgets.filter(w => w.id !== id);
        root.save();
    }

    // Writes one or more properties of a widget. The array is rebuilt:
    // QML does not detect mutation of a nested object.
    function updateGameWidget(id: string, changes: var): void {
        a.gameWidgets = (a.gameWidgets ?? []).map(w =>
            w.id === id ? Object.assign({}, w, changes) : w);
        root.save();
    }

    // ── Desktop widgets ───────────────────────────────────────────────
    property alias widgets: a.widgets

    // ── Glyph Matrix ──────────────────────────────────────────────────
    property alias glyphEnabled: a.glyphEnabled
    property alias glyphX: a.glyphX
    property alias glyphY: a.glyphY
    property alias glyphSize: a.glyphSize
    property alias glyphAbove: a.glyphAbove
    property alias glyphToy: a.glyphToy
    property alias glyphToys: a.glyphToys

    function hasWidget(id: string): bool { return (a.widgets ?? []).includes(id); }

    function addWidget(id: string): void {
        if (!id || root.hasWidget(id)) return;
        a.widgets = a.widgets.concat([id]);
        root.save();
    }

    function removeWidget(id: string): void {
        a.widgets = a.widgets.filter(x => x !== id);
        root.save();
    }

    function toggleWidget(id: string): void {
        if (root.hasWidget(id)) root.removeWidget(id);
        else root.addWidget(id);
    }

    function recenterGlyph(): void {
        a.glyphX = -1;
        a.glyphY = -1;
        root.save();
    }

    function hasGlyphToy(id: string): bool {
        return (a.glyphToys ?? []).includes(id);
    }

    function toggleGlyphToy(id: string): void {
        const list = (a.glyphToys ?? []).slice();
        const i = list.indexOf(id);
        if (i >= 0) {
            if (list.length <= 1)
                return;
            list.splice(i, 1);
            if (a.glyphToy === id)
                a.glyphToy = list[0];
        } else {
            list.push(id);
        }
        a.glyphToys = list;
        root.save();
    }

    function moveWidget(index: int, delta: int): void {
        const list = a.widgets.slice();
        const to = index + delta;
        if (to < 0 || to >= list.length) return;
        const [item] = list.splice(index, 1);
        list.splice(to, 0, item);
        a.widgets = list;
        root.save();
    }

    // Shipped with the rice (clone: hypr/wallpaper.png, install: ~/.config/hypr/).
    readonly property string bundledWallpaper: Quickshell.shellPath("../../hypr/wallpaper.png")

    // Absolute path, ~ allowed. Empty (and the old Documents path) = bundled.
    readonly property url wallpaperUrl: {
        const w = (a.wallpaper ?? "").trim();
        const home = Quickshell.env("HOME");
        const fallback = root.bundledWallpaper;
        const isDefault = w === ""
            || w === "~/Documents/wallpaper-nothing.png"
            || w === home + "/Documents/wallpaper-nothing.png";
        if (isDefault)
            return "file://" + fallback;
        if (w.startsWith("~/"))
            return "file://" + home + w.slice(1);
        if (w.startsWith("/"))
            return "file://" + w;
        return w;
    }

    function save(): void {
        if (!root.ready)
            return;
        persist.restart();
    }

    function addDockApp(id: string): void {
        if (!id || a.dockApps.includes(id)) return;
        a.dockApps = a.dockApps.concat([id]);
        root.save();
    }

    function removeDockApp(index: int): void {
        const list = a.dockApps.slice();
        list.splice(index, 1);
        a.dockApps = list;
        root.save();
    }

    function moveDockApp(index: int, delta: int): void {
        const list = a.dockApps.slice();
        const to = index + delta;
        if (to < 0 || to >= list.length) return;
        const [item] = list.splice(index, 1);
        list.splice(to, 0, item);
        a.dockApps = list;
        root.save();
    }

    // Every JsonAdapter property, no exceptions: a button that claims to
    // reset "everything" while skipping game mode, the crosshair, night
    // light and the wallpaper is lying about what it does.
    function reset(): void {
        a.scale = 1.0;
        a.accent = "#d71921";
        a.iconTheme = "Nothing";
        a.drawWallpaper = true;
        a.wallpaper = "";

        a.showDock = true;
        a.showDesktopWidgets = true;
        a.widgets = ["date", "weather", "clock", "media"];
        a.showTray = true;
        a.showBattery = true;
        a.showWorkspaces = true;
        a.barShowCpu = true;
        a.barShowRam = true;
        a.barShowGpu = true;
        a.barShowTemp = true;

        a.notificationsEnabled = true;
        a.notificationTimeout = 5;
        a.osdEnabled = true;
        a.essentialEnabled = true;
        a.essentialSide = "right";
        a.mindBackend = "stub";

        a.weatherEnabled = true;
        a.weatherCity = "";

        a.terminal = "kitty";
        a.launcher = "";
        a.fileManager = "dolphin";

        a.dockAutoHide = true;
        a.dockHideDelay = 700;
        a.dockApps = ["firefox", "kitty", "org.kde.dolphin", "spotify", "com.google.Chrome"];

        a.workspaceStyle = "japanese";
        a.workspaceCount = 10;
        a.workspaceRows = 2;
        a.workspaceCols = 5;
        a.workspaceScale = 0.18;

        a.nightAutomatic = false;
        a.nightFrom = "19:00";
        a.nightTo = "06:30";
        a.nightTemperature = 4000;

        a.gameMode = false;
        a.gameNoAnimations = true;
        a.gameNoBlur = true;
        a.gameNoShadow = true;
        a.gameTearing = true;
        a.gameInhibitIdle = true;
        a.gameHideShell = false;
        a.gameUnfocusedFps = 30;
        a.gameFpsLimit = 0;

        a.crosshair = false;
        a.crosshairStyle = "crossdot";
        a.crosshairSize = 14;
        a.crosshairThickness = 2;
        a.crosshairGap = 4;
        a.crosshairColor = "#00ff88";
        a.crosshairOutline = true;

        a.gameWidgets = [];
        a.gameImage = "";

        a.glyphEnabled = true;
        a.glyphX = -1;
        a.glyphY = -1;
        a.glyphSize = 220;
        a.glyphAbove = false;
        a.glyphToy = "clock";
        a.glyphToys = [
            "clock", "battery", "system", "notices", "counter",
            "dice", "timer", "pendulum", "visualizer"
        ];

        // gameNotes is left intact: it is user-written text, not a setting.
        // Resetting the UI should not wipe it.

        root.save();
    }

    // Migration: early versions stored objects
    // { icon, exec, match }. Convert them to .desktop identifiers.
    function migrate(): void {
        const list = a.dockApps ?? [];
        if (list.length > 0 && typeof list[0] !== "string") {
            const ids = [];
            for (const item of list) {
                const id = (typeof item === "string") ? item : (item.exec ?? item.match ?? "");
                if (id !== "" && !ids.includes(id)) ids.push(id);
            }
            a.dockApps = ids;
            root.save();
            console.info("Config: dockApps migrated to .desktop identifiers");
        }

        // The old column widget "glyph" is now a disc toy.
        const widgets = a.widgets ?? [];
        if (widgets.includes("glyph")) {
            a.widgets = widgets.filter(x => x !== "glyph");
            a.glyphEnabled = true;
            root.save();
            console.info("Config: glyph widget moved to Glyph Matrix");
        }
    }

    Process {
        id: mkdir
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    Timer {
        id: persist
        interval: 80
        onTriggered: if (root.ready) file.writeAdapter()
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        preload: true
        blockLoading: true
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.ready)
                persist.restart();
        }
        onLoaded: {
            root.ready = true;
            root.migrate();
        }
        // First launch: write the defaults.
        onLoadFailed: (err) => {
            if (err === FileViewError.FileNotFound) {
                root.ready = true;
                writeAdapter();
            }
        }

        adapter: JsonAdapter {
            id: a

            property real   scale: 1.0
            property string accent: "#d71921"
            property string iconTheme: "Nothing"
            property bool   drawWallpaper: true
            // Empty = hypr/wallpaper.png (see wallpaperUrl).
            property string wallpaper: ""

            property bool showDock: true
            property bool showDesktopWidgets: true

            // Desktop widgets, in display order.
            // Known identifiers: date, weather, clock, media, system, calendar.
            property var widgets: ["date", "weather", "clock", "media"]
            property bool showTray: true
            property bool showBattery: true
            property bool showWorkspaces: true
            property bool barShowCpu: true
            property bool barShowRam: true
            property bool barShowGpu: true
            property bool barShowTemp: true

            property bool notificationsEnabled: true
            property int  notificationTimeout: 5
            property bool osdEnabled: true
            property bool   essentialEnabled: true
            property string essentialSide: "right"   // right | left
            property string mindBackend: "stub"      // stub | ollama | gemini

            property bool   weatherEnabled: true
            property string weatherCity: ""

            property string terminal: "kitty"
            property string launcher: ""
            property string fileManager: "dolphin"

            // .desktop identifiers. The dock only shows those that exist on
            // this machine, so a missing entry is ignored instead of a dead icon.
            property bool dockAutoHide: true
            property int  dockHideDelay: 700   // grace ms after the pointer leaves

            // arabic | roman | japanese
            property string workspaceStyle: "japanese"
            property int workspaceCount: 10

            // Preview grid: 2 rows of 5, thumbnails at 18 % of the screen
            property int  workspaceRows: 2
            property int  workspaceCols: 5
            property real workspaceScale: 0.18

            property bool   nightAutomatic: false
            property string nightFrom: "19:00"
            property string nightTo: "06:30"
            property int    nightTemperature: 4000

            // ── Game mode ─────────────────────────────────────────────
            property bool gameMode: false
            property bool gameNoAnimations: true
            property bool gameNoBlur: true
            property bool gameNoShadow: true
            property bool gameTearing: true
            property bool gameInhibitIdle: true
            property bool gameHideShell: false
            property int  gameUnfocusedFps: 30
            property int  gameFpsLimit: 0        // 0 = unlimited (MangoHud)

            // cross | dot | circle | crossdot | tshape
            property bool   crosshair: false
            property string crosshairStyle: "crossdot"
            property int    crosshairSize: 14
            property int    crosshairThickness: 2
            property int    crosshairGap: 4
            property string crosshairColor: "#00ff88"
            property bool   crosshairOutline: true

            property string gameNotes: ""

            // Game bar canvas: position, size and state of each widget
            // placed on the screen.
            property var gameWidgets: []
            property string gameImage: ""

            // Glyph Matrix: floating disc. x/y at -1 = automatic placement
            // on the right of the screen, until the first drag-and-drop.
            property bool   glyphEnabled: true
            property int    glyphX: -1
            property int    glyphY: -1
            property int    glyphSize: 220
            property bool   glyphAbove: false
            property string glyphToy: "clock"
            property var    glyphToys: [
                "clock", "battery", "system", "notices", "counter",
                "dice", "timer", "pendulum", "visualizer"
            ]

            property var dockApps: [
                "firefox", "kitty", "org.kde.dolphin", "spotify", "com.google.Chrome"
            ]
        }
    }
}
