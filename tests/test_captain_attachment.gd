extends SceneTree
var g
var count:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 count+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func close(a: float,b: float,label: String) -> void:check(absf(a-b)<.001,label+" got="+str(a))
func equip(id: String,hand: String) -> void:
 var index: int=g.loadout.bag.find(id)
 var src: Dictionary={"kind":"bag","index":index}
 if index<0:
  for i in range(2):
   for h in ["main","off"]:
    if g.loadout.sets[i][h]==id:src={"kind":"slot","set":i,"hand":h}
 var dst:={"kind":"slot","set":0,"hand":hand}
 if src!=dst:check(g.loadout.move_item(src,dst),"equip fixture")
func fresh(main: String,off: String="") -> void:
 g.loadout.defaults();g.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 g.loadout_edited();g.start_run(true);g.test_aim=Vector3.RIGHT;g.move_input=Vector2.ZERO;g.stats.base.critical_chance=0
 for e in g.enemies:e.position=Vector3(100,0,100)
func advance(t: float) -> void:
 while t>.0000001:
  var dt: float=minf(t,1.0/120);g.tick(dt);t-=dt
func right(on: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=on;root.push_input(e,true)
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path="";g.start_captain();var e=g.enemies[0]
 check(e.has_method("configure_throw_launch"),"throw release point from actual hand")
 if not e.has_method("configure_throw_launch"):g.queue_free();await process_frame;finish();return
 for mirror in [false,true]:
  g.start_captain();e=g.enemies[0];e.position=Vector3.ZERO;e.sprite.flip_h=mirror;e.attack_angle=PI if mirror else 0;e.state="attack";e.attack_data=e.Rules.definition("throw");e.configure_throw_launch();e.elapsed=e.attack_data.release-.00002;e.active_left=e.attack_data.active-e.elapsed;e.tick(.000001,g)
  close(e.captain_view.anchor_ring_world().distance_to(e.chain_wrist()),0,"held ring in hand "+str(mirror));var before: Vector3=e.captain_view.anchor.global_position;e.tick(.00004,g)
  check(e.captain_view.anchor.global_position.distance_to(before)<.01,"no release teleport "+str(mirror))
  e.elapsed=.50;e.tick(.0001,g);close(e.captain_view.chain_end.distance_to(e.captain_view.anchor_ring_world()),0,"chain ends at rotated ring")
  check(e.sprite.animation=="throw_active" and e.sprite.frame==3,"body finished cast while anchor airborne")
  var old: Vector3=e.captain_view.anchor.global_position;e.receive_parry();e.tick(1.0/120,g);check(e.captain_view.anchor.global_position.distance_to(old)<.03,"parry settles anchor instead of teleport");check(e.attack_data.is_empty(),"parried anchor no damage state")
 g.start_captain();e=g.enemies[0];e.state="attack";e.attack_data=e.Rules.definition("throw");e.configure_throw_launch();e.elapsed=.5;e.tick(.001,g);var old: Vector3=e.captain_view.anchor.global_position;e.register_melee_contact("chain_arm",108,"sword");e.tick(1.0/120,g)
 check(e.captain_view.anchor.global_position.distance_to(old)<.03,"cut cancels without anchor teleport");check(e.captain_view.handoff_left>0,"remaining hand takes chain over");advance(.3);close(e.captain_view.chain_start.distance_to(e.chain_wrist()),0,"handoff ends in remaining hand")
 e.receive_damage(10000,Vector3.ZERO);advance(.02);check(not e.captain_view.anchor.visible,"death clears anchor")
 g.start_captain();e=g.enemies[0];e.position=Vector3.ZERO;g.player.position=Vector3(-3,.03,0);g.test_aim=Vector3.RIGHT;e.state="attack";e.attack_angle=0;e.attack_data=e.Rules.definition("throw");e.configure_throw_launch();e.elapsed=.8;e.tick(.00001,g)
 var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,2.5,4);shape.shape=box;wall.add_child(shape);wall.position=Vector3(2,1,0);g.add_child(wall);await physics_frame;await physics_frame;g.vision.update_view(0)
 check(float(g.vision.material.get_shader_parameter("weapon_enabled"))==0,"far anchor behind wall not sharp")
 e.receive_parry();e.tick(1.0/120,g);g.vision.update_view(0);check(float(g.vision.material.get_shader_parameter("weapon_enabled"))==0,"cancelled anchor behind wall remains obscured while settling")
 g.queue_free();await process_frame;finish()
func finish() -> void:
 print("CAPTAIN ATTACHMENT: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
