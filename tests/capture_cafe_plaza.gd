extends SceneTree
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var output:=""
var failures: Array=[]
var checks:=0
var shots: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(seconds: float) -> void:
 while seconds>.0001:
  g.tick(minf(seconds,1.0/60));seconds-=1.0/60
  await process_frame
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
func frame_view(at: Vector3,target: Vector3,fov_: float=48) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 await advance(.5);await shot("01-original-ship-title")
 check(g.camera.position.distance_to(Vector3(62,11.45,-13))<.001,"original sea-only title retained")
 g.start_arrival();await advance(10);await shot("02-new-plaza-pullback")
 await advance(4.1);await shot("03-coffee-endpoint")
 check(g.phase==&"line" and g.camera.position.distance_to(Profile.CAFE_CAMERA)<.001,"opening ends at new cafe")
 await advance(2.1);await shot("04-rising-at-new-table")
 await advance(.9);check(g.phase==&"play" and g.walker!=null,"new cafe releases walking")
 await shot("05-new-cafe-standing")
 g.return_title();g.set_view(&"cafe");await advance(1.0);await shot("06-cafe-inspection")
 await advance(5.1);await shot("07-cafe-sipping")
 check(g.world.cup.global_position.distance_to(Profile.CUP_REST)>.05,"visible cup lifts at relocated sip")
 g.set_view(&"market");await advance(1);await shot("08-fountain-market")
 var clock_before: float=g.world.plaza.fountain.water_time
 await advance(1);await shot("09-fountain-water-later")
 check(g.world.plaza.fountain.water_time>clock_before,"fountain water animates")
 frame_view(Vector3(-24,7,4),Vector3(-31,1,-9),52);g.world.tick(0,g.camera);await shot("10-plaza-connection")
 frame_view(Vector3(-9,8,-1),Vector3(-22,.4,-6),52);g.world.tick(0,g.camera);await shot("11-square-quay-rail")
 frame_view(Vector3(30,9,23),Vector3(16,.1,10),52);g.world.tick(0,g.camera);await shot("12-square-quay-end")
 check(get_nodes_in_group("harbor_quay_edge").size()>=5,"new visible rails have physical boundaries")
 g.return_title();await advance(.2);await shot("13-replay-original-ship")
 g.start_arrival();g.skip_arrival();await advance(.2);await shot("14-skip-new-cafe")
 check(g.walker.position.distance_to(Profile.CAFE)<.3,"native skip reaches new cafe")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots},"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE CAFE PLAZA ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
