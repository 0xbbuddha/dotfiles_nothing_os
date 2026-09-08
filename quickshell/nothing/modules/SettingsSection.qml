import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// A titled block in a settings page.
ColumnLayout {
    id: root
    property string title: ""

    // Taken from the title rather than set at each call site. The titles
    // are unique across the pages, so one table here cannot fall out of
    // step with thirty declarations the way thirty icon properties would.
    readonly property string icon: SettingsIndex.sectionIcon(root.title)
    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: Theme.px(10)

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.px(4)
        spacing: Theme.px(9)

        NIcon {
            visible: root.icon !== ""
            text: root.icon
            size: Theme.z.icon
            color: Theme.c.onFaint
        }

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
