import QtQuick
import ".."
import "../.."
import "../../services"

Item {
    anchors.fill: parent

    DisplayText {
        anchors.centerIn: parent
        text: Time.hhmm
        size: Math.min(parent.height * 0.6, parent.width * 0.28)
    }
}
