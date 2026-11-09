// Irregular, short-crested wave packets; dominant travel is shoreward -X.
float harbor_shelter(vec2 p){
 float land=max(p.x+19.55,p.y-17.5);
 vec2 d=abs(p-vec2(1.225,8.75))-vec2(20.775,6.65);
 float quay=length(max(d,vec2(0.0)))+min(max(d.x,d.y),0.0);
 float pier_z=min(min(abs(p.y+29.0),abs(p.y+72.0)),min(abs(p.y+110.0),min(abs(p.y+148.0),abs(p.y+186.0))));
 float pier=max(abs(p.x-1.65)-21.35,pier_z-4.2);
 return mix(0.45,1.0,smoothstep(2.0,20.0,min(land,min(quay,pier))));
}
vec3 harbor_wave(vec2 p,float seconds,vec2 d,float k,float amplitude,float omega,float wave_seed){
 vec2 cross_d=vec2(-d.y,d.x);
 float along=dot(p,d);float across=dot(p,cross_d);
 float phase=along*k-seconds*omega+wave_seed;
 float packet=across*0.113+along*0.027-seconds*0.173+wave_seed*2.13;
 float group=0.68+0.32*sin(packet);
 float shape=sin(phase)+0.23*sin(phase*2.0);
 float derivative=cos(phase)+0.46*cos(phase*2.0);
 vec2 slope=amplitude*(group*derivative*k*d+0.32*cos(packet)*shape*(cross_d*0.113+d*0.027));
 return vec3(amplitude*group*shape,slope);
}
vec3 harbor_water_sample(vec2 p,float seconds){
 vec3 total=vec3(0.0);
 total+=harbor_wave(p,seconds,vec2(-0.991655617,0.128915230),0.289547710,0.250000000,1.205985664,0.310000000);
 total+=harbor_wave(p,seconds,vec2(-0.955157326,-0.296098771),0.439383588,0.180000000,1.640518357,2.140000000);
 total+=harbor_wave(p,seconds,vec2(-0.865031189,0.501718090),0.690459924,0.115000000,2.046640165,4.920000000);
 total+=harbor_wave(p,seconds,vec2(-0.992876838,-0.119145221),0.997331001,0.075000000,2.607130833,1.180000000);
 total+=harbor_wave(p,seconds,vec2(-0.921982106,0.387232484),1.495996502,0.045000000,3.324436670,5.670000000);
 total+=harbor_wave(p,seconds,vec2(-0.716994919,-0.697078393),2.243994753,0.025000000,4.106657064,3.830000000);
 total+=harbor_wave(p,seconds,vec2(-0.998752339,0.049937617),0.200740745,0.120000000,0.971126013,5.130000000);
 total+=harbor_wave(p,seconds,vec2(-0.901523057,-0.432731068),0.541653906,0.065000000,1.810716227,1.910000000);

 float factor=harbor_shelter(p);total*=factor;
 if(total.x>0.0){
  float exposure=(factor-0.45)/0.55;
  float crest=0.23*(1.0-exp(-total.x/0.23));
  total.yz*=mix(exp(-total.x/0.23),1.0,exposure);
  total.x=mix(crest,total.x,exposure);
 }
 return total;
}
float harbor_wave_displacement(vec2 p,float seconds){return harbor_water_sample(p,seconds).x;}
