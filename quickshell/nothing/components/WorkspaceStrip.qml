import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

// Workspaces in the bar.
// On the special workspace, the strip announces it and only returns to
// numbers if the cursor hovers it.
Item {
    id: root

    property string monitorName: ""

    readonly property int count: Math.max(1, Config.workspaceCount)
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1

    // ── Special workspace ─────────────────────────────────────────────
    // Hyprland does not put it in activeworkspace: that stays on the normal
    // workspace underneath. State lives on the monitor, and since
    // refreshMonitors() is async, the activespecialv2 event payload is read
    // directly: "<id>,<name>,<monitor>".
    property int specialId: 0
    property string specialRaw: ""

    readonly property bool onSpecial: specialId !== 0
    readonly property string specialName: {
        const n = root.specialRaw;
        if (n.startsWith("special:")) return n.slice(8) || "special";
        return n || "special";
    }

    function applySpecial(id: int, name: string): void {
        root.specialId = (isFinite(id) && id !== 0) ? id : 0;
        root.specialRaw = root.specialId !== 0 ? name : "";
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        const mon = (Hyprland.monitors?.values ?? [])
            .find(m => m.name === root.monitorName);
        const sp = mon?.lastIpcObject?.specialWorkspace ?? null;
        root.applySpecial(sp?.id ?? 0, sp?.name ?? "");
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name !== "activespecialv2") return;
            const p = String(event.data).split(",");
            // the name may contain a comma; the monitor is the last field
            if (p[p.length - 1] !== root.monitorName) return;
            root.applySpecial(parseInt(p[0]), p.slice(1, -1).join(","));
        }
    }

    // ── Hover ─────────────────────────────────────────────────────────
    // One zone for the whole strip. Per-cell MouseAreas would steal hover
    // from the one below (Qt does not propagate hover), and the state
    // would drop as soon as a digit is reached.
    readonly property bool showNumbers: !onSpecial || hover.containsMouse || grace.running

    Timer { id: grace; interval: 300 }

    Connections {
        target: hover
        function onContainsMouseChanged(): void {
            if (hover.containsMouse) grace.stop();
            else grace.restart();
        }
    }

    implicitWidth: numbers.implicitWidth
    implicitHeight: Theme.px(22)

    // Digits according to the chosen style.
    function glyph(n: int): string {
        switch (Config.workspaceStyle) {
        case "japanese": {
            const kanji = ["一", "二", "三", "四", "五",
                           "六", "七", "八", "九", "十"];
            return kanji[n - 1] ?? String(n);
        }
        case "roman": {
            const romans = ["I", "II", "III", "IV", "V",
                            "VI", "VII", "VIII", "IX", "X"];
            return romans[n - 1] ?? String(n);
        }
        default:
            return String(n);
        }
    }

    function used(id: int): bool {
        return (root.windowsOn[id] ?? []).length > 0;
    }

    // Application classes per workspace, no duplicates. Recalculated as soon as
    // Hyprland notifies a toplevels change.
    readonly property var windowsOn: {
        const map = {};
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const ipc = t.lastIpcObject ?? {};
            const id = t.workspace?.id ?? ipc.workspace?.id ?? -1;
            if (id < 1)
                continue;
            const cls = String(ipc.class ?? ipc.initialClass ?? "");
            if (cls === "")
                continue;
            if (!map[id])
                map[id] = [];
            if (!map[id].includes(cls))
                map[id].push(cls);
        }
        return map;
    }

    // Without refresh, lastIpcObject is sometimes empty: the window exists
    // (hyprctl sees it) but the strip thinks the workspace is free.
    Timer {
        id: toplevelRefresh
        interval: 80
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow"
                || n === "movewindow" || n === "movewindowv2")
                toplevelRefresh.restart();
        }
    }

    function cellWidth(id: int): real {
        const n = Math.min(3, (root.windowsOn[id] ?? []).length);
        if (n === 0)
            return root.cellW;
        return Math.max(root.cellW, n * Theme.px(18) + Theme.px(8));
    }

    readonly property real cellW: Theme.px(22)
    readonly property real cellGap: Theme.px(3)

    // Index of the cell under an x in the MouseArea's coordinate system
    // (offset by its negative left margin).
    function indexAt(mx: real): int {
        let x = mx - Theme.px(8);
        if (x < 0)
            return -1;
        for (let i = 0; i < root.count; i++) {
            const w = root.cellWidth(i + 1);
            if (x < w + root.cellGap)
                return i;
            x -= w + root.cellGap;
        }
        return -1;
    }

    // ── Special-workspace label ───────────────────────────────────────
    // Same width as the numbers: the pill must not shrink.
    Item {
        id: special
        anchors.fill: parent
        opacity: root.showNumbers ? 0 : 1
        visible: !root.showNumbers || opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        Row {
            anchors.centerIn: parent
            spacing: Theme.px(6)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(5); height: width; radius: width / 2
                color: Theme.c.red

                SequentialAnimation on opacity {
                    running: root.onSpecial && !root.showNumbers
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutQuad }
                }
            }

            NLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: root.specialName
                dim: false
                font.pixelSize: Theme.f.tiny
            }
        }
    }

    // ── The numbers ───────────────────────────────────────────────────
    Row {
        id: numbers
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.cellGap
        opacity: root.showNumbers ? 1 : 0
        visible: true
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        Repeater {
            model: root.count

            Item {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool active: root.focusedId === wsId
                readonly property var clients: (root.windowsOn[wsId] ?? []).slice(0, 3)
                readonly property bool occupied: clients.length > 0
                readonly property bool hovered: hover.hoveredIndex === index

                width: root.cellWidth(wsId)
                height: Theme.px(22)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.px(5)
                    color: cell.hovered ? Theme.c.surface3 : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -Theme.px(1)
                    width: cell.active ? Theme.px(12) : 0
                    height: Theme.px(2)
                    radius: height / 2
                    color: Theme.c.red
                    Behavior on width {
                        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                    }
                }

                Row {
                    id: icons
                    anchors.centerIn: parent
                    spacing: Theme.px(1)
                    visible: cell.occupied

                    Repeater {
                        model: cell.clients

                        AppIcon {
                            required property string modelData
                            appId: modelData
                            size: Theme.px(18)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !cell.occupied
                    text: root.glyph(cell.wsId)
                    color: cell.active ? Theme.c.on : Theme.c.onFaint
                    font.family: Config.workspaceStyle === "japanese"
                        ? Theme.f.sans : Theme.f.mono
                    font.pixelSize: Theme.f.small
                    font.weight: cell.active ? Font.Medium : Font.Normal
                    renderType: Text.QtRendering

                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    scale: cell.hovered ? 1.18 : 1
                    Behavior on scale {
                        NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack }
                    }
                }
            }
        }
    }

    // Single zone: strip hover, hovered cell and clicks.
    // Per-cell MouseAreas would steal hover from this one (Qt does not
    // propagate hover), and the state would drop as soon as a digit is reached.
    MouseArea {
        id: hover
        anchors.fill: parent
        // Overflow generously: folded onto "special", the strip is narrow;
        // it must be aimable without precision.
        anchors.leftMargin: -Theme.px(8)
        anchors.rightMargin: -Theme.px(8)
        anchors.topMargin: -Theme.px(6)
        anchors.bottomMargin: -Theme.px(6)

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: hoveredIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

        // Binding rather than event handling: mouseX follows the cursor and
        // showNumbers is a dependency, so the index also recalculates when
        // the numbers appear, without waiting for a move.
        readonly property int hoveredIndex:
            containsMouse ? root.indexAt(mouseX) : -1

        onClicked: (m) => {
            const i = root.indexAt(m.x);
            if (i < 0) return;
            // Hyprland >= 0.56 evaluates dispatches as Lua: the classic
            // syntax ("workspace 3") fails to parse and does nothing.
            if (m.button === Qt.RightButton)
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${i + 1} })`);
            else
                // gotoWorkspaceSafe first closes the special workspace, otherwise
                // it would stay shown on top and nothing would appear to move.
                Hyprland.dispatch(`gotoWorkspaceSafe(${i + 1})`);
        }
    }
}
