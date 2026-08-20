import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// Open + extra notification actions (Mark as read, …).
RowLayout {
    id: root
    required property var entry
    spacing: Theme.px(5)

    readonly property var extra: Notifs.listedActions(entry)
    visible: Notifs.canOpen(entry) || extra.length > 0

    Repeater {
        model: {
            const row = [];
            if (Notifs.canOpen(root.entry))
                row.push({ kind: "open", text: Notifs.isChat(root.entry) ? "Open message" : "Open" });
            const extra = root.extra;
            for (let i = 0; i < extra.length; i++)
                row.push({ kind: "act", text: extra[i].text, action: extra[i] });
            return row;
        }

        Rectangle {
            id: chip
            required property var modelData

            implicitWidth: label.implicitWidth + Theme.px(20)
            implicitHeight: Theme.px(23)
            radius: Theme.r.tiny
            color: ma.containsMouse ? Theme.c.on : Theme.c.surface3
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            Text {
                id: label
                anchors.centerIn: parent
                text: chip.modelData.text
                color: ma.containsMouse ? Theme.c.surface : Theme.c.on
                font.family: Theme.f.sans
                font.pixelSize: Theme.f.small
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (chip.modelData.kind === "open")
                        Notifs.activate(root.entry);
                    else
                        Notifs.invokeAction(root.entry, chip.modelData.action);
                }
            }
        }
    }
}
