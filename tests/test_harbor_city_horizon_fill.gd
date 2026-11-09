extends SceneTree
const Matte=preload("res://scripts/opening/harbor_city_matte.gd")
const HarborCamera=preload("res://scripts/opening/harbor_camera.gd")
const Waterfront=preload("res://scripts/opening/harbor_city_waterfront_3d.gd")
const Detail=preload("res://scripts/opening/harbor_detail.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures.append(message);printerr("FAIL: "+message)
func ground_hit(node: Node3D,point: Vector3) -> Variant:
 var hit: Variant=null;var nearest:=4.0
 var visuals: Array=[node] if node is MeshInstance3D else node.find_children("*","MeshInstance3D",true,false)
 for visual in visuals:
  var faces: PackedVector3Array=visual.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var from:=point+Vector3.UP*2
   var at: Variant=Geometry3D.ray_intersects_triangle(from,Vector3.DOWN,visual.global_transform*faces[i],visual.global_transform*faces[i+1],visual.global_transform*faces[i+2])
   if at!=null and from.distance_to(at)<nearest:hit=at;nearest=from.distance_to(at)
 return hit
func mesh_ray_hit(mesh: MeshInstance3D,origin: Vector3,direction: Vector3) -> Variant:
 if mesh==null:return null
 var faces: PackedVector3Array=mesh.mesh.get_faces()
 var nearest:=INF;var result: Variant=null
 for i in range(0,faces.size(),3):
  var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,mesh.global_transform*faces[i],mesh.global_transform*faces[i+1],mesh.global_transform*faces[i+2])
  if hit!=null and origin.distance_to(hit)<nearest:nearest=origin.distance_to(hit);result=hit
 return result
func run() -> void:
 var path:="res://scripts/opening/harbor_city_horizon_fill.gd"
 check(FileAccess.file_exists(path),"bounded northern horizon fill exists")
 if not FileAccess.file_exists(path):finish();return
 var script=load(path)
 if script==null:check(false,"northern horizon helper parses");finish();return
 var source:=Matte.new();root.add_child(source);await process_frame
 var waterfront:=Waterfront.new();root.add_child(waterfront);await process_frame
 var source_state: Array=[]
 for i in source.layers.size():source_state.append([source.layers[i].transform,source.layers[i].get_instance_id(),source.materials[i].get_instance_id(),source.textures[i].get_instance_id(),source.materials[i].uv1_scale,source.materials[i].uv1_offset])
 var leaf_material:=Detail.material("6b8558","moss",7713)
 var leaf_state: Array=[leaf_material.albedo_texture,leaf_material.albedo_color,leaf_material.texture_filter,leaf_material.transparency,leaf_material.no_depth_test,leaf_material.cull_mode]
 var fill: Node3D=script.new();fill.source_matte=source;fill.source_waterfront=waterfront
 for property in fill.get_property_list():
  if property.name=="ridge_material":fill.set("ridge_material",leaf_material)
 root.add_child(fill);await process_frame
 check(fill.build_errors.is_empty() and fill.layers.size()==3,"the two accepted returns and one small tail-town overlay are available")
 if fill.layers.size()!=3:fill.queue_free();source.queue_free();waterfront.queue_free();await process_frame;finish();return
 check(fill.ground_rect==Rect2(-320,-525,300,105) and fill.ground_material==waterfront.materials.stone,"new ground reuses the exact native city palette within its inland footprint")
 var ground_box: AABB=fill.ground.global_transform*fill.ground.get_aabb()
 check(ground_box.position.is_equal_approx(Vector3(-320,-2.4,-525)) and ground_box.end.is_equal_approx(Vector3(-20,0,-420)),"actual native ground stops at the inland bounds and leaves the eastern sea open")
 check(not fill.ground_material.no_depth_test and fill.ground_material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"inland ground is an ordinary opaque depth-tested native surface")
 for x in [-150.0,-92.0,-24.0]:
  var old_hit: Variant=ground_hit(waterfront.main,Vector3(x,0,-419.97))
  var new_hit: Variant=ground_hit(fill.ground,Vector3(x,0,-420.03))
  check(old_hit!=null and new_hit!=null and absf(old_hit.y)<.002 and absf(new_hit.y)<.002,"actual ground triangles join the accepted northern terminal at x="+str(x))
 var camera:=HarborCamera.new();root.add_child(camera);await process_frame
 camera.start_flyin();camera.tick(10)
 var ridge: MeshInstance3D=fill.get("ridge_mesh") as MeshInstance3D
 var tail: Dictionary=fill.definitions[2]
 for x in [tail.center_x-tail.width*.5,tail.center_x,tail.center_x+tail.width*.5]:
  var footer:=Vector3(x,tail.base_y,tail.z)
  var origin: Vector3=camera.global_position
  var hit: Variant=mesh_ray_hit(ridge,origin,(footer-origin).normalized())
  check(hit!=null and origin.distance_to(hit)<origin.distance_to(footer)-.01,"low native ridge hides the small town overlay's footer before the painted card at "+str(footer.x))
 var tail_card: MeshInstance3D=fill.layers[2]
 var tail_size: Vector2=tail_card.mesh.size
 var town_point: Vector3=tail_card.global_transform*Vector3(-tail_size.x*.25,tail_size.y*.15,0)
 var town_hit: Variant=mesh_ray_hit(ridge,camera.global_position,(town_point-camera.global_position).normalized())
 check(town_hit==null or camera.global_position.distance_to(town_hit)>=camera.global_position.distance_to(town_point),"a real painted town crown remains visible above the low ridge rather than being buried")
 for pixel in [Vector2(620,42),Vector2(680,44),Vector2(740,46),Vector2(800,48),Vector2(850,45),Vector2(840,33)]:
  var origin:=camera.project_ray_origin(pixel);var direction:=camera.project_ray_normal(pixel)
  var hit: Variant=mesh_ray_hit(ridge,origin,direction)
  var sea_distance: float=(-.249-origin.y)/direction.y if direction.y<0 else INF
  check(hit!=null and origin.distance_to(hit)<sea_distance,"marked inland camera ray meets actual opaque hill triangles before the highest sea surface at "+str(pixel))
 for pixel in [Vector2(880,33),Vector2(890,43)]:
  check(mesh_ray_hit(ridge,camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))==null,"offshore ray remains outside the inland ridge at "+str(pixel))
 if ridge!=null:
  var ridge_box: AABB=ridge.global_transform*ridge.get_aabb()
  check(ridge_box.position.x>=-290.01 and ridge_box.end.x<=-20 and ridge_box.position.z>=-720.01 and ridge_box.end.z<=-524.99 and ridge_box.size.y>19.6 and ridge_box.size.y<=30.0,"low inland ridge fills critical rays while keeping its crest below the accepted painted town peaks")
  var surface: StandardMaterial3D=fill.get("ridge_surface_material") as StandardMaterial3D
  check(surface!=null and surface!=leaf_material and ridge.material_override==surface,"native ridge renders through one private material copy without replacing the shared foliage source")
  if surface!=null:
   check(surface.albedo_texture==leaf_material.albedo_texture,"private ridge material reuses the exact original pixel texture without a new raster")
   check(surface.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and surface.albedo_color.is_equal_approx(Color(.93,.87,1,1)) and not surface.no_depth_test and surface.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"actual ridge surface uses the bounded softer sampling and color while retaining opaque depth")
 check(fill.geometry_count==5,"one small tail-town overlay adds a card beside the unchanged ground, ridge and two returns")
 var painted_upper_samples:=0;var resources: Array=[]
 for i in fill.layers.size():
  var card: MeshInstance3D=fill.layers[i]
  var definition: Dictionary=fill.definitions[i]
  var material: StandardMaterial3D=fill.materials[i]
  var texture: Texture2D=material.albedo_texture
  var used: Rect2i=fill.used_rects[definition.id]
  var quad: QuadMesh=card.mesh
  var source_index: int=1 if definition.source_id=="skyline" else 0
  check(material==source.materials[source_index] and texture==source.textures[source_index],"northern return reuses the exact accepted material and texture resource")
  var image:=texture.get_image()
  check(image.detect_alpha()!=Image.ALPHA_NONE,"northern city retains genuine transparent sky")
  var sampled_min:=Vector2(material.uv1_offset.x,material.uv1_offset.y)*Vector2(image.get_size())
  var sampled_size:=Vector2(material.uv1_scale.x,material.uv1_scale.y)*Vector2(image.get_size())
  check(sampled_min.distance_to(Vector2(used.position))<.01 and sampled_size.distance_to(Vector2(used.size))<.01,"actual material source UVs use the accepted alpha crop")
  check(absf(quad.size.x/sampled_size.x-quad.size.y/sampled_size.y)<.0001,"north return preserves original painted building proportions")
  var box: AABB=card.transform*card.get_aabb()
  check(box.end.x<=-20 and card.position.z< -420,"northern return stays inland behind the terminal and outside the shipping channel")
  if i<2:check(box.position.y< -1,"accepted return footings remain buried below the original ground datum")
  check(box.is_equal_approx(fill.bounds[definition.id]) and card.basis.is_equal_approx(Basis.IDENTITY),"published bounds match fixed north-facing world planes")
  check(not material.no_depth_test and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and card.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"return planes retain foreground depth and never rotate or cast rectangular shadows")
  for row in 17:
   for column in 41:
    var uv:=Vector2((column+.5)/41.0,(row+.5)/17.0)
    var pixel: Vector2=sampled_min+uv*sampled_size
    if image.get_pixel(int(pixel.x),int(pixel.y)).a<material.alpha_scissor_threshold:continue
    var world: Vector3=card.global_transform*Vector3((uv.x-.5)*quad.size.x,(.5-uv.y)*quad.size.y,0)
    if camera.is_position_behind(world):continue
    var screen: Vector2=camera.unproject_position(world)/camera.get_viewport().get_visible_rect().size
    if screen.x>=0 and screen.x<=1 and screen.y>=0 and screen.y<=.65:painted_upper_samples+=1
  resources.append([card.get_instance_id(),quad.get_instance_id(),card.transform,material.get_instance_id(),texture.get_instance_id()])
 check(painted_upper_samples>0,"actual painted north city projects into the untouched ten-second arrival camera's upper view")
 check(fill.find_children("*","CollisionObject3D",true,false).is_empty() and fill.find_children("*","NavigationRegion3D",true,false).is_empty(),"horizon repair adds no physics or navigation")
 check(not fill.is_processing() and not fill.is_physics_processing() and not fill.has_method("tick"),"northern return owns no simulation clock")
 camera.set_view(&"port",0);await process_frame
 var after: Array=[]
 for i in fill.layers.size():
  var card: MeshInstance3D=fill.layers[i]
  after.append([card.get_instance_id(),card.mesh.get_instance_id(),card.transform,fill.materials[i].get_instance_id(),fill.materials[i].albedo_texture.get_instance_id()])
 check(resources==after,"camera changes reuse unchanged return meshes and art resources")
 var source_after: Array=[]
 for i in source.layers.size():source_after.append([source.layers[i].transform,source.layers[i].get_instance_id(),source.materials[i].get_instance_id(),source.textures[i].get_instance_id(),source.materials[i].uv1_scale,source.materials[i].uv1_offset])
 check(source.layers.size()==2 and source_state==source_after,"accepted western city cards and sampling remain exactly unchanged")
 check(leaf_state==[leaf_material.albedo_texture,leaf_material.albedo_color,leaf_material.texture_filter,leaf_material.transparency,leaf_material.no_depth_test,leaf_material.cull_mode],"shared native foliage texture, filter, color and material state remain unchanged")
 print("NORTH HORIZON painted upper arrival10 samples=",painted_upper_samples)
 camera.queue_free();fill.queue_free();source.queue_free();waterfront.queue_free();await process_frame
 finish()
func finish() -> void:
 print("HARBOR CITY HORIZON FILL "+str(checks)+" checks; "+("PASS[]" if failures.is_empty() else "FAIL "+str(failures)))
 quit(0 if failures.is_empty() else 1)
