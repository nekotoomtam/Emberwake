extends SceneTree
const STEP := 1.0/120
var game
var cues: Array[String]=[]
var failures: Array[String]=[]
var checks := 0
func _initialize() -> void:Engine.physics_ticks_per_second=120;call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func record(cue: String) -> void:
 if cue.begins_with("pistol_") or cue.begins_with("rifle_"):cues.append(cue)
func key(code: Key) -> void:
 for down in [true,false]:
  var e := InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true)
func ticks(count: int) -> void:
 for i in range(count):await physics_frame;game.tick(STEP)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.audio.cue_requested.connect(record)
 for family in ["pistol","rifle"]:
  game.start_run(true);game.set_weapon_family(family);game.test_aim=Vector3.RIGHT
  for enemy in game.enemies:enemy.position=Vector3(100,.03,100)
  check(game.request_attack(),family+" shot starts")
  for i in range(200):
   await ticks(1)
   if not game.motion.busy:break
  check(game.casing_fx.spawned_count==1,family+" ejects one casing at its real shot")
  var mag=game.active_magazine();var spent: int=mag.rounds
  check(game.request_reload(),family+" partial R starts")
  await ticks(roundi(mag.reload_duration*.25/STEP))
  var elapsed: float=mag.elapsed;var count: int=cues.size()
  key(KEY_ESCAPE);check(game.mode=="paused","Escape pauses reload")
  await ticks(40)
  check(mag.elapsed==elapsed and cues.size()==count,family+" pause freezes reload clock and cues")
  key(KEY_ESCAPE);key(KEY_SPACE);await ticks(1)
  check(not mag.reloading and not game.reload_visual.active,family+" dodge cancels reload timeline")
  check(mag.rounds==spent,family+" cancellation grants no early refill")
  count=cues.size();await ticks(90)
  check(cues.size()==count,family+" canceled timeline emits no late reload cues")
  cues.clear();check(game.request_reload(),family+" can start a fresh reload")
  await ticks(ceili(mag.reload_duration/STEP)+2)
  var expected: Array=["pistol_reload_open","pistol_spin","pistol_catch","pistol_reload_done"] if family=="pistol" else ["rifle_reload_open","rifle_insert","rifle_rack","rifle_reload_done"]
  check(cues==expected,family+" four staged cues ordered once per real reload")
  check(mag.rounds==mag.capacity and not mag.reloading,family+" single refill at completion")
 game.queue_free();await process_frame
 print("RELOAD EVENTS: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
