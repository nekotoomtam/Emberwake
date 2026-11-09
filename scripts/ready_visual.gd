extends Node3D
## Persistent geometry; no per-frame transient spawning.
const Rules=preload("res://scripts/weapon_ready.gd")
var mesh:=ImmediateMesh.new()
var node: MeshInstance3D
var center_start:=Vector3.ZERO
var center_end:=Vector3.ZERO
var line_visible:=false
func _ready() -> void:
 node=MeshInstance3D.new();node.mesh=mesh
 var material:=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.no_depth_test=true
 material.render_priority=0;node.material_override=material;add_child(node)
func segment(a: Vector3,b: Vector3,color: Color) -> void:
 mesh.surface_set_color(color);mesh.surface_add_vertex(a);mesh.surface_set_color(color);mesh.surface_add_vertex(b)
func clipped(game,start: Vector3,end: Vector3) -> Vector3:
 if not Engine.is_in_physics_frame():return end
 var query:=PhysicsRayQueryParameters3D.create(start,end,1 if game.primary_family()=="rifle" else 3)
 query.hit_from_inside=true
 var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
 return hit.position if not hit.is_empty() else end
func update_view(game) -> void:
 mesh.clear_surfaces();line_visible=false
 if game.primary_family() in ["rifle","pistol"]:
  visible=false;return
 var action: String=game.right_action()
 var hip_rifle: bool=game.primary_family()=="rifle" and game.mode in ["practice","combat"] and not game.inventory_open and not game.stats_open and game._dodge_left<=0
 visible=hip_rifle or action!="" or ((game.readiness.broken_left>0 or game.readiness.parry_flash>0) and game.mode in ["practice","combat"] and not game.inventory_open)
 if not visible:return
 mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 var angle: float=atan2(game.aim.z,game.aim.x)
 if action=="aim" or hip_rifle:
  line_visible=true
  var rig=game.dual_visual.rigs[0] if game._uses_dual_hands() else game.avatar
  var points: Dictionary=rig.get_blade_points()
  center_start=points.tip
  var family: String=game.primary_family()
  var definition: Dictionary=game.primary_definition()
  var distance: float=12.0 if hip_rifle and action=="aim" else definition.projectile_range
  var launch_root: Vector3=game.DualHandVisual.origin(game.player.position,angle,0) if game._uses_dual_hands() else game.player.position
  var origin:=Vector3(launch_root.x,center_start.y,launch_root.z)
  for i in [-1,0,1]:
   var ray_angle: float=angle+Rules.spread(family,action=="aim")*i
   var direction:=Vector3(cos(ray_angle),0,sin(ray_angle))
   var end:=clipped(game,origin,center_start+direction*distance)
   # A muzzle beyond close cover must not draw a line through that cover.
   var start:=center_start if (end-origin).dot(direction)>=(center_start-origin).dot(direction) else origin
   segment(start,end,Color(1,.86,.48,.9) if i==0 else Color(.5,.9,.85,.32))
   if i==0:
    center_end=end
    segment(end-Vector3(.07,0,0),end+Vector3(.07,0,0),Color(1,.9,.6,.9))
    segment(end-Vector3(0,0,.07),end+Vector3(0,0,.07),Color(1,.9,.6,.9))
 else:
  var color:=Color(1,.35,.28,.9) if game.readiness.broken_left>0 else (Color(1,1,.8,1) if game.readiness.parry_left>0 or game.readiness.parry_flash>0 else Color(.55,.92,1,.8))
  var origin: Vector3=game.player.position+Vector3.UP*.06
  for i in range(24):
   var a:=angle-deg_to_rad(60)+deg_to_rad(120)*i/24
   var b:=angle-deg_to_rad(60)+deg_to_rad(120)*(i+1)/24
   segment(origin+Vector3(cos(a),0,sin(a))*.9,origin+Vector3(cos(b),0,sin(b))*.9,color)
 mesh.surface_end()
