extends SceneTree
var g
var output:=""
var shots: Array=[]
var failures: Array=[]
var checks:=0
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(seconds: float) -> void:
 for frame in roundi(seconds*30):
  await process_frame;g.tick(1.0/30)
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label)
 shots.append({"name":label,"world_time":g.world.clock,"phase":str(g.phase),"camera":str(g.camera.global_transform),"fov":g.camera.fov})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.ui.start_button.pressed.emit();g.tick(0)
 var previous:=0.0
 for seconds in [6.0,9.0,12.0,15.0,18.0,21.0,23.0,25.0,28.2]:
  await advance(seconds-previous);previous=seconds
  await shot("%02d-pan-%04.1fs"%[shots.size()+1,seconds])
 check(g.phase==&"line","normal opening reaches coffee dialogue")
 await advance(3);await shot("10-standing-play")
 check(g.phase==&"play" and g.walker!=null,"actual actor remains playable")
 g.return_title();g.ui.menu.hide();g.ui.footer.hide()
 var outlet: Vector3=g.world.chimney_smoke.sources[0]
 g.camera._duration=0;g.camera.position=outlet+Vector3(12,5,12);g.camera.look_at(outlet+Vector3.UP*2);g.camera.fov=42
 g.world.tick(0,g.camera);await shot("11-smoke-from-native-chimney")
 var before: Transform3D=g.world.chimney_smoke.batch.multimesh.get_instance_transform(0)
 await advance(3);await shot("12-smoke-later")
 check(not before.is_equal_approx(g.world.chimney_smoke.batch.multimesh.get_instance_transform(0)),"native GPU smoke drifts and rises between frames")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"emitters":g.world.chimney_smoke.sources.size(),"puffs":g.world.chimney_smoke.batch.multimesh.instance_count,"offscreen":true,"unfocusable":root.unfocusable},"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE CITY ATMOSPHERE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
