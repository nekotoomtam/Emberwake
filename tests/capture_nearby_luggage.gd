extends SceneTree
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var game
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label);shots.append(label)
func detail_camera() -> void:
 game.camera.flying=false;game.camera._duration=0
 game.camera.position=Profile.CAFE+Vector3(0,3.5,6)
 game.camera.look_at(Profile.CAFE+Vector3(.2,.6,0));game.camera.fov=40;game.world.tick(0,game.camera)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 var bag=game.world.plaza.travel_luggage
 game.set_view(&"cafe");game.camera.tick(1);game.world.tick(0,game.camera)
 check(bag.visual_root.position==bag.REST_POSITION and bag.floor_body.position==bag.REST_POSITION,"resting visual and floor collider use the new position")
 var original:=Profile.CAFE+Vector3(-.85,.24,.45)
 var new_screen: Vector2=game.camera.unproject_position(bag.REST_POSITION)
 var old_screen: Vector2=game.camera.unproject_position(original)
 check(new_screen.x>old_screen.x and new_screen.y>old_screen.y,"case moves toward the marked foot area on screen")
 detail_camera();await shot("01-new-bag-near-feet")
 game.ui.start_button.pressed.emit()
 for i in 906:game.tick(1.0/30)
 check(game.phase==&"rising","original opening timing still reaches the pickup without added story")
 for i in 9:game.tick(1.0/30)
 detail_camera();bag.update_stand(clampf(game.phase_age/.85,0,1),game.world.hero,game.camera)
 check(bag.state==&"lifting" and bag.floor_body.collision_layer==0,"pickup releases the new floor footprint")
 check(bag.grip.global_position.distance_to(bag.hand_world)<.025,"pickup hand meets the same case handle")
 await shot("02-new-position-pickup")
 for i in 24:game.tick(1.0/30)
 check(game.phase==&"play" and game.walker!=null and bag.state==&"carried","original stand sequence hands off to the real carrying player")
 check(bag.grip.global_position.distance_to(bag.hand_world)<.025 and bag.floor_body.collision_layer==0,"carried case retains grip with no floor collider left behind")
 await shot("03-carry-after-pickup")
 game.return_title()
 check(bag.state==&"resting" and bag.visual_root.position==bag.REST_POSITION and bag.floor_body.position==bag.REST_POSITION,"replay restores the case and blocker to the new spot")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"new_rest_position":str(bag.REST_POSITION),"old_rest_position":str(original),"screen_shift":str(new_screen-old_screen),"original_intro_timing_preserved":true},"  "));file.close()
 game.audio.shutdown();await create_timer(.25).timeout;game.free();await process_frame
 print("NEARBY LUGGAGE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
