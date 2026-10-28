#version 440
// Phosphor decay over a CRT-style screen, drawn as an overlay: a bright
// refresh beam rolls down the screen and fades out behind it the way P1/P3
// phosphor glows on, plus a faint vignette at the tube's curved edges.
// Compile: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o phosphor.frag.qsb phosphor.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;        // 0..1, the beam's position down the screen
    float strength;     // 0..1
    vec4 tint;          // the phosphor colour
};
void main() {
    float y = qt_TexCoord0.y;
    float d = phase - y;                       // how far the beam has passed this row
    d = d < 0.0 ? d + 1.0 : d;
    float glow = exp(-d * 9.0) * 0.55 + exp(-d * 60.0) * 0.45;
    vec2 c = qt_TexCoord0 - 0.5;
    float vignette = smoothstep(0.35, 0.75, length(c * vec2(1.0, 1.25)));
    float a = strength * (glow * 0.10);
    vec4 beam = vec4(tint.rgb * a, a);
    vec4 edge = vec4(0.0, 0.0, 0.0, strength * vignette * 0.22);
    fragColor = (beam + edge * (1.0 - beam.a)) * qt_Opacity;
}
