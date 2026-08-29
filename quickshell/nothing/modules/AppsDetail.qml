import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../components/apps"
import "../services"

// One app opened, stacked rather than side by side: the shelf is narrow,
// so the app sits on top and everything you can do to it follows under.
Flickable {
    id: root

    property var spec: null
    signal closed()

    readonly property string appId: root.spec?.id ?? ""
    property bool confirming: false
    property bool coding: false

    contentWidth: width
    contentHeight: col.implicitHeight + Theme.pad * 2
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    // The runtime folds saved state into the spec when it lists it; the
    // editor must show what the file holds, not that.
    readonly property string pretty: {
        if (!root.spec)
            return "";
        const copy = JSON.parse(JSON.stringify(root.spec));
        for (const key of ["saved", "id", "created", "version", "history", "preset"])
            delete copy[key];
        return JSON.stringify(copy, null, 2);
    }

    onAppIdChanged: {
        root.confirming = false;
        root.coding = false;
        code.text = root.pretty;
    }
    onPrettyChanged: if (!code.activeFocus) code.text = root.pretty

    function sourceLabel(name: string): string {
        switch (name) {
        case "time":    return "CLOCK";
        case "weather": return "WEATHER";
        case "sys":     return "CPU / RAM";
        case "media":   return "NOW PLAYING";
        case "net":     return "NETWORK";
        case "vault":   return "ESSENTIAL SPACE";
        case "notify":  return "NOTIFICATIONS";
        case "audio":   return "VOLUME";
        case "battery": return "BATTERY";
        case "updates": return "UPDATES";
        case "notifs":  return "NOTIFICATIONS";
        case "desktop": return "WORKSPACE";
        default:        return name.toUpperCase();
        }
    }

    function host(url: string): string {
        const m = /^https:\/\/([^\/]+)/.exec(url ?? "");
        return m ? m[1] : "";
    }

    ColumnLayout {
        id: col
        x: Theme.pad
        y: Theme.px(2)
        width: root.width - Theme.pad * 2
        spacing: Theme.px(14)

        // ── The app, running ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: live.implicitHeight
            radius: Theme.r.chip
            color: Theme.c.surface2
            clip: true

            AppHost {
                id: live
                anchors.left: parent.left
                anchors.right: parent.right
                visible: root.spec !== null
                spec: root.spec ?? ({})
                chrome: false
                closable: false
                flat: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            NPillButton {
                text: Config.hasDeskApp(root.appId) ? "ON DESKTOP" : "ADD TO DESKTOP"
                onActivated: Config.toggleDeskApp(root.appId)
            }

            Item { Layout.fillWidth: true }

            CircleButton {
                icon: "󰑐"
                size: Theme.px(24)
                visible: !!root.spec?.fetch
                onActivated: MiniApps.refetch(root.appId)
            }

            CircleButton {
                icon: "󰦛"
                size: Theme.px(24)
                onActivated: MiniApps.reset(root.appId)
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

        // ── What it reads ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(7)

            NLabel { text: "READS"; dim: false }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.px(5)

                Repeater {
                    model: root.spec?.sources ?? []

                    Rectangle {
                        required property string modelData
                        implicitWidth: tag.implicitWidth + Theme.px(18)
                        implicitHeight: Theme.px(22)
                        radius: height / 2
                        color: Theme.c.surface2

                        NLabel {
                            id: tag
                            anchors.centerIn: parent
                            text: root.sourceLabel(parent.modelData)
                            dim: false
                        }
                    }
                }
            }

            NText {
                Layout.fillWidth: true
                visible: (root.spec?.sources ?? []).length === 0
                text: "Nothing. This app only uses what you type into it."
                color: Theme.c.onDim
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !!root.spec?.fetch
                spacing: Theme.px(8)

                NIcon { text: "󰖩"; size: Theme.z.icon; color: Theme.c.red }

                Text {
                    Layout.fillWidth: true
                    text: root.host(root.spec?.fetch?.url ?? "")
                        + "  ·  every " + Math.round((root.spec?.fetch?.every ?? 900) / 60) + " min"
                    color: Theme.c.onDim
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.small
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

        // ── How it got here ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            NLabel { text: "PROMPT"; dim: false }

            NText {
                Layout.fillWidth: true
                text: root.spec?.prompt ?? ""
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: (root.spec?.history ?? []).slice(1)

                RowLayout {
                    id: step
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.px(2)
                    spacing: Theme.px(8)

                    NLabel { text: "V" + (step.index + 2) }

                    NText {
                        Layout.fillWidth: true
                        text: step.modelData
                        color: Theme.c.onDim
                        wrapMode: Text.WordWrap
                    }

                    CircleButton {
                        icon: "󰕌"
                        size: Theme.px(20)
                        visible: (step.index + 2) < (root.spec?.version ?? 1)
                        onActivated: MiniApps.revert(root.appId, step.index + 2)
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

        // ── The spec, by hand ────────────────────────────────────────
        // The escape hatch. It goes back through the same validator as a
        // generated app: editing the JSON is not a way past it.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(7)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                NLabel { text: "SPEC"; dim: false }
                Item { Layout.fillWidth: true }

                NPillButton {
                    text: root.coding ? "HIDE" : "EDIT"
                    onActivated: {
                        root.coding = !root.coding;
                        if (root.coding)
                            code.text = root.pretty;
                    }
                }

                NPillButton {
                    text: "SAVE"
                    visible: root.coding
                    onActivated: MiniApps.put(root.appId, code.text)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: root.coding ? Theme.px(240) : 0
                visible: root.coding
                radius: Theme.r.tiny
                color: Theme.c.surface2
                border.width: 1
                border.color: code.activeFocus ? Theme.c.red : Theme.c.outline
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Theme.px(8)
                    contentWidth: Math.max(width, code.implicitWidth)
                    contentHeight: code.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    TextEdit {
                        id: code
                        color: Theme.c.on
                        font.family: Theme.f.mono
                        font.pixelSize: Theme.f.small
                        selectByMouse: true
                        selectionColor: Theme.c.red
                        wrapMode: TextEdit.NoWrap
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

        // ── Removal ──────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.px(6)
            spacing: Theme.px(8)

            NText {
                Layout.fillWidth: true
                visible: root.confirming
                text: "This deletes the app and everything it saved."
                color: Theme.c.red
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                NPillButton {
                    text: "CANCEL"
                    visible: root.confirming
                    onActivated: root.confirming = false
                }

                Item { Layout.fillWidth: true }

                NPillButton {
                    text: root.confirming ? "DELETE FOR GOOD" : "DELETE"
                    danger: true
                    onActivated: {
                        if (!root.confirming) {
                            root.confirming = true;
                            return;
                        }
                        const id = root.appId;
                        root.confirming = false;
                        root.closed();
                        MiniApps.remove(id);
                    }
                }
            }
        }
    }
}
