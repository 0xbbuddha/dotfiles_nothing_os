import QtQuick
import ".."
import "../.."
import "../../services"

// A clock dial, drawn in one pass on a canvas.
//
// The first version built the marks and the hands out of Rectangles, each
// carrying its own Rotation with an origin outside itself. That works on
// paper and is miserable in practice: every mark depends on the dial's
// size through three levels of binding, and anything that resizes mid
// layout leaves the face scrambled. Here the geometry is arithmetic in one
// function, which can be read, and got wrong only in one place.
Item {
    id: root

    // "ticks" = sixty marks, the minutes readable.
    // "dots"  = twelve dots, the hours only.
    property string face: "ticks"

    // Nothing ships its analogue clock with two sets of hands and no other
    // difference: "bold" is thick with rounded ends, "scale" is a pair of
    // hairlines with square ones. Compared side by side in their own
    // artwork that is the whole of it, and it changes the character of the
    // face completely.
    property string hands: "bold"

    readonly property int hh: parseInt(Time.hhmm.slice(0, 2)) || 0
    readonly property int mm: parseInt(Time.hhmm.slice(3, 5)) || 0

    onHhChanged: canvas.requestPaint()
    onMmChanged: canvas.requestPaint()
    onFaceChanged: canvas.requestPaint()
    onHandsChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const w = width, h = height;
            const r = Math.min(w, h) / 2;
            if (r <= 4)
                return;
            const cx = w / 2, cy = h / 2;

            // Straight up is -90 degrees in canvas terms; every angle below
            // is measured from there, so noon is noon.
            const at = (deg, dist) => [
                cx + Math.cos((deg - 90) * Math.PI / 180) * dist,
                cy + Math.sin((deg - 90) * Math.PI / 180) * dist
            ];

            if (root.face === "dots") {
                for (let i = 0; i < 12; i++) {
                    const quarter = i % 3 === 0;
                    const [x, y] = at(i * 30, r - Theme.px(7));
                    ctx.beginPath();
                    ctx.arc(x, y, quarter ? Theme.px(3) : Theme.px(2), 0, Math.PI * 2);
                    ctx.fillStyle = quarter ? Theme.c.on : Theme.c.onFaint;
                    ctx.fill();
                }
            } else {
                ctx.lineCap = "round";
                for (let i = 0; i < 60; i++) {
                    const onHour = i % 5 === 0;
                    const len = onHour ? Theme.px(7) : Theme.px(3);
                    const [x1, y1] = at(i * 6, r - Theme.px(3));
                    const [x2, y2] = at(i * 6, r - Theme.px(3) - len);
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(x2, y2);
                    ctx.lineWidth = onHour ? Theme.px(2) : Theme.px(1);
                    ctx.strokeStyle = onHour ? Theme.c.on : Theme.c.onFaint;
                    ctx.stroke();
                }
            }

            const bold = root.hands !== "scale";
            const hand = (deg, len, wide, colour) => {
                const [x, y] = at(deg, len);
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(x, y);
                ctx.lineWidth = wide;
                ctx.lineCap = bold ? "round" : "butt";
                ctx.strokeStyle = colour;
                ctx.stroke();
            };

            // The hour hand carries the minutes too, so it creeps between
            // the marks the way a real one does.
            hand((root.hh % 12) * 30 + root.mm * 0.5, r * 0.5,
                 bold ? Theme.px(6) : Theme.px(2), Theme.c.on);
            hand(root.mm * 6, r * 0.76,
                 bold ? Theme.px(4) : Theme.px(2),
                 root.face === "dots" ? Theme.c.red : Theme.c.on);

            // The scale face has no cap: a disc at the centre would be the
            // heaviest thing on a dial made of hairlines.
            if (bold) {
                ctx.beginPath();
                ctx.arc(cx, cy, Theme.px(3.5), 0, Math.PI * 2);
                ctx.fillStyle = Theme.c.red;
                ctx.fill();
            }
        }
    }
}
