import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../services"

// Capture motion: the shot becomes a card, Essential Space peeks open,
// and the card lands in the vault.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-essential-fly"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    readonly property string path: {
        const p = GlobalState.essentialFlyPath;
        const cut = p.indexOf("?");
        return cut >= 0 ? p.slice(0, cut) : p;
    }
    readonly property bool onThisScreen:
        GlobalState.essentialFlyScreen === (win.modelData?.name ?? "")
    readonly property bool rightSide: Config.essentialSide !== "left"
    readonly property int paneW: Theme.px(372)

    visible: path !== "" && onThisScreen

    property real fold: 0
    property real dock: 0
    property real fade: 1

    readonly property real floatW: Math.min(width * 0.46, Theme.px(520))
    readonly property real floatH: Math.min(height * 0.42, Theme.px(320))
    readonly property real floatX: win.rightSide
        ? Math.max(Theme.px(24), (width - paneW - floatW) / 2)
        : paneW * 0.72 + Math.max(Theme.px(24), (width - paneW - floatW) / 2)
    readonly property real floatY: (height - floatH) / 2

    readonly property real destX: win.rightSide
        ? width - paneW + Theme.pad
        : Theme.pad
    readonly property real destY: Theme.z.barWin + Theme.px(54)
    readonly property real destW: paneW - Theme.pad * 2
    readonly property real destH: Theme.px(148)

    readonly property real cardX:
        (1 - dock) * ((1 - fold) * 0 + fold * floatX) + dock * destX
    readonly property real cardY:
        (1 - dock) * ((1 - fold) * 0 + fold * floatY) + dock * destY
    readonly property real cardW:
        (1 - dock) * ((1 - fold) * width + fold * floatW) + dock * destW
    readonly property real cardH:
        (1 - dock) * ((1 - fold) * height + fold * floatH) + dock * destH
    readonly property real cardR:
        Theme.px(4) + fold * Theme.px(16) + dock * Theme.px(4)

    onVisibleChanged: {
        if (visible)
            fly.start();
        else {
            fly.stop();
            fold = 0;
            dock = 0;
            fade = 1;
            flash.opacity = 0;
        }
    }

    MouseArea { anchors.fill: parent }

    Item {
        id: card
        x: win.cardX
        y: win.cardY
        width: win.cardW
        height: win.cardH
        opacity: win.fade

        Rectangle {
            anchors.fill: parent
            radius: win.cardR
            color: Theme.c.surface
            clip: true

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
                source: win.path !== "" ? ("file://" + win.path) : ""
            }
        }
    }

    Rectangle {
        id: flash
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
    }

    SequentialAnimation {
        id: fly
        ScriptAction { script: flash.opacity = 0.5; }
        NumberAnimation {
            target: flash; property: "opacity"; to: 0
            duration: 150; easing.type: Easing.OutQuad
        }
        ScriptAction { script: GlobalState.essentialCatching = true; }
        PauseAnimation { duration: 180 }
        NumberAnimation {
            target: win; property: "fold"; from: 0; to: 1
            duration: 420; easing.type: Easing.OutCubic
        }
        PauseAnimation { duration: 70 }
        NumberAnimation {
            target: win; property: "dock"; from: 0; to: 1
            duration: 540; easing.type: Easing.InOutCubic
        }
        PauseAnimation { duration: 80 }
        NumberAnimation {
            target: win; property: "fade"; to: 0
            duration: 180; easing.type: Easing.InQuad
        }
        ScriptAction { script: Essentials.finishFly(); }
    }
}
