import QtQuick
import ".."
import "../.."
import "../../services"

// Days until something.
//
// Nothing gives this widget twelve shapes to sit on and no other
// decoration, which tells you what it is for: not a project deadline but a
// date you are looking forward to. The shape is the whole of the styling,
// so it is behind the number rather than beside it.
//
// Counting in whole days from midnight to midnight, not in elapsed hours.
// "3 days" should not become "2 days" because it is now the afternoon:
// people count sleeps, not durations.
NCard {
    id: root
    property bool simple: false

    readonly property date target: {
        const raw = (Config.countdownDate ?? "").trim();
        return raw === "" ? new Date(NaN) : new Date(raw + "T00:00:00");
    }

    readonly property bool set: !isNaN(root.target.getTime())

    readonly property int days: {
        if (!root.set)
            return 0;
        void Time.now;
        const now = new Date();
        const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        return Math.round((root.target.getTime() - midnight.getTime())
                          / 86400000);
    }

    // Past dates count up, the way Nothing's own does: an anniversary is
    // as good a thing to count as a deadline.
    readonly property bool passed: root.set && root.days < 0

    NShape {
        anchors.centerIn: parent
        // Well inside the card. At a tighter margin the wider lobes ran
        // to the card's own edge and the two outlines merged into one.
        width: Math.min(parent.width, parent.height) - Theme.px(36)
        height: width
        index: Config.countdownShape
        color: Theme.c.surface3
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.px(1)

        DisplayText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.set ? Math.abs(root.days) : "--"
            size: Theme.px(40)
            color: Theme.c.on
        }

        NLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                if (!root.set)
                    return "No date set";
                if (root.days === 0)
                    return "Today";
                const unit = Math.abs(root.days) === 1 ? "day" : "days";
                return root.passed ? unit + " since" : unit + " to go";
            }
            color: root.days === 0 ? Theme.c.red : Theme.c.onDim
        }
    }

    NLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(12)
        width: parent.width - Theme.px(24)
        horizontalAlignment: Text.AlignHCenter
        visible: !root.simple && text !== ""
        text: Config.countdownLabel
        elide: Text.ElideRight
    }
}
