import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

// Shortcut cheatsheet, two columns, with search.
OverlayWindow {
    id: win
    open: GlobalState.cheatsheetOpen
    onOpenChanged: GlobalState.cheatsheetOpen = open
    sheetWidth: Math.min(Theme.px(800), screen.width * 0.85)
    sheetHeight: Math.min(Theme.px(560), screen.height * 0.82)

    property var results: Shortcuts.groups

    onShown: {
        field.text = "";
        win.results = Shortcuts.groups;
        field.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.pad
            spacing: Theme.px(12)

            DisplayText { text: "SHORTCUTS"; size: Theme.px(22) }

            Item { Layout.fillWidth: true }

            NIcon { text: "󰍉"; size: Theme.z.iconM; color: Theme.c.onDim }

            TextInput {
                id: field
                Layout.preferredWidth: Theme.px(180)
                color: Theme.c.on
                font.family: Theme.f.sans
                font.pixelSize: Theme.f.body
                selectByMouse: true
                selectionColor: Theme.c.red
                focus: true

                onTextChanged: win.results = Shortcuts.search(text)
                Keys.onEscapePressed: GlobalState.cheatsheetOpen = false

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: "Filter…"
                    color: Theme.c.onFaint
                    font: field.font
                }
            }

            CircleButton {
                icon: "󰅖"
                size: Theme.px(26)
                onActivated: GlobalState.cheatsheetOpen = false
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: grid.implicitHeight + Theme.pad * 2
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            GridLayout {
                id: grid
                x: Theme.pad
                y: Theme.pad
                width: parent.width - Theme.pad * 2
                columns: 2
                columnSpacing: Theme.px(16)
                rowSpacing: Theme.px(16)

                Repeater {
                    model: win.results

                    ColumnLayout {
                        id: group
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Theme.px(6)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.px(8)

                            NIcon {
                                text: group.modelData.icon
                                size: Theme.z.icon
                                color: Theme.c.red
                            }
                            NLabel { text: group.modelData.title; dim: false }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: Theme.c.outline
                            }
                        }

                        Repeater {
                            model: group.modelData.items

                            RowLayout {
                                id: row
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Theme.px(10)

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.label
                                    color: Theme.c.onDim
                                    font.family: Theme.f.sans
                                    font.pixelSize: Theme.f.small
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: Theme.px(3)

                                    Repeater {
                                        model: row.modelData.keys
                                        KeyCap {
                                            required property string modelData
                                            text: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.margins: Theme.pad
            visible: win.results.length === 0
            text: "No matching shortcut."
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
