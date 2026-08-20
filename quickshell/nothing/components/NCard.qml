import QtQuick
import ".."

// The base container: matte black, very round corners, discreet outline.
Rectangle {
    id: root
    property bool outlined: false
    property real elevation: 0   // 0..1, slightly darkens/lightens

    color: Qt.lighter(Theme.c.surface, 1 + elevation * 0.45)
    radius: Theme.r.card
    border.width: outlined ? 1 : 0
    border.color: Theme.c.outline
    antialiasing: true

    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
