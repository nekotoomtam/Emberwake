extends SceneTree
## Thirteen genuine native hybrid-city views; every camera is an original product
## camera. Never hide original foreground to expose the new distant scenery.
var g
var matte
var waterfront
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var views: Array=[]
var fixed: Array=[]
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
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func step(world_only: bool=false) -> void:
 await physics_frame
 var dt:=1.0/Engine.physics_ticks_per_second
 if world_only:g.world.tick(dt,g.camera)
 else:g.tick(dt)
func advance(seconds: float,world_only: bool=false) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step(world_only)
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE HYBRID CITY WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func inspection_ui() -> void:
 # Existing controls only; all native scenery and human art remain present.
 g.ui.menu.visible=false;g.ui.footer.visible=false;g.ui.back_button.visible=false;g.ui.caption.visible=false
func foreground_visible() -> bool:
 return g.world.main.visible and g.world.ship.visible and g.world.arrival.visible and g.world.backdrop.visible and g.world.lighthouse.visible and g.world.sea_surface.visible and waterfront.visible and matte.visible
func native_state(node: Node,result: Array) -> void:
 if node is Node3D:result.append([node.get_instance_id(),str(node.global_transform)])
 if node is MeshInstance3D:result.append([node.mesh.get_instance_id(),node.material_override.get_instance_id() if node.material_override!=null else 0])
 for child in node.get_children():native_state(child,result)
func hybrid_state() -> Array:
 var result: Array=[];native_state(waterfront,result);native_state(matte,result)
 for texture in matte.textures:result.append(texture.get_instance_id())
 return result
func projected_points(points: Array) -> Array:
 var result: Array=[]
 for point: Vector3 in points:result.append({"world":str(point),"screen":str(g.camera.unproject_position(point)),"behind_camera":g.camera.is_position_behind(point)})
 return result
func projected_cards() -> Array:
 var result: Array=[]
 for index in matte.layers.size():
  var definition: Dictionary=matte.definitions[index];var id_: String=str(definition.id);var box: AABB=matte.bounds[id_]
  result.append({"id":id_,"source":str(definition.path),"bounds":str(box),"used_rect":str(matte.used_rects[id_]),"material_uv_scale":str(matte.materials[index].uv1_scale),"material_uv_offset":str(matte.materials[index].uv1_offset),"projection_samples":projected_points([box.position,Vector3(box.end.x,box.position.y,box.position.z),box.end,Vector3(box.position.x,box.end.y,box.position.z),box.get_center()])})
 return result
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 check(image.save_png(output+"/"+label+".png")==OK,"native PNG written: "+label);shots.append(label)
 check(hybrid_state()==fixed and foreground_visible(),"fixed hybrid city and all original visible foreground retained: "+label)
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"original_camera":true,"camera_view":str(g.camera.view_id),"camera":str(g.camera.global_transform),"camera_age":g.camera._age,"fov":g.camera.fov,"phase":str(g.phase),"phase_age":g.phase_age,"arrival_progress":g.world.arrival.progress,"arrival_position":str(g.world.arrival.position),"world_clock":g.world.clock,"sea_clock":g.world.sea_surface.clock,"menu_visible":g.ui.menu.visible,"caption_visible":g.ui.caption.visible,"foreground_visible":foreground_visible(),"walker":str(g.walker.position) if g.walker!=null else null,"native_land_rect":str(waterfront.land_rect),"native_geometry_count":waterfront.geometry_count,"native_seam_projection":projected_points([Vector3(-164,0,-220),Vector3(-92,0,-220),Vector3(-20,0,-220)]),"layers":projected_cards()})
func finish() -> void:
 release_walk()
 if not output.is_empty():
  var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
  if file!=null:
   file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"native_window_position":str(DisplayServer.window_get_position()),"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"visual_gate":"Review native port/quay and all original arrival/coffee views through14seconds for continuous 3D coast, coherent inland art scale/occlusion and no floating strip. Bounds alone are not visual continuity proof; original northeast title may face open sea."},"  "));file.close()
  else:check(false,"write native hybrid evidence manifest")
 if g!=null:g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR HYBRID CITY v97 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native hybrid capture destination supplied")
 if output.is_empty():await finish();return
 DirAccess.make_dir_recursive_absolute(output)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 waterfront=g.world.get("hybrid_waterfront") if has_property(g.world,"hybrid_waterfront") else null
 matte=g.world.city_matte
 check(waterfront!=null and matte.layers.size()==2 and matte.build_errors.is_empty(),"actual hybrid prologue contains one native waterfront and two inland image cards")
 if waterfront==null or matte.layers.size()!=2 or not matte.build_errors.is_empty():await finish();return
 fixed=hybrid_state()
 g.set_view(&"port");g.camera.set_view(&"port",0);inspection_ui();await advance(.15,true)
 await shot("01-original-port-hybrid-continuity")
 g.set_view(&"quay");g.camera.set_view(&"quay",0);inspection_ui();await advance(.15,true)
 await shot("02-original-quay-camera")
 g.return_title();g.start_arrival();g.tick(0)
 check(is_equal_approx(g.world.arrival.progress,0),"original moving-camera sequence starts at true arrival zero")
 await shot("03-original-arrival-00-seconds")
 var labels: Array=["04-original-arrival-02-seconds","05-original-arrival-04-seconds","06-original-arrival-06-seconds","07-original-arrival-08-seconds"]
 for index in labels.size():
  await advance(2.0)
  check(is_equal_approx(g.world.arrival.progress,float(index+1)/4.0),"genuine original arrival progress at "+str((index+1)*2)+" seconds")
  await shot(labels[index])
 # Docking ends at8s, while the original higher curved camera continues to
 # the cafe at14s. Cover that remaining authored rail before resetting it.
 await advance(2.0)
 await shot("07b-original-arrival-10-seconds")
 await advance(2.0)
 await shot("07c-original-arrival-12-seconds")
 await advance(2.15)
 check(g.phase==&"line" and g.walker==null,"original higher camera reaches its genuine coffee handoff at14.15seconds")
 await shot("07d-original-coffee-handoff-14-seconds")
 g.return_title();await advance(.15)
 await shot("08-original-northeast-title")
 g.start_arrival();g.skip_arrival();g.tick(0);await advance(.1)
 var entered: bool=await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16.5,.055,7.2),Vector3(-10,.055,7.2)])
 check(entered,"actual carrying protagonist walks through the preserved cafe/forecourt route")
 if not entered:await finish();return
 await advance(1.3)
 check(g.phase==&"play" and g.ui.caption.visible,"normal follow-camera photograph retains its ordinary gameplay HUD")
 await shot("09-actual-follow-camera-and-hud")
 g.return_title();root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640)
 g.set_view(&"port");g.camera.set_view(&"port",0);inspection_ui();await advance(.15,true)
 await shot("10-original-port-small-1024-window")
 check(root.get_texture().get_width()==1024 and root.get_texture().get_height()==640,"small original-port photograph uses the genuine native 1024-by-640 viewport")
 check(shots.size()==13,"thirteen useful original-camera hybrid photographs captured")
 await finish()
