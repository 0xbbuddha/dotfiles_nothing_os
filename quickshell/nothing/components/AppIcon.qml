import QtQuick
import Quickshell
import ".."
import "../services"

// Nothing pack: Lawnicons glyphs (white on black squircle), the real
// phone pack look. Other packs keep the theme icons.
Item {
    id: root
    property string appId: ""
    property string iconName: ""
    property real size: Theme.z.dockIcon
    property bool tinted: false

    implicitWidth: size
    implicitHeight: size

    readonly property bool nothingPack: (Config.iconTheme || "Nothing") === "Nothing"

    readonly property var candidates: {
        const urls = [];
        const seen = {};
        const add = u => {
            if (!u || seen[u])
                return;
            seen[u] = true;
            urls.push(u);
        };
        const addPack = n => {
            if (!root.nothingPack || !n)
                return;
            const ps = Icons.packPathsFor(n);
            for (let i = 0; i < ps.length; i++)
                add(ps[i]);
        };
        void Icons.catalog;
        void Icons.named;

        addPack(root.appId);
        if (root.iconName !== "") {
            const n = root.iconName;
            if (n.startsWith("image://") || n.startsWith("qrc:")) {
                add(n);
                return urls;
            }
            addPack(n);
            if (n.includes("://") || n.startsWith("/")) {
                if (!root.nothingPack)
                    add(n.startsWith("/") ? "file://" + n : n);
            } else {
                const p = Quickshell.iconPath(n, true);
                if (p && p !== "") {
                    const url = Apps.toImageUrl(p);
                    if (!root.nothingPack || url.indexOf("/icons/Nothing/") >= 0)
                        add(url);
                }
            }
            return urls;
        }
        const names = Apps.iconNames(root.appId);
        for (let i = 0; i < names.length; i++)
            addPack(names[i]);
        if (root.nothingPack)
            return urls;
        const rest = Apps.iconCandidates(root.appId);
        for (let j = 0; j < rest.length; j++)
            add(rest[j]);
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
        cache: false
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

        Text {
            anchors.centerIn: parent
            text: (Apps.nameFor(root.appId)[0] ?? "?").toUpperCase()
            color: Theme.c.on
            font.family: Theme.f.sans
            font.pixelSize: root.size * 0.55
        }
    }
}
