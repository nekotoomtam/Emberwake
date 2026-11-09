extends SceneTree
## v28: the requested resting carry replaces the historical indefinitely-held cut.
const STEP := 1.0/240
var game
var failures: Array[String]=[]
var checks := 0
func _initialize() -> void:Engine.physics_ticks_per_second=240;call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func ticks(count: int) -> void:
 for i in range(count):
  await physics_frame;game.tick(STEP)
  var blade: Dictionary=game.avatar.get_blade_points()
  check(absf(blade.tip.distance_to(blade.grip)-1.9)<.0001,"blade length stable during carry/entry/return")
  if game.motion.busy and game.current_visual_sample().phase=="active":check(blade.tip.distance_to(game._staff_tip(game.current_visual_sample()))<.0001,"authored active blade matches physical contact")
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 for initial in [.0,PI-.04,-PI+.04]:
  game.start_run(true);game.set_weapon_family("sword")
  for enemy in game.enemies:enemy.position=Vector3(100,.03,100)
  game.test_aim=Vector3(cos(initial),0,sin(initial));await ticks(300)
  for stage in range(3):
   var before: Dictionary=game.avatar.get_blade_points()
   check(game.request_attack(),"ordinary attack starts from carry")
   check(game.motion.stage==stage,"three-cut combo survives idle returns")
   game._visual_tick(.0)
   var entry: Dictionary=game.avatar.get_blade_points()
   check(entry.grip.distance_to(before.grip)<.0001 and entry.tip.distance_to(before.tip)<.0001,"windup begins at displayed carry without snapping")
   for i in range(400):
    await ticks(1)
    if not game.motion.busy:break
   check(not game.motion.busy,"cut finishes")
   await ticks(300)
   var points: Dictionary=game.avatar.get_blade_points();var axis: Vector3=(points.tip-points.grip).normalized()
   var angle: float=atan2(game.aim.z,game.aim.x)
   var expected := Vector3(cos(angle)*cos(.56),sin(.56),sin(angle)*cos(.56))
   check(axis.distance_to(expected)<.0001,"cut returns smoothly to requested diagonal carry")
   var next: float=[PI-.03,-PI+.03,.7][stage]
   game.test_aim=Vector3(cos(next),0,sin(next));await ticks(300)
 game.queue_free();await process_frame
 print("SWORD CARRY CONTINUITY: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
