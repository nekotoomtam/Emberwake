extends SceneTree
const Clash=preload("res://scripts/parry_clash_visual.gd")
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func fresh(direction: Vector3) -> void:
 game.start_run(true);game.set_weapon_family("sword");game.test_aim=direction;game._refresh_aim();game._visual_tick(.02)
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true;root.push_input(e,true)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
  for perfect in [true,false]:
   fresh(direction)
   if not perfect:game.readiness.parry_left=0
   var source: Vector3=game.player.position+direction*3
   game.incoming_attack(10,source,true)
   check(game.fx.clashes.size()==1,"successful defense emits impact")
   check(game.fx.last_clash.distance_to(game.player.position+direction*.8+Vector3.UP*.85)<.00001,"source direction contact independent of blade")
   var clash=game.fx.clashes[0];check(clash.perfect==perfect,"correct defense tier")
   check(is_equal_approx(clash.pixel_size,.021 if perfect else .012),"parry visibly larger than guard")
   check(game.health==100 if perfect else game.health==97,"defense balance preserved")
   var point: Vector3=clash.global_position;game._visual_tick(.02)
   check(clash.global_position==point,"weapon movement cannot relocate impact")
   game.fx.tick(.31);check(game.fx.clashes.is_empty(),"cleanup")
 fresh(Vector3.RIGHT);game.incoming_attack(10,game.player.position+Vector3.RIGHT,false)
 check(game.fx.clashes.size()==1 and not game.fx.clashes[0].perfect,"red attack still gives ordinary guard effect")
 fresh(Vector3.RIGHT);game.incoming_attack(10,game.player.position+Vector3.LEFT,true)
 check(game.fx.clashes.is_empty(),"unguarded rear hit no defense flash")
 fresh(Vector3.RIGHT);game.stamina=0;game.incoming_attack(10,game.player.position+Vector3.RIGHT,true)
 check(game.fx.clashes.is_empty(),"guard break no success flash")
 for heavy in [true,false]:
  for i in range(18):
   check(Clash.frame(i,heavy).get_size()==Vector2(128,128),"pixel effect frame")
   check(Clash.frame(i,heavy)==Clash.frame(i,heavy),"cache")
 game.fx.clear_transients();game.queue_free();await process_frame
 print("DIRECTIONAL DEFENSE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
