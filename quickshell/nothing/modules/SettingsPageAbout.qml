import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"

SettingsPage {
    id: page

    property string hyprVersion: "…"
    property string qsVersion: "…"

    property bool armed: false
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = false }

    NProcess {
        running: true
        command: ["sh", "-c",
            "hyprctl version | head -1 | cut -d' ' -f1-2; quickshell --version"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                page.hyprVersion = l[0] ?? "inconnu";
                page.qsVersion = (l[1] ?? "").replace(/\s*\(.*$/, "") || "inconnu";
            }
        }
    }

    NProcess { id: sh; function run(cmd) { command = ["sh", "-c", cmd]; running = true; } }

    SettingsSection {
        title: "Versions"

        SettingRow {
            key: "versions"
            label: "Hyprland"
            hint: page.hyprVersion
        }
        SettingRow {
            label: "Quickshell"
            hint: page.qsVersion
        }
        SettingRow {
            label: "Fonts"
            hint: Theme.f.display + "  ·  " + Theme.f.sans
        }
    }

    SettingsSection {
        title: "Files"

        SettingRow {
            key: "configFile"
            label: "Configuration"
            hint: Config.path.replace(Quickshell.env("HOME"), "~")
            interactive: true
            onActivated: sh.run(`xdg-open ${JSON.stringify(Config.dir)}`)
            NIcon { text: "󰏋"; size: Theme.z.icon; color: Theme.c.onDim }
        }

        SettingRow {
            label: "Theme repository"
            hint: Quickshell.shellDir.replace(Quickshell.env("HOME"), "~")
            interactive: true
            onActivated: sh.run(`xdg-open ${JSON.stringify(Quickshell.shellDir)}`)
            NIcon { text: "󰏋"; size: Theme.z.icon; color: Theme.c.onDim }
        }
    }

    SettingsSection {
        title: "Maintenance"

        SettingRow {
            key: "reloadShell"
            label: "Reload the shell"
            hint: "Restarts Quickshell without touching the session"
            interactive: true
            onActivated: Power.restartShell()
            NIcon { text: "󰑐"; size: Theme.z.icon; color: Theme.c.onDim }
        }

        // Two-step: the button first says what it will do, and only acts on
        // the second press. A full reset is irreversible, and the button sits
        // a click away from "Reload the shell".
        SettingRow {
            key: "reset"
            label: "Reset settings"
            hint: page.armed
                ? "Every value goes back to its default. Click again to confirm."
                : "Resets every value to its default"
            NPillButton {
                text: page.armed ? "Confirm" : "Reset"
                danger: true
                onActivated: {
                    if (page.armed) {
                        Config.reset();
                        page.armed = false;
                        return;
                    }
                    page.armed = true;
                    disarm.restart();
                }
            }
        }
    }
}
