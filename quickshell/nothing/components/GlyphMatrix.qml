import QtQuick
import ".."
import "glyph/draw.js" as D

// The dot disc. Builds the grid, clips it to the circle, and asks the
// shown toy to fill the frame at the cadence it requests.
//
// 25x25 clipped to the disc is exactly 489 dots, the Phone (3) Glyph
// Matrix definition. The Phone (4a) Pro's 13x13 cannot write a readable hour.
Item {
    id: root

    property int resolution: 25
    // An Item exposing render(frame), tick (ms) and, optionally, tap() and scroll().
    property var toy: null
    property bool running: true

    property color onColor: Theme.c.on
    property color accentColor: Theme.c.red
    // Off dots stay just visible: that is what makes the matrix; otherwise
    // the disc shrinks to the lit shape.
    property real offOpacity: 0.18
    property real fill: 0.62

    // 0 = the toy only lives on its signals (dirty). The timer does not run.
    readonly property int cadence: root.toy?.tick ?? 0
    // Dot fades cost one animation per dot. They dress a clock; they would
    // choke a visualiser: beyond five frames per second the toy already
    // carries its own motion.
    readonly property bool fade: root.cadence === 0 || root.cadence >= 200

    readonly property real pitch: Math.min(width, height) / root.resolution
    readonly property real dotSize: root.pitch * root.fill

    // Flat indices of the dots inside the circle.
    readonly property var cells: {
        const n = root.resolution;
        const c = (n - 1) / 2;
        const r2 = (n / 2) * (n / 2);
        const out = [];
        for (let y = 0; y < n; y++) {
            for (let x = 0; x < n; x++) {
                const dx = x - c, dy = y - c;
                if (dx * dx + dy * dy <= r2)
                    out.push(y * n + x);
            }
        }
        return out;
    }

    // Frame and last-render memory, allocated once.
    property var _frame: null
    property var _lastLum: []
    property var _lastHue: []

    implicitWidth: Theme.px(220)
    implicitHeight: implicitWidth

    Component.onCompleted: root._rebuild()
    onResolutionChanged: root._rebuild()

    function _rebuild(): void {
        root._frame = D.frame(root.resolution);
        root._lastLum = new Array(root.cells.length).fill(-1);
        root._lastHue = new Array(root.cells.length).fill(-1);
        root.paint();
    }

    // Opacities are assigned in JS, not via bindings on the toy's data.
    // 489 bindings re-evaluated thirty times a second would cost far more
    // than this loop, and unchanged dots are skipped.
    // Do not "fix" this with bindings.
    function paint(): void {
        const toy = root.toy;
        const f = root._frame;
        if (!f || !toy || !toy.render)
            return;

        D.clear(f);
        toy.render(f);

        const cells = root.cells;
        const lum = f.lum, hue = f.hue;
        const prevL = root._lastLum, prevH = root._lastHue;

        for (let k = 0; k < cells.length; k++) {
            const i = cells[k];
            const v = lum[i], h = hue[i];
            if (v === prevL[k] && h === prevH[k])
                continue;
            prevL[k] = v;
            prevH[k] = h;
            const dot = rep.itemAt(k);
            if (dot) {
                dot.level = v;
                dot.accent = h > 0;
            }
        }
    }

    // A toy state change (click, a moving service) does not wait for the
    // next tick.
    Connections {
        target: root.toy
        ignoreUnknownSignals: true
        function onDirty(): void { root.paint(); }
    }

    onToyChanged: {
        root._lastLum.fill(-1);
        root._lastHue.fill(-1);
        root.paint();
    }

    Timer {
        interval: Math.max(16, root.cadence)
        running: root.running && root.toy !== null && root.visible && root.cadence > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.paint()
    }

    Item {
        id: grid
        anchors.centerIn: parent
        width: root.pitch * root.resolution
        height: width

        Repeater {
            id: rep
            model: root.cells

            onItemAdded: (index, item) => {
                if (index === root.cells.length - 1)
                    root.paint();
            }

            Rectangle {
                required property int modelData
                property real level: 0
                property bool accent: false

                readonly property int gx: modelData % root.resolution
                readonly property int gy: Math.floor(modelData / root.resolution)

                x: (gx + 0.5) * root.pitch - width / 2
                y: (gy + 0.5) * root.pitch - height / 2
                width: root.dotSize
                height: root.dotSize
                radius: width / 2

                color: accent ? root.accentColor : root.onColor
                opacity: root.offOpacity + level * (1 - root.offOpacity)

                Behavior on level {
                    enabled: root.fade
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
