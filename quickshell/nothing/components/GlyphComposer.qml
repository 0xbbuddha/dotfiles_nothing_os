import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// Compose your own rhythm, the way Nothing's Glyph Composer does it: pads,
// not a timeline you draw. You hold a pad, that zone lights, you let go and
// it goes out, and what you played is what gets kept.
//
// One pad per zone group of the surface that is lit, so three on the Strip
// and six on the Bar. A pad addresses a group rather than a zone, which is
// what lets a rhythm composed on one surface play on the other.
//
// Recording is a list of changes, not a poll. Sampling on a timer would
// quantise every tap to the sample rate and lose exactly the thing being
// recorded, which is the timing.
ColumnLayout {
    id: root
    spacing: Theme.px(8)

    readonly property int pads: GlyphEvents.slots

    property bool recording: false
    property var held: []           // pads currently down
    property var steps: []          // what has been recorded
    property real lastAt: 0
    property string name: ""

    // Ten seconds, as the phone allows. A rhythm you cannot hold in your
    // head is not a signature, it is a light show.
    readonly property int limit: 10000
    property real elapsed: 0

    readonly property bool empty: root.steps.length === 0

    function now(): real { return Date.now(); }

    function start(): void {
        root.steps = [];
        root.held = [];
        root.elapsed = 0;
        root.lastAt = root.now();
        root.recording = true;
        tick.restart();
    }

    // Close the step that was playing, then note what is held now. Called
    // on every press and release, so a step's duration is the real gap
    // between two changes.
    function mark(): void {
        if (!root.recording)
            return;
        const t = root.now();
        const ms = Math.round(t - root.lastAt);
        if (ms > 0) {
            const list = root.steps.slice();
            list.push({ ms: ms, k: "zones",
                        z: root.held.slice(), g: root.pads });
            root.steps = list;
        }
        root.lastAt = t;
    }

    function stop(): void {
        if (!root.recording)
            return;
        root.mark();
        root.held = [];
        root.recording = false;
        tick.stop();

        // Two pads pressed in the same frame leave a step of a millisecond
        // or two between them. Nobody can see it and nobody meant it, so
        // it is folded into the step before rather than dropped: dropping
        // would shorten the rhythm by exactly as much as it removed.
        const list = [];
        for (const st of root.steps) {
            if (st.ms < 24 && list.length > 0)
                list[list.length - 1].ms += st.ms;
            else
                list.push({ ms: st.ms, k: st.k, z: st.z, g: st.g });
        }

        // A rhythm has to end dark, or the surface stays lit on the last
        // pad you were holding when the ten seconds ran out.
        if (list.length > 0 && (list[list.length - 1].z ?? []).length > 0)
            list.push({ ms: 240, k: "zones", z: [], g: root.pads });
        root.steps = list;
    }

    function press(i: int): void {
        if (!root.recording)
            root.start();
        root.mark();
        if (root.held.indexOf(i) < 0)
            root.held = root.held.concat(i);
        root.light();
    }

    function release(i: int): void {
        root.mark();
        root.held = root.held.filter(x => x !== i);
        root.light();
    }

    // Drive the real surface while composing, so you are looking at the
    // thing you are making rather than at a preview of it.
    function light(): void {
        GlyphEvents.event = "compose";
        GlyphEvents.frameKind = "zones";
        GlyphEvents.frameGroups = root.pads;
        GlyphEvents.frameZones = root.held;
        if (root.held.length === 0 && !root.recording)
            GlyphEvents.event = "";
    }

    Timer {
        id: tick
        interval: 50
        repeat: true
        onTriggered: {
            root.elapsed = root.now() - root.lastAt
                + root.steps.reduce((t, s) => t + s.ms, 0);
            if (root.elapsed >= root.limit)
                root.stop();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(8)

        NLabel { Layout.fillWidth: true; text: "Composer" }
        NLabel {
            text: root.recording
                ? (root.elapsed / 1000).toFixed(1) + "s"
                : (root.empty ? "" : (root.steps.reduce((t, s) => t + s.ms, 0)
                                      / 1000).toFixed(1) + "s")
            color: root.recording ? Theme.c.red : Theme.c.onFaint
        }
    }

    NText {
        Layout.fillWidth: true
        text: "Hold a pad to light that part of the Glyph. Recording starts "
            + "on your first press and runs to ten seconds."
        color: Theme.c.onFaint
        font.pixelSize: Theme.f.tiny
        wrapMode: Text.WordWrap
    }

    // ── The pads ──────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(6)

        Repeater {
            model: root.pads

            Rectangle {
                id: pad
                required property int index

                readonly property bool down: root.held.indexOf(index) >= 0

                Layout.fillWidth: true
                implicitHeight: Theme.px(54)
                radius: Theme.px(4)
                color: pad.down ? Theme.c.on : Theme.c.surface3
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                NText {
                    anchors.centerIn: parent
                    // A, B, C on the ring; the segment number on the bar.
                    text: GlyphEvents.surface === "strip"
                        ? ["C", "A", "B"][pad.index] ?? String(pad.index + 1)
                        : String(pad.index + 1)
                    color: pad.down ? Theme.c.surface : Theme.c.onDim
                    font.pixelSize: Theme.f.big
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: root.press(pad.index)
                    onReleased: root.release(pad.index)
                    // Dragging off a pad has to count as letting go, or
                    // the release is never seen and the zone stays lit.
                    onCanceled: root.release(pad.index)
                }
            }
        }
    }

    // ── Keep it ───────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(8)
        visible: !root.empty

        NField {
            Layout.fillWidth: true
            text: root.name
            placeholder: "Name this rhythm"
            onCommitted: (v) => root.name = v.trim()
        }

        NPillButton {
            text: "Play"
            onActivated: {
                GlyphEvents.event = "notify";
                GlyphEvents.frames = root.steps;
                GlyphEvents.frame = -1;
                GlyphEvents.advance();
            }
        }

        NPillButton {
            text: "Save"
            onActivated: {
                const label = root.name !== "" ? root.name
                    : "Rhythm " + (Config.glyphCustom.length + 1);
                Config.addGlyphCustom(label, root.steps);
                root.steps = [];
                root.name = "";
            }
        }

        NPillButton {
            text: "Discard"
            danger: true
            onActivated: { root.steps = []; root.name = ""; }
        }
    }

    // ── Yours ─────────────────────────────────────────────────────────
    Repeater {
        model: Config.glyphCustom

        RowLayout {
            id: own
            required property var modelData

            Layout.fillWidth: true
            spacing: Theme.px(8)

            NText {
                Layout.fillWidth: true
                text: own.modelData.label
                elide: Text.ElideRight
            }
            NLabel {
                text: ((own.modelData.steps ?? []).reduce(
                    (t, s) => t + s.ms, 0) / 1000).toFixed(1) + "s"
            }
            NPillButton {
                text: "Play"
                onActivated: GlyphEvents.preview(own.modelData.id)
            }
            CircleButton {
                icon: "󰅖"
                size: Theme.px(24)
                onActivated: Config.removeGlyphCustom(own.modelData.id)
            }
        }
    }
}
