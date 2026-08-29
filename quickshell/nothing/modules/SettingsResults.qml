import QtQuick
import QtQuick.Layouts
import ".."
import "../components"

// Search results, all settings together.
//
// Takes the place of the current page while typing: showing both would
// overlay a list on a page that no longer has anything to do with the
// query.
Flickable {
    id: root

    property string query: ""
    property var results: []
    property var pages: []
    signal chosen(var entry)

    contentWidth: width
    contentHeight: col.implicitHeight + Theme.pad * 2
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    ColumnLayout {
        id: col
        width: root.width - Theme.pad * 2
        x: Theme.pad
        y: Theme.pad
        spacing: Theme.px(4)

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.px(6)
            spacing: Theme.px(9)

            NLabel {
                text: root.results.length === 0
                    ? "no match"
                    : root.results.length + (root.results.length > 1 ? " results" : " result")
                dim: false
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.c.outline
            }
        }

        NText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(10)
            visible: root.results.length === 0
            text: "Nothing matches \u201c" + root.query + "\u201d."
            color: Theme.c.onDim
            font.pixelSize: Theme.f.body
        }

        Repeater {
            model: root.results

            Rectangle {
                id: hit
                required property var modelData
                required property int index

                readonly property string pageLabel:
                    root.pages[hit.modelData.page]?.label ?? ""

                Layout.fillWidth: true
                implicitHeight: Theme.px(42)
                radius: Theme.r.chip
                color: hma.containsMouse ? Theme.c.surface2 : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                // Results land one after another, like the blocks of a page.
                opacity: 0

                NumberAnimation {
                    id: appear
                    target: hit
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.fast
                    easing.type: Easing.OutQuad
                }

                // 26 ms per row, capped at the twelfth result: enough to read
                // a cascade arrival, too little to wait.
                Timer {
                    running: true
                    interval: Math.min(hit.index, 12) * 26
                    onTriggered: appear.start()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(12)
                    anchors.rightMargin: Theme.px(14)
                    spacing: Theme.px(12)

                    Rectangle {
                        width: Theme.px(4)
                        height: width
                        radius: width / 2
                        color: hma.containsMouse ? Theme.c.red : Theme.c.onFaint
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }

                    NText {
                        Layout.fillWidth: true
                        text: hit.modelData.label
                        font.pixelSize: Theme.f.body
                        elide: Text.ElideRight
                    }

                    NLabel { text: hit.pageLabel }
                }

                MouseArea {
                    id: hma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(hit.modelData)
                }
            }
        }
    }
}
