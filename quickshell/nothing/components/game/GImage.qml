import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../.."

// Pinned reference image: map, plan, build order.
Item {
    id: root

    Image {
        id: img
        anchors.fill: parent
        source: Config.gameImage
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
        mipmap: true
        smooth: true
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Theme.px(16)
        spacing: Theme.px(8)
        visible: img.status !== Image.Ready && GlobalState.gameBarOpen

        NIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "󰋩"
            size: Theme.px(22)
            color: Theme.c.onFaint
        }

        NLabel {
            Layout.alignment: Qt.AlignHCenter
            text: "Reference image"
        }

        NField {
            Layout.fillWidth: true
            text: Config.gameImage.toString().replace("file://", "")
            placeholder: "/path/to/image.png"
            onCommitted: (v) => {
                const p = v.trim();
                if (p === "") {
                    Config.gameImage = "";
                } else {
                    Config.gameImage = p.startsWith("/") ? "file://" + p : p;
                }
                Config.save();
            }
        }
    }

    NText {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready && !GlobalState.gameBarOpen
        text: "No image"
        color: Theme.c.onFaint
    }
}
