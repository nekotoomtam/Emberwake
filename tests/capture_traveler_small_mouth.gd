extends SceneTree
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
const Appearance=preload("res://scripts/opening/harbor_hero_appearance.gd")
const Luggage=preload("res://scripts/opening/harbor_travel_luggage.gd")
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
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label);shots.append(label)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(output)
 var before:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/revisions/v110-front-128.png"))
 var after: Image=Standing.texture("front").get_image();var changed:=0;var outside:=0;var mouth_pixels:=0
 for y in 128:
  for x in 128:
   if before.get_pixel(x,y)!=after.get_pixel(x,y):
    changed+=1
    if not Rect2i(64,64,4,4).has_point(Vector2i(x,y)):outside+=1
   if Rect2i(64,64,4,4).has_point(Vector2i(x,y)) and after.get_pixel(x,y).is_equal_approx(Color("a96c5b")):mouth_pixels+=1
 check(changed==12 and outside==0 and mouth_pixels==4,"smaller mouth only; accepted eyes and all other front pixels preserved")
 for direction in ["right","left","back"]:
  var saved:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/directions/"+direction+"/idle-128.png"))
  check(Standing.texture(direction).get_image().get_data()==saved.get_data(),"preserve "+direction)
 check(after.save_png("res://assets/traveler_study/directions/front/idle-128.png")==OK,"export smaller-mouth front")
 check(Standing.layers("front").head.get_image().save_png("res://assets/traveler_study/directions/front/head-128.png")==OK,"export smaller-mouth head")
 var atlas:=Image.create(512,128,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
 var directions: Array[String]=["right","front","left","back"]
 for index in directions.size():atlas.blit_rect(Standing.texture(directions[index]).get_image(),Rect2i(0,0,128,128),Vector2i(index*128,0))
 check(atlas.save_png("res://assets/traveler_study/standing-four-directions.png")==OK,"export four-view atlas")
 Appearance.select("traveler")
 check(Appearance.frames("front").get_frame_texture("idle",0).get_image().get_data()==after.get_data(),"actual idle consumes smaller mouth")
 var walking: Image=Luggage.carry_texture("front","walk",1).get_image();var walk_ok:=true
 for y in range(64,68):
  for x in range(64,68):walk_ok=walk_ok and walking.get_pixel(x,y-4)==after.get_pixel(x,y)
 check(walk_ok,"walking/carry head bob retains smaller mouth")
 var review=load("res://scenes/review/traveler_appearance.tscn").instantiate();root.add_child(review);current_scene=review;review.set_process(false);review.set_direction("front");review.set_close(true)
 review.old_actor.texture=ImageTexture.create_from_image(before)
 for label in review.find_children("*","Label",true,false):
  if label.text.begins_with("ตัวละครใหม่") or label.text.begins_with("เทียบ"):label.text="ลดขนาดปากหน้าตรง"
  if label.text.begins_with("ซ้าย:"):label.text="ซ้าย: ก่อนปรับ     |     ขวา: หลังปรับ"
 await shot("01-smaller-mouth-before-after")
 review.set_close(false);await shot("02-smaller-mouth-play-scale")
 var strip:=Image.create(256,128,false,Image.FORMAT_RGBA8);strip.fill(Color.TRANSPARENT)
 strip.blit_rect(before,Rect2i(0,0,128,128),Vector2i.ZERO);strip.blit_rect(after,Rect2i(0,0,128,128),Vector2i(128,0))
 check(strip.save_png(output+"/mouth-before-after.png")==OK,"export before-after strip")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"changed_texture_pixels":changed,"outside_mouth_changes":outside,"mouth_pixels_before":16,"mouth_pixels_after":mouth_pixels,"offscreen":true,"unfocusable":root.unfocusable},"  "));file.close()
 review.free();await process_frame;await create_timer(.2).timeout
 print("NATIVE SMALLER FRONT MOUTH ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
