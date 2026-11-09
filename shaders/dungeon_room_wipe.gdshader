shader_type canvas_item;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float progress = 0.0;

void fragment() {
	float span = abs(direction.x) + abs(direction.y);
	float position_on_path = dot(UV - vec2(0.5), direction) / span + 0.5;
	float edge = 0.055;
	float front = mix(-edge, 1.0 + edge, fract(progress));
	float passed = 1.0 - smoothstep(front - edge, front + edge, position_on_path);
	float darkness = progress < 1.0 ? passed : 1.0 - passed;
	COLOR = vec4(0.0, 0.0, 0.0, progress >= 2.0 ? 0.0 : darkness);
}
