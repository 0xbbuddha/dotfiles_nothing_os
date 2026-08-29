import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

// Pick the region then the action. This panel closes before grim;
// the launcher and game bar stay up so they can be in the shot.
OverlayWindow {
    id: win
    open: GlobalState.screenshotOpen
    onOpenChanged: GlobalState.screenshotOpen = open
    sheetWidth: Theme.px(400)
    sheetHeight: Theme.px(250)

    property string mode: "region"

    function go(action: string): void {
        GlobalState.screenshotOpen = false;
        delay.action = action;
        delay.restart();
    }

    // Let the layer vanish before capturing.
    Timer {
        id: delay
        property string action: "save"
        interval: 220
        onTriggered: Shot.capture(win.mode, action)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        NText {
            text: "Screenshot"
            font.pixelSize: Theme.f.big
            font.weight: Font.Medium
        }

        NLabel { text: "Region" }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            Repeater {
                model: [
                    { key: "region", label: "Selection", icon: "󰆞" },
                    { key: "window", label: "Window",   icon: "󰖯" },
                    { key: "screen", label: "Screen",     icon: "󰍹" }
                ]

                Rectangle {
                    id: modeBtn
                    required property var modelData
                    readonly property bool active: win.mode === modelData.key

                    Layout.fillWidth: true
                    implicitHeight: Theme.px(52)
                    radius: Theme.r.chip
                    color: active ? Theme.c.on : Theme.c.surface2
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.px(4)

                        NIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: modeBtn.modelData.icon
                            size: Theme.z.iconM
                            color: modeBtn.active ? Theme.c.surface : Theme.c.on
                        }
                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modeBtn.modelData.label
                            color: modeBtn.active ? Theme.c.surface : Theme.c.onDim
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.mode = modeBtn.modelData.key
                    }
                }
            }
        }

        NLabel { text: "Action" }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            Repeater {
                model: [
                    { key: "copy", label: "Copy",   icon: "󰅍" },
                    { key: "save", label: "Keep",   icon: "󰆓" },
                    { key: "edit", label: "Annotate",  icon: "󰏫" },
                    { key: "ocr",  label: "Text",    icon: "󰈚" }
                ]

                Rectangle {
                    id: actBtn
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: Theme.px(46)
                    radius: Theme.r.chip
                    color: ama.containsMouse ? Theme.c.red : Theme.c.surface2
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.px(3)
                        NIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: actBtn.modelData.icon
                            size: Theme.z.icon
                        }
                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: actBtn.modelData.label
                            font.pixelSize: Theme.f.tiny
                        }
                    }

                    MouseArea {
                        id: ama
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.go(actBtn.modelData.key)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        NLabel {
            Layout.fillWidth: true
            text: "Saved to ~/Pictures/Captures  ·  OCR in English "
                + "(pacman -S tesseract-data-fra for French)"
            elide: Text.ElideRight
        }
    }

}
