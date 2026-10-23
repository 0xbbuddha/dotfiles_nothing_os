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
    property string restoreArmed: ""
    Timer { id: disarmRestore; interval: 4000; onTriggered: page.restoreArmed = "" }

    // config-20261023-201500.json -> "23/10/2026 20:15"
    function backupLabel(name: string): string {
        const m = name.match(/^config-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})/);
        const when = m ? m[3] + "/" + m[2] + "/" + m[1] + " " + m[4] + ":" + m[5] : name;
        if (name.indexOf("before-restore") >= 0)
            return when + " · before a restore";
        return name.indexOf("-auto") >= 0 ? when + " · automatic" : when;
    }

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

    // Apps opened at login: picked from the installed ones, launched the
    // way the launcher launches them. See services/Autostart.qml.
    property string startupFilter: ""

    SettingsSection {
        title: "Startup apps"

        SettingRow {
            key: "autostartApps"
            label: "Open at login"
            hint: (Config.autostartApps ?? []).length === 0
                ? "Nothing yet: add apps below. Your own exec-once lines are left alone"
                : "Once per session, skipped if already running"
                  + (Autostart.skipped.length > 0
                     ? ". Last run skipped: " + Autostart.skipped.map(x => x.id + " (" + x.why + ")").join(", ")
                     : "")
            NPillButton {
                visible: (Config.autostartApps ?? []).length > 0
                text: "Start now"
                onActivated: Autostart.startNow()
            }
        }

        Repeater {
            model: Config.autostartApps ?? []

            Rectangle {
                id: chosen
                required property string modelData
                readonly property var entry: Apps.entry(modelData)

                Layout.fillWidth: true
                implicitHeight: Theme.px(34)
                radius: Theme.r.tiny
                color: Theme.c.surface2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(6)
                    spacing: Theme.px(9)

                    AppIcon { iconName: chosen.entry?.icon ?? ""; size: Theme.px(17) }

                    NText {
                        Layout.fillWidth: true
                        text: chosen.entry ? chosen.entry.name : chosen.modelData + " (not installed)"
                        color: chosen.entry ? Theme.c.on : Theme.c.onFaint
                        elide: Text.ElideRight
                    }

                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(22)
                        onActivated: Autostart.remove(chosen.modelData)
                    }
                }
            }
        }

        SettingRow {
            key: "autostartDelay"
            label: "Wait after login"
            hint: "Gives the tray and the keyring time to come up first"
        }

        DotPicker {
            options: [
                { label: "0 s", value: 0 },
                { label: "3 s", value: 3 },
                { label: "10 s", value: 10 },
                { label: "30 s", value: 30 }
            ]
            current: Config.autostartDelay
            onPicked: (v) => { Config.autostartDelay = v; Config.save(); }
        }
    }

    SettingsSection {
        title: "Add a startup app"

        NField {
            Layout.fillWidth: true
            placeholder: "Search installed applications…"
            onTextChanged: page.startupFilter = text
        }

        Repeater {
            model: {
                const q = page.startupFilter.trim().toLowerCase();
                const pool = Apps.visible.filter(e => !(Config.autostartApps ?? []).includes(e.id));
                if (q === "") return pool.slice(0, 6);
                return pool.filter(e => e.name.toLowerCase().includes(q)
                                     || e.id.toLowerCase().includes(q)).slice(0, 10);
            }

            Rectangle {
                id: cand
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Theme.px(34)
                radius: Theme.r.tiny
                color: cma.containsMouse ? Theme.c.surface3 : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(9)

                    AppIcon { iconName: cand.modelData.icon; size: Theme.px(17) }

                    NText {
                        Layout.fillWidth: true
                        text: cand.modelData.name
                        font.pixelSize: Theme.f.body
                        elide: Text.ElideRight
                    }

                    NIcon { text: "󰐕"; size: Theme.z.icon; color: Theme.c.onDim }
                }

                MouseArea {
                    id: cma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Autostart.add(cand.modelData.id)
                }
            }
        }
    }

    SettingsSection {
        title: "Removable drives"

        SettingRow {
            key: "drivesAutomount"
            label: "Mount when plugged in"
            hint: !Drives.available ? "Needs udisks2 (udisksctl)"
                : "USB sticks and SD cards, not encrypted ones; Eject in the control centre or the bar"
            DotSwitch {
                checked: Config.drivesAutomount
                onToggled: (v) => { Config.drivesAutomount = v; Config.save(); }
            }
        }

        SettingRow {
            key: "drivesNotify"
            label: "Notify on plug, mount and eject"
            DotSwitch {
                checked: Config.drivesNotify
                onToggled: (v) => { Config.drivesNotify = v; Config.save(); }
            }
        }
    }

    // Copies of config.json: one click to save, one to put back. Restoring
    // keeps what it replaces, so it can be undone from the same list.
    SettingsSection {
        title: "Backups"

        SettingRow {
            key: "settingsBackup"
            label: "Back up settings"
            hint: ConfigBackup.status !== "" ? ConfigBackup.status
                : "A copy of config.json in ~/.config/nothing/backups"
            NPillButton {
                text: ConfigBackup.busy ? "…" : "Back up now"
                onActivated: ConfigBackup.backup(false)
            }
        }

        SettingRow {
            key: "autoBackup"
            label: "Daily automatic backup"
            hint: "Once a day, the seven newest kept; your own backups are never deleted"
            DotSwitch {
                checked: Config.autoBackup
                onToggled: (v) => { Config.autoBackup = v; Config.save(); if (v) ConfigBackup.refresh(); }
            }
        }

        SettingRow {
            key: "settingsRestore"
            label: "Restore settings"
            hint: ConfigBackup.list.length === 0
                ? "No backup yet"
                : (page.restoreArmed !== ""
                   ? "Replace every setting with " + page.restoreArmed + "? Click again to confirm."
                   : ConfigBackup.list.length + " backup" + (ConfigBackup.list.length > 1 ? "s" : "")
                     + ". The current settings are kept aside first.")
            NPillButton {
                text: "Folder"
                onActivated: ConfigBackup.openFolder()
            }
        }

        Repeater {
            // The ten newest; the folder has the rest.
            model: ConfigBackup.list.slice(0, 10)

            SettingRow {
                required property string modelData
                label: page.backupLabel(modelData)
                hint: modelData
                NPillButton {
                    text: page.restoreArmed === modelData ? "Confirm" : "Restore"
                    danger: page.restoreArmed === modelData
                    onActivated: {
                        if (page.restoreArmed === modelData) {
                            page.restoreArmed = "";
                            ConfigBackup.restore(modelData);
                            return;
                        }
                        page.restoreArmed = modelData;
                        disarmRestore.restart();
                    }
                }
            }
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
