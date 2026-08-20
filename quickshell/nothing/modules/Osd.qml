import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import ".."
import "../components"
import "../services"

// Volume / brightness overlay: a pill at the bottom that fades on its own.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    visible: Config.osdEnabled && shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-osd"

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.px(96)
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}   // purely decorative, captures nothing

    property bool shown: false
    property string mode: "volume"     // volume | brightness | keyboard
    property bool armed: false         // skip showing at startup

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property real value: {
        if (mode === "volume") return volume;
        if (mode === "keyboard") return Brightness.kbdValue;
        return Brightness.combined;
    }

    readonly property string glyph: {
        if (mode === "keyboard") return Brightness.kbdValue > 0 ? "󰌌" : "󰌐";
        if (mode === "brightness") {
            if (Brightness.extraDim) return "󰖔";
            return Brightness.value > 0.5 ? "󰃠" : "󰃞";
        }
        if (muted) return "󰝟";
        if (volume > 0.5) return "󰕾";
        if (volume > 0) return "󰖀";
        return "󰕿";
    }

    function flash(which: string): void {
        if (!win.armed || !Config.osdEnabled) return;
        win.mode = which;
        win.shown = true;
        Cava.osdHold = which === "volume" && Config.glyphEnabled;
        hideTimer.restart();
    }

    onVolumeChanged: flash("volume")
    onMutedChanged: flash("volume")

    Connections {
        target: Brightness
        function onChangedExternally(kind): void {
            win.flash(kind === "keyboard" ? "keyboard" : "brightness");
        }
    }

    Connections {
        target: NightLight
        function onGammaAdjusted(): void { win.flash("brightness"); }
    }

    // Arm the OSD only after services have settled.
    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: hideTimer; interval: 1600; onTriggered: { win.shown = false; Cava.osdHold = false; } }

    NCard {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(16)
        radius: Theme.r.pill
        clip: true
        implicitWidth: content.implicitWidth + Theme.px(26)
        implicitHeight: Theme.px(38)

        opacity: win.shown ? 1 : 0
        y: win.shown ? 0 : Theme.px(10)
        Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
        Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: Theme.px(11)

            NIcon {
                text: win.glyph
                size: Theme.z.iconL
                color: win.mode === "volume" && win.muted ? Theme.c.red : Theme.c.on
            }

            DotBar {
                Layout.preferredWidth: Theme.px(120)
                Layout.maximumWidth: Theme.px(120)
                Layout.preferredHeight: Theme.z.dot
                count: 24
                value: win.value
                split: win.mode === "brightness" && NightLight.available ? Brightness.split : -1
                onColor: win.mode === "volume" && win.muted ? Theme.c.onFaint
                    : (win.mode === "brightness" && Brightness.extraDim ? Theme.c.onDim : Theme.c.on)
            }

            Text {
                Layout.preferredWidth: Theme.px(28)
                Layout.minimumWidth: Theme.px(28)
                horizontalAlignment: Text.AlignRight
                text: Math.round(Math.max(0, Math.min(1, win.value)) * 100)
                color: Theme.c.on
                font.family: Theme.f.mono
                font.pixelSize: Theme.f.small
            }
        }
    }
}
