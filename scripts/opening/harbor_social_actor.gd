extends "res://scripts/opening/harbor_npc.gd"
const SocialArt=preload("res://scripts/opening/harbor_social_art.gd")
var role:="coffee"
var action:="seated_rest"
var pose_index:=0
var sip_lift:=0.0
var time_phase:=0.0
var tick_count:=0
var cup: Node3D
var cup_rest:=Vector3.ZERO
var cup_mouth:=Vector3.ZERO
var saucer:=Vector3.ZERO
var brush: Node3D
var palette_prop: Node3D
var facing_side:="right"
func _ready() -> void:
 super._ready()
 set_meta("social_life_owned",true)
 if role=="coffee":sprite.pixel_size=.018;shadow.scale=Vector3(1.35,1,1.0)
func tick(_delta: float,camera: Camera3D,time_: float) -> void:
 actor_clock=time_;tick_count+=1;walking=false
 if role=="coffee":
  var cycle:=fposmod(time_+time_phase,10.6)
  sip_lift=0.0
  if cycle>=3.0 and cycle<4.4:sip_lift=smoothstep(3.0,4.4,cycle)
  elif cycle>=4.4 and cycle<5.65:sip_lift=1.0
  elif cycle>=5.65 and cycle<7.1:sip_lift=1.0-smoothstep(5.65,7.1,cycle)
  pose_index=0 if sip_lift<.12 else 1 if sip_lift<.48 else 2 if sip_lift<.86 else 3
  action="seated_sip" if sip_lift>.02 else "seated_rest"
  if is_instance_valid(cup):cup.position=cup_rest.lerp(cup_mouth,sip_lift)
  sprite.texture=SocialArt.frame(profile,role,facing_side,pose_index)
  sprite.global_basis=camera.global_basis;sprite.global_position=global_position+camera.global_basis.y*1.08
 else:
  pose_index=int(floor((time_+time_phase)*1.35))%3 if role=="painter" else int(floor((time_+time_phase)*.45))%2
  action="painting" if role=="painter" else "portrait_pose"
  facing=facing_side
  render_modular(camera,action,pose_index,"Noble" if role=="model" else "Middle")
  if is_instance_valid(brush):
   brush.rotation.z=.15+sin(time_*1.8)*.11;brush.global_position=modular_hand_world("right",.09)
  if is_instance_valid(palette_prop):palette_prop.global_position=modular_hand_world("left",.09)
