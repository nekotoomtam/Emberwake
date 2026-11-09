extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var dirs=load("res://scripts/hero_directions.gd")
 var base=load("res://scripts/pixel_art.gd")
 var expected_back: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("back-reference.json")))
 for state in ["idle","walk","attack","hit","death"]:
  for i in range(base.frames("player").get_frame_count(state)):
   var accepted: Image=base.frames("player").get_frame_texture(state,i).get_image()
   var right: Image=dirs.frames("right").get_frame_texture(state,i).get_image()
   check(right.get_data()==accepted.get_data(),"right keeps accepted three-quarter art: "+state+str(i))
   accepted.flip_x()
   check(dirs.frames("left").get_frame_texture(state,i).get_image().get_data()==accepted.get_data(),"left mirrors accepted three-quarter art: "+state+str(i))
   check(dirs.frames("back").get_frame_texture(state,i).get_image().get_data().hex_encode().sha256_text()==expected_back[state+str(i)],"accepted rear unchanged: "+state+str(i))
 var front: Image=dirs.frames("front").get_frame_texture("idle",0).get_image()
 check(front.get_pixel(13*4,13*4).is_equal_approx(Color("419f9e")) and front.get_pixel(18*4,13*4).is_equal_approx(Color("419f9e")),"front eyes centered symmetrically around face center")
 print("DIRECTION ANGLES: ","PASS" if failures.is_empty() else "FAIL", " ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
