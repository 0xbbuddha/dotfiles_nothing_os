import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

// Wallpaper drawn by the shell - no need for swww or hyprpaper.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: Theme.c.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nothing-wallpaper"
    // Without this, the bar's exclusive zone crops the wallpaper and
    // lets the compositor background colour show at the top.
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}   // fully click-through

    Item {
        id: stage
        anchors.fill: parent

        // Asked per screen, not once for all of them: the bundled pair
        // has a 16:10 frame and a 16:9 one, and each output should get
        // the one it was drawn for.
        readonly property url wallUrl: Wallpapers.wallpaperUrlFor(
            win.modelData?.width ?? 0, win.modelData?.height ?? 0)

        // The picture underneath, always live. A change never touches
        // it directly - the window below reveals the new one on top of
        // it first, and only swaps it in once fully covered, so there
        // is never a frame where neither layer has the whole picture.
        Image {
            id: base
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            smooth: true
            Component.onCompleted: source = stage.wallUrl
        }

        // Never shown directly - a status probe for the copy inside
        // `frame`, which is what actually gets seen.
        Image {
            id: incoming
            visible: false
            asynchronous: true
            cache: true
        }

        // Grows from the centre rather than crossfading in place: a
        // square window onto the new picture, opening like a Glyph
        // waking up. Pure geometry - width and height on a plain clipped
        // Item - after a full-screen Canvas here turned out to be the
        // one animation in this house too heavy for its own screen:
        // fine at a widget's size, not at every pixel of it.
        Item {
            id: frame
            anchors.centerIn: parent
            width: 0
            height: width
            clip: true

            Image {
                anchors.centerIn: parent
                width: stage.width
                height: stage.height
                fillMode: Image.PreserveAspectCrop
                smooth: true
                source: incoming.status === Image.Ready ? incoming.source : ""
            }

            // The one accent this house allows itself, riding the
            // growing edge rather than blending into it.
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: Theme.px(2)
                border.color: Theme.c.red
                visible: frame.width > Theme.px(4)
            }
        }

        readonly property real maxSide:
            Math.hypot(stage.width, stage.height) * 1.06

        NumberAnimation {
            id: sweep
            target: frame
            property: "width"
            from: 0
            to: stage.maxSide
            duration: 1300
            easing.type: Theme.ease
            onStopped: {
                base.source = incoming.source;
                frame.width = 0;
            }
        }

        onWallUrlChanged: incoming.source = stage.wallUrl

        Connections {
            target: incoming
            function onStatusChanged(): void {
                if (incoming.status === Image.Ready
                        && incoming.source != base.source) {
                    frame.width = 0;
                    sweep.restart();
                }
            }
        }
    }
}
