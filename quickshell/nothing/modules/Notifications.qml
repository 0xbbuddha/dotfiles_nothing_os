import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import ".."
import "../components"
import "../services"

// Notification bubbles. The server lives in services/Notifs.qml so
// history survives this window closing.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData

    // Shown only on the focused monitor.
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")
    color: "transparent"
    visible: Config.notificationsEnabled && Notifs.popups.length > 0 && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-notifications"

    anchors { top: true; right: true }
    implicitWidth: Theme.px(330)
    implicitHeight: Math.min(screen.height * 0.8, column.implicitHeight + Theme.px(28))
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: column }

    ColumnLayout {
        id: column
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(14)
        width: Theme.px(300)
        spacing: Theme.px(8)

        Repeater {
            model: Notifs.popups

            NCard {
                id: bubble
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + Theme.px(22)
                radius: Theme.r.chip
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Theme.px(2)
                    color: Theme.c.red
                    visible: bubble.modelData.urgency === NotificationUrgency.Critical
                }

                opacity: 0
                x: Theme.px(28)
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: Theme.med } }
                Behavior on x { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

                Timer {
                    running: bubble.modelData.urgency !== NotificationUrgency.Critical
                    interval: Config.notificationTimeout * 1000
                    onTriggered: Notifs.dismissPopup(bubble.modelData.key)
                }

                ColumnLayout {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.px(13)
                    anchors.rightMargin: Theme.px(9)
                    spacing: Theme.px(3)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        AppIcon {
                            size: Theme.px(14)
                            appId: bubble.modelData.desktopEntry
                            iconName: bubble.modelData.appIcon
                        }

                        NLabel {
                            Layout.fillWidth: true
                            text: bubble.modelData.appName
                            elide: Text.ElideRight
                        }

                        CircleButton {
                            icon: "󰅖"
                            size: Theme.px(18)
                            onActivated: Notifs.dismissPopup(bubble.modelData.key)
                        }
                    }

                    NText {
                        Layout.fillWidth: true
                        text: bubble.modelData.summary
                        visible: text !== ""
                        font.pixelSize: Theme.f.body
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    NText {
                        Layout.fillWidth: true
                        text: bubble.modelData.body
                        visible: text !== ""
                        color: Theme.c.onDim
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    NotifActions {
                        Layout.topMargin: Theme.px(5)
                        entry: bubble.modelData
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    z: -1
                    cursorShape: Notifs.canOpen(bubble.modelData)
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) {
                            GlobalState.notifCenterOpen = true;
                            Notifs.dismissPopup(bubble.modelData.key);
                            return;
                        }
                        if (m.button === Qt.LeftButton && Notifs.canOpen(bubble.modelData)) {
                            Notifs.activate(bubble.modelData);
                            return;
                        }
                        Notifs.dismissPopup(bubble.modelData.key);
                    }
                }
            }
        }
    }
}
