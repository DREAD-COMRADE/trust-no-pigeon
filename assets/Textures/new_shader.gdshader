shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------
// Wall De-Tiling Shader (Godot 4.x)
// Combines:
//   1. Texture bombing: blends a normal + rotated UV sample
//      of the same texture using large-scale noise, so the
//      repeat pattern never lines up with itself.
//   2. Per-instance UV offset/scale jitter (via INSTANCE_ID)
//      so adjacent mesh copies don't repeat identically.
// ---------------------------------------------------------

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float uv_scale : hint_range(0.1, 10.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;

// Large-scale blend noise controls
uniform float bomb_noise_scale : hint_range(0.5, 20.0) = 3.0; // lower = bigger blobs
uniform float bomb_sharpness : hint_range(1.0, 20.0) = 6.0;   // higher = harder edge between the two samples

// Per-instance variation
uniform float instance_jitter_strength : hint_range(0.0, 1.0) = 1.0;

varying vec2 base_uv;
varying float instance_seed;

// Simple hash for per-instance pseudo-random values
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec2 hash21(float p) {
    return vec2(hash11(p), hash11(p + 17.0));
}

// Cheap 2D value noise for the large-scale blend mask
float value_noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float a = hash11(dot(i, vec2(127.1, 311.7)));
    float b = hash11(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7)));
    float c = hash11(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7)));
    float d = hash11(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7)));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Rotate UVs around 0.5,0.5 pivot
vec2 rotate_uv(vec2 uv, float angle) {
    vec2 centered = uv - 0.5;
    float s = sin(angle);
    float c = cos(angle);
    mat2 rot = mat2(vec2(c, -s), vec2(s, c));
    return rot * centered + 0.5;
}

void vertex() {
    // Per-instance random seed from INSTANCE_ID (works with MultiMeshInstance3D
    // or GPU instancing; for single unique meshes this will just be 0 per draw call,
    // so also mix in object world position for variation across separate MeshInstance3Ds)
    float id_seed = float(INSTANCE_ID) * 12.9898;
    float pos_seed = dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 45.164));
    instance_seed = hash11(id_seed + pos_seed);

    base_uv = UV * uv_scale;
}

void fragment() {
    // --- Per-instance jitter: offset + slight scale variation ---
    vec2 jitter_offset = hash21(instance_seed * 7.0 + 1.0) * instance_jitter_strength;
    float jitter_scale = 1.0 + (hash11(instance_seed * 13.0) - 0.5) * 0.2 * instance_jitter_strength;

    vec2 uv_a = base_uv * jitter_scale + jitter_offset;

    // --- Texture bombing: second sample rotated 90 degrees + offset ---
    vec2 uv_b = rotate_uv(base_uv * jitter_scale, 1.5708) + jitter_offset + vec2(0.37, 0.61);

    // --- Large-scale noise to decide which sample dominates where ---
    float mask_raw = value_noise(base_uv * bomb_noise_scale * 0.1 + instance_seed * 3.0);
    float mask = clamp((mask_raw - 0.5) * bomb_sharpness + 0.5, 0.0, 1.0);

    vec4 albedo_a = texture(albedo_tex, uv_a);
    vec4 albedo_b = texture(albedo_tex, uv_b);
    vec3 albedo_final = mix(albedo_a.rgb, albedo_b.rgb, mask);

    vec3 normal_a = texture(normal_tex, uv_a).rgb;
    vec3 normal_b = texture(normal_tex, uv_b).rgb;
    vec3 normal_final = mix(normal_a, normal_b, mask);

    float rough_a = texture(roughness_tex, uv_a).r;
    float rough_b = texture(roughness_tex, uv_b).r;
    float rough_final = mix(rough_a, rough_b, mask);

    ALBEDO = albedo_final;
    NORMAL_MAP = normal_final;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = rough_final * roughness_value;
}
