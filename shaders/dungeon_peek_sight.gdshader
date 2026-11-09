shader_type canvas_item;

uniform vec2 world_origin;
uniform vec2 world_dx;
uniform vec2 world_dy;
uniform vec2 eyes;
uniform vec2 forward = vec2(1.0, 0.0);
uniform float sight_length = 15.5;
uniform sampler2D ray_lengths : filter_nearest, repeat_disable;

void fragment() {
	vec2 ground = world_origin + UV.x * world_dx + UV.y * world_dy;
	vec2 offset = ground - eyes;
	float ahead = dot(offset, forward);
	float side = abs(dot(offset, vec2(-forward.y, forward.x)));
	float depth = clamp(ahead / sight_length, 0.0, 1.0);
	float half_width = mix(0.18, 2.15, depth);
	float window = (1.0 - smoothstep(half_width - 0.12, half_width + 0.27, side));
	window *= smoothstep(0.0, 0.15, ahead);
	float distance_from_eye = length(offset);
	float ray_index = fract(atan(offset.y, offset.x) / 6.2831853 + 1.0);
	float stop = texture(ray_lengths, vec2(ray_index, 0.5)).r * sight_length;
	window *= 1.0 - smoothstep(max(0.0, stop - 0.22), stop + 0.09, distance_from_eye);
	COLOR = vec4(0.018, 0.026, 0.028, 1.0 - window);
}
