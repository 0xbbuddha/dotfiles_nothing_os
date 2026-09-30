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
        // window onto the new picture, opening like a Glyph waking up.
        // Shaped like the screen itself, not a square dropped onto it -
        // height tracks width at the screen's own ratio, so the frame
        // reads as the screen arriving rather than a shape unrelated to
        // it. Pure geometry - width and height on a plain clipped Item -
        // after a full-screen Canvas here turned out to be the one
        // animation in this house too heavy for its own screen: fine at
        // a widget's size, not at every pixel of it. A true circle would
        // need a shader mask to clip the image to, and that shader is
        // exactly what crashed the vinyl widget once already - not a
        // risk worth taking at the size of a whole screen.
        Item {
            id: frame
            anchors.centerIn: parent
            width: 0
            height: stage.width > 0 ? width * (stage.height / stage.width) : 0
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

        NumberAnimation {
            id: sweep
            target: frame
            property: "width"
            from: 0
            to: stage.width * 1.02
            duration: 2600
            // Theme.ease (OutExpo) front-loads almost all of its motion
            // into the first fifth of the duration, which is right for a
            // button settling but wrong here: the frame reached its full
            // size almost at once and spent the rest of the duration
            // crawling through the last invisible fraction of it, so the
            // picture looked like it had simply appeared. This grows at
            // a steady rate instead, so the reveal actually takes as
            // long as it is given.
            easing.type: Easing.InOutQuad
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
