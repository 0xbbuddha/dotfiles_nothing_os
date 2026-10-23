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
        title: "Dock"

        DockPreview {}
    }

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

        // Dragged by the grip. The dock is read left to right and this
        // list top to bottom, so the order matters more here than almost
        // anywhere: it is worth being able to see it move.
        DragList {
            id: dockRows
            Layout.fillWidth: true
            count: Config.dockApps.length
            rowHeight: Theme.px(38)
            rowSpacing: Theme.px(4)
            onReordered: (from, to) => Config.moveDockApp(from, to - from)

            Repeater {
                model: Config.dockApps

                // `index` is neither declared nor assigned here: DragRow
                // already requires it, so the Repeater fills it in.
                DragRow {
                    id: row
                    required property string modelData
                    readonly property var entry: Apps.entry(modelData)

                    list: dockRows

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r.tiny
                        color: row.dragging ? Theme.c.surface3 : Theme.c.surface2
                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(10)
                            anchors.rightMargin: Theme.px(6)
                            spacing: Theme.px(9)

                            DragHandle { row: row }

                            AppIcon {
                                appId: row.modelData
                                size: Theme.px(20)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                NText {
                                    Layout.fillWidth: true
                                    text: row.entry?.name ?? row.modelData
                                    color: row.entry ? Theme.c.on : Theme.c.red
                                    font.pixelSize: Theme.f.body
                                    elide: Text.ElideRight
                                }
                                NLabel {
                                    text: row.entry ? row.modelData
                                        : "not found on this system"
                                    color: row.entry ? Theme.c.onDim : Theme.c.red
                                }
                            }

                            CircleButton {
                                icon: "󰅖"
                                size: Theme.px(21)
                                onActivated: Config.removeDockApp(row.index)
                            }
                        }
                    }
                }
            }
        }

        NText {
            Layout.fillWidth: true
            visible: Config.dockApps.length === 0
            text: "Dock is empty. Pick an app below."
            color: Theme.c.onDim
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

                    NText {
                        Layout.fillWidth: true
                        text: cand.modelData.name
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

    // Which app opens which kind of file: ~/.config/mimeapps.list, the
    // file xdg-open, the portals and file managers all read. Each row
    // opens the list of installed apps that say they handle that kind.
    property string mimeOpen: ""
    onCurrentChanged: if (page.current) MimeDefaults.refresh()

    SettingsSection {
        title: "Default apps"

        SettingRow {
            key: "mimeDefaults"
            label: "Opens files and links"
            hint: MimeDefaults.error !== "" ? MimeDefaults.error
                : "SUPER+W follows the web browser chosen here"
        }

        Repeater {
            model: MimeDefaults.categories

            ColumnLayout {
                id: cat
                required property var modelData
                readonly property bool open: page.mimeOpen === modelData.key
                Layout.fillWidth: true
                spacing: Theme.px(3)

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Theme.px(34)
                    radius: Theme.r.tiny
                    color: catMa.containsMouse || cat.open ? Theme.c.surface3 : Theme.c.surface2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(10)
                        spacing: Theme.px(9)

                        NText { text: cat.modelData.label; Layout.preferredWidth: Theme.px(110) }
                        AppIcon {
                            visible: cat.modelData.current !== ""
                            iconName: Apps.entry(cat.modelData.current.replace(/\.desktop$/, ""))?.icon ?? ""
                            size: Theme.px(16)
                        }
                        NText {
                            Layout.fillWidth: true
                            text: cat.modelData.current !== "" ? cat.modelData.currentName : "Not set"
                            color: cat.modelData.current !== "" ? Theme.c.on : Theme.c.onFaint
                            elide: Text.ElideRight
                        }
                        NLabel {
                            text: cat.modelData.candidates.length + " apps"
                        }
                        NIcon { text: cat.open ? "󰅃" : "󰅀"; size: Theme.z.icon; color: Theme.c.onDim }
                    }

                    MouseArea {
                        id: catMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.mimeOpen = cat.open ? "" : cat.modelData.key
                    }
                }

                Repeater {
                    model: cat.open ? cat.modelData.candidates : []

                    Rectangle {
                        id: cand2
                        required property var modelData
                        readonly property bool chosen: modelData.id === cat.modelData.current
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.px(18)
                        implicitHeight: Theme.px(30)
                        radius: Theme.r.tiny
                        color: c2ma.containsMouse ? Theme.c.surface3 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(10)
                            anchors.rightMargin: Theme.px(10)
                            spacing: Theme.px(9)
                            AppIcon { iconName: Apps.entry(cand2.modelData.id.replace(/\.desktop$/, ""))?.icon ?? ""; size: Theme.px(15) }
                            NText {
                                Layout.fillWidth: true
                                text: cand2.modelData.name
                                elide: Text.ElideRight
                                color: cand2.chosen ? Theme.c.on : Theme.c.onDim
                            }
                            Text {
                                visible: cand2.chosen
                                text: "ON"
                                color: Theme.c.red
                                font.family: Theme.f.mono
                                font.pixelSize: Theme.f.micro
                                font.letterSpacing: Theme.f.track
                            }
                        }

                        MouseArea {
                            id: c2ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !MimeDefaults.busy && !cand2.chosen
                            onClicked: MimeDefaults.set(cat.modelData.key, cand2.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
