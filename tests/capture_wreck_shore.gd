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
 captures.append({"label":label,"position":str(g.player.position),"mode":g.mode,"intro":g.arena.intro_age,"reveal":g.arena.reveal_amount,"view_size":g.camera.size})
func place(x: float) -> void:
 g.player.position=Vector3(x,.03,g.arena.travel_z(x));g.player.velocity=Vector3.ZERO
 g._camera_focus=g.arena.camera_focus(g.player.position);g.camera.position=g._camera_focus+g.CAMERA_OFFSET;g.camera.look_at(g._camera_focus)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false);g.start_wreck_shore();g.test_aim=Vector3(1,0,-.3).normalized()
 await advance(.3);await shot("01-carried-by-wave")
 check(not g.avatar.weapon.visible,"unarmed during wave")
 var age: float=g.arena.intro_age;g.toggle_pause();await advance(.3);check(g.arena.intro_age==age,"native pause freezes intro");g.toggle_pause()
 await advance(1.2);await shot("02-wave-landing")
 await advance(.9);await shot("03-wash-recedes")
 await advance(1.1);await shot("04-rising")
 await advance(.9);check(g.arena.intro_done(),"intro finishes");await shot("05-awake-on-beach")
 g.move_input=Vector2.LEFT;await advance(1.6);g.move_input=Vector2.ZERO
 check(g.player.position.x>1 and g.player.position.x<4.5,"native walk left meets visible crooked rock bank")
 await shot("12-natural-west-edge");g.player.position=g.arena.landing_point;g.player.velocity=Vector3.ZERO
 g.set_weapon_family("pistol");g._visual_tick(0);check(not g.pistol_reticle.visible,"native unarmed gun reticle hidden");g.set_weapon_family("sword")
 var start: Vector3=g.player.position;Input.action_press("move_right");await advance(.6);Input.action_release("move_right");check(g.player.position.x>start.x+2,"real WASD after waking")
 place(19);await advance(.1);await shot("06-diagonal-shore")
 place(28);await advance(.2);await shot("07-shack-and-ship-glimpse")
 place(38);await advance(2.8);check(g.arena.reveal_seen and g.camera.size>24,"vista camera reveals large ship")
 for point: Vector3 in g.arena.ship.landmark_points():
  var pixel: Vector2=g.camera.unproject_position(point)
  check(Rect2(25,25,1230,700).has_point(pixel),"ship landmark framed "+str(pixel))
 await shot("08-giant-grounded-wreck")
 var tip: Vector3=g.arena.ship.fallen_mast_tips[1]
 g.player.position=Vector3(tip.x,.03,tip.z-1.8);g.player.velocity=Vector3.ZERO
 var approach_z: float=g.player.position.z;g.move_input=Vector2.DOWN;await advance(.65);g.move_input=Vector2.ZERO
 check(g.player.position.z>approach_z+.3,"native player actually approaches fallen mast")
 check(g.player.position.z<tip.z-.15,"native grounded mast physically stops shore-side approach")
 await shot("13-fallen-mast-blocker")
 place(54);g.player.position.z=load("res://scripts/wreck_shore_profile.gd").sea_z(54)-3.8;await advance(2);await shot("14-crushed-bow-contact")
 var profile=load("res://scripts/wreck_shore_profile.gd")
 g.player.position=Vector3(54,.03,profile.coast_z(54)+1);g.player.velocity=Vector3.ZERO
 g.move_input=Vector2.RIGHT;await advance(1.8);g.move_input=Vector2.ZERO
 check(g.player.position.x<60 and g.mode=="practice","straight east shoreline is physically closed")
 await shot("15-right-headland-blockade")
 place(19);await advance(2)
 var surf=g.arena.surge
 await advance(fposmod(2.16-fposmod(surf.clock,6),6))
 var front_a: float=surf.surf_front(20,surf.clock,0);await shot("16-recurring-swash-up")
 await advance(3.18)
 check(absf(front_a-surf.surf_front(20,surf.clock,0))>2.5,"late swash advances and recedes across wet sand")
 check(surf.clock>10,"wave animation continues long after intro")
 await shot("17-recurring-backwash")


 check(is_instance_valid(g.arena.surge.sound) and g.arena.surge.sound.stream.data.size()>100000,"native original surf stream loaded")
 var paused_wave: float=g.arena.surge.clock
 g.toggle_pause();await advance(.03);check(g.arena.surge.clock==paused_wave,"pause freezes recurring swash");check(g.arena.surge.sound.stream_paused,"pause stops surf without forcing visual refresh")
 var mute:=InputEventKey.new();mute.physical_keycode=KEY_M;mute.keycode=KEY_M;mute.pressed=true;root.push_input(mute,true);Input.flush_buffered_events();await advance(.03)
 check(not g.audio.enabled and g.arena.surge.sound.stream_paused,"real M mute while paused")
 mute.pressed=false;root.push_input(mute,true);Input.flush_buffered_events();g.toggle_pause();await advance(.03)
 check(g.arena.surge.sound.stream_paused,"muted surf stays silent after resume")
 mute.pressed=true;root.push_input(mute,true);Input.flush_buffered_events();await advance(.03)
 check(g.audio.enabled and not g.arena.surge.sound.stream_paused,"M unmute restores surf")
 mute.pressed=false;root.push_input(mute,true);Input.flush_buffered_events()
 # Run the entire authored route through the actual movement controller.
 g.player.position=g.arena.landing_point
 for step in 2600:
  await physics_frame
  var target_x: float=minf(62,g.player.position.x+1);var target:=Vector3(target_x,.03,g.arena.travel_z(target_x));var direction: Vector3=target-g.player.position;direction.y=0;direction=direction.normalized();g.move_input=Vector2(direction.x,direction.z);g.tick(1.0/120)
  if g.mode=="shore_end":break
 g.move_input=Vector2.ZERO;check(g.mode=="shore_end" and g.arena.exit_reached,"native whole route reaches forest exit");await shot("09-forest-arrival")
 check(g.ui.overlay.visible and g.ui.buttons.get_child(0).get_global_rect().position.y>0,"arrival screen usable")
 g.restart();check(not g.arena.intro_done(),"replay resets intro")
 var key:=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.keycode=KEY_ENTER;key.pressed=true;root.push_input(key,true);Input.flush_buffered_events();await advance(.02);check(g.arena.intro_done(),"real Enter skips intro")
 place(57);await advance(.3);await shot("10-forest-threshold")
 g.return_menu();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/11-menu.png")==OK,"menu capture")
 check(g.ui.buttons.get_child(0).get_global_rect().position.y>0 and g.ui.menu_scroll.size.y<=400,"new first menu entry in viewport")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"geometry_count":g.arena.geometry_count,"batch_count":g.arena.batch_count,"scope":"native renderer and controlled real input/controller, wash/stand, ship framing, full route and exit/skip/menu, audio stream/mute data only; save disabled"},"\t"));file.close()
 g.audio.set_enabled(false);g.arena.surge.sound.stop();g.arena.surge.sound.stream=null;await create_timer(.12).timeout;g.free();await process_frame;await create_timer(.12).timeout;print("NATIVE WRECK ",checks," checks;",captures.size()+1," images; failures=",failures);quit(0 if failures.is_empty() else 1)
