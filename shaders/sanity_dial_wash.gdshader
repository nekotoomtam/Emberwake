shader_type canvas_item;
render_mode unshaded;

uniform float violet_fill = 0.0;
uniform float amber_fill = 0.0;

float wash(float depth, float fill, float reach) {
	float front = fill * reach;
	return fill * (1.0 - smoothstep(front * 0.24, front + 0.01, depth));
}

void fragment() {
	float depth = 1.0 - length(UV * 2.0 - 1.0);
	float inside = smoothstep(0.0, 0.065, depth);
	float violet = wash(depth, violet_fill, 0.60) * 0.78;
	float amber = wash(depth, amber_fill, 0.73) * 0.88;
	vec3 violet_color = vec3(0.43, 0.25, 0.52);
	vec3 amber_color = vec3(0.61, 0.30, 0.18);
	float alpha = amber + violet * (1.0 - amber);
	vec3 tint = (amber_color * amber + violet_color * violet * (1.0 - amber)) / max(alpha, 0.001);
	COLOR = vec4(tint, alpha * inside * 0.64);
}
