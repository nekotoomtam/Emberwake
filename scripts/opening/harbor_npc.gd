extends Node3D
const CityPose=preload("res://modular/scripts/city_npc_pose.gd")
const Directions=preload("res://scripts/hero_directions.gd")
var profile: Dictionary={}
var modular_look: Dictionary={}
var modular_frame: Dictionary={}
var route: Array[Vector3]=[]
var speed:=.85
var work:=false
var facing:="front"
var aim:=Vector3.BACK
var sprite: Sprite3D
var shadow: MeshInstance3D
var _target:=1
var _wait:=0.0
var _arrived:=false
var carrying:=true
var walking:=false
var actor_clock:=0.0
var native_load: Node3D
var human_blocker: AnimatableBody3D
var _human_shape: CollisionShape3D
var _route_shape: CapsuleShape3D
func _ready() -> void:
 if profile.get("carry",false):profile.native_cargo=true
 sprite=Sprite3D.new();sprite.pixel_size=.018;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;add_child(sprite)
 shadow=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=.22;disc.bottom_radius=.22;disc.height=.004;disc.radial_segments=12;shadow.mesh=disc;shadow.position.y=.055
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(0,.05,.07,.12);shadow.material_override=mat;add_child(shadow)
 if not route.is_empty():position=route[0]
 _wait=float(profile.get("phase",0))*.15
 human_blocker=AnimatableBody3D.new();human_blocker.name="HumanFootprint";human_blocker.sync_to_physics=false;human_blocker.collision_layer=1;human_blocker.collision_mask=3;human_blocker.add_to_group("harbor_person")
 _human_shape=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.27;capsule.height=1.4;_human_shape.shape=capsule;_human_shape.position.y=.7;human_blocker.add_child(_human_shape);add_child(human_blocker)
 _route_shape=CapsuleShape3D.new();_route_shape.radius=.27;_route_shape.height=1.34
 if profile.get("native_cargo",false):
  native_load=preload("res://scripts/opening/harbor_carried_cargo.gd").new();native_load.name="CarriedCrate3D"
  add_child(native_load);native_load.configure(float(profile.get("cargo_size",.6)),str(profile.get("cargo_kind","crate")));native_load.hide()
func move_on_route(next_position: Vector3) -> bool:
 # Authored routes remain deterministic. A resident waits for the player rather
 # than teleporting its native footprint through the occupied next step.
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=_route_shape;query.transform=human_blocker.global_transform*_human_shape.transform
 # The 6cm raised sole ignores the supporting pavement while still testing
 # people, furniture and actual walls above it, not an arbitrary scene bound.
 query.transform.origin+=global_basis*(next_position-position)+Vector3.UP*.03;query.collision_mask=3;query.exclude=[human_blocker.get_rid()]
 if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
 position=next_position;return true
func tick(delta: float,camera: Camera3D,time_: float) -> void:
 actor_clock=time_;var before:=position;var dt:=minf(delta,.05)
 if route.size()>1:
  var target: Vector3=route[_target]
  if position.distance_to(target)<.025:
   if move_on_route(target):
    if not _arrived:_arrived=true;_wait=1.1;carrying=_target==0
    if _wait>0:_wait-=dt
    else:_target=(_target+1)%route.size();_arrived=false
  elif _wait>0:_wait-=dt
  else:aim=(target-position).normalized();move_on_route(position.move_toward(target,speed*dt))
 walking=position.distance_squared_to(before)>.0000001
 facing=Directions.choose(aim,camera,facing)
 var action: String="carry_walk" if profile.get("native_cargo",false) and carrying else "broom" if profile.get("broom",false) else "walk" if walking else "work" if work else "idle"
 var index: int=int(time_*(7 if walking else 2)+float(profile.get("phase",0)))%(4 if walking or work else 2)
 render_modular(camera,action,index)
 human_blocker.position=Vector3.ZERO
 if native_load!=null:
  native_load.visible=carrying
  var forward: Vector3=global_basis*Vector3(aim.x,0,aim.z).normalized()
  native_load.global_position=carry_grip(camera)+forward*.14+camera.global_basis.z*.13
  native_load.global_rotation=Vector3(0,atan2(forward.x,forward.z),0)
func render_modular(camera: Camera3D,action: String,sample: int,tier: String="") -> void:
 if modular_look.is_empty():modular_look=CityPose.appearance(profile,str(name),tier)
 var blink: bool=action=="idle" and fposmod(actor_clock+float(profile.get("phase",0))*.37,5.3)<.14
 modular_frame=CityPose.frame(modular_look,facing,action,sample,blink)
 sprite.texture=modular_frame.texture
 sprite.global_basis=camera.global_basis
 sprite.global_position=global_position+camera.global_basis.y*.864

func modular_hand_world(side: String,depth: float=0.0) -> Vector3:
 var p: Vector2=(Vector2(modular_frame[side])-CityPose.CENTER)*CityPose.PIXEL_SIZE
 return sprite.global_position+sprite.global_basis*Vector3(p.x,-p.y,depth)

func carry_grip(camera: Camera3D) -> Vector3:
 return (modular_hand_world("left")+modular_hand_world("right"))*.5+camera.global_basis.y*.09

func apply_deck_offset(offset: Vector3,camera: Camera3D) -> void:
 # Routes stay in berth coordinates; only rendered feet/shadow follow the swell.
 sprite.global_position=global_position+offset+camera.global_basis.y*.864
 shadow.global_position=global_position+Vector3.UP*.055+offset
 human_blocker.global_position=global_position+offset
 if native_load!=null:native_load.global_position+=offset
