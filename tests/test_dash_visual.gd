extends SceneTree
const Dash=preload("res://scripts/dash_visual.gd")
const Art=preload("res://scripts/dash_art.gd")
var failures: Array[String]=[]
var checks:=0
var game
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func fresh() -> void:
 game.loadout.defaults();game.loadout_edited();game.start_run(true);game.test_aim=Vector3.RIGHT
 for enemy in game.enemies:enemy.position=Vector3(100,0,100)
func step(count: int) -> void:
 for i in range(count):await physics_frame;game.tick(1.0/120)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for facing in ["front","back","left","right"]:
  var kinds: Dictionary={}
  for kind in ["front","back","left","right"]:
   kinds[hash(Art.frames(facing,kind).get_frame_texture("dodge",2).get_image().get_data())]=true
   var textures:=Art.frames(facing,kind)
   var unique: Dictionary={}
   for i in range(6):
    var image:=textures.get_frame_texture("dodge",i).get_image()
    check(image.get_size()==Vector2i(128,128),"128px dash frames")
    unique[hash(image.get_data())]=true
    check(Art.shoulders(facing,kind,i).size()==2,"two shoulder anchors")
   check(unique.size()>=3,"articulated leg poses: "+facing+kind)
  check(kinds.size()==4,"all four dash directions have distinct leg poses: "+facing)
 for f in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
  var right:=Vector3(-f.z,0,f.x)
  for entry in [[f,"front"],[-f,"back"],[right,"right"],[-right,"left"]]:check(Dash.classify(f,entry[0])==entry[1],"mouse-relative classification")
 fresh();game.request_attack();check(game.motion.busy,"start melee");check(game.request_dodge(Vector3.LEFT),"dodge interrupts melee")
 check(not game.motion.busy and not game.pair_strikes.active and game._next_combo==0,"paired chain canceled and combo reset")
 check(is_equal_approx(game._dodge_left,.24) and is_equal_approx(game._dodge_recharge,.42) and game._iframes==0 and game.rewards.invulnerable() and game.rewards.DODGE_IFRAMES==.16 and is_equal_approx(game.stamina,70),"approved dodge timing and separate0.16 iframe")
 check(not game.request_dodge(Vector3.RIGHT),"cannot redash during dash")
 await step(12)
 check(game.avatar.body.animation=="dodge" and game.avatar.dodge_kind=="back","retreat pose instead of forward pose")
 var selected: String=game.avatar.facing;game.test_aim=Vector3.LEFT;await step(1);check(game.avatar.facing==selected,"dash facing snapshot prevents midpoint flip")
 await step(20);check(game.avatar.body.animation!="dodge" and game.avatar.dodge_kind=="","dash cleanup")
 check(game.request_attack(),"no extra landing action lock")
 for kind in ["twin_cut","armor_pierce"]:
  fresh();check(game.request_skill() if kind=="twin_cut" else game.request_armor_skill(),"start skill")
  check(game.request_dodge(Vector3.RIGHT) and not game.skill_active and not game.motion.busy,"dodge cancels skill "+kind)
 fresh();game.item_magazines.pistol0.rounds=9;check(game.request_reload(),"start paired pistol reload")
 check(game.request_dodge(Vector3.RIGHT) and not game.guns_reloading() and not game.reload_visual.active,"dodge cancels reload")
 fresh();game.stamina=29;check(not game.request_dodge(Vector3.RIGHT),"low stamina blocks dash")
 game._visual_tick(.01);check(game.avatar.body.animation!="dodge","blocked dash does not animate")
 game.queue_free();await process_frame
 print("DASH VISUAL: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
