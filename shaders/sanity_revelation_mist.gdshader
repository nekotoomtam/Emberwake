shader_type canvas_item;
render_mode unshaded;

uniform float perception : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float strength = COLOR.a;
	vec2 point = abs(UV * 2.0 - 1.0);
	float edge = max(point.x, point.y) + min(point.x, point.y) * 0.16;
	float reach = mix(0.83, 0.58, strength);
	float drift = sin(UV.x * 15.0 + UV.y * 10.0 + TIME * 0.65);
	float wisps = sin(UV.y * 20.0 - TIME * 0.45 + drift * 1.5);
	float mist = smoothstep(reach, 1.1, edge + (drift + wisps) * 0.024);
	vec3 violet = mix(vec3(0.32, 0.19, 0.49), vec3(0.58, 0.35, 0.72), 0.5 + 0.5 * wisps);
	float mist_alpha = mist * strength * 0.48;
	float tint_alpha = perception * 0.14 * (1.0 - mist_alpha);
	float alpha = mist_alpha + tint_alpha;
	vec3 tint = vec3(0.42, 0.36, 0.56);
	COLOR = vec4(mix(tint, violet, mist_alpha / max(alpha, 0.001)), alpha);
}
