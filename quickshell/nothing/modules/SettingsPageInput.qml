import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Mouse, touchpad and keyboard. Every change is live (hyprctl eval) and
// kept in ~/.config/hypr/input.lua, see services/Input.qml. custom.lua is
// read after that file, so a value set there wins over this page.
SettingsPage {
    id: page

    function set(key: string, v: var): void {
        Config[key] = v;
        Config.save();
        Input.apply();
    }

    SettingsSection {
        title: "Mouse"

        SettingRow {
            key: "inputSensitivity"
            label: "Pointer speed"
            hint: "Added to the mouse's own speed, from -1 to +1"
            DotSlider {
                implicitWidth: Theme.px(190)
                count: 21
                value: (Config.inputSensitivity + 1) / 2
                display: (Config.inputSensitivity > 0 ? "+" : "") + Number(Config.inputSensitivity).toFixed(1)
                onMoved: (v) => page.set("inputSensitivity", Math.round((v * 2 - 1) * 10) / 10)
            }
        }

        SettingRow {
            key: "inputAccel"
            label: "Acceleration"
            hint: Config.inputAccel === "flat"
                ? "Flat: the same distance whatever the speed, for games"
                : (Config.inputAccel === "adaptive" ? "Adaptive: faster moves go further"
                                                    : "Whatever the device does by default")
        }

        DotPicker {
            options: [
                { label: "Default", value: "" },
                { label: "Adaptive", value: "adaptive" },
                { label: "Flat", value: "flat" }
            ]
            current: Config.inputAccel
            onPicked: (v) => page.set("inputAccel", v)
        }

        SettingRow {
            key: "inputNaturalScroll"
            label: "Natural scrolling"
            hint: "The wheel moves the page, not the view"
            DotSwitch {
                checked: Config.inputNaturalScroll
                onToggled: (v) => page.set("inputNaturalScroll", v)
            }
        }

        SettingRow {
            key: "inputFollowMouse"
            label: "Focus follows the pointer"
            hint: Config.inputFollowMouse ? "Hovering a window focuses it" : "Click to focus"
            DotSwitch {
                checked: Config.inputFollowMouse
                onToggled: (v) => page.set("inputFollowMouse", v)
            }
        }
    }

    SettingsSection {
        title: "Touchpad"

        SettingRow {
            key: "touchpadNaturalScroll"
            label: "Natural scrolling"
            DotSwitch {
                checked: Config.touchpadNaturalScroll
                onToggled: (v) => page.set("touchpadNaturalScroll", v)
            }
        }

        SettingRow {
            key: "touchpadDisableTyping"
            label: "Ignore while typing"
            DotSwitch {
                checked: Config.touchpadDisableTyping
                onToggled: (v) => page.set("touchpadDisableTyping", v)
            }
        }

        SettingRow {
            key: "touchpadScrollFactor"
            label: "Scroll speed"
            DotSlider {
                implicitWidth: Theme.px(190)
                count: 16
                value: (Config.touchpadScrollFactor - 0.1) / 1.4
                display: Number(Config.touchpadScrollFactor).toFixed(1) + "x"
                onMoved: (v) => page.set("touchpadScrollFactor", Math.round((0.1 + v * 1.4) * 10) / 10)
            }
        }
    }

    SettingsSection {
        title: "Keyboard"

        SettingRow {
            key: "inputRepeatDelay"
            label: "Repeat delay"
            hint: "How long a key is held before it repeats"
            DotSlider {
                implicitWidth: Theme.px(190)
                count: 16
                value: (Config.inputRepeatDelay - 150) / 750
                display: Config.inputRepeatDelay + " ms"
                onMoved: (v) => page.set("inputRepeatDelay", Math.round((150 + v * 750) / 50) * 50)
            }
        }

        SettingRow {
            key: "inputRepeatRate"
            label: "Repeat rate"
            DotSlider {
                implicitWidth: Theme.px(190)
                count: 16
                value: (Config.inputRepeatRate - 10) / 50
                display: Config.inputRepeatRate + " /s"
                onMoved: (v) => page.set("inputRepeatRate", Math.round(10 + v * 50))
            }
        }

        SettingRow {
            key: "inputNumlock"
            label: "Num Lock on at login"
            DotSwitch {
                checked: Config.inputNumlock
                onToggled: (v) => page.set("inputNumlock", v)
            }
        }

        SettingRow {
            label: "Keyboard layout"
            hint: "Detected at login by hypr/hyprland/variables.lua; set it in custom.lua to force one"
        }
    }

    SettingsSection {
        title: "Input file"

        SettingRow {
            key: "inputReset"
            label: Input.written ? "~/.config/hypr/input.lua" : "Nothing written yet"
            hint: Input.error !== ""
                ? "Hyprland refused it: " + Input.error
                : "custom.lua is read after this file, so its values win"
            NPillButton {
                text: "Back to defaults"
                visible: Input.written
                onActivated: Input.reset()
            }
        }
    }
}
