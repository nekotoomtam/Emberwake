extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
var walls: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func fresh() -> void:
 game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05
 game.start_run(true);game.clear_actors();game.test_aim=Vector3.RIGHT;game.aim=Vector3.RIGHT;game.player.position=Vector3.ZERO
func enemy(where: Vector3,kind: String="melee"):
 var e=game.spawn_enemy(kind,where);e.set_physics_process(false);return e
func wall(where: Vector3) -> void:
 var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.3,2,3)
 shape.shape=box;body.position=where;body.add_child(shape);game.add_child(body);walls.append(body)
func refresh() -> void:
 await physics_frame;game._visual_tick(.05)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 fresh();await refresh()
 check(game.stats.base.sight_range==10 and game.stats.base.sense_radius==5,"independent authored vision stats")
 for degrees in [-180,-90,-61,-60,-59,0,59,60,61,90,180]:
  var a:=deg_to_rad(float(degrees));check(game.vision.in_cone(Vector3(cos(a),0,sin(a))*3)==(abs(degrees)<=60),"120degree exact cone "+str(degrees))
 check(not game.vision.can_see(Vector3(10.1,0,0)),"finite sight range")
 var front=enemy(Vector3(3,0,0));var rear=enemy(Vector3(-3,0,0));var far=enemy(Vector3(-6,0,0))
 await refresh();check(front.visible,"front enemy visible")
 check(not rear.visible and not far.visible,"rear enemies hidden")
 check(not rear.sprite.is_visible_in_tree() and not rear.bar.is_visible_in_tree() and not rear.attack_visual.is_visible_in_tree(),"hide full enemy hierarchy")
 check(game.vision.warnings.size()==1 and game.vision.warnings.has(8),"rear inside sense directional cue only")
 var near=enemy(Vector3(-1,0,.1));await refresh();check(game.vision.warnings.size()==1,"same direction merges")
 check(game.vision.warnings[8]>.79,"closest threat strongest")
 near.dead=true;rear.dead=true;await refresh();check(game.vision.warnings.is_empty(),"dead and out-of-range give no cue")
 fresh();rear=enemy(Vector3(-3,0,0));game.stats.flat.sense_radius=2;await refresh()
 check(game.vision.warnings.size()==1,"sense modifier expands radius")
 check(game.stats.base.sense_radius==5,"sense base preserved")
 game.stats.flat.sense_radius=-4;await refresh();check(game.vision.warnings.is_empty(),"sense modifier shrinks radius")
 game.stats.flat.sense_radius=-5;await refresh();check(game.vision.warnings.is_empty(),"zero sense disabled")
 game.stats.reset_modifiers();game.test_aim=Vector3.LEFT;game._refresh_aim();await refresh();check(rear.visible and game.vision.warnings.is_empty(),"turn reveals threat and removes cue")
 fresh();front=enemy(Vector3(3,0,0));rear=enemy(Vector3(-3,0,0));wall(Vector3(1.5,1,0));wall(Vector3(-1.5,1,0))
 await refresh();check(not front.visible and not rear.visible,"walls block enemy sight")
 check(game.vision.warnings.is_empty(),"wall blocks rear sense")
 check(not game.vision.clear_line(game.player.position,Vector3(3,0,0)),"solid line of sight")
 check(game.vision.ray_samples[0]<2 and game.vision.ray_samples[128]<2,"fog rays stop at walls")
 for body in walls:body.queue_free()
 walls.clear();await refresh();check(front.visible and game.vision.warnings.has(8),"wall removal restores sight and sense")
 fresh();front=enemy(Vector3(3,0,0));rear=enemy(Vector3(-3,0,0));rear.cooldown=10
 await refresh();var before: Vector3=rear.position
 await physics_frame;game.tick(.05)
 check(not rear.visible and rear.position.distance_to(before)>.01,"hidden AI still moves")
 var hp: float=rear.health;game.enemy_hit(rear,5,Vector3.ZERO);check(rear.health==hp-5,"hidden enemy still receives real damage")
 fresh();front=enemy(Vector3(3,0,0));game.set_weapon_family("sword");game.request_attack();var locked: Vector3=game.aim
 game.test_aim=Vector3.LEFT;await refresh()
 check(not front.visible and game.aim==locked,"live sight turns while combat aim remains committed")
 fresh();front=enemy(Vector3(2,0,0));await refresh();game.enemy_hit(front,5,Vector3.ZERO)
 var tagged: Array=[]
 for particle in game.fx.particles:
  var point: Vector3=particle.get("sight_point",Vector3.INF)
  if point.is_finite():tagged.append(particle)
 check(not tagged.is_empty(),"enemy feedback carries concealment point")
 game.test_aim=Vector3.LEFT;await refresh()
 for particle in tagged:check(not particle.node.visible,"existing hit feedback hides when sight turns")
 game.test_aim=Vector3.RIGHT;await refresh()
 for particle in tagged:check(particle.node.visible,"visible impact feedback may reappear until normal expiry")
 game.mode="menu";game.vision.update_view(0);check(not game.vision.fog.visible and game.vision.warnings.is_empty(),"menu clears overlay and cues")
 fresh();game.stats.flat.sight_range=-9;check(not game.vision.can_see(Vector3(3,0,0)),"sight range modifier")
 game.stats.flat.sight_range=-20;await refresh();check(is_finite(game.vision.ray_samples[0]),"zeroed sight remains numerically safe")
 check(game.ui.layer>game.vision.layer and game.arsenal.layer>game.vision.layer and game.stats_panel.layer>game.vision.layer,"all UI above fog")
 game.stats.reset_modifiers();game.start_dungeon(173);game.test_aim=Vector3.RIGHT
 game.set_weapon_family("sword");await refresh()
 check(is_equal_approx(rad_to_deg(game.vision.half_angle())*2,150),"dungeon uses a 150 degree view")
 check(is_equal_approx(game.vision.reach(),15),"dungeon has 15 metre normal sight")
 var origin: Vector3=game.player.position
 for degrees in [-76,-75,75,76]:
  var angle:=deg_to_rad(float(degrees))
  check(game.vision.in_cone(origin+Vector3(cos(angle),0,sin(angle))*3)==(abs(degrees)<=75),"dungeon cone boundary "+str(degrees))
 check(game.vision.in_cone(origin+Vector3.RIGHT*15) and not game.vision.in_cone(origin+Vector3.RIGHT*15.05),"dungeon range boundary")
 check(is_equal_approx(float(game.vision.material.get_shader_parameter("sight_range")),15),"fog uses dungeon range")
 check(is_equal_approx(float(game.vision.material.get_shader_parameter("cone_cos")),cos(deg_to_rad(75))),"fog uses dungeon cone")
 wall(origin+Vector3(4,1,0));await refresh()
 check(not game.vision.can_see(origin+Vector3.RIGHT*8),"dungeon sight still stops at cover")
 game.set_weapon_family("pistol");game.pistol_aim_state.advance(1.0,true)
 check(is_equal_approx(rad_to_deg(game.vision.half_angle())*2,90),"dungeon pistol retains its fully aimed cone")
 game.set_weapon_family("rifle");game.rifle_focus_state.advance(1.0,true)
 check(is_equal_approx(rad_to_deg(game.vision.half_angle())*2,32),"dungeon rifle retains its fully aimed cone")
 check(is_equal_approx(game.vision.reach(),21),"dungeon rifle focus scales the wider sight range")
 game.queue_free();await process_frame
 print("SIGHT SENSE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

