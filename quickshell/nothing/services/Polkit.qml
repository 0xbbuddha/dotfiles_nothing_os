pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import ".."

// PolicyKit authentication agent.
// With no registered agent, every privilege-elevation request fails
// silently: graphical package manager, disk mount, system settings.
// Quickshell provides the implementation; we only write the UI.
Singleton {
    id: root

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null
    readonly property bool registered: agent.isRegistered

    // polkit's message often ends with a period; strip it to show it as
    // a title.
    readonly property string message: {
        const m = root.flow?.message ?? "";
        return m.endsWith(".") ? m.slice(0, -1) : m;
    }

    readonly property string prompt: {
        const p = (root.flow?.inputPrompt ?? "").trim();
        // polkit returns "Password: " or "Mot de passe : " depending on locale
        return p.replace(/\s*:\s*$/, "");
    }

    readonly property bool hidden: !(root.flow?.responseVisible ?? false)
    readonly property string note: root.flow?.supplementaryMessage ?? ""
    readonly property bool noteIsError: root.flow?.supplementaryIsError ?? false
    readonly property string actionId: root.flow?.actionId ?? ""
    readonly property var identities: root.flow?.identities ?? []

    signal succeeded()
    signal failed()

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: GlobalState.polkitOpen = true
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onAuthenticationSucceeded(): void {
            GlobalState.polkitOpen = false;
            root.succeeded();
        }
        function onAuthenticationFailed(): void { root.failed(); }
        function onAuthenticationRequestCancelled(): void {
            GlobalState.polkitOpen = false;
        }
    }

    function submit(password: string): void {
        root.flow?.submit(password);
    }

    function cancel(): void {
        root.flow?.cancelAuthenticationRequest();
        GlobalState.polkitOpen = false;
    }

    function pickIdentity(identity: var): void {
        if (root.flow) root.flow.selectedIdentity = identity;
    }
}
