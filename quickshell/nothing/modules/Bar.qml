import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import ".."
import "../components"
import "../components/bar"
import "../services"

// Four independent islands. The clock and Essential Key sit together at
// the centre of the screen; workspaces and the CC stay on the edges.
//
// The CC and flyouts live on a separate layer. Growing the bar window
// reconfigures the Hyprland layer and the navbar blinks as if it were
// reloading.
Item {
    id: root
    required property var modelData

PanelWindow {
    id: bar

    screen: root.modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nothing-bar"

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.z.barWin
    exclusiveZone: Theme.z.bar + Theme.px(9)

    mask: Region {
        intersection: Intersection.Combine
        regions: [
            Region { item: leftIsland },
            // The bar only takes clicks where an island is, and the
            // centre is now a variable number of them. Regions are not
            // Items so a Repeater cannot make them: a fixed pool is
            // indexed into instead.
            //
            // Both centreRep.count and centreIds are named on purpose.
            // count is what makes the binding re-run once the delegates
            // exist: evaluated during construction it found none, handed
            // back null, and never looked again, so the whole centre was
            // drawn and took no clicks at all. centreIds is what makes it
            // re-run when the list is reordered.
            Region { item: (centreRep.count > 0 && bar.centreIds.length > 0)
                ? centreRep.itemAt(0) : null },
            Region { item: (centreRep.count > 1 && bar.centreIds.length > 1)
                ? centreRep.itemAt(1) : null },
            Region { item: (centreRep.count > 2 && bar.centreIds.length > 2)
                ? centreRep.itemAt(2) : null },
            Region { item: (centreRep.count > 3 && bar.centreIds.length > 3)
                ? centreRep.itemAt(3) : null },
            Region { item: (centreRep.count > 4 && bar.centreIds.length > 4)
                ? centreRep.itemAt(4) : null },
            Region { item: (centreRep.count > 5 && bar.centreIds.length > 5)
                ? centreRep.itemAt(5) : null },
            Region { item: rightIsland }
        ]
    }

    readonly property var batt: UPower.displayDevice
    readonly property bool hasBatt: (batt?.isLaptopBattery ?? false) && Config.showBattery
    readonly property var trayItems: SystemTray.items?.values ?? []
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (root.modelData?.name ?? "")

    // Read once per change rather than in every binding: barZone builds
    // a fresh array each call, and a Repeater model that is a new array
    // every evaluation rebuilds its delegates constantly.
    readonly property var leftIds: Config.barLeft ? Config.barZone("left") : []
    readonly property var centreIds: Config.barCentre ? Config.barZone("centre") : []
    readonly property var rightIds: Config.barRight ? Config.barZone("right") : []

    readonly property int edge: Theme.px(10)
    readonly property int islandGap: Theme.px(12)
    readonly property real midX: (width - midCluster.width) / 2
    readonly property real leftMax: Math.max(Theme.px(72), midX - edge - islandGap)
    readonly property real rightMax: Math.max(Theme.px(72),
        width - edge - midX - midCluster.width - islandGap)

    // The flyouts are held open by whatever is hovering, and what hovers
    // now lives in a component that cannot see the timers. One call each
    // rather than a reach into this window's internals.
    function holdRecap(on: bool): void {
        if (on) { recapHide.stop(); bar.recapKeep = true; }
        else recapHide.restart();
    }

    function holdBatt(on: bool): void {
        if (on) { battHide.stop(); bar.battKeep = true; }
        else battHide.restart();
    }

    function holdMedia(on: bool): void {
        if (on) { mediaHide.stop(); bar.mediaKeep = true; }
        else mediaHide.restart();
    }

    function openCc(): void {
        GlobalState.controlCenterOpen = !GlobalState.controlCenterOpen;
    }

    property bool recapKeep: false
    property bool battKeep: false
    property bool mediaKeep: false
    property int essentialClicks: 0
    property bool essentialHeld: false
    Timer {
        id: recapHide
        interval: 220
        onTriggered: bar.recapKeep = false
    }
    Timer {
        id: battHide
        interval: 220
        onTriggered: bar.battKeep = false
    }
    Timer {
        id: mediaHide
        interval: 220
        onTriggered: bar.mediaKeep = false
    }

    // ── Left: workspaces + media ──────────────────────────────────────
    // ── Left ──────────────────────────────────────────────────────────
    // Contents come from Config.barLeft: see components/BarRegistry.qml.
    BarIsland {
        id: leftIsland
        anchors.left: parent.left
        anchors.leftMargin: bar.edge
        anchors.top: parent.top
        anchors.topMargin: Theme.px(5)
        width: Math.min(implicitWidth, bar.leftMax)
        visible: bar.leftIds.length > 0
        onActivated: bar.openCc()
        onSecondary: GlobalState.toggleLauncher()

        Repeater {
            model: bar.leftIds

            RowLayout {
                required property string modelData
                required property int index
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                // Between elements, never before the first: a separator
                // leading an island reads as a crack in it.
                BarSeparator { visible: index > 0 && slotItem.applies }

                BarSlot {
                    id: slotItem
                    Layout.alignment: Qt.AlignVCenter
                    itemId: modelData
                    win: bar
                }
            }
        }
    }

    // ── Centre ────────────────────────────────────────────────────────
    // One island per element, side by side and centred on the screen as a
    // group. Contents come from Config.barCentre.
    Row {
        id: midCluster
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(5)
        height: Theme.z.bar
        spacing: bar.islandGap

        Repeater {
            id: centreRep
            model: bar.centreIds

            NCard {
                id: centreCard
                required property string modelData
                radius: Theme.r.pill
                height: Theme.z.bar
                // A wide element sizes to its own content plus breathing
                // room; a square one keeps the bar's height, so the pill
                // stays a circle.
                width: BarRegistry.isWide(modelData)
                    ? centreSlot.implicitWidth + Theme.px(28)
                    : Theme.z.bar
                visible: centreSlot.applies

                BarSlot {
                    id: centreSlot
                    anchors.centerIn: parent
                    itemId: centreCard.modelData
                    win: bar
                }
            }
        }
    }

    // ── Right ─────────────────────────────────────────────────────────
    // Contents come from Config.barRight.
    BarIsland {
        id: rightIsland
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        anchors.top: parent.top
        anchors.topMargin: Theme.px(5)
        width: Math.min(implicitWidth, bar.rightMax)
        visible: bar.rightIds.length > 0
        onActivated: bar.openCc()
        onSecondary: GlobalState.toggleLauncher()
        onScrolled: (d) => {
            if (!Audio.audio) return;
            Audio.audio.volume = Math.max(0, Math.min(1, Audio.audio.volume + d * 0.05));
        }

        Repeater {
            model: bar.rightIds

            // Straight into the island, with no wrapper: BarIsland already
            // spaces its children by 10, and the margin this used to carry
            // simply added to that and left nine pixels hanging off the
            // end of the last element.
            BarSlot {
                required property string modelData
                Layout.alignment: Qt.AlignVCenter
                itemId: modelData
                win: bar
            }
        }
    }

    }

    PanelWindow {
        id: dropLayer
        screen: root.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nothing-overlay"
        anchors { top: true; left: true; right: true }
        implicitHeight: screen.height
        exclusiveZone: -1
        exclusionMode: ExclusionMode.Ignore

        readonly property int dropY: Theme.px(5) + Theme.z.bar + Theme.px(8)

        mask: Region {
            intersection: Intersection.Combine
            regions: [
                Region { item: cc.open ? cc : null },
                Region { item: recap.shown ? recap : null },
                Region { item: battRecap.shown ? battRecap : null },
                Region { item: mediaRecap.shown ? mediaRecap : null },
                Region { item: flyout.open ? flyout : null },
                Region { item: audioFlyout.open ? audioFlyout : null },
                Region { item: lightFlyout.open ? lightFlyout : null }
            ]
        }

    ControlCenter {
        id: cc
        open: GlobalState.controlCenterOpen && bar.onFocusedMonitor
        maxHeight: bar.screen.height - Theme.px(20) - Theme.z.barWin - Theme.px(8)
        onRequestClose: GlobalState.controlCenterOpen = false
        onOpenChanged: if (open) {
            GlobalState.netPanel = "";
            GlobalState.audioPanel = false;
            GlobalState.lightPanel = false;
        }
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.horizontalCenter: parent.horizontalCenter
    }

    NetFlyout {
        id: flyout
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        visible: bar.onFocusedMonitor && (open || opacity > 0.01)
    }

    AudioFlyout {
        id: audioFlyout
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        visible: bar.onFocusedMonitor && (open || opacity > 0.01)
    }

    BrightnessFlyout {
        id: lightFlyout
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        visible: bar.onFocusedMonitor && (open || opacity > 0.01)
    }

    SysRecap {
        id: recap
        onHoveredChanged: bar.holdRecap(hovered)
        shown: bar.recapKeep && !cc.open && !flyout.open && !audioFlyout.open && !lightFlyout.open && bar.onFocusedMonitor
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
    }

    BattRecap {
        id: battRecap
        batt: bar.batt
        onHoveredChanged: bar.holdBatt(hovered)
        shown: bar.battKeep && !cc.open && !flyout.open && !audioFlyout.open && !lightFlyout.open && bar.onFocusedMonitor
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
    }

    MediaRecap {
        id: mediaRecap
        onHoveredChanged: bar.holdMedia(hovered)
        shown: bar.mediaKeep && Player.active && !cc.open && !flyout.open && !audioFlyout.open && !lightFlyout.open && bar.onFocusedMonitor
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        x: leftIsland.x + leftIsland.width - width
    }

    HyprlandFocusGrab {
        active: (cc.open || flyout.open || audioFlyout.open || lightFlyout.open) && bar.onFocusedMonitor
        windows: [bar, dropLayer]
        onCleared: {
            GlobalState.controlCenterOpen = false;
            GlobalState.netPanel = "";
            GlobalState.audioPanel = false;
            GlobalState.lightPanel = false;
        }
    }
    }
}
