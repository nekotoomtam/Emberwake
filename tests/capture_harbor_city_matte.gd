extends SceneTree
## Ten unedited native v95 views, predominantly the original camera sequence.
## Steep gameplay may naturally clip the far horizon; record that honestly.
var g
var matte
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var views: Array=[]
var fixed_cards: Array=[]
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
 # The native physics cadence preserves actors, motion and route queries.
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step(world_only)
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE CITY MATTE WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func inspection_ui() -> void:
 # UI only. Original buildings, people, vessels, lighthouse and sea stay on.
 g.ui.menu.visible=false;g.ui.footer.visible=false;g.ui.back_button.visible=false;g.ui.caption.visible=false
func foreground_visible() -> bool:
 return g.world.main.visible and g.world.ship.visible and g.world.arrival.visible and g.world.backdrop.visible and g.world.lighthouse.visible and g.world.sea_surface.visible
func cards_state() -> Array:
 var result: Array=[]
 for index in matte.layers.size():
  var layer: MeshInstance3D=matte.layers[index]
  result.append([layer.get_instance_id(),str(layer.global_transform),layer.mesh.get_instance_id(),layer.material_override.get_instance_id(),matte.textures[index].get_instance_id()])
 return result
func projected_cards() -> Array:
 var result: Array=[]
 for index in matte.layers.size():
  var definition: Dictionary=matte.definitions[index];var id_: String=str(definition.id);var layer: MeshInstance3D=matte.layers[index];var box: AABB=matte.bounds[id_]
  var points: Array=[];var in_frame:=0
  for at: Vector3 in [box.position,Vector3(box.end.x,box.position.y,box.position.z),box.end,Vector3(box.position.x,box.end.y,box.position.z),box.get_center()]:
   var screen: Vector2=g.camera.unproject_position(at);var behind: bool=g.camera.is_position_behind(at)
   var inside: bool=not behind and root.get_visible_rect().has_point(screen)
   if inside:in_frame+=1
   points.append({"world":str(at),"screen":str(screen),"behind_camera":behind,"inside_viewport":inside})
  # These samples describe projection only. Alpha artwork/native occlusion is
  # judged in the PNG; no claim of visible art follows from a bounding corner.
  result.append({"id":id_,"world_transform":str(layer.global_transform),"world_bounds":str(box),"source":str(definition.path),"used_rect":str(matte.used_rects[id_]),"mesh":layer.mesh.get_instance_id(),"material":layer.material_override.get_instance_id(),"texture":matte.textures[index].get_instance_id(),"sample_points_in_frame":in_frame,"projection_samples":points})
 return result
func shot(label: String,source_camera: bool=true) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 check(image.save_png(output+"/"+label+".png")==OK,"native PNG written: "+label);shots.append(label)
 check(cards_state()==fixed_cards and foreground_visible(),"fixed city resources and original visible foreground retained: "+label)
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"source_camera":source_camera,"camera_view":str(g.camera.view_id),"camera":str(g.camera.global_transform),"fov":g.camera.fov,"far":g.camera.far,"phase":str(g.phase),"phase_age":g.phase_age,"arrival_progress":g.world.arrival.progress,"arrival_position":str(g.world.arrival.position),"world_clock":g.world.clock,"sea_clock":g.world.sea_surface.clock,"menu_visible":g.ui.menu.visible,"caption_visible":g.ui.caption.visible,"foreground_visible":foreground_visible(),"walker":str(g.walker.position) if g.walker!=null else null,"layers":projected_cards()})
func finish() -> void:
 release_walk()
 if not output.is_empty():
  var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
  if file!=null:
   file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"native_window_position":str(DisplayServer.window_get_position()),"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"note":"Projection samples are not visibility proof. Review actual alpha silhouettes, sea, foreground depth and camera-dependent horizon clipping in the native PNGs."},"  "));file.close()
  else:check(false,"write native city matte evidence manifest")
 if g!=null:g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR CITY MATTE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native city capture destination supplied")
 if output.is_empty():await finish();return
 DirAccess.make_dir_recursive_absolute(output)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 matte=g.world.get("city_matte") if has_property(g.world,"city_matte") else null
 check(matte!=null,"actual prologue composes the original-raster city owner")
 if matte==null:await finish();return
 check(matte.layers.size()==3 and matte.build_errors.is_empty(),"all three native city card assets are ready")
 if matte.layers.size()!=3 or not matte.build_errors.is_empty():await finish();return
 fixed_cards=cards_state()
 # Keep the actual title menu here; later inspection frames hide UI only.
 await advance(.15)
 await shot("01-original-title-city-and-lighthouse")
 g.start_arrival();g.tick(0)
 check(g.phase==&"flyin" and is_equal_approx(g.world.arrival.progress,0),"native arrival begins at its true source-camera frame zero")
 await shot("02-original-arrival-00-seconds")
 await advance(4.0)
 check(is_equal_approx(g.world.arrival.progress,.5),"native four-second view uses the true half-complete arriving ship")
 await shot("03-original-arrival-04-seconds")
 await advance(4.0)
 check(g.world.arrival.docked,"native eight-second view uses the genuinely docked arrival")
 await shot("04-original-arrival-08-seconds")
 await advance(6.15)
 check(g.phase==&"line" and g.walker==null,"original fourteen-second camera reaches its actual coffee handoff")
 await shot("05-original-near-coffee-handoff")
 g.return_title();g.set_view(&"quay");g.camera.set_view(&"quay",0);inspection_ui();await advance(.15,true)
 await shot("06-original-quay-camera")
 g.set_view(&"port");g.camera.set_view(&"port",0);inspection_ui();await advance(.15,true)
 await shot("07-original-port-camera")
 # One explicitly diagnostic perspective shows sea/city depth with every
 # original foreground object still present; it never becomes product camera.
 g.camera._duration=0;g.camera.flying=false;g.camera.position=Vector3(17,22,20);g.camera.look_at(Vector3(65,14,-330));g.camera.fov=64
 g.world.tick(0,g.camera);await advance(.15,true)
 await shot("08-diagnostic-wide-sea-and-city",false)
 g.return_title();g.start_arrival();g.skip_arrival();g.tick(0);await advance(.1)
 var entered: bool=await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16.5,.055,7.2),Vector3(-10,.055,7.2)])
 check(entered,"ordinary carrying protagonist really walks from the cafe to the passenger forecourt")
 if not entered:await finish();return
 await advance(1.5)
 check(g.phase==&"play" and g.ui.caption.visible,"forecourt image retains the real follow camera and ordinary gameplay HUD")
 await shot("09-actual-forecourt-gameplay-hud")
 # A real smaller native window, without resizing a captured image or any art.
 g.return_title();root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640);await advance(.15)
 await shot("10-original-title-small-1024-window")
 check(root.get_texture().get_width()==1024 and root.get_texture().get_height()==640,"small-window image comes from the actual 1024-by-640 native viewport")
 check(shots.size()==10,"ten useful source-camera/native city photographs captured")
 await finish()
