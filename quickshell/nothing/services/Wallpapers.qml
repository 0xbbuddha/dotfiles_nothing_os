pragma Singleton

import QtQuick
import Quickshell
import ".."

// Resolves Config's wallpaper schema (wallpaper, wallpaperFormat,
// dotWallpaperChar) into an actual file URL. Config only says what was
// picked; this says what that picks out, which is why it was three
// functions and two computed properties living inside the persisted
// schema they read from.
Singleton {
    id: root

    // Shipped with the rice (clone: hypr/wallpaper.png, install: ~/.config/hypr/).
    readonly property string bundledWallpaper: Quickshell.shellPath("../../hypr/wallpaper.png")

    // The bundled dot-matrix pair, chosen by name rather than by path.
    // The same way an empty string already means hypr/wallpaper.png, what
    // is being picked is "the shipped set", and which of its files that
    // is depends on the screen it lands on and the character chosen.
    readonly property string dotWallpaperKey: "nothing-dots"
    readonly property bool dotWallpaperOn:
        (Config.wallpaper ?? "").trim() === root.dotWallpaperKey

    // Known characters ship as a named list rather than a free-text field:
    // typing a name that has no file behind it would silently fall back to
    // Tamaki with no sign anything was wrong.
    readonly property var dotWallpaperChars: [
        { label: "Tamaki",  value: "tamaki" },
        { label: "Frieren", value: "frieren" },
        { label: "Waguri",  value: "waguri" }
    ]

    // The character is explicit, not read off Config, so a picker can
    // ask "what does Tamaki look like" without that answer changing to
    // whichever character happens to be chosen at the moment.
    function dotWallpaperPathFor(character: string, wide: bool): string {
        const c = (character || "tamaki");
        const suffix = c === "tamaki" ? "" : ("-" + c);
        return Quickshell.shellPath("../../hypr/wallpapers/nothing-dots"
            + suffix + "-" + (wide ? "16-9" : "16-10") + ".png");
    }

    function dotWallpaperPath(wide: bool): string {
        return root.dotWallpaperPathFor(Config.dotWallpaperChar, wide);
    }

    // A stored choice (Config.wallpaper, or one screen's entry in
    // Config.wallpaperScreenMap()) to a URL. Empty and the old Documents
    // path mean the bundled image; "nothing-dots" the pair; else a path, ~ allowed.
    function resolve(value: string, w: real, h: real): url {
        const v = (value ?? "").trim();
        if (v === root.dotWallpaperKey) {
            let wide;
            switch (Config.wallpaperFormat) {
            case "16-9":  wide = true; break;
            case "16-10": wide = false; break;
            // 16:10 is 1.600 and 16:9 is 1.778. The midpoint separates them,
            // and anything wider than that (21:9, 32:9) is better served by
            // the wider of the two.
            default:      wide = (w / Math.max(1, h)) > 1.69; break;
            }
            return "file://" + root.dotWallpaperPath(wide);
        }
        const home = Quickshell.env("HOME");
        if (v === "" || v === "~/Documents/wallpaper-nothing.png"
                || v === home + "/Documents/wallpaper-nothing.png")
            return "file://" + root.bundledWallpaper;
        if (v.startsWith("~/"))
            return "file://" + home + v.slice(1);
        if (v.startsWith("/"))
            return "file://" + v;
        return v;
    }

    readonly property url plainWallpaperUrl: root.resolve(Config.wallpaper, 1920, 1080)

    // What a screen shows: its own choice if it has one, else the shared one.
    function valueFor(name: string): string {
        const per = Config.wallpaperScreenMap();
        return (name && per[name]) ? per[name] : (Config.wallpaper ?? "");
    }

    // Per screen. Wallpaper.qml is instantiated once per output, so each
    // one can ask for the frame that fits its own shape and its own image.
    function wallpaperUrlFor(name: string, w: real, h: real): url {
        return root.resolve(root.valueFor(name), w, h);
    }

    // For the callers with no screen to hand (the settings preview, the
    // workspace overview): answer for the first screen.
    readonly property url wallpaperUrl: root.wallpaperUrlFor(
        Quickshell.screens[0]?.name ?? "",
        Quickshell.screens[0]?.width ?? 1920,
        Quickshell.screens[0]?.height ?? 1200)

    // ── Choosing ──────────────────────────────────────────────────────
    // screen "" = every screen: the shared choice, and any per-screen ones
    // dropped, so "all" means all. A screen name = that screen only.
    function set(value: string, screen: string): void {
        const v = String(value ?? "").trim();
        if (screen === "") {
            Config.wallpaper = v;
            Config.clearWallpaperScreens();
        } else {
            Config.setWallpaperScreen(screen, v);
        }
        Config.save();
    }

    function isCurrent(value: string, screen: string): bool {
        return root.valueFor(screen) === value;
    }

    // ── Folder slideshow ──────────────────────────────────────────────
    // Next picture from the wallpaper folder (Walls.folderFiles): shuffled
    // without repeating the one on screen, or in name order. Applied to
    // every screen, or to each screen separately with different pictures
    // when "different on each screen" is on.
    function next(): void {
        // A turn of the slideshow is not news: no popup for it.
        root.quiet = true;
        quietOff.restart();
        const list = Walls.folderFiles;
        if (list.length === 0) {
            Walls.refresh();
            return;
        }
        const screens = Quickshell.screens.map(s => s.name);
        if (Config.wallpaperEachScreen && screens.length > 1) {
            const used = [];
            let first = "";
            for (const n of screens) {
                const pick = root.pickAfter(root.valueFor(n), list, used);
                Config.setWallpaperScreen(n, pick);
                used.push(pick);
                if (n === screens[0]) first = pick;
            }
            Config.wallpaper = first;
            Config.save();
            return;
        }
        root.set(root.pickAfter(Config.wallpaper, list, []), "");
    }

    function pickAfter(cur: string, list: var, avoid: var): string {
        const pool = list.filter(f => f !== cur && avoid.indexOf(f) < 0);
        const from = pool.length > 0 ? pool : list;
        if (Config.wallpaperShuffle)
            return from[Math.floor(Math.random() * from.length)];
        const i = list.indexOf(cur);
        for (let k = 1; k <= list.length; k++) {
            const f = list[(i + k + list.length) % list.length];
            if (from.indexOf(f) >= 0)
                return f;
        }
        return from[0];
    }

    // Config.wallpaperRotate minutes, 0 = never. Counted from shell start
    // or the last change, never catching up on missed turns.
    Timer {
        interval: Math.max(1, Config.wallpaperRotate) * 60000
        repeat: true
        running: Config.wallpaperRotate > 0 && Config.drawWallpaper
        onTriggered: root.next()
    }

    // ── Telling you ───────────────────────────────────────────────────
    // A popup on every real change, the same way a reload that failed
    // tells you rather than leaving you to notice. Lives here rather
    // than in Wallpaper.qml: that one is instantiated once per screen,
    // and a change would otherwise say so once per monitor rather than
    // once per change. Silent for the slideshow's own turns.
    property bool quiet: false
    Timer { id: quietOff; interval: 500; onTriggered: root.quiet = false }

    function announce(): void {
        if (root.quiet)
            return;
        const label = root.dotWallpaperOn
            ? (root.dotWallpaperChars.find(c => c.value === Config.dotWallpaperChar)?.label ?? "Custom")
            : ((Config.wallpaper ?? "").split("/").pop() || "Custom");
        const thumb = root.dotWallpaperOn
            ? root.dotWallpaperPath(true)
            : String(root.plainWallpaperUrl).replace("file://", "");
        WallpaperAnnounce.announce(label, thumb);
    }

    Connections {
        target: Config
        function onWallpaperChanged(): void { root.announce(); }
        function onDotWallpaperCharChanged(): void {
            if (root.dotWallpaperOn) root.announce();
        }
    }
}
