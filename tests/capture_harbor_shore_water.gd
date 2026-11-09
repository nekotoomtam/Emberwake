extends SceneTree
## Native GPU evidence: eight views and a four-second effect-only motion loop.
var g
var sea
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var views: Array=[]
var motion: Array=[]
var metrics: Dictionary={}
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func step() -> void:await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
func walk_to(target: Vector3) -> bool:
 var delta: Vector3=target-g.walker.position;delta.y=0
 for frame in ceili((delta.length()/2.4+3)*Engine.physics_ticks_per_second):
  delta=target-g.walker.position;delta.y=0
  if delta.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE SHORE WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func frame_view(at: Vector3,target: Vector3,fov_: float=48) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
 g.world.tick(0,g.camera)
 if g.walker!=null:g.walker.update_art(0,Vector3.ZERO)
func rendered_image() -> Image:
 await process_frame;await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func shot(label: String) -> void:
 var image: Image=await rendered_image()
 check(image.save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"camera":str(g.camera.transform),"fov":g.camera.fov,"world_clock":g.world.clock,"effect_clock":sea.clock})
func projected_rect(points: Array,image_size: Vector2i) -> Rect2i:
 var rect:=Rect2(g.camera.unproject_position(points[0]),Vector2.ZERO)
 for point in points:rect=rect.expand(g.camera.unproject_position(point))
 return Rect2i(Vector2i(ceil(rect.position.x),ceil(rect.position.y)),Vector2i(floor(rect.size.x),floor(rect.size.y))).intersection(Rect2i(Vector2i.ZERO,image_size))
func rect_data(rect: Rect2i) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func water_rect_without_ui(projected: Rect2i,image_size: Vector2i) -> Dictionary:
 # Controls report canvas coordinates. Convert their real visible rectangles
 # to image pixels before excluding the caption and any other covering panel.
 var scale: Vector2=Vector2(image_size)/root.get_visible_rect().size
 var safe_bottom:=image_size.y;var overlays: Array=[]
 for control in [g.ui.caption,g.ui.bark_panel,g.ui.footer,g.ui.back_button,g.ui.menu,g.ui.settings_shade,g.ui.settings]:
  if not control.is_visible_in_tree():continue
  var canvas: Rect2=control.get_global_rect()
  var pixels:=Rect2i(Vector2i(floor(canvas.position.x*scale.x),floor(canvas.position.y*scale.y)),Vector2i(ceil(canvas.size.x*scale.x),ceil(canvas.size.y*scale.y)))
  overlays.append({"name":String(control.name),"rect":rect_data(pixels)})
  var shares_columns: bool=pixels.position.x<projected.end.x and pixels.end.x>projected.position.x
  if shares_columns and pixels.position.y>=projected.position.y:safe_bottom=mini(safe_bottom,pixels.position.y-8)
  elif pixels.intersects(projected):safe_bottom=mini(safe_bottom,projected.position.y)
 var safe:=projected.intersection(Rect2i(Vector2i.ZERO,Vector2i(image_size.x,maxi(0,safe_bottom))))
 return {"rect":safe,"safe_bottom":safe_bottom,"overlays":overlays}
func difference(a: Image,b: Image,rect: Rect2i) -> Dictionary:
 var total:=0.0;var changed:=0;var count:=0
 for y in range(rect.position.y,rect.end.y,2):
  for x in range(rect.position.x,rect.end.x,2):
   var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
   var delta: float=(absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b))/3
   total+=delta;count+=1
   if delta>.012:changed+=1
 return {"mean":total/maxi(1,count),"changed_fraction":float(changed)/maxi(1,count)}
func brightness_rows(image: Image,rect: Rect2i) -> Dictionary:
 var rows: Array=[];var low:=INF;var high:=-INF;var peak_y:=rect.position.y;var peak:=-INF
 for y in range(rect.position.y,rect.end.y,2):
  var total:=0.0;var count:=0
  for x in range(rect.position.x,rect.end.x,2):
   var color:=image.get_pixel(x,y);var luma: float=color.r*.2126+color.g*.7152+color.b*.0722
   total+=luma;count+=1;low=minf(low,luma);high=maxf(high,luma)
  var mean: float=total/maxi(1,count);rows.append({"y":y,"mean":mean})
  if mean>peak:peak=mean;peak_y=y
 return {"peak_y":peak_y,"contrast":high-low,"rows":rows}
func motion_loop() -> void:
 # Freeze all other world clocks and the real actor while selecting only the
 # sea material's absolute time. Dry stone is an unchanged render reference.
 release_walk();g.walker.set_physics_process(false);g.world.tick(0,g.camera)
 var world_clock: float=g.world.clock;var ship_pose: Transform3D=g.world.ship.visual_root.transform
 var time_start:=1.35;sea.set_clock(time_start)
 var reference: Image=await rendered_image();var size:=Vector2i(reference.get_width(),reference.get_height())
 # The coping ends at z=15.74. Start at z=15.8 on water, close enough to retain
 # the arriving crest; stop before the lower HUD, then apply its actual bounds.
 var level: float=g.world.sea_surface.MEAN_LEVEL
 var projected_wet:=projected_rect([Vector3(4.5,level,15.8),Vector3(11.5,level,15.8),Vector3(11.5,level,18.4),Vector3(4.5,level,18.4)],size)
 var ui_safe:=water_rect_without_ui(projected_wet,size)
 var wet: Rect2i=ui_safe.rect
 var dry:=projected_rect([Vector3(4.5,.06,12),Vector3(6.5,.06,12),Vector3(6.5,.06,13.2),Vector3(4.5,.06,13.2)],size)
 check(wet.size.x>40 and wet.size.y>20 and wet.end.y<=ui_safe.safe_bottom and dry.size.x>20 and dry.size.y>8,"fixed camera provides water-only and dry-stone regions outside the actual HUD")
 var wet_peak:=0.0;var wet_changed:=0.0;var dry_peak:=0.0;var contrast:=0.0
 var rows: Array=[];var sequence_saved:=true
 DirAccess.make_dir_recursive_absolute(output+"/motion")
 for index in 32:
  var time: float=time_start+float(index)/8;sea.set_clock(time)
  var image: Image=await rendered_image()
  var wet_delta:=difference(reference,image,wet);var dry_delta:=difference(reference,image,dry);var row_profile:=brightness_rows(image,wet)
  wet_peak=maxf(wet_peak,wet_delta.mean);wet_changed=maxf(wet_changed,wet_delta.changed_fraction);dry_peak=maxf(dry_peak,dry_delta.mean);contrast=maxf(contrast,row_profile.contrast)
  rows.append(row_profile.peak_y)
  var name: String="motion/frame_%03d.png"%index
  var saved:=image.save_png(output+"/"+name);sequence_saved=sequence_saved and saved==OK
  motion.append({"file":name,"time":time,"wet_difference":wet_delta,"dry_difference":dry_delta,"shore_brightness":row_profile})
  if index==0:
   check(image.save_png(output+"/03-fixed-coast-time-a.png")==OK,"capture fixed coast time a");shots.append("03-fixed-coast-time-a")
  if index==16:
   check(image.save_png(output+"/04-fixed-coast-time-b.png")==OK,"capture fixed coast time b");shots.append("04-fixed-coast-time-b")
 check(sequence_saved and motion.size()==32,"all 32 native water-loop images are saved")
 metrics={"wet_rect":rect_data(wet),"dry_rect":rect_data(dry),"wet_projected_before_ui_clip":rect_data(projected_wet),"water_world_bounds_xz":[4.5,15.8,11.5,18.4],"hud_safe_bottom":ui_safe.safe_bottom,"visible_ui_rects":ui_safe.overlays,"wet_peak_mean_change":wet_peak,"wet_peak_changed_fraction":wet_changed,"dry_peak_mean_change":dry_peak,"water_luma_contrast":contrast,"brightest_water_rows":rows,"fps":8,"frames":32,"duration_seconds":4,"world_clock":world_clock,"fixed_camera":str(g.camera.transform),"fixed_fov":g.camera.fov}
 check(wet_peak>.001 and wet_changed>.02 and wet_peak>dry_peak*4+.0005,"native wet-region pixels change with effect time beyond the static dry reference")
 check(dry_peak<.002,"effect-only frame sequence leaves actual dry stone visually stable")
 check(contrast>.05,"actual water-only rendered region retains readable water/crest colour contrast without HUD pixels")
 check(is_equal_approx(g.world.clock,world_clock) and g.world.ship.visual_root.transform==ship_pose,"water-only image comparison does not advance ships or the world")
 sea.set_clock(world_clock);g.walker.set_physics_process(true)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native water capture destination supplied")
 if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 sea=g.world.get("sea_surface")
 check(sea!=null,"native prologue contains the composed sea helper")
 if sea==null:g.audio.shutdown();g.free();quit(1);return
 g.tick(0);await shot("01-original-ship-title-water")
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(await route([Vector3(-43,.055,-7.3),Vector3(-36,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16,.055,11.6),Vector3(-5,.055,13.2),Vector3(8,.055,13.2),Vector3(8,.055,14.6)]),"actual protagonist walks from cafe to the unchanged straight coast")
 release_walk()
 for frame in Engine.physics_ticks_per_second:await step()
 await shot("02-actual-gameplay-follow-coast")
 frame_view(Vector3(8,6.8,25),Vector3(8,0,14.5),50)
 await motion_loop()
 root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640);await process_frame;await process_frame
 frame_view(Vector3(-43,7,24),Vector3(-51,.1,16.3),48);sea.set_clock(2.7);await shot("05-western-step-small-window")
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800);await process_frame;await process_frame
 frame_view(Vector3(32,7,23),Vector3(22,.2,14),48);sea.set_clock(4.1);await shot("06-east-corner-shore-wash")
 frame_view(Vector3(25,8,-5),Vector3(12,.1,1),52);sea.set_clock(1.9);await shot("07-north-basin-and-boarding-mouth")
 frame_view(Vector3(22,7,7),Vector3(8,1.4,-4),48);sea.set_clock(g.world.clock);await shot("08-retained-moored-ship-water-contact")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"motion":motion,"metrics":metrics},"  "));file.close()
 else:check(false,"write native water evidence manifest")
 release_walk();g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR SHORE WATER ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
