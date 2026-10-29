#version 440
// CRT glass: bends `source` outward like a curved tube face, darkening the
// corners that fall off the glass.
// Compile: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o barrel.frag.qsb barrel.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float curvature;    // 0 flat .. 0.15 strongly curved
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec2 c = qt_TexCoord0 * 2.0 - 1.0;
    c *= 1.0 + curvature * dot(c.yx, c.yx);
    vec2 uv = (c + 1.0) * 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { fragColor = vec4(0.0, 0.0, 0.0, qt_Opacity); return; }
    vec2 edge = smoothstep(vec2(0.0), vec2(0.012), uv) * smoothstep(vec2(0.0), vec2(0.012), 1.0 - uv);
    fragColor = texture(source, uv) * edge.x * edge.y * qt_Opacity;
}
