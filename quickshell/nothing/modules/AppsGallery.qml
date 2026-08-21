import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// The library, one card per row. A shelf is narrow, and a single wide
// column shows an app running at close to the size it will have on the
// desktop, which two cramped columns never did.
ListView {
    id: root

    signal opened(string id)

    model: {
        MiniApps.stamp;
        return MiniApps.specs;
    }

    clip: true
    spacing: Theme.px(10)
    topMargin: Theme.px(2)
    bottomMargin: Theme.pad
    leftMargin: Theme.pad
    rightMargin: Theme.pad
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: Theme.px(1200)

    delegate: AppsCard {
        required property var modelData
        width: root.width - Theme.pad * 2
        spec: modelData
        onOpened: (id) => root.opened(id)
    }

    // Empty state, in the same voice as the rest of the shelf.
    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.px(50)
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        visible: MiniApps.empty
        spacing: Theme.px(12)

        DotMatrix {
            Layout.alignment: Qt.AlignHCenter
            pattern: ["1101011",
                      "1101011",
                      "0000000",
                      "1101011",
                      "1101011",
                      "0000000",
                      "0011100"]
            dot: Theme.px(4)
            gap: Theme.px(3)
            onColor: Theme.c.onFaint
            offColor: Theme.c.onFaint
            offOpacity: 0.15
        }

        DisplayText {
            Layout.alignment: Qt.AlignHCenter
            text: "NOTHING YET"
            size: Theme.px(20)
            color: Theme.c.onFaint
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Describe an app in the field above, or start from a preset."
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
            wrapMode: Text.WordWrap
        }
    }
}
