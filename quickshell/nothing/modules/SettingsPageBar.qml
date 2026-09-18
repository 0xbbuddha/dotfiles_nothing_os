import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// The bar: what sits in it, what shape it is, and what it shows.
//
// Used to share a page with Windows, the control centre and half the
// screen's ambient settings, all stacked under one "Interface" heading.
// That page grew to 777 lines before anyone could find the bar in it, so
// it now has one of its own - the same move this file's neighbours
// (SettingsPageDock, SettingsPageWindows, SettingsPageScreen) all made.
SettingsPage {
    id: page

    // Half the bar's own island height: past this, the corners are
    // already touching and the radius stops changing anything.
    readonly property int barMaxRadius: Math.round(Theme.z.bar / 2)

    SettingsSection {
        title: "Bar"

        SettingRow {
            key: "barLayout"
            label: "What is in the bar"
            hint: "Drag a glyph between islands to move it, drag it into "
                + "the strip below to take it out, drag one up from there "
                + "to add it. Click one to remove it outright."
        }

        BarPreview {}

        SettingRow {
            key: "barRadius"
            label: "Corner radius"
            hint: "0 is square, " + page.barMaxRadius + " is a full pill. "
                + "Windows and the control centre keep their own radius - "
                + "this is the bar only"

            DotSlider {
                implicitWidth: Theme.px(180)
                count: page.barMaxRadius + 1
                value: page.barMaxRadius > 0 ? Config.barRadius / page.barMaxRadius : 0
                display: Config.barRadius + " px"
                onMoved: (v) => {
                    Config.barRadius = Math.round(v * page.barMaxRadius);
                    Config.save();
                }
            }
        }
    }

    SettingsSection {
        title: "Indicators"

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
}
