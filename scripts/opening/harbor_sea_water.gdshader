shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform float clock=0.0;
uniform float mean_level=-0.85;
#include "harbor_sea_waves.gdshaderinc"
varying vec2 water_world;
float water_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float water_noise(vec2 p){
 vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(water_hash(i),water_hash(i+vec2(1,0)),f.x),mix(water_hash(i+vec2(0,1)),water_hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 water_world=world.xz;
 VERTEX.y+=harbor_wave_displacement(world.xz,clock);
}
void fragment(){
 vec2 p=water_world;
 float distance_=length(p-CAMERA_POSITION_WORLD.xz);
 float detail=1.0-smoothstep(100.0,500.0,distance_);
 vec3 wave=harbor_water_sample(p,clock);
 vec3 normal_=normalize(vec3(-wave.y,1.0,-wave.z));
 vec3 light_=normalize(vec3(-0.4,0.85,0.45));
 vec3 eye=normalize(CAMERA_POSITION_WORLD-vec3(p.x,mean_level+wave.x,p.y));
 float face=dot(normal_,light_);
 float fresnel=pow(1.0-max(dot(normal_,eye),0.0),3.0);
 float tone=clamp(0.43+((face-0.82)*1.65+wave.x*0.20)*detail,0.08,0.9);
 vec3 water=mix(vec3(0.075,0.255,0.31),vec3(0.245,0.49,0.54),tone);
 water=mix(water,vec3(0.38,0.59,0.65),fresnel*0.26);
 vec2 flow=p+vec2(clock*2.9,clock*0.25);
 float broken=water_noise(flow*0.85)*0.65+water_noise(flow*2.1)*0.35;
 float crest=smoothstep(0.12,0.40,wave.x)*smoothstep(0.45,0.72,broken);
 float whitecaps=crest*detail*harbor_shelter(p);
 float sparkle=pow(max(dot(reflect(-light_,normal_),eye),0.0),45.0)*0.15*detail;
 ALBEDO=mix(water,vec3(0.78,0.88,0.87),whitecaps*0.55)+vec3(sparkle);
 ROUGHNESS=0.48;
}
