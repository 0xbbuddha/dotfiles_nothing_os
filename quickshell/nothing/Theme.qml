pragma Singleton

import QtQuick
import Quickshell

// All dimensions go through here and are multiplied by Config.scale.
// Type scale kept deliberately small: Nothing's text is small and very
// spaced out - the empty space carries the layout.
Singleton {
    id: root

    readonly property real s: Config.scale
    function px(v: real): int { return Math.round(v * root.s); }

    // ── Palette Nothing OS ────────────────────────────────────────────
    // Nothing ships both looks. The numbered surfaces read the same way in
    // either: the higher the number, the further the surface stands out
    // from the panel it sits on. Dark goes black to grey, light goes white
    // to grey, so every call site keeps its meaning without being touched.
    readonly property bool light: Config.theme === "light"

    readonly property QtObject c: QtObject {
        readonly property color bg:       "#c4c4c4"   // under the wallpaper
        readonly property color surface:  root.light ? "#ffffff" : "#0b0b0b"
        readonly property color surface2: root.light ? "#f1f1f1" : "#161616"
        readonly property color surface3: root.light ? "#e4e4e4" : "#212121"
        readonly property color on:       root.light ? "#0b0b0b" : "#ffffff"
        readonly property color onDim:    root.light ? "#6e6e6e" : "#8a8a8a"
        readonly property color onFaint:  root.light ? "#b4b4b4" : "#454545"
        readonly property color red:      Config.accent
        // Ink for whatever sits ON the accent. It cannot just follow the
        // theme: the accent is the user's choice and the presets include
        // white, where white ink scores a contrast of exactly 1.00 and the
        // content simply disappears. Picked by contrast instead.
        readonly property color onAccent: ColorUtils.readableOn(Config.accent)
        readonly property color outline:  root.light ? "#dcdcdc" : "#2a2a2a"
        readonly property color scrim:    root.light ? Qt.rgba(0, 0, 0, 0.35)
                                                     : Qt.rgba(0, 0, 0, 0.6)

        // Text laid over album art. The art has a dark gradient under it in
        // both themes, so this stays light: following `on` would turn the
        // track title black on a black scrim as soon as the theme went
        // light, and the title would vanish.
        readonly property color onArt:    "#ffffff"
        readonly property color onArtDim: Qt.rgba(1, 1, 1, 0.62)
    }

    // A translucent veil in the direction that contrasts with the current
    // surface: white over black, black over white. Use this wherever a
    // hardcoded Qt.rgba(1,1,1,a) or Qt.rgba(0,0,0,a) meant "lift this a
    // little off its background" rather than a genuine black.
    function veil(a: real): color {
        return root.light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a);
    }

    // A genuinely dark veil, for what sits on album art or a screenshot,
    // where the background is an image and never the theme.
    function shade(a: real): color { return Qt.rgba(0, 0, 0, a); }

    // A translucent panel, for a card floating over the wallpaper rather
    // than over another panel.
    function pane(a: real): color {
        return ColorUtils.applyAlpha(root.c.surface, a);
    }

    // ── Typo ──────────────────────────────────────────────────────────
    // display : the real Nothing Ndot (ttf-nothing-font-git package)
    // sans    : Inter, the Nothing OS UI grotesque
    // mono    : aligned digits (fixed pitch)
    // glyphs  : proportional Nerd Font icons - in mono, the Wi-Fi
    //           overflows its cell and looks off-centre in a circle.
    readonly property QtObject f: QtObject {
        readonly property string display: "Ndot77JPExtended"
        readonly property string sans: "Inter Variable"
        readonly property string mono: "JetBrainsMono NF"
        readonly property string glyphs: "JetBrainsMono Nerd Font Propo"

        readonly property int micro: root.px(9)    // tracked labels
        readonly property int tiny:  root.px(10)
        readonly property int small: root.px(11)
        readonly property int body:  root.px(13)
        readonly property int big:   root.px(16)
        readonly property int huge:  root.px(22)

        // Tracking for small uppercase labels, a Nothing signature
        readonly property real track: 1.4
    }

    // ── Rayons ────────────────────────────────────────────────────────
    readonly property QtObject r: QtObject {
        readonly property int pill: 999
        readonly property int card: root.px(20)
        readonly property int chip: root.px(13)
        readonly property int tiny: root.px(8)
    }

    // ── Dimensions ────────────────────────────────────────────────────
    readonly property QtObject z: QtObject {
        readonly property int bar:      root.px(30)
        readonly property int barWin:   root.px(42)

        readonly property int icon:  root.px(11)
        readonly property int iconM: root.px(13)
        readonly property int iconL: root.px(16)

        readonly property int dock:     root.px(46)
        readonly property int dockSlot: root.px(34)
        readonly property int dockIcon: root.px(20)

        readonly property int panel:    root.px(520)
        readonly property int settings: root.px(560)
        readonly property int sheet:    root.px(440)

        readonly property int widgets: root.px(296)
        readonly property int cardS:   root.px(116)

        readonly property real dot:  root.px(4)
        readonly property real knob: root.px(10)
        readonly property real rail: root.px(3)
    }

    // Spacing: more generous than before - that was the main gap.
    readonly property int gap: root.px(9)
    readonly property int pad: root.px(14)
    readonly property int padCard: root.px(12)

    // ── Animations: dry, fast, no bounce ──────────────────────────────
    readonly property int fast: 130
    readonly property int med: 240
    readonly property int slow: 380
    readonly property var ease: Easing.OutExpo
}
