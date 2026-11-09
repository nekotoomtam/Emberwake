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
 shots.append({"name":label,"time":g.camera._age,"phase":str(g.phase),"camera":str(g.camera.global_transform),"fov":g.camera.fov})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 await shot("00-menu")
 g.ui.start_button.pressed.emit();g.tick(0)
 await shot("01-ship-departing-composition")
 var previous:=0.0
 for seconds in [3.0,6.0,9.0,12.0,15.0,18.0,21.0,24.0,27.0,28.2]:
  await advance(seconds-previous);previous=seconds
  await shot("%02d-flight-%04.1fs"%[shots.size(),seconds])
 check(g.phase==&"line" and g.world.hero.visible,"normal unskipped flight reaches the seated hero's dialogue")
 await advance(3);await shot("13-standing-playable")
 check(g.phase==&"play" and g.walker!=null and g.walker.carrying_luggage,"normal flight stands up with native luggage into play")
 check(g.world.foliage_study.crowns.size()==2 and g.world.dock_life.marked_workers.size()==2,"accepted full trees and both marked workers remain present")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"offscreen":true,"unfocusable":root.unfocusable},"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE CAMERA FLOW ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
