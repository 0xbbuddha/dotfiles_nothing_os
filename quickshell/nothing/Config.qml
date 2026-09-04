pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services"

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
    property alias theme: a.theme
    property alias accent: a.accent
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
    property alias essentialSearch: a.essentialSearch
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

    // Falls back to the standard picture folder rather than storing that
    // path: a config written on one machine then read on another with a
    // different locale would point at a folder that does not exist.
    readonly property string photoDir: a.photoDir !== ""
        ? a.photoDir
        : `${Quickshell.env("HOME")}/Pictures`

    property alias worldClocks: a.worldClocks
    property alias screenTimeLimit: a.screenTimeLimit

    // ── Essential Apps ────────────────────────────────────────────────
    property alias deskApps: a.deskApps
    property alias showDeskApps: a.showDeskApps
    property alias appsKey: a.appsKey

    // ── Lock screen ───────────────────────────────────────────────────
    property alias lockScreen: a.lockScreen

    // ── Glyph Matrix ──────────────────────────────────────────────────
    property alias glyphEnabled: a.glyphEnabled
    property alias glyphX: a.glyphX
    property alias glyphY: a.glyphY
    property alias glyphSize: a.glyphSize
    property alias glyphAbove: a.glyphAbove
    property alias glyphToy: a.glyphToy
    property alias glyphToys: a.glyphToys

    // The Glyph Bar: its own placement, because it is a different shape
    // from the Matrix and sharing one position would put a tall strip
    // where a round disc used to be.
    property alias glyphBarEnabled: a.glyphBarEnabled
    property alias glyphBarX: a.glyphBarX
    property alias glyphBarY: a.glyphBarY
    property alias glyphBarLength: a.glyphBarLength
    property alias glyphBarAbove: a.glyphBarAbove
    // Shared by every event-driven Glyph surface: only one is ever lit, so
    // which sources you care about is a property of you, not of the shape.
    // Per surface. Shared at first, on the reasoning that only one Glyph
    // is on at a time so the settings belong to you rather than the shape.
    // Two things were wrong with that: switching surface carried over
    // choices made for a different one, and the channel list cannot be
    // shared at all, because the Strip has three sectors and the Bar six.
    //
    // Composed rhythms stay common: a rhythm addresses zone groups, so it
    // plays on any of the three.
    // What you are counting to. One countdown, not a list: the widget
    // system keys on the id, so a second countdown would be a second
    // widget, and Nothing's own is one per placed card too.
    property alias countdownLabel: a.countdownLabel
    property alias countdownDate: a.countdownDate
    property alias countdownShape: a.countdownShape

    // The Glyph Strip: the ring of arcs around the camera, Phone (3a).
    property alias glyphStripEnabled: a.glyphStripEnabled
    property alias glyphStripX: a.glyphStripX
    property alias glyphStripY: a.glyphStripY
    property alias glyphStripSize: a.glyphStripSize
    property alias glyphStripAbove: a.glyphStripAbove

    property alias glyphCustom: a.glyphCustom

    readonly property var glyphSurfaces: ["matrix", "bar", "strip"]

    // Only these three sources have a rhythm to choose. The others are not
    // events with a shape: a level, a state that lasts, a snapshot.
    readonly property var glyphRhythmSources: ["notify", "battery", "media"]

    // Spelled out rather than reached by name. Building the property name
    // and indexing the adapter with it read every value as its default:
    // bracket access does not resolve these. Verbose, and it works.
    function _list(v: var): var {
        if (!v || typeof v !== "object" || v.length === undefined)
            return null;
        const out = [];
        for (let i = 0; i < v.length; i++)
            out.push(v[i]);
        return out;
    }

    function glyphEventsOf(surface: string): var {
        switch (surface) {
        case "matrix": return root._list(a.glyphEventsMatrix) ?? [];
        case "strip":  return root._list(a.glyphEventsStrip) ?? [];
        default:       return root._list(a.glyphEventsBar) ?? [];
        }
    }

    function toggleGlyphEvent(surface: string, id: string): void {
        const list = root.glyphEventsOf(surface);
        const at = list.indexOf(id);
        if (at >= 0)
            list.splice(at, 1);
        else
            list.push(id);
        switch (surface) {
        case "matrix": a.glyphEventsMatrix = list; break;
        case "strip":  a.glyphEventsStrip = list; break;
        default:       a.glyphEventsBar = list; break;
        }
        root.save();
    }

    function glyphQuietOf(surface: string): bool {
        switch (surface) {
        case "matrix": return a.glyphQuietMatrix;
        case "strip":  return a.glyphQuietStrip;
        default:       return a.glyphQuietBar;
        }
    }

    function setGlyphQuiet(surface: string, on: bool): void {
        switch (surface) {
        case "matrix": a.glyphQuietMatrix = on; break;
        case "strip":  a.glyphQuietStrip = on; break;
        default:       a.glyphQuietBar = on; break;
        }
        root.save();
    }

    function glyphLevelOf(surface: string): int {
        switch (surface) {
        case "matrix": return a.glyphLevelMatrix;
        case "strip":  return a.glyphLevelStrip;
        default:       return a.glyphLevelBar;
        }
    }

    function setGlyphLevel(surface: string, level: int): void {
        const v = Math.max(0, Math.min(2, level));
        switch (surface) {
        case "matrix": a.glyphLevelMatrix = v; break;
        case "strip":  a.glyphLevelStrip = v; break;
        default:       a.glyphLevelBar = v; break;
        }
        root.save();
    }

    function glyphChannelsOf(surface: string): var {
        switch (surface) {
        case "matrix": return root._list(a.glyphChannelsMatrix) ?? [];
        case "strip":  return root._list(a.glyphChannelsStrip) ?? [];
        default:       return root._list(a.glyphChannelsBar) ?? [];
        }
    }

    function setGlyphChannel(surface: string, index: int, id: string): void {
        const list = root.glyphChannelsOf(surface);
        while (list.length < 6)
            list.push("off");
        if (index < 0 || index >= 6)
            return;
        list[index] = id;
        switch (surface) {
        case "matrix": a.glyphChannelsMatrix = list; break;
        case "strip":  a.glyphChannelsStrip = list; break;
        default:       a.glyphChannelsBar = list; break;
        }
        root.save();
    }

    // Validated where it is played, not here: a composed pattern lives in
    // this file, so asking the built-in library whether it exists would
    // have thrown every custom rhythm away on the next read.
    function glyphPattern(surface: string, source: string): string {
        let p = "";
        if (surface === "matrix")
            p = source === "battery" ? a.glyphPatternMatrixBattery
              : source === "media"   ? a.glyphPatternMatrixMedia
              :                        a.glyphPatternMatrixNotify;
        else if (surface === "strip")
            p = source === "battery" ? a.glyphPatternStripBattery
              : source === "media"   ? a.glyphPatternStripMedia
              :                        a.glyphPatternStripNotify;
        else
            p = source === "battery" ? a.glyphPatternBarBattery
              : source === "media"   ? a.glyphPatternBarMedia
              :                        a.glyphPatternBarNotify;
        return (typeof p === "string" && p !== "") ? p : "double";
    }

    function setGlyphPattern(surface: string, source: string,
                             pattern: string): void {
        if (surface === "matrix") {
            if (source === "battery")   a.glyphPatternMatrixBattery = pattern;
            else if (source === "media") a.glyphPatternMatrixMedia = pattern;
            else                         a.glyphPatternMatrixNotify = pattern;
        } else if (surface === "strip") {
            if (source === "battery")   a.glyphPatternStripBattery = pattern;
            else if (source === "media") a.glyphPatternStripMedia = pattern;
            else                         a.glyphPatternStripNotify = pattern;
        } else {
            if (source === "battery")   a.glyphPatternBarBattery = pattern;
            else if (source === "media") a.glyphPatternBarMedia = pattern;
            else                         a.glyphPatternBarNotify = pattern;
        }
        root.save();
    }

    function stepGlyphPattern(surface: string, source: string, by: int): void {
        const list = GlyphEvents.patterns;
        const cur = root.glyphPattern(surface, source);
        let at = list.findIndex(p => p.id === cur);
        if (at < 0)
            at = 0;
        root.setGlyphPattern(surface, source,
            list[(at + by + list.length) % list.length].id);
    }

    // ── Which Glyph is on ─────────────────────────────────────────────
    //
    // The order a shortcut walks them. "" is all off, and it has to be one
    // of the stops: a cycle that cannot reach silence is one you have to
    // open a panel to escape.
    readonly property var glyphOrder: ["", "matrix", "bar", "strip"]

    function activeGlyph(): string {
        if (a.glyphEnabled)      return "matrix";
        if (a.glyphBarEnabled)   return "bar";
        if (a.glyphStripEnabled) return "strip";
        return "";
    }

    function cycleGlyph(by: int): string {
        const order = root.glyphOrder;
        const at = order.indexOf(root.activeGlyph());
        const n = order.length;
        const next = order[(((at + by) % n) + n) % n];
        a.glyphEnabled      = next === "matrix";
        a.glyphBarEnabled   = next === "bar";
        a.glyphStripEnabled = next === "strip";
        root.save();
        return next;
    }

    // One at a time: they are the same object on the phone, a Matrix or a
    // Bar or a ring depending which you own. Turning one off leaves them
    // all off, which is allowed; this only forbids having two.
    function enableGlyph(id: string, on: bool): void {
        if (id === "matrix")
            a.glyphEnabled = on;
        else if (id === "bar")
            a.glyphBarEnabled = on;
        else if (id === "strip")
            a.glyphStripEnabled = on;
        else
            return;

        if (on) {
            if (id !== "matrix") a.glyphEnabled = false;
            if (id !== "bar")    a.glyphBarEnabled = false;
            if (id !== "strip")  a.glyphStripEnabled = false;
        }
        root.save();
    }

    function addGlyphCustom(label: string, steps: var): string {
        const list = (a.glyphCustom ?? []).slice();
        // Time-stamped rather than counted: deleting one and composing
        // another must not hand out an id a source is still pointing at.
        const id = "own-" + Date.now().toString(36);
        list.push({ id: id, label: label, steps: steps });
        a.glyphCustom = list;
        root.save();
        return id;
    }

    function removeGlyphCustom(id: string): void {
        a.glyphCustom = (a.glyphCustom ?? []).filter(c => c.id !== id);
        // Anything pointing at it falls back, on every surface, or a
        // deleted rhythm would leave a source silently doing nothing.
        for (const surface of root.glyphSurfaces)
            for (const source of root.glyphRhythmSources)
                if (root.glyphPattern(surface, source) === id)
                    root.setGlyphPattern(surface, source, "double");
        root.save();
    }

    // Cities on the world clock. Ordered, because the widget reads them
    // top to bottom, and capped at four because that is what the card can
    // hold without the rows closing up.
    readonly property int worldClockMax: 4

    function hasCity(zone: string): bool {
        return (a.worldClocks ?? []).indexOf(zone) >= 0;
    }

    function toggleCity(zone: string): void {
        if (!zone) return;
        const list = (a.worldClocks ?? []).slice();
        const at = list.indexOf(zone);
        if (at >= 0)
            list.splice(at, 1);
        else if (list.length < root.worldClockMax)
            list.push(zone);
        else
            return;             // full: drop one first, silently doing it
                                // for them would lose a city they chose.
        a.worldClocks = list;
        root.save();
    }

    function moveCity(index: int, by: int): void {
        const list = (a.worldClocks ?? []).slice();
        const to = index + by;
        if (index < 0 || index >= list.length || to < 0 || to >= list.length)
            return;
        const [it] = list.splice(index, 1);
        list.splice(to, 0, it);
        a.worldClocks = list;
        root.save();
    }

    function hasWidget(id: string): bool {
        return (a.widgets ?? []).includes(id);
    }

    function addWidget(id: string): void {
        if (!id || root.hasWidget(id)) return;
        a.widgets = (a.widgets ?? []).concat([id]);
        root.save();
    }

    function removeWidget(id: string): void {
        a.widgets = (a.widgets ?? []).filter(x => x !== id);
        root.save();
    }

    function toggleWidget(id: string): void {
        if (root.hasWidget(id)) root.removeWidget(id);
        else root.addWidget(id);
    }

    // Picking a face swaps it in, it does not stack a second one.
    //
    // Choosing "Clock, dial" when the Ndot clock was already there used to
    // leave you with two clocks, which is never what picking a different
    // face means. Only one widget of a family sits on the desktop, and the
    // replacement takes the place the old one held, so the column does not
    // reshuffle under a change of mind.
    function chooseWidget(id: string): void {
        if (!id) return;
        if (root.hasWidget(id)) {
            root.removeWidget(id);
            return;
        }
        const group = WidgetRegistry.group(id);
        const list = (a.widgets ?? []).slice();
        const at = group === ""
            ? -1
            : list.findIndex(x => WidgetRegistry.group(x) === group);
        if (at >= 0)
            list[at] = id;
        else
            list.push(id);
        a.widgets = list;
        root.save();
    }

    function moveWidget(index: int, delta: int): void {
        const list = (a.widgets ?? []).slice();
        const to = index + delta;
        if (to < 0 || to >= list.length) return;
        const [item] = list.splice(index, 1);
        list.splice(to, 0, item);
        a.widgets = list;
        root.save();
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

    // ── Essential Apps on the desktop ─────────────────────────────────
    // The rice's own widgets hold the left column; generated apps get
    // the right one, so a bad prompt can never disturb the stock layout.

    function hasDeskApp(id: string): bool {
        return (a.deskApps ?? []).includes(id);
    }

    function addDeskApp(id: string): void {
        if (!id || root.hasDeskApp(id)) return;
        a.deskApps = (a.deskApps ?? []).concat([id]);
        root.save();
    }

    function removeDeskApp(id: string): void {
        if (!root.hasDeskApp(id)) return;
        a.deskApps = (a.deskApps ?? []).filter(x => x !== id);
        root.save();
    }

    function toggleDeskApp(id: string): void {
        if (root.hasDeskApp(id)) root.removeDeskApp(id);
        else root.addDeskApp(id);
    }

    function moveDeskApp(index: int, delta: int): void {
        const list = (a.deskApps ?? []).slice();
        const to = index + delta;
        if (to < 0 || to >= list.length) return;
        const [item] = list.splice(index, 1);
        list.splice(to, 0, item);
        a.deskApps = list;
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
        a.theme = "dark";
        a.accent = "#d71921";
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
        a.essentialSearch = true;
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
        a.glyphBarEnabled = false;
        a.glyphBarX = -1;
        a.glyphBarY = -1;
        a.glyphBarLength = 300;
        a.glyphBarAbove = false;
        for (const surface of root.glyphSurfaces) {
            root.toggleGlyphEvent(surface, "");   // no-op, keeps the shape
            root.setGlyphQuiet(surface, true);
            root.setGlyphLevel(surface, 1);
            root.setGlyphPattern(surface, "notify", "double");
            root.setGlyphPattern(surface, "battery", "blink");
            root.setGlyphPattern(surface, "media", "blink");
        }
        a.glyphCustom = [];
        a.glyphStripEnabled = false;
        a.glyphStripX = -1;
        a.glyphStripY = -1;
        a.glyphStripSize = 240;
        a.glyphStripAbove = false;
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

        // These were one flat set shared by every surface. Per surface
        // now, so the same values become each one's starting point rather
        // than being reset: nobody loses what they had chosen.

        // The old column widget "glyph" is now a disc toy.
        let widgets = a.widgets ?? [];
        if (widgets.some(w => w === "glyph" || w?.id === "glyph")) {
            widgets = widgets.filter(w => (w?.id ?? w) !== "glyph");
            a.widgets = widgets;
            a.glyphEnabled = true;
            root.save();
            console.info("Config: glyph widget moved to Glyph Matrix");
        }

        // Widgets were briefly cells on a free grid. That is undone:
        // they stack in a column again, so only the order survives, taken
        // from how far down the screen each one had been dropped.
        if (widgets.length > 0 && typeof widgets[0] === "object") {
            a.widgets = widgets
                .slice()
                .sort((x, y) => (x?.row ?? 0) - (y?.row ?? 0))
                .map(w => w?.id ?? "")
                .filter(id => id !== "");
            root.save();
            console.info("Config: widgets back to an ordered column");
        }
    }

    NProcess {
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
            // "dark" or "light". Nothing OS ships both; the dark one is the
            // signature look, so it stays the default.
            property string theme: "dark"
            property string accent: "#d71921"
            property bool   drawWallpaper: true
            // Empty = hypr/wallpaper.png (see wallpaperUrl).
            property string wallpaper: ""

            property bool showDock: true
            property bool showDesktopWidgets: true

            // Desktop widgets and where they sit, as cells of a logical
            // fixed-size grid (see Desktop.qml). Heights stay natural:
            // the media tile grows with the number of players and the
            // system tile with zram and swap, so only the anchor and the
            // width in columns are stored.
            // Known identifiers: date, weather, clock, media, system, calendar.
            property var widgets: ["date", "weather", "clock", "media"]

            // Minutes at the machine before the screen-time face frowns.
            property int screenTimeLimit: 240

            // Cities for the world clock, as tz database zone names.
            property string countdownLabel: "New year"
            property string countdownDate: ""
            property int countdownShape: 0

            property var worldClocks: ["Europe/Paris", "America/New_York",
                                       "Asia/Tokyo", "Australia/Sydney"]

            // Where the photo widget looks. Empty means the usual place.
            property string photoDir: ""

            // Essential Apps pinned to the right column, in display order.
            property var deskApps: []
            property bool showDeskApps: true
            // Bar button, left of the clock, mirroring the Essential Key.
            property bool appsKey: true

            // hyprlock | shell. The shell's own lock draws in the Nothing
            // language and varies the mark per character, but a lock
            // screen is not a thing to switch by default: hyprlock keeps
            // it until you have tried the other.
            property string lockScreen: "hyprlock"
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
            property bool   essentialSearch: true    // mix captures + Ask in SUPER
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
            property bool glyphBarEnabled: false
            property int glyphBarX: -1
            property int glyphBarY: -1
            property int glyphBarLength: 300
            property bool glyphBarAbove: false
            // Per surface, one property each, spelled out.
            //
            // Not a map keyed by surface: a JsonAdapter property declared
            // with an empty object default never loads anything from the
            // file, so every nested map read back as {} and every setting
            // silently fell to its default. The properties that do work
            // here all have a concrete default, so these do too.
            property var glyphEventsMatrix: ["volume", "notify", "recording", "reveal"]
            property var glyphEventsBar:    ["volume", "notify", "recording", "reveal"]
            property var glyphEventsStrip:  ["volume", "notify", "recording", "reveal"]

            property var glyphChannelsMatrix: ["battery", "volume", "cpu", "ram", "net", "notifs"]
            property var glyphChannelsBar:    ["battery", "volume", "cpu", "ram", "net", "notifs"]
            property var glyphChannelsStrip:  ["battery", "volume", "cpu", "ram", "net", "notifs"]

            // One string per surface per source, not a map. A JsonAdapter
            // var declared with an object default never loads from the
            // file; one declared with a list does. Strings always do.
            property string glyphPatternMatrixNotify:  "double"
            property string glyphPatternMatrixBattery: "blink"
            property string glyphPatternMatrixMedia:   "blink"
            property string glyphPatternBarNotify:     "double"
            property string glyphPatternBarBattery:    "blink"
            property string glyphPatternBarMedia:      "blink"
            property string glyphPatternStripNotify:   "double"
            property string glyphPatternStripBattery:  "blink"
            property string glyphPatternStripMedia:    "blink"

            property bool glyphQuietMatrix: true
            property bool glyphQuietBar: true
            property bool glyphQuietStrip: true

            property int glyphLevelMatrix: 1
            property int glyphLevelBar: 1
            property int glyphLevelStrip: 1

            // Composed in the launcher. { id, label, steps }.
            property var glyphCustom: []


            property bool glyphStripEnabled: false
            property int glyphStripX: -1
            property int glyphStripY: -1
            property int glyphStripSize: 240
            property bool glyphStripAbove: false
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
