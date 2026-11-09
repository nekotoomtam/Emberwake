extends RefCounted

## Clear maritime daylight. The clouds live on the sky dome, so they retain their
## distant scale throughout the harbor fly-in without adding scene geometry.
static func make_sky() -> Sky:
 var shader := Shader.new()
 shader.code = """shader_type sky;
render_mode disable_fog;

uniform vec4 zenith_color : source_color = vec4(0.17, 0.44, 0.78, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.53, 0.76, 0.90, 1.0);
uniform vec4 cloud_light : source_color = vec4(0.99, 0.985, 0.95, 1.0);
uniform vec4 cloud_body : source_color = vec4(0.91, 0.95, 0.96, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.67, 0.79, 0.85, 1.0);

float hash21(vec2 p) {
 p = fract(p * vec2(123.34, 456.21));
 p += dot(p, p + 45.32);
 return fract(p.x * p.y);
}

float noise2(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
            mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float billow(vec2 p) {
 return noise2(p) * 0.57 + noise2(p * 2.07 + 11.4) * 0.28
      + noise2(p * 4.13 - 6.2) * 0.15;
}

float puff(vec2 p, vec2 center, vec2 radius) {
 return 1.0 - length((p - center) / radius);
}

// A broad, quiet underside and unequal overlapping turrets make each bank read
// as a cumulus formation rather than a row of separate round primitives.
vec4 cloud_bank(vec2 angle, vec2 center, vec2 size, float seed) {
 float dx = atan(sin(angle.x - center.x), cos(angle.x - center.x));
 vec2 q = vec2(dx, angle.y - center.y) / size;
 if (abs(q.x) > 1.3 || abs(q.y) > 1.3) {
  return vec4(0.0);
 }
 vec2 p = q;
 p.x += (noise2(q * 3.3 + seed) - 0.5) * 0.12;
 p.y += (noise2(q * 4.1 - seed) - 0.5) * 0.09;
 float s = sin(seed * 2.31);
 float shape = puff(p, vec2(-0.03, -0.25), vec2(0.91, 0.30));
 shape = max(shape, puff(p, vec2(-0.66, -0.08), vec2(0.31, 0.35)));
 shape = max(shape, puff(p, vec2(-0.38, 0.09 + s * 0.17), vec2(0.35, 0.50 + s * 0.10)));
 shape = max(shape, puff(p, vec2(-0.04 + s * 0.08, 0.24 - s * 0.15), vec2(0.36, 0.65 - s * 0.12)));
 shape = max(shape, puff(p, vec2(0.32, 0.06 + s * 0.17), vec2(0.35, 0.47 + s * 0.13)));
 shape = max(shape, puff(p, vec2(0.67, -0.13), vec2(0.31, 0.30)));
 float detail = billow(p * 6.5 + vec2(seed, seed * 0.73));
 shape += (detail - 0.5) * 0.15;
 float alpha = smoothstep(-0.055, 0.060, shape);
 // The slightly translucent outer edge keeps the silhouette soft, while the
// opaque center and blue-gray underside preserve crisp clear-weather volume.
 vec2 volume_uv = p * 5.0 + vec2(seed * 0.6, seed);
 float volume = billow(volume_uv);
 float sunward_volume = billow(volume_uv + vec2(-0.38, 0.52));
 float soft_volume = clamp(0.58 + (sunward_volume - volume) * 1.65, 0.15, 0.95);
 float light = smoothstep(-0.52, 0.65, p.y + detail * 0.16);
 float sculpted_light = clamp(light * 0.76 + soft_volume * 0.24, 0.0, 1.0);
 vec3 color = mix(cloud_shadow.rgb, cloud_body.rgb, smoothstep(0.0, 0.68, sculpted_light));
 color = mix(color, cloud_light.rgb, smoothstep(0.54, 0.98, sculpted_light));
 float pockets = smoothstep(0.40, 0.67, volume) * (1.0 - smoothstep(-0.12, 0.62, p.y));
 color = mix(color, cloud_shadow.rgb, pockets * 0.17);
 return vec4(color, alpha * 0.99);
}

void sky() {
 vec3 dir = normalize(EYEDIR);
 float elevation = asin(clamp(dir.y, -1.0, 1.0));
 vec2 angle = vec2(atan(dir.x, -dir.z), elevation);
 float blue_height = pow(clamp(dir.y, 0.0, 1.0), 0.48);
 vec3 color = mix(horizon_color.rgb, zenith_color.rgb, blue_height);
 // Below the sea line uses the same clean blue family; no white horizon veil.
 color = mix(color, horizon_color.rgb * 0.82, 1.0 - smoothstep(-0.35, 0.0, dir.y));
 vec3 sun_dir = normalize(vec3(-0.55, 0.73, -0.55));
 float sun_dot = max(dot(dir, sun_dir), 0.0);
 color += vec3(0.10, 0.075, 0.032) * pow(sun_dot, 90.0);
 color += vec3(1.35, 1.16, 0.80) * smoothstep(0.99994, 0.99997, sun_dot);

 vec4 c;
 // Smaller distant banks sit above a narrow band of open blue at the horizon.
 c = cloud_bank(angle, vec2(-2.77, 0.100), vec2(0.24, 0.060), 8.1); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(-1.78, 0.105), vec2(0.22, 0.065), 3.2); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(-0.83, 0.082), vec2(0.23, 0.052), 5.7); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(0.08, 0.115), vec2(0.26, 0.075), 1.4); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(0.53, 0.075), vec2(0.15, 0.045), 6.8); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(1.19, 0.095), vec2(0.27, 0.059), 7.5); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(2.23, 0.110), vec2(0.31, 0.063), 2.1); color = mix(color, c.rgb, c.a);

 // Uneven higher formations frame the opening views with generous blue gaps.
 c = cloud_bank(angle, vec2(-2.34, 0.390), vec2(0.39, 0.145), 4.1); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(-1.24, 0.345), vec2(0.33, 0.130), 6.3); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(-0.34, 0.320), vec2(0.35, 0.165), 2.6); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(0.75, 0.420), vec2(0.43, 0.155), 9.2); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(1.78, 0.315), vec2(0.34, 0.125), 5.2); color = mix(color, c.rgb, c.a);
 c = cloud_bank(angle, vec2(2.88, 0.405), vec2(0.42, 0.150), 7.8); color = mix(color, c.rgb, c.a);
 COLOR = color;
}
"""
 var material := ShaderMaterial.new()
 material.shader = shader
 var sky := Sky.new()
 sky.sky_material = material
 sky.radiance_size = Sky.RADIANCE_SIZE_256
 sky.process_mode = Sky.PROCESS_MODE_QUALITY
 return sky
