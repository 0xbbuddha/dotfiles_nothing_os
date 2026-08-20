pragma Singleton

import QtQuick
import Quickshell

// Shared state between shell windows (each is a distinct Wayland
// window; they cannot reference each other directly).
Singleton {
    property bool settingsOpen: false

    // Key of the setting to highlight in the panel, set by search. A row
    // cannot be targeted otherwise: pages are logical windows distinct
    // from the search field.
    property string settingsFocus: ""

    property bool controlCenterOpen: false
    property bool launcherOpen: false

    // Pre-filled query when the launcher opens: used by shortcuts that
    // jump straight into a mode (clipboard, emoji, calculator...).
    property string launcherQuery: ""

    // Opens the launcher on a prefix, or closes it if already there.
    function launchWith(query: string): void {
        if (launcherOpen && launcherQuery === query) {
            launcherOpen = false;
            return;
        }
        launcherQuery = query;
        launcherOpen = true;
    }
    property bool sessionOpen: false
    property bool notifCenterOpen: false
    property bool screenshotOpen: false
    property bool gameBarOpen: false
    property string gameSelected: ""
    property bool cheatsheetOpen: false
    property bool essentialOpen: false
    property bool essentialPulse: false
    property string essentialFlyPath: ""
    property string essentialFlyScreen: ""
    property bool essentialCatching: false
    property bool polkitOpen: false
    property string netPanel: ""
    property bool audioPanel: false
    property bool lightPanel: false

    function openNet(kind: string): void {
        controlCenterOpen = false;
        audioPanel = false;
        lightPanel = false;
        netPanel = (netPanel === kind) ? "" : kind;
    }

    function openAudio(): void {
        controlCenterOpen = false;
        netPanel = "";
        lightPanel = false;
        audioPanel = !audioPanel;
    }

    function openLight(): void {
        controlCenterOpen = false;
        netPanel = "";
        audioPanel = false;
        lightPanel = !lightPanel;
    }

    function toggleSettings(): void { settingsOpen = !settingsOpen; }
    function toggleLauncher(): void {
        launcherQuery = "";
        launcherOpen = !launcherOpen;
    }

    function closeAll(): void {
        settingsOpen = false;
        launcherOpen = false;
        sessionOpen = false;
        notifCenterOpen = false;
        screenshotOpen = false;
        gameSelected = "";
        cheatsheetOpen = false;
        essentialOpen = false;
        netPanel = "";
        audioPanel = false;
        lightPanel = false;
    }
}
