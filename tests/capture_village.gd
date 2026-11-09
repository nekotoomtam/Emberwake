extends SceneTree
var g
var output:=""
var captures: Array=[]
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
 while seconds>.000001:
  await physics_frame;var dt:=minf(seconds,1.0/120);g.tick(dt);seconds-=dt
func shot(label: String) -> void:
 g._visual_tick(0);await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
 captures.append({"label":label,"position":str(g.player.position),"mode":g.encounter_mode,"roof":g.arena.house_roof.visible})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false);g.start_village_study();g.test_aim=Vector3.FORWARD
 await advance(.1);await shot("01-beach-arrival")
 Input.action_press("move_up");await advance(.8);Input.action_release("move_up");check(g.player.position.z<3,"real WASD movement advances from beach");await shot("02-wet-path")
 Input.action_press("move_up");await advance(.7);Input.action_release("move_up");await shot("03-cottage-approach")
 Input.action_press("move_up");await advance(.9);Input.action_release("move_up");check(g.player.position.z< -3.3,"real movement climbs ramp and crosses doorway");check(g.player.position.y>.15,"raised cottage floor reached");check(not g.arena.house_roof.visible,"native cutaway interior");await shot("04-interior-cutaway")
 Input.action_press("move_down");await advance(1);Input.action_release("move_down");check(g.player.position.z> -3,"real movement exits doorway");check(g.arena.house_roof.visible,"roof restores outside");await shot("05-exit")
 var before: Vector3=g.player.position;check(g.request_dodge(Vector3.RIGHT),"existing dash still accepted");await advance(.25);check(g.player.position.distance_to(before)>.5,"dash physically moves");await shot("06-path-dodge")
 g.player.position=Vector3(-4,.03,4.8);await advance(.15);await shot("07-skiff-and-net")
 g.player.position=Vector3(2.4,.03,-2);await advance(.2);g.village_zoom=12;g.camera.size=12;g._camera_focus=Vector3(0,0,-4.4);await shot("08-facade-detail")
 var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;root.push_input(wheel,true);Input.flush_buffered_events();await advance(.3)
 check(g.village_zoom==10.5 and g.camera.size<12,"real wheel input zooms smoothly")
 g.restart();check(g.enemies.is_empty() and g.encounter_mode=="village_study","restart remains empty visual study")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"geometry_count":g.arena.geometry_count,"batch_count":g.arena.batch_count,"checks":checks,"failures":failures,"captures":captures,"scope":"actual native renderer, real action movement and ramp/door traversal, save disabled before ready"},"\t"));file.close()
 g.audio.set_enabled(false);g.free();await process_frame;print("NATIVE VILLAGE ",checks," checks;",captures.size()," captures; failures=",failures);quit(0 if failures.is_empty() else 1)
