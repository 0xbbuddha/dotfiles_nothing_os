import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import ".."
import "../components"
import "../services"

// Game: performance mode, the crosshair and overlay widgets.
//
// These sixteen settings only existed in the JSON file. The crosshair in
// particular was tuned blindly, yet it is the only one of the lot you
// adjust by eye: hence the live preview.
SettingsPage {
    id: page

    SettingsSection {
        title: "Game mode"

        SettingRow {
            key: "gameMode"
            label: "Game mode"
            hint: Game.applying ? "applying…"
                : (Config.gameMode ? "on - Hyprland is running lean"
                                   : "off - everything back to normal")
            DotSwitch {
                checked: Config.gameMode
                onToggled: Game.toggle()
            }
        }

        SettingRow {
            key: "gameNoAnimations"
            label: "Disable animations"
            DotSwitch {
                checked: Config.gameNoAnimations
                onToggled: (v) => {
                    Config.gameNoAnimations = v;
                    Config.save();
                    if (Config.gameMode) Game.apply(true);
                }
            }
        }

        SettingRow {
            key: "gameNoBlur"
            label: "Disable blur"
            DotSwitch {
                checked: Config.gameNoBlur
                onToggled: (v) => {
                    Config.gameNoBlur = v;
                    Config.save();
                    if (Config.gameMode) Game.apply(true);
                }
            }
        }

        SettingRow {
            key: "gameNoShadow"
            label: "Disable shadows"
            DotSwitch {
                checked: Config.gameNoShadow
                onToggled: (v) => {
                    Config.gameNoShadow = v;
                    Config.save();
                    if (Config.gameMode) Game.apply(true);
                }
            }
        }

        SettingRow {
            key: "gameTearing"
            label: "Allow tearing"
            hint: "Lower latency, visible seams on fast motion"
            DotSwitch {
                checked: Config.gameTearing
                onToggled: (v) => {
                    Config.gameTearing = v;
                    Config.save();
                    if (Config.gameMode) Game.apply(true);
                }
            }
        }

        SettingRow {
            key: "gameInhibitIdle"
            label: "Keep the screen awake"
            hint: "Suspends hypridle while the game is running"
            DotSwitch {
                checked: Config.gameInhibitIdle
                onToggled: (v) => {
                    Config.gameInhibitIdle = v;
                    Config.save();
                    if (Config.gameMode) Idle.apply(v);
                }
            }
        }

        SettingRow {
            key: "gameHideShell"
            label: "Hide bar and dock"
            hint: "Frees the screen edges while game mode is on"
            DotSwitch {
                checked: Config.gameHideShell
                onToggled: (v) => { Config.gameHideShell = v; Config.save(); }
            }
        }

        SettingRow {
            key: "gameUnfocusedFps"
            label: "Unfocused frame rate"
            hint: "What other windows render at while you play"
        }

        DotPicker {
            options: [
                { label: "Frozen", value: 0 },
                { label: "15",     value: 15 },
                { label: "30",     value: 30 },
                { label: "60",     value: 60 }
            ]
            current: Config.gameUnfocusedFps
            onPicked: (v) => {
                Config.gameUnfocusedFps = v;
                Config.save();
                if (Config.gameMode) Game.apply(true);
            }
        }

        SettingRow {
            key: "gameFpsLimit"
            label: "Frame rate limit"
            hint: Game.mangohudAvailable
                ? "Written to the MangoHud configuration"
                : "mangohud is not installed"
        }

        DotPicker {
            enabled: Game.mangohudAvailable
            opacity: enabled ? 1 : 0.4
            options: [
                { label: "Uncapped", value: 0 },
                { label: "60",  value: 60 },
                { label: "120", value: 120 },
                { label: "144", value: 144 },
                { label: "165", value: 165 },
                { label: "240", value: 240 }
            ]
            current: Config.gameFpsLimit
            onPicked: (v) => Game.setFpsLimit(v)
        }
    }

    SettingsSection {
        title: "Crosshair"

        DotPreview {
            implicitHeight: Theme.px(160)
            caption: Config.crosshair ? Config.crosshairStyle : "off"

            CrosshairArt {
                anchors.centerIn: parent
                opacity: Config.crosshair ? 1 : 0.3
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }
        }

        SettingRow {
            key: "crosshair"
            label: "Show crosshair"
            hint: "Drawn by the shell, never intercepts the mouse"
            DotSwitch {
                checked: Config.crosshair
                onToggled: (v) => { Config.crosshair = v; Config.save(); }
            }
        }

        SettingRow {
            key: "crosshairStyle"
            label: "Shape"
        }

        DotPicker {
            options: [
                { label: "Cross",     value: "cross" },
                { label: "Dot",       value: "dot" },
                { label: "Circle",    value: "circle" },
                { label: "Cross dot", value: "crossdot" },
                { label: "T shape",   value: "tshape" }
            ]
            current: Config.crosshairStyle
            onPicked: (v) => { Config.crosshairStyle = v; Config.save(); }
        }

        SettingRow {
            key: "crosshairSize"
            label: "Arm length"
            DotSlider {
                implicitWidth: Theme.px(180)
                count: 14
                value: (Config.crosshairSize - 2) / 28
                display: Config.crosshairSize + " px"
                onMoved: (v) => {
                    Config.crosshairSize = Math.round(2 + v * 28);
                    Config.save();
                }
            }
        }

        SettingRow {
            label: "Thickness"
            DotSlider {
                implicitWidth: Theme.px(180)
                count: 8
                value: (Config.crosshairThickness - 1) / 7
                display: Config.crosshairThickness + " px"
                onMoved: (v) => {
                    Config.crosshairThickness = Math.round(1 + v * 7);
                    Config.save();
                }
            }
        }

        SettingRow {
            label: "Centre gap"
            DotSlider {
                implicitWidth: Theme.px(180)
                count: 13
                value: Config.crosshairGap / 24
                display: Config.crosshairGap + " px"
                onMoved: (v) => {
                    Config.crosshairGap = Math.round(v * 24);
                    Config.save();
                }
            }
        }

        SettingRow {
            key: "crosshairColor"
            label: "Colour"
            hint: Config.crosshairColor.toUpperCase()

            Row {
                spacing: Theme.px(8)

                Repeater {
                    model: ["#00ff88", "#00e5ff", "#ff00d4", "#ffe600",
                            "#ff2d2d", "#ffffff"]

                    Rectangle {
                        id: tint
                        required property string modelData
                        readonly property bool active:
                            Config.crosshairColor.toLowerCase() === modelData

                        width: Theme.px(20); height: width; radius: width / 2
                        color: modelData
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + Theme.px(8)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: tint.active ? 1 : 0
                            border.color: Theme.c.on
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.px(3)
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.crosshairColor = tint.modelData;
                                Config.save();
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            label: "Dark outline"
            hint: "Keeps the crosshair readable on bright scenes"
            DotSwitch {
                checked: Config.crosshairOutline
                onToggled: (v) => { Config.crosshairOutline = v; Config.save(); }
            }
        }
    }

    SettingsSection {
        title: "Overlay widgets"

        SettingRow {
            key: "gameWidgets"
            label: "On the game canvas"
            hint: (Config.gameWidgets ?? []).length
                + " placed  ·  SUPER+G to move, pin and resize"
        }

        Repeater {
            model: GameRegistry.all

            Rectangle {
                id: tool
                required property var modelData
                readonly property bool active:
                    Config.gameWidgetEnabled(tool.modelData.id)

                Layout.fillWidth: true
                implicitHeight: Theme.px(44)
                radius: Theme.r.chip
                color: gma.containsMouse ? Theme.c.surface2 : "transparent"
                border.width: gma.containsMouse ? 0 : 1
                border.color: Theme.c.outline
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(16)
                    anchors.rightMargin: Theme.px(14)
                    spacing: Theme.px(12)

                    NIcon {
                        text: tool.modelData.icon
                        size: Theme.z.iconM
                        color: tool.active ? Theme.c.on : Theme.c.onDim
                        Layout.preferredWidth: Theme.px(18)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        NText {
                            Layout.fillWidth: true
                            text: tool.modelData.label
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }
                        NText {
                            Layout.fillWidth: true
                            text: tool.modelData.hint
                            color: Theme.c.onDim
                            elide: Text.ElideRight
                        }
                    }

                    DotSwitch {
                        checked: tool.active
                        onToggled: page.placeWidget(tool.modelData)
                    }
                }

                MouseArea {
                    id: gma
                    anchors.fill: parent
                    hoverEnabled: true
                    // The click is carried by the switch: the whole row is
                    // only for hover.
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }

    // Stagger placement so widgets are not stacked on the same spot, as
    // the game bar does.
    function placeWidget(meta: var): void {
        if (Config.gameWidgetEnabled(meta.id)) {
            Config.removeGameWidget(meta.id);
            return;
        }
        const n = (Config.gameWidgets ?? []).length;
        Config.addGameWidget(meta.id,
            Theme.px(80) + n * Theme.px(28),
            Theme.px(80) + n * Theme.px(28),
            Theme.px(meta.w), Theme.px(meta.h),
            Hyprland.focusedMonitor?.name ?? "");
    }
}
