import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import ".."
import "../components"
import "../services"

// Region picker: frozen screen, drag, click a detected region,
// or click empty space for the whole screen.
PanelWindow {
    id: win
    required property var modelData

    // Re-resolved when the monitor list changes: monitorFor() alone is a
    // one-shot call and would keep a dead HyprlandMonitor after a hotplug.
    //
    // Resolved on the signal rather than by reading monitors.values inside
    // the binding, which is what the dock and the workspace grid do. That
    // form reads the list the call itself can extend, and Qt called it a
    // binding loop here: this window is built at startup, while the list
    // is still filling, where the other two are built later and never
    // caught it. Same behaviour, no self-reference to race.
    property var mon: null

    function resolveMon(): void {
        win.mon = Hyprland.monitorFor(win.modelData);
    }

    Component.onCompleted: win.resolveMon()

    Connections {
        target: Hyprland.monitors
        function onValuesChanged(): void { win.resolveMon(); }
    }
    readonly property real offX: mon?.x ?? (modelData?.x ?? 0)
    readonly property real offY: mon?.y ?? (modelData?.y ?? 0)
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    property real startX: 0
    property real startY: 0
    property real curX: 0
    property real curY: 0
    property bool dragging: false
    property var imageRegions: []
    property var hovered: null

    readonly property real boxX: Math.min(startX, curX)
    readonly property real boxY: Math.min(startY, curY)
    readonly property real boxW: Math.abs(curX - startX)
    readonly property real boxH: Math.abs(curY - startY)
    readonly property bool hasBox: dragging && boxW > 2 && boxH > 2
    readonly property bool shotPick: Shot.picking && !Recorder.picking

    readonly property var windowRegions: {
        const list = Hyprland.toplevels?.values ?? [];
        const ws = win.mon?.activeWorkspace?.id
            ?? win.mon?.lastIpcObject?.activeWorkspace?.id
            ?? -1;
        const monId = win.mon?.id;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const o = t.lastIpcObject ?? {};
            if (o.hidden || o.mapped === false)
                continue;
            const id = t.workspace?.id ?? o.workspace?.id ?? -1;
            if (id !== ws)
                continue;
            if (o.monitor !== undefined && o.monitor !== monId)
                continue;
            const at = o.at ?? [0, 0];
            const size = o.size ?? [0, 0];
            const x = at[0] - win.offX;
            const y = at[1] - win.offY;
            const w = size[0];
            const h = size[1];
            if (w < 8 || h < 8)
                continue;
            if (x + w < 4 || y + h < 4)
                continue;
            if (x > win.width - 4 || y > win.height - 4)
                continue;
            out.push({
                at: [x, y],
                size: [w, h],
                area: w * h,
                kind: "window",
                label: o.class ?? ""
            });
        }
        out.sort((a, b) => a.area - b.area);
        return out;
    }

    screen: modelData
    color: "transparent"
    visible: Recorder.picking || Shot.picking
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-region"
    WlrLayershell.keyboardFocus: (visible && onFocusedMonitor)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    onVisibleChanged: {
        dragging = false;
        startX = startY = curX = curY = 0;
        hovered = null;
        imageRegions = [];
        if (visible) {
            Hyprland.refreshToplevels();
            if (win.shotPick)
                detect.kick();
        } else {
            detect.running = false;
        }
    }

    function contains(r: var, x: real, y: real): bool {
        return x >= r.at[0] && y >= r.at[1]
            && x <= r.at[0] + r.size[0] && y <= r.at[1] + r.size[1];
    }

    function sameRegion(a: var, b: var): bool {
        if (!a || !b)
            return false;
        return a.at[0] === b.at[0] && a.at[1] === b.at[1]
            && a.size[0] === b.size[0] && a.size[1] === b.size[1];
    }

    function hit(x: real, y: real): var {
        const imgs = win.imageRegions ?? [];
        for (let i = 0; i < imgs.length; i++) {
            if (win.contains(imgs[i], x, y))
                return imgs[i];
        }
        const wins = win.windowRegions;
        for (let i = 0; i < wins.length; i++) {
            if (win.contains(wins[i], x, y))
                return wins[i];
        }
        return null;
    }

    function sendGeo(x: real, y: real, w: real, h: real): void {
        const gx = Math.round(win.offX + x);
        const gy = Math.round(win.offY + y);
        const gw = Math.round(w);
        const gh = Math.round(h);
        if (gw < 2 || gh < 2)
            return;
        const geo = `${Math.round(x)},${Math.round(y)} ${gw}x${gh}`;
        if (Recorder.picking)
            Recorder.confirmRegion(`${gx},${gy} ${gw}x${gh}`);
        else
            Shot.confirmRegion(String(win.modelData.name), geo);
    }

    function confirmDrag(): void {
        if (boxW < 8 || boxH < 8)
            return;
        win.sendGeo(boxX, boxY, boxW, boxH);
    }

    function confirmClick(): void {
        const t = win.hovered;
        if (t)
            win.sendGeo(t.at[0], t.at[1], t.size[0], t.size[1]);
        else
            win.sendGeo(0, 0, win.width, win.height);
    }

    NProcess {
        id: detect
        function kick(): void {
            running = false;
            const img = `${Shot.snipDir}/${win.modelData.name}.png`;
            command = ["python3", Shot.detectScript,
                       "--image", img, "--hyprctl",
                       "--max-width", String(Math.round(win.width * 0.55)),
                       "--max-height", String(Math.round(win.height * 0.55))];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text.trim() || "[]");
                    const wins = win.windowRegions;
                    const kept = [];
                    for (let i = 0; i < raw.length; i++) {
                        const r = raw[i];
                        r.kind = "content";
                        r.label = "";
                        r.area = (r.size?.[0] ?? 0) * (r.size?.[1] ?? 0);
                        let overlap = false;
                        for (let j = 0; j < wins.length; j++) {
                            const a = r.at, s = r.size, b = wins[j].at, t = wins[j].size;
                            const ix = Math.max(0, Math.min(a[0] + s[0], b[0] + t[0]) - Math.max(a[0], b[0]));
                            const iy = Math.max(0, Math.min(a[1] + s[1], b[1] + t[1]) - Math.max(a[1], b[1]));
                            const inter = ix * iy;
                            const union = r.area + wins[j].area - inter;
                            if (union > 0 && inter / union > 0.55) {
                                overlap = true;
                                break;
                            }
                        }
                        if (!overlap)
                            kept.push(r);
                    }
                    win.imageRegions = kept;
                } catch (e) {
                    win.imageRegions = [];
                }
            }
        }
    }

    ScreencopyView {
        anchors.fill: parent
        live: false
        paintCursor: false
        captureSource: win.visible ? win.screen : null
    }

    Rectangle {
        anchors.fill: parent
        color: "#99000000"
        visible: !win.hasBox
    }

    Rectangle {
        visible: win.hasBox
        x: 0; y: 0
        width: parent.width
        height: win.boxY
        color: "#99000000"
    }
    Rectangle {
        visible: win.hasBox
        x: 0; y: win.boxY + win.boxH
        width: parent.width
        height: parent.height - y
        color: "#99000000"
    }
    Rectangle {
        visible: win.hasBox
        x: 0; y: win.boxY
        width: win.boxX
        height: win.boxH
        color: "#99000000"
    }
    Rectangle {
        visible: win.hasBox
        x: win.boxX + win.boxW; y: win.boxY
        width: parent.width - x
        height: win.boxH
        color: "#99000000"
    }

    Repeater {
        model: win.hasBox ? [] : win.windowRegions
        delegate: RegionMark {
            required property var modelData
            region: modelData
            targeted: !win.dragging && win.sameRegion(win.hovered, modelData)
            z: 2
        }
    }

    Repeater {
        model: win.hasBox ? [] : win.imageRegions
        delegate: RegionMark {
            required property var modelData
            region: modelData
            targeted: !win.dragging && win.sameRegion(win.hovered, modelData)
            z: 3
        }
    }

    Rectangle {
        visible: win.hasBox
        x: win.boxX
        y: win.boxY
        width: win.boxW
        height: win.boxH
        color: "transparent"
        border.width: 2
        border.color: Theme.c.red
        z: 5
    }

    Text {
        visible: win.hasBox
        x: win.boxX
        y: Math.max(Theme.px(8), win.boxY - Theme.px(22))
        text: `${Math.round(win.boxW)} × ${Math.round(win.boxH)}`
        color: Theme.c.red
        font.family: Theme.f.display
        font.pixelSize: Theme.px(14)
        renderType: Text.QtRendering
        z: 6
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (m) => {
            if (m.button === Qt.RightButton) {
                Recorder.cancelPick();
                Shot.cancelPick();
                return;
            }
            win.startX = win.curX = m.x;
            win.startY = win.curY = m.y;
            win.dragging = true;
        }
        onPositionChanged: (m) => {
            win.hovered = win.hit(m.x, m.y);
            if (!win.dragging)
                return;
            win.curX = m.x;
            win.curY = m.y;
        }
        onReleased: (m) => {
            if (m.button !== Qt.LeftButton || !win.dragging)
                return;
            win.dragging = false;
            if (win.boxW < 8 && win.boxH < 8)
                win.confirmClick();
            else
                win.confirmDrag();
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: win.visible && win.onFocusedMonitor
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
                Recorder.cancelPick();
                Shot.cancelPick();
                e.accepted = true;
            }
        }
    }

    NCard {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(18)
        radius: Theme.r.pill
        implicitWidth: hintRow.implicitWidth + Theme.px(22)
        implicitHeight: Theme.px(28)
        z: 8

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: Theme.px(10)
            NLabel {
                text: Recorder.picking ? "Drag to record" : "Click screen · highlight · drag"
                dim: false
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: Theme.px(10)
                color: Theme.c.outline
            }
            NLabel { text: "Esc cancel" }
        }
    }

    component RegionMark: Rectangle {
        required property var region
        property bool targeted: false

        x: region.at[0]
        y: region.at[1]
        width: region.size[0]
        height: region.size[1]
        radius: Theme.r.tiny
        color: targeted ? "#33d71921" : "transparent"
        border.width: targeted ? 2 : 1
        border.color: targeted ? Theme.c.red : "#66ffffff"
        opacity: targeted ? 1 : 0.35
        visible: width > 2 && height > 2

        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        NLabel {
            visible: parent.targeted && (region.label ?? "") !== ""
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.px(8)
            text: region.label
            dim: false
        }
    }
}
