import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Fallback pill when the Glyph Matrix is off. The pulse itself lives
// in OsdPulse so the matrix overlay can share it.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    visible: Config.osdEnabled && !Config.glyphEnabled && OsdPulse.shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-osd"

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.px(96)
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}   // purely decorative, captures nothing

    readonly property string mode: OsdPulse.mode
    readonly property real value: OsdPulse.level
    readonly property bool muted: OsdPulse.muted

    readonly property string glyph: {
        if (mode === "keyboard") return Brightness.kbdValue > 0 ? "󰌌" : "󰌐";
        if (mode === "brightness") {
            if (Brightness.extraDim) return "󰖔";
            return Brightness.value > 0.5 ? "󰃠" : "󰃞";
        }
        if (mode === "charge") return "󰂄";
        if (muted) return "󰝟";
        if (value > 0.5) return "󰕾";
        if (value > 0) return "󰖀";
        return "󰕿";
    }

    NCard {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(16)
        radius: Theme.r.pill
        clip: true
        implicitWidth: content.implicitWidth + Theme.px(26)
        implicitHeight: Theme.px(38)

        opacity: win.visible ? 1 : 0
        y: win.visible ? 0 : Theme.px(10)
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
