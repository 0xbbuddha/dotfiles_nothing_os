import QtQuick
import ".."

// Thin rail + round knob, Nothing-style.
Item {
    id: root
    property real value: 0.5
    property real railHeight: Theme.z.rail
    property color accent: Theme.c.on
    property real split: -1   // 0..1, <0 = no notch
    signal moved(real v)

    implicitHeight: Theme.z.knob + Theme.px(5)

    Rectangle {
        id: rail
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.railHeight
        radius: height / 2
        color: Theme.c.surface3
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(root.railHeight, rail.width * Math.max(0, Math.min(1, root.value)))
        height: root.railHeight
        radius: height / 2
        color: root.accent
        Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }
    }

    Rectangle {
        width: Theme.z.knob
        height: Theme.z.knob
        radius: Theme.z.knob / 2
        color: root.accent
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(rail.width - width, rail.width * root.value - width / 2))
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }
        z: 2
    }

    // Notch between the gamma phase (darker) and the panel.
    Rectangle {
        visible: root.split >= 0 && root.split <= 1
        width: Theme.px(2)
        height: root.railHeight + Theme.px(6)
        radius: 1
        color: Theme.c.onDim
        anchors.verticalCenter: rail.verticalCenter
        x: rail.width * root.split - width / 2
        z: 3
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Theme.px(5)
        onPressed: (m) => root.moved(Math.max(0, Math.min(1, m.x / root.width)))
        onPositionChanged: (m) => { if (pressed) root.moved(Math.max(0, Math.min(1, m.x / root.width))); }
    }
}
