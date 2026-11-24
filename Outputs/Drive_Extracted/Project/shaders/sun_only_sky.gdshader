shader_type sky;

uniform sampler2D halo_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D inscatter_lut : source_color, filter_linear, repeat_disable;
uniform sampler2D transmittance_lut : source_color, filter_linear, repeat_disable;
uniform sampler2D irradiance_lut : source_color, filter_linear, repeat_disable;
uniform sampler2D moon_tex : source_color, filter_linear, repeat_disable;

uniform vec3 sun_color : source_color = vec3(1.0, 0.99222, 0.98529);
uniform float sun_intensity : hint_range(0.0, 40.0) = 18.0;
uniform float sun_disc_radius : hint_range(0.005, 0.1) = 0.024;
uniform float halo_radius : hint_range(0.05, 0.8) = 0.18;
uniform float halo_larger_radius : hint_range(0.1, 1.5) = 0.45;
uniform float halo_intensity : hint_range(0.0, 5.0) = 1.25;

uniform vec3 moon_dir = vec3(0.0, 0.50, 0.866025);
uniform vec3 moon_color : source_color = vec3(0.78, 0.86, 1.0);
uniform float moon_radius : hint_range(0.01, 0.15) = 0.036;
uniform float moon_intensity : hint_range(0.0, 10.0) = 2.6;
uniform float star_intensity : hint_range(0.0, 4.0) = 1.35;

uniform vec3 beta_r = vec3(0.0058, 0.0135, 0.0331);
uniform float beta_m = 0.0045;
uniform float mie_g : hint_range(0.0, 0.99) = 0.85;
uniform float atmosphere_exposure : hint_range(0.2, 4.0) = 1.35;

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_density : hint_range(0.0, 2.0) = 1.05;
uniform float cloud_scale : hint_range(0.1, 4.0) = 1.15;
uniform vec2 wind_speed = vec2(0.035, 0.018);
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.0;

highp float smooth_cloud_fbm(highp vec2 p) {
    highp float sum = 0.0;
    highp float amp = 0.50;
    highp mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
    for (int i = 0; i < 5; i++) {
        highp vec2 w = vec2(sin(p.y * 1.15 + 1.3), cos(p.x * 1.15 + 0.7)) * 0.45;
        highp float n = (sin(p.x + w.x) * cos(p.y + w.y) + sin((p.x + p.y) * 0.72) * 0.5) * 0.35 + 0.5;
        sum += amp * n;
        p = rot * p * 2.07 + vec2(2.41, 1.73);
        amp *= 0.52;
    }
    return clamp(sum, 0.0, 1.0);
}

void sky() {
    highp vec3 dir = normalize(EYEDIR);
    highp vec3 sun_dir = normalize(LIGHT0_DIRECTION);
    highp vec3 m_dir = normalize(moon_dir);
    highp float cos_theta = clamp(dot(dir, sun_dir), -1.0, 1.0);
    highp float mu = clamp(dir.y, 0.0, 1.0);
    highp float mu_s = clamp(sun_dir.y * 0.5 + 0.5, 0.01, 0.99);

    vec3 trans = texture(transmittance_lut, vec2(clamp(mu, 0.01, 0.99), mu_s)).rgb;
    vec3 irrad = texture(irradiance_lut, vec2(mu_s, 0.5)).rgb;
    vec3 inscat = texture(inscatter_lut, vec2(clamp(cos_theta * 0.5 + 0.5, 0.01, 0.99), clamp(mu, 0.02, 0.98))).rgb;

    float od = 1.0 / (max(mu, 0.035) + 0.12);
    vec3 ext = exp(-(beta_r * 38.0 + vec3(beta_m * 18.0)) * od);
    float r_phase = 0.059683 * (1.0 + cos_theta * cos_theta);
    float g2 = mie_g * mie_g;
    float m_phase = 0.119366 * ((1.0 - g2) * (1.0 + cos_theta * cos_theta)) / ((2.0 + g2) * pow(max(1.0 + g2 - 2.0 * mie_g * cos_theta, 0.001), 1.5));

    float day = smoothstep(-0.18, 0.25, sun_dir.y);
    float night = 1.0 - day;
    vec3 day_sky = (beta_r * 115.0 * r_phase * (1.0 - ext) + vec3(beta_m * 42.0) * m_phase * (1.0 - ext) * sun_color + inscat * 0.28 + irrad * 0.12) * atmosphere_exposure;
    vec3 night_sky = mix(vec3(0.025, 0.052, 0.115), vec3(0.008, 0.018, 0.048), pow(mu, 0.6));
    vec3 sky_col = mix(night_sky, day_sky, day);

    vec3 storm_col = vec3(0.11, 0.14, 0.18) * max(day, 0.15);
    sky_col = mix(sky_col, storm_col, storm_intensity * 0.85);
    vec3 hor_col = mix(vec3(0.04, 0.08, 0.16), vec3(0.58, 0.78, 0.95) * (0.65 + 0.35 * trans), day);
    hor_col = mix(hor_col, storm_col * 1.15, storm_intensity * 0.85);
    sky_col = mix(hor_col, sky_col, smoothstep(0.0, 0.32, mu));

    if (night > 0.05 && dir.y > 0.02) {
        highp vec3 sp = dir * 135.0;
        highp float st = sin(sp.x) * sin(sp.y * 1.31) * sin(sp.z * 1.73);
        highp float st2 = cos(sp.x * 1.9 + 0.7) * cos(sp.y * 2.3) * cos(sp.z * 1.41);
        float star = pow(max(st * st2, 0.0), 18.0) * 18.0;
        float twinkle = 0.75 + 0.25 * sin(TIME * 2.8 + sp.x * 0.3);
        sky_col += vec3(0.82, 0.90, 1.0) * star * twinkle * star_intensity * night * smoothstep(0.02, 0.25, dir.y) * (1.0 - storm_intensity);
    }

    highp vec3 up_ref = abs(sun_dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    highp vec3 right = normalize(cross(up_ref, sun_dir));
    highp vec3 up = cross(sun_dir, right);
    highp float ang = acos(cos_theta);
    highp vec2 lxy = vec2(dot(dir, right), dot(dir, up));
    float front = step(0.0, cos_theta);

    float disc = smoothstep(sun_disc_radius, sun_disc_radius * 0.75, ang);
    float h1 = texture(halo_tex, clamp((lxy / (halo_radius * 2.0)) + 0.5, 0.0, 1.0)).r * smoothstep(halo_radius, 0.0, ang) * front;
    float h2 = texture(halo_tex, clamp((lxy / (halo_larger_radius * 2.0)) + 0.5, 0.0, 1.0)).r * smoothstep(halo_larger_radius, 0.0, ang) * front * 0.45;
    vec3 sun_col_out = sun_color * (disc * sun_intensity + (h1 + h2) * halo_intensity) * smoothstep(-0.08, 0.08, sun_dir.y) * (1.0 - storm_intensity * 0.92);

    highp float m_cos = clamp(dot(dir, m_dir), -1.0, 1.0);
    highp float m_ang = acos(m_cos);
    highp vec3 m_up_ref = abs(m_dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    highp vec3 m_right = normalize(cross(m_up_ref, m_dir));
    highp vec3 m_up = cross(m_dir, m_right);
    highp vec2 m_uv = (vec2(dot(dir, m_right), dot(dir, m_up)) / (moon_radius * 2.0)) + 0.5;
    vec4 m_sample = texture(moon_tex, clamp(m_uv, 0.0, 1.0));
    float m_mask = smoothstep(moon_radius, moon_radius * 0.88, m_ang) * step(0.0, m_cos);
    float m_glow = exp(-m_ang * 14.0) * 0.55 * step(0.0, m_cos);
    vec3 moon_out = moon_color * (m_sample.rgb * m_mask * moon_intensity + m_glow) * smoothstep(-0.05, 0.12, m_dir.y) * (1.0 - storm_intensity * 0.9);

    vec3 col = sky_col + sun_col_out + moon_out;

    if (dir.y > 0.01) {
        highp vec2 suv = (dir.xz / (dir.y + 0.24)) * cloud_scale;
        float n1 = smooth_cloud_fbm(suv + TIME * wind_speed);
        float n2 = smooth_cloud_fbm(suv * 1.95 - TIME * (wind_speed * 0.55) + vec2(3.1, 5.7));
        float raw_c = mix(n1, n2, 0.36);

        float thr = mix(1.0 - cloud_coverage, 0.22, storm_intensity);
        float alpha = clamp(smoothstep(thr, thr + 0.26, raw_c) * cloud_density * smoothstep(0.01, 0.18, dir.y), 0.0, 0.96);

        float silver = pow(max(cos_theta, 0.0), 6.0) * day * (1.0 - storm_intensity * 0.8);
        float m_silver = pow(max(m_cos, 0.0), 8.0) * night * (1.0 - storm_intensity * 0.8);
        vec3 c_hi = mix(vec3(0.18, 0.24, 0.36), mix(hor_col * 0.45 + vec3(0.62), sun_color * 1.15, 0.38), day);
        vec3 c_lo = mix(vec3(0.04, 0.06, 0.11), mix(hor_col, sky_col, 0.45) * 0.82, day);
        vec3 c_col = mix(c_lo, c_hi, smoothstep(thr, thr + 0.34, raw_c)) + sun_color * silver * 0.45 + moon_color * m_silver * 0.35;
        c_col = mix(c_col, vec3(0.14, 0.16, 0.21) * max(day, 0.16), storm_intensity * 0.84);
        col = mix(col, c_col, alpha);
    }
    COLOR = col;
}
