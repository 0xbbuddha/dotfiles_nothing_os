import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"

// SUPER+SHIFT+T: pick one of the three characters this rice ships with,
// or browse to a picture of your own.
//
// No folder grid, no slideshow: this used to list every picture in the
// wallpaper folder as a thumbnail wall, which fought the three bundled
// characters for the same space. One picture is one click away through
// the file's own picker (zenity, same as Settings > Appearance), which
// needs no folder to scan and no thumbnails to decode.
OverlayWindow {
    id: win
    open: GlobalState.wallpaperPickerOpen
    onCloseRequested: GlobalState.wallpaperPickerOpen = false
    sheetWidth: Math.min(Theme.px(900), screen.width * 0.9)
    sheetHeight: col.implicitHeight + Theme.pad * 2
    // Low and out of the way, no scrim: the choice plays out as the
    // reveal on the wallpaper itself, which the sheet must not hide.
    topBias: 0.85
    scrim: "transparent"

    // "" = every screen, else a connector name.
    property string target: ""
    readonly property var screenNames: Quickshell.screens.map(s => s.name)

    readonly property bool dotsActive:
        win.target === "" ? Config.wallpaper === Wallpapers.dotWallpaperKey
                           : Wallpapers.isCurrent(Wallpapers.dotWallpaperKey, win.target)

    // The house texture, barely there - the same field the settings
    // sheet and the lock screen use, so this reads as part of the same
    // desktop rather than a plain dialog dropped on top of it.
    DotField {
        anchors.fill: parent
        dotColor: Theme.c.onFaint
        opacity: 0.3
    }

    // The file's own picker, not a path typed anywhere: same as
    // Settings > Appearance's "Browse".
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

        // ── Header: for which screen, how ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(10)

            ColumnLayout {
                spacing: Theme.px(2)
                DisplayText { text: "WALLPAPER"; size: Theme.px(22) }
                NText { text: "A character, or a picture of your own"; color: Theme.c.onDim; font.pixelSize: Theme.f.small }
            }

            Item { Layout.fillWidth: true }

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(110) * (win.screenNames.length + 1)
                visible: win.screenNames.length > 1
                options: [{ label: "All screens", value: "" }]
                    .concat(win.screenNames.map(n => ({ label: n, value: n })))
                current: win.target
                onPicked: (v) => win.target = v
            }

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.px(130)
                options: [{ label: "Crop", value: "crop" }, { label: "Fit", value: "fit" }]
                current: Config.wallpaperFill
                onPicked: (v) => { Config.wallpaperFill = v; Config.save(); }
            }

            CircleButton {
                icon: "󰅖"
                size: Theme.px(26)
                onActivated: win.requestClose()
            }
        }

        // ── Characters, plus "your own" ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(14)

            Repeater {
                model: Wallpapers.dotWallpaperChars

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool active:
                        win.dotsActive && Config.dotWallpaperChar === card.modelData.value

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(250)
                    radius: Theme.r.panel
                    color: Theme.c.surface2
                    border.width: card.active ? 2 : 0
                    border.color: Theme.c.red
                    clip: true
                    scale: dma.pressed ? 0.98 : (dma.containsMouse ? 1.02 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                    Behavior on border.width { NumberAnimation { duration: Theme.fast } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + Wallpapers.dotWallpaperPathFor(card.modelData.value, true)
                        sourceSize.width: Theme.px(560)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: card.active || dma.containsMouse ? 1 : 0.68
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.px(64)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                        }
                    }

                    // A small index tag in the house dot-matrix font - the
                    // same numbering habit the Glyph Interface itself uses.
                    DisplayText {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.px(10)
                        text: "0" + (card.index + 1)
                        size: Theme.px(14)
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }

                    DisplayText {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.px(14)
                        text: card.modelData.label.toUpperCase()
                        size: Theme.px(16)
                        color: "white"
                    }

                    // Opposite corner from the index tag, clear of the
                    // name label at the bottom.
                    Rectangle {
                        visible: card.active
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: Theme.px(10)
                        width: Theme.px(22); height: width; radius: width / 2
                        color: Theme.c.red
                        NText {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: Theme.f.small
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: dma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.dotWallpaperChar = card.modelData.value;
                            Wallpapers.set(Wallpapers.dotWallpaperKey, win.target);
                        }
                    }
                }
            }

            // ── Your own picture ─────────────────────────────────────
            Rectangle {
                id: customCard
                readonly property bool active: !win.dotsActive

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(250)
                radius: Theme.r.panel
                color: customCard.active ? Theme.c.surface2 : "transparent"
                border.width: customCard.active ? 2 : 1
                border.color: customCard.active ? Theme.c.red : Theme.c.outline
                Behavior on border.width { NumberAnimation { duration: Theme.fast } }
                scale: cma.pressed ? 0.98 : (cma.containsMouse ? 1.02 : 1)
                Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.px(10)
                    NIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰉏"
                        size: Theme.px(30)
                        color: customCard.active ? Theme.c.on : Theme.c.onDim
                    }
                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Your picture"
                        color: customCard.active ? Theme.c.on : Theme.c.onDim
                        font.pixelSize: Theme.f.body
                    }
                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: customCard.active
                        text: "Currently set"
                        color: Theme.c.red
                        font.pixelSize: Theme.f.tiny
                    }
                }

                MouseArea {
                    id: cma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: filePicker.running = true
                }
            }
        }
    }
}
