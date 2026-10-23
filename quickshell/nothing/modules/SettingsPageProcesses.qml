import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// What is using the CPU and the memory right now, grouped by program, with
// a way to close one that has stopped answering. CTRL+SHIFT+Escape opens
// this page. Sampling runs only while it is on screen (services/Processes).
SettingsPage {
    id: page

    property string armed: ""
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = "" }

    Binding {
        target: Processes
        property: "active"
        value: page.current && GlobalState.settingsOpen
    }

    SettingsSection {
        title: "Processes"

        SettingRow {
            key: "processes"
            label: "Memory " + Processes.gb(Processes.memUsed) + " of " + Processes.gb(Processes.memTotal)
            hint: Processes.status !== "" ? Processes.status
                : "CPU: 100 % is one full core, " + Processes.cores + " cores in all"
        }

        SegmentedControl {
            Layout.fillWidth: true
            options: [
                { label: "By CPU", value: "cpu" },
                { label: "By memory", value: "mem" }
            ]
            current: Processes.sort
            onPicked: (v) => Processes.sort = v
        }

        Repeater {
            model: Processes.items

            Rectangle {
                id: proc
                required property var modelData
                readonly property bool can: modelData.mine && !modelData.protected
                Layout.fillWidth: true
                implicitHeight: Theme.px(34)
                radius: Theme.r.tiny
                color: Theme.c.surface2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(6)
                    spacing: Theme.px(9)

                    NText {
                        Layout.fillWidth: true
                        text: proc.modelData.name
                            + (proc.modelData.pids.length > 1 ? "  ×" + proc.modelData.pids.length : "")
                        color: proc.can ? Theme.c.on : Theme.c.onDim
                        elide: Text.ElideRight
                    }
                    NText {
                        Layout.preferredWidth: Theme.px(64)
                        horizontalAlignment: Text.AlignRight
                        text: proc.modelData.cpu.toFixed(proc.modelData.cpu < 10 ? 1 : 0) + " %"
                        font.family: Theme.f.mono
                        font.pixelSize: Theme.f.small
                        color: proc.modelData.cpu >= 80 ? Theme.c.red
                             : (Processes.sort === "cpu" ? Theme.c.on : Theme.c.onDim)
                    }
                    NText {
                        Layout.preferredWidth: Theme.px(72)
                        horizontalAlignment: Text.AlignRight
                        text: Processes.gb(proc.modelData.mem)
                        font.family: Theme.f.mono
                        font.pixelSize: Theme.f.small
                        color: Processes.sort === "mem" ? Theme.c.on : Theme.c.onDim
                    }
                    Item {
                        Layout.preferredWidth: Theme.px(140)
                        implicitHeight: Theme.px(28)

                        NLabel {
                            anchors.centerIn: parent
                            visible: !proc.can
                            text: proc.modelData.protected ? "session" : "system"
                        }
                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: proc.can
                            spacing: Theme.px(4)

                            NPillButton {
                                // Two presses: closing the wrong browser
                                // loses every tab in it.
                                text: page.armed === proc.modelData.name ? "Confirm" : "End"
                                danger: page.armed === proc.modelData.name
                                onActivated: {
                                    if (page.armed === proc.modelData.name) {
                                        page.armed = "";
                                        Processes.end(proc.modelData, false);
                                        return;
                                    }
                                    page.armed = proc.modelData.name;
                                    disarm.restart();
                                }
                            }
                            NPillButton {
                                // Only after End, for a program that did
                                // not listen.
                                visible: Processes.ended[proc.modelData.name] === true
                                text: "Force"
                                danger: true
                                onActivated: Processes.end(proc.modelData, true)
                            }
                        }
                    }
                }
            }
        }
    }
}
