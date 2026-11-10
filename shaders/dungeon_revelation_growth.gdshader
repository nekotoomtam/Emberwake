shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_prepass_alpha;

uniform vec2 observer = vec2(0.0);
uniform sampler2D eye_tissue : source_color, filter_nearest, repeat_disable;

float lobe(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.68, 1.0, length((p - center) / radius));
}

void fragment() {
	float kind = COLOR.r;
	float phase = COLOR.b;
	float pulse = 0.5 + 0.5 * sin(TIME * 2.1 + phase * 1.3);
	vec3 tone;
	float coverage;

	if (kind < 0.25) {
		vec2 p = (floor(UV * 32.0) + 0.5) / 16.0 - 1.0;
		p /= 0.91 + pulse * 0.09;
		p.x *= mix(-1.0, 1.0, step(0.5, phase));
		float nodules = lobe(p, vec2(-0.46, 0.12), vec2(0.27, 0.40));
		nodules = max(nodules, lobe(p, vec2(-0.04, -0.22), vec2(0.33, 0.47)));
		nodules = max(nodules, lobe(p, vec2(0.37, 0.11), vec2(0.30, 0.39)));
		nodules = max(nodules, lobe(p, vec2(0.12, 0.49), vec2(0.20, 0.27)));
		float sheen = max(lobe(p, vec2(-0.51, 0.01), vec2(0.11, 0.15)),
			lobe(p, vec2(-0.12, -0.36), vec2(0.15, 0.20)));
		sheen = max(sheen, lobe(p, vec2(0.30, -0.03), vec2(0.11, 0.14)));
		float light = smoothstep(-0.15, 0.86, nodules * 0.65 - p.y * 0.43);
		tone = mix(vec3(0.22, 0.083, 0.091), vec3(0.52, 0.24, 0.21), light);
		tone += vec3(0.16, 0.09, 0.07) * sheen;
		coverage = nodules;
	} else if (kind < 0.75) {
		vec2 patch_uv = (floor(UV * 64.0) + 0.5) / 64.0;
		vec2 patch = patch_uv * 2.0 - 1.0;
		vec2 p = patch * 1.72;
		float timer = fract(TIME / mix(4.4, 7.2, phase) + phase);
		float blink = 1.0 - 0.92 * (1.0 - smoothstep(0.0, 0.045, abs(timer - 0.78)));
		p.y += (p.x * 0.18) * sin(phase * 6.28);
		float lens = abs(p.y) + pow(abs(p.x), 1.5) * 0.80;
		float aperture = abs(p.y + 0.025) / blink + pow(abs(p.x), 1.6) * 0.88;
		float eye = 1.0 - smoothstep(0.35, 0.42, aperture);
		vec2 look = observer - UV2;
		float iris_x = clamp(look.x / max(length(look), 0.1), -1.0, 1.0) * 0.19;
		float iris = length(vec2((p.x - iris_x) * 1.46, p.y * 0.90));
		vec3 iris_color = mix(vec3(0.10, 0.056, 0.05), vec3(0.55, 0.32, 0.24), step(0.105, iris));
		vec3 eyeball = mix(iris_color, vec3(0.66, 0.52, 0.44), step(0.225, iris));
		float lid = (1.0 - smoothstep(0.02, 0.085, abs(lens - 0.48))) * 0.74;
		float side = mix(-1.0, 1.0, step(0.5, phase));
		float x = patch.x * side;
		float bend = sin(x * 4.6 + phase * 6.28) * abs(x) * 0.26;
		float y = patch.y - bend;
		vec2 tissue_uv = vec2(x * 0.48 + 0.5, y * 0.44 + 0.53);
		vec3 tissue = texture(eye_tissue, tissue_uv).rgb;
		float tip = mix(0.74, 0.94, phase) + x * 0.10;
		float root_taper = 1.0 - smoothstep(tip - 0.31, tip, abs(x));
		float reach = mix(0.34, 0.62, phase);
		float pocket = (1.0 - smoothstep(0.12, reach, abs(y))) * root_taper;
		float split = abs(x) * (0.35 + 0.14 * sin(x * 8.0));
		float strands = min(abs(y - split), abs(y + split * 0.73));
		float forks = (1.0 - smoothstep(0.023, 0.088, strands)) * root_taper * smoothstep(0.15, 0.59, abs(x));
		vec3 fold = mix(vec3(0.26, 0.22, 0.16), tissue * (1.26 + pulse * 0.07), pocket * 0.83 + forks * 0.13);
		fold = mix(fold, vec3(0.38, 0.19, 0.18), lid * 0.56 + forks * 0.29);
		tone = mix(fold, eyeball, eye);
		float seam = (1.0 - smoothstep(0.24, 0.61, lens)) * 0.82;
		coverage = max(eye, max(max(pocket * 0.74, forks * 0.66), seam));
	} else {
		vec2 uv = (floor(UV * vec2(112.0, 36.0)) + 0.5) / vec2(112.0, 36.0);
		float y = uv.y * 2.0 - 1.0;
		float spine = 0.19 * sin(uv.x * 13.0 + phase * 6.28);
		float width = 0.46 * sin(uv.x * 3.14);
		float upper = spine + width * (0.74 + 0.27 * sin(uv.x * 20.0));
		float lower = spine - width * (0.83 + 0.31 * cos(uv.x * 17.0));
		float thread = min(abs(y - spine), min(abs(y - upper), abs(y - lower)));
		float cross = abs(sin(uv.x * 42.0 + y * (6.0 + 3.0 * sin(uv.x * 15.0))));
		float inside = smoothstep(lower - 0.12, lower + 0.04, y) * (1.0 - smoothstep(upper - 0.04, upper + 0.12, y));
		float cord = 1.0 - smoothstep(0.022, 0.084, thread);
		float fibers = (1.0 - smoothstep(0.05, 0.38, cross)) * inside;
		float skin = 0.41 * inside * (1.0 - smoothstep(0.15, 0.50, abs(y - spine)));
		vec3 tissue = texture(eye_tissue, vec2(uv.x, 0.53 + (y - spine) * 0.40)).rgb;
		vec3 ground = mix(vec3(0.25, 0.20, 0.15), tissue * 1.35, inside);
		tone = mix(ground, vec3(0.41, 0.213, 0.18), max(cord, fibers * 0.65) * (0.78 + pulse * 0.22));
		float taper = smoothstep(0.0, 0.12, min(uv.x, 1.0 - uv.x));
		coverage = max(max(cord * 0.85, fibers * 0.72), skin) * taper;
		if (COLOR.a > 0.25) {
			float ripple = sin(uv.x * 21.0 + phase * 9.0) * 0.13 + cos(uv.x * 43.0 - y * 5.0) * 0.06;
			float edge = 0.69 + ripple + sin(uv.x * 3.14) * 0.08;
			float sheet = 1.0 - smoothstep(edge - 0.25, edge, abs(y - spine));
			float grain = sin(uv.x * 27.0 + y * 9.0) * cos(y * 13.0 - uv.x * 19.0 + phase * 6.28);
			float islands = smoothstep(-0.45, 0.37, grain);
			float growth = sheet * (COLOR.a > 0.75 ? mix(0.18, 0.64, islands) : mix(0.50, 0.72, islands));
			tone = mix(tissue * 1.54, vec3(0.43, 0.22, 0.18), cord * 0.46 + fibers * 0.18);
			coverage = max(coverage * 0.71, growth * taper);
		}
	}

	ALBEDO = tone * COLOR.g;
	ALPHA = coverage;
}
