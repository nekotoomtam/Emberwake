extends SceneTree
var review
var game
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
const Appearance=preload("res://scripts/opening/harbor_hero_appearance.gd")
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
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
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label)
 shots.append(label)
func press_profile(label: String) -> void:
 for button in review.find_children("*","Button",true,false):
  if button.text==label:button.pressed.emit();return
 check(false,"profile button exists: "+label)
func wait_game() -> void:
 await process_frame;await process_frame
 game=current_scene;review=null;game.set_process(false)
func advance(seconds: float) -> void:
 for frame in roundi(seconds*30):
  await process_frame;game.tick(1.0/30)
func open_review() -> void:
 game.return_title();game.ui.appearance_button.pressed.emit()
 await process_frame;await process_frame
 review=current_scene;game=null;review.set_process(false);review.set_close(true)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(output)
 review=load("res://scenes/review/traveler_appearance.tscn").instantiate();root.add_child(review);current_scene=review;review.set_process(false);review.set_close(true)
 var locked: Image=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/idle-right-128.png"))
 check(Standing.texture("right").get_image().get_data()==locked.get_data(),"the approved right-facing pixels are exactly preserved")
 var atlas:=Image.create(512,128,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
 var directions: Array[String]=["right","front","left","back"]
 var unique: Dictionary={}
 for index in directions.size():
  var direction: String=directions[index]
  review.direction_buttons[direction].pressed.emit()
  check(review.direction==direction,"actual direction button: "+direction)
  var image: Image=Standing.texture(direction).get_image()
  check(image.get_size()==Vector2i(128,128) and image.get_used_rect().end.y==112,"registered 128px "+direction+" body")
  unique[hash(image.get_data())]=true
  var folder: String="res://assets/traveler_study/directions/"+direction+"/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
  check(image.save_png(folder+"idle-128.png")==OK,"export "+direction)
  for id in Standing.PARTS:Standing.layers(direction)[id].get_image().save_png(folder+id+"-128.png")
  atlas.blit_rect(image,Rect2i(0,0,128,128),Vector2i(index*128,0))
  await shot("%02d-standing-%s"%[index+1,direction])
 check(unique.size()==4,"all four views are distinct, with a genuine front and back")
 check(atlas.save_png("res://assets/traveler_study/standing-four-directions.png")==OK,"export four-direction atlas")
 var event:=InputEventKey.new();event.physical_keycode=KEY_LEFT;event.pressed=true;review._unhandled_key_input(event)
 check(review.direction=="left","keyboard cycles to the preceding facing")
 press_profile("ใช้ตัวใหม่ในท่าเรือ");await wait_game()
 check(Appearance.is_traveler(),"new-profile review button reaches the selected real prologue")
 game.set_view(&"cafe");game.camera.tick(1);game.world.tick(0,game.camera);await shot("05-new-traveler-coffee")
 game.ui.start_button.pressed.emit();await advance(game.camera.intro_duration+.2)
 check(game.phase==&"line","normal unskipped flight reaches the new coffee dialogue")
 await advance(2.35);await shot("06-new-traveler-pickup")
 check(game.phase==&"rising" and game.world.plaza.travel_luggage.state==&"lifting","new traveler picks up the original native case")
 await advance(.6)
 check(game.phase==&"play" and game.walker!=null,"normal new coffee/pickup sequence reaches the real controller")
 for index in directions.size():
  game.walker.facing=directions[index];game.walker.update_art(0,Vector3.ZERO);game.tick(0)
  check(game.world.plaza.travel_luggage.grip.global_position.distance_to(game.world.plaza.travel_luggage.hand_world)<.025,"native case grip matches "+directions[index]+" carrying hand")
  await shot("%02d-new-carry-%s"%[index+7,directions[index]])
 await open_review();press_profile("ใช้ตัวเดิมในท่าเรือ");await wait_game()
 check(not Appearance.is_traveler(),"legacy-profile button still opens the original appearance")
 game.set_view(&"cafe");game.camera.tick(1);game.world.tick(0,game.camera);await shot("11-legacy-preserved")
 await open_review();press_profile("ใช้ตัวใหม่ในท่าเรือ");await wait_game()
 check(Appearance.is_traveler(),"switching back restores the new default within the same process")
 game.set_view(&"cafe");game.camera.tick(1);game.world.tick(0,game.camera);await shot("12-new-restored")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"directions":directions,"parts_per_direction":6,"offscreen":true,"unfocusable":root.unfocusable},"  "));file.close()
 game.audio.shutdown();await create_timer(.25).timeout;game.free();await process_frame
 print("TRAVELER FOUR DIRECTIONS ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
