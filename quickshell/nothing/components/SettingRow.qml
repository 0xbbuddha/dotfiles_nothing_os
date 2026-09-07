import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// One settings row: label and description on the left, control on the right.
Rectangle {
    id: root
    property string label: ""
    property string hint: ""
    property bool interactive: false

    // Identifier used by search to target this row. Must match an entry
    // in SettingsIndex.
    property string key: ""

    // Taken from the index rather than set here. A page of eighty rows was
    // eighty lines of label and hint and nothing to catch the eye: the
    // glyph is what makes the list scannable instead of read.
    readonly property string icon:
        root.key !== "" ? SettingsIndex.iconFor(root.key) : ""

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
        anchors.leftMargin: root.icon !== "" ? Theme.px(10) : Theme.px(14)
        anchors.rightMargin: Theme.px(12)
        spacing: Theme.px(14)

        // A dim well rather than a bare glyph: at this size a lone icon
        // floats, and the disc gives the row a left edge to start from.
        Rectangle {
            visible: root.icon !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.px(26)
            implicitHeight: Theme.px(26)
            radius: width / 2
            color: root.highlighted ? Theme.c.red : Theme.veil(0.05)
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            NIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Theme.z.iconM
                color: root.highlighted ? Theme.c.onAccent : Theme.c.onDim
            }
        }

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
