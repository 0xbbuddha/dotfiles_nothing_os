import QtQuick
import QtQuick.Layouts
import ".."

// Bar pill-module: width = content. The background MouseArea is internal:
// putting it in the Row would break the layout.
NCard {
    id: root
    default property alias content: row.data
    property real pad: Theme.px(12)

    signal activated()
    signal secondary()
    signal scrolled(int direction)

    radius: Theme.r.pill
    height: Theme.z.bar
    implicitWidth: row.implicitWidth + pad * 2
    clip: true

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => m.button === Qt.RightButton ? root.secondary() : root.activated()
        onWheel: (w) => root.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        spacing: Theme.px(10)
    }
}
