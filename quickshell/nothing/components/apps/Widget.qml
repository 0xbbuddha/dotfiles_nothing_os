import QtQuick
import QtQuick.Layouts
import "../.."
import ".."
import "../../services"
import "expr.js" as Expr

// One Essential App tile. Sizes match Nothing widgets: s is 2×2, m is
// a 2×4 strip, l is 4×4. Faces are the layouts the model actually hits;
// custom falls back to the block tree.
Item {
    id: root

    required property var spec
    property bool tools: false
    signal edited()
    signal dropped()

    readonly property string appId: root.spec?.id ?? ""
    readonly property string sizeKey: {
        const s = root.spec?.size ?? "s";
        return (s === "m" || s === "l") ? s : "s";
    }
    readonly property string face: {
        const f = (root.spec?.face ?? "").toString();
        if (f !== "")
            return f;
        return (root.spec?.body && root.spec.body.length > 0) ? "custom" : "stat";
    }
    readonly property var ctx: {
        MiniApps.pulse;
        return root.spec ? MiniApps.ctxFor(root.spec) : null;
    }
    readonly property var slots: root.spec?.slots ?? ({})

    readonly property int tileW: root.sizeKey === "s"
        ? Math.floor((Theme.z.widgets - Theme.gap) / 2)
        : Theme.z.widgets
    readonly property int tileH: {
        if (root.sizeKey === "s")
            return root.tileW;
        if (root.sizeKey === "m")
            return Theme.px(148);
        return Theme.z.widgets;
    }

    implicitWidth: root.tileW
    implicitHeight: root.tileH
    width: implicitWidth
    height: implicitHeight

    function txt(field: string, fallback: string): string {
        const src = root.slots[field];
        if (src === undefined || src === "")
            return fallback ?? "";
        const v = Expr.asText(src, root.ctx, null, 0);
        return v !== "" ? v : (fallback ?? "");
    }

    function num(field: string, fallback: real): real {
        const src = root.slots[field];
        if (src === undefined || src === "")
            return fallback;
        return Expr.asNumber(src, root.ctx, null, 0, fallback);
    }

    function rows(): var {
        const src = root.slots.rows;
        if (!src)
            return [];
        return Expr.asArray(src, root.ctx, null, 0).slice(0, 5);
    }

    Rectangle {
        id: tile
        anchors.fill: parent
        radius: Theme.r.chip
        color: Theme.c.surface
        clip: true
        border.width: 1
        border.color: Theme.c.outline

        // ── stat / tracker / clock / media / note ────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(12)
            spacing: Theme.px(4)
            visible: root.face !== "custom" && root.face !== "list"

            NLabel {
                Layout.fillWidth: true
                text: (root.spec?.title || root.spec?.name || "").toString()
                elide: Text.ElideRight
                visible: root.face !== "media"
            }

            Item { Layout.fillHeight: root.face === "note" }

            DisplayText {
                Layout.fillWidth: true
                visible: root.face === "stat" || root.face === "tracker"
                    || root.face === "clock"
                text: {
                    if (root.face === "clock")
                        return root.ctx?.time?.hhmm ?? "--:--";
                    const v = root.txt("value", "—");
                    return v === "" ? "—" : v;
                }
                size: root.sizeKey === "s" ? Theme.px(28) : Theme.px(36)
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.face === "stat" || root.face === "tracker"
                spacing: Theme.px(4)

                NText {
                    text: root.txt("unit", "")
                    color: Theme.c.red
                    font.pixelSize: Theme.f.body
                    visible: text !== ""
                }
                NText {
                    Layout.fillWidth: true
                    text: root.face === "clock"
                        ? (root.ctx?.time?.dateLong ?? "")
                        : root.txt("caption", "")
                    color: Theme.c.onDim
                    elide: Text.ElideRight
                    font.letterSpacing: Theme.f.track
                    font.pixelSize: Theme.f.micro
                    font.capitalization: Font.AllUppercase
                }
            }

            NText {
                Layout.fillWidth: true
                visible: root.face === "media"
                text: root.ctx?.media?.title || "NOTHING PLAYING"
                font.pixelSize: Theme.f.body
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            NText {
                Layout.fillWidth: true
                visible: root.face === "media"
                text: root.ctx?.media?.artist || ""
                color: Theme.c.onDim
                elide: Text.ElideRight
            }

            NText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.face === "note"
                text: root.txt("note", "")
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                color: Theme.c.on
            }

            // Dots for a tracker
            Row {
                Layout.fillWidth: true
                visible: root.face === "tracker"
                spacing: Theme.px(3)
                Repeater {
                    model: 8
                    Rectangle {
                        required property int index
                        width: Theme.px(7)
                        height: width
                        radius: width / 2
                        readonly property real filled: root.num("progress", 0)
                        color: index < Math.round(filled * 8)
                            ? Theme.c.red : Theme.c.surface3
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                visible: root.face === "tracker"
                    || (root.spec?.primary ?? "") !== ""
                spacing: Theme.px(6)

                Rectangle {
                    Layout.preferredWidth: Theme.px(28)
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.r.tiny
                    color: minusMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                    visible: root.face === "tracker"
                    NText {
                        anchors.centerIn: parent
                        text: root.spec?.minus || "−"
                        font.pixelSize: Theme.f.body
                    }
                    MouseArea {
                        id: minusMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MiniApps.run(root.appId, "minus", null, 0)
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: primaryLab.implicitWidth + Theme.px(16)
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.r.tiny
                    color: Theme.c.red
                    visible: (root.spec?.primary ?? "") !== ""
                    NText {
                        id: primaryLab
                        anchors.centerIn: parent
                        text: root.spec?.primary ?? ""
                        color: Theme.c.onAccent
                        font.pixelSize: Theme.f.micro
                        font.letterSpacing: Theme.f.track
                        font.capitalization: Font.AllUppercase
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MiniApps.run(root.appId, "primary", null, 0)
                    }
                }

                Item { Layout.fillWidth: root.face !== "tracker" }

                Rectangle {
                    Layout.preferredWidth: Theme.px(28)
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.r.tiny
                    color: plusMa.containsMouse ? Theme.c.red : Theme.c.surface2
                    visible: root.face === "tracker"
                    NText {
                        anchors.centerIn: parent
                        text: root.spec?.plus || "+"
                        font.pixelSize: Theme.f.body
                    }
                    MouseArea {
                        id: plusMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MiniApps.run(root.appId, "plus", null, 0)
                    }
                }
            }
        }

        // ── list ─────────────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(12)
            spacing: Theme.px(6)
            visible: root.face === "list"

            NLabel {
                Layout.fillWidth: true
                text: (root.spec?.title || root.spec?.name || "").toString()
                elide: Text.ElideRight
            }

            Repeater {
                model: root.rows()

                Rectangle {
                    id: line
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: Theme.px(28)
                    radius: Theme.r.tiny
                    color: lineMa.containsMouse ? Theme.c.surface2 : "transparent"

                    readonly property string title: Expr.asText(
                        root.slots.rowTitle || "it.title || it.name || it",
                        root.ctx, line.modelData, line.index)
                    readonly property string sub: Expr.asText(
                        root.slots.rowSub || "it.sub || it.when || ''",
                        root.ctx, line.modelData, line.index)

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        NText {
                            width: parent.width
                            text: line.title
                            elide: Text.ElideRight
                        }
                        NText {
                            width: parent.width
                            text: line.sub
                            color: Theme.c.onDim
                            font.pixelSize: Theme.f.micro
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                    MouseArea {
                        id: lineMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MiniApps.run(root.appId, "open",
                            line.modelData, line.index)
                    }
                }
            }

            NText {
                Layout.fillWidth: true
                visible: root.rows().length === 0
                text: root.txt("empty", "Nothing yet")
                color: Theme.c.onDim
            }
        }

        // ── custom block tree ────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(10)
            spacing: Theme.px(6)
            visible: root.face === "custom"

            Repeater {
                model: root.spec?.body ?? []
                AppSlot {
                    required property var modelData
                    block: modelData
                    appId: root.appId
                    ctx: root.ctx
                }
            }
        }

        HoverHandler { id: hover }

        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.px(6)
            spacing: Theme.px(4)
            visible: root.tools && hover.hovered
            z: 4

            CircleButton {
                icon: "󰏫"
                size: Theme.px(20)
                onActivated: root.edited()
            }
            CircleButton {
                icon: "󰅖"
                size: Theme.px(20)
                onActivated: root.dropped()
            }
        }
    }
}
