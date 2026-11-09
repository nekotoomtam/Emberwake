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
 captures.append({"label":label,"position":str(g.player.position),"form":g.arena.form_index(g.player.position.x),"house_alpha":g.arena.cottage.cover_alpha})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false);g.start_coast_forms();g.test_aim=Vector3.RIGHT
 for index in 5:
  g.jump_coast_form(index);await advance(.12);await shot("form-%d"%[index+1])
  check(g.arena.form_index(g.player.position.x)==index,"native inspection form "+str(index))
 g.village_zoom=24;g.camera.size=24;await shot("shore-zoom-out");g.village_zoom=18.5;g.camera.size=18.5
 var key:=InputEventKey.new();key.keycode=KEY_2;key.physical_keycode=KEY_2;key.pressed=true;root.push_input(key,true);Input.flush_buffered_events();await advance(.03)
 check(g.arena.form_index(g.player.position.x)==1,"real key2 jumps form")
 g.jump_coast_form(0);var before: Vector3=g.player.position;Input.action_press("move_right");await advance(.6);Input.action_release("move_right");check(g.player.position.x>before.x+2,"native WASD walks along beach")
 g.player.position=Vector3(1,.03,g.arena.path_center(1)+.8)
 for step in 2300:
  await physics_frame
  var target:=Vector3(g.player.position.x+1,.03,g.arena.path_center(g.player.position.x+1)+.8)
  var direction: Vector3=target-g.player.position;direction.y=0;direction=direction.normalized();g.move_input=Vector2(direction.x,direction.z);g.tick(1.0/120)
  if g.player.position.x>78.5:break
 g.move_input=Vector2.ZERO;check(g.player.position.x>78.5,"native controller traverses entire five-form coast")
 var house=g.arena.cottage;g.player.position=house.to_global(Vector3(0,.04,0));g._camera_focus=g.player.position+Vector3(0,0,-4);g.test_aim=Vector3.FORWARD
 Input.action_press("move_up");await advance(.91);Input.action_release("move_up")
 check(house.to_local(g.player.position).z< -3.3,"actual cottage doorway entry")
 check(house.cover_alpha>0 and house.cover_alpha<1,"roof fades instead of instantly disappearing");await shot("cottage-fade-enter")
 await advance(.55);check(house.cover_alpha<.01,"roof fully open");await shot("cottage-interior")
 Input.action_press("move_down");await advance(.48);Input.action_release("move_down");await shot("cottage-fade-exit")
 await advance(.55);check(house.cover_alpha>.99,"roof restores smoothly")
 g.jump_coast_form(2);await advance(.1);var start: Vector3=g.player.position;check(g.request_dodge(Vector3.RIGHT),"dash accepted");await advance(.3);check(g.player.position.distance_to(start)>.5,"native dash moves");await shot("forest-dash")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"geometry_count":g.arena.geometry_count,"batch_count":g.arena.batch_count,"scope":"native rendering, actual keyboard review jump and WASD, controller traversal, physical doorway and animated cover fade; save disabled"},"\t"));file.close()
 g.audio.set_enabled(false);g.free();await process_frame;print("NATIVE COAST FORMS ",checks," checks;",captures.size()," captures; failures=",failures);quit(0 if failures.is_empty() else 1)
