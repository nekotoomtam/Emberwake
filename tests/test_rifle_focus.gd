extends SceneTree
var count:=0
var failures: Array=[]
func check(ok: bool,message: String) -> void:
 count+=1
 if not ok:failures.append(message);printerr("FAIL: ",message)
func close(a: float,b: float,message: String) -> void:check(absf(a-b)<.001,message+" got="+str(a))
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var focus=load("res://scripts/rifle_focus.gd").new()
 close(focus.camera_size(),13.5,"normal camera")
 focus.advance(.1,true);check(focus.amount()>0 and focus.amount()<.3,"entry gradual notinstant")
 check(rad_to_deg(focus.half_angle())*2<120 and rad_to_deg(focus.half_angle())*2>32,"cone moves gradually")
 focus.advance(.175,true);close(focus.amount(),.5,"halfway smooth")
 focus.advance(.275,true);close(focus.amount(),1,"full after.55")
 close(rad_to_deg(focus.half_angle())*2,32,"full narrow32")
 close(focus.camera_size(),13,"actual zoomIN")
 close(focus.sight_multiplier(),1.4,"same longrange")
 focus.advance(.1,false);check(focus.amount()<1 and focus.amount()>.7,"exit gradual")
 focus.advance(.45,false);close(focus.amount(),0,"returnsnormal")
 focus.advance(NAN,true);close(focus.amount(),0,"invaliddelta ignored")
 var game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path="";game.start_run(true);game.set_weapon_family("rifle");game.test_aim=Vector3.RIGHT
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true;root.push_input(e,true)
 close(game.vision.reach(),10,"RMBpress noinstantfarvision")
 game.tick(.1);check(game.vision.reach()>10 and game.vision.reach()<14,"controller intermediate reach")
 game.tick(.45);close(game.vision.reach(),14,"controller fullreach")
 close(rad_to_deg(game.vision.half_angle())*2,32,"controller fullcone")
 close(game.camera.size,13,"controller zoomin")
 check(not game.rifle_scope.visible,"ordinary aim has no dark scope overlay")
 check(game._camera_focus.x > 3.0,"camera still pushes toward the aim direction at full zoom")
 check(not game.vision.in_cone(Vector3(5,0,3)),"side target clipped")
 check(game.vision.in_cone(Vector3(10,0,0)),"forward linevisible")
 check(game.request_attack(),"shooting still immediate afterfocus");close(game.stamina,85,"ADS cost15 unchanged")
 close(game.motion.definition(0).windup+game.motion.definition(0).active+game.motion.definition(0).recovery,1.2,"ADS timing unchanged")
 e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=false;root.push_input(e,true);game.tick(.55)
 close(game.camera.size,13.5,"camera restored")
 close(rad_to_deg(game.vision.half_angle())*2,120,"cone restored")
 close(game.rifle_focus_state.amount(),0,"release ends aim zoom")
 for action in ["toggle_inventory","toggle_stats","toggle_pause"]:
  game.start_run(true);game.set_weapon_family("rifle")
  e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true;root.push_input(e,true);game.tick(.55)
  check(game.rifle_aiming(),"menu test aiming before "+action)
  game.call(action);check(not game.rifle_aiming(),"menu cancels aim in "+action)
  game.call(action);game.tick(.55);close(game.camera.size,13.5,"camera safely restored after "+action)
 game.use_cutout_avatar = true
 game.avatar.enable_cutout()
 for direction: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3(-.6, 0, -.8)]:
  game.start_run(true)
  game.set_weapon_family("rifle")
  game.clear_actors()
  game.test_aim = Vector3.ZERO
  game.readiness.press(false)
  var target: Vector3 = game.player.global_position + direction * 6.0 + Vector3.UP * game.RifleMotion.RAISED_AIM_HEIGHT
  for frame in 44:
   game._mouse_position = game.camera.unproject_position(target)
   game.tick(1.0 / 120.0)
  check(game.request_attack(), "cursor-aimed shot starts")
  var cursor_origin: Vector3 = game._rifle_target_origin
  var cursor_ray: Vector3 = game._rifle_target_ray
  game._mouse_position += Vector2(60, 35)
  var muzzle_before_shot := Vector3.ZERO
  for frame in 100:
   muzzle_before_shot = game.avatar.get_blade_points().tip
   game.tick(1.0 / 240.0)
   if game.staff_flight.shots_fired > 0: break
  check(not game.staff_flight.active.is_empty(), "cursor-aimed shot releases")
  if game.staff_flight.active.is_empty(): continue
  var shot: Dictionary = game.staff_flight.active[0]
  close(shot.origin.y, game.rifle_cursor_height(), "all aimed directions use one shot height")
  close(shot.node.bullet.global_position.y, shot.origin.y, "drawn tracer follows the actual height")
  check(game.camera.unproject_position(shot.origin).distance_to(game.camera.unproject_position(muzzle_before_shot)) < 1.0,
   "shot begins at the visible muzzle")
  var locked_target := cursor_origin + cursor_ray * ((float(shot.origin.y) - cursor_origin.y) / cursor_ray.y)
  close((locked_target - shot.origin).cross(shot.direction).length(), 0, "actual bullet passes through locked cursor")
  close(game.camera.unproject_position(locked_target).distance_to(game.pistol_reticle.center), 0, "reticle displays the locked target")
 game.start_run(true)
 game.set_weapon_family("rifle")
 game.clear_actors()
 game.test_aim = Vector3.ZERO
 var finisher_target: Vector3 = game.player.global_position + Vector3.RIGHT * 6.0 + Vector3.UP * game.RifleMotion.RAISED_AIM_HEIGHT
 game._mouse_position = game.camera.unproject_position(finisher_target)
 check(game._use_rifle_skill(game.RifleMotion.FINISHER_ID), "finisher starts a scoped charge")
 for frame in 95:
  game._mouse_position = game.camera.unproject_position(finisher_target)
  game.tick(1.0 / 120.0)
 var guide: PackedVector2Array = game.rifle_scope.guide.points
 check(game.rifle_scope.guide.visible and guide.size() == 2, "finisher draws a guide during charge")
 if guide.size() == 2:
  var line: Dictionary = game.aimed_rifle_line(game.motion.sample())
  var muzzle: Vector3 = game.avatar.get_blade_points().tip
  close(guide[0].distance_to(game.camera.unproject_position(muzzle)), 0, "scope guide begins at the drawn muzzle")
  close(guide[1].distance_to(game.camera.unproject_position(line.origin + line.direction * game.RifleMotion.FINISHER_RANGE)), 0,
   "scope guide previews the actual aimed shot")
  close(absf((game.pistol_reticle.center - guide[0]).cross((guide[1] - guide[0]).normalized())), 0,
   "scope guide passes through the reticle")
 game.queue_free();await process_frame
 print("RIFLE FOCUS: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
