import QtQuick
import ".."
import "../.."

// Breathe.
//
// Nothing ships three of these as separate widgets, not one with a mode,
// and the reason is in the rhythms: calm, focus and relax are different
// counts, and a widget you have to configure before it can help you is not
// going to help you.
//
// A ring of dots that opens and closes on the count. The ring is the
// instruction: no numbers, no progress bar, nothing to read. You match it
// or you do not.
NCard {
    id: root
    property bool simple: false

    // Seconds. In, hold, out, hold. The fourth is the pause most people
    // skip and the one that does the work.
    property real inhale: 4
    property real hold: 4
    property real exhale: 4
    property real rest: 4
    property string title: "Breathe"

    readonly property int dots: 24
    // 0 = smallest, 1 = fullest. The phases drive this and nothing else.
    property real open: 0
    property string phase: "in"

    readonly property string caption: {
        if (!run.running)
            return "Tap to begin";
        switch (root.phase) {
        case "in":   return "Breathe in";
        case "hold": return "Hold";
        case "out":  return "Breathe out";
        default:     return "Rest";
        }
    }

    // Four steps, chained. An animation per phase rather than one curve
    // with keyframes, because the counts differ per widget and a keyframe
    // curve would have to be rebuilt whenever they did.
    SequentialAnimation {
        id: run
        running: false
        loops: Animation.Infinite

        ScriptAction { script: root.phase = "in" }
        NumberAnimation {
            target: root; property: "open"; to: 1
            duration: root.inhale * 1000
            easing.type: Easing.InOutSine
        }
        ScriptAction { script: root.phase = "hold" }
        PauseAnimation { duration: root.hold * 1000 }
        ScriptAction { script: root.phase = "out" }
        NumberAnimation {
            target: root; property: "open"; to: 0
            duration: root.exhale * 1000
            easing.type: Easing.InOutSine
        }
        ScriptAction { script: root.phase = "rest" }
        PauseAnimation { duration: root.rest * 1000 }
    }

    Item {
        id: ring
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Theme.px(6)
        width: Math.min(parent.width, parent.height) - Theme.px(40)
        height: width

        // Never all the way shut. A ring that collapses to a point loses
        // the shape, and finding it again is a distraction at exactly the
        // moment you are meant to have stopped looking.
        readonly property real r:
            (width / 2) * (0.42 + 0.58 * root.open)

        Repeater {
            model: root.dots

            Rectangle {
                required property int index
                readonly property real d: Theme.px(4)
                readonly property real a: index * 2 * Math.PI / root.dots

                width: d
                height: d
                radius: d / 2
                x: ring.width / 2 + Math.cos(a) * ring.r - d / 2
                y: ring.height / 2 + Math.sin(a) * ring.r - d / 2
                color: root.phase === "hold" ? Theme.c.red : Theme.c.on
                opacity: run.running ? 1 : 0.45
                Behavior on color { ColorAnimation { duration: Theme.med } }
                Behavior on opacity { NumberAnimation { duration: Theme.med } }
            }
        }

        NLabel {
            anchors.centerIn: parent
            visible: !root.simple
            text: root.title
        }
    }

    NLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(14)
        text: root.caption
        color: run.running ? Theme.c.onDim : Theme.c.onFaint
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (run.running) {
                run.stop();
                // Back to the smallest ring, so stopping looks like
                // stopping rather than freezing mid-breath.
                root.open = 0;
                root.phase = "in";
            } else {
                run.start();
            }
        }
    }
}
