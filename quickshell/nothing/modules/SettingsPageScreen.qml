import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// The screen over time: notification and OSD behaviour, night light,
// weather, what happens when you stop touching the machine, and what the
// lock screen shows. Split out of the page these used to share with the
// bar and the window layout - see SettingsPageBar's header for why.
SettingsPage {
    id: page

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
        title: "Idle"

        NText {
            Layout.fillWidth: true
            text: "What happens when you stop touching the machine, in order. "
                + "Each step has to come after the one before it, so raising "
                + "one pushes the later ones along."
            color: Theme.c.onDim
            wrapMode: Text.WordWrap
        }

        SettingRow {
            key: "idleDim"
            label: "Dim the screen"
            hint: Config.idleDim > 0
                ? "Brightness drops to 10 %, nothing is locked"
                : "The screen never dims on its own"
        }

        DotPicker {
            options: [
                { label: "30 s",  value: 30 },
                { label: "1 min", value: 60 },
                { label: "2 min", value: 120 },
                { label: "5 min", value: 300 },
                { label: "Never", value: 0 }
            ]
            current: Config.idleDim
            onPicked: (v) => { Config.idleDim = v; Config.save(); }
        }

        SettingRow {
            key: "idleLock"
            label: "Lock"
            hint: Config.idleLock > 0
                ? "Whichever lock screen is set above"
                : "Never locks on its own"
        }

        DotPicker {
            options: [
                { label: "1 min",  value: 60 },
                { label: "5 min",  value: 300 },
                { label: "10 min", value: 600 },
                { label: "30 min", value: 1800 },
                { label: "Never",  value: 0 }
            ]
            current: Config.idleLock
            onPicked: (v) => { Config.idleLock = v; Config.save(); }
        }

        SettingRow {
            key: "idleOff"
            label: "Screens off"
            hint: Config.idleOff > 0
                ? "DPMS off. The machine stays awake, the panels do not"
                : "The screens stay on"
        }

        DotPicker {
            options: [
                { label: "2 min",  value: 120 },
                { label: "5 min",  value: 300 },
                { label: "10 min", value: 600 },
                { label: "30 min", value: 1800 },
                { label: "Never",  value: 0 }
            ]
            current: Config.idleOff
            onPicked: (v) => { Config.idleOff = v; Config.save(); }
        }

        SettingRow {
            key: "idleSuspend"
            label: "Suspend"
            hint: Config.idleSuspend > 0
                ? "The machine goes to sleep"
                : "Never suspends on its own"
        }

        DotPicker {
            options: [
                { label: "15 min", value: 900 },
                { label: "20 min", value: 1200 },
                { label: "1 h",    value: 3600 },
                { label: "Never",  value: 0 }
            ]
            current: Config.idleSuspend
            onPicked: (v) => { Config.idleSuspend = v; Config.save(); }
        }

        NText {
            Layout.fillWidth: true
            // The steps are independent listeners in hypridle, so nothing
            // stops you asking it to suspend before it locks. Say so
            // rather than silently reordering what was chosen.
            visible: Config.idleLock > 0 && Config.idleSuspend > 0
                && Config.idleSuspend <= Config.idleLock
            text: "Suspend comes at or before the lock, so the machine will "
                + "sleep unlocked. before_sleep_cmd still locks it on the "
                + "way down, but the order is worth a second look."
            color: Theme.c.red
            wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        title: "Lock"

        SettingRow {
            key: "lockBackground"
            label: "Behind the lock screen"
            hint: Config.lockBackground === "wallpaper"
                ? "Your wallpaper, veiled only on the left where the clock and the field are"
                : "Matte black with the dot field, the Nothing look"
        }

        DotPicker {
            options: [
                { label: "Black",     value: "black" },
                { label: "Wallpaper", value: "wallpaper" }
            ]
            current: Config.lockBackground
            onPicked: (v) => { Config.lockBackground = v; Config.save(); }
        }

        NText {
            Layout.fillWidth: true
            text: "The shell draws the lock itself, on ext-session-lock. "
                + "The compositor keeps those surfaces up even if the shell "
                + "dies, so a crash leaves you locked out of the desktop "
                + "rather than letting you in."
            color: Theme.c.onDim
            wrapMode: Text.WordWrap
        }
    }
}
