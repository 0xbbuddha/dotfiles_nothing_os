import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/apps"
import "../services"

// Essential Apps pinned to the desktop, as a homescreen of tiles.
// Stock widgets keep the left column; these sit on the right.
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

    mask: Region { item: grid }

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

    Flow {
        id: grid
        x: Theme.px(48)
        y: Theme.px(62)
        width: Theme.z.widgets
        spacing: Theme.gap

        // Only the session-launch case: the Flow populating for the
        // first time. Tiles pinned afterward from Essential Apps just
        // appear, same as before.
        populate: Transition {
            SequentialAnimation {
                // See Desktop.qml's copy of this: index has come back
                // -1 here before, and a negative duration is a hard Qt
                // warning rather than something it clamps for itself.
                PauseAnimation { duration: Math.max(0, ViewTransition.index) * 45 }
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.med }
                    NumberAnimation { property: "scale"; from: 0.92; to: 1
                                      duration: Theme.med; easing.type: Theme.ease }
                }
            }
        }

        Repeater {
            model: win.pinned

            AppHost {
                required property var modelData
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
