shader_type canvas_item;
render_mode unshaded, blend_disabled;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float interior = art.a;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 delta = vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE;
			interior = min(interior, texture(TEXTURE, UV + delta).a);
		}
	}
	vec3 outline = vec3(0.188, 0.145, 0.165);
	vec3 skin = vec3(1.0, 0.980, 0.961);
	float ink = clamp((0.957 - art.r / max(art.a, 0.0001)) / 0.769, 0.0, 1.0);
	vec3 surface = mix(skin, outline, ink);
	float contour = art.a - interior;
	COLOR = vec4(mix(surface, outline, contour), art.a);
}
