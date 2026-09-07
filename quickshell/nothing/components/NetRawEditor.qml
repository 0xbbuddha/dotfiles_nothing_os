import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// The NetworkManager profile, key by key.
//
// Every value is shown as JSON and read back as JSON, because the map
// holds strings, booleans, numbers and lists side by side and a plain
// text field cannot tell 1 from "1". Anything that will not parse is
// kept as a string, which is what a bare interface name wants anyway.
//
// Only edited keys are sent. write() takes a partial map, so leaving the
// rest out is both correct and much safer than posting the whole thing
// back: a value NM handed us read-only would otherwise be written again.
ColumnLayout {
    id: root
    required property var network
    required property var map

    signal wrote()

    // "group key" -> text, for the rows the user actually touched.
    property var edits: ({})
    readonly property int pending: Object.keys(root.edits).length

    function keyOf(group: string, key: string): string { return group + " " + key; }

    function stage(group: string, key: string, text: string): void {
        const e = {};
        for (const k in root.edits)
            e[k] = root.edits[k];
        e[root.keyOf(group, key)] = text;
        root.edits = e;
    }

    function parse(text: string): var {
        const t = text.trim();
        if (t === "null")
            return null;
        try {
            return JSON.parse(t);
        } catch (err) {
            // Not JSON, so it is a plain string: wlan0, wpa-psk.
            return t;
        }
    }

    function apply(): void {
        const patch = {};
        for (const k in root.edits) {
            const parts = k.split(" ");
            if (!patch[parts[0]])
                patch[parts[0]] = {};
            patch[parts[0]][parts[1]] = root.parse(root.edits[k]);
        }
        if (Net.writeProfile(root.network, patch))
            root.edits = ({});
        root.wrote();
    }

    // Flattened for the Repeater: QML models do not walk a nested map.
    readonly property var rows: {
        const out = [];
        for (const group in root.map) {
            const inner = root.map[group];
            for (const key in inner)
                out.push({ group: group, key: key,
                           text: JSON.stringify(inner[key]) });
        }
        return out;
    }

    Layout.fillWidth: true
    spacing: Theme.px(4)

    NText {
        Layout.fillWidth: true
        Layout.topMargin: Theme.px(6)
        text: "Written straight to NetworkManager. A wrong value here "
            + "breaks this connection until you fix it or forget the network."
        color: Theme.c.red
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.rows

        Rectangle {
            id: line
            required property var modelData
            readonly property string stored:
                root.edits[root.keyOf(modelData.group, modelData.key)] ?? ""
            readonly property bool touched: line.stored !== ""

            Layout.fillWidth: true
            implicitHeight: Theme.px(32)
            radius: Theme.r.tiny
            color: line.touched ? Theme.c.surface3 : Theme.c.surface2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(6)
                spacing: Theme.px(8)

                NLabel {
                    Layout.preferredWidth: Theme.px(150)
                    text: line.modelData.group + " . " + line.modelData.key
                    elide: Text.ElideLeft
                    color: line.touched ? Theme.c.red : Theme.c.onDim
                }

                NField {
                    Layout.fillWidth: true
                    implicitWidth: 0
                    implicitHeight: Theme.px(26)
                    color: "transparent"
                    border.width: 0
                    text: line.modelData.text
                    // Staged, not written: nothing reaches NM until Apply.
                    onCommitted: (v) => root.stage(line.modelData.group,
                                                   line.modelData.key, v)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.px(4)
        spacing: Theme.px(8)

        NLabel {
            Layout.fillWidth: true
            text: root.pending === 0
                ? "Press enter in a field to stage a change"
                : root.pending + " staged"
            color: root.pending > 0 ? Theme.c.red : Theme.c.onFaint
        }

        NPillButton {
            text: "Discard"
            visible: root.pending > 0
            onActivated: root.edits = ({})
        }

        NPillButton {
            text: "Apply"
            danger: true
            visible: root.pending > 0
            onActivated: root.apply()
        }
    }
}
