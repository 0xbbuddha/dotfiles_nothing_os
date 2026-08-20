import QtQuick
import ".."
import "../.."

Flickable {
    id: root
    anchors.fill: parent
    contentWidth: width
    contentHeight: edit.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    TextEdit {
        id: edit
        width: parent.width
        text: Config.gameNotes
        color: Theme.c.on
        font.family: Theme.f.sans
        font.pixelSize: Theme.f.small
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        selectionColor: Theme.c.red
        onTextChanged: save.restart()
    }

    Timer {
        id: save
        interval: 450
        onTriggered: {
            if (Config.gameNotes === edit.text) return;
            Config.gameNotes = edit.text;
            Config.save();
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        visible: edit.text === "" && !edit.activeFocus
        text: "Codes, macros, loadouts…"
        color: Theme.c.onFaint
        font.family: Theme.f.sans
        font.pixelSize: Theme.f.small
    }
}
