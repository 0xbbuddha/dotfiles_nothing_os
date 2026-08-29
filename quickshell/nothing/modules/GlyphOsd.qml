import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/glyph"
import "../services"

// Overlay copy of the disc while OsdPulse is showing. Lives on Overlay
// so the lights stay visible even when the idle matrix is under windows.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    visible: Config.osdEnabled && Config.glyphEnabled && OsdPulse.shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-glyph-osd"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}

    OsdToy { id: toyOsd }

    Component.onCompleted: win.place()

    function place(): void {
        const s = Config.glyphSize;
        const w = win.width, h = win.height;
        if (w <= 0 || h <= 0)
            return;
        if (Config.glyphX < 0 || Config.glyphY < 0) {
            disc.x = Math.round(Math.max(0, w - s - Theme.px(56)));
            disc.y = Math.round(Math.max(0, (h - s) / 2));
        } else {
            disc.x = Math.max(0, Math.min(w - s, Config.glyphX));
            disc.y = Math.max(0, Math.min(h - s, Config.glyphY));
        }
    }

    onWidthChanged: win.place()
    onHeightChanged: win.place()

    Connections {
        target: Config
        function onGlyphXChanged(): void { win.place(); }
        function onGlyphYChanged(): void { win.place(); }
        function onGlyphSizeChanged(): void { win.place(); }
    }

    Item {
        id: disc
        width: Config.glyphSize
        height: Config.glyphSize

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#0b0b0b"
        }

        GlyphMatrix {
            anchors.fill: parent
            anchors.margins: Theme.px(10)
            toy: toyOsd
            // The plate is the Glyph Matrix itself, always black, so the
            // dots stay white even on the light theme. Following
            // `on` painted them black on black.
            onColor: NightLight.active ? "#e8a070" : "#ffffff"
            offOpacity: NightLight.active ? 0.10 : 0.18
        }
    }
}
