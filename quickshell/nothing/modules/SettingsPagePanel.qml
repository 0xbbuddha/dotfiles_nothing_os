import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Interface: what the bar shows, how the screen responds, and the
// workspace preview grid.
//
// Dock settings used to live here even though a Dock page exists: they
// joined it, so the dock is no longer sought in two places.
SettingsPage {
    id: page

    SettingsSection {
        title: "Workspaces"

        SettingRow {
            key: "workspaces"
            label: "Show in bar"
            hint: "On the special workspace the bar says so and returns to "
                + "numbers on hover"
            DotSwitch {
                checked: Config.showWorkspaces
                onToggled: (v) => { Config.showWorkspaces = v; Config.save(); }
            }
        }

        SettingRow {
            key: "workspaceStyle"
            label: "Numbering"
            hint: {
                switch (Config.workspaceStyle) {
                case "japanese": return "一 二 三 四 五";
                case "roman":    return "I II III IV V";
                default:         return "1 2 3 4 5";
                }
            }
        }

        DotPicker {
            options: [
                { label: "Normal",   value: "arabic" },
                { label: "Roman",    value: "roman" },
                { label: "Japanese", value: "japanese" }
            ]
            current: Config.workspaceStyle
            onPicked: (v) => { Config.workspaceStyle = v; Config.save(); }
        }

        SettingRow {
            key: "workspaceCount"
            label: "How many shown"
            hint: Config.workspaceCount + " workspaces always visible"
        }

        DotPicker {
            options: [
                { label: "3",  value: 3 },
                { label: "5",  value: 5 },
                { label: "7",  value: 7 },
                { label: "10", value: 10 }
            ]
            current: Config.workspaceCount
            onPicked: (v) => { Config.workspaceCount = v; Config.save(); }
        }
    }

    // These three settings only existed in the JSON: the preview grid was
    // tuned blindly, reloading the shell to see the result.
    SettingsSection {
        title: "Overview grid"

        DotPreview {
            id: gridPreview
            implicitHeight: Theme.px(140)
            caption: Config.workspaceRows + " × " + Config.workspaceCols
                + "  ·  " + (Config.workspaceRows * Config.workspaceCols) + " spaces"

            readonly property real gap: Theme.px(5)
            readonly property real cellW: Math.min(
                (width - Theme.px(40) - (Config.workspaceCols - 1) * gap) / Config.workspaceCols,
                ((height - Theme.px(44) - (Config.workspaceRows - 1) * gap)
                    / Config.workspaceRows) * (16 / 9))

            Grid {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Theme.px(6)
                rows: Config.workspaceRows
                columns: Config.workspaceCols
                rowSpacing: gridPreview.gap
                columnSpacing: gridPreview.gap

                Repeater {
                    model: Config.workspaceRows * Config.workspaceCols

                    Rectangle {
                        id: cell
                        required property int index

                        width: gridPreview.cellW
                        height: gridPreview.cellW * 9 / 16
                        radius: Theme.px(3)
                        color: Theme.c.surface3
                        border.width: cell.index === 0 ? 1 : 0
                        border.color: Theme.c.red

                        DisplayText {
                            anchors.centerIn: parent
                            text: cell.index + 1
                            size: Math.max(Theme.px(8), cell.height * 0.5)
                            color: Theme.c.onDim
                        }
                    }
                }
            }
        }

        SettingRow {
            key: "workspaceGrid"
            label: "Rows"
            DotPicker {
                options: [{ label: "1", value: 1 }, { label: "2", value: 2 },
                          { label: "3", value: 3 }]
                current: Config.workspaceRows
                onPicked: (v) => { Config.workspaceRows = v; Config.save(); }
            }
        }

        SettingRow {
            label: "Columns"
            DotPicker {
                options: [{ label: "3", value: 3 }, { label: "4", value: 4 },
                          { label: "5", value: 5 }, { label: "6", value: 6 }]
                current: Config.workspaceCols
                onPicked: (v) => { Config.workspaceCols = v; Config.save(); }
            }
        }

        SettingRow {
            key: "workspaceScale"
            label: "Thumbnail size"
            hint: "Share of the real screen each cell takes"
            DotSlider {
                implicitWidth: Theme.px(190)
                count: 12
                value: (Config.workspaceScale - 0.08) / 0.24
                display: Math.round(Config.workspaceScale * 100) + " %"
                onMoved: (v) => {
                    Config.workspaceScale =
                        Math.round((0.08 + v * 0.24) * 100) / 100;
                    Config.save();
                }
            }
        }
    }

    SettingsSection {
        title: "Bar"

        SettingRow {
            key: "tray"
            label: "System tray"
            hint: "Icons of background applications"
            DotSwitch {
                checked: Config.showTray
                onToggled: (v) => { Config.showTray = v; Config.save(); }
            }
        }

        SettingRow {
            key: "battery"
            label: "Battery"
            DotSwitch {
                checked: Config.showBattery
                onToggled: (v) => { Config.showBattery = v; Config.save(); }
            }
        }

        SettingRow {
            key: "barCpu"
            label: "CPU usage"
            hint: "Percent in the bar - hover for used / free / zram"
            DotSwitch {
                checked: Config.barShowCpu
                onToggled: (v) => { Config.barShowCpu = v; Config.save(); }
            }
        }

        SettingRow {
            key: "barRam"
            label: "RAM usage"
            DotSwitch {
                checked: Config.barShowRam
                onToggled: (v) => { Config.barShowRam = v; Config.save(); }
            }
        }

        SettingRow {
            key: "barGpu"
            label: "GPU usage"
            hint: Sys.gpuSeen ? "Shown next to CPU and RAM" : "No GPU sensor found"
            DotSwitch {
                checked: Config.barShowGpu
                onToggled: (v) => { Config.barShowGpu = v; Config.save(); }
            }
        }

        SettingRow {
            key: "barTemp"
            label: "Temperature"
            DotSwitch {
                checked: Config.barShowTemp
                onToggled: (v) => { Config.barShowTemp = v; Config.save(); }
            }
        }
    }

    SettingsSection {
        title: "On-screen feedback"

        SettingRow {
            key: "notifications"
            label: "Notifications"
            DotSwitch {
                checked: Config.notificationsEnabled
                onToggled: (v) => { Config.notificationsEnabled = v; Config.save(); }
            }
        }

        SettingRow {
            key: "notificationTimeout"
            label: "Display time"
            hint: "Before a notification dismisses itself"
            DotSlider {
                implicitWidth: Theme.px(190)
                count: 14
                value: (Config.notificationTimeout - 2) / 13
                display: Config.notificationTimeout + " s"
                onMoved: (v) => {
                    Config.notificationTimeout = Math.round(2 + v * 13);
                    Config.save();
                }
            }
        }

        SettingRow {
            key: "osd"
            label: "Volume and brightness overlays"
            hint: "On the Glyph Matrix when it is on, otherwise a bubble"
            DotSwitch {
                checked: Config.osdEnabled
                onToggled: (v) => { Config.osdEnabled = v; Config.save(); }
            }
        }
    }

    SettingsSection {
        title: "Night light"

        SettingRow {
            key: "night"
            label: "Automatic schedule"
            hint: NightLight.available
                ? "From " + Config.nightFrom + " to " + Config.nightTo
                : "hyprsunset is not installed"
            DotSwitch {
                checked: Config.nightAutomatic
                onToggled: (v) => {
                    Config.nightAutomatic = v;
                    Config.save();
                    if (v) NightLight.apply(NightLight.inSchedule);
                }
            }
        }

        SettingRow {
            label: "Starts at"
            NField {
                implicitWidth: Theme.px(90)
                text: Config.nightFrom
                placeholder: "19:00"
                onCommitted: (v) => { Config.nightFrom = v.trim(); Config.save(); }
            }
        }

        SettingRow {
            label: "Ends at"
            NField {
                implicitWidth: Theme.px(90)
                text: Config.nightTo
                placeholder: "06:30"
                onCommitted: (v) => { Config.nightTo = v.trim(); Config.save(); }
            }
        }

        SettingRow {
            key: "nightTemp"
            label: "Colour temperature"
            hint: "Lower is warmer"
            DotSlider {
                implicitWidth: Theme.px(190)
                count: 16
                value: (Config.nightTemperature - 2500) / 4000
                display: Config.nightTemperature + " K"
                onMoved: (v) => {
                    Config.nightTemperature = Math.round((2500 + v * 4000) / 100) * 100;
                    Config.save();
                    if (NightLight.active) NightLight.apply(true);
                }
            }
        }
    }

    SettingsSection {
        title: "Weather"

        SettingRow {
            key: "weather"
            label: "Enable"
            hint: "Queries wttr.in - updates as soon as the city is saved"
            DotSwitch {
                checked: Config.weatherEnabled
                onToggled: (v) => { Config.weatherEnabled = v; Config.save(); }
            }
        }

        SettingRow {
            key: "weatherCity"
            label: "City"
            hint: "Empty = locate by IP"
            NField {
                implicitWidth: Theme.px(180)
                text: Config.weatherCity
                placeholder: "auto"
                onCommitted: (v) => {
                    Config.weatherCity = v.trim();
                    Config.save();
                    Weather.refresh();
                }
            }
        }
    }

    SettingsSection {
        title: "Lock"

        SettingRow {
            key: "lockScreen"
            label: "Lock screen"
            hint: Config.lockScreen === "shell"
                ? "Drawn by the shell: a dot-matrix mark per character, session buttons that wait for the password"
                : "hyprlock, from hypr/hyprlock.conf"
        }

        DotPicker {
            options: [
                { label: "hyprlock", value: "hyprlock" },
                { label: "Shell",    value: "shell" }
            ]
            current: Config.lockScreen
            onPicked: (v) => { Config.lockScreen = v; Config.save(); }
        }

        NText {
            Layout.fillWidth: true
            text: "Try it with SUPER+L before trusting it to the idle timer. "
                + "If the shell ever fails to answer, locking falls back to "
                + "hyprlock rather than leaving the session open."
            color: Theme.c.onDim
            wrapMode: Text.WordWrap
        }
    }
}
