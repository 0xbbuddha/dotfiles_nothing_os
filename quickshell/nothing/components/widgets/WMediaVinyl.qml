import QtQuick
import ".."
import "../.."
import "../../services"

// The cover on the record, turning while it plays and still the moment
// it does not, ringed by the mix itself rather than by a clock telling
// you how far in you are - Cava's own bars, bent around the disc, so
// what moves here is the music, not a progress readout.
//
// The disc face is drawn on a Canvas rather than cropped with a shader
// mask: a GPU mask effect here is what was crashing the process
// outright on this machine, and a hand-drawn circle is simpler than
// debugging someone else's shader anyway.
//
// No card: a record does not come with a square backing plate, and one
// drawn behind it just buried the cover in more black than the disc
// itself. This sits straight on the wallpaper, the way the bare clock
// and Quick Look faces already do.
Item {
    id: root
    readonly property bool empty: !Player.active
    readonly property bool hasArt: discFace.hasArt

    // Cava is a shared daemon - see services/Cava.qml - so this only
    // asks for it while there is something to show.
    readonly property bool wantsCava: Player.playing
    onWantsCavaChanged: Cava.widgetWantsIt = root.wantsCava
    Component.onCompleted: Cava.widgetWantsIt = root.wantsCava
    Component.onDestruction: Cava.widgetWantsIt = false

    Item {
        id: stage
        anchors.fill: parent
        readonly property real s: Math.min(width, height)

        Item {
            id: disc
            anchors.centerIn: parent
            width: stage.s * 0.62
            height: width

            Item {
                id: spinner
                anchors.fill: parent

                RotationAnimation {
                    target: spinner
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 7000
                    loops: Animation.Infinite
                    running: Player.playing
                }

                Canvas {
                    id: discFace
                    anchors.fill: parent
                    antialiasing: true
                    renderStrategy: Canvas.Cooperative

                    // Canvas keeps its own image cache reachable by URL,
                    // which sidesteps the whole "hide an Image item but
                    // still let Canvas read it" problem: an item Canvas
                    // grabs the rendered node for, and a rendered node
                    // with opacity 0 grabs as blank.
                    readonly property string artUrl: Player.artUrl

                    // Whether a given url is loaded is a plain function
                    // call, not a property - QML has nothing to watch
                    // there, so `hasArt` would freeze at whatever it saw
                    // the instant `artUrl` last changed, art loading
                    // asynchronously a moment later or not. `_tick` is
                    // read here only to give the binding something real
                    // to depend on; `onImageLoaded` bumping it is what
                    // makes the cover actually reappear on its own.
                    property int _tick: 0
                    readonly property bool hasArt: {
                        _tick;
                        return artUrl !== "" && isImageLoaded(artUrl);
                    }

                    property string _loaded: ""
                    onArtUrlChanged: {
                        // The active source can blink empty for a
                        // moment around a track change - a known quirk
                        // elsewhere in this shell too. Riding it out
                        // rather than reacting keeps the last cover on
                        // screen instead of flashing it to blank and
                        // back a second later.
                        if (artUrl === "" || artUrl === _loaded)
                            return;
                        _loaded = artUrl;
                        loadImage(artUrl);
                        _tick++;
                        requestPaint();
                    }
                    onImageLoaded: { _tick++; requestPaint(); }
                    Component.onCompleted: {
                        if (artUrl !== "") {
                            _loaded = artUrl;
                            loadImage(artUrl);
                        }
                    }

                    Connections {
                        target: Player
                        // Only a real stop clears the cover - not the
                        // transient empty artUrl above, but the player
                        // actually going away.
                        function onActiveChanged(): void {
                            if (!Player.active) {
                                discFace._loaded = "";
                                discFace._tick++;
                                discFace.requestPaint();
                            }
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width, h = height, r = w / 2;

                        ctx.save();
                        ctx.beginPath();
                        ctx.arc(r, r, r, 0, 2 * Math.PI);
                        ctx.clip();

                        ctx.fillStyle = Theme.c.surface;
                        ctx.fillRect(0, 0, w, h);
                        if (hasArt)
                            ctx.drawImage(artUrl, 0, 0, w, h);

                        // Grooves, over the cover rather than beside it:
                        // thin rings a shade darker than what is under
                        // them, so the art still reads as a record and
                        // not a sticker on one.
                        const n = root.hasArt ? 5 : 4;
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = root.hasArt
                            ? Qt.rgba(0, 0, 0, 0.22) : Theme.c.onFaint;
                        for (let i = 0; i < n; i++) {
                            const inset = Theme.px(7) + i * (w * 0.15);
                            const rr = Math.max(0, r - inset);
                            ctx.beginPath();
                            ctx.arc(r, r, rr, 0, 2 * Math.PI);
                            ctx.stroke();
                        }
                        ctx.restore();
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: root.hasArt ? Theme.px(7) : Theme.px(10)
                height: width
                radius: width / 2
                color: Theme.c.red
                z: 2
            }
        }

        // ── The mix, bent around the disc: Cava's own 25 bars, each
        // one a needle pointing out from the rim. Silent, they rest as
        // a low ring; playing, they are the one thing here that never
        // holds still. ─────────────────────────────────────────────────
        Canvas {
            id: bars
            anchors.fill: parent
            antialiasing: true
            renderStrategy: Canvas.Cooperative

            readonly property real baseR: disc.width / 2 + Theme.px(5)
            readonly property real maxLen: stage.s * 0.15
            readonly property real restLen: Theme.px(2)

            Connections {
                target: Cava
                function onValuesChanged(): void { bars.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2, cy = height / 2;
                const n = Cava.bars;
                const vals = Cava.values;
                const lineW = Math.max(1.4, stage.s * 0.014);
                ctx.lineCap = "round";
                ctx.lineWidth = lineW;

                for (let i = 0; i < n; i++) {
                    const v = (Cava.available && root.wantsCava)
                        ? (vals[i] ?? 0) : 0;
                    const len = bars.restLen + v * bars.maxLen;
                    const a = -Math.PI / 2 + i * (2 * Math.PI / n);
                    const ca = Math.cos(a), sa = Math.sin(a);
                    const x0 = cx + ca * bars.baseR;
                    const y0 = cy + sa * bars.baseR;
                    const x1 = cx + ca * (bars.baseR + len);
                    const y1 = cy + sa * (bars.baseR + len);

                    // White at rest, warming to the accent as a bar
                    // climbs - the ring's own VU meter, not a flat dot.
                    const t = Math.min(1, v * 1.3);
                    const r = Math.round(Theme.c.onDim.r * 255 * (1 - t) + Theme.c.red.r * 255 * t);
                    const g = Math.round(Theme.c.onDim.g * 255 * (1 - t) + Theme.c.red.g * 255 * t);
                    const b = Math.round(Theme.c.onDim.b * 255 * (1 - t) + Theme.c.red.b * 255 * t);
                    ctx.strokeStyle = `rgb(${r},${g},${b})`;

                    ctx.beginPath();
                    ctx.moveTo(x0, y0);
                    ctx.lineTo(x1, y1);
                    ctx.stroke();
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.empty
        cursorShape: Qt.PointingHandCursor
        onClicked: Player.playPause()
    }
}
