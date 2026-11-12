shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float clock = 0.0;
#include "harbor_sea_waves.gdshaderinc"
varying float patch_seed;
varying vec2 shore_world;
void vertex() {
 vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 patch_seed = COLOR.r;
 shore_world = world.xz;
 VERTEX.y += harbor_wave_displacement(world.xz, clock) + 0.010;
}
void fragment() {
 float phase = clock * 1.293;
 float cycle = fract(clock * (0.15 + patch_seed * 0.11) + patch_seed + sin(clock * 0.17 + patch_seed * 9.0) * 0.035);
 float advance = smoothstep(0.02, 0.62, cycle);
 float retreat = smoothstep(0.62, 1.0, cycle);
 float centre = mix(0.96, 0.025, advance) + retreat * 0.32;
 centre += 0.042 * sin(UV.x * 12.566371 + patch_seed * 6.283185 + phase);
 centre += 0.018 * sin(UV.x * 32.0 - phase * 0.65);
 float crest = 1.0 - smoothstep(0.032, 0.095, abs(UV.y - centre));
 float life = smoothstep(0.01, 0.12, cycle) * (1.0 - smoothstep(0.72, 1.0, cycle));
 float grains = sin(UV.x * 18.76 + patch_seed * 31.0);
 grains += 0.35 * sin(UV.x * 71.0 + phase * 2.0 + patch_seed * 13.0);
 float broken = smoothstep(-0.18, 0.52, grains);
 float ends = smoothstep(0.0, 0.15, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
 float impact = exp(-pow((cycle - 0.62) / 0.085, 2.0));
 float wash = (1.0 - smoothstep(0.015, 0.11, abs(UV.y - 0.025))) * impact;
 float backwash = crest * retreat * (1.0 - smoothstep(0.70, 1.0, cycle));
 float foam = max(crest * life * 0.70, wash * 0.95) * broken;
 float blue_crest = crest * life * 0.14 + backwash * 0.14;
 ALBEDO = mix(vec3(0.36, 0.64, 0.66), vec3(0.89, 0.95, 0.89), clamp(foam + impact * 0.22, 0.0, 1.0));
 float arriving_surge = 0.30 + 0.70 * smoothstep(-0.11,0.12,harbor_wave_displacement(shore_world,clock));
 ALPHA = clamp((foam + blue_crest) * ends * arriving_surge * 0.72, 0.0, 0.85);
 if (ALPHA < 0.015) { discard; }
 ROUGHNESS = 0.7;
}
