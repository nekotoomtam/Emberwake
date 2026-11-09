extends SceneTree
var game
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.start_run(true)
 var faces: Array=[]
 for aim in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
  game.aim=aim;game._visual_tick(.01)
  check(game.avatar.back_hair.visible==(game.avatar.facing=="back"),"rear hair occludes weapon only when facing away")
  var im: Image=game.avatar.body.sprite_frames.get_frame_texture("idle",0).get_image()
  faces.append(im.get_data().hex_encode())
 check(faces[0]!=faces[1],"back is an original rear drawing, not front art")
 check(faces[2]!=faces[3],"left and right have distinct directional frame pixels")
 check(faces[0]!=faces[3] and faces[1]!=faces[3],"front/back differ from three-quarter views")
 var directions=load("res://scripts/hero_directions.gd")
 for name in ["front","back","left","right"]:
  var frames: SpriteFrames=directions.frames(name)
  check(frames==directions.frames(name),name+" frames cached")
  for state in ["idle","walk","attack","hit","death"]:
   check(frames.has_animation(state) and frames.get_frame_count(state)>0,name+" supports "+state)
   for i in range(frames.get_frame_count(state)):
    check(frames.get_frame_texture(state,i).get_size()==Vector2(128,128),"native 128px frame size")
 var back: Image=directions.frames("back").get_frame_texture("idle",0).get_image()
 var iris := 0
 for y in range(8*4,17*4):
  for x in range(8*4,26*4):
   if back.get_pixel(x,y).is_equal_approx(Color("419f9e")):iris+=1
 check(iris==0,"rear head has no front-facing eyes")
 for prior in ["right","front"]:
  for angle in [PI/4-.01,PI/4+.01,PI/4-.02,PI/4+.02]:
   check(directions.choose(Vector3(cos(angle),0,sin(angle)),game.camera,prior)==prior,"diagonal hysteresis prevents flicker")
 game.queue_free();await process_frame
 print("FOUR DIRECTIONS: ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
