shader_type spatial;
render_mode cull_disabled;

uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform sampler2D soil_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform float field_range = 3.0;
uniform vec2 soil_uv_scale;
uniform vec2 patch_origin;
uniform vec2 patch_size;
uniform vec2 flow_axis = vec2(1.0, 0.0);
uniform bool water = true;
uniform vec4 shallow_water : source_color = vec4(0.48, 0.58, 0.43, 1.0);
uniform vec4 deep_water : source_color = vec4(0.28, 0.47, 0.45, 1.0);
uniform vec4 water_glint : source_color = vec4(0.71, 0.78, 0.64, 1.0);

float hash_cell(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1137, 0.1379));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), f.x);
	float b = mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0)), f.x);
	return mix(a, b, f.y);
}

varying vec2 room_point;

void vertex() {
	room_point = VERTEX.xz + patch_origin + patch_size * 0.5;
}

void fragment() {
	vec2 point = room_point;
	vec2 pixel = (floor(point * 20.0) + 0.5) / 20.0;
	vec2 field_uv = (pixel - patch_origin) / patch_size;
	float distance = (texture(shore_field, field_uv).r * 2.0 - 1.0) * field_range;
	float mottling = noise2(pixel * 2.1);
	float grain = hash_cell(floor(pixel * 20.0));
	float edge = distance + (mottling - 0.5) * 0.42 + (grain - 0.5) * 0.095;
	// Break up the outer bank with stable pixels and keep attack markers above the ground.
	float bank_coverage = 1.0 - smoothstep(water ? 0.30 : 0.48, water ? 1.20 : 1.50, edge);
	if (bank_coverage <= grain) {
		discard;
	}
	vec3 soil = texture(soil_texture, point * soil_uv_scale).rgb;
	float dampness = 1.0 - smoothstep(-0.34, 0.94, edge);
	vec3 bank = mix(soil, soil * vec3(0.79, 0.82, 0.83), dampness * (0.54 + 0.26 * mottling));
	float depth = -edge;
	float basin = noise2(pixel * 0.62);

	if (water) {
		float deep = smoothstep(0.10, 1.30, depth + (basin - 0.5) * 0.45);
		vec3 shallows = mix(bank, shallow_water.rgb, 0.65);
		vec3 pool = mix(shallows, deep_water.rgb, deep) * (0.90 + 0.17 * basin);
		vec2 flow = vec2(dot(pixel, flow_axis), dot(pixel, vec2(-flow_axis.y, flow_axis.x)));
		float waves = sin(flow.y * 15.0 + noise2(flow * vec2(1.4, 2.0)) * 1.9 - TIME * 1.35);
		float broken = smoothstep(0.51, 0.80, noise2(flow * vec2(1.6, 4.2) + vec2(-TIME * 0.17, 0.0)));
		float glint = smoothstep(0.82, 0.99, waves) * broken * smoothstep(0.18, 0.72, depth);
		pool = mix(pool, water_glint.rgb, glint * 0.25);
		float waterline = smoothstep(-0.08, 0.18, depth);
		ALBEDO = mix(bank, pool, waterline);
		ROUGHNESS = mix(0.97, 0.59, waterline);
	} else {
		float wet = smoothstep(-0.20, 1.13, depth + (basin - 0.5) * 0.48);
		vec3 clay = soil * vec3(0.78, 0.66, 0.59) * (0.87 + 0.24 * basin + 0.10 * mottling);
		float sheen = smoothstep(0.66, 0.87, noise2(pixel * vec2(3.0, 8.0))) * wet;
		clay += vec3(0.052, 0.047, 0.038) * sheen;
		ALBEDO = mix(bank, clay, wet);
		ROUGHNESS = mix(0.98, 0.73, wet);
	}
}
