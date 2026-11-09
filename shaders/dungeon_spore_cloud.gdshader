shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool plume = false;
uniform float phase = 0.0;

float puff(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.18, 1.0, length((p - center) / radius));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME * 1.05 + phase;
	vec2 drift = vec2(sin(t * 0.78), cos(t * 0.65)) * 0.15;
	float body = puff(p, vec2(-0.39, 0.12) + drift, vec2(0.55, 0.56));
	body = max(body, puff(p, vec2(0.10, -0.16) - drift * 0.7, vec2(0.65, 0.57)));
	body = max(body, puff(p, vec2(0.42, 0.28) + drift * 0.6, vec2(0.51, 0.52)));
	body = max(body, puff(p, vec2(-0.04, 0.39) - drift, vec2(0.58, 0.49)) * 0.74);

	float curl = sin(p.x * 12.0 + cos(p.y * 8.0 - t) * 2.4 - t * 1.5);
	float wisps = 0.5 + 0.5 * curl * sin(p.y * 12.0 + p.x * 5.0 + t);
	float edge = plume ? 1.0 - smoothstep(0.68, 0.99, max(abs(p.x), abs(p.y))) :
		1.0 - smoothstep(0.69, 1.0, length(p));
	float opacity = body * edge * (0.60 + 0.35 * wisps);
	ALBEDO = mix(vec3(0.49, 0.35, 0.57), vec3(0.85, 0.71, 0.89), smoothstep(0.18, 0.88, wisps));
	ALPHA = opacity * (plume ? 0.78 : 0.81);
}
