import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Pageable month. The current day is marked only on the current month.
NCard {
    id: root
    implicitHeight: col.implicitHeight + Theme.px(24)

    property int year: Time.now.getFullYear()
    property int month: Time.now.getMonth()

    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    readonly property int firstWeekday: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property bool currentMonth:
        year === Time.now.getFullYear() && month === Time.now.getMonth()
    readonly property string title: Time.capitalize(
        new Date(year, month, 1).toLocaleDateString(Time.locale, "MMMM yyyy"))

    function prev(): void {
        if (month === 0) { month = 11; year -= 1; }
        else month -= 1;
    }
    function next(): void {
        if (month === 11) { month = 0; year += 1; }
        else month += 1;
    }
    function goToday(): void {
        year = Time.now.getFullYear();
        month = Time.now.getMonth();
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.px(12)
        spacing: Theme.px(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            NText {
                text: "‹"
                font.pixelSize: Theme.f.big
                font.weight: Font.Medium

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.px(6)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prev()
                }
            }

            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.title

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToday()
                }
            }

            NText {
                text: "›"
                font.pixelSize: Theme.f.big
                font.weight: Font.Medium

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.px(6)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.next()
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: Theme.px(3)
            columnSpacing: Theme.px(3)

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.c.onFaint
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.micro
                }
            }

            Repeater {
                model: root.firstWeekday
                Item { Layout.fillWidth: true; Layout.preferredHeight: Theme.px(22) }
            }

            Repeater {
                model: root.daysInMonth

                Item {
                    id: cell
                    required property int index
                    readonly property int day: index + 1
                    readonly property bool today: root.currentMonth && day === Time.now.getDate()

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(22)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, Theme.px(22))
                        height: width
                        radius: width / 2
                        color: cell.today ? Theme.c.red : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.day
                        color: cell.today ? Theme.c.on : Theme.c.onDim
                        font.family: Theme.f.mono
                        font.pixelSize: Theme.f.tiny
                    }
                }
            }
        }
    }
}
