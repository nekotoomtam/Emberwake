extends "res://scripts/coastal_enemy.gd"
const SpitArt=preload("res://scripts/spitter_art.gd")
var _view:="right"
var _committed_view:="right"
var _moved:=Vector3.ZERO
var _walk_clock:=0.0
var lane_origin:=Vector3.ZERO
var lane_reach:=3.8
var current_zone: Dictionary={}
func _ready() -> void:
 super._ready();_stats.speed=1.05
 _profile={"name":"ผู้สำรอกน้ำเค็ม","pixel_size":.03,"foot_pixel":120,"body_radius":.33,"body_height":2.6,"body_crop":Rect2i(15,8,101,113)}
 sprite.sprite_frames=SpitArt.frames();sprite.pixel_size=.03;sprite.animation="right_idle";sprite.frame=0
 nameplate.text=_profile.name
 for child in get_children():
  if child is CollisionShape3D:child.shape.radius=.33;child.shape.height=2.6;child.position.y=1.3
func spitter_direction() -> String:return _view
func _attack_definition(index: int) -> Dictionary:
 var data:=Roster.attack("spitter",index)
 data.merge({"id":"brine_stream","projectiles":0,"shape":"lane","width":1.1,"reach":3.8,"trigger":3.8,"windup":1.0,"active":.85,"recovery":1.8,"impact":0.0,"damage":9.0,"parryable":false,"base_parryable":false,"variant":false},true)
 return data
func _locked_attack_angle(direction_: Vector3,game) -> float:
 _committed_view=SpitArt.direction(direction_,game.camera)
 lane_origin=global_position+direction_*.35;lane_origin.y=global_position.y
 var angle:=atan2(direction_.z,direction_.x)
 lane_reach=3.8
 var query:=PhysicsRayQueryParameters3D.create(lane_origin+Vector3.UP*.3,lane_origin+direction_*lane_reach+Vector3.UP*.3,1);query.hit_from_inside=true
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():lane_reach=maxf(0,lane_origin.distance_to(hit.position-Vector3.UP*.3)-.56)
 attack_data.reach=lane_reach;current_zone={}
 return angle
func threatens(point: Vector3) -> bool:
 return not attack_data.is_empty() and Attacks.contains(lane_origin,attack_angle,point,attack_data) and _lane_clear(point)
func _lane_clear(point: Vector3) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.65,point+Vector3.UP*.65,1);query.hit_from_inside=true
 return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func tick(delta: float,game,advance_status: bool=true) -> void:
 _moved=Vector3.ZERO;super.tick(delta,game,advance_status)
func _move(displacement: Vector3,game) -> void:
 var before:=global_position;super._move(displacement,game);_moved+=global_position-before
func _advance(delta: float,game) -> void:
 var windup:=state=="windup";super._advance(delta,game)
 if windup and state=="attack":_resolve_attack(game)
func _resolve_attack(game) -> void:
 if dead or attack_data.is_empty() or state!="attack":return
 if not attack_hit:
  attack_hit=true;current_zone=game.brine_zones.spawn_lane(lane_origin,attack_angle,lane_reach,1.1,self)
  if game.vision.can_see(global_position):game.audio.play("cast")
 game.check_perfect_evade(self)
 game.damage_companions_in_attack(self)
 if current_zone.get("hit",false) or not threatens(game.player.global_position):return
 current_zone.hit=true;contact_count+=1
 game.incoming_attack(9.0,global_position,false,self,1.0,attack_data.body_part,1.8,&"area")
func mouth_world() -> Vector3:
 var pixel:=Vector2(67,34)
 if _view in ["right","left"]:
  var index:=5
  if state=="windup":index=0 if telegraph_left>.65 else 1
  elif state=="attack":index=2 if elapsed<.2 else 3 if elapsed<.65 else 4
  pixel=SpitArt.MOUTHS[index]
 var local:=Vector2(pixel.x-64,64-pixel.y)
 if sprite.flip_h:local.x=-local.x
 local+=sprite.offset
 return sprite.global_transform*Vector3(local.x*sprite.pixel_size,local.y*sprite.pixel_size,0)
func _pose(game) -> void:
 if state in ["windup","attack","recover","parried"]:_view=_committed_view
 elif not dead:
  var facing: Vector3=_moved if _moved.length_squared()>.000001 else game.player.global_position-global_position
  if facing.length_squared()>.000001:_view=SpitArt.direction(facing,game.camera)
 var phase:="idle";var index:=0
 if dead:phase="death"
 elif state=="parried":phase="hit"
 elif state in ["windup","attack","recover"]:
  phase=state
  if state=="windup":index=0 if telegraph_left>.65 else 1
  elif state=="attack":index=0 if elapsed<.2 else 1 if elapsed<.65 else 2
 elif _moved.length_squared()>.000001:
  phase="walk";_walk_clock+=_moved.length()/1.05;index=int(_walk_clock/.28)%6
 sprite.animation=_view+"_"+phase;sprite.frame=index;sprite.flip_h=_view=="left"
 var root_x:=72 if _view=="left" else 56 if _view=="right" else 64
 sprite.offset=Vector2(64-root_x,0);sprite.global_basis=game.camera.global_basis
 var bob:=0.0
 if _view in ["front","back"]:
  if phase=="walk":bob=absf(sin(_walk_clock*PI/.28))*.045
  var lean:=.0
  if phase=="windup":lean=-.045*sin((1.0-telegraph_left)*PI)
  elif phase=="attack":lean=.09
  sprite.global_basis=game.camera.global_basis*Basis(Vector3.FORWARD,lean)
 sprite.global_position=global_position+sprite.global_basis.y*(56*sprite.pixel_size+bob)
 bar.global_position=global_position+game.camera.global_basis.y*2.9;nameplate.global_position=global_position+game.camera.global_basis.y*3.15
 _update_overhead_visibility(game)
 sprite.modulate=Color(1.5,1.5,1.5) if _hurt_time>0 else Color.WHITE
 if dead:sprite.modulate=Color(.65,.65,.65,maxf(0,1-maxf(0,death_time-.4)*1.5))
 attack_visual.global_position=lane_origin
 attack_visual.update_view(attack_data,attack_angle,state,telegraph_left)
 for extra in fan_guides:extra.visible=false
