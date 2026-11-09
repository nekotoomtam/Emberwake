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
func advance(seconds: float) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
func pose(at: Vector3,target: Vector3,fov_: float) -> void:
 g.camera.flying=false;g.camera._duration=0;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
 g.world.tick(0,g.camera)
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label);shots.append(label)
 views.append({"name":label,"camera":str(g.camera.global_transform),"clock":g.world.clock,"crown_count":g.world.foliage_study.crowns.size(),"clusters":g.world.foliage_study.clusters.size(),"cards":g.world.foliage_study.cards.size()})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.ui.menu.hide();g.ui.footer.hide();g.ui.back_button.hide();g.ui.caption.hide()
 pose(Vector3(-45,5.4,8),Vector3(-49.7,2.6,-.4),40)
 await advance(.1);await shot("01-west-tree-full-canopy")
 pose(Vector3(-54,5.4,6),Vector3(-49.7,2.6,-.4),40)
 await shot("02-west-tree-second-angle")
 var before: Vector3=g.world.foliage_study.clusters[0].rotation
 await advance(4)
 check(not before.is_equal_approx(g.world.foliage_study.clusters[0].rotation),"slow leaf wind changes the actual retained cluster")
 await shot("03-west-tree-slow-wind-later")
 pose(Vector3(-21.6,5.4,8),Vector3(-26.3,2.6,-.4),40)
 await shot("04-east-tree-full-canopy")
 pose(Vector3(-30.6,5.4,6),Vector3(-26.3,2.6,-.4),40)
 await shot("05-east-tree-second-angle")
 pose(Vector3(-36,13,22),Vector3(-38,1.9,-1),65)
 await shot("06-both-trees-in-plaza")
 g.camera.follow_actor(Vector3(-49.7,.055,2.5),100);g.world.tick(0,g.camera)
 await shot("07-west-tree-normal-follow-lens")
 check(g.world.square_garden.trees.all(func(t):return t.get_node_or_null("HybridFoliage")!=null),"both actual plaza trees have full leaf canopies")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE FULL CANOPIES v103 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
