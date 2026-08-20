import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/widgets"
import "../services"

// Widgets placed on the desktop. List and order come from
// Config.widgets; add, remove and reorder are animated.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nothing-widgets"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true }
    implicitWidth: Theme.z.widgets + Theme.px(96)

    mask: Region { item: stack }

    // A Column (positioner), not a ColumnLayout: only it can animate
    // children arriving, leaving and moving.
    Column {
        id: stack
        x: Theme.px(48)
        y: Theme.px(62)
        width: Theme.z.widgets
        spacing: Theme.gap

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.med }
            NumberAnimation { property: "scale"; from: 0.92; to: 1
                              duration: Theme.med; easing.type: Theme.ease }
        }

        move: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.med; easing.type: Theme.ease }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.fast }
        }

        Repeater {
            model: Config.widgets

            Item {
                id: slot
                required property string modelData
                required property int index

                width: stack.width
                height: loader.item ? loader.item.implicitHeight : 0
                visible: height > 0

                Behavior on height {
                    NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                }

                Loader {
                    id: loader
                    width: parent.width
                    height: parent.height
                    active: true
                    sourceComponent: {
                        switch (slot.modelData) {
                        case "date":     return cDate;
                        case "weather":  return cWeather;
                        case "clock":    return cClock;
                        case "media":    return cMedia;
                        case "system":   return cSystem;
                        case "calendar": return cCalendar;
                        default:         return null;
                        }
                    }
                }
            }
        }
    }

    // Components are declared once and instantiated on demand.
    Component { id: cDate;     WDate {} }
    Component { id: cWeather;  WWeather {} }
    Component { id: cClock;    WClock {} }
    Component { id: cMedia;    WMedia {} }
    Component { id: cSystem;   WSystem {} }
    Component { id: cCalendar; WCalendar {} }
}
