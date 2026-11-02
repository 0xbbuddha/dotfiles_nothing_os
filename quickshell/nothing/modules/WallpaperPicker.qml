import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"

// SUPER+SHIFT+T.
//
// Not a grid of equal thumbnails: one big stage shows whichever picture
// you're pointing at, and a row of Glyph-style dot rings below it is the
// switch - the same off-dots-stay-faint, lit-dots-go-red language the
// Glyph Matrix itself uses (components/GlyphMatrix.qml), just small and
// static rather than a live LED simulation, which this does not need.
//
// Four rings: the three characters this rice ships with, plus one that
// opens the file's own picker (zenity, same as Settings > Appearance) for
// a picture of your own - no folder to scan, no thumbnail wall.
OverlayWindow {
    id: win
    open: GlobalState.wallpaperPickerOpen
    onCloseRequested: { GlobalState.wallpaperPickerOpen = false; win.hoverChar = ""; }
    sheetWidth: Math.min(Theme.px(760), screen.width * 0.86)
    sheetHeight: col.implicitHeight + Theme.pad * 2
    topBias: 0.85
    scrim: "transparent"

    // "" = every screen, else a connector name.
    property string target: ""
    readonly property var screenNames: Quickshell.screens.map(s => s.name)

    readonly property bool dotsActive:
        win.target === "" ? Config.wallpaper === Wallpapers.dotWallpaperKey
                           : Wallpapers.isCurrent(Wallpapers.dotWallpaperKey, win.target)

    readonly property string customValue: "__custom__"

    // Hovering a ring previews it on the stage without picking it yet;
    // "" falls back to whatever is actually set.
    property string hoverChar: ""
    readonly property string shownChar: win.hoverChar !== "" ? win.hoverChar
        : (win.dotsActive ? Config.dotWallpaperChar : win.customValue)

    readonly property var tiles: Wallpapers.dotWallpaperChars
        .concat([{ label: "Custom", value: win.customValue }])

    NProcess {
        id: filePicker
        command: ["zenity", "--file-selection", "--title=Choose a wallpaper",
                  "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "")
                    Wallpapers.set(p, win.target);
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.px(16)

        // ── Header ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(10)

            DisplayText { text: "WALLPAPER"; size: Theme.px(20) }
            Item { Layout.fillWidth: true }

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(100) * (win.screenNames.length + 1)
                visible: win.screenNames.length > 1
                options: [{ label: "All screens", value: "" }]
                    .concat(win.screenNames.map(n => ({ label: n, value: n })))
                current: win.target
                onPicked: (v) => win.target = v
            }
            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(120)
                options: [{ label: "Crop", value: "crop" }, { label: "Fit", value: "fit" }]
                current: Config.wallpaperFill
                onPicked: (v) => { Config.wallpaperFill = v; Config.save(); }
            }
            CircleButton {
                icon: "󰅖"
                size: Theme.px(24)
                onActivated: win.requestClose()
            }
        }

        // ── Stage: whatever is hovered, or whatever is set ──────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(300)
            radius: Theme.r.panel
            color: Theme.c.surface2
            clip: true

            readonly property bool custom: win.shownChar === win.customValue
            readonly property bool hasCustomPic:
                (Config.wallpaper ?? "") !== "" && Config.wallpaper !== Wallpapers.dotWallpaperKey

            Image {
                anchors.fill: parent
                visible: !parent.custom
                source: parent.custom ? "" : "file://" + Wallpapers.dotWallpaperPathFor(win.shownChar, true)
                sourceSize.width: Theme.px(900)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.med } }
            }

            Image {
                anchors.fill: parent
                visible: parent.custom && parent.hasCustomPic
                source: parent.custom && parent.hasCustomPic ? "file://" + Config.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.med } }
            }

            // Nothing to show: no custom picture set yet.
            ColumnLayout {
                anchors.centerIn: parent
                visible: parent.custom && !parent.hasCustomPic
                spacing: Theme.px(8)
                NIcon { Layout.alignment: Qt.AlignHCenter; text: "󰉏"; size: Theme.px(34); color: Theme.c.onDim }
                NText { Layout.alignment: Qt.AlignHCenter; text: "No picture set yet"; color: Theme.c.onDim }
            }

            DotField {
                anchors.fill: parent
                dotColor: Theme.c.onFaint
                opacity: 0.12
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.px(110)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                }
            }

            // A spec-sheet tag, the way Nothing prints a part number
            // next to anything it shows you.
            NText {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.px(14)
                text: (win.tiles.findIndex(t => t.value === win.shownChar) + 1)
                    + " / " + win.tiles.length
                color: Qt.rgba(1, 1, 1, 0.5)
                font.family: Theme.f.mono
                font.pixelSize: Theme.f.small
            }

            DisplayText {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.px(18)
                text: (win.tiles.find(t => t.value === win.shownChar)?.label ?? "").toUpperCase()
                size: Theme.px(30)
                color: "white"
            }
        }

        // ── Dock: one Glyph-style ring per choice ───────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.px(28)

            Repeater {
                model: win.tiles

                ColumnLayout {
                    id: tile
                    required property var modelData
                    readonly property bool isCustom: tile.modelData.value === win.customValue
                    readonly property bool active: tile.isCustom
                        ? !win.dotsActive
                        : (win.dotsActive && Config.dotWallpaperChar === tile.modelData.value)
                    readonly property real lit: tile.active ? 1 : (tma.containsMouse ? 0.55 : 0)

                    spacing: Theme.px(8)

                    Item {
                        id: ring
                        Layout.alignment: Qt.AlignHCenter
                        readonly property real size: Theme.px(62)
                        width: size; height: size

                        Repeater {
                            model: 20
                            Rectangle {
                                required property int index
                                readonly property real angle:
                                    (index / 20) * Math.PI * 2 - Math.PI / 2
                                readonly property real r: ring.size / 2 - Theme.px(3)
                                width: Theme.px(3.4); height: width; radius: width / 2
                                x: ring.size / 2 + r * Math.cos(angle) - width / 2
                                y: ring.size / 2 + r * Math.sin(angle) - width / 2
                                color: tile.lit > 0 ? Theme.c.red : Theme.c.onFaint
                                opacity: tile.lit > 0 ? (0.4 + tile.lit * 0.6) : 0.4
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                            }
                        }

                        NIcon {
                            anchors.centerIn: parent
                            visible: tile.isCustom
                            text: "󰉏"
                            size: Theme.px(20)
                            color: tile.lit > 0 ? Theme.c.on : Theme.c.onDim
                        }

                        DisplayText {
                            anchors.centerIn: parent
                            visible: !tile.isCustom
                            text: tile.modelData.label.charAt(0)
                            size: Theme.px(22)
                            color: tile.lit > 0 ? Theme.c.on : Theme.c.onDim
                        }

                        scale: tma.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast } }

                        MouseArea {
                            id: tma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.hoverChar = tile.modelData.value
                            onExited: if (win.hoverChar === tile.modelData.value) win.hoverChar = ""
                            onClicked: {
                                if (tile.isCustom) {
                                    filePicker.running = true;
                                } else {
                                    Config.dotWallpaperChar = tile.modelData.value;
                                    Wallpapers.set(Wallpapers.dotWallpaperKey, win.target);
                                }
                            }
                        }
                    }

                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.label.toUpperCase()
                        color: tile.active ? Theme.c.on : Theme.c.onDim
                        font.pixelSize: Theme.f.micro
                        font.letterSpacing: Theme.f.track
                    }
                }
            }
        }
    }
}
