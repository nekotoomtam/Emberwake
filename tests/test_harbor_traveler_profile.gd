extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func pink_count(texture: Texture2D) -> int:
 var image: Image=texture.get_image();var count_:=0
 for y in image.get_height():
  for x in image.get_width():
   var color: Color=image.get_pixel(x,y)
   if color.a>.5 and color.r>.50 and color.r>color.g*1.6 and color.b>color.g*1.2:count_+=1
 return count_
func finish() -> void:
 if g!=null:g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("HARBOR TRAVELER PROFILE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 check(pink_count(g.world.hero.texture)==0,"normal harbor opening starts with the new traveler rather than the previous pink-haired body")
 if not FileAccess.file_exists("res://scripts/opening/harbor_hero_appearance.gd"):finish();return
 var appearance=load("res://scripts/opening/harbor_hero_appearance.gd")
 var luggage=load("res://scripts/opening/harbor_travel_luggage.gd")
 var traveler=load("res://scripts/opening/traveler_appearance_art.gd")
 for direction in ["right","left","front","back"]:
  var frames: SpriteFrames=appearance.frames(direction)
  var consistent:=true;var walk_images: Dictionary={}
  for action in ["idle","walk"]:
   for index in frames.get_frame_count(action):
    var texture: Texture2D=frames.get_frame_texture(action,index)
    consistent=consistent and pink_count(texture)==0 and texture.get_size()==Vector2(128,128)
    if action=="walk":walk_images[hash(texture.get_image().get_data())]=true
  check(consistent,"new "+direction+" idle/walk frames retain the selected appearance")
  check(walk_images.size()>=3,"new "+direction+" walking articulates beyond a single static picture")
  check(traveler.texture(direction).get_image().get_used_rect().end.y==112,"new "+direction+" standing feet retain the existing datum")
 for index in 6:check(pink_count(appearance.sipping(index))==0,"coffee sip "+str(index)+" keeps the new head and clothes")
 for index in 4:check(pink_count(appearance.rising(index))==0,"rising pose "+str(index)+" keeps the new head and clothes")
 g.ui.start_button.pressed.emit();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and g.walker!=null and pink_count(g.walker.sprite.texture)==0,"normal skip reaches the real new traveler with luggage")
 for direction in ["right","front","left","back"]:
  var fresh: Texture2D=luggage.carry_texture(direction,"walk",1)
  check(pink_count(fresh)==0,"new "+direction+" carry pose is not a cached legacy body")
  appearance.select("legacy")
  var previous: Texture2D=luggage.carry_texture(direction,"walk",1)
  check(pink_count(previous)>0,"the previous "+direction+" body remains selectable")
  appearance.select("traveler")
  check(luggage.carry_texture(direction,"walk",1).get_image().get_data()==fresh.get_image().get_data(),"switching back restores the exact new "+direction+" carry image")
 appearance.select("legacy");g.return_title()
 check(pink_count(g.world.hero.texture)>0,"menu reset honors the preserved legacy appearance")
 appearance.select("traveler");g.return_title()
 check(pink_count(g.world.hero.texture)==0,"menu reset restores the new appearance without stale coffee cache")
 g.start_arrival();g.phase_age=g.camera.intro_duration;g.tick(0);g.tick(2.1);g.tick(.76)
 var lifting: Image=g.world.hero.texture.get_image()
 check(g.world.plaza.travel_luggage.stand_arm.visible and lifting.get_pixel(38,82).a<.01,"pickup replaces the resting sleeve with the reaching arm instead of drawing a duplicate arm")
 finish()
