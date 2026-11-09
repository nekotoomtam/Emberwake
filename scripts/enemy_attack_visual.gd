extends Node3D
const Geometry=preload("res://scripts/danger_geometry.gd")
var fill:=ImmediateMesh.new()
var outline:=ImmediateMesh.new()
var cue: Sprite3D
var boundary_points: Array[Vector3]=[]
var display_progress:=0.0
var display_color:=Color.WHITE
var _last_phase:=""
var _impact_clock:=0.0
var cache_static_walls:=false
var _footprint_key: Array=[]
var _triangles:=PackedInt32Array()
var _perimeter:=0.0
var _meshes_visible:=true
var _last_mesh_progress := -1.0
var _last_mesh_flash := false
static var guide_material: StandardMaterial3D
static var cue_texture: Texture2D
func _ready() -> void:
	if guide_material==null:
		guide_material=StandardMaterial3D.new()
		guide_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		guide_material.vertex_color_use_as_albedo=true
		guide_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		guide_material.cull_mode=BaseMaterial3D.CULL_DISABLED
		guide_material.render_priority=-20
	for mesh in [fill,outline]:
		var node:=MeshInstance3D.new();node.mesh=mesh
		node.material_override=guide_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	cue=Sprite3D.new();cue.pixel_size=.012;cue.position.y=2.35;cue.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	cue.shaded=false;cue.no_depth_test=true;cue.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if cue_texture==null:
		var image:=Image.create(12,12,false,Image.FORMAT_RGBA8)
		for y in range(1,11):
			var width:=mini(y,11-y)
			for x in range(6-width,7+width):image.set_pixel(x,y,Color.WHITE)
		cue_texture=ImageTexture.create_from_image(image)
	cue.texture=cue_texture;add_child(cue)
func vertex(mesh: ImmediateMesh,v: Vector3,color: Color) -> void:
	mesh.surface_set_color(color);mesh.surface_add_vertex(v+Vector3.UP*.065)
func line(a: Vector3,b: Vector3,color: Color,width: float) -> void:
	var axis:=b-a
	if axis.length_squared()<.00000001:return
	var side:=Vector3(-axis.z,0,axis.x).normalized()*width*.5
	for p in [a-side,b-side,b+side,a-side,b+side,a+side]:vertex(outline,p,color)
func update_view(data: Dictionary,angle: float,phase: String,remaining: float) -> void:
	visible=not data.is_empty() and phase in ["windup","attack"]
	if _meshes_visible!=visible:
		_meshes_visible=visible
		for child in get_children():
			if child is MeshInstance3D:child.visible=visible
	if not visible and boundary_points.is_empty():
		_last_phase=phase
		cue.hide()
		return
	var parent_clock = get_parent().get("clock")
	var clock := float(parent_clock) if parent_clock != null else 0.0
	var phase_changed := phase != _last_phase
	if phase=="attack" and phase_changed:_impact_clock=clock
	_last_phase=phase
	if not visible:
		fill.clear_surfaces();outline.clear_surfaces()
		if is_instance_valid(cue):cue.visible=false
		boundary_points.clear();_footprint_key.clear()
		return
	display_progress=Geometry.progress(data,phase,remaining)
	var red: bool=not bool(data.get("parryable",true))
	display_color=Color("ff5046") if red else Color("efb85b")
	var urgent: bool=phase=="attack" or remaining<=.12
	cue.visible=red;cue.modulate=display_color;cue.scale=Vector3.ONE*(1.1 if urgent else .8)
	var key: Array=[global_transform,angle,data]
	var footprint_changed := not cache_static_walls or key != _footprint_key
	if footprint_changed:
		boundary_points=Geometry.outline(data,angle)
		_clip_to_walls(float(data.get("telegraph_height",.65)))
		var polygon:=PackedVector2Array()
		_perimeter=0.0
		for i in boundary_points.size():
			var point:=boundary_points[i]
			polygon.append(Vector2(point.x,point.z))
			_perimeter+=point.distance_to(boundary_points[(i+1)%boundary_points.size()])
		_triangles=Geometry2D.triangulate_polygon(polygon)
		if cache_static_walls:_footprint_key=[global_transform,angle,data.duplicate()]
	var delay: float=float(data.get("impact",0))*float(data.get("active",0))
	if data.get("id","")=="throw":delay=float(data.get("release",0))
	var active_age:=clock-_impact_clock
	var flash: bool=phase=="attack" and active_age>=delay and active_age<delay+.09
	# Static dungeon outlines only need another mesh when the visible fill
	# advances. Phase transitions and impact flashes still draw immediately.
	if not footprint_changed and not phase_changed and flash == _last_mesh_flash and absf(display_progress - _last_mesh_progress) < .02 and not urgent:
		return
	if not footprint_changed and not phase_changed and phase == "attack" and flash == _last_mesh_flash and display_progress == _last_mesh_progress:
		return
	_last_mesh_progress = display_progress
	_last_mesh_flash = flash
	fill.clear_surfaces();outline.clear_surfaces()
	var alpha:=.23 if flash else .065+.065*display_progress
	if not _triangles.is_empty():
		fill.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in _triangles:vertex(fill,boundary_points[index],Color(display_color,alpha))
		fill.surface_end()
	outline.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var budget:=_perimeter*display_progress
	for i in boundary_points.size():
		var a:=boundary_points[i];var b:=boundary_points[(i+1)%boundary_points.size()];var length_:=a.distance_to(b)
		line(a,b,Color(display_color,.48),.032)
		if budget>0 and length_>.00001:
			var end:=a.lerp(b,minf(1,budget/length_))
			line(a,end,Color(1,.94,.77,.95) if flash else Color(display_color,.92),.044 if urgent else .034)
		budget=maxf(0,budget-length_)
	outline.surface_end()
func _clip_to_walls(height: float) -> void:
	if not is_inside_tree():return
	var space:=get_world_3d().direct_space_state
	var start:=global_position+Vector3.UP*maxf(.05,height)
	for i in boundary_points.size():
		var end:=to_global(boundary_points[i])+Vector3.UP*maxf(.05,height)
		if start.distance_squared_to(end)<.000001:continue
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1))
		if not hit.is_empty():
			var point: Vector3=hit.position;point.y=global_position.y
			boundary_points[i]=to_local(point)
