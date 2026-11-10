shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float density : hint_range(0.0, 1.0) = 0.0;
uniform bool ground_haze = false;
varying float puff_phase;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	puff_phase = dot(center, vec3(2.1, 4.7, 3.4));
	if (!ground_haze) {
		float size = length(MODEL_MATRIX[0].xyz);
		mat4 billboard = mat4(
			vec4(INV_VIEW_MATRIX[0].xyz * size, 0.0),
			vec4(INV_VIEW_MATRIX[1].xyz * size, 0.0),
			vec4(INV_VIEW_MATRIX[2].xyz * size, 0.0),
			MODEL_MATRIX[3]
		);
		MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	}
}

float lobe(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.10, 1.0, length((p - center) / radius));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME * 1.2 + puff_phase;
	vec2 curl = vec2(sin(p.y * 5.0 + t), cos(p.x * 5.0 - t)) * 0.11;
	p += curl;
	if (ground_haze) {
		float radius = length(p - curl);
		float wisps = 0.5 + 0.5 * sin(p.x * 8.0 + p.y * 5.0 - t) * cos(p.y * 9.0 - t * 0.7);
		float edge = 1.0 - smoothstep(0.80 + 0.08 * wisps, 1.0, radius);
		ALBEDO = vec3(0.69, 0.48, 0.80);
		ALPHA = edge * mix(0.20, 0.36, wisps) * density;
	} else {
		float edge = 1.0 - smoothstep(0.72, 1.0, length(p - curl));
		float body = lobe(p, vec2(-0.28, 0.10), vec2(0.64, 0.66));
		body = max(body, lobe(p, vec2(0.14, -0.17), vec2(0.67, 0.66)));
		body = max(body, lobe(p, vec2(0.29, 0.22), vec2(0.57, 0.55)) * 0.84);
		float soft_light = smoothstep(-0.25, 0.78, -p.y + body * 0.4);
		ALBEDO = mix(vec3(0.33, 0.20, 0.44), vec3(0.77, 0.59, 0.88), soft_light);
		ALPHA = body * edge * density * 0.75;
	}
}
