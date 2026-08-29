import QtQuick
import QtQuick.Layouts
import ".."

// One settings row: label and description on the left, control on the right.
Rectangle {
    id: root
    property string label: ""
    property string hint: ""
    property bool interactive: false

    // Identifier used by search to target this row. Must match an entry
    // in SettingsIndex.
    property string key: ""

    signal activated()
    default property alias content: holder.data

    readonly property bool highlighted:
        root.key !== "" && GlobalState.settingsFocus === root.key

    Layout.fillWidth: true
    implicitHeight: Math.max(Theme.px(46), text.implicitHeight + Theme.px(18))
    radius: Theme.r.chip
    color: (root.highlighted || (root.interactive && ma.containsMouse))
        ? Theme.c.surface3 : Theme.c.surface2
    border.width: root.highlighted ? 1 : 0
    border.color: Theme.c.red
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    // A row found by search is often off-screen: targeting it without
    // bringing it into view is useless.
    onHighlightedChanged: if (root.highlighted) Qt.callLater(root.reveal)

    function reveal(): void {
        // Walk up to the page Flickable. The test looks at contentY for
        // lack of a way to query an object's type in QML.
        let f = root.parent;
        while (f && f.contentY === undefined)
            f = f.parent;
        if (!f)
            return;
        const top = root.mapToItem(f.contentItem, 0, 0).y;
        scroll.target = f;
        scroll.to = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height),
                                         top - f.height / 3));
        scroll.restart();
    }

    PropertyAnimation {
        id: scroll
        property: "contentY"
        duration: Theme.med
        easing.type: Theme.ease
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(12)
        spacing: Theme.px(14)

        ColumnLayout {
            id: text
            Layout.fillWidth: true
            spacing: Theme.px(1)

            NText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Theme.f.body
                elide: Text.ElideRight
            }

            NText {
                Layout.fillWidth: true
                text: root.hint
                visible: root.hint !== ""
                color: Theme.c.onDim
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: holder
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: Math.max(Theme.px(20), childrenRect.height)
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
