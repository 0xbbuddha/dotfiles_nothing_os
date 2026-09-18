import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// A miniature of the bar, and the thing you actually edit through: drag a
// glyph between islands to move it, drag it below the islands to take it
// out, drag one up from below to add it, click one to remove it outright.
// No separate list to scroll to find the row that matches what you just
// looked at - the shapes being arranged are the controls now.
//
// Full labelled pills rather than bare glyphs, close to the real bar's
// own height rather than a thumbnail of it: half the point of editing
// through the shape itself is that the shape is legible enough to work
// with, not just to recognise. Each island gets a fixed share of the
// width and wraps onto more than one row past that, rather than growing
// wide enough to run into its neighbours - the right island alone can
// hold a dozen things, and a preview that lets it get wider than the
// other two put together is a preview nobody can aim at.
Rectangle {
    id: root

    Layout.fillWidth: true
    radius: Theme.r.chip
    color: Theme.veil(0.04)
    // The ghost travels outside whichever island it started in while it
    // is being dragged between them; clipping it there would make it
    // vanish at the border it is trying to cross.
    clip: false

    readonly property real chipH: Theme.px(32)
    // Three even shares of whatever width the settings page actually
    // gave this row, not a guess at it: the page's own margins already
    // decided that, and hardcoding a number here would drift from it the
    // moment the page's own padding changed.
    readonly property real islandBudget:
        Math.max(Theme.px(160), (root.width - Theme.px(56)) / 3)
    // The tallest island decides how much room the row of them needs -
    // an island with a dozen things in it wraps onto more than one row
    // rather than stretching sideways, so this is rarely all the same
    // number.
    readonly property real islandsH:
        Math.max(leftIsland.height, centreIsland.height, rightIsland.height)
    implicitHeight: islandsH + shelfCol.implicitHeight + Theme.px(14)

    // ── Drag state, owned here so a glyph can travel between islands
    // that are otherwise unrelated siblings ─────────────────────────────
    property string dragId: ""
    property string dragFrom: ""   // "left" / "centre" / "right" / "" (shelf)
    property real dragX: 0
    property real dragY: 0
    property real pressX: 0
    property real pressY: 0
    readonly property bool dragging: dragId !== ""

    readonly property string hoverZone: {
        if (!root.dragging) return "";
        if (root.dragY > root.islandsH) return ""; // over the shelf: taking it out
        if (leftIsland.visible && root.dragX >= leftIsland.x
            && root.dragX <= leftIsland.x + leftIsland.width) return "left";
        if (centreIsland.visible && root.dragX >= centreIsland.x
            && root.dragX <= centreIsland.x + centreIsland.width) return "centre";
        if (rightIsland.visible && root.dragX >= rightIsland.x
            && root.dragX <= rightIsland.x + rightIsland.width) return "right";
        return "";
    }

    function beginDrag(id: string, from: string, x: real, y: real): void {
        root.dragId = id;
        root.dragFrom = from;
        root.dragX = root.pressX = x;
        root.dragY = root.pressY = y;
    }

    function moveDrag(x: real, y: real): void {
        root.dragX = x;
        root.dragY = y;
    }

    function islandFor(zoneName: string): var {
        switch (zoneName) {
        case "left":   return leftIsland;
        case "centre": return centreIsland;
        case "right":  return rightIsland;
        default:       return null;
        }
    }

    // Where among its siblings a drop lands, read off their real
    // positions rather than guessed from spacing and count: an island can
    // wrap onto more than one row, so this is the same row-major scan
    // CcPreview uses for its own wrapping grid, not a single left-to-
    // right comparison.
    function indexForDrop(zoneName: string): int {
        const isl = root.islandFor(zoneName);
        const rep = isl?.chips ?? null;
        if (!rep) return 0;
        const p = isl.flowArea.mapFromItem(root, root.dragX, root.dragY);
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (!it || it.itemId === root.dragId) continue;
            // A row entirely above the drop is behind it (keep looking);
            // one entirely below is the first thing after it (land here);
            // within the drop's own row it comes down to which side of
            // centre.
            if (p.y >= it.y + it.height) continue;
            if (p.y < it.y) return i;
            if (p.x < it.x + it.width / 2) return i;
        }
        return rep.count;
    }

    // A press that barely moved is a click: remove outright, one gesture
    // for "I want this gone" instead of a drag all the way down to the
    // shelf. Anywhere else, it moves - to another island, or to wherever
    // among its own neighbours it was let go.
    function endDrag(): void {
        if (!root.dragging) return;
        const travelled = Math.abs(root.dragX - root.pressX)
            + Math.abs(root.dragY - root.pressY);
        if (travelled < Theme.px(6)) {
            Config.barPlace(root.dragId, "");
        } else if (root.hoverZone !== root.dragFrom) {
            Config.barPlace(root.dragId, root.hoverZone);
        } else if (root.hoverZone !== "") {
            // Same island: barMove's delta is relative to the list before
            // anything moves, so a target past the dragged item's own
            // slot has to shift back by one - that slot is gone once it
            // is lifted out.
            const from = Config.barZone(root.hoverZone).indexOf(root.dragId);
            const to = root.indexForDrop(root.hoverZone);
            const landing = to > from ? to - 1 : to;
            if (from >= 0 && landing !== from)
                Config.barMove(root.hoverZone, from, landing - from);
        }
        root.dragId = "";
        root.dragFrom = "";
    }

    // The bar sits on a wallpaper, so the preview sits on a field of dots
    // rather than on the flat sheet: against nothing, the islands read as
    // rows in a list instead of as objects floating over a desktop.
    DotField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.islandsH
        step: Theme.px(10)
        dotRadius: Theme.px(0.9)
        baseAlpha: 0.5
    }

    // A full pill - icon and label both, the same shape a real toggle in
    // this shell takes - rather than a bare glyph a bar element only
    // half resembles. Bigger, so the hand has something real to hold.
    component Chip: MouseArea {
        id: chip
        required property string itemId
        required property string zone   // island it is currently in, "" for the shelf
        property bool targeted: false
        readonly property bool lifted: root.dragging && root.dragId === chip.itemId
        readonly property bool small: chip.zone === "" && !chip.lifted

        implicitWidth: chipRow.implicitWidth + Theme.px(chip.small ? 14 : 18)
        implicitHeight: chip.small ? Theme.px(26) : root.chipH
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // The settings page is a Flickable; a slow drag would otherwise
        // be read as a scroll a few pixels in and the glyph would never
        // leave home.
        preventStealing: true
        // Above its own island once picked up, so it visibly leaves the
        // row rather than fighting its neighbours for the same pixels.
        z: chip.pressed ? 10 : 0
        opacity: chip.lifted ? 0.32 : 1
        scale: chip.pressed ? 0.94 : (chip.containsMouse && !root.dragging ? 1.05 : 1)
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        onPressed: (m) => {
            const p = chip.mapToItem(root, m.x, m.y);
            root.beginDrag(chip.itemId, chip.zone, p.x, p.y);
        }
        onPositionChanged: (m) => {
            if (!chip.pressed) return;
            const p = chip.mapToItem(root, m.x, m.y);
            root.moveDrag(p.x, p.y);
        }
        onReleased: root.endDrag()

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.zone !== ""
                ? (chip.containsMouse ? Theme.c.surface3 : Theme.c.surface2)
                : "transparent"
            border.width: chip.zone === "" ? 1 : (chip.targeted ? 2 : 0)
            border.color: chip.targeted ? Theme.c.red : Theme.c.outline
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.px(6)

            NIcon {
                text: BarRegistry.icon(chip.itemId)
                size: chip.small ? Theme.px(12) : Theme.px(14)
                color: chip.zone !== "" ? Theme.c.on : Theme.c.onDim
            }

            NText {
                text: BarRegistry.label(chip.itemId)
                visible: !chip.small
                font.pixelSize: Theme.f.tiny
                color: Theme.c.onDim
                elide: Text.ElideRight
            }
        }
    }

    component Island: Rectangle {
        id: island
        required property var ids
        required property string zoneName
        property bool hovered: false
        property alias chips: rep
        property alias flowArea: flow
        // Live, while a drag is being walked along this same island: the
        // index it would land on if let go right now.
        readonly property int targetIndex:
            (root.dragging && root.hoverZone === island.zoneName
                && root.dragFrom === island.zoneName)
                ? root.indexForDrop(island.zoneName) : -1

        visible: ids.length > 0 || island.hovered
        width: root.islandBudget
        implicitHeight: flow.implicitHeight + Theme.px(16)
        // Config.barRadius is set against the real bar's own islands; this
        // one is drawn at a different height, so the radius is scaled
        // with it. A preview that rounds harder than the thing it
        // previews is a lie about the shape - and the whole point of
        // this preview is to answer "what does that radius actually look
        // like" while dragging the slider that sets it.
        radius: Math.min(Config.barRadius * (root.chipH + Theme.px(16)) / Theme.z.bar,
                          Theme.r.chip)
        color: island.hovered ? Theme.c.surface3 : Theme.veil(0.05)
        border.width: island.hovered ? 2 : 1
        border.color: island.hovered ? Theme.c.red : Theme.c.outline
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
        anchors.top: parent.top
        anchors.topMargin: Theme.px(10)

        Flow {
            id: flow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.px(8)
            spacing: Theme.px(8)

            Repeater {
                id: rep
                model: island.ids
                Chip {
                    required property string modelData
                    required property int index
                    itemId: modelData
                    zone: island.zoneName
                    targeted: island.targetIndex === index
                }
            }
        }
    }

    Island {
        id: leftIsland
        zoneName: "left"
        ids: Config.barLeft ? Config.barZone("left") : []
        hovered: root.hoverZone === "left"
        anchors.left: parent.left
        anchors.leftMargin: Theme.px(10)
    }

    // The centre is one island per element in the real bar, but at this
    // size three pills with one glyph each are three specks: shown as one
    // group, which is what the arrangement actually says. It is still one
    // drop target, same as the real bar treats it as one zone.
    Island {
        id: centreIsland
        zoneName: "centre"
        ids: Config.barCentre ? Config.barZone("centre") : []
        hovered: root.hoverZone === "centre"
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Island {
        id: rightIsland
        zoneName: "right"
        ids: Config.barRight ? Config.barZone("right") : []
        hovered: root.hoverZone === "right"
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(10)
    }

    // ── Everything left out ─────────────────────────────────────────────
    // Its own strip under the islands rather than a separate list further
    // down the page: dragging a glyph up out of here is how it joins the
    // bar, and dragging one down out of an island is how it leaves - one
    // surface, one gesture, both directions.
    ColumnLayout {
        id: shelfCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.islandsH
        anchors.margins: Theme.px(10)
        spacing: Theme.px(6)

        NLabel {
            text: "Not in the bar - drag one up"
            visible: shelfFlow.count > 0
        }

        Flow {
            id: shelfFlow
            Layout.fillWidth: true
            spacing: Theme.px(8)
            readonly property int count: rep.count

            Repeater {
                id: rep
                model: BarRegistry.unplaced()
                Chip {
                    required property var modelData
                    itemId: modelData.id
                    zone: ""
                }
            }
        }
    }

    // The glyph being dragged, following the pointer above everything
    // else, at full size and lit red so it unmistakably reads as picked
    // up rather than as a fourth, stray pill.
    Rectangle {
        visible: root.dragging
        z: 1000
        x: root.dragX - width / 2
        y: root.dragY - height / 2
        implicitWidth: ghostRow.implicitWidth + Theme.px(20)
        height: root.chipH
        radius: height / 2
        color: Theme.c.surface3
        border.width: 2
        border.color: Theme.c.red
        scale: 1.08

        RowLayout {
            id: ghostRow
            anchors.centerIn: parent
            spacing: Theme.px(6)
            NIcon { text: BarRegistry.icon(root.dragId); size: Theme.px(15); color: Theme.c.red }
            NText { text: BarRegistry.label(root.dragId); font.pixelSize: Theme.f.tiny; color: Theme.c.on }
        }
    }
}
