import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// PolicyKit authentication window.
PanelWindow {
    id: win
    required property var modelData

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    screen: modelData
    color: "transparent"
    visible: GlobalState.polkitOpen && Polkit.active && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-polkit"
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    onVisibleChanged: {
        if (visible) {
            field.text = "";
            field.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.c.scrim
        // No dismiss on outside click: an auth request is refused explicitly.
        MouseArea { anchors.fill: parent }
    }

    NCard {
        id: sheet
        anchors.centerIn: parent
        width: Theme.px(400)
        implicitHeight: col.implicitHeight + Theme.pad * 2

        scale: win.visible ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.gap

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                Rectangle {
                    Layout.preferredWidth: Theme.px(40)
                    Layout.preferredHeight: Theme.px(40)
                    radius: width / 2
                    color: Theme.c.red

                    NIcon {
                        anchors.centerIn: parent
                        text: "󰌾"
                        size: Theme.px(19)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "Authentication required"
                        color: Theme.c.on
                        font.family: Theme.f.sans
                        font.pixelSize: Theme.f.big
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    NLabel {
                        Layout.fillWidth: true
                        text: Polkit.actionId
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: Polkit.message
                visible: text !== ""
                color: Theme.c.onDim
                font.family: Theme.f.sans
                font.pixelSize: Theme.f.small
                wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

            // ── Account, when there is a choice ───────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: Polkit.identities.length > 1

                NLabel { text: "Account" }

                Repeater {
                    model: Polkit.identities

                    Rectangle {
                        id: idBtn
                        required property var modelData
                        readonly property bool active:
                            Polkit.flow?.selectedIdentity === modelData

                        implicitWidth: idLabel.implicitWidth + Theme.px(18)
                        implicitHeight: Theme.px(24)
                        radius: height / 2
                        color: active ? Theme.c.on : Theme.c.surface2

                        Text {
                            id: idLabel
                            anchors.centerIn: parent
                            text: idBtn.modelData.toString()
                            color: idBtn.active ? Theme.c.surface : Theme.c.onDim
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.small
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Polkit.pickIdentity(idBtn.modelData)
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ── Input ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.px(38)
                radius: Theme.r.chip
                color: Theme.c.surface2
                border.width: 1
                border.color: field.activeFocus ? Theme.c.red : "transparent"
                Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(10)

                    NIcon { text: "󰌆"; size: Theme.z.icon; color: Theme.c.onDim }

                    TextInput {
                        id: field
                        Layout.fillWidth: true
                        color: Theme.c.on
                        font.family: Theme.f.sans
                        font.pixelSize: Theme.f.body
                        echoMode: Polkit.hidden ? TextInput.Password : TextInput.Normal
                        passwordCharacter: "•"
                        selectByMouse: true
                        selectionColor: Theme.c.red
                        focus: true

                        onAccepted: { Polkit.submit(text); text = ""; }
                        Keys.onEscapePressed: Polkit.cancel()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: Polkit.prompt !== "" ? Polkit.prompt : "Password"
                            color: Theme.c.onFaint
                            font: field.font
                        }
                    }
                }
            }

            // ── Polkit feedback ───────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)
                visible: Polkit.note !== ""

                Rectangle {
                    Layout.preferredWidth: Theme.px(4)
                    Layout.preferredHeight: Theme.px(4)
                    radius: width / 2
                    color: Polkit.noteIsError ? Theme.c.red : Theme.c.onDim
                }

                Text {
                    Layout.fillWidth: true
                    text: Polkit.note
                    color: Polkit.noteIsError ? Theme.c.red : Theme.c.onDim
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.small
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(2)
                spacing: Theme.px(8)

                Item { Layout.fillWidth: true }

                NPillButton {
                    text: "Cancel"
                    onActivated: Polkit.cancel()
                }

                NPillButton {
                    text: "Authenticate"
                    danger: true
                    onActivated: { Polkit.submit(field.text); field.text = ""; }
                }
            }
        }
    }
}
