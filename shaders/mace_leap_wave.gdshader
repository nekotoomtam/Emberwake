shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D wave_art : source_color, filter_linear, repeat_disable;
uniform float half_arc = 0.8726646;
uniform float strength = 1.0;
uniform float progress = 0.0;

void fragment() {
	vec2 ground = vec2(UV.x, (UV.y - 0.5) * 2.0);
	float distance_from_landing = length(ground);
	float angle_ratio = atan(ground.y, max(0.00001, ground.x)) / half_arc;
	float footprint = (1.0 - smoothstep(0.95, 1.0, abs(angle_ratio)))
		* (1.0 - smoothstep(0.96, 1.0, distance_from_landing));

	// Remap the authored wide fan into the same angle as each charge's hit area.
	float paint_angle = angle_ratio * 0.8726646;
	vec2 paint_uv = vec2(0.10, 0.50)
		+ vec2(cos(paint_angle) * 0.84, sin(paint_angle) * 0.50) * distance_from_landing;
	vec4 paint = texture(wave_art, paint_uv);

	float front = mix(0.12, 1.13, smoothstep(0.0, 0.48, progress));
	float reveal = 1.0 - smoothstep(front - 0.08, front + 0.08, distance_from_landing);
	float crest = 1.0 - smoothstep(0.02, 0.25, abs(distance_from_landing - front));
	float fade = 1.0 - smoothstep(0.43, 1.0, progress);
	float lift = crest * mix(0.56, 0.87, strength);
	vec3 crest_color = mix(vec3(1.0, 0.64, 0.29), vec3(1.0, 0.94, 0.70), strength);
	ALBEDO = mix(paint.rgb, crest_color, lift);
	ALPHA = paint.a * footprint * reveal * fade;
}
