import QtQuick
import QtQuick.Layouts
import ".."

// Icon + value, clickable and scrollable. Basic bar brick.
// An Item, not a Row: in a Row the MouseArea would count as a positioned
// child and shift the whole group.
Item {
    id: root
    property string icon: ""
    property var value: ""
    property bool showValue: true
    property color accent: Theme.c.on
    readonly property bool hovered: ma.containsMouse
    signal activated()
    signal secondary()
    signal scrolled(int direction)

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: content.implicitWidth
    implicitHeight: Math.max(Theme.px(14), content.implicitHeight)

    // Reserve the width of the largest figure ("100%"): otherwise 6% vs 100%
    // makes the whole pill dance.
    property string valueHint: "100%"

    TextMetrics {
        id: valueMetrics
        text: root.valueHint
        font: valueText.font
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.px(5)

        NIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: Theme.px(13)
            color: root.accent
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }

        Text {
            id: valueText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showValue && String(root.value) !== ""
            width: visible ? valueMetrics.width : 0
            horizontalAlignment: Text.AlignLeft
            text: root.value
            color: Theme.c.onDim
            font.family: Theme.f.mono
            font.pixelSize: Theme.f.small
            font.kerning: false
            clip: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -Theme.px(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => m.button === Qt.RightButton ? root.secondary() : root.activated()
        onWheel: (w) => root.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
