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
    readonly property QtObject c: QtObject {
        readonly property color bg:       "#c4c4c4"
        readonly property color surface:  "#0b0b0b"   // black panels
        readonly property color surface2: "#161616"   // inner cards
        readonly property color surface3: "#212121"   // rails, hover
        readonly property color on:       "#ffffff"
        readonly property color onDim:    "#8a8a8a"
        readonly property color onFaint:  "#454545"
        readonly property color red:      Config.accent
        readonly property color redDim:   Qt.darker(Config.accent, 2.4)
        readonly property color outline:  "#2a2a2a"
        readonly property color scrim:    Qt.rgba(0, 0, 0, 0.6)
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
