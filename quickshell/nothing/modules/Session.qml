import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Session menu. Explicit confirmation: nothing destructive on a single click.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData

    // Shown only on the focused monitor.
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")
    color: "transparent"
    visible: GlobalState.sessionOpen && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-session"
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    property int armed: -1     // index waiting for confirmation

    onVisibleChanged: if (!visible) armed = -1

    readonly property var actions: [
        { icon: "󰌾", label: "Lock",      run: () => Power.lock(),     confirm: false },
        { icon: "󰤄", label: "Sleep",     run: () => Power.suspend(),  confirm: false },
        { icon: "󰗽", label: "Log out",   run: () => Power.logout(),   confirm: true  },
        { icon: "󰜉", label: "Restart",   run: () => Power.reboot(),   confirm: true  },
        { icon: "󰐥", label: "Shut down", run: () => Power.poweroff(), confirm: true  }
    ]

    function trigger(i: int): void {
        const a = win.actions[i];
        if (a.confirm && win.armed !== i) { win.armed = i; return; }
        GlobalState.sessionOpen = false;
        a.run();
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.c.scrim
        MouseArea { anchors.fill: parent; onClicked: GlobalState.sessionOpen = false }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: GlobalState.sessionOpen = false
    }

    NCard {
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + Theme.px(28)
        implicitHeight: Theme.px(128)

        scale: win.visible ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.px(12)

            RowLayout {
                id: row
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.px(10)

                Repeater {
                    model: win.actions

                    Item {
                        id: btn
                        required property var modelData
                        required property int index
                        readonly property bool waiting: win.armed === index

                        implicitWidth: Theme.px(64)
                        implicitHeight: Theme.px(64)

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r.chip
                            color: btn.waiting ? Theme.c.red
                                 : (bma.containsMouse ? Theme.c.surface3 : Theme.c.surface2)
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.px(6)

                            NIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: btn.modelData.icon
                                size: Theme.px(20)
                            }

                            NText {
                                Layout.alignment: Qt.AlignHCenter
                                text: btn.waiting ? "Confirmer ?" : btn.modelData.label
                                color: btn.waiting ? Theme.c.on : Theme.c.onDim
                                font.pixelSize: Theme.f.tiny
                            }
                        }

                        MouseArea {
                            id: bma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.trigger(btn.index)
                            onExited: if (btn.waiting) win.armed = -1
                        }

                        scale: bma.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast } }
                    }
                }
            }

            NLabel {
                Layout.alignment: Qt.AlignHCenter
                text: win.armed >= 0 ? "Click again to confirm" : "Esc to cancel"
            }
        }
    }

}
