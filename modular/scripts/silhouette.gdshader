shader_type canvas_item;
render_mode unshaded;

uniform vec4 ink : source_color = vec4(0.318, 0.161, 0.102, 1.0);

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec2 dx = vec2(TEXTURE_PIXEL_SIZE.x, 0.0);
	vec2 dy = vec2(0.0, TEXTURE_PIXEL_SIZE.y);
	// Keep drawn ink and the silhouette. Only shade fill newly exposed at a cut cap.
	if (pixel.a > 0.5 && pixel.r > 0.65) {
		float adjacent = min(
			min(texture(TEXTURE, UV - dx).a, texture(TEXTURE, UV + dx).a),
			min(texture(TEXTURE, UV - dy).a, texture(TEXTURE, UV + dy).a)
		);
		if (adjacent < 0.5) {
			pixel = ink;
		}
	}
	COLOR = pixel;
}
