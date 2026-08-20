import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../components"
import "../services"

// Black-pill dock. Auto mode: always visible on an empty workspace,
// hidden as soon as a window occupies it (except when hovering the edge).
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nothing-dock"

    anchors { bottom: true; left: true; right: true }
    // Height must leave room for the tooltip, which draws above the dock:
    // otherwise it leaves the window and gets clipped.
    implicitHeight: Theme.z.dock + Theme.px(64)
    exclusionMode: ExclusionMode.Ignore

    readonly property bool autoHide: Config.dockAutoHide

    // monitorFor() is a plain call: without a reactive dependency the
    // binding runs once and keeps a pointer to the HyprlandMonitor that
    // existed at startup. After a hotplug, a DPMS cycle or a hyprctl
    // reload that object is gone, activeWsId freezes on whatever
    // workspace was active then, and the dock never comes back out.
    readonly property var monitor: {
        Hyprland.monitors.values;
        return Hyprland.monitorFor(modelData);
    }

    // Active workspace of THIS screen (not global focus, which may be
    // on the other monitor).
    readonly property int activeWsId: {
        const m = win.monitor;
        const ipc = m?.lastIpcObject ?? {};
        const sp = ipc.specialWorkspace;
        if (sp && (sp.id ?? 0) !== 0)
            return sp.id;
        return m?.activeWorkspace?.id
            ?? ipc.activeWorkspace?.id
            ?? Hyprland.focusedWorkspace?.id
            ?? 0;
    }

    readonly property bool workspaceOccupied: {
        const ws = win.activeWsId;
        if (ws === 0)
            return false;
        const list = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            // Closed windows linger in the model with a stale
            // lastIpcObject but no workspace object: trusting the IPC
            // copy would keep the workspace looking occupied forever.
            const w = t.workspace;
            if (!w)
                continue;
            if (t.lastIpcObject?.hidden)
                continue;
            if (w.id === ws)
                return true;
        }
        return false;
    }

    // The trigger strip does not reveal immediately: without this delay,
    // aiming at a field at the bottom of a window (chat, address bar)
    // would pop the dock and swallow the click.
    Timer {
        id: showDelay
        interval: 180
        onTriggered: if (hotzone.containsMouse) win.armed = true
    }

    property bool armed: false

    readonly property bool hovered: hotzone.containsMouse || dockArea.containsMouse

    readonly property bool revealed: !autoHide || !win.workspaceOccupied
        || dockArea.containsMouse || win.armed || hold.running

    Timer {
        id: toplevelRefresh
        interval: 80
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            const n = event.name;
            // A monitor's lastIpcObject is only rewritten by an
            // explicit refresh, and that is where specialWorkspace
            // lives. Without this, opening the scratchpad once pins
            // activeWsId to -98 and the dock never comes back out.
            if (n === "activespecial" || n === "activespecialv2"
                || n === "focusedmon" || n === "focusedmonv2"
                || n === "monitoradded" || n === "monitoraddedv2"
                || n === "monitorremoved")
                Hyprland.refreshMonitors();

            if (n === "openwindow" || n === "closewindow"
                || n === "movewindow" || n === "movewindowv2"
                || n === "workspace" || n === "workspacev2"
                || n === "focusedmon" || n === "focusedmonv2"
                || n === "activespecial" || n === "activespecialv2"
                || n === "monitoradded" || n === "monitoraddedv2"
                || n === "monitorremoved")
                toplevelRefresh.restart();
        }
    }

    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
    }

    // Safety net: a dropped event would otherwise leave the dock stuck
    // off-screen until the next reload. Only runs while it is hidden.
    Timer {
        running: win.autoHide && !win.revealed
        interval: 5000
        repeat: true
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshToplevels();
        }
    }

    onHoveredChanged: {
        if (hotzone.containsMouse && !dockArea.containsMouse && !win.armed)
            showDelay.restart();
        if (hovered) {
            hold.stop();
            return;
        }
        showDelay.stop();
        // The grace delay only applies if the dock was actually out:
        // a mere pass over the edge must not reveal it.
        if (win.armed)
            hold.restart();
        win.armed = false;
    }

    Timer {
        id: hold
        interval: Config.dockHideDelay
    }

    // Hidden: only the thin edge strip, not the full screen width.
    // Revealed: the dock is added so hovering icons keeps it out.
    Region { id: hotzoneRegion; item: hotzone }
    Region { id: dockRegion; item: dockArea }

    mask: Region {
        intersection: Intersection.Combine
        regions: win.revealed ? [hotzoneRegion, dockRegion] : [hotzoneRegion]
    }

    Process { id: sh; function run(cmd) { command = ["sh", "-c", cmd]; running = true; } }

    readonly property var openClasses: {
        const out = {};
        for (const t of (Hyprland.toplevels?.values ?? [])) {
            const c = t.lastIpcObject?.class;
            if (c) out[String(c).toLowerCase()] = true;
        }
        return out;
    }

    // Keep only apps that are actually installed.
    readonly property var entries: (Config.dockApps ?? [])
        .map(id => ({ id: id, entry: Apps.entry(id) }))
        .filter(x => x.entry !== null)

    // ── Trigger strip, glued to the bottom edge ───────────────────────
    // Not the full width: only under the dock. A fullscreen chat has its
    // input bar at the bottom, but not necessarily in the centre.
    MouseArea {
        id: hotzone
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.max(dock.width + Theme.px(16), Theme.px(160))
        height: Theme.px(2)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ── The dock ──────────────────────────────────────────────────────
    MouseArea {
        id: dockArea
        anchors.horizontalCenter: parent.horizontalCenter
        width: dock.width + Theme.px(16)
        height: Theme.z.dock + Theme.px(12)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        // Position via y, without anchors.bottom: both at once cancel
        // out, and the dock stayed in the mask even when hidden.
        y: win.revealed ? parent.height - height : parent.height
        Behavior on y {
            NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
        }

        NCard {
            id: dock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(8)
            radius: Theme.r.chip
            height: Theme.z.dock
            width: apps.implicitWidth + Theme.px(16)

            opacity: win.revealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            RowLayout {
                id: apps
                anchors.centerIn: parent
                spacing: Theme.px(2)

                Item {
                    id: osSlot
                    Layout.preferredWidth: Theme.z.dockSlot
                    Layout.preferredHeight: Theme.z.dockSlot

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r.tiny
                        color: oma.containsMouse ? Theme.c.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -Theme.px(2)
                        iconName: "endeavouros"
                        size: Theme.z.dockIcon
                        opacity: oma.containsMouse ? 1 : 0.9
                    }

                    MouseArea {
                        id: oma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (m) => {
                            if (m.button === Qt.RightButton)
                                GlobalState.settingsOpen = true;
                            else
                                GlobalState.sessionOpen = true;
                        }
                    }

                    scale: oma.pressed ? 0.88 : (oma.containsMouse ? 1.08 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }

                    Tooltip {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: Theme.px(6)
                        text: "Session  ·  right click: settings"
                        shown: oma.containsMouse
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Theme.px(18)
                    Layout.leftMargin: Theme.px(4)
                    Layout.rightMargin: Theme.px(4)
                    color: Theme.c.outline
                }

                Repeater {
                    model: win.entries

                    Item {
                        id: slot
                        required property var modelData
                        readonly property string appId: modelData.id
                        readonly property var entry: modelData.entry
                        readonly property bool running:
                            win.openClasses[Apps.classFor(appId)] ?? false

                        Layout.preferredWidth: Theme.z.dockSlot
                        Layout.preferredHeight: Theme.z.dockSlot

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r.tiny
                            color: ma.containsMouse ? Theme.c.surface3 : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -Theme.px(2)
                            appId: slot.appId
                            size: Theme.z.dockIcon
                            opacity: slot.running || ma.containsMouse ? 1 : 0.82
                            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.px(3)
                            width: slot.running ? Theme.px(9) : 0
                            height: Theme.px(2)
                            radius: height / 2
                            color: Theme.c.red
                            Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (slot.running)
                                    Hyprland.dispatch(`hl.dsp.focus({ window = "class:${Apps.classFor(slot.appId)}" })`);
                                else
                                    Apps.launch(slot.appId);
                            }
                        }

                        scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.08 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }

                        Tooltip {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: Theme.px(6)
                            text: slot.entry.name
                            shown: ma.containsMouse
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Theme.px(18)
                    Layout.leftMargin: Theme.px(4)
                    Layout.rightMargin: Theme.px(4)
                    color: Theme.c.outline
                    visible: win.entries.length > 0
                }

                Item {
                    Layout.preferredWidth: Theme.z.dockSlot
                    Layout.preferredHeight: Theme.z.dockSlot

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r.tiny
                        color: lma.containsMouse ? Theme.c.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }

                    NIcon {
                        anchors.centerIn: parent
                        text: "󰀻"
                        size: Theme.px(15)
                        color: lma.containsMouse ? Theme.c.on : Theme.c.onDim
                    }

                    MouseArea {
                        id: lma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (m) => {
                            if (m.button === Qt.RightButton) GlobalState.settingsOpen = true;
                            else GlobalState.toggleLauncher();
                        }
                    }

                    Tooltip {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: Theme.px(6)
                        text: "Applications  ·  right click: settings"
                        shown: lma.containsMouse
                    }
                }
            }
        }
    }
}
