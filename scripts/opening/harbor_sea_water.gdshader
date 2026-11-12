shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform float clock=0.0;
uniform float mean_level=-0.85;
uniform vec4 waterline[7];
uniform bool player_reflection_visible=false;
uniform sampler2D player_reflection_texture : source_color,filter_linear,repeat_disable;
uniform vec3 player_reflection_origin;
uniform vec3 player_reflection_right;
uniform vec3 player_reflection_up;
uniform vec2 player_reflection_size=vec2(1.0);
#include "harbor_sea_waves.gdshaderinc"
varying vec2 water_world;
float water_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float water_noise(vec2 p){
 vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(water_hash(i),water_hash(i+vec2(1,0)),f.x),mix(water_hash(i+vec2(0,1)),water_hash(i+vec2(1,1)),f.x),f.y);
}
float distance_to_quay(vec2 p){
 float nearest=100.0;
 for(int i=0;i<7;i++){
  vec2 a=waterline[i].xy;
  vec2 span=waterline[i].zw-a;
  float along=clamp(dot(p-a,span)/max(dot(span,span),0.001),0.0,1.0);
  nearest=min(nearest,length(p-a-span*along));
 }
 return nearest;
}
float stone_shade(vec2 p){
 vec2 cell=floor(p);
 float seed=water_hash(cell);
 vec2 center=vec2(0.25)+0.5*vec2(water_hash(cell+11.0),water_hash(cell-17.0));
 vec2 local=fract(p)-center;
 float angle=seed*6.283;
 vec2 axis=vec2(cos(angle),sin(angle));
 local=vec2(dot(local,axis),dot(local,vec2(-axis.y,axis.x)));
 float radius=mix(0.10,0.29,water_hash(cell+29.0));
 float shape=max(abs(local.x)*0.83,abs(local.y+local.x*0.18)*1.22);
 shape=max(shape,abs(local.x-local.y)*0.71);
 shape+=(water_noise(p*16.0)-0.5)*0.058;
 float edge=1.0-smoothstep(radius*0.83,radius,shape);
 float facet=smoothstep(-0.04,0.06,local.y-local.x*0.55);
 float grain=mix(0.72,1.0,water_noise(p*22.0));
 return edge*mix(0.40,0.95,facet)*grain*smoothstep(0.34,0.52,seed);
}
float caustic_light(vec2 p,float seconds){
 vec2 drift=p+vec2(seconds*0.24,-seconds*0.18);
 float breakup=water_noise(drift*2.1);
 float a=sin(p.x*3.8+p.y*2.5+seconds*1.25);
 float b=sin(p.x*2.0-p.y*4.1-seconds*0.93);
 float fold=abs(sin(p.x*4.2-p.y*1.5+a*1.4+b*0.8+seconds*0.48+breakup*1.5));
 return pow(1.0-fold,7.0)*smoothstep(-0.35,0.85,a+b)*smoothstep(0.32,0.66,breakup);
}
vec3 player_reflection(vec3 water,vec3 surface,vec3 eye,vec2 ripples){
 if(!player_reflection_visible || distance(surface.xz,player_reflection_origin.xz)>9.0) return water;
 // Trace the reflected view ray back to the current player sprite.
 vec3 ray=reflect(-eye,normalize(vec3(ripples.x*0.007,1.0,ripples.y*0.009)));
 vec3 billboard_normal=cross(player_reflection_right,player_reflection_up);
 float alignment=dot(ray,billboard_normal);
 if(abs(alignment)<0.001) return water;
 float travel=dot(player_reflection_origin-surface,billboard_normal)/alignment;
 if(travel<=0.0) return water;
 vec3 hit=surface+ray*travel-player_reflection_origin;
 vec2 uv=vec2(dot(hit,player_reflection_right),-dot(hit,player_reflection_up))/player_reflection_size+0.5;
 uv.x+=ripples.x*0.011;
 if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return water;
 vec4 actor=texture(player_reflection_texture,uv);
 vec3 reflected=mix(water*0.45,actor.rgb*vec3(0.56,0.74,0.82),0.68);
 float opacity=actor.a*0.60*(1.0-smoothstep(2.5,6.0,travel));
 return mix(water,reflected,opacity);
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
 vec3 water=mix(vec3(0.045,0.18,0.30),vec3(0.13,0.37,0.49),tone);
 float near_camera=1.0-smoothstep(34.0,92.0,distance_);
 if(near_camera>0.0){
  float shore=distance_to_quay(p);
  float shallows=(1.0-smoothstep(0.4,14.0,shore+water_noise(p*0.18)*3.2))*near_camera;
  if(shallows>0.0){
   vec2 bed=p+wave.yz*0.48+eye.xz*0.22;
   float sand=water_noise(bed*0.44)*0.65+water_noise(bed*2.6)*0.35;
   float stones=max(stone_shade(bed*0.58),stone_shade(bed*1.18+vec2(13.0,7.0))*0.58);
   vec3 seabed=mix(vec3(0.035,0.40,0.49),vec3(0.17,0.72,0.65),sand);
   seabed=mix(seabed,vec3(0.025,0.18,0.23),stones*0.67);
   seabed+=vec3(0.25,0.41,0.29)*caustic_light(bed,clock)*0.26;
   water=mix(water,seabed,shallows*mix(0.87,0.28,fresnel));
  }
 }
 water=mix(water,vec3(0.42,0.63,0.73),fresnel*0.23);
 vec2 flow=p+vec2(clock*2.9,clock*0.25);
 float broken=water_noise(flow*0.85)*0.65+water_noise(flow*2.1)*0.35;
 float crest=smoothstep(0.12,0.40,wave.x)*smoothstep(0.45,0.72,broken);
 float whitecaps=crest*detail*harbor_shelter(p);
 vec2 ripples=vec2(sin(dot(p,vec2(4.8,2.9))+clock*1.8+broken*2.5),
                   sin(dot(p,vec2(-2.1,6.0))-clock*1.2));
 vec3 ripple_normal=normalize(normal_+vec3(ripples.x,0.0,ripples.y)*0.036*near_camera);
 float sparkle=pow(max(dot(reflect(-light_,ripple_normal),eye),0.0),36.0)*0.17*detail;
 water=player_reflection(water,vec3(p.x,mean_level+wave.x,p.y),eye,ripples);
 ALBEDO=mix(water,vec3(0.78,0.88,0.87),whitecaps*0.50)+vec3(1.0,0.91,0.75)*sparkle;
 ROUGHNESS=0.48;
}
