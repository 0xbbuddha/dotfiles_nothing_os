import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

SettingsPage {
    id: page

    property string filter: ""

    // These three settings used to live on the Interface page, while the
    // rest of the dock is configured here.
    SettingsSection {
        title: "Behaviour"

        SettingRow {
            key: "dockShow"
            label: "Show dock"
            DotSwitch {
                checked: Config.showDock
                onToggled: (v) => { Config.showDock = v; Config.save(); }
            }
        }

        SettingRow {
            key: "dockAutoHide"
            label: "Auto hide"
            hint: "Shown on an empty workspace, hidden when a window is open - hover the bottom edge to bring it back"
            DotSwitch {
                checked: Config.dockAutoHide
                onToggled: (v) => { Config.dockAutoHide = v; Config.save(); }
            }
        }

        SettingRow {
            key: "dockDelay"
            label: "Delay before hiding"
            hint: "After the cursor leaves"
            visible: Config.dockAutoHide
            DotSlider {
                implicitWidth: Theme.px(180)
                count: 15
                value: (Config.dockHideDelay - 200) / 1800
                display: Config.dockHideDelay + " ms"
                onMoved: (v) => {
                    Config.dockHideDelay = Math.round((200 + v * 1800) / 50) * 50;
                    Config.save();
                }
            }
        }
    }

    SettingsSection {
        title: "Dock applications"

        SettingRow {
            key: "dockApps"
            label: "Pinned applications"
            hint: Config.dockApps.length + " in the dock, ordered left to right"
        }

        Repeater {
            model: Config.dockApps

            Rectangle {
                id: row
                required property string modelData
                required property int index
                readonly property var entry: Apps.entry(modelData)

                Layout.fillWidth: true
                implicitHeight: Theme.px(38)
                radius: Theme.r.tiny
                color: Theme.c.surface2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(6)
                    spacing: Theme.px(9)

                    AppIcon {
                        appId: row.modelData
                        size: Theme.px(20)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.entry?.name ?? row.modelData
                            color: row.entry ? Theme.c.on : Theme.c.red
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }
                        NLabel {
                            text: row.entry ? row.modelData : "not found on this system"
                            color: row.entry ? Theme.c.onDim : Theme.c.red
                        }
                    }

                    CircleButton {
                        icon: "󰁝"
                        size: Theme.px(21)
                        enabled: row.index > 0
                        opacity: enabled ? 1 : 0.3
                        onActivated: Config.moveDockApp(row.index, -1)
                    }
                    CircleButton {
                        icon: "󰁅"
                        size: Theme.px(21)
                        enabled: row.index < Config.dockApps.length - 1
                        opacity: enabled ? 1 : 0.3
                        onActivated: Config.moveDockApp(row.index, 1)
                    }
                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(21)
                        onActivated: Config.removeDockApp(row.index)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Config.dockApps.length === 0
            text: "Dock is empty. Pick an app below."
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
        }
    }

    SettingsSection {
        title: "Add an app"

        NField {
            Layout.fillWidth: true
            placeholder: "Search installed applications…"
            onTextChanged: page.filter = text
            Component.onCompleted: page.filter = ""
        }

        // System .desktop list: no more command to type by hand, no more
        // guessed icon - we take what the system declares.
        Repeater {
            model: {
                const q = page.filter.trim().toLowerCase();
                const pool = Apps.visible.filter(e => !Config.dockApps.includes(e.id));
                if (q === "") return pool.slice(0, 8);
                return pool.filter(e => e.name.toLowerCase().includes(q)
                                     || e.id.toLowerCase().includes(q)).slice(0, 12);
            }

            Rectangle {
                id: cand
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Theme.px(34)
                radius: Theme.r.tiny
                color: cma.containsMouse ? Theme.c.surface3 : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(9)

                    AppIcon { iconName: cand.modelData.icon; size: Theme.px(17) }

                    Text {
                        Layout.fillWidth: true
                        text: cand.modelData.name
                        color: Theme.c.on
                        font.family: Theme.f.sans
                        font.pixelSize: Theme.f.body
                        elide: Text.ElideRight
                    }

                    NIcon { text: "󰐕"; size: Theme.z.icon; color: Theme.c.onDim }
                }

                MouseArea {
                    id: cma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.addDockApp(cand.modelData.id)
                }
            }
        }
    }

    SettingsSection {
        title: "Default programs"

        SettingRow {
            key: "terminal"
            label: "Terminal"
            NField {
                implicitWidth: Theme.px(180)
                text: Config.terminal
                onCommitted: (v) => { Config.terminal = v.trim(); Config.save(); }
            }
        }
        SettingRow {
            key: "fileManager"
            label: "File manager"
            NField {
                implicitWidth: Theme.px(180)
                text: Config.fileManager
                onCommitted: (v) => { Config.fileManager = v.trim(); Config.save(); }
            }
        }
        SettingRow {
            key: "launcher"
            label: "External launcher"
            hint: "Leave empty to use the built-in launcher (SUPER+R)"
            NField {
                implicitWidth: Theme.px(180)
                text: Config.launcher
                placeholder: "built-in"
                onCommitted: (v) => { Config.launcher = v.trim(); Config.save(); }
            }
        }
    }
}
