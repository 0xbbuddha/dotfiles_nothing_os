pragma Singleton

import QtQuick
import Quickshell

// Single clock for the whole shell + actually localised formatting.
// Qt.formatDateTime() ignores the system locale; use
// toLocaleDateString/toLocaleTimeString with an explicit locale.
Singleton {
    id: root

    // The UI is in English: dates follow.
    readonly property var locale: Qt.locale("en_GB")

    readonly property date now: clock.date
    readonly property string hhmm: format("HH:mm")
    readonly property string seconds: format("ss")
    readonly property string dayNum: format("d")
    readonly property string dayShort:
        capitalize(root.now.toLocaleDateString(root.locale, "ddd")).replace(/\.$/, "")
    readonly property string dateLong:
        capitalize(root.now.toLocaleDateString(root.locale, "dddd d MMMM"))
    readonly property string monthLong:
        capitalize(root.now.toLocaleDateString(root.locale, "MMMM yyyy"))

    // ISO 8601 week number
    readonly property int weekNumber: {
        const d = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
        const day = (d.getDay() + 6) % 7;          // Monday = 0
        d.setDate(d.getDate() - day + 3);          // Thursday of the week
        const firstThursday = new Date(d.getFullYear(), 0, 4);
        const fday = (firstThursday.getDay() + 6) % 7;
        firstThursday.setDate(firstThursday.getDate() - fday + 3);
        return 1 + Math.round((d - firstThursday) / (7 * 24 * 3600 * 1000));
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function format(f: string): string {
        return root.now.toLocaleString(root.locale, f);
    }

    function capitalize(s: string): string {
        // locales may render "tuesday"; we want "Tuesday"
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    // Duration in seconds → m:ss, with a guard: MPRIS sometimes returns
    // nonsense lengths (web streams, unknown position).
    function duration(sec: real): string {
        if (!isFinite(sec) || sec <= 0 || sec > 86400) return "--:--";
        const s = Math.floor(sec);
        const m = Math.floor(s / 60);
        if (m >= 60) {
            const h = Math.floor(m / 60);
            return `${h}:${String(m % 60).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
        }
        return `${m}:${String(s % 60).padStart(2, "0")}`;
    }

    function isValidLength(sec: real): bool {
        return isFinite(sec) && sec > 0 && sec <= 86400;
    }
}
