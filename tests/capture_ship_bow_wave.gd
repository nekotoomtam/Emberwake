extends SceneTree
var game
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func frame_image() -> Image:
 await process_frame;await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func shot(label: String) -> void:
 var picture: Image=await frame_image()
 check(picture.save_png(output+"/"+label+".png")==OK,label);shots.append(label)
func different(a: Image,b: Image) -> int:
 var count_:=0
 for y in range(150,750):
  for x in range(80,1200):
   if a.get_pixel(x,y)!=b.get_pixel(x,y):count_+=1
 return count_
func close_bow() -> void:
 var bow: Vector3=game.world.arrival.water_contact.to_global(Vector3(11.1,.1,1.4))
 game.camera.global_position=bow+Vector3(-8,5.3,10)
 game.camera.look_at(bow+Vector3(0,.4,0));game.camera.fov=45
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 game.ui.start_button.pressed.emit()
 for index in 66:
  game.tick(1.0/30);await process_frame
 var contact=game.world.arrival.water_contact;var wave=contact.bow_wave
 check(contact.cruising>.6 and game.world.arrival.progress>0 and not game.world.arrival.docked,"real arriving ship is moving and driving the bow wave")
 check(game.world.ship_water.bow_wave!=null,"moored ship also owns gentle bow water contact")
 check(is_equal_approx(float(wave.material.get_shader_parameter("sea_clock")),game.world.clock),"bow water follows the same world-time swell as the ocean")
 game.ui.open_settings();var frozen_clock: float=game.world.clock;var frozen_wave: float=contact.phase_clock;game.tick(.5)
 check(is_equal_approx(game.world.clock,frozen_clock) and is_equal_approx(contact.phase_clock,frozen_wave),"actual pause freezes ocean and bow animation together")
 game.ui.close_settings()
 await shot("01-original-opening-bow-wave")
 close_bow();var first: Image=await frame_image()
 wave.visible=false;var absent: Image=await frame_image();wave.visible=true
 var visible_pixels:=different(first,absent)
 check(visible_pixels>120,"new crest produces visible native pixels in the bow view")
 var clock: float=contact.phase_clock
 wave.tick(clock+.45,contact.cruising,contact.phase);var moved: Image=await frame_image()
 wave.visible=false;var moved_absent: Image=await frame_image();wave.visible=true
 var motion_pixels:=0
 for y in range(150,750):
  for x in range(80,1200):
   if first.get_pixel(x,y)!=absent.get_pixel(x,y) and moved.get_pixel(x,y)!=moved_absent.get_pixel(x,y) and first.get_pixel(x,y)!=moved.get_pixel(x,y):motion_pixels+=1
 check(motion_pixels>40,"wave itself animates on the native GPU with scene and camera frozen")
 wave.tick(clock,contact.cruising,contact.phase)
 await shot("02-bow-wave-detail")
 for index in 90:
  game.tick(1.0/30);close_bow();await process_frame
  if index==20:await shot("03-bow-wave-detail-moving")
 check(contact.phase_clock>clock+2.9 and contact.cruising>.5,"clock and wake continue during the actual ship approach")
 var moving_drive: float=contact.cruising
 for index in 240:game.tick(1.0/30)
 check(game.world.arrival.docked and contact.cruising<moving_drive*.1,"wake becomes gentle after the real ship reaches berth")
 game.return_title()
 check(is_zero_approx(contact.phase_clock) and is_zero_approx(float(wave.material.get_shader_parameter("drive"))),"replay resets the real bow wake")
 game.set_view(&"quay");game.camera.tick(1);game.world.tick(0,game.camera)
 await shot("04-irregular-water-at-quay")
 game.set_view(&"cafe");game.camera.tick(1);game.world.tick(0,game.camera)
 await shot("05-approved-traveler-and-shore")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"visible_bow_wave_pixels":visible_pixels,"animated_bow_wave_pixels":motion_pixels,"native_gpu":true,"detail_camera":"Inspection camera follows the real moving bow; original opening camera is unchanged in product","offscreen":true},"  "));file.close()
 game.audio.shutdown();await create_timer(.25).timeout;game.free();await process_frame
 print("NATIVE SHIP BOW WAVE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
