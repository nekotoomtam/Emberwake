extends SceneTree
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
var review
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
 review=load("res://scenes/review/traveler_appearance.tscn").instantiate();root.add_child(review);current_scene=review;review.set_process(false)
 review.direction_buttons.front.pressed.emit();review.set_close(true)
 await shot("01-corrected-front-in-harbor")
 var before:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/revisions/v107-front-128.png"))
 var after: Image=Standing.texture("front").get_image();var changed:=0;var outside:=0
 for y in 128:
  for x in 128:
   if before.get_pixel(x,y)!=after.get_pixel(x,y):
    changed+=1
    if not Rect2i(72,48,12,12).has_point(Vector2i(x,y)):outside+=1
 check(changed==96 and outside==0,"only six logical eye pixels change; all other front-body pixels are retained")
 check(after.save_png("res://assets/traveler_study/directions/front/idle-128.png")==OK,"export corrected front")
 check(Standing.layers("front").head.get_image().save_png("res://assets/traveler_study/directions/front/head-128.png")==OK,"export corrected front head")
 var atlas:=Image.create(512,128,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
 var directions: Array[String]=["right","front","left","back"]
 for index in directions.size():atlas.blit_rect(Standing.texture(directions[index]).get_image(),Rect2i(0,0,128,128),Vector2i(index*128,0))
 check(atlas.save_png("res://assets/traveler_study/standing-four-directions.png")==OK,"export corrected four-view atlas")
 var comparison:=Image.create(256,128,false,Image.FORMAT_RGBA8);comparison.fill(Color.TRANSPARENT)
 comparison.blit_rect(before,Rect2i(0,0,128,128),Vector2i.ZERO);comparison.blit_rect(after,Rect2i(0,0,128,128),Vector2i(128,0))
 check(comparison.save_png(output+"/front-eye-before-after.png")==OK,"export actual sprite comparison")
 # A labeled native review photo: both specimens are the new traveler,
 # using the archived v107 front on the left and corrected front on right.
 review.old_actor.texture=ImageTexture.create_from_image(before)
 for label in review.find_children("*","Label",true,false):
  if label.text.begins_with("ตัวละครใหม่"):label.text="ปรับดวงตาหน้าตรง"
  if label.text.begins_with("ซ้าย:"):label.text="ซ้าย: ก่อนปรับ     |     ขวา: หลังปรับ"
 await shot("02-front-eyes-before-after")
 review.set_close(false);await shot("03-front-eyes-at-play-scale")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"changed_texture_pixels":changed,"changed_logical_pixels":changed/16,"outside_eye_changes":outside,"offscreen":true,"unfocusable":root.unfocusable},"  "));file.close()
 review.free();await process_frame;await create_timer(.2).timeout
 print("NATIVE FRONT EYES ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
