import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../components/apps"
import "../services"

// A library entry: a titled strip, then the app running underneath.
// The chrome lives here rather than in AppHost, so the desktop column
// can show the same app with no frame at all.
Rectangle {
    id: card

    required property var spec
    signal opened(string id)

    readonly property string appId: card.spec?.id ?? ""
    readonly property bool onDesk: Config.hasDeskApp(card.appId)
    readonly property bool networked: !!card.spec?.fetch

    implicitHeight: body.implicitHeight
    radius: Theme.r.chip
    color: Theme.c.surface2
    clip: true

    // Pinned apps keep a red edge even when the pointer is away: the
    // library has to say at a glance what is already on the desktop.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.px(2)
        color: Theme.c.red
        opacity: card.onDesk ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        // ── Strip ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.px(38)
            color: hoverMa.containsMouse ? Theme.c.surface3 : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(12)
                anchors.rightMargin: Theme.px(8)
                spacing: Theme.px(10)

                Rectangle {
                    Layout.preferredWidth: Theme.px(22)
                    Layout.preferredHeight: Theme.px(22)
                    radius: width / 2
                    color: card.onDesk ? Theme.c.red : Theme.c.surface

                    NIcon {
                        anchors.centerIn: parent
                        text: card.spec?.icon ?? "󰀻"
                        size: Theme.px(11)
                        color: Theme.c.on
                    }
                }

                NText {
                    Layout.fillWidth: true
                    text: card.spec?.name ?? ""
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                NIcon {
                    text: "󰖩"
                    size: Theme.px(10)
                    color: Theme.c.onFaint
                    visible: card.networked && !hoverMa.containsMouse
                }

                CircleButton {
                    icon: card.onDesk ? "󰤱" : "󰐕"
                    filled: card.onDesk
                    size: Theme.px(22)
                    visible: hoverMa.containsMouse || card.onDesk
                    onActivated: Config.toggleDeskApp(card.appId)
                }

                CircleButton {
                    icon: "󰏫"
                    size: Theme.px(22)
                    visible: hoverMa.containsMouse
                    onActivated: card.opened(card.appId)
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.surface }

        // ── The app itself ───────────────────────────────────────────
        AppHost {
            Layout.fillWidth: true
            spec: card.spec
            chrome: false
            closable: false
            flat: true
        }
    }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
