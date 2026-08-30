import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/widgets"
import "../services"

// Widgets placed on the desktop. Which ones, and where, comes from
// Config.widgets as cells of a logical grid.
//
// Cells rather than pixels: a layout arranged on a wide screen has to come
// back looking right on a narrower one, and only a proportional grid
// survives that. Heights stay natural, because the media tile grows with
// the number of players and the system tile with zram and swap; forcing
// them into fixed row spans would either clip them or leave holes.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    // Bottom is where widgets belong: behind every window, part of the
    // desktop. Arranging them is the exception. Left at the bottom the
    // grid sat under whatever was open, so with a single window on screen
    // the whole mode was invisible and unreachable.
    WlrLayershell.layer: win.editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "nothing-widgets"
    exclusionMode: ExclusionMode.Ignore

    // Full screen now that a widget may sit anywhere on it.
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property bool editing: GlobalState.widgetsEditing

    // OnDemand, not Exclusive: this layer covers the whole screen while
    // arranging, and a full-screen surface that seizes the keyboard is
    // how you lock someone out of their own session. On demand it takes
    // focus once clicked, which is enough for Escape, and clicking the
    // wallpaper leaves the mode anyway.
    WlrLayershell.keyboardFocus: win.editing
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: win.editing
        Keys.onEscapePressed: GlobalState.widgetsEditing = false
    }

    // Margins the grid keeps clear: the bar at the top, and enough of an
    // edge that a widget never sits flush against the screen border.
    readonly property real padX: Theme.px(48)
    readonly property real padTop: Theme.px(62)
    readonly property real padBottom: Theme.px(28)

    // The cell is a fixed size and the column count follows from it, not
    // the reverse. 148 is half the 296 the widget column used to be, so a
    // stock two-cell widget is exactly as wide as it always was, on every
    // screen. Dividing the screen into a fixed number of columns instead
    // would have made the same clock 456px wide on 1920 and 936px on 3840.
    readonly property real cellW: Theme.px(148)
    // Rows are deliberately much finer than a widget is tall. At 60 the
    // step was bigger than the gap between two tiles, so a widget could
    // only ever land overlapping its neighbour or a long way below it,
    // and there was no way to sit one snugly under another.
    readonly property real cellH: Theme.px(20)

    readonly property real gridW: Math.max(0, width - win.padX * 2)
    readonly property real gridH: Math.max(0, height - win.padTop - win.padBottom)
    readonly property int cols: Math.max(1, Math.floor(win.gridW / win.cellW))
    readonly property int rows: Math.max(1, Math.floor(win.gridH / win.cellH))

    // While arranging, the whole screen takes input so a widget can be
    // dropped anywhere. Otherwise the input region is the union of the
    // widget rectangles, and a click on bare wallpaper still reaches
    // whatever is behind this layer.
    //
    // The entries are written out one by one because `regions` is a
    // read-only list: it takes children declared here, and no binding can
    // fill it from an array. A widget appears at most once, so there can
    // never be more rectangles than there are kinds of widget.
    mask: win.editing ? null : maskRegion

    Region {
        id: maskRegion
        intersection: Intersection.Combine
        regions: [
            Region { item: slots.count > 0 ? slots.itemAt(0) : null },
            Region { item: slots.count > 1 ? slots.itemAt(1) : null },
            Region { item: slots.count > 2 ? slots.itemAt(2) : null },
            Region { item: slots.count > 3 ? slots.itemAt(3) : null },
            Region { item: slots.count > 4 ? slots.itemAt(4) : null },
            Region { item: slots.count > 5 ? slots.itemAt(5) : null },
            Region { item: slots.count > 6 ? slots.itemAt(6) : null },
            Region { item: slots.count > 7 ? slots.itemAt(7) : null }
        ]
    }

    // If the registry ever outgrows the list above, the extra widgets
    // would draw but not take clicks, which is the kind of fault nobody
    // thinks to look for. Say so instead.
    readonly property int maskSlots: 8
    onMaskSlotsChanged: win.checkMask()
    Component.onCompleted: win.checkMask()
    function checkMask(): void {
        if (WidgetRegistry.all.length > win.maskSlots)
            console.warn("Desktop: " + WidgetRegistry.all.length
                + " widget kinds but only " + win.maskSlots
                + " mask regions; add more in Desktop.qml");
    }

    // Where a widget can actually land, given what is already there.
    //
    // Snapping alone is not enough: rows are finer than a widget is tall,
    // so the row a drop lands on says nothing about whether the space is
    // free. This pushes the dropped widget down until it clears everything
    // it overlaps, which is what "put it under the clock" has to mean.
    function settledRow(self: var, col: int, row: int, span: int): int {
        if (win.cellH <= 0)
            return row;
        const x = win.padX + col * win.cellW;
        const w = span * win.cellW - Theme.gap;
        let y = win.padTop + row * win.cellH;
        const h = self.height;

        // Bounded: a cycle of widgets pushing each other would otherwise
        // spin here forever.
        for (let pass = 0; pass < 40; pass++) {
            let hit = false;
            for (let i = 0; i < slots.count; i++) {
                const o = slots.itemAt(i);
                if (!o || o === self || o.height <= 0)
                    continue;
                if (x < o.x + o.width && o.x < x + w
                    && y < o.y + o.height && o.y < y + h) {
                    y = o.y + o.height + Theme.gap;
                    hit = true;
                }
            }
            if (!hit)
                break;
        }
        return Math.max(0, Math.min(win.rows - 1,
            Math.round((y - win.padTop) / win.cellH)));
    }

    // ── The grid, drawn only while arranging ──────────────────────────
    Item {
        anchors.fill: parent
        visible: win.editing
        opacity: win.editing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.med } }

        Rectangle {
            anchors.fill: parent
            color: Theme.shade(0.45)
        }

        // Dots at the cell corners rather than ruled lines: it reads as a
        // grid without drawing a cage around the wallpaper, and it is the
        // same dot language as the rest of the shell.
        // Drawn every few rows. Snapping is finer than this: a dot per
        // snap position would be a wall of dots, and the eye only needs
        // enough of them to read the columns.
        Repeater {
            id: dots
            readonly property int step: 4
            readonly property int rowDots: Math.floor(win.rows / dots.step) + 1
            model: (win.cols + 1) * dots.rowDots

            Rectangle {
                required property int index
                readonly property int cx: index % (win.cols + 1)
                readonly property int cy: Math.floor(index / (win.cols + 1))
                x: win.padX + cx * win.cellW - width / 2
                y: win.padTop + cy * dots.step * win.cellH - height / 2
                width: Theme.px(3)
                height: width
                radius: width / 2
                color: Theme.c.onFaint
            }
        }

        // A banner, at the top and on a card. At the bottom it landed
        // squarely behind the dock, and bare text on the wallpaper is only
        // legible until someone picks a pale one.
        NCard {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: win.padTop
            radius: Theme.r.pill
            implicitWidth: hint.implicitWidth + Theme.px(28)
            implicitHeight: Theme.px(32)

            NText {
                id: hint
                anchors.centerIn: parent
                text: "Drag to move · pull the right edge to resize · "
                    + "click the wallpaper when done"
                color: Theme.c.onDim
            }
        }

        // A click on bare desktop leaves arrange mode, so there is always
        // a way out that does not need the keyboard.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: GlobalState.widgetsEditing = false
        }
    }

    Repeater {
        id: slots
        model: Config.widgets

        Item {
            id: slot
            required property var modelData
            required property int index

            readonly property string wid: modelData?.id ?? ""
            // Width in cells, not pixels. Named apart from win.cellW on
            // purpose: one is a count, the other a size.
            readonly property int span: Math.max(WidgetRegistry.minWidth,
                Math.min(WidgetRegistry.maxWidth,
                         modelData?.w ?? WidgetRegistry.defaultWidth))

            // Clamped for display only, never written back: plugging in a
            // narrower screen must not quietly rewrite a layout that was
            // arranged on the wide one.
            readonly property int cellCol: Math.max(0,
                Math.min(win.cols - slot.span, modelData?.col ?? 0))
            readonly property int cellRow: Math.max(0,
                Math.min(win.rows - 1, modelData?.row ?? 0))

            // Where the cell says it goes. While a drag is running the
            // item follows the pointer instead, and only settles back onto
            // the grid once it is dropped.
            readonly property real homeX: win.padX + slot.cellCol * win.cellW
            readonly property real homeY: win.padTop + slot.cellRow * win.cellH

            width: slot.span * win.cellW - Theme.gap
            height: loader.item ? loader.item.implicitHeight : 0
            visible: height > 0

            Component.onCompleted: { x = slot.homeX; y = slot.homeY; }
            onHomeXChanged: if (!grip.drag.active) x = slot.homeX
            onHomeYChanged: if (!grip.drag.active) y = slot.homeY

            Behavior on x {
                enabled: !grip.drag.active
                NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
            }
            Behavior on y {
                enabled: !grip.drag.active
                NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
            }
            Behavior on width {
                NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
            }
            Behavior on height {
                NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
            }

            Loader {
                id: loader
                width: parent.width
                height: parent.height
                active: true
                sourceComponent: {
                    switch (slot.wid) {
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

            // ── Arrange mode ──────────────────────────────────────────
            Rectangle {
                anchors.fill: parent
                anchors.margins: -Theme.px(4)
                radius: Theme.r.card
                color: "transparent"
                border.width: win.editing ? 1 : 0
                border.color: grip.drag.active ? Theme.c.red : Theme.c.onDim
                visible: win.editing
            }

            MouseArea {
                id: grip
                anchors.fill: parent
                enabled: win.editing
                visible: win.editing
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                drag.target: slot
                drag.threshold: Theme.px(4)
                drag.minimumX: win.padX
                drag.minimumY: win.padTop
                drag.maximumX: Math.max(win.padX,
                    win.padX + win.gridW - slot.width)
                drag.maximumY: Math.max(win.padTop,
                    win.padTop + win.gridH - slot.height)

                onReleased: {
                    if (win.cellW <= 0 || win.cellH <= 0)
                        return;
                    // Snap to the nearest cell, then clamp so a widget can
                    // never be parked past the right or bottom edge where
                    // it would be unreachable next time.
                    const col = Math.max(0, Math.min(
                        win.cols - slot.span,
                        Math.round((slot.x - win.padX) / win.cellW)));
                    const raw = Math.max(0, Math.min(
                        win.rows - 1,
                        Math.round((slot.y - win.padTop) / win.cellH)));
                    const row = win.settledRow(slot, col, raw, slot.span);
                    Config.placeWidget(slot.wid, col, row, slot.span);
                    slot.x = win.padX + col * win.cellW;
                    slot.y = win.padTop + row * win.cellH;
                }
            }

            // Right-edge handle: width only. Height is the widget's own
            // business and stays that way.
            Rectangle {
                id: handle
                visible: win.editing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(5)
                height: Theme.px(34)
                radius: width / 2
                color: sizer.drag.active ? Theme.c.red : Theme.c.onDim

                MouseArea {
                    id: sizer
                    anchors.fill: parent
                    anchors.margins: -Theme.px(8)
                    enabled: win.editing
                    cursorShape: Qt.SizeHorCursor
                    // The pointer is mapped into the slot, so its x IS the
                    // width being asked for. QML's MouseEvent carries only
                    // x and y, both local to this handle: an earlier
                    // version read m.scenePosition, which does not exist,
                    // so every move threw and the handle did nothing at all.
                    onPositionChanged: (m) => {
                        if (!pressed || win.cellW <= 0)
                            return;
                        const want = sizer.mapToItem(slot, m.x, 0).x;
                        const w = Math.max(WidgetRegistry.minWidth,
                            Math.min(WidgetRegistry.maxWidth,
                                Math.min(win.cols - slot.cellCol,
                                         Math.round(want / win.cellW))));
                        if (w !== slot.span)
                            Config.placeWidget(slot.wid, slot.cellCol,
                                               slot.cellRow, w);
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
