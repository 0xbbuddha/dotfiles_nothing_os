import QtQuick
import ".."
import "../.."
import "../../services"

// Weather in a square, three faces in one.
//
// A square has room for one thing said properly, not three said badly. So
// it says one at a time and turns the page: the sky, then the temperature,
// then the day's range. Three dots at the foot say where you are, and a
// click moves it on for anyone who does not want to wait.
//
// The voice is taken from Nothing's own Quick Look widget rather than
// invented: their layouts name the ndot font outright, set textAllCaps on
// every label, and write the reading as one line, "12 SUNNY". An earlier
// version here used sentence case and a large icon over a description,
// which read like any other weather widget.
NCard {
    id: root
    readonly property int pages: 3
    property int page: 0

    // Each face is drawn at full opacity and slid, rather than crossfaded
    // through a half-visible middle: two readings of the weather overlaid
    // at 50 % is worse than either.
    Item {
        id: stage
        anchors.fill: parent
        anchors.bottomMargin: Theme.px(16)
        clip: true

        // ── Condition ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            y: (0 - root.page) * height
            Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(6)

                // Nothing's own icon, not a font glyph standing in for
                // it. On a square this is the whole reading, and a Nerd
                // Font sun beside their dot type was the tell.
                DotGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    kind: Weather.dotKind
                    width: Theme.px(56)
                    height: Theme.px(56)
                }
                NText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: stage.width - Theme.px(18)
                    horizontalAlignment: Text.AlignHCenter
                    text: Weather.desc
                    color: Theme.c.onDim
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Theme.f.track
                    font.pixelSize: Theme.f.micro
                    elide: Text.ElideRight
                }
            }
        }

        // ── Temperature ───────────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            y: (1 - root.page) * height
            Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(2)

                DisplayText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.temp + "°"
                    size: Theme.px(38)
                }
                NLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.city
                }
            }
        }

        // ── Range ─────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            y: (2 - root.page) * height
            Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(8)

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.px(7)
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰁝"; size: Theme.px(13); color: Theme.c.onDim
                    }
                    DisplayText {
                        text: Weather.hi + "°"
                        size: Theme.px(24)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.px(7)
                    NIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰁅"; size: Theme.px(13); color: Theme.c.onDim
                    }
                    DisplayText {
                        text: Weather.lo + "°"
                        size: Theme.px(24)
                        color: Theme.c.onDim
                    }
                }
            }
        }
    }

    // Where you are, in the shell's own language.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(10)
        spacing: Theme.px(5)

        Repeater {
            model: root.pages

            Rectangle {
                required property int index
                width: Theme.px(4)
                height: width
                radius: width / 2
                color: index === root.page ? Theme.c.red : Theme.c.onFaint
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // The page turns when you turn it, and not otherwise. A tile
        // that cycles on its own is a tile you cannot read: you look at it
        // to check one thing and it has already moved on to another.
        onClicked: root.page = (root.page + 1) % root.pages
    }

}
