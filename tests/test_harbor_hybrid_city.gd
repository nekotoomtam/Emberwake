extends SceneTree
## Focused actual-prologue evidence for a native coast extension with two
## retained inland paintings. Exact visual continuity remains a native gate.
const SOURCE_HASHES: Dictionary={
 "harbor_sea_surface.gd":"59770283CC83F15BB9C02445BF541F02CC98965480514E94A0FA5A6515AC8816",
 "harbor_clear_sky.gd":"AD1D82BD924FC6294448DC87F55DD54E594174CFB3E44D4A6FC9B3185094CFED",
 "harbor_lighthouse.gd":"0DA04B548D29A7E1247D3598FD20430156B8B74EAC28B1BC70EF913C5DFBC0A4",
}
const ART_HASHES: Dictionary={
 "rooftops.png":"36B621638B0B517BD986F3F72A1828D22A6A47472B66E4736D1811F5356BC844",
 "skyline-no-clock-v96.png":"E39543A7971F008014FA967BB0EB45EDFDDAC79C6560452B1D52A2730A418161"}
var g
var checks:=0
var failures: Array=[]
var lowest_y:=INF
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,label: String) -> bool:
 for property in object.get_property_list():
  if property.name==label:return true
 return false
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func step() -> void:
 await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
 if g.walker!=null:lowest_y=minf(lowest_y,g.walker.position.y)
func advance(seconds: float) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step()
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("HYBRID CITY WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func actors() -> Array:
 return g.world.townspeople+g.world.crew+g.world.arrival.crew+g.world.plaza.people+g.world.bench_life.actors+g.world.passenger_forecourt.life.actors
func identities() -> Array:
 var result: Array=[]
 for actor in actors():result.append([actor.get_instance_id(),actor.profile.duplicate(true)])
 return result
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
func hybrid_state(owner: Node3D,matte: Node3D) -> Array:
 var result: Array=[];native_state(owner,result);native_state(matte,result)
 for texture in matte.textures:result.append(texture.get_instance_id())
 return result
func rendered_top_at(main: Node,at: Vector3) -> bool:
 # Actual batched native triangles, not marker coordinates or collider boxes.
 for node in main.find_children("*","MeshInstance3D",true,false):
  if node.mesh==null:continue
  var faces: PackedVector3Array=node.mesh.get_faces()
  for index in range(0,faces.size()-2,3):
   var a: Vector3=node.global_transform*faces[index];var b: Vector3=node.global_transform*faces[index+1];var c: Vector3=node.global_transform*faces[index+2]
   if maxf(absf(a.y-at.y),maxf(absf(b.y-at.y),absf(c.y-at.y)))>.006:continue
   var triangle:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
   if Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),triangle):return true
 return false
func original_draw_sources() -> Array:
 var sky_id:=0
 for node in g.world.get_children():
  if node is WorldEnvironment:sky_id=node.environment.sky.get_instance_id()
 return [g.world.main.get_instance_id(),g.world.ship.get_instance_id(),g.world.arrival.ship.get_instance_id(),g.world.lighthouse.get_instance_id(),g.world.backdrop.get_instance_id(),g.world.sea_surface.near_mesh.mesh.get_instance_id(),g.world.sea_surface.far_mesh.mesh.get_instance_id(),g.world.water_material.get_instance_id(),sky_id,g.world.plaza.travel_luggage.get_instance_id()]
func clocks_agree() -> bool:
 var okay:=is_equal_approx(g.world.sea_surface.clock,g.world.clock) and is_equal_approx(float(g.world.water_material.get_shader_parameter("clock")),g.world.clock)
 for material in g.world.cloth_materials:okay=okay and is_equal_approx(float(material.get_shader_parameter("clock")),g.world.clock)
 return okay
func foreground_visible() -> bool:
 return g.world.main.visible and g.world.ship.visible and g.world.arrival.visible and g.world.backdrop.visible and g.world.lighthouse.visible and g.world.sea_surface.visible
func finish() -> void:
 release_walk()
 if g!=null:g.audio.shutdown();g.free()
 print("HARBOR HYBRID CITY v97 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 # A clean RED does not need image import resources or a partly built scene.
 var declared=load("res://scripts/opening/harbor_world.gd").new()
 var declared_owner:=has_property(declared,"hybrid_waterfront");declared.free()
 check(declared_owner,"World declares the native 3D waterfront owner instead of a painted waterfront")
 if not declared_owner:finish();return
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var owner=g.world.get("hybrid_waterfront")
 check(owner!=null,"actual prologue composes the static native 3D waterfront")
 if owner==null:finish();return
 var matte=g.world.city_matte;var ids: Array=[];var paths: Array=[]
 for definition in matte.definitions:ids.append(str(definition.id));paths.append(str(definition.path))
 check(ids==["rooftops","skyline"] and paths==["res://assets/city_backdrop/rooftops.png","res://assets/city_backdrop/skyline-no-clock-v96.png"],"hybrid city retains exactly the original roofs and no-clock skyline cards, with no painted waterfront")
 if ids!=["rooftops","skyline"]:finish();return
 check(owner.get_parent()==g.world and matte.get_parent()==g.world and forbidden_nodes(owner)==0 and forbidden_nodes(matte)==0 and not owner.has_method("tick") and not matte.has_method("tick"),"one world owner per static district/card group introduces no physics, navigation, HUD or simulation tick")
 check(matte.layers.size()==2 and matte.materials.size()==2 and matte.textures.size()==2 and matte.build_errors.is_empty(),"two original inland raster resources build cleanly beside the native district")
 if matte.layers.size()!=2 or not matte.build_errors.is_empty():finish();return
 var source_ok:=true
 for path_ in SOURCE_HASHES:source_ok=source_ok and FileAccess.get_sha256("res://scripts/opening/"+path_).to_upper()==SOURCE_HASHES[path_]
 for path_ in ART_HASHES:source_ok=source_ok and FileAccess.get_sha256("res://assets/city_backdrop/"+path_).to_upper()==ART_HASHES[path_]
 check(source_ok,"sky/sea, lighthouse and both retained paintings remain byte-identical; camera v104 and appearance wiring v107 are intentional revisions")
 var seam_matches:=is_equal_approx(owner.land_rect.end.y,-220.0) and is_equal_approx(owner.land_rect.position.x,-164.0) and is_equal_approx(owner.land_rect.end.x,-20.0)
 for x in [-160.0,-92.0,-24.0]:
  seam_matches=seam_matches and rendered_top_at(g.world.backdrop.b,Vector3(x,0,-219.97)) and rendered_top_at(owner.main,Vector3(x,0,-220.03))
 check(seam_matches,"actual old/new land-top triangles meet across the original z=-220 west-bank seam without a water gap")
 var native_depth:=true;var native_meshes:=0
 for node in owner.find_children("*","MeshInstance3D",true,false):
  native_meshes+=1
  for surface in node.mesh.get_surface_count():
   var material: Material=node.get_active_material(surface)
   native_depth=native_depth and material is StandardMaterial3D and not material.no_depth_test and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
 check(native_meshes>0 and native_depth,"the connected working waterfront uses actual opaque depth-tested native meshes")
 var rear_depth:=true;var depths: Dictionary={}
 for index in matte.layers.size():
  var definition: Dictionary=matte.definitions[index];var id_: String=str(definition.id);var material: StandardMaterial3D=matte.materials[index];var used: Rect2i=matte.used_rects[id_]
  var actual: AABB=matte.layers[index].global_transform*matte.layers[index].mesh.get_aabb();depths[matte.layers[index].global_position.x]=true
  var horizontal_span:=maxf(actual.size.x,actual.size.z)
  rear_depth=rear_depth and matte.bounds[id_].end.x<=owner.land_rect.position.x and is_equal_approx(actual.size.y/horizontal_span,float(used.size.y)/used.size.x) and not material.no_depth_test and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and matte.layers[index].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(depths.size()==2 and rear_depth,"both original-aspect fixed inland cards stay west of the actual native city edge at different X depths with no foreground shadows")
 if depths.size()!=2 or not rear_depth:finish();return
 var fixed:=hybrid_state(owner,matte);var original_people:=identities();var draws:=original_draw_sources();var bodies:=body_count(g.world)
 for view: StringName in [&"port",&"quay",&"lighthouse"]:
  g.camera.set_view(view,0);g.tick(.01)
  check(hybrid_state(owner,matte)==fixed and foreground_visible(),"unchanged original "+str(view)+" camera preserves fixed hybrid resources and all foreground owners")
 g.return_title();g.start_arrival();g.tick(0)
 check(g.phase==&"flyin" and is_equal_approx(g.world.arrival.progress,0),"the unchanged original arrival starts at its genuine frame zero")
 for seconds in [2.0,4.0,6.0,8.0]:
  await advance(2.0)
  check(is_equal_approx(g.world.arrival.progress,seconds/8.0) and hybrid_state(owner,matte)==fixed and foreground_visible(),"original arrival at "+str(seconds)+"s moves camera/ship past fixed connected city resources")
 g.skip_arrival();g.tick(0);await step()
 check(g.phase==&"play" and g.walker is CharacterBody3D and g.world.plaza.travel_luggage.state==&"carried","normal intro handoff retains the actual carrying protagonist")
 if g.walker==null:finish();return
 check(await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16.5,.055,7.2),Vector3(-1.0,.055,7.2)]),"actual controller leaves the cafe and crosses the unchanged passenger forecourt")
 var aboard: bool=await route([Vector3(-1.8,.055,11.6),Vector3(-1.8,.055,13.2),Vector3(13.5,.055,13.2),Vector3(13.5,.055,11.6),Vector3(13,.055,2.7),Vector3(13,.15,-2),Vector3(12,2.315,-4.8)])
 check(aboard and g.walker.position.y>2.2 and lowest_y>-.05,"ordinary player follows the old porter bypass and supported gangway to the original deck")
 check(hybrid_state(owner,matte)==fixed and body_count(g.world)==bodies and forbidden_nodes(owner)==0,"arrival/cameras/walking create no hybrid geometry/resources or gameplay bodies")
 check(identities()==original_people and original_draw_sources()==draws and clocks_agree(),"all original actor profiles/identities, sky/sea/foreground/luggage owners and animation clocks remain intact")
 finish()
