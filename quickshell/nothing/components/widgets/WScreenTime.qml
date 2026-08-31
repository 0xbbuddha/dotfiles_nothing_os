import QtQuick
import ".."
import "../.."
import "../../services"

// Time at the machine, with a face that stops smiling.
//
// The first attempt drew this with strokes and arcs and it read as a
// cartoon, which is the one thing Nothing never is. Their own widget is a
// dot matrix and nothing else: a 13 by 21 grid, a dot of radius 3.26 on a
// pitch of 6.51 so neighbours all but touch, the four corners left out to
// round the shape, and the face laid on the same grid as the frame. Eyes,
// nose and mouth are dots, not features. That grammar is copied here
// exactly; only the outline changed, from a phone to a screen on a stand,
// because this is a desk.
//
// Two faces in one square, the same as the weather: the matrix on its own,
// then the figure. A square has room for one thing said properly, and the
// face is the thing you actually read, so it gets the whole tile.
//
// Rectangles rather than a Canvas. A canvas has to be told to repaint, and
// the day the theme flips is the day you find out you forgot; a dot that
// binds its own colour cannot get that wrong.
NCard {
    id: root

    readonly property real ratio: ScreenTime.fraction
    readonly property bool over: ScreenTime.over
    readonly property color ink: root.over ? Theme.c.red : Theme.c.on

    readonly property int pages: 2
    property int page: 0

    // Three moods, as Nothing has: at ease, then watchful, then not.
    readonly property string mood:
        root.over ? "sad" : (root.ratio >= 0.8 ? "flat" : "happy")

    readonly property int cols: 17
    readonly property int rows: 16

    // Where the frame's top edge runs. It doubles as the gauge, so it is
    // named once here and read twice below.
    readonly property int edgeFrom: 1
    readonly property int edgeTo: 15
    readonly property int edgeLit:
        Math.round(root.ratio * (root.edgeTo - root.edgeFrom + 1))

    // col, row, and what the dot is for. Built once: the shape does not
    // depend on the time, only its colour does.
    readonly property var frame: {
        const out = [];
        const put = (c, r, k) => out.push({ c: c, r: r, k: k });
        for (let c = root.edgeFrom; c <= root.edgeTo; c++) {
            put(c, 0, "edge");        // the gauge
            put(c, 12, "frame");      // the chin
        }
        for (let r = 1; r <= 11; r++) {
            put(0, r, "frame");
            put(16, r, "frame");
        }
        for (let c = 7; c <= 9; c++) {  // the neck
            put(c, 13, "frame");
            put(c, 14, "frame");
        }
        for (let c = 4; c <= 12; c++)   // the foot
            put(c, 15, "frame");
        return out;
    }

    // Lifted dot for dot from Nothing's own face, shifted to this frame's
    // centre column. The nose hooks left at its foot; that hook is theirs,
    // and leaving it out is what made the earlier version look generic.
    readonly property var face: {
        const out = [];
        const put = (c, r, k) => out.push({ c: c, r: r, k: k ?? "face" });
        put(5, 3, "eye"); put(11, 3, "eye");
        put(8, 3); put(8, 4); put(8, 5);             // nose
        put(7, 6); put(8, 6);                        // its hook

        if (root.mood === "happy") {
            put(5, 8); put(11, 8);                   // corners up
            for (let c = 6; c <= 10; c++) put(c, 9);
        } else if (root.mood === "flat") {
            for (let c = 5; c <= 11; c++) put(c, 9);
        } else {
            for (let c = 6; c <= 10; c++) put(c, 8); // corners down
            put(5, 9); put(11, 9);
        }
        return out;
    }

    // A blink is the cheapest thing that makes a face look occupied, and
    // an eye here is one dot, so there is no shut eyelid to draw: it goes
    // and comes back. Irregular on purpose. A blink on a metronome is the
    // one rhythm nothing alive has, and it reads as a fault in the widget.
    property bool blinking: false

    Timer {
        id: blink
        running: root.page === 0
        interval: 4000
        repeat: true
        onTriggered: {
            root.blinking = true;
            shut.restart();
            blink.interval = 2600 + Math.floor(Math.random() * 4200);
        }
    }

    Timer {
        id: shut
        interval: 120
        onTriggered: root.blinking = false
    }

    // Eyes open again whenever the page turns away, so coming back never
    // finds the face mid-blink and stuck there.
    onPageChanged: if (page !== 0) root.blinking = false;

    Item {
        id: stage
        anchors.fill: parent
        anchors.bottomMargin: Theme.px(16)
        clip: true

        // ── The face ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            y: (0 - root.page) * height
            Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

            Item {
                id: art
                anchors.centerIn: parent
                // Deliberately short of the tile. At full bleed the matrix
                // filled the square and read as a picture of a screen rather
                // than an icon on a card.
                width: parent.width - Theme.px(58)
                height: parent.height - Theme.px(46)

                readonly property real step: Math.min(width / root.cols,
                                                      height / root.rows)
                // Nothing's ratio is 3.26 to 6.51, so the dots all but
                // meet. Held just short of that: at this size touching
                // dots close up into solid rule and the matrix stops being
                // visible at all.
                readonly property real dot: art.step * 0.9

                Item {
                    anchors.centerIn: parent
                    width: art.step * root.cols
                    height: art.step * root.rows

                    Repeater {
                        model: root.frame.concat(root.face)

                        Rectangle {
                            required property var modelData

                            width: art.dot
                            height: art.dot
                            radius: width / 2
                            x: modelData.c * art.step + (art.step - width) / 2
                            y: modelData.r * art.step + (art.step - height) / 2

                            scale: modelData.k === "eye" && root.blinking ? 0 : 1
                            Behavior on scale {
                                NumberAnimation { duration: 60 }
                            }

                            color: {
                                if (root.over)
                                    return Theme.c.red;
                                if (modelData.k === "edge")
                                    return modelData.c < root.edgeFrom + root.edgeLit
                                        ? Theme.c.red : Theme.c.onFaint;
                                return modelData.k === "frame"
                                    ? Theme.c.onFaint : Theme.c.on;
                            }
                            Behavior on color { ColorAnimation { duration: Theme.med } }
                        }
                    }
                }
            }
        }

        // ── The figure ────────────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            y: (1 - root.page) * height
            Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(6)

                DisplayText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.pretty(ScreenTime.seconds)
                    size: Theme.px(26)
                    color: root.ink
                }

                NLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.over ? "Over your limit"
                                    : "of " + root.pretty(ScreenTime.limit)
                    color: root.over ? Theme.c.red : Theme.c.onDim
                }

                // The same gauge as the screen's top edge, so the two
                // pages are visibly the same reading.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Theme.px(4)
                    spacing: Theme.px(4)

                    Repeater {
                        model: root.edgeTo - root.edgeFrom + 1

                        Rectangle {
                            required property int index
                            width: Theme.px(5)
                            height: width
                            radius: width / 2
                            color: index < root.edgeLit ? Theme.c.red
                                                        : Theme.c.onFaint
                            Behavior on color { ColorAnimation { duration: Theme.med } }
                        }
                    }
                }
            }
        }
    }

    function pretty(sec: real): string {
        const m = Math.floor(Math.max(0, sec) / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? h + "H " + (m % 60) + "M" : m + "M";
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(10)
        spacing: Theme.px(5)

        Repeater {
            model: root.pages

            Rectangle {
                required property int index
                width: Theme.px(4)
                height: width
                radius: width / 2
                color: index === root.page ? Theme.c.red : Theme.c.onFaint
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // The page turns when you turn it, and not otherwise. A tile
        // that cycles on its own is a tile you cannot read: you look at it
        // to check one thing and it has already moved on to another.
        onClicked: root.page = (root.page + 1) % root.pages
    }

}
