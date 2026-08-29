import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"

SettingsPage {
    id: page

    onCurrentChanged: if (current) Walls.refresh()

    Process { id: sh; function run(cmd) { command = ["sh", "-c", cmd]; running = true; } }

    SettingsSection {
        title: "Theme"

        SettingRow {
            key: "theme"
            label: "Light or dark"
            hint: "Dark is the Nothing signature. Light keeps the same layout on white."
        }

        DotPicker {
            options: [
                { label: "Dark",  value: "dark" },
                { label: "Light", value: "light" }
            ]
            current: Config.theme
            onPicked: (v) => { Config.theme = v; Config.save(); }
        }
    }

    SettingsSection {
        title: "Scale"

        SettingRow {
            key: "scale"
            label: "Interface size"
            hint: "The whole shell follows this"

            DotSlider {
                implicitWidth: Theme.px(190)
                value: (Config.scale - 0.6) / 0.8      // 60 % to 140 %
                display: Math.round(Config.scale * 100) + " %"
                onMoved: (v) => {
                    Config.scale = Math.round((0.6 + v * 0.8) * 20) / 20;
                    Config.save();
                }
            }
        }

        DotPicker {
            options: [
                { label: "Compact", value: 0.85 },
                { label: "Normal",  value: 1.0 },
                { label: "Comfort", value: 1.15 },
                { label: "Large",   value: 1.3 }
            ]
            current: Config.scale
            onPicked: (v) => { Config.scale = v; Config.save(); }
        }
    }

    SettingsSection {
        title: "Accent"

        SettingRow {
            key: "accent"
            label: "Colour"
            hint: Config.accent.toUpperCase()

            Row {
                spacing: Theme.px(8)

                Repeater {
                    model: ["#d71921", "#ffffff", "#ff6b00", "#00d68f", "#3b82f6", "#a855f7"]

                    Rectangle {
                        id: sw
                        required property string modelData
                        readonly property bool active:
                            Config.accent.toLowerCase() === modelData

                        width: Theme.px(20); height: width; radius: width / 2
                        color: modelData
                        anchors.verticalCenter: parent.verticalCenter

                        // Detached selection ring, like the halo of a lit
                        // dot.
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + Theme.px(8)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: sw.active ? 1 : 0
                            border.color: Theme.c.on
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.px(3)
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Config.accent = sw.modelData; Config.save(); }
                        }
                    }
                }
            }
        }
    }

    SettingsSection {
        title: "Wallpaper"

        DotPreview {
            caption: Config.drawWallpaper ? "shown" : "hidden by the shell"
            implicitHeight: Theme.px(130)

            Image {
                anchors.fill: parent
                anchors.margins: Theme.px(10)
                source: Config.wallpaperUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: Config.drawWallpaper ? 1 : 0.25
                Behavior on opacity { NumberAnimation { duration: Theme.med } }
            }
        }

        SettingRow {
            key: "wallpaperDraw"
            label: "Drawn by the shell"
            hint: "Avoids installing swww or hyprpaper"
            DotSwitch {
                checked: Config.drawWallpaper
                onToggled: (v) => { Config.drawWallpaper = v; Config.save(); }
            }
        }

        SettingRow {
            key: "wallpaper"
            label: "Image"
            hint: "Absolute path, empty = the image shipped in hypr/"
            NField {
                implicitWidth: Theme.px(210)
                text: Config.wallpaper
                placeholder: "hypr/wallpaper.png"
                onCommitted: (v) => { Config.wallpaper = v.trim(); Config.save(); }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: Theme.px(6)
            rowSpacing: Theme.px(6)
            visible: Walls.files.length > 0

            Repeater {
                model: Walls.files

                Item {
                    id: thumb
                    required property string modelData
                    readonly property bool active: Config.wallpaper === modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(52)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r.tiny
                        color: Theme.c.surface2
                        border.width: thumb.active ? 1 : 0
                        border.color: Theme.c.red
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: thumb.active ? 1 : 0
                            source: "file://" + thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.wallpaper = thumb.modelData;
                                Config.save();
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            label: "Regenerate the shipped image"
            hint: "Runs the Python script at screen resolution"
            NPillButton {
                text: "Generate"
                onActivated: {
                    const s = page.Window.window?.screen;
                    const w = Math.round((s?.width ?? 1920) * 1.5);
                    const h = Math.round((s?.height ?? 1080) * 1.5);
                    sh.run(`cd "$HOME/hypr_nothing" && python3 scripts/gen-wallpaper.py ${w} ${h}`);
                }
            }
        }
    }
}
