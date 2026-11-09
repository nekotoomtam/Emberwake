extends SceneTree
## Narrow v99 consumer gate: retained horizon fill plus native inland ridge.
const SOURCE_HASHES: Dictionary={
 "harbor_city_matte.gd":"63B0102AC87E261D1EDA954515D893433C4011127D6B64264684DBFD76B6BC0A",
 "harbor_city_waterfront_3d.gd":"CC510E3EDF5AB1B7A069D66732D9E9C53479FE953774B8C2DB1FA6FE19918F2D",
 "harbor_camera.gd":"7FADE685A12251661701714D1264251EC3A2D6318EBF858EFE2F5566381DACD4",
 "harbor_sea_surface.gd":"59770283CC83F15BB9C02445BF541F02CC98965480514E94A0FA5A6515AC8816",
 "harbor_clear_sky.gd":"AD1D82BD924FC6294448DC87F55DD54E594174CFB3E44D4A6FC9B3185094CFED"}
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,label: String) -> bool:
 for property in object.get_property_list():
  if property.name==label:return true
 return false
func step() -> void:
 await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
func advance(seconds: float) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step()
func forbidden_nodes(node: Node) -> int:
 var count_:=1 if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is NavigationAgent3D or node is CanvasItem or node is CanvasLayer or node is Camera3D else 0
 for child in node.get_children():count_+=forbidden_nodes(child)
 return count_
func body_count(node: Node) -> int:
 var count_:=1 if node is PhysicsBody3D else 0
 for child in node.get_children():count_+=body_count(child)
 return count_
func native_state(node: Node,result: Array) -> void:
 if node is Node3D:result.append([node.get_instance_id(),node.global_transform])
 if node is MeshInstance3D:
  result.append([node.mesh.get_instance_id(),node.material_override.get_instance_id() if node.material_override!=null else 0])
 for child in node.get_children():native_state(child,result)
func state(node: Node) -> Array:
 var result: Array=[];native_state(node,result);return result
func identities() -> Array:
 var result: Array=[]
 for actor in g.world.townspeople+g.world.crew+g.world.arrival.crew+g.world.plaza.people+g.world.bench_life.actors+g.world.passenger_forecourt.life.actors:result.append([actor.get_instance_id(),actor.profile.duplicate(true)])
 return result
func sea_sky_sources() -> Array:
 var sky_id:=0
 for node in g.world.get_children():
  if node is WorldEnvironment:sky_id=node.environment.sky.get_instance_id()
 return [g.world.sea_surface.near_mesh.mesh.get_instance_id(),g.world.sea_surface.far_mesh.mesh.get_instance_id(),g.world.water_material.get_instance_id(),sky_id,g.world.lighthouse.get_instance_id(),g.world.plaza.travel_luggage.get_instance_id()]
func clocks_agree() -> bool:
 var okay:=is_equal_approx(g.world.sea_surface.clock,g.world.clock) and is_equal_approx(float(g.world.water_material.get_shader_parameter("clock")),g.world.clock)
 for material in g.world.cloth_materials:okay=okay and is_equal_approx(float(material.get_shader_parameter("clock")),g.world.clock)
 return okay
func foreground_visible() -> bool:
 return g.world.main.visible and g.world.ship.visible and g.world.arrival.visible and g.world.backdrop.visible and g.world.lighthouse.visible and g.world.sea_surface.visible and g.world.hybrid_waterfront.visible and g.world.city_matte.visible
func finish() -> void:
 if g!=null:g.audio.shutdown();g.free()
 print("HARBOR HORIZON FILL v99 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 var declared=load("res://scripts/opening/harbor_world.gd").new()
 var declared_owner:=has_property(declared,"horizon_fill");declared.free()
 check(declared_owner,"World declares an additive inland horizon-fill owner")
 if not declared_owner:finish();return
 var declared_fill=load("res://scripts/opening/harbor_city_horizon_fill.gd").new()
 var declared_ridge:=has_property(declared_fill,"ridge_mesh") and has_property(declared_fill,"ridge_material") and has_property(declared_fill,"ridge_surface_material");declared_fill.free()
 check(declared_ridge,"horizon owner declares actual native ridge geometry plus source and private surface materials")
 if not declared_ridge:finish();return
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var fill=g.world.get("horizon_fill")
 check(fill!=null,"actual prologue composes the additive inland horizon fill")
 if fill==null:finish();return
 var matte=g.world.city_matte;var waterfront=g.world.hybrid_waterfront
 check(fill.get_parent()==g.world and fill.source_matte==matte and fill.source_waterfront==waterfront,"the new additive owner uses the actual accepted western matte and native waterfront owners")
 check(forbidden_nodes(fill)==0 and not fill.has_method("tick") and not fill.is_processing() and not fill.is_physics_processing(),"horizon fill adds only static world geometry without bodies, navigation, HUD/camera or animation ownership")
 var sources_unchanged:=true
 for path_ in SOURCE_HASHES:sources_unchanged=sources_unchanged and FileAccess.get_sha256("res://scripts/opening/"+path_).to_upper()==SOURCE_HASHES[path_]
 check(sources_unchanged,"accepted western matte/native waterfront and original camera/sea/sky source stay byte-identical to v97")
 var panels: Array=fill.layers
 var source_ids: Array=[]
 for definition in fill.definitions:source_ids.append(str(definition.source_id))
 check(panels.size()==3 and source_ids==["rooftops","skyline","rooftops"],"additive scope contains exactly the approved rooftops/skyline returns and retained-rooftops tail-town overlay")
 var exact_reuse:=not panels.is_empty();var inland:=not panels.is_empty()
 for panel in panels:
  var actual: AABB=panel.global_transform*panel.mesh.get_aabb()
  inland=inland and actual.end.z<=waterfront.land_rect.position.y and actual.end.x<=waterfront.land_rect.end.x
  for surface in panel.mesh.get_surface_count():
   var material: Material=panel.get_active_material(surface)
   exact_reuse=exact_reuse and material in matte.materials and material.albedo_texture in matte.textures and not material.no_depth_test and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and panel.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(exact_reuse,"native return panels reuse the exact retained alpha materials/textures with real depth and no foreground shadows")
 var ground_meshes:=0;var native_ground:=true
 for node in fill.find_children("*","MeshInstance3D",true,false):
  if node in panels or node==fill.ridge_mesh:continue
  ground_meshes+=1
  var actual: AABB=node.global_transform*node.mesh.get_aabb()
  inland=inland and actual.end.z<=waterfront.land_rect.position.y+.001 and actual.end.x<=waterfront.land_rect.end.x+.001
  for surface in node.mesh.get_surface_count():
   var material: Material=node.get_active_material(surface)
   native_ground=native_ground and material in waterfront.materials.values() and material is StandardMaterial3D and not material.no_depth_test and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
 check(ground_meshes==1 and native_ground and fill.ground_material==waterfront.materials.stone,"retained visual inland ground alone borrows the exact existing opaque native waterfront stone")
 var ridge: MeshInstance3D=fill.ridge_mesh;var ridge_source: StandardMaterial3D=fill.ridge_material;var ridge_material: StandardMaterial3D=fill.ridge_surface_material
 var source_color: Color=g.world.materials.leaves.albedo_color;var source_filter: int=g.world.materials.leaves.texture_filter
 var ridge_ok: bool=ridge!=null and ridge_source==g.world.materials.leaves and ridge_material!=ridge_source and ridge.material_override==ridge_material and ridge_material.albedo_texture==ridge_source.albedo_texture and not ridge_material.no_depth_test and ridge_material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
 if ridge!=null:
  var ridge_box: AABB=ridge.global_transform*ridge.mesh.get_aabb()
  ridge_ok=ridge_ok and ridge_box.end.x<=-20.0+.001 and ridge_box.end.z<=-525.0+.001
 check(ridge_ok,"native inland ridge uses a private opaque depth-tested surface sharing the exact World foliage texture and stays west/north of the offshore channel")
 check(source_color==Color.WHITE and source_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST,"private ridge finish leaves the original shared foliage color/filter unchanged")
 check(fill.find_children("*","MeshInstance3D",true,false).size()==5,"additive scope retains exactly three art cards, one original ground mesh and one native ridge")
 check(inland,"actual return and ground geometry stay north of the accepted terminal and west of its offshore east edge")
 var fixed:=state(fill);var old_matte:=state(matte);var old_waterfront:=state(waterfront);var people:=identities();var bodies:=body_count(g.world);var sources:=sea_sky_sources()
 for view: StringName in [&"port",&"quay",&"lighthouse"]:
  g.camera.set_view(view,0);g.tick(.01)
  check(state(fill)==fixed and state(matte)==old_matte and state(waterfront)==old_waterfront and foreground_visible(),"original "+str(view)+" camera retains additive and accepted hybrid transforms/resources/foreground")
 g.return_title();g.start_arrival();g.tick(0);await advance(6.0)
 for seconds in [6.0,8.0,10.0,12.0]:
  if seconds>6.0:await advance(2.0)
  check(is_equal_approx(g.camera._age,seconds) and state(fill)==fixed and state(matte)==old_matte and state(waterfront)==old_waterfront and foreground_visible(),"authored higher camera at "+str(seconds)+"s observes the fixed additive fill without replacing any foreground")
 check(body_count(g.world)==bodies and forbidden_nodes(fill)==0 and identities()==people,"original camera rail creates no horizon resources, gameplay bodies or actor/profile changes")
 check(sea_sky_sources()==sources and clocks_agree(),"actual animated sea, sky, lighthouse/luggage owners and original shader clocks stay intact")
 check(g.world.materials.leaves.albedo_color==source_color and g.world.materials.leaves.texture_filter==source_filter,"original camera activity preserves the same shared foliage color/filter")
 finish()
