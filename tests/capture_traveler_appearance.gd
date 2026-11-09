extends SceneTree
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
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label)
 shots.append({"name":label,"close":review.close_view,"camera":str(review.camera.global_transform),"fov":review.camera.fov,"old_pixel_size":review.old_actor.pixel_size,"new_pixel_size":review.new_actor.pixel_size})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(output)
 review=load("res://scenes/review/traveler_appearance.tscn").instantiate();root.add_child(review);current_scene=review;review.set_process(false)
 review.tick(0)
 var art=load("res://scripts/opening/traveler_appearance_art.gd")
 var previous: Image=review.old_actor.texture.get_image();var next: Image=review.new_actor.texture.get_image()
 check(previous.get_size()==Vector2i(128,128) and next.get_size()==previous.get_size(),"both compared body images use the original 128px frame")
 check(previous.get_used_rect().end.y==112 and next.get_used_rect().end.y==112,"both silhouettes end at the established foot datum")
 check(next.get_used_rect().size.y==previous.get_used_rect().size.y,"new standing silhouette preserves the old actual pixel height")
 check(is_equal_approx(review.old_actor.pixel_size,.018) and is_equal_approx(review.new_actor.pixel_size,.018),"comparison keeps equal real-world pixel sizes")
 check(not review.old_actor.no_depth_test and not review.new_actor.no_depth_test,"both specimens respect normal scene depth")
 check(art.layers().size()==6,"new pose has six separately authored parts")
 var path: String="res://assets/traveler_study/"
 check(next.save_png(path+"idle-right-128.png")==OK,"save the exact in-scene new sprite")
 var source: Image=next.duplicate();source.resize(32,32,Image.INTERPOLATE_NEAREST)
 check(source.save_png(path+"idle-right-logical-32.png")==OK,"save the native logical pixel artwork")
 for id in art.PARTS:check(art.layers()[id].get_image().save_png(path+id+"-128.png")==OK,"save part "+id)
 previous.save_png(output+"/previous-body-128.png");next.save_png(output+"/traveler-body-128.png")
 var normal: Transform3D=review.camera.transform
 await shot("01-normal-play-scale")
 review.close_button.pressed.emit()
 check(review.close_view and not review.camera.transform.is_equal_approx(normal),"actual close-view button changes the camera")
 check(is_equal_approx(review.old_actor.pixel_size,review.new_actor.pixel_size),"close view does not enlarge either sprite independently")
 await shot("02-close-comparison")
 review.ui.hide();await shot("03-close-comparison-clean");review.ui.show()
 review.normal_button.pressed.emit()
 check(not review.close_view and review.camera.transform.is_equal_approx(normal),"actual normal-view button restores the exact play-scale lens")
 var event:=InputEventKey.new();event.physical_keycode=KEY_2;event.pressed=true;review._unhandled_key_input(event)
 check(review.close_view,"keyboard close-view shortcut remains functional")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"old_bounds":str(previous.get_used_rect()),"new_bounds":str(next.get_used_rect()),"logical_size":32,"frame_size":128,"parts":art.PARTS,"offscreen":true,"unfocusable":root.unfocusable},"  "));file.close()
 review.free();await process_frame;await create_timer(.2).timeout
 print("TRAVELER APPEARANCE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
