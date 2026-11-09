extends Node3D
const Motion=preload("res://scripts/captain_anchor_motion.gd")
const Pose=preload("res://scripts/captain_pose.gd")
var chain_links:=0
var last_slack:=0.0
const Rules=preload("res://scripts/captain_rules.gd")
const Art=preload("res://scripts/captain_art.gd")
var captain
var chain_start:=Vector3.ZERO
var chain_end:=Vector3.ZERO
var ground_tip:=Vector3.ZERO
var handoff_left:=.0
var _handoff_from:=Vector3.ZERO
var _settle_left:=.0
var _settle_from:=Vector3.ZERO
var _settle_roll:=.0
var _last_ground:=Vector3.ZERO
var _settle_ground_from:=Vector3.ZERO
var _last_anchor:=Vector3.ZERO
var _last_wrist:=Vector3.ZERO
var _last_roll:=.0
var _last_clock:=.0
var _last_committed:=false
var _last_cut:=false
var _has_frame:=false
var fill:=ImmediateMesh.new()
var edges:=ImmediateMesh.new()
var chain:=ImmediateMesh.new()
var debug:=ImmediateMesh.new()
var anchor: Sprite3D
var cue: Sprite3D
func _ready() -> void:
 for mesh in [fill,edges,chain,debug]:
  var node:=MeshInstance3D.new();node.mesh=mesh
  var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.no_depth_test=true
  node.material_override=mat;add_child(node)
 anchor=Sprite3D.new();anchor.texture=Art.anchor_texture();anchor.pixel_size=Rules.ANCHOR_PIXEL_SIZE;anchor.shaded=false;anchor.no_depth_test=true;anchor.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;anchor.render_priority=9;add_child(anchor)
 cue=Sprite3D.new();cue.pixel_size=.02;cue.shaded=false;cue.no_depth_test=true;cue.position.y=2.5;cue.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 var image:=Image.create(9,9,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 for y in range(9):
  for x in range(9):
   if absi(x-4)+absi(y-4)<=4:image.set_pixel(x,y,Color.WHITE)
 cue.texture=ImageTexture.create_from_image(image);add_child(cue)
func vert(mesh: ImmediateMesh,p: Vector3,color: Color) -> void:mesh.surface_set_color(color);mesh.surface_add_vertex(p)
func circle(mesh: ImmediateMesh,center: Vector3,radius: float,color: Color) -> void:
 for i in range(48):
  for a in [TAU*i/48,TAU*(i+1)/48]:vert(mesh,center+Vector3(cos(a)*radius,.07,sin(a)*radius),color)
func update_view(game) -> void:
 for mesh in [fill,edges,chain,debug]:mesh.clear_surfaces()
 captain.attack_visual.update_view(captain.attack_data,captain.attack_angle,"dead" if captain.dead else captain.state,captain.telegraph_left)
 anchor.visible=not captain.dead;cue.visible=false
 if captain.dead:_has_frame=false;handoff_left=0;_settle_left=0;return
 var data: Dictionary=captain.attack_data
 var committed: bool=not data.is_empty() and captain.state in ["windup","attack"]
 var pose: Dictionary=Pose.sample(data,captain.state,captain.telegraph_left,captain.elapsed,captain.cooldown,captain.attack_angle)
 var tip: Vector3=pose.tip
 var dt:=maxf(0,float(captain.clock)-_last_clock);_last_clock=captain.clock
 if _has_frame and _last_committed and not committed and (data.is_empty() or captain.state!="recover"):
  _settle_left=.24;_settle_from=_last_anchor;_settle_ground_from=_last_ground;_settle_roll=_last_roll
 if _has_frame and captain.arm_cut!=_last_cut:
  handoff_left=.18;_handoff_from=_last_wrist
 var first_wrist: Vector3=captain.chain_wrist()-captain.global_position
 var last_wrist: Vector3=first_wrist
 if not data.is_empty():
  var first_pose: Dictionary=Pose.sample(data,"attack",0,0,0,captain.attack_angle)
  var last_pose: Dictionary=Pose.sample(data,"attack",0,float(data.active),0,captain.attack_angle)
  first_wrist=captain.pixel_world(Art.hand_pixel(first_pose.animation,int(first_pose.frame),captain.arm_cut))-captain.global_position
  last_wrist=captain.pixel_world(Art.hand_pixel(last_pose.animation,int(last_pose.frame),captain.arm_cut))-captain.global_position
 var roll: float=Motion.roll(data,captain.state,pose,captain.elapsed,captain.cooldown,captain.attack_angle,game.camera.global_basis.x,game.camera.global_basis.y,captain.chain_wrist()-captain.global_position,first_wrist,last_wrist)
 if _settle_left>0:roll=lerp_angle(_settle_roll,roll,smoothstep(0,1,1-_settle_left/.24))
 elif _has_frame and captain.state=="chase":roll=lerp_angle(_last_roll,roll,1-exp(-14*dt))
 anchor.global_basis=game.camera.global_basis;anchor.rotate_object_local(Vector3.BACK,roll)
 var desired_ground: Vector3=captain.global_position+tip
 var desired: Vector3=desired_ground+game.camera.global_basis.y*(Rules.VISUAL_HEIGHT+float(pose.lift))
 if pose.held:
  var ring: Vector2=Art.anchor_ring_pixel();var offset:=anchor.global_basis*Vector3((ring.x-64)*anchor.pixel_size,(64-ring.y)*anchor.pixel_size,0)
  var grip_point: Vector3=captain.chain_wrist()-offset
  desired=desired.lerp(grip_point,float(pose.grip))
  desired_ground=desired_ground.lerp(captain.global_position+captain.view_right*(grip_point-captain.global_position).dot(captain.view_right),float(pose.grip))
 if _settle_left>0:
  var weight:=smoothstep(0,1,1-_settle_left/.24)
  anchor.global_position=_settle_from.lerp(desired,weight);ground_tip=_settle_ground_from.lerp(desired_ground,weight);_settle_left=maxf(0,_settle_left-dt)
 elif _has_frame and captain.state=="chase":
  var weight:=1-exp(-14*dt)
  anchor.global_position=_last_anchor.lerp(desired,weight);ground_tip=_last_ground.lerp(desired_ground,weight)
 else:anchor.global_position=desired;ground_tip=desired_ground
 anchor.modulate=Color(1.5,.45,.3) if committed and not data.parryable else Color.WHITE
 cue.global_position=captain.global_position+game.camera.global_basis.y*3.62
 var wrist_world: Vector3=captain.chain_wrist()
 if handoff_left>0:
  wrist_world=_handoff_from.lerp(wrist_world,smoothstep(0,1,1-handoff_left/.18));handoff_left=maxf(0,handoff_left-dt);pose.slack=maxf(float(pose.slack),.32)
 chain_start=wrist_world;chain_end=anchor_ring_world()
 var wrist: Vector3=chain_start-captain.global_position;var ring_end: Vector3=chain_end-captain.global_position
 _last_ground=ground_tip;_last_anchor=anchor.global_position;_last_wrist=wrist_world;_last_roll=roll;_last_committed=committed;_last_cut=captain.arm_cut;_has_frame=true
 var perpendicular:=Vector3(-sin(captain.attack_angle),0,cos(captain.attack_angle))
 last_slack=pose.slack;var arc_length: float=wrist.distance_to(ring_end)+2*float(pose.slack);chain_links=clampi(int(arc_length/.11),12,48)
 chain.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(chain_links):
  var t: float=(i+.5)/chain_links
  var center:=_chain_point(wrist,ring_end,t,pose,perpendicular)
  var tangent:=(_chain_point(wrist,ring_end,minf(1,t+.02),pose,perpendicular)-_chain_point(wrist,ring_end,maxf(0,t-.02),pose,perpendicular)).normalized()
  var across:=tangent.cross(game.camera.global_basis.z).normalized()
  if across.length_squared()<.01:across=game.camera.global_basis.x
  var half_length:=minf(.057,arc_length/chain_links*.48)
  var width: float=.027 if i%2==0 else .019
  var points: Array[Vector3]=[center-tangent*half_length,center+across*width,center+tangent*half_length,center-across*width]
  for j in range(4):_wire(points[j],points[(j+1)%4],game.camera.global_basis.z,Color("#b6bab0") if j<2 else Color("#647676"))
 chain.surface_end()
 cue.modulate=Color(1,.18,.13) if committed and not data.parryable else Color.WHITE
 cue.visible=committed and not data.parryable
 if game.debug_range:
  debug.surface_begin(Mesh.PRIMITIVE_LINES)
  for region in captain.hurt_regions():circle(debug,region.position-captain.global_position,region.radius,Color("#69ffc5") if region.id=="body" else Color("#ffe477"))
  if committed and captain.state=="attack" and Rules.damaging(data,captain.elapsed):circle(debug,Rules.tip(data,captain.attack_angle,captain.elapsed),float(data.radius),Color(1,.3,.15))
  debug.surface_end()

func _chain_point(a: Vector3,b: Vector3,t: float,pose: Dictionary,perpendicular: Vector3) -> Vector3:
 var p:=a.lerp(b,t);p.y=maxf(.06,p.y-sin(PI*t)*float(pose.slack))
 return p+perpendicular*sin(PI*t)*sin(TAU*t-float(pose.progress)*TAU*2)*float(pose.whip)
func _wire(a: Vector3,b: Vector3,normal: Vector3,color: Color) -> void:
 var across: Vector3=(b-a).cross(normal).normalized()*.007
 for point in [a-across,b-across,b+across,a-across,b+across,a+across]:vert(chain,point,color)

func anchor_ring_world() -> Vector3:
 var point: Vector2=Art.anchor_ring_pixel()
 return anchor.global_transform*Vector3((point.x-64)*anchor.pixel_size,(64-point.y)*anchor.pixel_size,0)
