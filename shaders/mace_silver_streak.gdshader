shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;

uniform sampler2D streak_art : source_color, filter_nearest, repeat_disable;
uniform float opacity = 1.0;

void fragment() {
	vec4 paint = texture(streak_art, UV);
	float brightness = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(0.12, 0.33, 0.51), vec3(0.85, 0.99, 1.0), brightness);
	ALPHA = paint.a * opacity;
}
