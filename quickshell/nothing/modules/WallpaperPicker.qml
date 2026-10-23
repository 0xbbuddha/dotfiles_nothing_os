import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../services"

// SUPER+SHIFT+T: every wallpaper choice in one place, one click each.
//
//   - which screen it is for: all of them, or one (each screen keeps its
//     own picture, the ultrawide and the 16:9 no longer share a crop)
//   - the two Nothing dot figures, then your pictures: the wallpaper
//     folder first, then Pictures, newest first, as thumbnails
//   - crop or fit, and the slideshow from the folder
//
// No path to type anywhere. SUPER+ALT+W is "next", and Dolphin's context
// menu has "Set as wallpaper" (applications/servicemenus/).
OverlayWindow {
    id: win
    open: GlobalState.wallpaperPickerOpen
    onCloseRequested: GlobalState.wallpaperPickerOpen = false
    sheetWidth: Math.min(Theme.px(980), screen.width * 0.92)
    sheetHeight: Math.min(col.implicitHeight + Theme.pad * 2, screen.height * 0.9)
    // Low and out of the way, no scrim: the choice plays out as the
    // reveal on the wallpaper itself, which the sheet must not hide.
    topBias: 0.85
    scrim: "transparent"

    // "" = every screen, else a connector name.
    property string target: ""
    readonly property var screenNames: Quickshell.screens.map(s => s.name)

    onOpenChanged: if (win.open) Walls.refresh()

    function apply(value: string): void {
        Wallpapers.set(value, win.target);
    }

    function current(value: string): bool {
        return win.target === "" ? Config.wallpaper === value
                                 : Wallpapers.isCurrent(value, win.target);
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        // ── Header: for which screen, how, next ──────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(10)

            DisplayText { text: "WALLPAPER"; size: Theme.px(22) }

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(110) * (win.screenNames.length + 1)
                visible: win.screenNames.length > 1
                options: [{ label: "All screens", value: "" }]
                    .concat(win.screenNames.map(n => ({ label: n, value: n })))
                current: win.target
                onPicked: (v) => win.target = v
            }

            Item { Layout.fillWidth: true }

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(130)
                options: [{ label: "Crop", value: "crop" }, { label: "Fit", value: "fit" }]
                current: Config.wallpaperFill
                onPicked: (v) => { Config.wallpaperFill = v; Config.save(); }
            }

            NPillButton {
                text: "Next"
                visible: Walls.folderFiles.length > 0
                onActivated: Wallpapers.next()
            }

            CircleButton {
                icon: "󰅖"
                size: Theme.px(26)
                onActivated: win.requestClose()
            }
        }

        // ── Nothing figures ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(10)

            Repeater {
                model: Wallpapers.dotWallpaperChars

                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool active:
                        win.current(Wallpapers.dotWallpaperKey)
                        && Config.dotWallpaperChar === card.modelData.value

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(110)
                    radius: Theme.r.panel
                    color: Theme.c.surface2
                    border.width: card.active ? 2 : 0
                    border.color: Theme.c.red
                    clip: true
                    scale: dma.pressed ? 0.98 : (dma.containsMouse ? 1.015 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + Wallpapers.dotWallpaperPathFor(card.modelData.value, true)
                        sourceSize.width: Theme.px(480)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.px(40)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(6)
                        Rectangle {
                            visible: card.active
                            width: Theme.px(6); height: width; radius: width / 2
                            color: Theme.c.red
                        }
                        DisplayText { text: card.modelData.label.toUpperCase(); size: Theme.px(14); color: "white" }
                    }

                    MouseArea {
                        id: dma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.dotWallpaperChar = card.modelData.value;
                            win.apply(Wallpapers.dotWallpaperKey);
                        }
                    }
                }
            }
        }

        // ── Your pictures ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            NLabel { text: "Your pictures" }
            NLabel { text: "· " + Walls.files.length; opacity: 0.6 }
            Item { Layout.fillWidth: true }
            NLabel {
                text: Walls.folder.replace(Walls.home, "~")
            }
            NPillButton {
                text: "Open folder"
                onActivated: Quickshell.execDetached(["sh", "-c", 'mkdir -p -- "$1" && xdg-open "$1"',
                                                      "wallpaper-folder", Walls.folder])
            }
            CircleButton {
                icon: "󰑐"
                size: Theme.px(22)
                onActivated: Walls.refresh()
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Theme.px(380),
                Math.ceil(Math.max(1, count) / 5) * cellHeight)
            visible: count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / 5
            cellHeight: cellWidth * 9 / 16
            model: Walls.files

            delegate: Item {
                id: thumb
                required property string modelData
                readonly property bool active: win.current(thumb.modelData)
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.px(3)
                    radius: Theme.r.tiny
                    color: Theme.c.surface2
                    border.width: thumb.active ? 2 : 0
                    border.color: Theme.c.red
                    clip: true
                    scale: tma.containsMouse ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.fast } }

                    // Decoded small: 300 full-size photos would be
                    // gigabytes; at this size the grid is a few MB.
                    Image {
                        anchors.fill: parent
                        anchors.margins: thumb.active ? 2 : 0
                        source: "file://" + thumb.modelData
                        sourceSize.width: Theme.px(320)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.px(20)
                        visible: tma.containsMouse
                        color: Qt.rgba(0, 0, 0, 0.65)
                        NText {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(6)
                            verticalAlignment: Text.AlignVCenter
                            text: thumb.modelData.split("/").pop()
                            elide: Text.ElideMiddle
                            font.pixelSize: Theme.f.tiny
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: tma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.apply(thumb.modelData)
                    }
                }
            }
        }

        NText {
            Layout.fillWidth: true
            visible: grid.count === 0
            wrapMode: Text.WordWrap
            color: Theme.c.onDim
            text: Walls.scanning ? "Looking for pictures…"
                : "No pictures yet. Put some in " + Walls.folder.replace(Walls.home, "~")
                  + " (Open folder), or pick another folder in Settings > Appearance."
        }

        // ── Slideshow ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: Walls.folderFiles.length > 1
            spacing: Theme.px(10)

            NLabel { text: "Change every" }
            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(330)
                options: [
                    { label: "Never", value: 0 },
                    { label: "15 min", value: 15 },
                    { label: "1 h", value: 60 },
                    { label: "1 day", value: 1440 }
                ]
                current: Config.wallpaperRotate
                onPicked: (v) => { Config.wallpaperRotate = v; Config.save(); }
            }
            Item { Layout.fillWidth: true }
            NText { text: "Shuffle"; color: Theme.c.onDim; font.pixelSize: Theme.f.small }
            NSwitch {
                checked: Config.wallpaperShuffle
                onToggled: (v) => { Config.wallpaperShuffle = v; Config.save(); }
            }
            NText {
                visible: win.screenNames.length > 1
                text: "Different per screen"
                color: Theme.c.onDim
                font.pixelSize: Theme.f.small
            }
            NSwitch {
                visible: win.screenNames.length > 1
                checked: Config.wallpaperEachScreen
                onToggled: (v) => { Config.wallpaperEachScreen = v; Config.save(); }
            }
        }
    }
}
