extends CanvasLayer
## Visual information only. Enemy AI, damage and collision stay independent.
const RAYS:=256
const HALF_ANGLE:=PI/3
const BINS:=16
const DUNGEON_HALF_ANGLE_BONUS := PI/12
const DUNGEON_REACH_MULTIPLIER := 1.5
var game
var fog: ColorRect
var material: ShaderMaterial
var cue_material: ShaderMaterial
var indicator: Node2D
var warnings: Dictionary={}
var cues=preload("res://scripts/sense_cues.gd").new()
var seen: Dictionary={}
var clock:=.0
var forward:=Vector3.RIGHT
var _ray_clock:=INF
var _last_reach:=-1.0
var _last_origin:=Vector3.INF
var ray_image: Image
var ray_texture: ImageTexture
var ray_samples:=PackedFloat32Array()
var ray_directions:=PackedVector3Array()
var wall_query:=PhysicsRayQueryParameters3D.new()
class PulseDrawer extends Node2D:
 var owner_vision
 func _draw() -> void:owner_vision.draw_warnings(self)
func _ready() -> void:
 layer=2
 fog=ColorRect.new();fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fog.mouse_filter=Control.MOUSE_FILTER_IGNORE
 material=ShaderMaterial.new();material.shader=preload("res://shaders/sight_fog.gdshader");fog.material=material;add_child(fog)
 ray_image=Image.create(RAYS,1,false,Image.FORMAT_RF);ray_image.fill(Color.WHITE)
 ray_texture=ImageTexture.create_from_image(ray_image);material.set_shader_parameter("ray_lengths",ray_texture)
 wall_query.collision_mask=1;wall_query.hit_from_inside=true
 for i in range(RAYS):
  var theta:=TAU*(float(i)+.5)/RAYS
  ray_directions.append(Vector3(cos(theta),0,sin(theta)))
 indicator=PulseDrawer.new();indicator.owner_vision=self
 cue_material=ShaderMaterial.new();cue_material.shader=preload("res://shaders/sense_clip.gdshader");indicator.material=cue_material
 add_child(indicator)
func clear_line(origin: Vector3,target: Vector3) -> bool:
 if origin.distance_squared_to(target)<.000001:return true
 var query:=PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.85,target+Vector3.UP*.85,1)
 query.hit_from_inside=true
 return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func sight_direction() -> Vector3:
 if game.mode not in ["practice","combat"]:return forward
 if game.test_aim.length_squared()>.001:return Vector3(game.test_aim.x,0,game.test_aim.z).normalized()
 var point:=ground(game._mouse_position)
 var offset:=Vector3(point.x-game.player.position.x,0,point.y-game.player.position.z)
 return offset.normalized() if offset.length_squared()>.1 else game.aim
func in_cone(point: Vector3) -> bool:
 var offset:=Vector3(point.x-game.player.position.x,0,point.z-game.player.position.z)
 if offset.length()>reach()+.00001:return false
 if offset.length_squared()<.000001:return true
 return offset.normalized().dot(sight_direction())>=cos(half_angle())-.00001
func can_see(point: Vector3) -> bool:return in_cone(point) and clear_line(game.player.position,point)
func _cast_rays() -> void:
 var origin: Vector3=game.player.position+Vector3.UP*.85
 var reach: float=reach()
 ray_samples.resize(RAYS)
 var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
 wall_query.from=origin
 for i in range(RAYS):
  wall_query.to=origin+ray_directions[i]*reach
  var hit: Dictionary=space.intersect_ray(wall_query)
  var distance: float=origin.distance_to(hit.position) if not hit.is_empty() else reach
  ray_samples[i]=distance;ray_image.set_pixel(i,0,Color(distance/reach,0,0,1))
 _last_reach=reach;ray_texture.update(ray_image);_last_origin=game.player.position;_ray_clock=0
func ground(screen: Vector2) -> Vector2:
 var origin: Vector3=game.camera.project_ray_origin(screen)
 var direction: Vector3=game.camera.project_ray_normal(screen)
 var point:=origin-direction*(origin.y/direction.y)
 return Vector2(point.x,point.z)
func update_view(delta: float) -> void:
 var active: bool=game.mode!="menu"
 fog.visible=active;indicator.visible=active
 if not active:
  warnings.clear();seen.clear();reset_cues();indicator.queue_redraw()
  for enemy in game.enemies:
   if is_instance_valid(enemy):enemy.visible=true
  return
 clock+=delta;_ray_clock+=delta;forward=sight_direction()
 var dungeon_sight: bool = game.encounter_mode == "dungeon"
 var travel_limit := .12 if dungeon_sight else .04
 var player_origin: Vector3 = game.player.position
 if _ray_clock==INF or (not dungeon_sight and _ray_clock>=.04) or _last_origin.distance_squared_to(player_origin)>travel_limit*travel_limit or ray_samples.is_empty() or absf(_last_reach-reach())>.001:
  _cast_rays()
 var ray_origin := _last_origin if dungeon_sight else player_origin
 material.set_shader_parameter("ray_origin",Vector2(ray_origin.x,ray_origin.z))
 var size: Vector2=game.get_viewport().get_visible_rect().size
 var zero:=ground(Vector2.ZERO)
 var center: Vector2=game.camera.unproject_position(game.player.position+game.camera.global_basis.y*.85)
 var edge: Vector2=game.camera.unproject_position(game.player.position+game.camera.global_basis.y*(.85+1.12)+game.camera.global_basis.x*.72)
 material.set_shader_parameter("hero_center",center/size)
 material.set_shader_parameter("hero_radius",(edge-center).abs()/size)
 material.set_shader_parameter("world_origin",zero)
 material.set_shader_parameter("world_dx",ground(Vector2(size.x,0))-zero)
 material.set_shader_parameter("world_dy",ground(Vector2(0,size.y))-zero)
 material.set_shader_parameter("player_ground",Vector2(game.player.position.x,game.player.position.z))
 material.set_shader_parameter("facing",Vector2(forward.x,forward.z).normalized())
 material.set_shader_parameter("sight_range",reach())
 material.set_shader_parameter("cone_cos",cos(half_angle()))
 material.set_shader_parameter("aim_height",.9*game.rifle_focus_state.amount())
 cue_material.set_shader_parameter("cone_cos",cos(half_angle()))
 cue_material.set_shader_parameter("world_origin",zero)
 cue_material.set_shader_parameter("world_dx",ground(Vector2(size.x,0))-zero)
 cue_material.set_shader_parameter("world_dy",ground(Vector2(0,size.y))-zero)
 cue_material.set_shader_parameter("player_ground",Vector2(game.player.position.x,game.player.position.z))
 cue_material.set_shader_parameter("facing",Vector2(forward.x,forward.z).normalized())
 material.set_shader_parameter("actor_enabled",0.0);material.set_shader_parameter("weapon_enabled",0.0)
 for i in range(6):material.set_shader_parameter("npc%d_enabled"%i,0.0)
 var npc_index:=0
 var sight_origin: Vector3 = game.player.position
 var sight_limit := reach() + .00001
 var sight_threshold := cos(half_angle()) - .00001
 warnings.clear();seen.clear()
 var radius: float=game.stats.value("sense_radius")
 for enemy in game.enemies:
  if not is_instance_valid(enemy):continue
  var offset: Vector3 = enemy.position - sight_origin
  offset.y = 0
  var distance_squared := offset.length_squared()
  var in_view := distance_squared <= sight_limit * sight_limit and (distance_squared < .000001 or offset.dot(forward) >= sight_threshold * sqrt(distance_squared))
  var visible_now := in_view and clear_line(sight_origin, enemy.position)
  enemy.visible=visible_now;seen[enemy.get_instance_id()]=visible_now
  if visible_now and enemy.has_method("coastal_projectile_style") and npc_index<6:
   var texture: Texture2D=enemy.sprite.sprite_frames.get_frame_texture(enemy.sprite.animation,enemy.sprite.frame)
   _sharp_sprite("npc%d"%npc_index,enemy.sprite,texture,float(enemy.sprite.modulate.a),size,enemy.sprite.flip_h);npc_index+=1
  if enemy.kind=="captain" and visible_now:
   var texture: Texture2D=enemy.sprite.sprite_frames.get_frame_texture(enemy.sprite.animation,enemy.sprite.frame)
   _sharp_sprite("actor",enemy.sprite,texture,float(enemy.sprite.modulate.a),size,enemy.sprite.flip_h)
   var weapon: Sprite3D=enemy.captain_view.anchor
   var ground_tip: Vector3=enemy.captain_view.ground_tip
   if weapon.visible and clear_line(game.player.position,ground_tip):_sharp_sprite("weapon",weapon,weapon.texture,1.0,size,false)
  if visible_now or enemy.dead or enemy.kind=="dummy" or radius<=0:continue
  if distance_squared>radius*radius or in_view or not clear_line(sight_origin,enemy.position):continue
  var distance:=sqrt(distance_squared)
  var angle:=atan2(offset.z,offset.x)
  var bin:=posmod(roundi(angle/TAU*BINS),BINS)
  var strength:=clampf(1-distance/radius,0,1)
  warnings[bin]=maxf(float(warnings.get(bin,0)),strength)
 cues.update(warnings,{},delta)
 indicator.queue_redraw()
func cue_points(bin: int,expansion: float=0.0) -> PackedVector2Array:
 var foot: Vector2=game.camera.unproject_position(game.player.position)
 var center: Vector2=game.camera.unproject_position(game.player.position+game.camera.global_basis.y*.85)
 var edge: Vector2=game.camera.unproject_position(game.player.position+game.camera.global_basis.y*(.85+1.12)+game.camera.global_basis.x*.72)
 var radii: Vector2=(edge-center).abs()*1.10
 var unit_pixel: float=game.camera.unproject_position(game.player.position+game.camera.global_basis.x).distance_to(foot)
 var points:=PackedVector2Array()
 for i in range(19):
  var a:=float(bin)*TAU/BINS+lerpf(-.22,.22,float(i)/18)
  var projected: Vector2=game.camera.unproject_position(game.player.position+Vector3(cos(a),0,sin(a))*(1.72+expansion))
  var offset:=projected-foot
  var direction:=offset.normalized()
  var p: Vector2=(foot-center)/radii
  var v: Vector2=direction/radii
  var qa:=v.length_squared();var qb:=p.dot(v);var qc:=p.length_squared()-1
  var determinant:=qb*qb-qa*qc
  var reach:=offset.length()
  if determinant>=0 and qa>.0000001:reach=maxf(reach,(-qb+sqrt(determinant))/qa+expansion*unit_pixel)
  points.append(foot+direction*reach)
 return points
func cue_segments(bin: int,expansion: float=0.0) -> Array:
 var points:=cue_points(bin,expansion)
 var segments: Array=[]
 var segment:=PackedVector2Array()
 for i in range(points.size()):
  var angle:=float(bin)*TAU/BINS+lerpf(-.22,.22,float(i)/18)
  var hidden:=Vector3(cos(angle),0,sin(angle)).dot(sight_direction())<cos(half_angle())-.00001
  if hidden:segment.append(points[i])
  else:
   if segment.size()>1:segments.append(segment)
   segment=PackedVector2Array()
 if segment.size()>1:segments.append(segment)
 return segments
func draw_warnings(drawer: Node2D) -> void:
 var scale: float=game.get_viewport().get_visible_rect().size.y/720.0
 for bin in cues.states:
  var state: Dictionary=cues.states[bin]
  var strength: float=state.strength
  var alpha: float=state.alpha
  var flash: float=state.flash/cues.FLASH_TIME
  var width: float=cues.width(strength)*scale
  var segments:=cue_segments(bin)
  var color:=Color(1,.23,.035).lerp(Color(1,.87,.5),flash*.8)
  color.a=alpha*(.72+.13*strength+.12*flash)
  for points in segments:
   drawer.draw_polyline(points,Color(1,.12,.025,.20*alpha),(width+10*scale),true)
   drawer.draw_polyline(points,Color(.16,.018,.01,.9*alpha),width+4*scale,true)
   drawer.draw_polyline(points,color,width,true)
   drawer.draw_polyline(points,Color(1,.65,.22,.55*alpha),1.4*scale,true)
  var pulse: float=state.phase
  for points in cue_segments(bin,pulse*.55):
   drawer.draw_polyline(points,Color(1,.25,.055,(1-pulse)*.65*alpha),(2.5+strength)*scale,true)

func reset_cues() -> void:
 cues.reset()
 _ray_clock = INF

func half_angle() -> float:
 var bonus := DUNGEON_HALF_ANGLE_BONUS if game.encounter_mode == "dungeon" else 0.0
 if game.primary_family()=="pistol":
  var focus: float = game.pistol_aim_state.amount()
  return lerpf(HALF_ANGLE + bonus, PI/4, focus)
 return game.rifle_focus_state.half_angle() + bonus * (1.0 - game.rifle_focus_state.amount())

func reach() -> float:
 var room_multiplier := DUNGEON_REACH_MULTIPLIER if game.encounter_mode == "dungeon" else 1.0
 return game.stats.value("sight_range") * room_multiplier * game.rifle_focus_state.sight_multiplier() * game.anatomy.sight_multiplier()

func _sharp_sprite(prefix: String,sprite: SpriteBase3D,texture: Texture2D,alpha: float,size: Vector2,flip: bool) -> void:
 var half: Vector2=texture.get_size()*.5
 var tl: Vector2=game.camera.unproject_position(sprite.global_transform*Vector3(-half.x*sprite.pixel_size,half.y*sprite.pixel_size,0))/size
 var tr: Vector2=game.camera.unproject_position(sprite.global_transform*Vector3(half.x*sprite.pixel_size,half.y*sprite.pixel_size,0))/size
 var bl: Vector2=game.camera.unproject_position(sprite.global_transform*Vector3(-half.x*sprite.pixel_size,-half.y*sprite.pixel_size,0))/size
 material.set_shader_parameter(prefix+"_mask",texture);material.set_shader_parameter(prefix+"_enabled",alpha);material.set_shader_parameter(prefix+"_flip",flip)
 material.set_shader_parameter(prefix+"_origin",tl);material.set_shader_parameter(prefix+"_dx",tr-tl);material.set_shader_parameter(prefix+"_dy",bl-tl)
