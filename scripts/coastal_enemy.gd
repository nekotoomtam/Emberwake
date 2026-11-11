extends "res://scripts/enemy.gd"
const Roster=preload("res://scripts/coastal_roster.gd")
const CoastalArt=preload("res://scripts/coastal_art.gd")
const CHASE_INTERVAL := 12
# Keep a buffer beyond the largest attack trigger for each coastal archetype.
const FULL_CHASE_RANGE := {"fisherman": 5.5, "brinehound": 5.5, "net_hauler": 5.5,
 "harpooner": 10.5, "spitter": 5.5}
var chase_slot := 0
var _full_chase_range_squared := INF
var _last_distant_chase_frame := -2
var _distant_chase_velocity := Vector3.ZERO
var home_position:=Vector3.ZERO
var engaged:=false
var returning:=false
var elapsed:=0.0
var lunge_travel:=0.0
var contact_count:=0
var nameplate: Label3D
var _profile: Dictionary={}
var _preview_attack_index := -1
var _preview_attack: Dictionary = {}
var _stats: Dictionary={}
var fan_guides: Array=[]
const ImageHurt=preload("res://scripts/enemy_image_hurt.gd")
var _hurt_debug: MeshInstance3D
static var name_font: SystemFont
func _ready() -> void:
 super._ready()
 _profile=CoastalArt.profile(kind);_stats=Roster.stats(kind)
 var full_range: float = FULL_CHASE_RANGE.get(kind, INF)
 _full_chase_range_squared = full_range * full_range
 health=_stats.health;max_health=health;armor_rating=_stats.armor
 home_position=global_position;state="idle"
 for child in get_children():
  if child is CollisionShape3D:
   child.name="BodyCollision";child.shape.radius=_profile.body_radius;child.shape.height=_profile.body_height;child.position.y=float(_profile.body_height)*.5
 sprite.sprite_frames=CoastalArt.frames(kind);sprite.pixel_size=_profile.pixel_size;sprite.animation="idle";sprite.frame=0
 nameplate=Label3D.new();nameplate.text=_profile.name;nameplate.font_size=25;nameplate.pixel_size=.008
 nameplate.billboard=BaseMaterial3D.BILLBOARD_ENABLED;nameplate.outline_size=6
 if name_font==null:
  name_font=SystemFont.new();name_font.font_names=PackedStringArray(["Tahoma"])
 nameplate.font=name_font;add_child(nameplate)
 attack_visual.visible=false
 for i in range(2):
  var extra:=AttackVisual.new();add_child(extra);extra.visible=false;fan_guides.append(extra)
 update_bar()
func image_hurt_regions(height: float) -> Array:
 if _profile.has("body_crop"):
  var regions:=ImageHurt.regions(sprite,_profile.body_crop,height)
  if not regions.is_empty():return regions
 return [{"id":"body","position":global_position,"radius":float(_profile.get("body_radius",.33))}]
func hurt_regions() -> Array:return image_hurt_regions(global_position.y+.7)
func _update_hurt_debug(game) -> void:
 var show: bool=game.get("debug_range")==true and not dead and visible
 if not show:
  if is_instance_valid(_hurt_debug):_hurt_debug.visible=false
  return
 if not is_instance_valid(_hurt_debug):
  _hurt_debug=MeshInstance3D.new();_hurt_debug.name="ImageHurtDebug";_hurt_debug.mesh=ImmediateMesh.new()
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("68ffd5");material.no_depth_test=true
  _hurt_debug.material_override=material;_hurt_debug.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(_hurt_debug)
 _hurt_debug.visible=true
 var mesh: ImmediateMesh=_hurt_debug.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 for region in hurt_regions():
  for i in range(12):
   for angle in [TAU*i/12,TAU*(i+1)/12]:
    mesh.surface_add_vertex(region.position-global_position+Vector3(cos(angle),0,sin(angle))*float(region.radius))
 mesh.surface_end()
func coastal_projectile_style() -> String:return "harpoon" if kind=="harpooner" else "glob" if kind=="spitter" else ""
func threatens(target: Vector3) -> bool:
 return not attack_data.is_empty() and int(attack_data.get("projectiles",0))==0 and Attacks.contains(global_position,attack_angle,target,attack_data)
func line_of_sight(target: Vector3) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.65,target+Vector3.UP*.65,1)
 return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func tick(delta: float,game,advance_status: bool=true) -> void:
 if not is_finite(delta) or delta<=0:return
 if advance_status:advance_combat_status(delta)
 # Bound steps preserve impact timing and collision sweeps on coarse game ticks.
 var left:=delta
 while left>0:
  var dt:=minf(left,1.0/60.0);_advance(dt,game);left=maxf(0,left-dt)
 _pose(game)
 _update_hurt_debug(game)
func _advance(delta: float,game) -> void:
 clock+=delta;_hurt_time=maxf(0,_hurt_time-delta);_parry_flash=maxf(0,_parry_flash-delta)
 if dead:death_time+=delta;return
 cooldown=maxf(0,cooldown-delta);stagger=maxf(0,stagger-delta)
 var combat_target: Vector3=game.enemy_target_for(self).global_position
 var offset: Vector3=combat_target-global_position;offset.y=0
 var distance:=offset.length()
 if global_position.distance_to(home_position)>float(_stats.leash):
  returning=true;engaged=false;state="chase";attack_data={};active_left=0;telegraph_left=0
 if returning:
  var home:=home_position-global_position;home.y=0
  if home.length()<.25:returning=false;state="idle"
  elif stagger<=0:_move(home.normalized()*float(_stats.speed)*movement_speed_scale()*delta,game)
 elif stagger<=0:
  if state=="windup":
   telegraph_left=maxf(0,telegraph_left-delta)
   if telegraph_left<=0:state="attack";elapsed=0;active_left=attack_data.active
  elif state=="attack":
   var previous:=elapsed;elapsed=minf(float(attack_data.active),elapsed+delta);active_left=maxf(0,float(attack_data.active)-elapsed)
   # The dog's snarl is stationary; only the early active bite lunges.
   var lunge: float=float(attack_data.get("lunge",0))
   if lunge>0 and elapsed<=float(attack_data.active)*.36:
    var travel:=minf(lunge-lunge_travel,lunge*delta/(float(attack_data.active)*.30))
    if travel>0:
     _move(Vector3(cos(attack_angle),0,sin(attack_angle))*travel,game);lunge_travel+=travel
   if elapsed>=float(attack_data.active)*float(attack_data.impact):_resolve_attack(game)
   if state=="attack" and active_left<=0:state="recover";cooldown=attack_data.recovery
  elif state in ["recover","parried"]:
   if cooldown<=0:state="chase";attack_data={}
  else:
   if not engaged and distance<=float(_stats.detection) and line_of_sight(combat_target):engaged=true
   if engaged:
    state="chase"
    if not _advance_distant_chase(delta,game,offset):
     var direction := offset.normalized()
     if _preview_attack_index != attack_index:
      _preview_attack = _attack_definition(attack_index)
      _preview_attack_index = attack_index
     var next := _preview_attack
     var within_trigger := distance <= float(next.trigger)
     var aligned := within_trigger and _can_begin_attack(direction,next,game)
     if aligned and cooldown<=0 and line_of_sight(combat_target):
      attack_data=next.duplicate();attack_data.parryable=game.enemy_attack_parryable(attack_data.base_parryable, global_position);attack_index+=1;state="windup";telegraph_left=attack_data.windup;attack_hit=false;elapsed=0;lunge_travel=0;attack_angle=_locked_attack_angle(direction,game);target_point=combat_target
     else:
      var move:=direction*float(_stats.speed) if distance>float(next.trigger)*.88 or not aligned else Vector3.ZERO
      if int(next.projectiles)>0 and distance<2.8:move=-direction*float(_stats.speed)
      _move(_steer(move,game)*movement_speed_scale()*delta,game)
   else:state="idle"
 knockback=knockback.move_toward(Vector3.ZERO,delta*14)
 if knockback.length_squared()>.001:_move(knockback*delta,game)
func _advance_distant_chase(delta: float,game,offset: Vector3) -> bool:
 if not game.get("_crowd_index_active") or not game.stagger_distant_ai or offset.length_squared() <= _full_chase_range_squared:
  return false
 var frame := Engine.get_physics_frames()
 if frame != _last_distant_chase_frame and (frame > _last_distant_chase_frame + 1 or frame % CHASE_INTERVAL == chase_slot):
  _distant_chase_velocity = _steer(offset.normalized() * float(_stats.speed),game)
 _last_distant_chase_frame = frame
 # Movement and swept collision still run on every physics step.
 _move(_distant_chase_velocity * movement_speed_scale() * delta,game)
 return true

func _attack_definition(index: int) -> Dictionary:return Roster.attack(kind,index)
func _can_begin_attack(_direction: Vector3,_data: Dictionary,_game) -> bool:return true
func _locked_attack_angle(direction: Vector3,_game) -> float:return atan2(direction.z,direction.x)
func _steer(move: Vector3,game) -> Vector3:
 var result:=move
 var origin:=global_position
 if is_instance_valid(game.arena):
  if game.get("encounter_mode") == "dungeon":
   result = game.arena.steer_around_cover(origin,move,origin.distance_to(game.player.global_position))
  for obstacle: Vector3 in game.arena.obstacles:
   var away:=origin-obstacle;away.y=0
   if away.length()>.01 and away.length()<1.5:result+=away.normalized()*(1.5-away.length())*2.5
 var candidates: Array=game.steering_neighbors(origin,.85) if game.has_method("steering_neighbors") else game.enemies
 for other in candidates:
  if other!=self and is_instance_valid(other) and not other.dead:
   var away: Vector3=origin-other.global_position;away.y=0
   var distance_squared:=away.length_squared()
   if distance_squared>.0001 and distance_squared<.7225:
    var distance_:=sqrt(distance_squared)
    result+=away/distance_*(.85-distance_)*3
 return result.limit_length(float(_stats.speed)*1.35)
func _move(displacement: Vector3,game) -> void:
 if state=="chase" and game.get("encounter_mode")=="dungeon" and is_instance_valid(game.arena.hazards):
  displacement *= game.arena.hazards.speed_scale(global_position)
 var collision:=move_and_collide(displacement)
 if collision:move_and_collide(collision.get_remainder().slide(collision.get_normal()))
 if is_instance_valid(game.arena) and game.arena.has_method("clamp_point"):
  global_position=game.arena.clamp_point(global_position)
func _resolve_attack(game) -> void:
 if dead or attack_data.is_empty():return
 if int(attack_data.projectiles)==0:game.damage_companions_in_attack(self)
 if attack_hit:return
 if int(attack_data.projectiles)>0:
  attack_hit=true
  var launch:=projectile_launch(game)
  var count: int=attack_data.projectiles
  for i in range(count):
   var angle:=float(launch.angle)+(i-(count-1)*.5)*float(attack_data.get("spread",0))
   var direction:=Vector3(cos(angle),0,sin(angle))
   game.shoot(launch.origin,direction,attack_data.damage,attack_data.parryable,self,attack_data.guard_cost,_projectile_range(launch.origin,direction),attack_data.body_part,attack_data.body_damage)
  return
 game.check_perfect_evade(self)
 if not threatens(game.player.global_position) or not line_of_sight(game.player.global_position):return
 attack_hit=true;contact_count+=1
 game.incoming_attack(attack_data.damage,global_position,attack_data.parryable,self,attack_data.guard_cost,attack_data.body_part,attack_data.body_damage)
func _update_overhead_visibility(game) -> void:
 bar.visible = not dead
 var show_name := not dead
 if show_name and game.get("encounter_mode") == "dungeon":
  show_name = global_position.distance_squared_to(game.player.global_position) <= 25.0
 nameplate.visible = show_name

func _pose(game) -> void:
 sprite.global_basis=game.camera.global_basis
 sprite.global_position=global_position+game.camera.global_basis.y*((float(_profile.foot_pixel)-64)*sprite.pixel_size)
 bar.global_position=global_position+game.camera.global_basis.y*(float(_profile.body_height)+.15)
 nameplate.global_position=global_position+game.camera.global_basis.y*(float(_profile.body_height)+.4)
 _update_overhead_visibility(game)
 sprite.modulate=Color(1.5,1.5,1.5) if _hurt_time>0 else Color.WHITE
 var anim: String="idle";var frame:=0
 if dead:
  anim="death";frame=mini(2,int(death_time*5));sprite.modulate.a=maxf(0,1-maxf(0,death_time-.5)*1.5)
 elif _hurt_time>0 or state=="parried":anim="hit";frame=int(clock*8)%2
 elif state in ["windup","attack","recover"]:
  anim=state
  if bool(attack_data.get("variant",false)) and sprite.sprite_frames.has_animation(anim+"_alt"):anim+="_alt"
  var progress:=1.0-telegraph_left/float(attack_data.windup) if state=="windup" else elapsed/float(attack_data.active) if state=="attack" else 1.0-cooldown/float(attack_data.recovery)
  frame=mini(sprite.sprite_frames.get_frame_count(anim)-1,int(clampf(progress,0,1)*sprite.sprite_frames.get_frame_count(anim)))
  sprite.flip_h=game.camera.global_basis.x.dot(Vector3(cos(attack_angle),0,sin(attack_angle)))<0
 elif state=="chase":
  anim="walk";frame=int(clock*7)%4;sprite.flip_h=game.camera.global_basis.x.dot(game.player.global_position-global_position)<0
 else:frame=int(clock*2)%2
 sprite.animation=anim;sprite.frame=frame
 if state=="windup" and not attack_data.get("parryable",true):sprite.modulate=Color(1.6,.35,.28)
 elif _parry_flash>0:sprite.modulate=Color(.45,1.5,1.7)
 var guide:=attack_data
 var guide_angle:=attack_angle
 attack_visual.position=Vector3.ZERO
 if not attack_data.is_empty() and int(attack_data.get("projectiles",0))>0:
  var launch:=projectile_launch(game);guide=attack_data.duplicate();guide.reach=launch.reach;guide.telegraph_height=launch.origin.y-global_position.y;guide_angle=launch.angle
  var ground_origin: Vector3=launch.origin;ground_origin.y=global_position.y
  attack_visual.global_position=ground_origin
 attack_visual.update_view(guide,guide_angle,state,telegraph_left)
 for i in range(fan_guides.size()):
  var extra=fan_guides[i]
  extra.update_view({},0,"idle",0)
  if not attack_data.is_empty() and int(attack_data.get("projectiles",0))==3 and state in ["windup","attack"]:
   var launch:=projectile_launch(game)
   var angle: float=float(launch.angle)+(1.0 if i==1 else -1.0)*float(attack_data.spread)
   var lane:=attack_data.duplicate();lane.reach=_projectile_range(launch.origin,Vector3(cos(angle),0,sin(angle)));lane.telegraph_height=launch.origin.y-global_position.y
   extra.global_position=attack_visual.global_position;extra.update_view(lane,angle,state,telegraph_left);extra.cue.visible=false
 # Keep the red cue; only diagnostic mode exposes ground footprints.
func next_boundary() -> float:
 if dead:return INF
 if stagger>0:return stagger
 if state=="windup":return maxf(.000001,telegraph_left)
 if state=="attack" and not attack_data.is_empty():
  var impact: float=float(attack_data.active)*float(attack_data.impact)
  if elapsed<impact-.000001:return impact-elapsed
  return maxf(.000001,active_left)
 if state in ["recover","parried"]:return maxf(.000001,cooldown)
 return INF


func _receive_hit(amount: float,force: Vector3,duration: float,keep_red: bool) -> float:
 var before:=health
 var applied: float=super._receive_hit(amount,force,duration,keep_red)
 if not dead and health<before:engaged=true
 return applied
func receive_burn(amount: float) -> void:
 var before:=health
 super.receive_burn(amount)
 if not dead and health<before:engaged=true
func projectile_launch(game) -> Dictionary:
 var pixel: Vector2=CoastalArt.muzzle_pixel(kind,bool(attack_data.get("variant",false)))
 var facing: float=-1.0 if game.camera.global_basis.x.dot(Vector3(cos(attack_angle),0,sin(attack_angle)))<0 else 1.0
 var origin: Vector3=global_position+game.camera.global_basis.x*((pixel.x-64)*sprite.pixel_size*facing)+game.camera.global_basis.y*((float(_profile.foot_pixel)-pixel.y)*sprite.pixel_size)
 var aim: Vector3=target_point-origin;aim.y=0
 var direction: Vector3=aim.normalized() if aim.length_squared()>.000001 else Vector3(cos(attack_angle),0,sin(attack_angle))
 return {"origin":origin,"direction":direction,"angle":atan2(direction.z,direction.x),"reach":_projectile_range(origin,direction)}
func _projectile_range(origin: Vector3,direction: Vector3) -> float:
 # The maximum endpoint stays on the original root-centered reach circle.
 var offset:=origin-global_position;offset.y=0
 var along:=offset.dot(direction)
 var radius: float=attack_data.reach
 return maxf(.01,-along+sqrt(maxf(0,along*along+radius*radius-offset.length_squared())))

