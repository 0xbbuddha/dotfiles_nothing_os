import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Essential Space, Search and Apps, kept together: the shelf, the key,
// whether SUPER mixes captures into the launcher, and which generated
// apps sit on the desktop. Mind is shared by all three, so it lives at
// the bottom rather than in any one of them.
SettingsPage {
    id: page

    SettingsSection {
        title: "Space"

        SettingRow {
            key: "essential"
            label: "Essential Space"
            hint: "Click the key to capture, double-click to open, hold to record a voice note. SUPER+A still opens."
            DotSwitch {
                checked: Config.essentialEnabled
                onToggled: (v) => { Config.essentialEnabled = v; Config.save(); }
            }
        }

        SettingRow {
            key: "essentialSide"
            label: "Shelf"
            hint: "Opens on this edge, under the bar"
        }

        DotPicker {
            options: [
                { label: "Right", value: "right" },
                { label: "Left",  value: "left" }
            ]
            current: Config.essentialSide
            onPicked: (v) => { Config.essentialSide = v; Config.save(); }
        }
    }

    SettingsSection {
        title: "Search"

        SettingRow {
            key: "essentialSearch"
            label: "Essential Search"
            hint: Config.essentialSearch
                ? "SUPER mixes captures and settings, with Ask for Gemini"
                : "SUPER stays a normal app launcher — no captures, no Ask"
            DotSwitch {
                checked: Config.essentialSearch
                onToggled: (v) => { Config.essentialSearch = v; Config.save(); }
            }
        }
    }

    SettingsSection {
        title: "Apps"

        SettingRow {
            key: "appsKey"
            label: "Button in the bar"
            hint: "Left of the clock, where the Essential Key sits on the right"
            DotSwitch {
                checked: Config.appsKey
                onToggled: (v) => { Config.appsKey = v; Config.save(); }
            }
        }

        SettingRow {
            key: "deskApps"
            label: "Apps on the desktop"
            hint: Config.showDeskApps
                ? (Config.deskApps ?? []).length + " in the right column. Widgets keep the left one."
                : "Hidden. The library stays available with SUPER+ALT+A."
            DotSwitch {
                checked: Config.showDeskApps
                onToggled: (v) => { Config.showDeskApps = v; Config.save(); }
            }
        }

        Repeater {
            model: Config.deskApps ?? []

            Rectangle {
                id: pinned
                required property string modelData
                required property int index
                readonly property var spec: {
                    MiniApps.stamp;
                    return MiniApps.specOf(pinned.modelData);
                }

                Layout.fillWidth: true
                implicitHeight: Theme.px(46)
                radius: Theme.r.chip
                color: Theme.c.surface2

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(3)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(3)
                    height: Theme.px(18)
                    radius: width / 2
                    color: Theme.c.red
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(16)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(12)

                    NIcon {
                        text: pinned.spec?.icon ?? "󰀻"
                        size: Theme.z.iconM
                        color: Theme.c.on
                        Layout.preferredWidth: Theme.px(18)
                    }

                    NText {
                        Layout.fillWidth: true
                        // A pin can outlive its app: the spec is gone but
                        // the id stays in config.json until it is removed.
                        text: pinned.spec?.name ?? (pinned.modelData + " (missing)")
                        color: pinned.spec ? Theme.c.on : Theme.c.onDim
                        font.pixelSize: Theme.f.body
                        elide: Text.ElideRight
                    }

                    NLabel { text: (pinned.index + 1) + "/" + (Config.deskApps ?? []).length }

                    CircleButton {
                        icon: "󰁝"
                        size: Theme.px(24)
                        enabled: pinned.index > 0
                        opacity: enabled ? 1 : 0.25
                        onActivated: Config.moveDeskApp(pinned.index, -1)
                    }
                    CircleButton {
                        icon: "󰁅"
                        size: Theme.px(24)
                        enabled: pinned.index < (Config.deskApps ?? []).length - 1
                        opacity: enabled ? 1 : 0.25
                        onActivated: Config.moveDeskApp(pinned.index, 1)
                    }
                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(24)
                        onActivated: Config.removeDeskApp(pinned.modelData)
                    }
                }
            }
        }

        NText {
            Layout.fillWidth: true
            visible: (Config.deskApps ?? []).length === 0
            text: MiniApps.empty
                ? "No apps yet. SUPER+ALT+A opens the library, where a prompt writes one."
                : "None pinned. Open the library and use the plus on a card."
            color: Theme.c.onDim
            wrapMode: Text.WordWrap
        }

        SettingRow {
            key: "appsLibrary"
            label: "Library"
            hint: MiniApps.specs.length + " apps written, in ~/.local/share/nothing/apps"
            NPillButton {
                text: "OPEN"
                onActivated: {
                    GlobalState.closeAll();
                    GlobalState.appsOpen = true;
                }
            }
        }
    }

    SettingsSection {
        title: "Mind"

        SettingRow {
            key: "mind"
            label: "Mind"
            hint: Config.mindBackend === "gemini"
                ? (Essentials.hasGeminiKey
                    ? "Gemini — key saved locally"
                    : "Gemini — paste a key from Google AI Studio")
                : (Config.mindBackend === "ollama"
                    ? "Ollama must be running locally"
                    : "Stub: title from the first line. Apps cannot be written on stub.")
        }

        DotPicker {
            options: [
                { label: "Stub",   value: "stub" },
                { label: "Ollama", value: "ollama" },
                { label: "Gemini", value: "gemini" }
            ]
            current: Config.mindBackend
            onPicked: (v) => {
                Config.mindBackend = v;
                Config.save();
                Essentials.setBackend(v);
            }
        }

        SettingRow {
            key: "geminiKey"
            visible: Config.mindBackend === "gemini"
            label: "Gemini API key"
            hint: "Stored in ~/.config/nothing/mind.env, not in config.json"
            NField {
                implicitWidth: Theme.px(180)
                secret: true
                placeholder: Essentials.hasGeminiKey ? "Key saved — paste to replace" : "Paste key"
                onCommitted: (v) => {
                    const t = v.trim();
                    if (t === "")
                        return;
                    Essentials.setGeminiKey(t);
                    clear();
                }
            }
        }
    }
}
