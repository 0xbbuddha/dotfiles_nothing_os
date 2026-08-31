import QtQuick
import ".."
import "../.."

// One desktop widget, chosen by id.
//
// The mapping from id to component lived inline in Desktop.qml. The
// launcher needs the very same mapping to show a live preview, and two
// copies of a switch like this is how a widget ends up on the desktop but
// missing from the picker.
Loader {
    id: root
    property string widget: ""

    // A widget with nothing to say collapses entirely rather than holding
    // its height open. Binary, never a sliding height: the size is either
    // the one the registry declares or nothing at all, so the column can
    // animate it away without the twitching that variable heights caused.
    readonly property bool empty: root.item?.empty ?? false

    sourceComponent: {
        switch (root.widget) {
        case "clock":          return cClock;
        case "clockStack":     return cClockStack;
        case "clockBare":      return cClockBare;
        case "clockLight":     return cClockLight;
        case "clockDial":      return cClockDial;
        case "clockDigital":   return cClockDigital;
        case "clockAnalog":    return cClockAnalog;
        case "date":           return cDate;
        case "dateCompact":    return cDateCompact;
        case "calendar":       return cCalendar;
        case "weather":        return cWeather;
        case "weatherCompact": return cWeatherCompact;
        case "media":          return cMedia;
        case "mediaList":      return cMediaList;
        case "system":         return cSystem;
        default:               return null;
        }
    }

    Component { id: cClock;          WClock {} }
    Component { id: cClockStack;     WClockStack {} }
    Component { id: cClockBare;      WClockBare {} }
    Component { id: cClockLight;     WClockLight {} }
    Component { id: cClockDial;      WClockDial {} }
    Component { id: cClockDigital;   WClockDigital {} }
    Component { id: cClockAnalog;    WClockAnalog {} }
    Component { id: cDate;           WDate {} }
    Component { id: cDateCompact;    WDateCompact {} }
    Component { id: cCalendar;       WCalendar {} }
    Component { id: cWeather;        WWeather {} }
    Component { id: cWeatherCompact; WWeatherCompact {} }
    Component { id: cMedia;          WMedia {} }
    Component { id: cMediaList;      WMediaList {} }
    Component { id: cSystem;         WSystem {} }
}
