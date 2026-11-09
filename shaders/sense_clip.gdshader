shader_type canvas_item;
render_mode unshaded;
uniform vec2 world_origin;
uniform vec2 world_dx;
uniform vec2 world_dy;
uniform vec2 player_ground;
uniform vec2 facing;
uniform float cone_cos=0.5;
void fragment(){
 vec2 ground=world_origin+SCREEN_UV.x*world_dx+SCREEN_UV.y*world_dy;
 vec2 offset=ground-player_ground;
 if(length(offset)<0.00001 || dot(normalize(offset),facing)>=cone_cos) discard;
}
