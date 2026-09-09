import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Library: one row per widget. Driven by `length`, not the array
// object — a JS array as a ListView model is silent in Quickshell.
Flickable {
    id: root
    signal opened(string id)

    readonly property int count: {
        MiniApps.stamp;
        return MiniApps.specs.length;
    }

    contentWidth: width
    contentHeight: col.implicitHeight + Theme.pad * 2
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    ColumnLayout {
        id: col
        x: Theme.pad
        y: Theme.px(2)
        width: root.width - Theme.pad * 2
        spacing: Theme.px(6)

        Repeater {
            model: root.count

            Rectangle {
                id: row
                required property int index
                readonly property var spec: {
                    MiniApps.stamp;
                    return MiniApps.specs[row.index] ?? ({});
                }
                readonly property string appId: row.spec.id ?? ""
                readonly property bool onDesk: Config.hasDeskApp(row.appId)

                Layout.fillWidth: true
                implicitHeight: Theme.px(56)
                radius: Theme.r.chip
                color: rma.containsMouse ? Theme.c.surface3 : Theme.c.surface2

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Theme.px(2)
                    color: Theme.c.red
                    visible: row.onDesk
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(8)
                    spacing: Theme.px(10)

                    Rectangle {
                        Layout.preferredWidth: Theme.px(28)
                        Layout.preferredHeight: Theme.px(28)
                        radius: width / 2
                        color: row.onDesk ? Theme.c.red : Theme.c.surface

                        NIcon {
                            anchors.centerIn: parent
                            text: row.spec.icon || "󰀻"
                            size: Theme.px(13)
                            color: Theme.c.on
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        NText {
                            Layout.fillWidth: true
                            text: row.spec.name || "Untitled"
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }
                        NText {
                            Layout.fillWidth: true
                            text: (row.spec.face || "widget")
                                + " · "
                                + (row.spec.size === "l" ? "4×4"
                                    : (row.spec.size === "m" ? "2×4" : "2×2"))
                            color: Theme.c.onDim
                            font.pixelSize: Theme.f.micro
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: Theme.f.track
                        }
                    }

                    CircleButton {
                        icon: row.onDesk ? "󰤱" : "󰐕"
                        filled: row.onDesk
                        size: Theme.px(22)
                        onActivated: if (row.appId !== "")
                            Config.toggleDeskApp(row.appId)
                    }
                    CircleButton {
                        icon: "󰏫"
                        size: Theme.px(22)
                        onActivated: if (row.appId !== "")
                            root.opened(row.appId)
                    }
                }

                MouseArea {
                    id: rma
                    anchors.fill: parent
                    hoverEnabled: true
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (row.appId !== "")
                        root.opened(row.appId)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(40)
            visible: root.count === 0
            spacing: Theme.px(12)

            DisplayText {
                Layout.alignment: Qt.AlignHCenter
                text: "NOTHING YET"
                size: Theme.px(20)
                color: Theme.c.onFaint
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Build a widget, or start from a preset."
                color: Theme.c.onDim
                wrapMode: Text.WordWrap
            }
        }
    }
}
