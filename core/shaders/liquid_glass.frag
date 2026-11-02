#version 440

// Original, MIT-licensed liquid-glass shader for the equisdots shell.
// It samples a full-screen wallpaper texture and applies:
//   - a rounded-rectangle SDF with per-corner radii,
//   - edge refraction (offset sampling along the SDF normal),
//   - a small chromatic dispersion on the refracted edge,
//   - a multi-tap frosted blur,
//   - a tint, a specular rim and fine grain.
// It is intentionally simpler than Apple's material: there is no adaptive
// tint or per-pixel lensing, only a convincing edge lens + frost.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  itemSize;
    vec2  screenPos;
    vec2  screenSize;
    vec4  radii;        // topLeft, topRight, bottomRight, bottomLeft
    vec4  tintColor;
    float bezel;
    float ior;
    float dispersion;
    float frost;
    float rim;
    float tintAmount;
    float interiorShade;
    float grain;
    vec4  rimSides;     // left, top, right, bottom
};

layout(binding = 1) uniform sampler2D src;

const int TAPS = 8;
const float GOLDEN = 2.39996323;

float sdRoundBox(vec2 p, vec2 b, vec4 r) {
    float rad = p.x > 0.0 ? (p.y > 0.0 ? r.z : r.y) : (p.y > 0.0 ? r.w : r.x);
    rad = min(rad, min(b.x, b.y));
    vec2 q = abs(p) - b + rad;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rad;
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 wallpaper(vec2 uv) {
    uv = clamp(uv, vec2(0.001), vec2(0.999));
    return texture(src, uv).rgb;
}

vec3 frosted(vec2 uv, float radius) {
    vec2 stepPx = radius / max(screenSize, vec2(1.0));
    float rot = hash12(gl_FragCoord.xy) * 6.2831853;
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < TAPS; ++i) {
        float fi = float(i) + 0.5;
        float r = sqrt(fi / float(TAPS));
        float a = fi * GOLDEN + rot;
        float w = exp(-2.2 * r * r);
        acc += wallpaper(uv + vec2(cos(a), sin(a)) * r * stepPx) * w;
        wsum += w;
    }
    return acc / max(wsum, 1e-4);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize - itemSize * 0.5;
    float d = sdRoundBox(p, itemSize * 0.5, radii);
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    if (coverage <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float t = max(-d, 0.0);
    float bz = max(bezel, 1.0);

    // Directional rim mask: a full-bleed surface can keep its top/bottom lit
    // edge while removing the side glow that would otherwise sit on the
    // monitor bezel.
    float sideL = 1.0 - smoothstep(0.0, bz, p.x + itemSize.x * 0.5);
    float sideR = 1.0 - smoothstep(0.0, bz, itemSize.x * 0.5 - p.x);
    float sideT = 1.0 - smoothstep(0.0, bz, p.y + itemSize.y * 0.5);
    float sideB = 1.0 - smoothstep(0.0, bz, itemSize.y * 0.5 - p.y);
    float rimMask = max(max(sideL * rimSides.x, sideR * rimSides.z),
                        max(sideT * rimSides.y, sideB * rimSides.w));
    rimMask = clamp(rimMask, 0.0, 1.0);

    // SDF gradient = surface normal, used for the edge lens.
    vec2 e = vec2(1.0, 0.0);
    vec2 n = vec2(sdRoundBox(p + e.xy, itemSize * 0.5, radii) - sdRoundBox(p - e.xy, itemSize * 0.5, radii),
                  sdRoundBox(p + e.yx, itemSize * 0.5, radii) - sdRoundBox(p - e.yx, itemSize * 0.5, radii));
    n = length(n) > 1e-4 ? normalize(n) : vec2(0.0, -1.0);

    float edge = 1.0 - smoothstep(0.0, bz, t);
    float lens = edge * edge * (bz * 0.45) * clamp(ior - 1.0, 0.0, 1.0);
    vec2 refr = n * lens;
    vec2 uv = (screenPos + p + itemSize * 0.5 + refr) / max(screenSize, vec2(1.0));

    vec3 col = frosted(uv, frost);

    // Chromatic separation only on the refractive rim.
    if (edge > 0.01) {
        vec2 spread = n * lens * dispersion;
        vec3 r = wallpaper(uv + spread / max(screenSize, vec2(1.0)));
        vec3 b = wallpaper(uv - spread / max(screenSize, vec2(1.0)));
        col = mix(col, vec3(r.r, col.g, b.b), edge * 0.8);
    }

    // Tint and a soft specular rim (light from the upper-left).
    vec3 tint = tintColor.rgb;
    col = mix(col, tint, clamp(tintAmount * (0.65 + 0.35 * edge), 0.0, 0.85));

    // Dim only the interior; the specular rim below stays bright. This keeps
    // content legible while preserving the lit edge that defines the glass.
    float innerMask = smoothstep(0.0, bz * 2.2, t);
    col *= mix(1.0, 1.0 - clamp(interiorShade, 0.0, 0.6), innerMask);

    vec2 lightDir = normalize(vec2(-0.55, -0.83));
    float spec = pow(max(dot(n, lightDir), 0.0), 2.0) * rim;
    float rimLight = (exp(-t / 1.2) * 0.55 + exp(-t / 5.0) * 0.18) * rim;
    col += vec3(spec + rimLight) * (0.35 + 0.65 * edge) * rimMask;

    // Fine grain breaks 8-bit banding without becoming a texture.
    col += vec3((hash12(gl_FragCoord.xy) - 0.5) * grain);

    float alpha = coverage * qt_Opacity;
    fragColor = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
