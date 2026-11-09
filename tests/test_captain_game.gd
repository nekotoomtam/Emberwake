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
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path=""
 check(g.has_method("start_captain"),"encounter entry")
 if not g.has_method("start_captain"):quit(1);return
 g.start_captain();check(g.encounter_mode=="captain" and g._harbor_mode,"harbor mode");check(g.enemies.size()==1 and g.enemies[0].kind=="captain","one mini only")
 var e=g.enemies[0];check(e.health==680 and not e.arm_cut,"fresh captain")
 var forward:=Vector3(-e.view_right.z,0,e.view_right.x)
 var a: Vector3=e.position+e.view_right*.45-forward;var b: Vector3=e.position+e.view_right*.45+forward
 check(g.staff_flight._first_contact(a,b,.01,[e],null).is_empty(),"slim body outside projectile misses")
 var arm_region: Dictionary=e.hurt_regions()[0];var arm_axis: Vector3=(arm_region.position-e.position).normalized()
 a=arm_region.position+arm_axis*(float(arm_region.radius)-.02)-forward;b=arm_region.position+arm_axis*(float(arm_region.radius)-.02)+forward
 check(not g.staff_flight._first_contact(a,b,.01,[e],null).is_empty(),"visible outer arm projectile hits")
 e.attack_data=e.Rules.definition("throw");e.state="windup";e.telegraph_left=1.0
 g.stats.base.critical_chance=0;g.enemy_hit(e,18,Vector3.ZERO);check(e.state=="windup","normalhit cannot stunlock mini")
 check(not e.register_melee_contact("chain_arm",999,"mace"),"blunt cannot sever");check(not e.register_melee_contact("body",999,"sword"),"body not arm")
 g.weapon_family="sword"
 for i in range(6):g.enemy_hit(e,18,Vector3.ZERO,"",-1,false,"chain_arm")
 check(e.arm_cut and e.health>0,"actualHP plus cut notkill");check(e.state!="windup" and e.attack_data.is_empty(),"cut cancels throw")
 e.state="chase";e.cooldown=0;g.player.position=Vector3(4,.03,0);g._iframes=100;var seen: Dictionary={};var throw_after_cut:=false
 for i in range(1400):
  advance(1.0/120)
  if not e.attack_data.is_empty():seen[e.attack_data.id]=true;throw_after_cut=throw_after_cut or e.attack_data.id=="throw"
 check(not throw_after_cut,"cut prevents future throws");check(seen.has("sweep") and seen.has("slam"),"remaining attacks still work");g._iframes=0
 e.receive_parry();check(e.state=="parried" and e.stagger==1,"parry stagger retained");advance(.2);g.enemy_hit(e,18,Vector3.ZERO);check(e.stagger<.2 and e.state=="chase","hit ends parry stagger")
 e.receive_damage(10000,Vector3.ZERO);advance(1);check(g.mode=="victory" and g.enemies.is_empty(),"victory no dummyrespawn");g.restart();check(g.encounter_mode=="captain" and not g.enemies[0].arm_cut and g.flasks.charges==3,"T replay restores mini flask")
 g.start_run(true);check(not g._harbor_mode and g.encounter_mode=="" and g.enemies[0].kind=="dummy","normalpractice retained")
 g.queue_free();await process_frame
 print("CAPTAIN GAME: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
