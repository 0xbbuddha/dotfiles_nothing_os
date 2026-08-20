import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// HUD card on the game canvas.
// Editing: header to drag, handle to resize, snap to grid and edges.
// Pinned: minimal chrome, stays above the game.
Item {
    id: root

    required property string wid
    required property var host
    property var cfg: Config.gameWidget(wid) ?? ({})
    property bool editing: false
    default property alias content: holder.data

    readonly property var meta: GameRegistry.meta(wid)
    readonly property bool pinned: cfg.pinned ?? false
    readonly property bool clickthrough: cfg.clickthrough ?? false
    readonly property real hudOpacity: Math.max(0.35, Math.min(1, cfg.opacity ?? 1))
    readonly property bool selected: GlobalState.gameSelected === root.wid
    readonly property string screenName: host?.modelData?.name ?? ""

    readonly property bool onThisScreen: {
        const m = cfg.monitor ?? "";
        return m === "" || m === root.screenName;
    }

    visible: root.onThisScreen && (root.editing || root.pinned)
    opacity: root.editing ? 1 : (root.pinned ? root.hudOpacity : 0)
    Behavior on opacity { NumberAnimation { duration: Theme.med } }

    x: cfg.x ?? 80
    y: cfg.y ?? 80
    width: cfg.w ?? (meta?.w ?? 240)
    height: cfg.h ?? (meta?.h ?? 160)

    readonly property bool wantsClicks: !root.editing && root.pinned && (
        !root.clickthrough || (root.wid === "recorder" && Recorder.recording)
    )

    onWantsClicksChanged: host?.setClickable(root, wantsClicks)
    Component.onCompleted: host?.setClickable(root, wantsClicks)
    Component.onDestruction: host?.setClickable(root, false)

    function persist(): void {
        Config.updateGameWidget(root.wid, {
            x: Math.round(root.x),
            y: Math.round(root.y),
            w: Math.round(root.width),
            h: Math.round(root.height),
            monitor: root.screenName
        });
    }

    function updateGuides(): void {
        const pw = root.parent?.width ?? 1920;
        const ph = root.parent?.height ?? 1080;
        const mag = Theme.px(20);
        const cx = (pw - root.width) / 2;
        const cy = (ph - root.height) / 2;
        host.guideX = Math.abs(root.x - cx) < mag ? pw / 2 : -1;
        host.guideY = Math.abs(root.y - cy) < mag ? ph / 2 : -1;
    }

    function snap(): void {
        const g = Theme.px(8);
        const pw = root.parent?.width ?? 1920;
        const ph = root.parent?.height ?? 1080;
        let nx = Math.round(root.x / g) * g;
        let ny = Math.round(root.y / g) * g;
        const mag = Theme.px(20);
        const cx = (pw - root.width) / 2;
        const cy = (ph - root.height) / 2;
        if (Math.abs(nx - cx) < mag) nx = cx;
        if (Math.abs(ny - cy) < mag) ny = cy;
        if (Math.abs(nx) < mag) nx = 0;
        if (Math.abs(ny) < mag) ny = 0;
        if (Math.abs(nx + root.width - pw) < mag) nx = pw - root.width;
        if (Math.abs(ny + root.height - ph) < mag) ny = ph - root.height;
        root.x = Math.max(0, Math.min(pw - root.width, nx));
        root.y = Math.max(0, Math.min(ph - root.height, ny));
        root.clearGuides();
    }

    function clearGuides(): void {
        host.guideX = -1;
        host.guideY = -1;
    }

    NCard {
        anchors.fill: parent
        radius: Theme.r.chip
        color: root.editing
            ? Theme.c.surface
            : Qt.rgba(0, 0, 0, 0.55)
        border.width: root.editing ? 1 : 0
        border.color: root.selected ? Theme.c.red
                    : (headerDrag.drag.active ? Theme.c.onDim : Theme.c.outline)
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(8)
            spacing: Theme.px(6)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(7)
                visible: root.editing
                Layout.preferredHeight: Theme.px(22)

                NIcon {
                    text: root.meta?.icon ?? "󰝦"
                    size: Theme.z.icon
                    color: Theme.c.onDim
                }

                Text {
                    Layout.fillWidth: true
                    text: root.meta?.label ?? root.wid
                    color: Theme.c.onDim
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.micro
                    font.letterSpacing: Theme.f.track
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                }

                CircleButton {
                    icon: root.pinned ? "󰐃" : "󰤱"
                    size: Theme.px(20)
                    filled: root.pinned
                    onActivated: Config.updateGameWidget(root.wid, { pinned: !root.pinned })
                }

                CircleButton {
                    icon: root.clickthrough ? "󰈈" : "󰈉"
                    size: Theme.px(20)
                    filled: root.clickthrough
                    onActivated: Config.updateGameWidget(root.wid,
                        { clickthrough: !root.clickthrough })
                }

                CircleButton {
                    icon: "󰅖"
                    size: Theme.px(20)
                    onActivated: {
                        if (GlobalState.gameSelected === root.wid)
                            GlobalState.gameSelected = "";
                        Config.removeGameWidget(root.wid);
                    }
                }
            }

            Item {
                id: holder
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
            }
        }
    }

    // Select by clicking the chrome, without swallowing controls.
    // Move via the left strip of the header (icon + title).
    MouseArea {
        id: headerDrag
        anchors.left: parent.left
        anchors.top: parent.top
        width: Math.max(Theme.px(48), parent.width - Theme.px(92))
        height: root.editing ? Theme.px(38) : 0
        enabled: root.editing
        z: 5
        cursorShape: enabled
            ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
            : Qt.ArrowCursor
        drag.target: root.editing ? root : null
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: Math.max(0, (root.parent?.width ?? 2000) - root.width)
        drag.maximumY: Math.max(0, (root.parent?.height ?? 1200) - root.height)
        onPressed: GlobalState.gameSelected = root.wid
        onPositionChanged: if (pressed) root.updateGuides()
        onReleased: {
            root.snap();
            root.persist();
        }
    }

    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Theme.px(18)
        height: Theme.px(18)
        enabled: root.editing
        visible: root.editing
        cursorShape: Qt.SizeFDiagCursor
        z: 10

        property real startX: 0
        property real startY: 0
        property real startW: 0
        property real startH: 0

        onPressed: (m) => {
            GlobalState.gameSelected = root.wid;
            startX = m.x; startY = m.y;
            startW = root.width; startH = root.height;
        }
        onPositionChanged: (m) => {
            if (!pressed) return;
            const g = Theme.px(8);
            const pw = root.parent?.width ?? 2000;
            const ph = root.parent?.height ?? 1200;
            let nw = Math.max(Theme.px(160), startW + (m.x - startX));
            let nh = Math.max(Theme.px(88), startH + (m.y - startY));
            nw = Math.round(nw / g) * g;
            nh = Math.round(nh / g) * g;
            root.width = Math.min(nw, pw - root.x);
            root.height = Math.min(nh, ph - root.y);
        }
        onReleased: root.persist()

        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: Theme.px(2)
                height: Theme.px(2) + index * Theme.px(4)
                radius: 1
                color: root.selected ? Theme.c.red : Theme.c.onFaint
                x: parent.width - Theme.px(5) - index * Theme.px(4)
                y: parent.height - Theme.px(4) - height
            }
        }
    }
}
