import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"

// SUPER+SHIFT+T.
//
// A contact sheet, not a stage with a selector under it: Nothing's own
// language leans on photography (the camera module, the Glyph as a
// shutter), and a strip of numbered negatives between two rows of
// sprocket holes says that without borrowing a single thing from
// anyone else's picker. The active choice gets a red frame, the way a
// photographer circles a pick in grease pencil on a real sheet.
//
// Kept deliberately flat: no 3D, no shader, nothing per-frame beyond a
// cheap scale on hover. Six frames: the four defaults this rice ships,
// one that opens the file's own picker (zenity, same as Settings >
// Appearance) for a picture of your own, and one that runs a chosen
// picture through Nothing's glass filter first (Wallpapers.glassify,
// scripts/glass-wallpaper.py).
OverlayWindow {
    id: win
    open: GlobalState.wallpaperPickerOpen
    onCloseRequested: GlobalState.wallpaperPickerOpen = false
    // This sheet renders on Wayland's Overlay layer, above every ordinary
    // window there is - including the picker zenity is about to open.
    // Same reasoning as Settings > Appearance's "Browse": closing this
    // sheet first is what actually lets the dialog be seen, instead of
    // opening behind it where nothing can reach it.
    onOpenChanged: if (!win.open) win.hoverChar = ""
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
    readonly property string glassValue: "__glass__"
    readonly property bool glassActive:
        Wallpapers.isCurrent(Wallpapers.glassOut, win.target)

    // Hovering a frame previews its name without picking it yet;
    // "" falls back to whatever is actually set.
    property string hoverChar: ""
    readonly property string shownChar: win.hoverChar !== "" ? win.hoverChar
        : (win.dotsActive ? Config.dotWallpaperChar
            : (win.glassActive ? win.glassValue : win.customValue))

    readonly property var tiles: Wallpapers.dotWallpaperChars
        .concat([{ label: "Custom", value: win.customValue },
                 { label: "Glass", value: win.glassValue }])

    readonly property bool hasCustomPic:
        (Config.wallpaper ?? "") !== "" && Config.wallpaper !== Wallpapers.dotWallpaperKey

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
        spacing: Theme.px(18)

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

        // ── The contact sheet ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(10)
            Layout.bottomMargin: Theme.px(10)
            spacing: Theme.px(10)

            // Sprocket holes: one strip of dots, printed twice (above
            // and below the frames) rather than shared, since an inline
            // local component this deeply nested isn't resolved by this
            // runtime.
            Item {
                id: perfTop
                Layout.fillWidth: true
                implicitHeight: Theme.px(6)
                readonly property real pitch: Theme.px(13)
                readonly property int count: Math.max(2, Math.floor(width / pitch))

                Repeater {
                    model: perfTop.count
                    Rectangle {
                        required property int index
                        readonly property real offset:
                            (perfTop.width - perfTop.count * perfTop.pitch) / 2
                        width: Theme.px(5); height: Theme.px(5); radius: Theme.px(1)
                        x: offset + index * perfTop.pitch
                        color: Theme.c.onFaint
                    }
                }
            }

            // ── Frames ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.px(10)

                Repeater {
                    model: win.tiles

                    Rectangle {
                        id: frame
                        required property var modelData
                        required property int index
                        readonly property bool isCustom: frame.modelData.value === win.customValue
                        readonly property bool isGlass: frame.modelData.value === win.glassValue
                        readonly property bool active: frame.isGlass
                            ? win.glassActive
                            : (frame.isCustom
                                ? (!win.dotsActive && !win.glassActive)
                                : (win.dotsActive && Config.dotWallpaperChar === frame.modelData.value))
                        readonly property bool hovered: fma.containsMouse

                        Layout.preferredWidth: Theme.px(120)
                        Layout.preferredHeight: Theme.px(68)
                        radius: Theme.px(3)
                        color: Theme.c.surface2
                        border.width: frame.active ? 2 : 1
                        border.color: frame.active ? Theme.c.red : Theme.c.outline
                        clip: true
                        z: frame.hovered ? 2 : (frame.active ? 1 : 0)
                        scale: fma.pressed ? 0.96 : (frame.hovered ? 1.14 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.ease } }
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                        Image {
                            anchors.fill: parent
                            visible: !frame.isCustom && !frame.isGlass
                            source: (frame.isCustom || frame.isGlass) ? ""
                                : "file://" + Wallpapers.dotWallpaperPathFor(frame.modelData.value)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.med } }
                        }

                        Image {
                            anchors.fill: parent
                            visible: frame.isCustom && win.hasCustomPic
                            source: frame.isCustom && win.hasCustomPic ? "file://" + Config.wallpaper : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.med } }
                        }

                        // The glass-filtered result, once scripts/glass-
                        // wallpaper.py has made one. Before that, or if
                        // it fails, the same empty-slot icon as Custom.
                        Image {
                            id: glassImg
                            anchors.fill: parent
                            visible: frame.isGlass
                            source: frame.isGlass ? "file://" + Wallpapers.glassOut : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.med } }
                        }

                        NIcon {
                            anchors.centerIn: parent
                            visible: (frame.isCustom && !win.hasCustomPic)
                                || (frame.isGlass && glassImg.status !== Image.Ready
                                    && !Wallpapers.glassBusy)
                            text: "󰉏"
                            size: Theme.px(20)
                            color: Theme.c.onDim
                        }

                        // No icon for "working" - the same plain label
                        // every other busy state in this shell uses.
                        NText {
                            anchors.centerIn: parent
                            visible: frame.isGlass && Wallpapers.glassBusy
                            text: "Working…"
                            color: Theme.c.onDim
                            font.pixelSize: Theme.f.tiny
                        }

                        // The frame number, printed the way a contact
                        // sheet's own negatives are - small, in the
                        // corner, out of the way of the picture itself.
                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: Theme.px(4)
                            text: "0" + (frame.index + 1)
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.family: Theme.f.mono
                            font.pixelSize: Theme.px(8)
                        }

                        MouseArea {
                            id: fma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.hoverChar = frame.modelData.value
                            onExited: if (win.hoverChar === frame.modelData.value) win.hoverChar = ""
                            onClicked: {
                                if (frame.isGlass) {
                                    GlobalState.wallpaperPickerOpen = false;
                                    Wallpapers.glassify(win.target);
                                } else if (frame.isCustom) {
                                    GlobalState.wallpaperPickerOpen = false;
                                    filePicker.running = true;
                                } else {
                                    Config.dotWallpaperChar = frame.modelData.value;
                                    Wallpapers.set(Wallpapers.dotWallpaperKey, win.target);
                                }
                            }
                        }
                    }
                }
            }

            // Sprocket holes: one strip of dots, printed twice (above
            // and below the frames) rather than shared, since an inline
            // local component this deeply nested isn't resolved by this
            // runtime.
            Item {
                id: perfBottom
                Layout.fillWidth: true
                implicitHeight: Theme.px(6)
                readonly property real pitch: Theme.px(13)
                readonly property int count: Math.max(2, Math.floor(width / pitch))

                Repeater {
                    model: perfBottom.count
                    Rectangle {
                        required property int index
                        readonly property real offset:
                            (perfBottom.width - perfBottom.count * perfBottom.pitch) / 2
                        width: Theme.px(5); height: Theme.px(5); radius: Theme.px(1)
                        x: offset + index * perfBottom.pitch
                        color: Theme.c.onFaint
                    }
                }
            }
        }

        // ── Which one this is ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            DisplayText {
                Layout.alignment: Qt.AlignHCenter
                text: (win.tiles.find(t => t.value === win.shownChar)?.label ?? "").toUpperCase()
                size: Theme.px(22)
            }
            NLabel {
                Layout.alignment: Qt.AlignHCenter
                text: (win.tiles.findIndex(t => t.value === win.shownChar) + 1)
                    + " of " + win.tiles.length
            }
        }
    }
}
