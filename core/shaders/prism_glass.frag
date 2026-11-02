#version 440

// Prism glass — independent refractive lens for the shell.
// This is a clean-room effect: it samples the wallpaper at the surface's
// screen position, bends the edge, adds chromatic separation and a bright rim.
// It deliberately shares only generic optics concepts with the liquid lens.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  itemSize;
    vec2  screenPos;
    vec2  screenSize;
    vec4  radii;
    vec4  tintColor;
    float bezel;
    float thickness;
    float ior;
    float dispersion;
    float frost;
    float rim;
    float tintAmount;
    float interiorShade;
    float saturation;
    float fresnel;
    float grain;
    float facetStrength;
    float sheenStrength;
    vec4  sourceRect;
    vec4  rimSides;     // left, top, right, bottom
};

layout(binding = 1) uniform sampler2D src;

const int TAPS = 9;
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
    float edge = 1.0 - smoothstep(0.0, bz, t);

    // Full-bleed panels can suppress only their side rim; see Liquid shader.
    float sideL = 1.0 - smoothstep(0.0, bz, p.x + itemSize.x * 0.5);
    float sideR = 1.0 - smoothstep(0.0, bz, itemSize.x * 0.5 - p.x);
    float sideT = 1.0 - smoothstep(0.0, bz, p.y + itemSize.y * 0.5);
    float sideB = 1.0 - smoothstep(0.0, bz, itemSize.y * 0.5 - p.y);
    float rimMask = max(max(sideL * rimSides.x, sideR * rimSides.z),
                        max(sideT * rimSides.y, sideB * rimSides.w));
    rimMask = clamp(rimMask, 0.0, 1.0);

    // SDF normal, used for refraction and the lit rim.
    vec2 e = vec2(0.75, 0.0);
    vec2 n2 = vec2(
        sdRoundBox(p + e.xy, itemSize * 0.5, radii) - sdRoundBox(p - e.xy, itemSize * 0.5, radii),
        sdRoundBox(p + e.yx, itemSize * 0.5, radii) - sdRoundBox(p - e.yx, itemSize * 0.5, radii));
    n2 = length(n2) > 1e-4 ? normalize(n2) : vec2(0.0, -1.0);

    float slope = edge * edge * 4.4;

    // Crystal facets: two slow, crossed waves perturb the normal across the
    // interior. This is what distinguishes Prism from the smooth Liquid lens.
    float facetA = sin(dot(p, vec2(0.071, 0.043)) + 0.9 * sin(dot(p, vec2(-0.029, 0.061)) * 1.7));
    float facetB = cos(dot(p, vec2(0.053, -0.067)) + 0.8 * sin(dot(p, vec2(0.041, 0.037)) * 1.3));
    float facetC = sin(dot(p, vec2(0.017, 0.023)) * 2.0 + facetA * 1.4);
    vec2 facets = vec2(facetA, facetB) * (0.55 + 0.45 * facetC) * clamp(facetStrength, 0.0, 1.5);

    vec3 normal = normalize(vec3(n2 * slope + facets * 0.16, 1.0));
    vec3 refracted = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / max(ior, 1.01));
    float bend = thickness * (0.22 + edge * 0.78) * 0.55;
    vec2 shift = refracted.xy * bend + facets * bend * 0.18;

    vec2 screenUv = sourceRect.xy
        + ((screenPos + p + itemSize * 0.5 + shift) / max(screenSize, vec2(1.0))) * sourceRect.zw;
    vec3 col = frosted(screenUv, frost * mix(0.55, 1.0, edge));

    if (edge > 0.01 || length(facets) > 0.2) {
        float spreadAmt = dispersion * (0.45 + 1.15 * edge + 0.35 * length(facets));
        vec2 spread = normalize(n2 + facets * 0.35 + vec2(0.001)) * bend * spreadAmt;
        vec3 r = wallpaper(screenUv + spread / max(screenSize, vec2(1.0)) * sourceRect.zw);
        vec3 b = wallpaper(screenUv - spread / max(screenSize, vec2(1.0)) * sourceRect.zw);
        col = mix(col, vec3(r.r, col.g, b.b), clamp(edge * 0.72 + length(facets) * 0.10, 0.0, 0.82));
    }

    // Cool crystalline sheen and fine facet highlights (not present in Liquid).
    float sheenPhase = dot(p, vec2(0.0035, 0.0051)) + facetA * 0.22;
    vec3 prismatic = 0.5 + 0.5 * cos(6.2831853 * (sheenPhase + vec3(0.0, 0.33, 0.67)));
    float sheen = smoothstep(0.18, 1.0, edge) * 0.16 + pow(abs(facetA * facetB), 7.0) * 0.22;
    col += prismatic * sheen * (0.55 + 0.45 * edge) * clamp(sheenStrength, 0.0, 1.5) * rimMask;

    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(lum), col, max(saturation, 0.0));

    vec3 prismTint = mix(tintColor.rgb, vec3(0.10, 0.16, 0.24), 0.28);
    col = mix(col, prismTint, clamp(tintAmount * (0.65 + 0.35 * edge), 0.0, 0.88));

    // Dim the interior only; the rim is added after this so it stays bright.
    float inner = smoothstep(0.0, bz * 2.4, t);
    col *= mix(1.0, 1.0 - clamp(interiorShade, 0.0, 0.6), inner);

    // Fresnel-like environment lift at the edge.
    float f = pow(1.0 - normal.z, 1.6) * clamp(fresnel, 0.0, 1.0)
        * mix(0.25, 1.0, clamp(sheenStrength, 0.0, 1.0)) * rimMask;
    if (f > 0.001) {
        vec3 env = wallpaper(screenUv + n2 * (bz * 1.5) / max(screenSize, vec2(1.0)) * sourceRect.zw);
        col = mix(col, env * 1.10 + 0.02, clamp(f * (0.35 + 0.65 * edge), 0.0, 0.55));
    }

    vec2 lightDir = normalize(vec2(-0.55, -0.83));
    float spec = pow(max(dot(n2, lightDir), 0.0), 2.0) * rim;
    float rimLight = (exp(-t / 1.2) * 0.55 + exp(-t / 5.0) * 0.18) * rim;
    col += vec3(spec + rimLight) * (0.35 + 0.65 * edge) * clamp(sheenStrength, 0.0, 1.5) * rimMask;

    col += vec3((hash12(gl_FragCoord.xy) - 0.5) * grain);

    float alpha = coverage * qt_Opacity;
    fragColor = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
