#version 440

// Settings-panel dot field, with a wave that starts from the point
// touched on a page change.
//
// As Rectangles it would need one object per dot, nearly 3000 on the
// sheet. Here it all fits in one fragment.
//
// Recompile after editing:
//   /usr/lib/qt6/bin/qsb --glsl 100es,120,150 --hlsl 50 --msl 12 \
//       -o dotfield.frag.qsb dotfield.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 dotColor;
    vec2 res;
    vec2 waveOrigin;
    float spacing;
    float radius;
    float waveTime;
    float baseAlpha;
};

void main() {
    vec2 px = qt_TexCoord0 * res;

    // Distance to the centre of the current grid cell.
    vec2 cell = mod(px, spacing) - spacing * 0.5;
    float disc = 1.0 - smoothstep(radius - 0.5, radius + 0.5, length(cell));

    float lum = baseAlpha;

    // Ring that expands from the origin and fades at the end of its run.
    if (waveTime > 0.0 && waveTime < 1.0) {
        float front = waveTime * length(res) * 1.15;
        float ring = 1.0 - smoothstep(0.0, spacing * 7.0,
                                      abs(length(px - waveOrigin) - front));
        lum += ring * (1.0 - waveTime);
    }

    // Premultiplied-alpha output, as the Qt Quick pipeline expects.
    float alpha = dotColor.a * disc * clamp(lum, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(dotColor.rgb * alpha, alpha);
}
