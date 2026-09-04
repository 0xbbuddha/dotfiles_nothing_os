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
                page.hyprVersion = l[0] ?? "Unknown";
                page.qsVersion = (l[1] ?? "").replace(/\s*\(.*$/, "") || "Unknown";
            }
        }
    }

    NProcess { id: sh; function run(cmd) { command = ["sh", "-c", cmd]; running = true; } }

    // The machine, with its own mark behind it.
    //
    // Not a logo dropped in a corner: it is set large, clipped by the card
    // and held at a low opacity, so it reads as the card's material rather
    // than as a picture of a distribution. EndeavourOS and the rest of the
    // Arch family all show the Arch mark, because that is what the system
    // descends from and what its packages come from; a distribution with
    // no mark here simply gets none, rather than a stand-in.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.px(132)
        radius: Theme.r.chip
        color: Theme.c.surface2
        clip: true

        NVectorIcon {
            anchors.right: parent.right
            anchors.rightMargin: -Theme.px(26)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(176)
            height: Theme.px(176)
            visible: Sys.distroMark !== ""
            icon: Sys.distroMark
            color: Theme.c.on
            opacity: 0.07
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.px(20)
            anchors.rightMargin: Theme.px(20)
            spacing: Theme.px(2)

            NLabel { text: "T H I S   M A C H I N E" }

            NText {
                Layout.fillWidth: true
                text: Sys.distro !== "" ? Sys.distro : "Linux"
                font.pixelSize: Theme.px(26)
                font.family: Theme.f.display
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.topMargin: Theme.px(6)
                spacing: Theme.px(18)

                Repeater {
                    model: [
                        { k: "Kernel", v: Sys.kernel },
                        { k: "Host",   v: Sys.host },
                        { k: "Up",     v: Sys.prettyUptime() }
                    ]

                    // Named, not reached through parent: counting parents
                    // up from a nested delegate breaks the moment anything
                    // is wrapped, and it broke here.
                    ColumnLayout {
                        id: fact
                        required property var modelData

                        visible: (fact.modelData.v ?? "") !== ""
                        spacing: 0

                        NLabel { text: fact.modelData.k }
                        NText {
                            text: fact.modelData.v
                            font.family: Theme.f.mono
                            font.pixelSize: Theme.f.small
                        }
                    }
                }
            }
        }
    }

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
