import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The floating Glyph Bar. Same handling as the Matrix: pick it up, put it
// where you want it, and the rest of the desktop stays clickable because
// the window is masked to the strip alone.
//
// Its own placement keys rather than the Matrix's. They are different
// shapes, and a shared position would drop a tall strip where a round disc
// had been sitting.
PanelWindow {
    id: win
    required property var modelData
    property bool above: false

    // Two surfaces, one per layer, and both stay mapped for the whole
    // session. A layer-shell surface cannot change layer once created, so
    // rising above a window means handing over to the other one; they read
    // the same position out of Config and sit on exactly the same pixels,
    // so the handover is invisible.
    //
    // Mapped, not shown. Unmapping the idle one was the obvious way to do
    // this and it was wrong: Hyprland animates a layer surface appearing,
    // and this shell sets layersIn to popin, so every volume key made the
    // bar jump out of nothing. A layer rule can suppress that, but relying
    // on the compositor's configuration for correctness is a worse answer
    // than not unmapping anything.
    //
    // This is the whole point of an event light. At rest it belongs on the
    // desktop, out of the way. The moment it has something to say, a
    // maximised window in front of it must not be able to swallow it.
    readonly property bool lifted: Config.glyphBarAbove
        || (GlyphEvents.event !== "" && !GlyphEvents.dragging)

    // Whether this surface, of the two, is the one showing.
    readonly property bool showing: win.above ? win.lifted : !win.lifted

    screen: modelData
    color: "transparent"

    // Overlay, not Top, for the raised one. A fullscreen window under
    // Hyprland covers the Top layer, which is exactly why the bar and the
    // dock live there and the OSD does not. An event light a fullscreen
    // video can swallow is not an event light: a notification arriving
    // during a film is the case it exists for.
    WlrLayershell.layer: win.above ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: win.above ? "nothing-glyphbar-over" : "nothing-glyphbar"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    // A null item contributes nothing to the region, so the idle surface
    // captures no input at all and clicks land on whatever is behind it.
    // Same idiom the bar uses for an island that is not on screen.
    mask: Region { item: win.showing ? plate : null }

    // The plate is roughly the proportion of the real bar: a narrow strip
    // beside the camera island, not a panel.
    readonly property real barLength: Config.glyphBarLength
    // The plate is derived from the lamps, not guessed. Length is what the
    // user set; everything else follows, so the black hugs the column on
    // all four sides instead of leaving a field of it at the ends.
    readonly property real pad: Theme.px(6)
    readonly property real barWidth: Math.round(
        (win.barLength - 2 * win.pad) / GlyphBar.aspect + 2 * win.pad)

    Component.onCompleted: win.place()
    onWidthChanged: win.place()
    onHeightChanged: win.place()

    Connections {
        target: Config
        function onGlyphBarXChanged(): void { win.place(); }
        function onGlyphBarYChanged(): void { win.place(); }
        function onGlyphBarLengthChanged(): void { win.place(); }
    }

    function place(): void {
        if (grip.drag.active)
            return;
        const w = win.width, h = win.height;
        if (w <= 0 || h <= 0)
            return;
        if (Config.glyphBarX < 0 || Config.glyphBarY < 0) {
            // First run: against the right edge, vertically centred, which
            // is where it sits on the back of the phone.
            plate.x = Math.round(Math.max(0, w - win.barWidth - Theme.px(56)));
            plate.y = Math.round(Math.max(0, (h - win.barLength) / 2));
        } else {
            plate.x = Math.max(0, Math.min(w - win.barWidth, Config.glyphBarX));
            plate.y = Math.max(0, Math.min(h - win.barLength, Config.glyphBarY));
        }
    }

    function persist(): void {
        Config.glyphBarX = Math.round(plate.x);
        Config.glyphBarY = Math.round(plate.y);
        Config.save();
    }

    function stepLevel(delta: int): void {
        Config.glyphLevel =
            Math.max(0, Math.min(2, Config.glyphLevel + delta));
        Config.save();
    }

    Item {
        id: plate
        width: win.barWidth
        height: win.barLength
        visible: win.showing

        // Black plate, for the same reason as the Matrix: unlit lamps have
        // to sit on something, or the strip is invisible until it lights
        // and there is nothing to aim the cursor at.
        Rectangle {
            anchors.fill: parent
            radius: Theme.px(4)
            color: "#0b0b0b"
        }

        GlyphBarStrip {
            anchors.fill: parent
            anchors.margins: win.pad
            // The plate is always black, so the lamps stay white even on
            // the light theme. Following Theme.c.on painted them black on
            // black, which is the mistake the Matrix already made once.
            onColor: NightLight.active ? "#e8a070" : "#ffffff"
        }

        MouseArea {
            id: grip
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            hoverEnabled: true

            drag.target: plate
            drag.threshold: Theme.px(8)
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: Math.max(0, win.width - plate.width)
            drag.maximumY: Math.max(0, win.height - plate.height)

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

            onReleased: (m) => {
                if (grip.dragged) {
                    win.persist();
                    return;
                }
                // The bar is dark, so a click is the only way to consult
                // it. Off by default for anyone who wants it dark full
                // stop.
                if (m.button === Qt.LeftButton && GlyphEvents.wants("reveal"))
                    GlyphEvents.reveal();
            }

            // Three levels, as the hardware has, on the wheel.
            onWheel: (w) => {
                w.accepted = true;
                win.stepLevel(w.angleDelta.y > 0 ? 1 : -1);
            }
        }
    }
}
