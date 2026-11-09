extends SceneTree
var g
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var views: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func step() -> void:
 await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
func advance(seconds: float) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step()
func pose(at: Vector3,target: Vector3,fov_: float) -> void:
 g.camera.flying=false;g.camera._duration=0;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
 g.world.tick(0,g.camera)
func overview() -> void:pose(Vector3(-17,9,-12),Vector3(-21,1.0,-30),44)
func until(index: int,state_: String,loaded: bool=true) -> void:
 var found:=false
 for frame in ceili(100*Engine.physics_ticks_per_second):
  var actor=g.world.dock_life.marked_workers[index]
  if actor.enabled and actor.state==state_ and actor.carrying==loaded:found=true;break
  await step()
 check(found,"actual marked worker "+str(index)+" reaches "+state_+" loaded="+str(loaded))
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label);shots.append(label)
 var workers: Array=[]
 for actor in g.world.dock_life.marked_workers:workers.append({"id":actor.profile.id,"position":str(actor.position),"state":actor.state,"carrying":actor.carrying,"enabled":actor.enabled,"deliveries":actor.completed_deliveries,"pickup":str(actor.pickup_anchor),"dropoff":str(actor.dropoff_anchor),"load_visible":actor.native_load.visible})
 views.append({"name":label,"clock":g.world.clock,"camera":str(g.camera.global_transform),"workers":workers})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.ui.menu.hide();g.ui.footer.hide();g.ui.back_button.hide();g.ui.caption.hide()
 g.start_arrival();g.tick(0);overview()
 await shot("01-marked-warehouse-and-pier-stocks")
 await until(0,"pickup",true);await advance(.65)
 await shot("02-red-worker-lifts-warehouse-stock")
 await until(0,"dropoff",true)
 pose(Vector3(-20,5,-22),Vector3(-27.4,1.0,-29),42)
 await shot("03-red-worker-enters-receiving-door")
 await advance(.9);await shot("04-red-delivery-received-inside")
 overview();await until(1,"pickup",true);await advance(.65)
 await shot("05-orange-worker-lifts-marked-pier-stock")
 await until(1,"returning",true);await advance(3)
 await shot("06-orange-native-crate-to-warehouse")
 await until(1,"dropoff",true)
 pose(Vector3(-20,5,-22),Vector3(-27.4,1,-29),42)
 await shot("07-orange-worker-enters-same-door")
 await advance(.9);await shot("08-orange-delivery-received-inside")
 overview();await advance(5);await shot("09-orange-empty-return-red-waits-at-own-stock")
 check(g.world.dock_life.marked_workers.all(func(n):return n.completed_deliveries>=1),"both actual marked deliveries photographed")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE MARKED CARGO v102 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
