extends CharacterBody3D
signal wrong_way_attempted
const PlazaProfile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const Directions=preload("res://scripts/opening/harbor_hero_appearance.gd")
const TravelLuggage=preload("res://scripts/opening/harbor_travel_luggage.gd")
const CityPose=preload("res://modular/scripts/city_npc_pose.gd")
var camera: Camera3D
var sprite: Sprite3D
var facing:="right"
var clock:=0.0
var enabled:=true
var visual_offset:=Vector3.ZERO
var _safe_position:=Vector3.ZERO
var wrong_way_latched:=false
var carrying_luggage:=false
var art_action:="idle"
var art_frame:=0
var modular_look: Dictionary={}
var modular_frame: Dictionary={}
func _ready() -> void:
 _safe_position=position
 collision_layer=2;collision_mask=1;floor_snap_length=.3;floor_max_angle=deg_to_rad(55)
 var col:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.height=1.4;shape.radius=.24;col.shape=shape;col.position.y=.7;add_child(col)
 sprite=Sprite3D.new();sprite.pixel_size=.018;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;add_child(sprite)
 for entry in [["harbor_left",KEY_A],["harbor_right",KEY_D],["harbor_up",KEY_W],["harbor_down",KEY_S]]:
  if not InputMap.has_action(entry[0]):
   InputMap.add_action(entry[0]);var key:=InputEventKey.new();key.physical_keycode=entry[1];InputMap.action_add_event(entry[0],key)
 update_art(0,Vector3.ZERO)
func _physics_process(delta: float) -> void:
 if not enabled:return
 var axis:=Input.get_vector("harbor_left","harbor_right","harbor_up","harbor_down")
 var right:=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
 var toward:=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
 var move: Vector3=(right*axis.x+toward*axis.y).limit_length(1)
 velocity.x=move.x*3.1;velocity.z=move.z*3.1
 velocity.y=-2 if is_on_floor() else velocity.y-18*delta
 var before:=position;move_and_slide()
 # The public plaza and connector join the original bounded quay/pier/deck.
 var on_quay: bool=position.x>=-17.4 and position.x<=PlazaProfile.QUAY_RECT.end.x-.2 and position.z>=2.5 and position.z<=PlazaProfile.QUAY_RECT.end.y
 var on_pier: bool=position.x>=4.8 and position.x<=9.2 and position.z>=-2.6 and position.z<=3.0
 var on_ramp: bool=position.x>=5.7 and position.x<=8.3 and position.z>=-4.8 and position.z<=.65
 var on_deck: bool=position.y>2.1 and position.x>=-4.5 and position.x<=19.2 and position.z>=-11.3 and position.z<=-3.8
 if not (PlazaProfile.contains_ground(position) or on_quay or on_pier or on_ramp or on_deck):
  if PlazaProfile.wrong_way_exit(position) and move.length_squared()>.01 and not wrong_way_latched:
   wrong_way_latched=true;wrong_way_attempted.emit()
  position=before;velocity=Vector3.ZERO
 if PlazaProfile.rearm_wrong_way(position):wrong_way_latched=false
 var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.35,global_position-Vector3.UP*.45,1,[get_rid()])
 var support: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
 if support.is_empty() or Vector3(support.get("normal",Vector3.ZERO)).y<.5:
  position=_safe_position;velocity=Vector3.ZERO
 else:_safe_position=position
 update_art(delta,move)
func update_art(delta: float,move: Vector3) -> void:
 clock+=delta
 if move.length_squared()>.01:facing=Directions.choose(move,camera,facing)
 var action: String="walk" if move.length_squared()>.01 else "idle"
 art_action=action
 if modular_look.is_empty():
  var frames: SpriteFrames=Directions.frames(facing)
  art_frame=int(clock*(8 if action=="walk" else 2))%frames.get_frame_count(action)
  sprite.texture=TravelLuggage.carry_texture(facing,action,art_frame) if carrying_luggage else frames.get_frame_texture(action,art_frame)
 else:
  art_frame=int(clock*8)%4 if action=="walk" else 0
  var pose_action: String="luggage_"+action if carrying_luggage else action
  var blink:=action=="idle" and fposmod(clock+1.0,5.3)<.14
  modular_frame=CityPose.frame(modular_look,facing,pose_action,art_frame,blink)
  sprite.texture=modular_frame.texture
 sprite.global_basis=camera.global_basis;sprite.global_position=global_position+Vector3.UP*.045+visual_offset+camera.global_basis.y*.864

func modular_grip() -> Vector3:
 return CityPose.right_grip(modular_frame,sprite.global_basis,sprite.global_position)
