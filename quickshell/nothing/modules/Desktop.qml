import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/widgets"
import "../services"

// Widgets stacked down the left of the desktop. Which ones, and in what
// order, comes from Config.widgets.
//
// A flow, not free placement. Letting widgets be dropped anywhere looked
// like more freedom and behaved like less: every widget carries its own
// height, so changing one face moved nothing else and the layout tore open
// or overlapped. A positioner owns the spacing instead, and removing a
// widget closes the gap on its own.
//
// A Flow rather than a Column, because not everything wants the full
// width. A dial is round; across the whole column it sat in a field of
// empty card. Half-width widgets are square and pair up on one row, the
// wide ones take a row to themselves, and the wrapping is arithmetic the
// positioner already knows how to do.
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

    // A positioner, not a Layout: only it can animate children arriving,
    // leaving and moving.
    Flow {
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

                // The registry owns both dimensions. A widget that sized
                // itself from its content made the desktop shuffle whenever
                // that content changed; now every tile is exactly as big as
                // it says it is.
                width: view.empty ? 0 : WidgetRegistry.width(slot.modelData)
                height: view.empty ? 0 : WidgetRegistry.height(slot.modelData)
                visible: width > 0 && height > 0
                clip: true

                Behavior on height {
                    NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                }

                WidgetView {
                    id: view
                    width: WidgetRegistry.width(slot.modelData)
                    height: WidgetRegistry.height(slot.modelData)
                    widget: slot.modelData
                }
            }
        }
    }
}
