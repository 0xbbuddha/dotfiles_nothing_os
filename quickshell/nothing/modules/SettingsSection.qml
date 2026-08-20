import QtQuick
import QtQuick.Layouts
import ".."
import "../components"

// A titled block in a settings page.
ColumnLayout {
    id: root
    property string title: ""
    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: Theme.px(10)

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.px(4)
        spacing: Theme.px(9)

        NLabel { text: root.title; dim: false }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.c.outline
        }
    }

    ColumnLayout {
        id: inner
        Layout.fillWidth: true
        spacing: Theme.px(4)
    }
}
