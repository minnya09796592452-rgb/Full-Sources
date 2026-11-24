shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D wave_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D deep_sea_tex : source_color, filter_linear_mipmap, repeat_enable;

// Exact Ceto.Ocean & Ceto.UnderWater Constants from Stranded Deep 4 Assembly-CSharp.dll
uniform vec3 default_sky_color : source_color = vec3(0.25882, 0.57647, 0.82353);      // Color32(66, 147, 210)
uniform vec3 default_ocean_color : source_color = vec3(0.03922, 0.07451, 0.14118);    // Color32(10, 19, 36)
uniform vec3 above_inscatter_tint : source_color = vec3(0.00784, 0.09804, 0.16863);   // Color32(2, 25, 43)
uniform vec3 below_inscatter_tint : source_color = vec3(0.02745, 0.20000, 0.30196);   // Color32(7, 51, 77)
uniform vec3 absorption_coef = vec3(0.45, 0.029, 0.018);                              // absorptionR/G/B

uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;                            // fresnelPower = 5f
uniform float min_fresnel : hint_range(0.0, 0.2) = 0.02;                              // minFresnel = 0.02f
uniform float specular_roughness : hint_range(0.01, 1.0) = 0.20;                      // specularRoughness = 0.2f
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.20;                       // specularIntensity = 0.2f

// Exact Ceto.WaveSpectrum Defaults
uniform float wind_speed : hint_range(0.0, 30.0) = 8.0;                               // windSpeed = 8f
uniform float wind_dir_deg : hint_range(0.0, 360.0) = 35.0;
uniform float choppyness : hint_range(0.0, 1.2) = 0.80;                               // choppyness = 0.8f
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;                               // waveSpeed = 1f
uniform float grid_scale : hint_range(0.1, 1.0) = 0.50;                               // gridScale = 0.5f
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

varying vec3 v_world_pos;
varying float v_cam_dist;

vec3 ceto_gerstner_offset(vec2 xz, float t) {
    float rad = radians(wind_dir_deg);
    vec2 d0 = vec2(cos(rad), sin(rad));
    vec2 d1 = vec2(cos(rad + 0.42), sin(rad + 0.42));
    vec2 d2 = vec2(cos(rad - 0.55), sin(rad - 0.55));
    vec2 d3 = vec2(cos(rad + 1.05), sin(rad + 1.05));

    float g = 9.81;
    float amp_scale = 0.34 * grid_scale * 2.0;
    float k0 = 0.11; float w0 = sqrt(g * k0); float a0 = 0.52 * amp_scale;
    float k1 = 0.19; float w1 = sqrt(g * k1); float a1 = 0.31 * amp_scale;
    float k2 = 0.33; float w2 = sqrt(g * k2); float a2 = 0.17 * amp_scale;
    float k3 = 0.58; float w3 = sqrt(g * k3); float a3 = 0.09 * amp_scale;

    float spd = max(wind_speed * 0.14 * wave_speed, 0.0);
    float p0 = dot(d0, xz) * k0 - w0 * t * spd;
    float p1 = dot(d1, xz) * k1 - w1 * t * spd;
    float p2 = dot(d2, xz) * k2 - w2 * t * spd;
    float p3 = dot(d3, xz) * k3 - w3 * t * spd;

    vec3 off = vec3(0.0);
    off.xz -= (d0 * a0 * sin(p0) + d1 * a1 * sin(p1) + d2 * a2 * sin(p2) + d3 * a3 * sin(p3)) * choppyness;
    off.y  += (a0 * cos(p0) + a1 * cos(p1) + a2 * cos(p2) + a3 * cos(p3));
    return off;
}

void vertex() {
    // Radial ProjectedGrid warp: packs high vertex density near camera & stretches smoothly to 3200m horizon
    vec2 n_xz = VERTEX.xz / 100.0; // normalized [-1..1]
    float r = length(n_xz);
    vec2 dir_xz = r > 0.0001 ? n_xz / r : vec2(0.0);
    float warped_r = pow(r, 2.4) * 3200.0;
    VERTEX.xz = dir_xz * warped_r;

    vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float dist = length(CAMERA_POSITION_WORLD - wpos);
    v_cam_dist = dist;

    float active = 1.0 - smoothstep(180.0, 950.0, dist);
    VERTEX += ceto_gerstner_offset(wpos.xz, TIME) * active;
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float dist = v_cam_dist;
    float blur_factor = smoothstep(220.0, 1400.0, dist);
    float lod_bias = blur_factor * 2.0;

    float opt_depth = clamp(dist * 0.045, 0.35, 16.0);
    vec3 transmittance = exp(-absorption_coef * opt_depth);
    vec3 base_tex = textureLod(deep_sea_tex, v_world_pos.xz * 0.018, lod_bias * 0.5).rgb;
    vec3 deep_col = default_ocean_color * (0.72 + 0.45 * base_tex) + above_inscatter_tint * 0.35;
    vec3 water_albedo = mix(deep_col, below_inscatter_tint, transmittance);

    float rad = radians(wind_dir_deg);
    vec2 wdir = vec2(cos(rad), sin(rad));
    vec2 perp = vec2(-wdir.y, wdir.x);
    float t = TIME * (wind_speed * 0.0042 * wave_speed);
    float tiling = 0.062;

    vec2 uv1 = v_world_pos.xz * tiling + wdir * t;
    vec2 uv2 = v_world_pos.xz * (tiling * 1.85) + (wdir * 0.7 + perp * 0.5) * (t * 1.35) + vec2(0.37, 0.61);
    vec2 uv3 = v_world_pos.xz * (tiling * 3.40) + (wdir * 0.5 - perp * 0.7) * (t * 1.85) + vec2(0.19, 0.83);

    vec3 n1 = textureLod(wave_normal_tex, uv1, lod_bias).xyz * 2.0 - 1.0;
    vec3 n2 = textureLod(wave_normal_tex, uv2, lod_bias).xyz * 2.0 - 1.0;
    vec3 n3 = textureLod(wave_normal_tex, uv3, lod_bias).xyz * 2.0 - 1.0;
    float d_str = normal_strength * (1.0 - blur_factor * 0.65);
    vec3 n_mix = normalize(vec3((n1.xy + n2.xy * 0.75 + n3.xy * 0.45) * d_str, 1.0));

    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
    float cos_v = clamp(dot(view_dir, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
    float fresnel = clamp(min_fresnel + (1.0 - min_fresnel) * pow(1.0 - cos_v, fresnel_power), min_fresnel, 0.92);
    vec3 col = mix(water_albedo, default_sky_color, fresnel);

    float horizon_blend = smoothstep(1400.0, 2900.0, dist);
    col = mix(col, default_sky_color, horizon_blend);

    ALBEDO = col;
    NORMAL_MAP = n_mix * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 1.0;
    ROUGHNESS = mix(specular_roughness, 0.35, blur_factor);
    SPECULAR = specular_intensity;
    METALLIC = 0.02;
}
