import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."
import "../components"
import "../services"

// Notification history, grouped by application.
OverlayWindow {
    id: win
    open: GlobalState.notifCenterOpen
    onOpenChanged: GlobalState.notifCenterOpen = open
    topBias: 0.28
    sheetWidth: Theme.px(430)
    sheetHeight: Math.min(Theme.px(500), screen.height * 0.72)

    onShown: Notifs.markAllSeen()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.pad
            spacing: Theme.px(10)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Notifications"
                    color: Theme.c.on
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.big
                    font.weight: Font.Medium
                }
                NLabel {
                    text: Notifs.history.length === 0
                        ? "None" : Notifs.history.length + " kept"
                }
            }

            Rectangle {
                implicitWidth: Theme.px(30)
                implicitHeight: Theme.px(30)
                radius: width / 2
                color: Notifs.doNotDisturb ? Theme.c.red : Theme.c.surface2
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                NIcon {
                    anchors.centerIn: parent
                    text: Notifs.doNotDisturb ? "󰂛" : "󰂚"
                    size: Theme.z.icon
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.doNotDisturb = !Notifs.doNotDisturb
                }
            }

            CircleButton {
                icon: "󰩹"
                size: Theme.px(30)
                onActivated: Notifs.clearHistory()
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Theme.px(8)
            clip: true
            spacing: Theme.px(6)
            model: Notifs.grouped()
            boundsBehavior: Flickable.StopAtBounds

            delegate: ColumnLayout {
                id: group
                required property var modelData
                width: ListView.view.width
                spacing: Theme.px(4)

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.px(4)
                    spacing: Theme.px(6)

                    Rectangle {
                        Layout.preferredWidth: Theme.px(4)
                        Layout.preferredHeight: Theme.px(4)
                        radius: width / 2
                        color: Theme.c.red
                    }
                    NLabel { text: group.modelData.app; dim: false }
                    Item { Layout.fillWidth: true }
                    NLabel { text: group.modelData.items.length }
                }

                Repeater {
                    model: group.modelData.items

                    NCard {
                        id: item
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: text.implicitHeight + Theme.px(20)
                        color: Theme.c.surface2
                        radius: Theme.r.chip

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Theme.px(2)
                            color: Theme.c.red
                            visible: item.modelData.urgency === NotificationUrgency.Critical
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(12)
                            anchors.rightMargin: Theme.px(8)
                            anchors.topMargin: Theme.px(10)
                            anchors.bottomMargin: Theme.px(10)
                            spacing: Theme.px(10)
                            z: 1

                            AppIcon {
                                Layout.alignment: Qt.AlignTop
                                size: Theme.px(20)
                                appId: item.modelData.desktopEntry
                                iconName: item.modelData.appIcon
                            }

                            ColumnLayout {
                                id: text
                                Layout.fillWidth: true
                                spacing: Theme.px(2)

                                Text {
                                    Layout.fillWidth: true
                                    text: item.modelData.summary
                                    visible: text !== ""
                                    color: Theme.c.on
                                    font.family: Theme.f.sans
                                    font.pixelSize: Theme.f.body
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: item.modelData.body
                                    visible: text !== ""
                                    color: Theme.c.onDim
                                    font.family: Theme.f.sans
                                    font.pixelSize: Theme.f.small
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }

                                NLabel {
                                    Layout.topMargin: Theme.px(2)
                                    text: Notifs.relative(item.modelData.time)
                                }

                                NotifActions {
                                    Layout.topMargin: Theme.px(4)
                                    entry: item.modelData
                                }
                            }

                            CircleButton {
                                Layout.alignment: Qt.AlignTop
                                icon: "󰅖"
                                size: Theme.px(19)
                                onActivated: Notifs.forget(item.modelData.key)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: 0
                            enabled: Notifs.canOpen(item.modelData)
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.activate(item.modelData)
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.margins: Theme.pad
            visible: Notifs.history.length === 0
            text: "Nothing to show."
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
            horizontalAlignment: Text.AlignHCenter
        }
    }

}
