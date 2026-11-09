extends SceneTree
## The actual prologue owns three far static cards; original cameras, sea,
## identities, native foreground and supported player movement remain real.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const SOURCE_HASHES: Dictionary={
 "harbor_camera.gd":"7FADE685A12251661701714D1264251EC3A2D6318EBF858EFE2F5566381DACD4",
 "harbor_sea_surface.gd":"59770283CC83F15BB9C02445BF541F02CC98965480514E94A0FA5A6515AC8816",
 "harbor_clear_sky.gd":"AD1D82BD924FC6294448DC87F55DD54E594174CFB3E44D4A6FC9B3185094CFED",
 "harbor_lighthouse.gd":"0DA04B548D29A7E1247D3598FD20430156B8B74EAC28B1BC70EF913C5DFBC0A4",
 "harbor_walker.gd":"81F1D664F1628F9B3549A3CA9096FE892B357F33DA33FDBD419D7DD8D39CEF38",
 "harbor_travel_luggage.gd":"12E3B11F684A39BB339BB49BBFCC4335FF5218649142DBE6831B957F2866833A"}
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
 release_walk();printerr("CITY MATTE WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func people() -> Array:
 return g.world.townspeople+g.world.crew+g.world.arrival.crew+g.world.plaza.people+g.world.bench_life.actors+g.world.passenger_forecourt.life.actors
func identities(actors: Array) -> Array:
 var result: Array=[]
 for actor in actors:result.append([actor.get_instance_id(),actor.profile.duplicate(true)])
 return result
func forbidden_nodes(node: Node) -> int:
 var count_:=1 if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is NavigationAgent3D or node is CanvasItem or node is CanvasLayer or node is Camera3D else 0
 for child in node.get_children():count_+=forbidden_nodes(child)
 return count_
func body_count(node: Node) -> int:
 var count_:=1 if node is PhysicsBody3D else 0
 for child in node.get_children():count_+=body_count(child)
 return count_
func card_state(matte: Node3D) -> Array:
 var result: Array=[]
 for index in matte.layers.size():
  var layer: MeshInstance3D=matte.layers[index]
  result.append([layer.get_instance_id(),layer.global_transform,layer.mesh.get_instance_id(),layer.material_override.get_instance_id(),matte.textures[index].get_instance_id()])
 return result
func projections(matte: Node3D) -> Array:
 var result: Array=[]
 for layer in matte.layers:result.append(g.camera.unproject_position(layer.global_position))
 return result
func alpha_content(path_: String) -> bool:
 var image:=Image.load_from_file(ProjectSettings.globalize_path(path_))
 if image==null or image.is_empty() or image.detect_alpha()==Image.ALPHA_NONE:return false
 var transparent:=false;var opaque:=false
 var pitch: int=maxi(1,mini(image.get_width(),image.get_height())/128)
 for y in range(0,image.get_height(),pitch):
  for x in range(0,image.get_width(),pitch):
   var alpha:=image.get_pixel(x,y).a
   transparent=transparent or alpha<.001;opaque=opaque or alpha>.95
 return transparent and opaque
func original_draw_sources() -> Array:
 var environment: WorldEnvironment
 for node in g.world.get_children():
  if node is WorldEnvironment:environment=node
 return [g.world.main.get_instance_id(),g.world.ship.get_instance_id(),g.world.arrival.ship.get_instance_id(),g.world.lighthouse.get_instance_id(),g.world.backdrop.get_instance_id(),g.world.sea_surface.near_mesh.mesh.get_instance_id(),g.world.sea_surface.far_mesh.mesh.get_instance_id(),g.world.water_material.get_instance_id(),environment.environment.sky.get_instance_id(),g.world.plaza.travel_luggage.get_instance_id()]
func clocks_agree() -> bool:
 var okay:=is_equal_approx(g.world.sea_surface.clock,g.world.clock) and is_equal_approx(float(g.world.water_material.get_shader_parameter("clock")),g.world.clock)
 for material in g.world.cloth_materials:okay=okay and is_equal_approx(float(material.get_shader_parameter("clock")),g.world.clock)
 return okay
func finish() -> void:
 release_walk();g.audio.shutdown();g.free()
 print("HARBOR CITY MATTE INTEGRATION ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var matte=g.world.get("city_matte") if has_property(g.world,"city_matte") else null
 check(matte!=null,"actual prologue composes the layered city matte owner")
 if matte==null:finish();return
 check(matte.layers.size()==3,"the actual world contains three static original-raster city layers")
 if matte.layers.size()!=3:finish();return
 check(matte.geometry_count==3 and matte.materials.size()==3 and matte.textures.size()==3,"one owner retains exactly three native card meshes/materials/textures")
 check(matte.build_errors.is_empty(),"all three selected original PNG assets load without a helper build error")
 check(matte.get_parent()==g.world and forbidden_nodes(matte)==0 and not matte.is_processing() and not matte.is_physics_processing() and not matte.has_method("tick"),"city cards stay world-owned static visuals without physics, navigation, camera or HUD/tick ownership")
 var original_people:=identities(people());var draws:=original_draw_sources();var bodies:=body_count(g.world);var cards:=card_state(matte)
 var ids: Dictionary={};var depths: Dictionary={};var exact_materials:=true
 for index in matte.layers.size():
  var definition: Dictionary=matte.definitions[index];var id_: String=str(definition.id);var layer: MeshInstance3D=matte.layers[index];var material: StandardMaterial3D=matte.materials[index]
  ids[id_]=true;depths[layer.global_position.z]=true
  check(alpha_content(str(definition.path)),"actual original PNG contains both clear alpha and opaque city artwork: "+id_)
  var used: Rect2i=matte.used_rects[id_];var box: AABB=matte.bounds[id_]
  var actual: AABB=layer.global_transform*layer.mesh.get_aabb()
  check(used.has_area() and is_equal_approx(actual.size.y/actual.size.x,float(used.size.y)/used.size.x),"world plane preserves the selected original used-rectangle aspect: "+id_)
  check(box.position.z< -220 and box.end.z< -220 and layer.global_position.z< -220,"city layer remains beyond the existing native coast/lighthouse: "+id_)
  exact_materials=exact_materials and layer.material_override==material and material.albedo_texture==matte.textures[index] and not material.no_depth_test and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED and layer.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(ids.size()==3 and depths.size()==3 and exact_materials,"three different world depths use alpha/depth-aware fixed cards without camera-facing spin or foreground shadows")
 var source_ok:=true
 for path_ in SOURCE_HASHES:source_ok=source_ok and FileAccess.get_sha256("res://scripts/opening/"+path_).to_upper()==SOURCE_HASHES[path_]
 check(source_ok,"original camera, clear sky, sea, lighthouse, controller and luggage source remain byte-identical to v94")
 check(is_equal_approx(g.camera.far,5000) and g.world.sea_surface.far_mesh.mesh.get_aabb().position.z<=-5500 and g.world.lighthouse.position==Vector3(42,0,-155),"original far draw, extended ocean and separate lighthouse keep their authored extents")
 var title_projection:=projections(matte);var before_clock: float=g.world.clock
 g.world.tick(.125,g.camera)
 check(is_equal_approx(g.world.clock,before_clock+.125) and clocks_agree(),"one ordinary World tick still owns the original sea and cloth shader clocks")
 for view: StringName in [&"quay",&"port",&"cafe",&"lighthouse"]:
  g.camera.set_view(view,0);g.tick(.01)
  check(card_state(matte)==cards,"original "+str(view)+" camera leaves all card transforms and resources fixed")
 g.camera.set_view(&"port",0)
 var port_projection:=projections(matte);var separation_changed:=false
 for index in range(1,3):
  separation_changed=separation_changed or (title_projection[index]-title_projection[0]).distance_to(port_projection[index]-port_projection[0])>.5
 check(separation_changed,"different original camera positions produce real depth-dependent city projections")
 g.return_title();g.start_arrival();g.tick(0)
 check(g.phase==&"flyin" and is_equal_approx(g.camera._age,0),"original arrival begins with its existing camera trajectory")
 await advance(4.0)
 check(g.phase==&"flyin" and is_equal_approx(g.world.arrival.progress,.5) and card_state(matte)==cards,"four-second original arrival moves the native ship/camera past fixed city cards")
 await advance(4.0)
 check(g.world.arrival.docked and g.world.arrival.position.is_equal_approx(Vector3(12,-.55,-38)) and card_state(matte)==cards,"eight-second original arrival docks without moving/rebuilding the city layers")
 g.skip_arrival();g.tick(0);await step()
 check(g.phase==&"play" and g.walker is CharacterBody3D and g.world.plaza.travel_luggage.state==&"carried","ordinary intro skip retains the same real controllable carrying protagonist")
 if g.walker==null:finish();return
 check(await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16.5,.055,7.2),Vector3(-1.0,.055,7.2)]),"actual player crosses the preserved passenger forecourt through the original cafe connector")
 var aboard: bool=await route([Vector3(-1.8,.055,11.6),Vector3(-1.8,.055,13.2),Vector3(13.5,.055,13.2),Vector3(13.5,.055,11.6),Vector3(13,.055,2.7),Vector3(13,.15,-2),Vector3(12,2.315,-4.8)])
 check(aboard and g.walker.position.y>2.2 and lowest_y>-.05,"actual supported walking still uses the old porter bypass and original boarding mouth/ramp/deck")
 check(card_state(matte)==cards and forbidden_nodes(matte)==0 and body_count(g.world)==bodies,"walk/arrival/camera activity creates no city resources or additional physics bodies")
 check(identities(people())==original_people and original_draw_sources()==draws and clocks_agree(),"native foreground, sky, water, luggage and every old identity retain their owners/resources/clock")
 check(g.world.main.visible and g.world.ship.visible and g.world.arrival.visible and g.world.backdrop.visible and g.world.lighthouse.visible and g.world.sea_surface.visible,"all original foreground, native city, lighthouse and sea remain visible")
 finish()
