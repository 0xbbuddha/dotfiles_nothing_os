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

    // Which slot a point in the flow falls nearest to, while a tile is
    // held and dragged - Flow itself still owns every position and
    // every animation, this only decides when a drag has crossed into
    // a neighbour's half and a swap should happen.
    DragFlow {
        id: dragFlow
        sizes: Config.widgets.map(id => ({
            width: WidgetRegistry.width(id), height: WidgetRegistry.height(id)
        }))
        maxWidth: Theme.z.widgets
        spacing: Theme.gap
        onSwapped: (from, to) => Config.swapWidget(from, to)
    }

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
                required property int index

                // The registry owns both dimensions. A widget that sized
                // itself from its content made the desktop shuffle whenever
                // that content changed; now every tile is exactly as big as
                // it says it is.
                width: view.empty ? 0 : WidgetRegistry.width(slot.modelData)
                height: view.empty ? 0 : WidgetRegistry.height(slot.modelData)
                visible: width > 0 && height > 0
                // Off while held: the content below rides out past this
                // box then, following the cursor rather than Flow.
                clip: !dragMa.pressed
                z: dragMa.pressed ? 10 : 0

                Behavior on height {
                    NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                }

                // Which tile a drop would trade places with.
                Rectangle {
                    anchors.fill: parent
                    visible: dragFlow.dragging && dragFlow.to === slot.index
                        && dragFlow.from !== slot.index
                    color: "transparent"
                    radius: Theme.r.chip
                    border.width: 2
                    border.color: Theme.c.red
                    z: 5
                }

                // Flow keeps owning slot's own x/y - only the two tiles
                // that end up trading places actually move, everyone
                // else stays put. This is the one thing riding a second,
                // private offset on top of that so the tile you are
                // holding actually moves with the pointer instead of
                // waiting where it was until it lands.
                Item {
                    id: content
                    width: parent.width
                    height: parent.height
                    scale: dragMa.pressed ? 0.96 : 1
                    opacity: dragMa.pressed ? 0.9 : 1
                    x: dragMa.pressed ? dragMa.liveOffsetX : 0
                    y: dragMa.pressed ? dragMa.liveOffsetY : 0
                    Behavior on x { enabled: !dragMa.pressed; NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                    Behavior on y { enabled: !dragMa.pressed; NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                    WidgetView {
                        id: view
                        width: WidgetRegistry.width(slot.modelData)
                        height: WidgetRegistry.height(slot.modelData)
                        widget: slot.modelData
                    }

                    // Edit mode only: the right column's app tiles have
                    // carried this remove button since the Essential Apps
                    // feature shipped (components/apps/Widget.qml); a stock
                    // widget never had one at all, since the desktop could
                    // not be edited in place until now.
                    CircleButton {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.px(6)
                        visible: GlobalState.desktopEditOpen
                        icon: "󰅖"
                        size: Theme.px(20)
                        z: 4
                        onActivated: Config.removeWidget(slot.modelData)
                    }
                }

                MouseArea {
                    id: dragMa
                    anchors.fill: parent
                    enabled: GlobalState.desktopEditOpen
                    cursorShape: Qt.OpenHandCursor
                    property real pressX: 0
                    property real pressY: 0
                    property real liveOffsetX: 0
                    property real liveOffsetY: 0

                    onPressed: (m) => {
                        dragMa.pressX = m.x;
                        dragMa.pressY = m.y;
                        dragMa.liveOffsetX = 0;
                        dragMa.liveOffsetY = 0;
                        dragFlow.from = slot.index;
                        dragFlow.to = slot.index;
                    }
                    onPositionChanged: (m) => {
                        if (!dragMa.pressed)
                            return;
                        dragMa.liveOffsetX = m.x - dragMa.pressX;
                        dragMa.liveOffsetY = m.y - dragMa.pressY;
                        const p = dragMa.mapToItem(stack, m.x, m.y);
                        dragFlow.to = dragFlow.nearestIndex(p.x, p.y);
                    }
                    // Committed here, not as the pointer crosses each
                    // neighbour: a widget moved and its config saved to
                    // disk mid-drag, over and over on the way to wherever
                    // it actually ends up, was the opposite of fluid.
                    onReleased: {
                        dragMa.liveOffsetX = 0;
                        dragMa.liveOffsetY = 0;
                        dragFlow.drop();
                    }
                    onCanceled: {
                        dragMa.liveOffsetX = 0;
                        dragMa.liveOffsetY = 0;
                        dragFlow.from = -1;
                        dragFlow.to = -1;
                    }
                }
            }
        }
    }
}
