extends SceneTree
var game
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, label: String) -> void:
 if not value:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 game.start_run(true);game.set_weapon_family("greatsword");game.test_aim=Vector3.RIGHT
 for i in range(120):game.tick(1.0/120)
 var points: Dictionary=game.avatar.get_blade_points()
 var blade: Vector3=points.tip-points.grip
 check(blade.normalized().dot(Vector3.RIGHT)<-.5,"resting greatsword points back while heroine aims forward")
 check(blade.y>.8,"resting greatsword rises over shoulder")
 check(game.aim.dot(Vector3.RIGHT)>.99,"face aim retained")
 for family in ["sword","mace","greatsword","staff","pistol","rifle"]:
  game.set_weapon_family(family)
  for i in range(120):game.tick(1.0/120)
  var carried: Dictionary=game.avatar.get_blade_points()
  var carried_length: float=carried.tip.distance_to(carried.grip)
  check(game.request_attack(),family+" attack starts")
  for i in range(300):
   game.tick(1.0/120)
   if game.motion.busy and game.current_visual_sample().phase=="active":
    var active: Dictionary=game.avatar.get_blade_points()
    check(absf(active.tip.distance_to(active.grip)-carried_length)<.0001,family+" length unchanged from rest to attack")
    check(active.tip.distance_to(game._staff_tip(game.current_visual_sample()))<.0001,family+" authored active tip retained")
    break
  while game.motion.busy:game.tick(1.0/120)
 game.loadout.defaults();game.loadout.save_path=""
 var index: int=game.loadout.bag.find("sword1")
 check(game.loadout.move_item({"kind":"bag","index":index},{"kind":"slot","set":0,"hand":"off"}),"equip paired swords")
 game.loadout_edited();game.start_run(true);game.test_aim=Vector3.LEFT
 for i in range(120):game.tick(1.0/120)
 var a: Dictionary=game.dual_visual.rigs[0].get_blade_points()
 var b: Dictionary=game.dual_visual.rigs[1].get_blade_points()
 check(Geometry2D.segment_intersects_segment(game.camera.unproject_position(a.grip),game.camera.unproject_position(a.tip),game.camera.unproject_position(b.grip),game.camera.unproject_position(b.tip))==null,"paired sword silhouettes do not cross while carrying left")
 game.queue_free();await process_frame
 print("HOLDING: ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
