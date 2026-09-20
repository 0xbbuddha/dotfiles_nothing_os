import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// A miniature of the control centre - the real shape of it, header dots
// and all - and the thing you actually edit through: drag a tile or a
// footer button out to remove it, drag one up from the shelf below to
// add it, drag one to where it should sit among its neighbours.
//
// Real titles on the tiles now, not just their glyph: CcRegistry's own
// comment calls a tile "a wide pill with a title", and a preview drawn
// smaller than that is a preview of a different control. Sized close to
// the real panel's own width for the same reason BarPreview sizes its
// pills close to the real bar's.
//
// Tiles and footer buttons stay two separate drag surfaces: a tile can
// never become a footer button, they are drawn from two different
// catalogues in CcRegistry, so there is no "other zone" to drag one into
// the way an island is for the bar.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: Theme.px(14) + outer.height + Theme.px(10)
        + (shelfFlow.count > 0 ? shelfCol.implicitHeight + Theme.px(10) : Theme.px(10))
    radius: Theme.r.chip
    color: Theme.veil(0.04)

    // The panel floats over a wallpaper, so the preview floats over a
    // field of dots: against nothing it would read as a list.
    DotField {
        anchors.fill: parent
        step: Theme.px(10)
        dotRadius: Theme.px(0.9)
        baseAlpha: 0.5
    }

    readonly property var tileIds: (Config.ccTiles && Config.ccFooter)
        ? Config.ccZone("tiles") : []
    readonly property var footIds: (Config.ccTiles && Config.ccFooter)
        ? Config.ccZone("footer") : []
    readonly property var tileSpare: (Config.ccTiles && Config.ccFooter)
        ? CcRegistry.unplaced("tiles") : []
    readonly property var footSpare: (Config.ccTiles && Config.ccFooter)
        ? CcRegistry.unplaced("footer") : []
    readonly property int cols: Math.max(2, Math.min(4, Config.ccColumns))

    // ── Drag, kept once for both rows: a tile and a footer button never
    // trade places, so all this needs to know is which of the two lists
    // (or neither) the pointer is currently over. ───────────────────────
    property string dragKind: ""     // "tiles" / "footer" / ""
    property string dragId: ""
    property real dragX: 0
    property real dragY: 0
    property real pressX: 0
    property real pressY: 0
    readonly property bool dragging: dragId !== ""

    function areaOf(kind: string): var {
        return kind === "tiles" ? grid : footRow;
    }

    // Which of the two rows the pointer sits over right now, "" for the
    // shelf strip below the panel.
    readonly property string hoverKind: {
        if (!root.dragging) return "";
        const gp = grid.mapFromItem(root, root.dragX, root.dragY);
        if (gp.y >= -Theme.px(8) && gp.y <= grid.height + Theme.px(8)) return "tiles";
        const fp = footRow.mapFromItem(root, root.dragX, root.dragY);
        if (fp.y >= -Theme.px(8) && fp.y <= footRow.height + Theme.px(8)) return "footer";
        return "";
    }

    // Whether the drag in flight would reorder a row, and where in it -
    // the direct answer to "where exactly", drawn on the target chip
    // itself rather than left to be discovered by letting go.
    readonly property bool reorderingTiles: dragging && dragKind === "tiles"
        && hoverKind === "tiles" && Config.ccHas("tiles", dragId)
    readonly property bool reorderingFooter: dragging && dragKind === "footer"
        && hoverKind === "footer" && Config.ccHas("footer", dragId)
    readonly property int tileTargetIndex: reorderingTiles ? indexForDrop("tiles") : -1
    readonly property int footTargetIndex: reorderingFooter ? indexForDrop("footer") : -1

    function beginDrag(kind: string, id: string, x: real, y: real): void {
        root.dragKind = kind;
        root.dragId = id;
        root.dragX = root.pressX = x;
        root.dragY = root.pressY = y;
    }

    function moveDrag(x: real, y: real): void {
        root.dragX = x;
        root.dragY = y;
    }

    // Where among its siblings a drop lands, read off their real
    // positions: tiles wrap into rows, so spacing and a plain count are
    // not enough to say what "third" means.
    function indexForDrop(kind: string): int {
        const rep = kind === "tiles" ? tileRep : footRep;
        const area = root.areaOf(kind);
        const p = area.mapFromItem(root, root.dragX, root.dragY);
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (!it || it.itemId === root.dragId) continue;
            // Scanning in the same row-major order the Flow itself lays
            // out in: a row entirely above the drop is behind it (keep
            // looking), a row entirely below is the first thing after it
            // (land here), and within the drop's own row it comes down
            // to which side of centre.
            if (p.y >= it.y + it.height) continue;
            if (p.y < it.y) return i;
            if (p.x < it.x + it.width / 2) return i;
        }
        return rep.count;
    }

    function endDrag(): void {
        if (!root.dragging) return;
        const kind = root.dragKind, id = root.dragId;
        const wasPlaced = Config.ccHas(kind, id);
        const onOwnRow = root.hoverKind === kind;
        const travelled = Math.abs(root.dragX - root.pressX)
            + Math.abs(root.dragY - root.pressY);

        if (travelled < Theme.px(6)) {
            // A click: placed leaves, shelved joins - one gesture, either
            // direction.
            Config.ccToggle(kind, id);
        } else if (wasPlaced && !onOwnRow) {
            // Dragged off its own row entirely: take it out.
            Config.ccToggle(kind, id);
        } else if (!wasPlaced && onOwnRow) {
            // Dragged up from the shelf onto its row: add it.
            Config.ccToggle(kind, id);
        } else if (wasPlaced && onOwnRow) {
            // Still on its own row: land it where the drop says, among
            // its neighbours.
            const list = Config.ccZone(kind);
            const from = list.indexOf(id);
            const to = root.indexForDrop(kind);
            const landing = to > from ? to - 1 : to;
            if (from >= 0 && landing !== from)
                Config.ccMove(kind, from, landing - from);
        }
        // The remaining case - shelved and dropped somewhere that is not
        // its row - is nothing: it was never placed to begin with.
        root.dragKind = "";
        root.dragId = "";
    }

    // One draggable glyph, shaped however the call site needs: a wide
    // tile pill or a small square footer button. The shape is the only
    // difference: press, drag and drop all go through root the same way.
    component Chip: MouseArea {
        id: chip
        required property string kind
        required property string itemId
        property bool targeted: false
        property alias radius: bg.radius
        default property alias content: bg.data

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        z: chip.pressed ? 10 : 0
        opacity: (root.dragging && root.dragId === chip.itemId) ? 0.32 : 1
        scale: chip.pressed ? 0.94 : (chip.containsMouse && !root.dragging ? 1.04 : 1)
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        onPressed: (m) => {
            const p = chip.mapToItem(root, m.x, m.y);
            root.beginDrag(chip.kind, chip.itemId, p.x, p.y);
        }
        onPositionChanged: (m) => {
            if (!chip.pressed) return;
            const p = chip.mapToItem(root, m.x, m.y);
            root.moveDrag(p.x, p.y);
        }
        onReleased: root.endDrag()

        Rectangle {
            id: bg
            anchors.fill: parent
            color: chip.containsMouse && !root.dragging ? Theme.c.surface3 : Theme.c.surface2
            border.width: chip.targeted ? 2 : 0
            border.color: Theme.c.red
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }

        Tooltip {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: Theme.px(6)
            text: CcRegistry.label(chip.kind, chip.itemId)
            shown: chip.containsMouse && !root.dragging
        }
    }

    Rectangle {
        id: outer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(12)
        width: Math.min(parent.width - Theme.px(24), Theme.px(360))
        implicitHeight: body.implicitHeight + Theme.px(18)
        height: implicitHeight
        radius: Theme.r.panel
        color: Theme.c.surface

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.px(12)
            spacing: Theme.px(8)

            // The header line, so the miniature is recognisable as the
            // panel and not as a grid of chips.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                Repeater {
                    model: 4
                    Rectangle {
                        implicitWidth: Theme.px(10)
                        implicitHeight: Theme.px(13)
                        radius: Theme.px(2)
                        color: Theme.c.onFaint
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: Theme.px(38)
                    implicitHeight: Theme.px(6)
                    radius: Theme.px(3)
                    color: Theme.c.outline
                }
            }

            Flow {
                id: grid
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(2)
                spacing: Theme.px(6)
                readonly property real cell:
                    (width - spacing * (root.cols - 1)) / root.cols

                Repeater {
                    id: tileRep
                    model: root.tileIds

                    Chip {
                        required property string modelData
                        required property int index
                        kind: "tiles"
                        itemId: modelData
                        targeted: root.tileTargetIndex === index
                        width: grid.cell
                        height: Theme.px(30)
                        radius: Theme.r.tiny

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(8)
                            anchors.rightMargin: Theme.px(6)
                            spacing: Theme.px(6)

                            NIcon {
                                text: CcRegistry.icon("tiles", modelData)
                                size: Theme.px(13)
                                color: Theme.c.on
                            }
                            NText {
                                Layout.fillWidth: true
                                text: CcRegistry.label("tiles", modelData)
                                font.pixelSize: Theme.f.tiny
                                color: Theme.c.onDim
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            NLabel {
                Layout.fillWidth: true
                visible: root.tileIds.length === 0
                text: "No tiles"
                color: Theme.c.onFaint
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(4)
                spacing: Theme.px(6)

                Rectangle {
                    Layout.fillWidth: true
                    visible: Config.ccCaffeine
                    implicitHeight: Theme.px(18)
                    radius: Theme.r.tiny
                    color: Theme.c.surface2
                }

                Item {
                    Layout.fillWidth: true
                    visible: !Config.ccCaffeine
                }

                Row {
                    id: footRow
                    spacing: Theme.px(6)

                    Repeater {
                        id: footRep
                        model: root.footIds

                        Chip {
                            required property string modelData
                            required property int index
                            kind: "footer"
                            itemId: modelData
                            targeted: root.footTargetIndex === index
                            width: Theme.px(24)
                            height: Theme.px(20)
                            radius: Theme.px(5)

                            NIcon {
                                anchors.centerIn: parent
                                text: CcRegistry.icon("footer", modelData)
                                size: Theme.px(11)
                                color: Theme.c.on
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Everything left out, for both rows ──────────────────────────────
    // A thin strip under the panel rather than a separate list further
    // down the page: dragging a glyph up from here is how it joins a row,
    // same gesture as the bar's own shelf.
    ColumnLayout {
        id: shelfCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: outer.bottom
        anchors.topMargin: Theme.px(10)
        anchors.margins: Theme.px(10)
        spacing: Theme.px(6)

        NLabel {
            text: "Not shown - drag one up"
            visible: shelfFlow.count > 0
        }

        Flow {
            id: shelfFlow
            Layout.fillWidth: true
            spacing: Theme.px(8)
            readonly property int count: tileSpareRep.count + footSpareRep.count

            Repeater {
                id: tileSpareRep
                model: root.tileSpare
                Chip {
                    required property var modelData
                    kind: "tiles"
                    itemId: modelData.id
                    // The icon alone sized this: right for the footer
                    // chips below, which have no label, wrong here, where
                    // a wide title like "Night light" overflowed into the
                    // chip after it instead of setting the chip's width.
                    implicitWidth: content.implicitWidth + Theme.px(20)
                    implicitHeight: Theme.px(26)
                    radius: height / 2
                    RowLayout {
                        id: content
                        anchors.centerIn: parent
                        spacing: Theme.px(5)
                        NIcon {
                            id: ic
                            text: CcRegistry.icon("tiles", modelData.id)
                            size: Theme.px(11)
                            color: Theme.c.onDim
                        }
                        NText {
                            text: CcRegistry.label("tiles", modelData.id)
                            font.pixelSize: Theme.f.tiny
                            color: Theme.c.onDim
                        }
                    }
                }
            }

            Repeater {
                id: footSpareRep
                model: root.footSpare
                Chip {
                    required property var modelData
                    kind: "footer"
                    itemId: modelData.id
                    implicitWidth: ic.implicitWidth + Theme.px(14)
                    implicitHeight: Theme.px(26)
                    radius: height / 2
                    NIcon {
                        id: ic
                        anchors.centerIn: parent
                        text: CcRegistry.icon("footer", modelData.id)
                        size: Theme.px(12)
                        color: Theme.c.onFaint
                    }
                }
            }
        }
    }

    // The glyph in flight, above everything so it reads as picked up
    // rather than as belonging to whichever row it started in.
    Rectangle {
        visible: root.dragging
        z: 1000
        x: root.dragX - width / 2
        y: root.dragY - height / 2
        implicitWidth: ghostRow.implicitWidth + Theme.px(20)
        height: Theme.px(28)
        radius: height / 2
        color: Theme.c.surface3
        border.width: 2
        border.color: Theme.c.red
        scale: 1.08

        RowLayout {
            id: ghostRow
            anchors.centerIn: parent
            spacing: Theme.px(6)
            NIcon { text: CcRegistry.icon(root.dragKind, root.dragId); size: Theme.px(14); color: Theme.c.red }
            NText { text: CcRegistry.label(root.dragKind, root.dragId); font.pixelSize: Theme.f.tiny; color: Theme.c.on }
        }
    }
}
