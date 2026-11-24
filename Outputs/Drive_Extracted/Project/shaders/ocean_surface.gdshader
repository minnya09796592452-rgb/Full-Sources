shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D displacement_map_0 : filter_linear, repeat_enable;
uniform sampler2D displacement_map_1 : filter_linear, repeat_enable;
uniform sampler2D displacement_map_2 : filter_linear, repeat_enable;
uniform sampler2D displacement_map_3 : filter_linear, repeat_enable;
uniform sampler2D deep_sea_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform float grid_size_0 = 1372.0;
uniform float grid_size_1 = 392.0;
uniform float grid_size_2 = 28.0;
uniform float grid_size_3 = 4.0;
uniform vec4 grid_choppyness = vec4(2.3, 2.1, 1.6, 0.9);
uniform float grid_scale = 0.5;
uniform float sea_level = 0.0;
uniform float max_horizon_dist = 2800.0;
uniform float choppyness = 0.8;
uniform float normal_strength = 1.0;
uniform float foam_amount = 1.0;
uniform float foam_coverage = 0.1;
uniform float fresnel_power = 5.0;
uniform float min_fresnel = 0.02;
uniform float refraction_intensity = 0.5;
uniform float refraction_distortion = 0.5;
uniform float absorption_distance = 500.0;
uniform vec3 absorption_coef = vec3(0.45, 0.029, 0.018);
uniform vec3 default_sky_color : source_color = vec3(0.25882, 0.57647, 0.82353);
uniform vec3 default_ocean_color : source_color = vec3(0.03922, 0.07451, 0.14118);
uniform vec3 above_inscatter_tint : source_color = vec3(0.00784, 0.09804, 0.16863);
uniform vec3 below_inscatter_tint : source_color = vec3(0.02745, 0.2, 0.30196);
uniform vec4 foam_tint : source_color = vec4(1.0);
uniform float specular_roughness = 0.2;
uniform float specular_intensity = 0.2;

varying vec3 v_world_position;
varying vec2 v_ocean_uv;
varying float v_view_distance;
varying float v_underwater;

vec4 sample_displacement(vec2 world_xz) {
	vec4 d0 = texture(displacement_map_0, world_xz / max(grid_size_0 * grid_scale, 0.001));
	vec4 d1 = texture(displacement_map_1, world_xz / max(grid_size_1 * grid_scale, 0.001));
	vec4 d2 = texture(displacement_map_2, world_xz / max(grid_size_2 * grid_scale, 0.001));
	vec4 d3 = texture(displacement_map_3, world_xz / max(grid_size_3 * grid_scale, 0.001));
	return vec4(
		d0.r * grid_choppyness.x + d1.r * grid_choppyness.y + d2.r * grid_choppyness.z + d3.r * grid_choppyness.w,
		(d0.g + d1.g + d2.g + d3.g) * grid_scale,
		d0.b * grid_choppyness.x + d1.b * grid_choppyness.y + d2.b * grid_choppyness.z + d3.b * grid_choppyness.w,
		1.0
	);
}

float sample_height(vec2 world_xz) {
	return sample_displacement(world_xz).g;
}

float jacobian_foam(vec2 world_xz, float cell_size) {
	vec2 dx = vec2(cell_size, 0.0);
	vec2 dz = vec2(0.0, cell_size);
	vec4 xp = sample_displacement(world_xz + dx);
	vec4 xm = sample_displacement(world_xz - dx);
	vec4 zp = sample_displacement(world_xz + dz);
	vec4 zm = sample_displacement(world_xz - dz);
	float dxx = ((xp.r - xm.r) / (2.0 * cell_size)) * choppyness;
	float dxz = ((zp.r - zm.r) / (2.0 * cell_size)) * choppyness;
	float dzx = ((xp.b - xm.b) / (2.0 * cell_size)) * choppyness;
	float dzz = ((zp.b - zm.b) / (2.0 * cell_size)) * choppyness;
	float jacobian = (1.0 + dxx) * (1.0 + dzz) - dxz * dzx;
	return clamp((foam_coverage - jacobian) * foam_amount * 3.0, 0.0, 1.0);
}

void vertex() {
	vec2 ndc = VERTEX.xy;
	vec4 near_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0, 1.0);
	vec4 far_view = INV_PROJECTION_MATRIX * vec4(ndc, 0.0, 1.0);
	near_view.xyz /= max(abs(near_view.w), 0.000001);
	far_view.xyz /= max(abs(far_view.w), 0.000001);
	vec3 near_world = (INV_VIEW_MATRIX * vec4(near_view.xyz, 1.0)).xyz;
	vec3 far_world = (INV_VIEW_MATRIX * vec4(far_view.xyz, 1.0)).xyz;
	vec3 ray_dir = normalize(far_world - near_world);
	float denom = ray_dir.y;
	float hit_distance = abs(denom) > 0.00001 ? (sea_level - near_world.y) / denom : max_horizon_dist;
	if (hit_distance < 0.0) {
		hit_distance = max_horizon_dist;
	}
	hit_distance = clamp(hit_distance, 0.0, max_horizon_dist);
	vec3 ocean_world = near_world + ray_dir * hit_distance;
	vec4 displacement = sample_displacement(ocean_world.xz);
	ocean_world.x += displacement.r * choppyness;
	ocean_world.y += displacement.g;
	ocean_world.z += displacement.b * choppyness;
	v_world_position = ocean_world;
	v_ocean_uv = ocean_world.xz;
	v_view_distance = distance(CAMERA_POSITION_WORLD, ocean_world);
	v_underwater = CAMERA_POSITION_WORLD.y < sea_level ? 1.0 : 0.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(ocean_world, 1.0);
}

void fragment() {
	float texel_world = max(grid_size_3 * grid_scale / 64.0, 0.05);
	vec2 dx = vec2(texel_world, 0.0);
	vec2 dz = vec2(0.0, texel_world);
	float dhdx = (sample_height(v_ocean_uv + dx) - sample_height(v_ocean_uv - dx)) / (2.0 * texel_world);
	float dhdz = (sample_height(v_ocean_uv + dz) - sample_height(v_ocean_uv - dz)) / (2.0 * texel_world);
	vec3 displacement_normal = normalize(vec3(-dhdx * normal_strength, 1.0, -dhdz * normal_strength));
	vec3 detail_normal = texture(wave_normal_tex, v_ocean_uv * 0.025).xyz * 2.0 - 1.0;
	vec3 normal_world = normalize(displacement_normal + vec3(detail_normal.x, 0.0, detail_normal.y) * 0.22);
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_position);
	float ndotv = clamp(dot(normal_world, view_dir), 0.0, 1.0);
	float fresnel = clamp(min_fresnel + (1.0 - min_fresnel) * pow(1.0 - ndotv, fresnel_power), min_fresnel, 0.96);

	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float scene_depth = length(view_pos.xyz / max(abs(view_pos.w), 0.00001));
	float water_depth = clamp(scene_depth, 0.0, absorption_distance);
	vec3 transmittance = exp(-absorption_coef * water_depth);
	vec2 refract_uv = SCREEN_UV + normal_world.xz * refraction_distortion * 0.012;
	vec3 refracted_scene = texture(screen_texture, clamp(refract_uv, vec2(0.001), vec2(0.999))).rgb;
	vec3 seabed = texture(deep_sea_tex, v_ocean_uv * 0.018).rgb;
	vec3 water_body = mix(default_ocean_color * (0.72 + seabed * 0.45), refracted_scene, refraction_intensity * (1.0 - fresnel));
	water_body = water_body * transmittance + above_inscatter_tint * (1.0 - transmittance);

	float foam = jacobian_foam(v_ocean_uv, texel_world);
	vec3 surface_color = mix(water_body, default_sky_color, fresnel);
	surface_color = mix(surface_color, foam_tint.rgb, foam * foam_tint.a);

	vec3 underwater_color = below_inscatter_tint + refracted_scene * transmittance;
	vec3 final_color = mix(surface_color, underwater_color, v_underwater);
	float horizon = smoothstep(max_horizon_dist * 0.55, max_horizon_dist, v_view_distance);
	final_color = mix(final_color, default_sky_color, horizon * (1.0 - v_underwater));

	ALBEDO = final_color;
	ROUGHNESS = mix(specular_roughness, 0.38, horizon);
	SPECULAR = specular_intensity;
	METALLIC = 0.0;
}
