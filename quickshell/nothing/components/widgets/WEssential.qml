import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// What is coming up, from Essential Space.
//
// Three rows, always three: a card that shrank with the list would move
// everything under it every time a note gained a date. Empty rows are left
// blank rather than the widget resizing.
//
// The whole tile opens the space, because a summary you cannot act on is
// just a reminder that you have not looked.
NCard {
    id: root
    property bool simple: false
    readonly property int rows: 3

    readonly property var items: {
        void Essentials.stamp;
        return Essentials.upcoming(root.rows);
    }
    readonly property bool empty: false

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(16)
        anchors.rightMargin: Theme.px(16)
        anchors.topMargin: Theme.px(12)
        anchors.bottomMargin: Theme.px(12)
        spacing: Theme.px(6)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(8)
            NIcon { text: "󰠮"; size: Theme.z.iconM; color: Theme.c.on }
            NLabel { Layout.fillWidth: true; text: "Essential" }
            // The total, not the three on show: "3 items" beside three
            // rows told you nothing you could not already see.
            NLabel {
                readonly property int total: {
                    void Essentials.stamp;
                    return Essentials.upcoming(0).length;
                }
                visible: total > 0
                text: total + (total === 1 ? " item" : " items")
            }
        }

        NText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.items.length === 0
            verticalAlignment: Text.AlignVCenter
            text: "Nothing due. Capture something with the Essential key."
            color: Theme.c.onDim
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.items.length > 0 ? root.rows : 0

            RowLayout {
                required property int index
                readonly property var it: root.items[index] ?? null

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: it !== null
                spacing: Theme.px(10)

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: Theme.px(4)
                    height: width
                    radius: width / 2
                    // The nearest deadline is the one that matters.
                    color: index === 0 ? Theme.c.red : Theme.c.onFaint
                }

                NText {
                    Layout.fillWidth: true
                    text: {
                        const i = parent.it;
                        return (i?.title || i?.summary
                            || (i?.text ?? "").slice(0, 48) || "Capture");
                    }
                    elide: Text.ElideRight
                }

                NLabel {
                    visible: !root.simple
                    text: Essentials.whenPretty(parent.it?.when ?? "")
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            GlobalState.closeAll();
            GlobalState.essentialOpen = true;
        }
    }
}
