extends SceneTree
## Nine unedited native v99 views target the remaining right inland-water tail.
## Original cameras, accepted western art/native district and sea remain real.
var g
var fill
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var views: Array=[]
var fixed: Array=[]
var old_matte: Array=[]
var old_waterfront: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,label: String) -> bool:
 for property in object.get_property_list():
  if property.name==label:return true
 return false
func step(world_only: bool=false) -> void:
 await physics_frame
 var dt:=1.0/Engine.physics_ticks_per_second
 if world_only:g.world.tick(dt,g.camera)
 else:g.tick(dt)
func advance(seconds: float,world_only: bool=false) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step(world_only)
func inspection_ui() -> void:
 # Existing controls only: every original foreground object stays visible.
 g.ui.menu.visible=false;g.ui.footer.visible=false;g.ui.back_button.visible=false;g.ui.caption.visible=false
func foreground_visible() -> bool:
 return g.world.main.visible and g.world.ship.visible and g.world.arrival.visible and g.world.backdrop.visible and g.world.lighthouse.visible and g.world.sea_surface.visible and g.world.hybrid_waterfront.visible and g.world.city_matte.visible
func native_state(node: Node,result: Array) -> void:
 if node is Node3D:result.append([node.get_instance_id(),str(node.global_transform)])
 if node is MeshInstance3D:result.append([node.mesh.get_instance_id(),node.material_override.get_instance_id() if node.material_override!=null else 0])
 for child in node.get_children():native_state(child,result)
func state(node: Node) -> Array:
 var result: Array=[];native_state(node,result);return result
func projected_points(points: Array) -> Array:
 var result: Array=[]
 for point: Vector3 in points:result.append({"world":str(point),"screen":str(g.camera.unproject_position(point)),"behind_camera":g.camera.is_position_behind(point)})
 return result
func projected_returns() -> Array:
 var result: Array=[]
 for node in fill.find_children("*","MeshInstance3D",true,false):
  var box: AABB=node.global_transform*node.mesh.get_aabb();var material: Material=node.get_active_material(0)
  result.append({"name":str(node.name),"kind":"native_ridge" if node==fill.ridge_mesh else "retained_ground" if node==fill.ground else "retained_art_return","world_bounds":str(box),"world_transform":str(node.global_transform),"material":material.get_instance_id(),"texture":material.albedo_texture.get_instance_id(),"private_ridge_surface":node==fill.ridge_mesh and material!=g.world.materials.leaves,"shared_world_foliage_texture":material.albedo_texture==g.world.materials.leaves.albedo_texture,"projection_samples":projected_points([box.position,Vector3(box.end.x,box.position.y,box.position.z),box.end,Vector3(box.position.x,box.end.y,box.end.z),box.get_center()])})
 return result
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 check(image.save_png(output+"/"+label+".png")==OK,"native PNG written: "+label);shots.append(label)
 check(state(fill)==fixed and state(g.world.city_matte)==old_matte and state(g.world.hybrid_waterfront)==old_waterfront and foreground_visible(),"additive fill and accepted hybrid/native foreground retained: "+label)
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"original_camera":true,"camera_view":str(g.camera.view_id),"camera":str(g.camera.global_transform),"camera_age":g.camera._age,"fov":g.camera.fov,"phase":str(g.phase),"phase_age":g.phase_age,"arrival_progress":g.world.arrival.progress,"arrival_position":str(g.world.arrival.position),"world_clock":g.world.clock,"sea_clock":g.world.sea_surface.clock,"caption_visible":g.ui.caption.visible,"foreground_visible":foreground_visible(),"north_roof_edge_projection":projected_points([Vector3(-160,9,-415),Vector3(-100,9,-415),Vector3(-41,9,-415)]),"north_returns":projected_returns()})
func finish() -> void:
 if not output.is_empty():
  var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
  if file!=null:
   file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"native_window_position":str(DisplayServer.window_get_position()),"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"visual_gate":"Compare actual critical10-second native views with v98 for the remaining right inland-water tail and natural native ridge joins behind north3D roofs. Review both1280 and1024 critical frames. Preserve offshore sea/lighthouse/channel and all accepted hybrid geometry. Projected bounds or texture-color counts cannot establish the visual correction."},"  "));file.close()
  else:check(false,"write native horizon-fill evidence manifest")
 if g!=null:g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR HORIZON FILL v99 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native horizon capture destination supplied")
 if output.is_empty():await finish();return
 DirAccess.make_dir_recursive_absolute(output)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 fill=g.world.get("horizon_fill") if has_property(g.world,"horizon_fill") else null
 check(fill!=null,"actual prologue composes the additive horizon fill")
 if fill==null:await finish();return
 check(has_property(fill,"ridge_mesh") and fill.ridge_mesh!=null,"actual revision contains the native ridge needed for right-tail coverage")
 if not has_property(fill,"ridge_mesh") or fill.ridge_mesh==null:await finish();return
 fixed=state(fill);old_matte=state(g.world.city_matte);old_waterfront=state(g.world.hybrid_waterfront)
 g.set_view(&"port");g.camera.set_view(&"port",0);inspection_ui();await advance(.15,true)
 await shot("01-original-port-additive-horizon")
 g.return_title();g.start_arrival();g.tick(0);await advance(6.0)
 check(is_equal_approx(g.camera._age,6.0),"original camera genuinely reaches the six-second authored position")
 await shot("02-original-arrival-06-seconds")
 await advance(2.0)
 check(g.world.arrival.docked and is_equal_approx(g.camera._age,8.0),"original eight-second view contains the genuinely docked native vessel")
 await shot("03-original-arrival-08-seconds")
 await advance(1.0)
 check(is_equal_approx(g.camera._age,9.0),"original nine-second view covers the authored camera between docking and the critical high rail")
 await shot("03b-original-arrival-09-seconds")
 await advance(1.0)
 check(is_equal_approx(g.camera._age,10.0),"critical upper-strip view uses the unchanged ten-second high rail")
 await shot("04-critical-original-arrival-10-seconds")
 await advance(1.0)
 check(is_equal_approx(g.camera._age,11.0),"original eleven-second view covers the authored camera after the critical high rail")
 await shot("04b-original-arrival-11-seconds")
 await advance(1.0)
 check(is_equal_approx(g.camera._age,12.0),"twelve-second view uses the original higher camera approaching the cafe")
 await shot("05-original-high-rail-12-seconds")
 g.return_title();g.set_view(&"quay");g.camera.set_view(&"quay",0);inspection_ui();await advance(.15,true)
 await shot("06-original-quay-camera")
 # A genuine smaller viewport repeats the critical authored camera, without
 # resizing a prior screenshot or changing any camera or artwork dimensions.
 g.return_title();root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640)
 g.start_arrival();g.tick(0);await advance(10.0)
 check(is_equal_approx(g.camera._age,10.0),"small critical frame reaches the same true ten-second camera position")
 await shot("07-critical-arrival-10-small-1024-window")
 check(root.get_texture().get_width()==1024 and root.get_texture().get_height()==640,"small critical image uses the actual 1024-by-640 native viewport")
 check(shots.size()==9,"nine focused original-camera horizon-fill photographs captured")
 await finish()
