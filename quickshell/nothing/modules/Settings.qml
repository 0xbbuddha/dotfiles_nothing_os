import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Settings panel: glyph rail on the left, content on the right, all on a
// dot field.
//
// Page navigation is not enough: finding a setting means knowing which page
// it lives on. Search flattens every setting, then the matching row is
// brought into view and circled in red.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    property bool open: GlobalState.settingsOpen

    color: "transparent"
    visible: open && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-settings"
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // Glyphs are drawn here rather than taken from an icon font: it is the
    // only way to keep the same dot pitch as the rest of the panel. At 5x5
    // the patterns blurred together, hence 7x7.
    readonly property var pages: [
        { key: "look", label: "Appearance", glyph: [
            "0011100",
            "0111010",
            "1111001",
            "1111001",
            "1111001",
            "0111010",
            "0011100"] },
        { key: "panel", label: "Interface", glyph: [
            "1111111",
            "1111111",
            "1000001",
            "1000001",
            "1000001",
            "1000001",
            "1111111"] },
        { key: "essential", label: "Essential", glyph: [
            "0011100",
            "0110110",
            "1100011",
            "1100011",
            "1100011",
            "0110110",
            "0011100"] },
        { key: "dock", label: "Dock", glyph: [
            "0000000",
            "0000000",
            "0101010",
            "0101010",
            "0000000",
            "1111111",
            "0000000"] },
        { key: "net", label: "Network", glyph: [
            "1111111",
            "1000001",
            "0111110",
            "0100010",
            "0011100",
            "0000000",
            "0001000"] },
        { key: "game", label: "Game", glyph: [
            "0011100",
            "0011100",
            "1111111",
            "1111111",
            "1111111",
            "0011100",
            "0011100"] },
        { key: "about", label: "System", glyph: [
            "0001000",
            "0001000",
            "0000000",
            "0011000",
            "0001000",
            "0001000",
            "0011100"] }
    ]

    readonly property string query: search.text.trim()
    readonly property bool searching: win.query !== ""
    readonly property var results: SettingsIndex.search(win.query)

    // Jump to the setting designated by search and leave it circled for a
    // few seconds, long enough for the eye to find it on the page.
    function reveal(entry: var): void {
        stack.currentIndex = entry.page;
        search.clear();
        GlobalState.settingsFocus = entry.key;
        forget.restart();
    }

    Timer {
        id: forget
        interval: 3200
        onTriggered: GlobalState.settingsFocus = ""
    }

    // "escape" is refused as a method name: it is a JavaScript global.
    function dismiss(): void {
        if (win.searching) {
            search.clear();
            return;
        }
        GlobalState.settingsOpen = false;
    }

    onOpenChanged: {
        if (win.open) {
            search.clear();
            if (GlobalState.settingsPage >= 0) {
                stack.currentIndex = GlobalState.settingsPage;
                GlobalState.settingsPage = -1;
                forget.restart();
            } else {
                GlobalState.settingsFocus = "";
                search.takeFocus();
            }
            stack.playEnter();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.c.scrim
        MouseArea { anchors.fill: parent; onClicked: GlobalState.settingsOpen = false }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.dismiss()

        NCard {
            id: sheet
            anchors.centerIn: parent
            // The same box as the Nothing Launcher. They are the two
            // panels this desktop is configured from, and a settings sheet
            // two thirds the size of the launcher read as the lesser of
            // the two rather than its equal.
            width: Math.min(Theme.px(1240), parent.width - Theme.px(96))
            height: Math.min(Theme.px(860), parent.height - Theme.px(80))
            clip: true

            scale: win.visible ? 1 : 0.97
            Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

            DotField {
                id: trame
                anchors.fill: parent
                step: Theme.px(15)
                dotRadius: Theme.px(1)
                baseAlpha: 0.4
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Header ────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.pad
                    Layout.bottomMargin: Theme.px(10)
                    spacing: Theme.px(14)

                    ColumnLayout {
                        spacing: Theme.px(2)
                        NLabel { text: "N O T H I N G" }
                        NText {
                            text: "Settings"
                            font.pixelSize: Theme.px(30)
                            font.family: Theme.f.display
                        }
                    }

                    Item { Layout.preferredWidth: Theme.px(8) }

                    // ── Search ────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: Theme.px(380)
                        implicitHeight: Theme.px(34)
                        radius: Theme.r.pill
                        color: Theme.c.surface2
                        border.width: 1
                        border.color: win.searching ? Theme.c.red : Theme.c.outline
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(12)
                            anchors.rightMargin: Theme.px(8)
                            spacing: Theme.px(8)

                            NIcon {
                                text: "󰍉"
                                size: Theme.z.icon
                                color: win.searching ? Theme.c.red : Theme.c.onFaint
                            }

                            NField {
                                id: search
                                Layout.fillWidth: true
                                implicitWidth: 0
                                implicitHeight: Theme.px(30)
                                color: "transparent"
                                border.width: 0
                                placeholder: "Search every setting"
                                onSubmitted: {
                                    if (win.results.length > 0)
                                        win.reveal(win.results[0]);
                                }
                            }

                            CircleButton {
                                icon: "󰅖"
                                size: Theme.px(18)
                                visible: win.searching
                                onActivated: search.clear()
                            }
                        }
                    }

                    NLabel {
                        text: Time.hhmm
                        font.pixelSize: Theme.f.small
                    }

                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(26)
                        onActivated: GlobalState.settingsOpen = false
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // ── Navigation rail ───────────────────────────────
                    ColumnLayout {
                        // maximumWidth is required: without it the rail eats
                        // all space, the page stack having no implicit width
                        // (its children are Flickables).
                        Layout.preferredWidth: Theme.px(232)
                        Layout.maximumWidth: Theme.px(232)
                        Layout.fillHeight: true
                        Layout.margins: Theme.px(14)
                        spacing: Theme.px(3)

                        opacity: win.searching ? 0.35 : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                        Repeater {
                            model: win.pages

                            Rectangle {
                                id: nav
                                required property var modelData
                                required property int index
                                readonly property bool active: stack.currentIndex === index

                                Layout.fillWidth: true
                                implicitHeight: Theme.px(50)
                                radius: Theme.px(4)
                                color: nav.active ? Theme.c.surface2
                                     : (nma.containsMouse ? Theme.c.surface2 : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.fast } }

                                // A red rule down the edge, the same mark
                                // the launcher's rail uses. It replaced a
                                // breathing dot: with the rail three times
                                // wider the dot floated in space, and two
                                // panels marking the same idea two
                                // different ways is one idea too many.
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.px(2)
                                    height: nav.active ? Theme.px(24) : 0
                                    radius: 1
                                    color: Theme.c.red
                                    Behavior on height {
                                        NumberAnimation {
                                            duration: Theme.fast
                                            easing.type: Theme.ease
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(16)
                                    anchors.rightMargin: Theme.px(14)
                                    spacing: Theme.px(12)

                                    DotMatrix {
                                        Layout.alignment: Qt.AlignVCenter
                                        pattern: nav.modelData.glyph
                                        dot: Theme.px(2.5)
                                        gap: Theme.px(2)
                                        onColor: nav.active ? Theme.c.red : Theme.c.on
                                        offColor: Theme.c.onFaint
                                        offOpacity: 0.22
                                    }

                                    NText {
                                        Layout.fillWidth: true
                                        text: nav.modelData.label
                                        color: nav.active ? Theme.c.on : Theme.c.onDim
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: nma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (m) => {
                                        const p = nav.mapToItem(trame, m.x, m.y);
                                        trame.ripple(p.x, p.y);
                                        stack.currentIndex = nav.index;
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Shortcut to open the file by hand
                        NLabel {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.px(4)
                            text: "~/.config/nothing"
                            elide: Text.ElideLeft
                        }
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.c.outline }

                    // ── Content ───────────────────────────────────────
                    Item {
                        Layout.minimumWidth: Theme.px(320)
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StackLayout {
                            id: stack
                            anchors.fill: parent
                            visible: !win.searching
                            currentIndex: 0

                            function playEnter(): void {
                                const page = stack.children[stack.currentIndex];
                                if (page?.playEnter)
                                    page.playEnter();
                            }

                            SettingsPageLook {}
                            SettingsPagePanel {}
                            SettingsPageEssential {}
                                            SettingsPageDock {}
                            SettingsPageNet {}
                            SettingsPageGame {}
                            SettingsPageAbout {}
                        }

                        SettingsResults {
                            anchors.fill: parent
                            visible: win.searching
                            query: win.query
                            results: win.results
                            pages: win.pages
                            onChosen: (entry) => win.reveal(entry)
                        }
                    }
                }
            }
        }
    }
}
