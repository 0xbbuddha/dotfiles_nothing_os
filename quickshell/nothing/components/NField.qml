import QtQuick
import ".."

// Minimal input field, slightly lighter fill, red outline on focus.
Rectangle {
    id: root
    property alias text: input.text
    property alias placeholder: ph.text
    signal committed(string value)

    // Emitted only on Enter. committed also fires on focus loss,
    // which is not suitable to trigger an action.
    signal submitted(string value)

    function clear(): void { input.text = ""; }
    function takeFocus(): void { input.forceActiveFocus(); }

    implicitWidth: Theme.px(150)
    implicitHeight: Theme.px(26)
    radius: Theme.r.tiny
    color: Theme.c.surface3
    border.width: 1
    border.color: input.activeFocus ? Theme.c.red : "transparent"

    Behavior on border.color { ColorAnimation { duration: Theme.fast } }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.px(8)
        anchors.rightMargin: Theme.px(8)
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.c.on
        font.family: Theme.f.sans
        font.pixelSize: Theme.f.body
        selectByMouse: true
        selectionColor: Theme.c.red
        clip: true
        onEditingFinished: root.committed(text)
        onAccepted: {
            root.committed(text);
            root.submitted(text);
        }
    }

    Text {
        id: ph
        anchors.left: parent.left
        anchors.leftMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text === "" && !input.activeFocus
        color: Theme.c.onFaint
        font.family: Theme.f.sans
        font.pixelSize: Theme.f.body
    }
}
