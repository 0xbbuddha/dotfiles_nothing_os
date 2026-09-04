import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The floating Glyph Strip. Handled exactly like the Bar: pick it up, put
// it where you want, and the rest of the desktop stays clickable because
// the window is masked to the disc alone.
//
// Two surfaces, both mapped for the whole session, one on the desktop and
// one on the overlay. Unmapping the idle one was tried on the Bar and was
// wrong twice over: Hyprland animates a layer surface appearing, and a
// fullscreen window covers the Top layer, so a notification arriving
// during a film went unseen. Neither is this widget's problem to solve
// again, so it copies the answer.
PanelWindow {
    id: win
    required property var modelData
    property bool above: false

    readonly property bool lifted: Config.glyphStripAbove
        || (GlyphEvents.event !== "" && !GlyphEvents.dragging)

    readonly property bool showing: win.above ? win.lifted : !win.lifted

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: win.above ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: win.above ? "nothing-glyphstrip-over"
                                       : "nothing-glyphstrip"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    // Round, because the thing is a ring. A rectangular mask would take
    // clicks from the empty middle, where there is nothing to click.
    mask: Region {
        item: win.showing ? disc : null
        shape: RegionShape.Ellipse
    }

    Component.onCompleted: win.place()
    onWidthChanged: win.place()
    onHeightChanged: win.place()

    Connections {
        target: Config
        function onGlyphStripXChanged(): void { win.place(); }
        function onGlyphStripYChanged(): void { win.place(); }
        function onGlyphStripSizeChanged(): void { win.place(); }
    }

    function place(): void {
        if (grip.drag.active)
            return;
        const s = Config.glyphStripSize;
        const w = win.width, h = win.height;
        if (w <= 0 || h <= 0)
            return;
        if (Config.glyphStripX < 0 || Config.glyphStripY < 0) {
            disc.x = Math.round(Math.max(0, w - s - Theme.px(56)));
            disc.y = Math.round(Math.max(0, (h - s) / 2));
        } else {
            disc.x = Math.max(0, Math.min(w - s, Config.glyphStripX));
            disc.y = Math.max(0, Math.min(h - s, Config.glyphStripY));
        }
    }

    function persist(): void {
        Config.glyphStripX = Math.round(disc.x);
        Config.glyphStripY = Math.round(disc.y);
        Config.save();
    }

    Item {
        id: disc
        width: Config.glyphStripSize
        height: Config.glyphStripSize
        visible: win.showing

        // No plate. On the phone the arcs sit on the back panel with
        // nothing behind them, and a black disc under a broken ring would
        // fill in the gaps that make it a broken ring.
        GlyphStripRing {
            anchors.fill: parent
            onColor: NightLight.active ? "#e8a070" : "#ffffff"
        }

        MouseArea {
            id: grip
            anchors.fill: parent
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            hoverEnabled: true

            drag.target: disc
            drag.threshold: Theme.px(8)
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: Math.max(0, win.width - disc.width)
            drag.maximumY: Math.max(0, win.height - disc.height)

            property bool dragged: false

            onPressed: grip.dragged = false
            onPositionChanged: {
                if (pressed && grip.drag.active)
                    grip.dragged = true;
            }

            Binding {
                target: GlyphEvents
                property: "dragging"
                value: true
                when: grip.drag.active
                restoreMode: Binding.RestoreBindingOrValue
            }

            onReleased: {
                if (grip.dragged) {
                    win.persist();
                    return;
                }
                if (GlyphEvents.wants("reveal"))
                    GlyphEvents.reveal();
            }

            onWheel: (w) => {
                w.accepted = true;
                Config.setGlyphLevel("strip", Config.glyphLevelOf("strip")
                    + (w.angleDelta.y > 0 ? 1 : -1));
            }
        }
    }
}
