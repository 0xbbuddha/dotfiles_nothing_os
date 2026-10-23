import QtQuick
import ".."
import "../services"

// A clipboard image entry's actual picture, not its mime-type glyph:
// with more than one screenshot in history, two "Image" rows read
// identically until you paste the wrong one.
//
// cliphist only gives up the bytes through `cliphist decode <id>`, so
// this decodes once into a small per-id cache file under
// XDG_RUNTIME_DIR and shows that. A row whose decode hasn't finished
// yet, or failed, shows nothing and the caller's own glyph icon
// underneath keeps showing through - never a broken image, never a
// stale one: Clipboard.qml clears this whole cache at shell start and
// whenever an id is removed or the history is wiped, since cliphist
// can hand that same id number to different content later.
Item {
    id: root
    required property string clipId

    readonly property string path: `${Clipboard.thumbCacheDir}/${root.clipId}.png`
    property bool ready: false

    onClipIdChanged: { root.ready = false; decode.running = false; decode.running = true; }
    Component.onCompleted: decode.running = true

    NProcess {
        id: decode
        quiet: true
        label: "clip-thumb"
        // $1 = cache dir, $2 = id, both positional - never interpolated
        // into the script text, same rule as Clipboard.qml's own
        // decode script.
        command: ["sh", "-c",
            'd="$1"; i="$2"; mkdir -p "$d" && f="$d/$i.png"; '
            + '[ -s "$f" ] || cliphist decode "$i" >"$f" 2>/dev/null || rm -f "$f"; [ -s "$f" ]',
            "clip-thumb", Clipboard.thumbCacheDir, root.clipId]
        onExited: (code) => { root.ready = code === 0; }
    }

    Image {
        anchors.fill: parent
        visible: root.ready
        source: root.ready ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: Math.max(1, width)
        sourceSize.height: Math.max(1, height)
    }
}
