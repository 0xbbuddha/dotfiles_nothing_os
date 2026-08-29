import QtQuick
import QtQuick.Layouts
import "../.."
import ".."
import "../../services"
import "expr.js" as Expr

// One node of an app spec. Recursive: layout blocks instantiate
// AppBlock again through a Repeater, which defers the instantiation and
// keeps the type resolvable.
//
// A Loader rather than an Item wrapper: it already adopts its content's
// implicit size, which is what the surrounding Layout needs.
Loader {
    id: root

    required property var block
    property string appId: ""
    property var ctx: null
    property var item: null     // the element, inside a list
    property int idx: 0

    readonly property string kind: root.block?.t ?? ""

    function txt(field: string, dflt: string): string {
        return Expr.asText(root.block[field] ?? dflt ?? "", root.ctx, root.item, root.idx);
    }

    function num(field: string, dflt: real): real {
        return Expr.asNumber(root.block[field] ?? "", root.ctx, root.item, root.idx, dflt);
    }

    function paint(name: string): color {
        switch (name) {
        case "red":   return Theme.c.red;
        case "dim":   return Theme.c.onDim;
        case "faint": return Theme.c.onFaint;
        default:      return Theme.c.on;
        }
    }

    function align(name: string): int {
        switch (name) {
        case "center": return Text.AlignHCenter;
        case "right":  return Text.AlignRight;
        default:       return Text.AlignLeft;
        }
    }

    function statSize(name: string): real {
        switch (name) {
        case "s": return Theme.px(24);
        case "l": return Theme.px(46);
        default:  return Theme.px(34);
        }
    }

    function glyphSize(name: string): real {
        switch (name) {
        case "s": return Theme.z.icon;
        case "l": return Theme.px(24);
        default:  return Theme.z.iconL;
        }
    }

    function fire(action: string): void {
        if ((action ?? "") !== "")
            MiniApps.run(root.appId, action, root.item, root.idx);
    }

    sourceComponent: {
        switch (root.kind) {
        case "text":     return cText;
        case "stat":     return cStat;
        case "row":      return cRow;
        case "col":      return cCol;
        case "grid":     return cGrid;
        case "card":     return cCard;
        case "button":   return cButton;
        case "toggle":   return cToggle;
        case "slider":   return cSlider;
        case "field":    return cField;
        case "progress": return cProgress;
        case "ring":     return cRing;
        case "dots":     return cDots;
        case "bars":     return cBars;
        case "list":     return cList;
        case "divider":  return cDivider;
        case "spacer":   return cSpacer;
        case "icon":     return cIcon;
        case "image":    return cImage;
        default:         return null;
        }
    }

    // ── Text ─────────────────────────────────────────────────────────
    // One Text with a conditional font rather than a component per
    // style: display is Ndot, label is the tracked uppercase mono, the
    // rest is Inter at two sizes.

    Component {
        id: cText

        Text {
            readonly property string style: root.block.style ?? "body"

            text: root.txt("value", "")
            color: root.paint(style === "label" && (root.block.color ?? "") === ""
                ? "dim" : root.block.color)
            horizontalAlignment: root.align(root.block.align)
            verticalAlignment: Text.AlignVCenter
            renderType: Text.QtRendering

            font.family: {
                if (style === "display") return Theme.f.display;
                if (style === "label" || style === "mono") return Theme.f.mono;
                return Theme.f.sans;
            }
            font.pixelSize: {
                if (style === "display") return Theme.px(28);
                if (style === "label") return Theme.f.micro;
                if (style === "title") return Theme.f.big;
                if (style === "mono") return Theme.f.small;
                return Theme.f.body;
            }
            font.weight: style === "title" ? Font.DemiBold : Font.Normal
            font.letterSpacing: {
                if (style === "display") return Theme.px(28) * 0.04;
                if (style === "label") return Theme.f.track;
                return 0;
            }
            font.capitalization: style === "label"
                ? Font.AllUppercase : Font.MixedCase

            wrapMode: root.block.wrap ? Text.WordWrap : Text.NoWrap
            elide: root.block.wrap ? Text.ElideNone : Text.ElideRight
            maximumLineCount: root.block.wrap ? 3 : 1
        }
    }

    // ── Stat: the focal number, in Ndot ──────────────────────────────

    Component {
        id: cStat

        ColumnLayout {
            spacing: Theme.px(2)
            Layout.minimumWidth: 0

            // A plain Item with anchors, not a RowLayout. Capping the
            // value against the row's own width made the width depend on
            // what the cap produced, and Qt aborts that as a recursive
            // rearrange. Here both widths derive only from the band, so
            // there is nothing to negotiate.
            Item {
                id: band
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: value.implicitHeight

                NText {
                    id: unit
                    text: root.txt("unit", "")
                    // Dropped rather than elided down to "A…": a stub of
                    // a unit reads worse than no unit at all.
                    visible: text !== ""
                        && (width >= implicitWidth || width >= Theme.px(34))
                    color: Theme.c.onDim
                    renderType: Text.QtRendering
                    width: Math.min(implicitWidth, Math.max(0, band.width * 0.34))
                    elide: Text.ElideRight
                    anchors.left: value.right
                    anchors.leftMargin: Theme.px(5)
                    anchors.bottom: value.bottom
                    anchors.bottomMargin: Theme.px(6)
                }

                // Sized to its text, shrunk only as far as the unit
                // requires, so "0" and "/ 8" stay a pair while a race
                // name elides.
                DisplayText {
                    id: value
                    anchors.left: parent.left
                    text: root.txt("value", "")
                    size: root.statSize(root.block.size)
                    elide: Text.ElideRight
                    width: Math.max(0, Math.min(implicitWidth,
                        band.width - (unit.visible ? unit.width + Theme.px(5) : 0)))
                }
            }

            NLabel {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.txt("caption", "")
                visible: text !== ""
                elide: Text.ElideRight
            }
        }
    }

    // ── Layout ───────────────────────────────────────────────────────

    Component {
        id: cRow

        RowLayout {
            spacing: Theme.px(8)

            Repeater {
                model: root.block.kids ?? []

                AppSlot {
                    required property var modelData
                    block: modelData
                    appId: root.appId
                    ctx: root.ctx
                    item: root.item
                    idx: root.idx
                }
            }
        }
    }

    Component {
        id: cCol

        ColumnLayout {
            spacing: Theme.px(6)

            Repeater {
                model: root.block.kids ?? []

                AppSlot {
                    required property var modelData
                    block: modelData
                    appId: root.appId
                    ctx: root.ctx
                    item: root.item
                    idx: root.idx
                }
            }
        }
    }

    Component {
        id: cGrid

        GridLayout {
            columns: root.block.cols ?? 2
            columnSpacing: Theme.px(8)
            rowSpacing: Theme.px(8)

            Repeater {
                model: root.block.kids ?? []

                AppSlot {
                    required property var modelData
                    block: modelData
                    appId: root.appId
                    ctx: root.ctx
                    item: root.item
                    idx: root.idx
                }
            }
        }
    }

    Component {
        id: cCard

        Rectangle {
            implicitHeight: inner.implicitHeight + Theme.px(20)
            radius: Theme.r.chip
            color: Theme.c.surface2

            ColumnLayout {
                id: inner
                anchors.fill: parent
                anchors.margins: Theme.px(10)
                spacing: Theme.px(6)

                Repeater {
                    model: root.block.kids ?? []

                    AppSlot {
                        required property var modelData
                        block: modelData
                        appId: root.appId
                        ctx: root.ctx
                        item: root.item
                        idx: root.idx
                    }
                }
            }
        }
    }

    // ── Controls ─────────────────────────────────────────────────────

    Component {
        id: cButton

        Loader {
            sourceComponent: root.block.style === "square" ? dSquare : dPill

            Component {
                id: dPill
                NPillButton {
                    text: root.txt("label", "")
                    maxWidth: Theme.px(150)
                    Layout.minimumWidth: 0
                    onActivated: root.fire(root.block.on)
                }
            }

            Component {
                id: dSquare
                Rectangle {
                    implicitWidth: Theme.px(32)
                    implicitHeight: Theme.px(30)
                    radius: Theme.r.chip
                    color: sma.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    NText {
                        anchors.centerIn: parent
                        text: root.txt("label", "")
                        font.pixelSize: Theme.f.body
                    }

                    MouseArea {
                        id: sma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fire(root.block.on)
                    }
                }
            }
        }
    }

    Component {
        id: cToggle

        RowLayout {
            spacing: Theme.px(8)

            NText {
                Layout.fillWidth: true
                text: root.txt("label", "")
                visible: text !== ""
                font.pixelSize: Theme.f.body
                elide: Text.ElideRight
            }

            NSwitch {
                checked: !!(MiniApps.stateOf(root.appId) ?? {})[root.block.key]
                onToggled: (v) => MiniApps.setKey(root.appId, root.block.key, v)
            }
        }
    }

    Component {
        id: cSlider

        ColumnLayout {
            id: sl
            readonly property real lo: root.block.min ?? 0
            readonly property real hi: Math.max(sl.lo + 0.0001, root.block.max ?? 100)
            readonly property real grain: Math.max(0, root.block.step ?? 1)
            readonly property real raw:
                Number((MiniApps.stateOf(root.appId) ?? {})[root.block.key]) || 0

            spacing: Theme.px(4)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)

                NLabel {
                    Layout.fillWidth: true
                    text: root.txt("label", "")
                    elide: Text.ElideRight
                }

                NLabel {
                    text: String(Math.round(sl.raw * 100) / 100)
                    dim: false
                }
            }

            NSlider {
                Layout.fillWidth: true
                accent: Theme.c.red
                value: (sl.raw - sl.lo) / (sl.hi - sl.lo)
                onMoved: (v) => {
                    let next = sl.lo + v * (sl.hi - sl.lo);
                    if (sl.grain > 0)
                        next = Math.round(next / sl.grain) * sl.grain;
                    MiniApps.setKey(root.appId, root.block.key,
                        Math.max(sl.lo, Math.min(sl.hi, next)));
                }
            }
        }
    }

    Component {
        id: cField

        NField {
            // The state is the source of truth, but rebinding `text` on
            // every keystroke would fight the caret: it is only pushed
            // back in while the field is not being edited.
            readonly property string live:
                String((MiniApps.stateOf(root.appId) ?? {})[root.block.key] ?? "")

            implicitHeight: Theme.px(28)
            placeholder: root.block.placeholder ?? ""

            onLiveChanged: if (!focused) text = live
            Component.onCompleted: text = live
            onCommitted: (v) => MiniApps.setKey(root.appId, root.block.key, v)
            onSubmitted: (v) => {
                MiniApps.setKey(root.appId, root.block.key, v);
                root.fire(root.block.on);
            }
        }
    }

    // ── Gauges ───────────────────────────────────────────────────────

    Component {
        id: cProgress

        ColumnLayout {
            spacing: Theme.px(4)

            NLabel {
                Layout.fillWidth: true
                text: root.txt("label", "")
                visible: text !== ""
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.z.rail
                radius: height / 2
                color: Theme.c.surface3

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.num("value", 0)))
                    height: parent.height
                    radius: height / 2
                    color: Theme.c.red
                    Behavior on width { NumberAnimation { duration: Theme.fast } }
                }
            }
        }
    }

    Component {
        id: cRing

        Item {
            id: ring
            readonly property real fraction: Math.max(0, Math.min(1, root.num("value", 0)))
            implicitHeight: Theme.px(78)
            implicitWidth: Theme.px(78)

            onFractionChanged: arc.requestPaint()

            Canvas {
                id: arc
                anchors.centerIn: parent
                width: Theme.px(74)
                height: width

                onPaint: {
                    const g = getContext("2d");
                    const r = width / 2 - Theme.px(5);
                    g.reset();
                    g.lineWidth = Theme.px(5);
                    g.lineCap = "round";
                    g.strokeStyle = Theme.c.surface3;
                    g.beginPath();
                    g.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                    g.stroke();
                    if (ring.fraction <= 0)
                        return;
                    g.strokeStyle = Theme.c.red;
                    g.beginPath();
                    g.arc(width / 2, height / 2, r, -Math.PI / 2,
                          -Math.PI / 2 + Math.PI * 2 * ring.fraction);
                    g.stroke();
                }
            }

            NLabel {
                anchors.centerIn: parent
                text: root.txt("label", "")
                dim: false
            }
        }
    }

    Component {
        id: cDots

        ColumnLayout {
            spacing: Theme.px(5)

            DotBar {
                Layout.fillWidth: true
                value: root.num("value", 0)
                count: root.block.count ?? 10
                dot: Theme.px(6)
                onColor: Theme.c.red
            }

            NLabel {
                Layout.fillWidth: true
                text: root.txt("label", "")
                visible: text !== ""
                elide: Text.ElideRight
            }
        }
    }

    Component {
        id: cBars

        Item {
            id: bars
            readonly property var series: {
                const src = Expr.asArray(root.block.of, root.ctx, root.item, root.idx);
                const limit = root.block.limit ?? 12;
                const out = [];
                for (let i = 0; i < src.length && i < limit; i++) {
                    const v = Number(Expr.evaluate(root.block.value ?? "it",
                        root.ctx, src[i], i));
                    out.push(isFinite(v) ? v : 0);
                }
                return out;
            }
            // Normalised on the tallest bar: feeds have no fixed ceiling.
            readonly property real peak: {
                let top = 0;
                for (let i = 0; i < bars.series.length; i++)
                    top = Math.max(top, Math.abs(bars.series[i]));
                return top > 0 ? top : 1;
            }
            readonly property real slot: {
                const n = Math.max(1, bars.series.length);
                return (bars.width - (n - 1) * Theme.px(3)) / n;
            }

            implicitHeight: Theme.px(46)

            Row {
                anchors.fill: parent
                spacing: Theme.px(3)

                Repeater {
                    model: bars.series

                    Item {
                        required property var modelData
                        width: bars.slot
                        height: bars.height

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(Theme.px(2), bars.height
                                * Math.abs(Number(parent.modelData) || 0) / bars.peak)
                            radius: Theme.px(2)
                            color: Theme.c.red
                            Behavior on height { NumberAnimation { duration: Theme.fast } }
                        }
                    }
                }
            }
        }
    }

    // ── List ─────────────────────────────────────────────────────────

    Component {
        id: cList

        ColumnLayout {
            id: list
            readonly property var rows: {
                const src = Expr.asArray(root.block.of, root.ctx, root.item, root.idx);
                return src.slice(0, root.block.limit ?? 5);
            }

            spacing: Theme.px(6)

            Repeater {
                model: list.rows

                ColumnLayout {
                    id: entry
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Repeater {
                        model: root.block.item ?? []

                        AppSlot {
                            required property var modelData
                            block: modelData
                            appId: root.appId
                            ctx: root.ctx
                            // `it` and `i` inside the template are the row,
                            // not the list block's own item.
                            item: entry.modelData
                            idx: entry.index
                        }
                    }
                }
            }

            NLabel {
                Layout.fillWidth: true
                visible: list.rows.length === 0
                text: root.txt("empty", "") || "NOTHING YET"
            }
        }
    }

    // ── Filler ───────────────────────────────────────────────────────

    Component {
        id: cDivider

        Rectangle {
            implicitHeight: 1
            color: Theme.c.outline
        }
    }

    Component {
        id: cSpacer

        Item {
            implicitHeight: Theme.px(root.block.size ?? 8)
        }
    }

    Component {
        id: cImage

        // Rounded like the album art elsewhere in the shell: a Rectangle
        // that clips, with the Image filling it. Only https is loaded,
        // so a spec cannot point the shell at a local file.
        Rectangle {
            id: frame
            readonly property string url: root.txt("src", "")
            readonly property bool allowed: /^https:\/\//.test(frame.url)

            implicitHeight: Theme.px(root.block.height ?? 64)
            implicitWidth: (root.block.width ?? 0) > 0
                ? Theme.px(root.block.width) : Theme.px(root.block.height ?? 64)

            radius: {
                switch (root.block.round) {
                case "pill": return height / 2;
                case "tiny": return Theme.r.tiny;
                case "none": return 0;
                default:     return Theme.r.chip;
                }
            }
            color: Theme.c.surface3
            clip: true

            Image {
                id: pic
                anchors.fill: parent
                source: frame.allowed ? frame.url : ""
                fillMode: root.block.fit === "contain"
                    ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }

            // A feed that has no artwork for a row should leave a quiet
            // placeholder, not a broken frame.
            NIcon {
                anchors.centerIn: parent
                visible: pic.status !== Image.Ready
                text: "󰋩"
                size: Theme.z.iconM
                color: Theme.c.onFaint
            }
        }
    }

    Component {
        id: cIcon

        NIcon {
            text: root.txt("glyph", "")
            size: root.glyphSize(root.block.size)
            color: root.paint(root.block.color)
        }
    }
}
