shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D crack_art : source_color, filter_linear_mipmap, repeat_disable;
uniform int phase = 0;
uniform float progress = 0.0;

void fragment() {
	vec4 art = texture(crack_art, UV);
	vec2 radial = (UV - vec2(0.5)) * 2.0;
	float distance_from_center = length(radial);
	float footprint = 1.0 - smoothstep(0.96, 1.02, distance_from_center);
	float opacity = 1.0;
	float flash = 0.0;
	vec3 color = art.rgb;

	if (phase == 0) {
		float edge = mix(0.17, 1.14, progress);
		opacity = 1.0 - smoothstep(edge - 0.13, edge, distance_from_center);
	} else if (phase == 1) {
		float edge = mix(1.02, 0.12, progress);
		float band = 1.0 - smoothstep(0.02, 0.22, abs(distance_from_center - edge));
		opacity = 0.35 + band * 0.5;
		color = mix(art.rgb, vec3(0.24, 0.75, 0.58), band * 0.75);
	} else {
		float edge = mix(0.22, 1.28, min(1.0, progress * 2.0));
		float band = 1.0 - smoothstep(0.03, 0.35, abs(distance_from_center - edge));
		float wake = (1.0 - smoothstep(edge - 0.26, edge + 0.02, distance_from_center)) * 0.35;
		float fade = 1.0 - smoothstep(0.47, 1.0, progress);
		opacity = (0.34 + max(band, wake) * 0.66) * fade;
		color = mix(art.rgb, mix(vec3(0.12, 0.73, 0.52), vec3(0.81, 1.0, 0.88), band), max(band, wake));

		float kick = 1.0 - smoothstep(0.02, 0.36, progress);
		float core_radius = mix(0.24, 0.63, smoothstep(0.0, 0.19, progress));
		float core = 1.0 - smoothstep(0.03, core_radius, distance_from_center);
		float angle = atan(radial.y, radial.x + 0.00001);
		float spokes = pow(0.5 + 0.5 * sin(angle * 9.0 + 1.3 * sin(angle * 3.0)), 9.0);
		float rays = spokes * (1.0 - smoothstep(0.16, 0.81, distance_from_center));
		flash = clamp((core * 0.84 + rays * 0.61) * kick, 0.0, 1.0);
	}

	float veins = art.a * opacity;
	float coverage = flash + veins * (1.0 - flash);
	vec3 flash_color = mix(vec3(0.21, 0.76, 0.59), vec3(0.98, 1.0, 0.87), flash);
	ALBEDO = mix(color, flash_color, flash / max(coverage, 0.00001));
	ALPHA = coverage * footprint;
}
