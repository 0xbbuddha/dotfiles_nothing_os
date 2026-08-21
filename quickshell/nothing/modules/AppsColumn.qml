import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/apps"
import "../services"

// Essential Apps pinned to the desktop. The rice's own widgets own the
// left column (Desktop.qml); generated apps live here, on the right, so
// a prompt gone wrong never disturbs the stock layout.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nothing-apps"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; right: true }
    implicitWidth: Theme.z.widgets + Theme.px(96)

    // Only the cards take clicks: an app has buttons, and the desktop
    // behind it has to stay reachable everywhere else.
    mask: Region { item: stack }

    readonly property var pinned: {
        MiniApps.stamp;
        const ids = Config.deskApps ?? [];
        const out = [];
        for (let i = 0; i < ids.length; i++) {
            const spec = MiniApps.specOf(ids[i]);
            if (spec)
                out.push(spec);
        }
        return out;
    }

    Column {
        id: stack
        x: Theme.px(48)
        y: Theme.px(62)
        width: Theme.z.widgets
        spacing: Theme.gap

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.med }
            NumberAnimation { property: "scale"; from: 0.92; to: 1
                              duration: Theme.med; easing.type: Theme.ease }
        }

        move: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.med; easing.type: Theme.ease }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.fast }
        }

        Repeater {
            model: win.pinned

            AppHost {
                required property var modelData
                width: stack.width
                spec: modelData
                chrome: true
                onEdited: {
                    GlobalState.appsFocus = modelData.id;
                    GlobalState.closeAll();
                    GlobalState.appsOpen = true;
                }
                onDropped: Config.removeDeskApp(modelData.id)
            }
        }
    }
}
