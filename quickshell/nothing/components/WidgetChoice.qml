import QtQuick
import QtQuick.Layouts
import ".."
import "widgets"

// One widget in the launcher: what it looks like, and whether it is on
// the desktop.
//
// The preview is the real widget at its real size, not a drawing of one.
// A mock-up would be a second thing to keep in step, and it would lie the
// day the widget changed. The card is sized from the registry, so the
// preview never disagrees with what the desktop will do.
Item {
    id: root
    required property var meta

    readonly property string wid: meta?.id ?? ""
    readonly property bool on: Config.hasWidget(root.wid)

    // Fixed. The tile is the same size whether the widget inside is a
    // one-line date or a full calendar, so the gallery does not jump as
    // you scroll past a tall one.
    implicitWidth: Theme.px(230)
    implicitHeight: Theme.px(210)

    Rectangle {
        anchors.fill: parent
        radius: Theme.r.card
        color: Theme.c.surface2
        border.width: root.on ? 1 : 0
        border.color: Theme.c.red
        Behavior on border.width { NumberAnimation { duration: Theme.fast } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(12)
            spacing: Theme.px(10)

            // ── Stage ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.r.chip
                color: Theme.c.surface
                clip: true

                Item {
                    id: stage
                    anchors.centerIn: parent

                    // The widget is built at the width it gets on the
                    // desktop and then scaled down whole, so proportions,
                    // type size and corner radii are all truthful. A square
                    // widget previews square, which is the point of it.
                    width: WidgetRegistry.width(root.wid)
                    height: Math.max(Theme.px(40), WidgetRegistry.height(root.wid))

                    scale: Math.min(
                        (parent.width - Theme.px(16)) / Math.max(1, width),
                        (parent.height - Theme.px(16)) / Math.max(1, height),
                        1)

                    WidgetView {
                        anchors.fill: parent
                        widget: root.wid
                    }
                }
            }

            // ── Name ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    NText {
                        Layout.fillWidth: true
                        text: root.meta?.label ?? root.wid
                        color: root.on ? Theme.c.on : Theme.c.onDim
                        font.weight: root.on ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }
                    NText {
                        Layout.fillWidth: true
                        text: root.meta?.hint ?? ""
                        color: Theme.c.onFaint
                        font.pixelSize: Theme.f.tiny
                        elide: Text.ElideRight
                    }
                }

                // A lit dot rather than a switch: the whole tile is the
                // target, and a switch beside it would invite a second,
                // smaller thing to aim at.
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: Theme.px(8)
                    height: width
                    radius: width / 2
                    color: root.on ? Theme.c.red : Theme.c.onFaint
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.chooseWidget(root.wid)
        }
    }
}
