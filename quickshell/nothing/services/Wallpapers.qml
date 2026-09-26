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
        { label: "Frieren", value: "frieren" }
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

    // Absolute path, ~ allowed. Empty (and the old Documents path) = bundled.
    readonly property url plainWallpaperUrl: {
        const w = (Config.wallpaper ?? "").trim();
        const home = Quickshell.env("HOME");
        const fallback = root.bundledWallpaper;
        const isDefault = w === ""
            || w === root.dotWallpaperKey
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

    // Per screen. Wallpaper.qml is instantiated once per output, so each
    // one can ask for the frame that fits its own shape: the 16:10 laptop
    // and the 16:9 external stop sharing a picture cropped for neither.
    function wallpaperUrlFor(w: real, h: real): url {
        if (!root.dotWallpaperOn)
            return root.plainWallpaperUrl;
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

    // For the callers with no screen to hand (the settings preview, the
    // workspace overview): answer for the first screen.
    readonly property url wallpaperUrl: root.dotWallpaperOn
        ? root.wallpaperUrlFor(Quickshell.screens[0]?.width ?? 1920,
                               Quickshell.screens[0]?.height ?? 1200)
        : root.plainWallpaperUrl

    // A popup on every real change, the same way a reload that failed
    // tells you rather than leaving you to notice. Lives here rather
    // than in Wallpaper.qml: that one is instantiated once per screen,
    // and a change would otherwise say so once per monitor rather than
    // once per change.
    function announce(): void {
        const label = root.dotWallpaperOn
            ? (root.dotWallpaperChars.find(c => c.value === Config.dotWallpaperChar)?.label ?? "Custom")
            : "Custom";
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
