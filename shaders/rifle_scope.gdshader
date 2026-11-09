shader_type canvas_item;
render_mode unshaded;
uniform vec2 center=vec2(.5);
uniform vec2 axis=vec2(1,0);
uniform vec2 viewport_size=vec2(1280,800);
uniform float focus=0.0;
void fragment(){
 vec2 perpendicular=vec2(-axis.y,axis.x);
 float side=abs(dot((UV-center)*viewport_size,perpendicular));
 float unit=min(viewport_size.x,viewport_size.y);
 float aperture=mix(unit*.60,unit*.16,focus);
 float edge=smoothstep(aperture,aperture+unit*.08,side);
 COLOR=vec4(.025,.04,.055,edge*.68*focus);
}
