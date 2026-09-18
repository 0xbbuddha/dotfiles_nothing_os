import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Windows: how a new one takes its place, the control centre's own
// layout, and the two workspace previews (the numbers in the bar and the
// overview grid). Split out of the page these used to share with the bar
// and the screen's ambient settings - see SettingsPageBar's header for why.
SettingsPage {
    id: page

    SettingsSection {
        title: "Windows"

        SettingRow {
            key: "windowLayout"
            label: "Layout"
            hint: WindowLayout.available
                ? "How a new window takes its place on screen"
                : "This Hyprland has no scrolling layout. 0.54 or newer has."
        }

        DotPicker {
            enabled: WindowLayout.available
            opacity: enabled ? 1 : 0.4
            options: [
                { label: "Tiling",    value: "tiling" },
                { label: "Scrolling", value: "scrolling" },
                { label: "Essential", value: "essential" }
            ]
            current: Config.windowLayout
            onPicked: (v) => { Config.windowLayout = v; Config.save(); }
        }

        // Said in full rather than left to the two words above: these are
        // two different ways to use a computer, and the choice is not
        // obvious from their names.
        NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.c.onDim
            text: {
                switch (Config.windowLayout) {
                case "scrolling":
                    return "Windows sit side by side on a tape that runs off "
                        + "the screen. A new one arrives at its own width and "
                        + "pushes the rest along instead of taking space from "
                        + "them, and you scroll to what you want.";
                case "essential":
                    return "One window in front of you, every other one "
                        + "parked as a sliver down one side. You do not "
                        + "arrange anything: you pick the next thing off "
                        + "the shelf.";
                default:
                    return "The screen is divided. Every new window splits "
                        + "the space again, so everything already open gets "
                        + "smaller.";
                }
            }
        }

        SettingRow {
            key: "scrollColumnWidth"
            label: "Column width"
            hint: "How much of the screen a new column takes"
            visible: WindowLayout.scrolling

            DotSlider {
                implicitWidth: Theme.px(190)
                value: (Config.scrollColumnWidth - 0.1) / 0.9
                display: Math.round(Config.scrollColumnWidth * 100) + " %"
                onMoved: (v) => {
                    Config.scrollColumnWidth =
                        Math.round((0.1 + v * 0.9) * 20) / 20;
                    Config.save();
                }
            }
        }

        SettingRow {
            key: "scrollFocusFit"
            label: "Following the focus"
            hint: "Where a column lands when you move to it"
            visible: WindowLayout.scrolling
        }

        DotPicker {
            visible: WindowLayout.scrolling
            options: [
                { label: "Fit",    value: "fit" },
                { label: "Centre", value: "center" }
            ]
            current: Config.scrollFocusFit
            onPicked: (v) => { Config.scrollFocusFit = v; Config.save(); }
        }

        SettingRow {
            key: "scrollDirection"
            label: "New windows appear"
            hint: "And the direction the tape runs in"
            visible: WindowLayout.scrolling
        }

        DotPicker {
            visible: WindowLayout.scrolling
            options: [
                { label: "Right", value: "right" },
                { label: "Left",  value: "left" },
                { label: "Down",  value: "down" },
                { label: "Up",    value: "up" }
            ]
            current: Config.scrollDirection
            onPicked: (v) => { Config.scrollDirection = v; Config.save(); }
        }

        SettingRow {
            key: "scrollFullscreenOne"
            label: "One window fills the screen"
            hint: "A workspace with a single column ignores the width above"
            visible: WindowLayout.scrolling

            NSwitch {
                checked: Config.scrollFullscreenOne
                onToggled: (v) => {
                    Config.scrollFullscreenOne = v;
                    Config.save();
                }
            }
        }

        SettingRow {
            key: "scrollFollowFocus"
            label: "Scroll to the focused window"
            hint: "Off keeps the tape still until you move it yourself"
            visible: WindowLayout.scrolling

            NSwitch {
                checked: Config.scrollFollowFocus
                onToggled: (v) => {
                    Config.scrollFollowFocus = v;
                    Config.save();
                }
            }
        }

        SettingRow {
            key: "shelfSide"
            label: "The shelf sits on the"
            hint: "Which side the parked windows go to"
            visible: WindowLayout.essential
        }

        DotPicker {
            visible: WindowLayout.essential
            options: [
                { label: "Right", value: "right" },
                { label: "Left",  value: "left" }
            ]
            current: Config.shelfSide
            onPicked: (v) => { Config.shelfSide = v; Config.save(); }
        }

        SettingRow {
            key: "mainWidth"
            label: "Main pane"
            hint: "How much of the screen the window in front takes"
            visible: WindowLayout.essential

            DotSlider {
                implicitWidth: Theme.px(190)
                value: (Config.mainWidth - 0.25) / 0.65
                display: Math.round(Config.mainWidth * 100) + " %"
                onMoved: (v) => {
                    Config.mainWidth = Math.round((0.25 + v * 0.65) * 20) / 20;
                    Config.save();
                }
            }
        }

        SettingRow {
            label: "Shortcuts"
            visible: WindowLayout.essential
            hint: "SUPER+J brings the focused window to the front. SUPER+, "
                + "and SUPER+; make the main pane narrower and wider. The "
                + "same keys the other layouts use."
        }

        SettingRow {
            label: "Shortcuts"
            hint: "SUPER+, and SUPER+; make the column narrower and wider. "
                + "SUPER+ALT+arrows moves along the tape, SHIFT carries the "
                + "column with you. Up and down split a column and fold it "
                + "back. SUPER+ALT+C centres the column, SUPER+ALT+Return "
                + "gives it the whole screen."
            visible: WindowLayout.scrolling
        }
    }

    SettingsSection {
        title: "Control centre"

        CcPreview {}

        SettingRow {
            key: "ccTiles"
            label: "Tiles"
            hint: "Fourteen to choose from. Drag one out of the preview to "
                + "remove it, one up from the shelf to add it"
        }

        SettingRow {
            key: "ccColumns"
            label: "Tiles per row"
            hint: "Two reads at a glance, four fits everything"

            DotPicker {
                options: [
                    { label: "2", value: 2 },
                    { label: "3", value: 3 },
                    { label: "4", value: 4 }
                ]
                current: Config.ccColumns
                onPicked: (v) => { Config.ccColumns = v; Config.save(); }
            }
        }

        SettingRow {
            key: "ccFooter"
            label: "Buttons"
            hint: "The squares along the bottom. Glyph only, so keep it short"
        }

        SettingRow {
            key: "ccSections"
            label: "Blocks"
            hint: "The whole rows, above and below the tiles"
        }

        // Straight from CcRegistry rather than five hand written rows: the
        // catalogue is what the panel reads, so a block added there shows
        // up here without a second edit.
        Repeater {
            model: CcRegistry.sections

            SettingRow {
                required property var modelData
                label: modelData.label
                hint: modelData.hint

                // ccSection reads the matching adapter property, and a
                // binding captures what a function it calls reads, so this
                // follows the value without naming it here.
                NSwitch {
                    checked: Config.ccSection(modelData.id)
                    onToggled: (v) => Config.setCcSection(modelData.id, v)
                }
            }
        }
    }

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
}
