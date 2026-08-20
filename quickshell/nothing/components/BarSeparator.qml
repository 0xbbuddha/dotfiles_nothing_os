import QtQuick
import QtQuick.Layouts
import ".."

// Thin vertical stroke between two bar groups.
Rectangle {
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: 1
    Layout.preferredHeight: Theme.px(10)
    color: Theme.c.outline
}
