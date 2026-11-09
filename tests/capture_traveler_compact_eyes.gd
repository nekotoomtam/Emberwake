extends SceneTree
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
const NPC=preload("res://scripts/opening/harbor_npc.gd")
const REFERENCE: Dictionary={"id":"npc_eye_reference","hairstyle":4,"male":false,"cap":false,"hair":"71503b","skin":"ffdfbd","coat":"586f75"}
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
func caption(title: String,subtitle: String) -> void:
 for label in review.find_children("*","Label",true,false):
  if label.text.begins_with("ตัวละครใหม่") or label.text.begins_with("เทียบ") or label.text.begins_with("ปรับ"):label.text=title
  if label.text.begins_with("ซ้าย:"):label.text=subtitle
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(output)
 review=load("res://scenes/review/traveler_appearance.tscn").instantiate();root.add_child(review);current_scene=review;review.set_process(false);review.set_direction("front");review.set_close(true)
 var before:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/revisions/v109-front-128.png"))
 var after: Image=Standing.texture("front").get_image();var changed:=0;var outside:=0
 for y in 128:
  for x in 128:
   if before.get_pixel(x,y)!=after.get_pixel(x,y):
    changed+=1
    if not Rect2i(44,48,40,12).has_point(Vector2i(x,y)):outside+=1
 check(changed>0 and outside==0,"all changed front pixels remain inside the two eye groups")
 check(after.save_png("res://assets/traveler_study/directions/front/idle-128.png")==OK,"export compact front")
 check(Standing.layers("front").head.get_image().save_png("res://assets/traveler_study/directions/front/head-128.png")==OK,"export compact front head")
 var atlas:=Image.create(512,128,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
 var directions: Array[String]=["right","front","left","back"]
 for index in directions.size():atlas.blit_rect(Standing.texture(directions[index]).get_image(),Rect2i(0,0,128,128),Vector2i(index*128,0))
 check(atlas.save_png("res://assets/traveler_study/standing-four-directions.png")==OK,"export updated four-view atlas")
 review.old_actor.texture=ImageTexture.create_from_image(before)
 caption("ลดขนาดตาให้พอดีกับใบหน้า","ซ้าย: ก่อนปรับ     |     ขวา: หลังปรับ")
 await shot("01-compact-eyes-before-after")
 # Compare an actual NPC node, drawn by the unchanged NPC art pipeline,
 # with the real new hero specimen. Replace only the comparison figure.
 review.old_actor.hide()
 var npc=NPC.new();npc.profile=REFERENCE.duplicate();npc.position=review.old_foot;review.add_child(npc);npc.tick(0,review.camera,0)
 check(is_equal_approx(npc.sprite.pixel_size,review.new_actor.pixel_size) and is_equal_approx(npc.sprite.pixel_size,.018),"actual NPC and hero use the same world pixel scale")
 check(npc.sprite.texture.get_size()==Vector2(128,128) and after.get_size()==Vector2i(128,128),"actual NPC and hero share the same 128px frame size")
 caption("เทียบทรงตาและสเกล","ซ้าย: NPC หญิง     |     ขวา: ตัวละครเรา")
 await shot("02-actual-npc-and-traveler-close")
 review.set_close(false);npc.tick(0,review.camera,0);await shot("03-actual-npc-and-traveler-play-scale")
 var comparison:=Image.create(384,128,false,Image.FORMAT_RGBA8);comparison.fill(Color.TRANSPARENT)
 comparison.blit_rect(before,Rect2i(0,0,128,128),Vector2i.ZERO)
 comparison.blit_rect(npc.sprite.texture.get_image(),Rect2i(0,0,128,128),Vector2i(128,0))
 comparison.blit_rect(after,Rect2i(0,0,128,128),Vector2i(256,0))
 check(comparison.save_png(output+"/before-npc-after.png")==OK,"export equal-frame reference strip")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"changed_texture_pixels":changed,"changed_logical_pixels":changed/16,"outside_eye_changes":outside,"npc_pixel_size":npc.sprite.pixel_size,"hero_pixel_size":review.new_actor.pixel_size,"reference_profile":REFERENCE,"offscreen":true,"unfocusable":root.unfocusable},"  "));file.close()
 review.free();await process_frame;await create_timer(.2).timeout
 print("NATIVE COMPACT FRONT EYES ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
