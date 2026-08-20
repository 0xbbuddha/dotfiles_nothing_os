import QtQuick
import ".."

// Crosshair drawing, centred on the item.
//
// Shared between the fullscreen overlay and the settings preview: duplicated,
// it would have ended up showing something other than what actually appears in-game.
Item {
    id: root

    property string style: Config.crosshairStyle
    property int size: Config.crosshairSize
    property int thickness: Config.crosshairThickness
    property int gap: Config.crosshairGap
    property color tint: Config.crosshairColor
    property bool outline: Config.crosshairOutline

    readonly property int len: Theme.px(root.size)
    readonly property int thick: Math.max(1, Theme.px(root.thickness))
    readonly property int space: Theme.px(root.gap)

    implicitWidth: (root.len + root.space) * 2 + root.thick
    implicitHeight: root.implicitWidth

    Item {
        anchors.centerIn: parent
        width: 1
        height: 1

        // Four arms
        Repeater {
            model: (root.style === "cross" || root.style === "crossdot"
                 || root.style === "tshape") ? [0, 1, 2, 3] : []

            Rectangle {
                required property int modelData
                // 0 top, 1 bottom, 2 left, 3 right
                readonly property bool vertical: modelData < 2
                visible: !(root.style === "tshape" && modelData === 0)

                width: vertical ? root.thick : root.len
                height: vertical ? root.len : root.thick
                color: root.tint
                antialiasing: false

                x: {
                    if (vertical) return -root.thick / 2;
                    return modelData === 2 ? -(root.space + root.len) : root.space;
                }
                y: {
                    if (!vertical) return -root.thick / 2;
                    return modelData === 0 ? -(root.space + root.len) : root.space;
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.6)
                    visible: root.outline
                    z: -1
                }
            }
        }

        // Centre dot
        Rectangle {
            visible: root.style === "dot" || root.style === "crossdot"
            width: root.thick + Theme.px(1)
            height: width
            radius: width / 2
            color: root.tint
            anchors.centerIn: parent

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 2
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.6)
                visible: root.outline
                z: -1
            }
        }

        // Circle
        Rectangle {
            visible: root.style === "circle"
            width: (root.space + root.len) * 2
            height: width
            radius: width / 2
            color: "transparent"
            border.width: root.thick
            border.color: root.tint
            anchors.centerIn: parent
            antialiasing: true
        }
    }
}
