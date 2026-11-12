shader_type canvas_item;

uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec2 local_uv = (UV - atlas_region.xy) / atlas_region.zw;
	float canopy_edge = sin(local_uv.x * 41.0) * 0.013 + sin(local_uv.x * 93.0) * 0.007;
	float depth = local_uv.y + canopy_edge;
	COLOR.a *= 1.0 - smoothstep(0.91, 0.99, depth);
	COLOR.rgb *= mix(1.0, 0.91, smoothstep(0.78, 0.99, local_uv.y));
}
