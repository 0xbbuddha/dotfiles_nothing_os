import QtQuick
import QtQuick.Effects
import ".."
import "../.."
import "../../services"

// A picture frame. Round or square, following Nothing's own Photos
// widget, which ships exactly those two shapes.
//
// The rounding is a mask, not clipping. QML's `clip` cuts to the bounding
// rectangle and ignores `radius` entirely, so the circle came out square
// with slightly soft corners.
//
// The frame holds its size whatever the picture is: a photo widget that
// resized itself to its contents would shuffle the desktop every time it
// turned a page.
Item {
    id: root
    property bool round: false

    // Nothing's "padding" flavour: the picture inset inside the card
    // instead of bleeding to its edge. It is a real variant in their app,
    // not a margin setting, and it reads differently: bled to the edge the
    // photo is the widget, inset it is a photo the widget is holding.
    property bool pad: false

    readonly property bool empty: !Photos.ready

    Rectangle {
        anchors.fill: parent
        visible: root.pad
        radius: Theme.r.card
        color: Theme.c.surface
    }

    Item {
        id: frame
        anchors.fill: parent
        anchors.margins: root.pad ? Theme.px(12) : 0
    }

    // Drawn only through the effect below.
    Item {
        id: content
        anchors.fill: frame
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            color: Theme.c.surface
        }

        Image {
            id: img
            anchors.fill: parent
            source: Photos.current !== "" ? "file://" + Photos.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false

            // Crossfade rather than a cut: the frame turns a page, it does
            // not blink.
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.med } }
        }
    }

    Rectangle {
        id: shape
        anchors.fill: frame
        visible: false
        layer.enabled: true
        // Inset, the corner is tighter: a card radius repeated a few
        // pixels in reads as two rings rather than one shape.
        radius: root.round ? width / 2
                           : (root.pad ? Theme.r.chip : Theme.r.card)
        color: "black"
    }

    MultiEffect {
        anchors.fill: frame
        source: content
        maskEnabled: true
        maskSource: shape
    }

    // Nothing to show yet, or the file will not open.
    NIcon {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: "󰉏"
        size: Theme.z.iconL
        color: Theme.c.onFaint
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Photos.next()
    }

    // One timer per frame, but they all advance the same shared index, so
    // two frames on the desktop show the same picture rather than drifting.
    Timer {
        running: Photos.ready
        interval: 30000
        repeat: true
        onTriggered: Photos.next()
    }
}
