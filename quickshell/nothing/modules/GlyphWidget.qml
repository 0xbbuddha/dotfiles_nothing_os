import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/glyph"
import "../services"

// Floating Glyph Matrix: a 489-dot disc, movable, masked to the circle
// so the rest of the desktop stays clickable.
PanelWindow {
    id: win
    required property var modelData
    property bool above: false

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: win.above ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: win.above ? "nothing-glyph-top" : "nothing-glyph"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    mask: Region {
        item: disc
        shape: RegionShape.Ellipse
    }

    // Toys are instantiated once. Only the shown one is painted, and
    // cava only listens if the visualiser is in front.
    Clock { id: toyClock }
    Battery { id: toyBattery }
    System { id: toySystem }
    Notices { id: toyNotices }
    Counter { id: toyCounter }
    Dice { id: toyDice }
    Chrono { id: toyChrono }
    Pendulum { id: toyPendulum }
    Visualizer { id: toyVisualizer }

    function toyById(id: string): var {
        switch (id) {
        case "clock":      return toyClock;
        case "battery":    return toyBattery;
        case "system":     return toySystem;
        case "notices":    return toyNotices;
        case "counter":    return toyCounter;
        case "dice":       return toyDice;
        case "timer":      return toyChrono;
        case "pendulum":   return toyPendulum;
        case "visualizer": return toyVisualizer;
        default:           return toyClock;
        }
    }

    readonly property var current: win.toyById(Config.glyphToy)

    Component.onCompleted: win.place()

    function step(delta: int): void {
        const list = Config.glyphToys ?? [];
        if (list.length === 0)
            return;
        let i = list.indexOf(Config.glyphToy);
        if (i < 0)
            i = 0;
        const next = list[(i + delta + list.length) % list.length];
        Config.glyphToy = next;
        Config.save();
    }

    function place(): void {
        if (grip.drag.active)
            return;
        const s = Config.glyphSize;
        const w = win.width, h = win.height;
        if (w <= 0 || h <= 0)
            return;
        if (Config.glyphX < 0 || Config.glyphY < 0) {
            disc.x = Math.round(Math.max(0, w - s - Theme.px(56)));
            disc.y = Math.round(Math.max(0, (h - s) / 2));
        } else {
            disc.x = Math.max(0, Math.min(w - s, Config.glyphX));
            disc.y = Math.max(0, Math.min(h - s, Config.glyphY));
        }
    }

    function persist(): void {
        Config.glyphX = Math.round(disc.x);
        Config.glyphY = Math.round(disc.y);
        Config.save();
    }

    onWidthChanged: win.place()
    onHeightChanged: win.place()

    Connections {
        target: Config
        function onGlyphXChanged(): void { win.place(); }
        function onGlyphYChanged(): void { win.place(); }
        function onGlyphSizeChanged(): void { win.place(); }
    }

    Item {
        id: disc
        width: Config.glyphSize
        height: Config.glyphSize

        // Black plate: without it the white dots blend into the wallpaper,
        // and the disc loses the Glyph Matrix silhouette.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#0b0b0b"
        }

        GlyphMatrix {
            anchors.fill: parent
            anchors.margins: Theme.px(10)
            toy: win.current
            // The plate is the Glyph Matrix itself, always black, so the
            // dots stay white even on the light theme. Following
            // `on` painted them black on black.
            onColor: NightLight.active ? "#e8a070" : "#ffffff"
            offOpacity: NightLight.active ? 0.10 : 0.18
        }

        MouseArea {
            id: grip
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            hoverEnabled: true

            drag.target: disc
            drag.threshold: Theme.px(8)
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: Math.max(0, win.width - disc.width)
            drag.maximumY: Math.max(0, win.height - disc.height)

            property bool held: false
            property bool dragged: false

            onPressed: (m) => {
                grip.held = false;
                grip.dragged = false;
                if (m.button === Qt.RightButton) {
                    win.current?.tap?.();
                    m.accepted = true;
                }
            }

            onPositionChanged: {
                if (pressed && grip.drag.active)
                    grip.dragged = true;
            }

            onPressAndHold: {
                if (grip.dragged)
                    return;
                grip.held = true;
                win.current?.tap?.();
            }

            onReleased: (m) => {
                if (m.button !== Qt.LeftButton)
                    return;
                if (grip.dragged) {
                    win.persist();
                    return;
                }
                if (!grip.held)
                    win.step(1);
            }

            onWheel: (w) => {
                w.accepted = true;
                if (win.current?.wheel) {
                    win.current.scroll(w.angleDelta.y);
                    return;
                }
                win.step(w.angleDelta.y < 0 ? 1 : -1);
            }
        }
    }
}
