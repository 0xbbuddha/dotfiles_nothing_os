import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Essential Space and Essential Search, kept together: the shelf, the
// key, and whether SUPER mixes captures into the launcher.
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
                    : "Stub: title from the first line")
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
