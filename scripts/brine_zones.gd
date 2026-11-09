extends Node3D
## One ground capsule drives drawing and damage; independent of the caster's life.
const Attacks=preload("res://scripts/enemy_attacks.gd")
var zones: Array[Dictionary]=[]
var poison_lock:=0.0
func spawn_lane(origin: Vector3,angle: float,reach: float,width: float,owner_enemy) -> Dictionary:
 var node:=MeshInstance3D.new();node.mesh=ImmediateMesh.new()
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
 var zone:={"origin":origin,"angle":angle,"reach":reach,"width":width,"owner":weakref(owner_enemy),"node":node,"age":0.0,"remaining":3.85,"hit":false,"flowing":true,"pulse":0.0}
 zones.append(zone);return zone
func clear() -> void:
 for zone in zones:
  if is_instance_valid(zone.node):zone.node.queue_free()
 zones.clear();poison_lock=0
func covers(zone: Dictionary,point: Vector3) -> bool:
 if not Attacks.contains(zone.origin,zone.angle,point,{"shape":"lane","reach":zone.reach,"width":zone.width}):return false
 var direction:=Vector3(cos(zone.angle),0,sin(zone.angle))
 var nearest: Vector3=zone.origin+direction*clampf((point-zone.origin).dot(direction),0,zone.reach)
 for origin: Vector3 in [zone.origin,nearest]:
  if origin.distance_squared_to(point)<.000001:continue
  var query:=PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.3,point+Vector3.UP*.3,1);query.hit_from_inside=true
  if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():return false
 return true
func tick(delta: float,game) -> void:
 if not is_finite(delta) or delta<=0:return
 poison_lock=maxf(0,poison_lock-delta)
 for zone in zones.duplicate():
  var owner_enemy=zone.owner.get_ref()
  var flowing: bool=is_instance_valid(owner_enemy) and not owner_enemy.dead and owner_enemy.state=="attack" and owner_enemy.current_zone==zone
  if zone.flowing and not flowing:zone.remaining=minf(zone.remaining,3.0);zone.pulse=0
  zone.flowing=flowing;zone.age+=delta;zone.remaining=maxf(0,zone.remaining-delta)
  if not flowing:
   zone.pulse+=delta
   if zone.pulse>=.5-.0000001:
    zone.pulse=fmod(zone.pulse,.5)
    for companion in game.companions:
     if not companion.downed and covers(zone,companion.global_position):companion.receive_hit(2.0)
    if poison_lock<=.0000001 and covers(zone,game.player.global_position):
     poison_lock=.5
     game.damage_player(2.0,zone.origin,0.0,"poison","torso",0.0,false,&"area")
  if zone.remaining<=.0000001:
   zone.node.queue_free();zones.erase(zone)
func refresh(game) -> void:
 for zone in zones:draw_zone(zone,game)
func vertex(mesh: ImmediateMesh,p: Vector3,color: Color) -> void:
 mesh.surface_set_color(color);mesh.surface_add_vertex(p)
func triangle(mesh: ImmediateMesh,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
 for p in [a,b,c]:vertex(mesh,p,color)
func draw_zone(zone: Dictionary,game) -> void:
 var mesh: ImmediateMesh=zone.node.mesh;mesh.clear_surfaces()
 var origin: Vector3=zone.origin+Vector3.UP*.055;var direction:=Vector3(cos(zone.angle),0,sin(zone.angle));var side:=Vector3(-direction.z,0,direction.x)
 var fade:=minf(1,zone.remaining/.4)
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 # Rounded lane ends use the exact same radius as contact.
 var boundary: Array[Vector3]=[];var radius: float=zone.width*.5
 for i in range(13):
  var angle: float=-PI*.5+PI*i/12
  boundary.append(origin+direction*zone.reach+(direction*cos(angle)+side*sin(angle))*radius)
 for i in range(13):
  var angle: float=PI*.5+PI*i/12
  boundary.append(origin+(direction*cos(angle)+side*sin(angle))*radius)
 var center: Vector3=origin+direction*zone.reach*.5
 for i in boundary.size():
  var p: Vector3=boundary[i];var q: Vector3=boundary[(i+1)%boundary.size()]
  var visible_p:=p
  var ray:=PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.25,p+Vector3.UP*.25,1);ray.hit_from_inside=true
  var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
  if not hit.is_empty():visible_p=hit.position-Vector3.UP*.25
  boundary[i]=visible_p
 for i in boundary.size():triangle(mesh,center,boundary[i],boundary[(i+1)%boundary.size()],Color(.22,.38,.055,.68*fade))
 # Pixel-sized wet facets and bubbles make the full dangerous lane readable.
 for i in range(24):
  var t: float=float(i)/23
  var p: Vector3=origin+direction*(t*zone.reach)+side*sin(i*9.7)*radius*.57+Vector3.UP*.005
  var size:=.04+.025*sin(i*7.3+zone.age*4)
  if not covers(zone,p):continue
  var color:=Color(.56,.69,.16,.7*fade)
  triangle(mesh,p-direction*size-side*size,p+direction*size-side*size,p+direction*size+side*size,color)
  triangle(mesh,p-direction*size-side*size,p+direction*size+side*size,p-direction*size+side*size,color)
 var owner_enemy=zone.owner.get_ref()
 if zone.flowing and is_instance_valid(owner_enemy):
  var mouth: Vector3=owner_enemy.mouth_world()
  # A continuous broken-surface liquid stream, connected to current lip pin.
  var end: Vector3=origin+direction*zone.reach
  var previous:=mouth
  for i in range(1,19):
   var t: float=i/18.0
   var point: Vector3=mouth.lerp(end,t)+Vector3.UP*(sin(t*PI)*.18)+side*sin(i*1.8-zone.age*22)*.035
   var width: float=.045+.075*t
   var spread: Vector3=game.camera.global_basis.x*width
   var color:=Color(.39,.59,.12,1)
   triangle(mesh,previous-spread,point-spread,point+spread,color);triangle(mesh,previous-spread,point+spread,previous+spread,color)
   previous=point
 mesh.surface_end()
 zone.node.visible=game.vision.can_see(origin) or game.vision.can_see(center) or game.vision.can_see(origin+direction*zone.reach)

