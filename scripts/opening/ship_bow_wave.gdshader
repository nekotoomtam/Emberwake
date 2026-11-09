shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float clock=0.0;
uniform float drive=0.0;
uniform float seed=0.0;
uniform float sea_clock=0.0;
#include "harbor_sea_waves.gdshaderinc"
void vertex(){
 float lift=sin(UV.y*3.141593);
 float bow=1.0-smoothstep(0.2,1.0,UV.x);
 float pulse=0.82+0.18*sin(clock*2.5-UV.x*14.0+seed);
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=harbor_wave_displacement(world.xz,sea_clock);
 VERTEX.y+=lift*(0.035+drive*(0.30+bow*0.60))*pulse;
 VERTEX.y+=0.012*sin(clock*1.9-UV.x*12.0+seed);
}
void fragment(){
 // Quantized grains retain the environment's pixel character, moving aft.
 vec2 cell=floor(UV*vec2(96.0,20.0));
 float flow=cell.x*1.73-clock*(5.0+drive*8.0)+seed;
 float grain=sin(flow+cell.y*2.37)*sin(cell.x*0.71+cell.y*1.91-clock*3.0);
 float crest_center=0.34+0.06*sin(UV.x*28.0-clock*3.0+seed);
 float crest=1.0-smoothstep(0.045,0.20,abs(UV.y-crest_center));
 float fragments=smoothstep(-0.55,0.25,grain);
 float outer=1.0-smoothstep(0.02,0.12,abs(UV.y-0.68-0.025*sin(UV.x*20.0-clock*2.5)));
 float white=max(crest*(0.65+fragments*0.35),outer*fragments*0.62);
 float bubbles=smoothstep(0.47,0.83,grain)*(1.0-smoothstep(0.4,0.95,UV.y))*0.65;
 float foam=max(white,bubbles);
 float ends=smoothstep(0.0,0.035,UV.x)*(1.0-smoothstep(0.72,1.0,UV.x));
 float across=smoothstep(0.0,0.10,UV.y)*(1.0-smoothstep(0.72,1.0,UV.y));
 float wash=(1.0-smoothstep(0.05,0.65,abs(UV.y-0.4)))*0.20;
 float water_body=pow(max(0.0,sin(UV.y*3.141593)),0.65);
 float raised_face=sin(UV.y*3.141593)*(0.75+0.25*sin(UV.x*17.0-clock*2.5));
 ALBEDO=mix(vec3(0.14,0.39,0.45),vec3(0.31,0.60,0.63),raised_face);
 ALBEDO=mix(ALBEDO,vec3(0.94,0.98,0.93),foam*0.86);
 ALPHA=(water_body*0.88+foam*0.30+wash)*ends*across*(0.15+drive*0.85);
 ROUGHNESS=0.8;
}
