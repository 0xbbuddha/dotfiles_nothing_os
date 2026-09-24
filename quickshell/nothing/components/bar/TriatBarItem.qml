import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../.."
import ".."
import "../../services"

// Triat dans la barre : le logo en points, et le titre en cours quand
// l'application tourne. Posé par Musicapp/packaging/nothing-os/install.sh.
//
//   clic gauche   ouvre le panneau de lecture (pochette, commandes)
//   clic milieu   lecture / pause
//   clic droit    piste suivante
//   molette       suivante / précédente
Item {
    id: root

    // Le lecteur MPRIS de Triat, repéré par son nom de bus.
    readonly property var player: Player.all.find(
        p => (p?.dbusName ?? "").indexOf("MediaPlayer2.triat") !== -1) ?? null
    readonly property bool running: player !== null
    readonly property bool playing: Player.isPlaying(player)
    readonly property string title: running ? Player.titleOf(player) : ""
    readonly property string artist: player?.trackArtist ?? ""

    Layout.alignment: Qt.AlignVCenter
    Layout.maximumWidth: Theme.px(180)
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, Theme.px(16))

    // Le logo : trois points en triangle de lecture. La pointe rougit
    // pendant la lecture, comme l'icône de l'application.
    component LogoMark: Item {
        property real dot: Theme.px(4)
        property bool live: false
        implicitWidth: dot * 3.2
        implicitHeight: dot * 3.4
        Rectangle { x: 0; y: 0; width: parent.dot; height: width; radius: width / 2
                    color: Theme.c.on }
        Rectangle { x: 0; y: parent.height - parent.dot; width: parent.dot; height: width
                    radius: width / 2; color: Theme.c.on }
        Rectangle { x: parent.width - parent.dot; y: (parent.height - parent.dot) / 2
                    width: parent.dot; height: width; radius: width / 2
                    color: parent.live ? "#d71921" : Theme.c.onDim
                    Behavior on color { ColorAnimation { duration: Theme.fast } } }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(7)

        LogoMark {
            anchors.verticalCenter: parent.verticalCenter
            live: root.playing
        }

        NText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Theme.px(150))
            text: root.running && root.title !== "" ? root.title : "Triat"
            color: root.running ? Theme.c.on : Theme.c.onDim
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -Theme.px(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: (m) => {
            if (m.button === Qt.MiddleButton) {
                if (root.running) Player.playPause(root.player);
                else Quickshell.execDetached(["triat", "--play-pause"]);
            } else if (m.button === Qt.RightButton) {
                if (root.running) Player.next(root.player);
            } else {
                panel.visible = !panel.visible;
            }
        }
        onWheel: (w) => {
            if (!root.running) return;
            if (w.angleDelta.y < 0) Player.next(root.player);
            else Player.previous(root.player);
        }
    }

    Tooltip {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: Theme.px(8)
        text: root.running
            ? ((root.artist !== "" ? root.artist + " · " : "")
               + "clic : ouvrir · milieu : pause · droit : suivante")
            : "Ouvrir Triat"
        shown: ma.containsMouse && !panel.visible
        enabled: false
    }

    // `qs ipc call triat panel` : ouvre le panneau depuis un raccourci.
    // Une barre par écran : seule celle de l'écran actif répond.
    IpcHandler {
        target: "triat"
        enabled: root.QsWindow.window?.screen?.name
                 === Hyprland.focusedMonitor?.name
        function panel(): void { panel.visible = !panel.visible; }
    }

    function openApp(): void {
        panel.visible = false;
        // Ouvre Triat, ou le ramène : l'instance ouverte se donne
        // elle-même le focus sous Hyprland (core/desktop.py).
        Quickshell.execDetached(["triat"]);
    }

    function clock(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ── Panneau de lecture ───────────────────────────────────────────
    // Sous le module, dans le style des panneaux du shell. Se referme au
    // clic à l'extérieur (grabFocus).
    PopupWindow {
        id: panel
        visible: false
        grabFocus: true
        color: "transparent"
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: Theme.px(12)
        implicitWidth: Theme.px(320)
        implicitHeight: card.implicitHeight

        Rectangle {
            id: card
            anchors.fill: parent
            implicitHeight: body.implicitHeight + Theme.px(28)
            radius: Theme.r.chip
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.outline

            Column {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.px(14)
                spacing: Theme.px(12)

                // Piste : pochette, titre, artiste
                Row {
                    width: parent.width
                    spacing: Theme.px(12)

                    Rectangle {
                        width: Theme.px(56)
                        height: width
                        radius: Theme.px(4)
                        color: Theme.c.surface2
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        LogoMark {
                            anchors.centerIn: parent
                            visible: (root.player?.trackArtUrl ?? "") === ""
                            dot: Theme.px(9)
                            live: root.playing
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.px(68)
                        spacing: Theme.px(3)
                        NText {
                            width: parent.width
                            text: root.running ? (root.title || "Rien en lecture")
                                               : "Triat est fermé"
                            color: Theme.c.on
                            font.pixelSize: Theme.f.body
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        NText {
                            width: parent.width
                            text: root.running ? root.artist
                                               : "La musique reprend où elle s'était arrêtée."
                            color: Theme.c.onDim
                            font.pixelSize: Theme.f.small
                            elide: Text.ElideRight
                            wrapMode: root.running ? Text.NoWrap : Text.WordWrap
                        }
                    }
                }

                // Progression, cliquable pour avancer
                Column {
                    width: parent.width
                    spacing: Theme.px(5)
                    visible: root.running && Player.lengthOf(root.player) > 0

                    Item {
                        width: parent.width
                        height: Theme.px(10)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: Theme.px(3)
                            radius: height / 2
                            color: Theme.c.surface3
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * Player.progressOf(root.player)
                            height: Theme.px(3)
                            radius: height / 2
                            color: root.playing ? Theme.c.red : Theme.c.on
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (m) => Player.seek(m.x / width, root.player)
                        }
                    }
                    Row {
                        width: parent.width
                        NText {
                            width: parent.width / 2
                            text: root.clock(Player.positionOf(root.player))
                            color: Theme.c.onDim
                            font.family: Theme.f.mono
                            font.pixelSize: Theme.f.tiny
                        }
                        NText {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignRight
                            text: root.clock(Player.lengthOf(root.player))
                            color: Theme.c.onDim
                            font.family: Theme.f.mono
                            font.pixelSize: Theme.f.tiny
                        }
                    }
                }

                // Transport
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.px(14)
                    visible: root.running

                    Repeater {
                        model: [
                            { glyph: "󰒮", big: false, act: () => Player.previous(root.player) },
                            { glyph: root.playing ? "󰏤" : "󰐊", big: true,
                              act: () => Player.playPause(root.player) },
                            { glyph: "󰒭", big: false, act: () => Player.next(root.player) }
                        ]
                        Rectangle {
                            required property var modelData
                            width: modelData.big ? Theme.px(40) : Theme.px(32)
                            height: width
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.big ? Theme.c.on
                                 : (btn.containsMouse ? Theme.c.surface3 : "transparent")
                            NIcon {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                size: modelData.big ? Theme.px(16) : Theme.px(13)
                                color: modelData.big ? Theme.c.surface : Theme.c.on
                            }
                            MouseArea {
                                id: btn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.act()
                            }
                        }
                    }
                }

                // Actions : ouvrir la fenêtre, quitter pour de bon
                Row {
                    width: parent.width
                    spacing: Theme.px(8)

                    Rectangle {
                        width: root.running ? (parent.width - Theme.px(8)) * 0.62 : parent.width
                        height: Theme.px(30)
                        radius: height / 2
                        color: openMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                        NText {
                            anchors.centerIn: parent
                            text: "Ouvrir Triat"
                            color: Theme.c.on
                            font.pixelSize: Theme.f.small
                        }
                        MouseArea {
                            id: openMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openApp()
                        }
                    }
                    Rectangle {
                        visible: root.running
                        width: (parent.width - Theme.px(8)) * 0.38
                        height: Theme.px(30)
                        radius: height / 2
                        color: quitMa.containsMouse ? Theme.c.surface3 : "transparent"
                        border.width: 1
                        border.color: Theme.c.outline
                        NText {
                            anchors.centerIn: parent
                            text: "Quitter"
                            color: Theme.c.onDim
                            font.pixelSize: Theme.f.small
                        }
                        MouseArea {
                            id: quitMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                panel.visible = false;
                                Quickshell.execDetached(
                                    ["gapplication", "action", "org.triat.Triat", "quit"]);
                            }
                        }
                    }
                }
            }
        }
    }
}
