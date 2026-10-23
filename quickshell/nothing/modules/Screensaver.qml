import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The idle screen: the time in Ndot dots on black, on every screen, before
// the panels go off (Settings > Screen > Idle > Screensaver). hypridle
// raises it and takes it down again on any input (on-resume); moving the
// mouse over it does too, in case that call is missed.
//
// The clock drifts to a new place every minute, so nothing sits on the
// same pixels long enough to mark an OLED or leave an image on IPS.
// Above the windows but under the lock screen: with the lock set earlier
// than the screensaver, it simply never shows.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    visible: GlobalState.screensaverOn
    color: "black"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-screensaver"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // 0..1 positions inside the free area, moved once a minute.
    property real fx: 0.5
    property real fy: 0.45

    function drift(): void {
        win.fx = 0.15 + Math.random() * 0.7;
        win.fy = 0.15 + Math.random() * 0.7;
    }

    onVisibleChanged: {
        if (!visible)
            return;
        win.drift();
        // A new showing: the next pointer position is the new reference.
        mover.first = Qt.point(-1, -1);
    }

    Timer {
        interval: 60000
        repeat: true
        running: win.visible
        onTriggered: win.drift()
    }

    Item {
        id: field
        anchors.fill: parent
        anchors.margins: Theme.px(40)

        ColumnLayout {
            id: face
            spacing: Theme.px(6)
            x: (field.width - width) * win.fx
            y: (field.height - height) * win.fy
            Behavior on x { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }
            Behavior on y { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }

            DisplayText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hhmm
                size: Math.min(Theme.px(180), win.width / 6)
                color: "#e8e8e8"
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.px(10)

                // The one red dot, breathing with the seconds.
                Rectangle {
                    implicitWidth: Theme.px(8)
                    implicitHeight: Theme.px(8)
                    radius: width / 2
                    color: Theme.c.red
                    opacity: (parseInt(Time.seconds, 10) % 2) === 0 ? 1 : 0.25
                    Behavior on opacity { NumberAnimation { duration: 600 } }
                }

                NLabel {
                    text: Time.dateLong
                    color: "#8a8a8a"
                    font.pixelSize: Theme.f.small
                }
            }
        }
    }

    // Covers the screen, so any movement over it is the hand coming back.
    MouseArea {
        id: mover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        property point first: Qt.point(-1, -1)
        onPositionChanged: (m) => {
            if (first.x < 0) { first = Qt.point(m.x, m.y); return; }
            if (Math.abs(m.x - first.x) + Math.abs(m.y - first.y) > 12)
                GlobalState.screensaverOn = false;
        }
        onPressed: GlobalState.screensaverOn = false
    }
}
