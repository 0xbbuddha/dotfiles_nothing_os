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

    // Nothing ships a reduced version of most of its widgets alongside the
    // full one: same widget, fewer things on it. Rather than a second
    // component per look, the registry marks the entry and the flag is
    // handed to whichever widget knows what to leave out.
    Binding {
        target: root.item
        property: "simple"
        value: WidgetRegistry.isSimple(root.widget)
        // Only where the widget declares it. Most do not have a reduced
        // form, and binding at them anyway logged a warning per instance
        // per reload without changing anything.
        when: root.item !== null && root.item.simple !== undefined
        restoreMode: Binding.RestoreNone
    }

    sourceComponent: {
        switch (root.widget) {
        case "clock":          return cClock;
        case "clockStack":     return cClockStack;
        case "clockBare":      return cClockBare;
        case "clockLight":     return cClockLight;
        case "clockDial":      return cClockDial;
        case "clockDigitalSimple":
        case "clockDigital":   return cClockDigital;
        case "clockAnalog":    return cClockAnalog;
        case "clockScale":     return cClockScale;
        case "dateSimple":
        case "date":           return cDate;
        case "dateCompact":    return cDateCompact;
        case "calendar":       return cCalendar;
        case "weatherSimple":
        case "weather":        return cWeather;
        case "weatherCompact": return cWeatherCompact;
        case "weatherSquare":  return cWeatherSquare;
        case "media":          return cMedia;
        case "mediaList":      return cMediaList;
        case "mediaSquare":    return cMediaSquare;
        case "worldClockSimple":
        case "worldClock":     return cWorldClock;
        case "worldClockOne":  return cWorldClockOne;
        case "photo":          return cPhoto;
        case "photoRound":     return cPhotoRound;
        case "systemSimple":
        case "netSimple":
        case "net":            return cNet;
        case "breathCalm":     return cBreathCalm;
        case "breathFocus":    return cBreathFocus;
        case "breathRelax":    return cBreathRelax;
        case "worldClockPair": return cWorldClockPair;
        case "photoPad":       return cPhotoPad;
        case "photoRoundPad":  return cPhotoRoundPad;
        case "photoWide":      return cPhoto;
        case "quickLookSimple":
        case "quickLook":      return cQuickLook;
        case "quickLookBare":  return cQuickLookBare;
        case "batterySimple":
        case "battery":        return cBattery;
        case "batteryRing":    return cBatteryRing;
        case "countdownSimple":
        case "countdown":      return cCountdown;
        case "essential":      return cEssential;
        case "screenTime":     return cScreenTime;
        case "system":         return cSystem;
        default:               return null;
        }
    }

    Component { id: cClock;          WClock {} }
    Component { id: cClockStack;     WClockStack {} }
    Component { id: cClockBare;      WClockBare {} }
    Component { id: cClockLight;     WClockLight {} }
    Component { id: cClockDial;      WClockDial {} }
    Component { id: cClockScale;     WClockScale {} }
    Component { id: cClockDigital;   WClockDigital {} }
    Component { id: cClockAnalog;    WClockAnalog {} }
    Component { id: cDate;           WDate {} }
    Component { id: cDateCompact;    WDateCompact {} }
    Component { id: cCalendar;       WCalendar {} }
    Component { id: cWeather;        WWeather {} }
    Component { id: cWeatherCompact; WWeatherCompact {} }
    Component { id: cWeatherSquare;  WWeatherSquare {} }
    Component { id: cMedia;          WMedia {} }
    Component { id: cMediaList;      WMediaList {} }
    Component { id: cMediaSquare;    WMediaSquare {} }
    Component { id: cWorldClock;     WWorldClock {} }
    Component { id: cWorldClockOne;  WWorldClockOne {} }
    Component { id: cPhoto;          WPhoto {} }
    Component { id: cPhotoRound;     WPhotoRound {} }
    Component { id: cNet;            WNet {} }
    Component { id: cBreathCalm;     WBreathCalm {} }
    Component { id: cBreathFocus;    WBreathFocus {} }
    Component { id: cBreathRelax;    WBreathRelax {} }
    Component { id: cWorldClockPair; WWorldClockPair {} }
    Component { id: cPhotoPad;       WPhotoPad {} }
    Component { id: cPhotoRoundPad;  WPhotoRoundPad {} }
    Component { id: cQuickLook;      WQuickLook {} }
    Component { id: cQuickLookBare;  WQuickLookBare {} }
    Component { id: cBattery;        WBattery {} }
    Component { id: cBatteryRing;    WBatterySmall {} }
    Component { id: cCountdown;      WCountdown {} }
    Component { id: cEssential;      WEssential {} }
    Component { id: cScreenTime;     WScreenTime {} }
    Component { id: cSystem;         WSystem {} }
}
