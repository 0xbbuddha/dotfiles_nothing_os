import QtQuick
import Quickshell
import ".."
import "../services"

// Whatever icon theme GTK / Qt are set to. The shell no longer ships or
// builds a pack of its own: it just resolves the name through the system
// theme and falls back to the app's initial when nothing is found.
Item {
    id: root
    property string appId: ""
    property string iconName: ""
    property real size: Theme.z.dockIcon

    implicitWidth: size
    implicitHeight: size

    readonly property var candidates: {
        const urls = [];
        const seen = {};
        const add = u => {
            if (!u || seen[u])
                return;
            seen[u] = true;
            urls.push(u);
        };

        if (root.iconName !== "") {
            const n = root.iconName;
            // Pixmaps handed over by the tray or a notification: already an
            // image, nothing to look up.
            if (n.startsWith("image://") || n.startsWith("qrc:")) {
                add(n);
                return urls;
            }
            if (n.includes("://") || n.startsWith("/")) {
                add(Apps.toImageUrl(n));
            } else {
                const p = Quickshell.iconPath(n, true);
                if (p)
                    add(Apps.toImageUrl(p));
            }
        }

        // The name may be missing or wrong (SNI ids in particular), so the
        // .desktop entry is always tried as well, never instead.
        const rest = Apps.iconCandidates(root.appId);
        for (let i = 0; i < rest.length; i++)
            add(rest[i]);
        return urls;
    }

    property int candIndex: 0

    onAppIdChanged: candIndex = 0
    onIconNameChanged: candIndex = 0
    onCandidatesChanged: candIndex = 0

    readonly property string resolved: {
        const c = root.candidates;
        if (!c || root.candIndex >= c.length)
            return "";
        return c[root.candIndex] ?? "";
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.resolved
        sourceSize.width: Math.max(64, Math.round(root.size * 2))
        sourceSize.height: Math.max(64, Math.round(root.size * 2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready

        onStatusChanged: {
            if (status !== Image.Error)
                return;
            if (root.candIndex < root.candidates.length - 1)
                root.candIndex++;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.size * 0.28
        color: Theme.c.surface3
        visible: root.resolved === "" || img.status !== Image.Ready

        NText {
            anchors.centerIn: parent
            text: (Apps.nameFor(root.appId)[0] ?? "?").toUpperCase()
            font.pixelSize: root.size * 0.55
        }
    }
}
