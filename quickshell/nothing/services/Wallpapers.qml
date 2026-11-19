pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Resolves Config's wallpaper schema (wallpaper, dotWallpaperChar) into
// an actual file URL. Config only says what was picked; this says what
// that picks out, which is why it was three functions and two computed
// properties living inside the persisted schema they read from.
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

    // Shipped defaults, one file each rather than tamaki/frieren/waguri's
    // 16:9-and-16:10 pair: these came in at a single ratio, and a second,
    // stretched or padded crop manufactured from it would be worse than
    // just not offering one. Named rather than free-text for the same
    // reason the old set was: typing a name with no file behind it would
    // silently fall back to the first one with no sign anything was wrong.
    readonly property var dotWallpaperChars: [
        { label: "Nothing, dark",  value: "nothing-dark" },
        { label: "Nothing, light", value: "nothing-light" },
        { label: "Manga, dark",    value: "manga-dark" },
        { label: "Manga, light",   value: "manga-light" }
    ]

    // The name is explicit, not read off Config, so a picker can ask
    // "what does this one look like" without that answer changing to
    // whichever one happens to be chosen at the moment.
    function dotWallpaperPathFor(name: string): string {
        const n = root.dotWallpaperChars.find(c => c.value === name)
            ? name : root.dotWallpaperChars[0].value;
        return Quickshell.shellPath("../../hypr/wallpapers/" + n + ".png");
    }

    function dotWallpaperPath(): string {
        return root.dotWallpaperPathFor(Config.dotWallpaperChar);
    }

    // A stored choice (Config.wallpaper, or one screen's entry in
    // Config.wallpaperScreenMap()) to a URL. Empty and the old Documents
    // path mean the bundled image; "nothing-dots" the shipped set; else a
    // path, ~ allowed.
    function resolve(value: string): url {
        const v = (value ?? "").trim();
        if (v === root.dotWallpaperKey)
            return "file://" + root.dotWallpaperPath();
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

    readonly property url plainWallpaperUrl: root.resolve(Config.wallpaper)

    // What a screen shows: its own choice if it has one, else the shared one.
    function valueFor(name: string): string {
        const per = Config.wallpaperScreenMap();
        return (name && per[name]) ? per[name] : (Config.wallpaper ?? "");
    }

    // Per screen. Wallpaper.qml is instantiated once per output. w/h are
    // its own screen's size - no longer read here now that the shipped
    // set is one file each instead of a 16:9-or-16:10 pick, kept in the
    // signature anyway so neither caller has to change what it passes.
    function wallpaperUrlFor(name: string, w: real, h: real): url {
        return root.resolve(root.valueFor(name));
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

    // ── Glass ─────────────────────────────────────────────────────────
    // Nothing's fluted-glass wallpaper style (scripts/glass-wallpaper.py),
    // offered from both Settings and the picker rather than built twice:
    // pick a photo, run it through the filter, set the result. One fixed
    // output file, not a gallery - picking a new photo replaces it, the
    // same way the bundled picture is just one file too.
    property bool glassBusy: false
    property string glassTarget: ""
    readonly property string glassScript:
        Quickshell.shellPath("../../scripts/glass-wallpaper.py")
    readonly property string glassOut:
        Quickshell.env("HOME") + "/.local/share/nothing/wallpapers/glass.png"

    function glassify(target: string): void {
        if (root.glassBusy)
            return;
        root.glassTarget = target;
        glassPick.running = true;
    }

    NProcess {
        id: glassPick
        command: ["zenity", "--file-selection", "--title=Choose a photo for the glass effect",
                  "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p === "")
                    return;
                root.glassBusy = true;
                glassRun.command = ["python3", root.glassScript, p, root.glassOut];
                glassRun.running = true;
            }
        }
    }

    NProcess {
        id: glassRun
        command: []
        onExited: (code) => {
            root.glassBusy = false;
            if (code === 0)
                root.set(root.glassOut, root.glassTarget);
        }
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
            ? root.dotWallpaperPath()
            : String(root.plainWallpaperUrl).replace("file://", "");
        WallpaperAnnounce.announce(label, thumb);
    }

    // Config.ready guards both: without it, the popup showed on every
    // reload and every login too, firing the instant the saved value
    // was read off disk and assigned for the first time - a config
    // load, not a change anyone made.
    Connections {
        target: Config
        function onWallpaperChanged(): void {
            if (Config.ready) root.announce();
        }
        function onDotWallpaperCharChanged(): void {
            if (Config.ready && root.dotWallpaperOn) root.announce();
        }
    }
}
