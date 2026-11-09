extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(v: bool,s: String) -> void:
 checks+=1
 if not v:failures.append(s);printerr("FAIL: ",s)
func advance(t: float) -> void:
 while t>.0000001:
  var dt:=minf(t,1.0/120);g.tick(dt);t-=dt
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false)
 check(g.has_method("start_coast"),"playable coast entry")
 if not g.has_method("start_coast"):g.queue_free();await process_frame;finish();return
 g.start_coast();check(g.encounter_mode=="coast" and g.mode=="combat","coast combat mode");check(g.enemies.size()==10,"two of each ordinary type")
 var kinds: Dictionary={}
 for e in g.enemies:kinds[e.kind]=true;check(e.has_method("hurt_regions") and not e.has_method("register_melee_contact"),"ordinary body only "+e.kind)
 check(kinds.size()==5,"five ordinary kinds");check(g.arena.is_walkable(g.player.position),"spawn on sand")
 for where in [Vector3(-18,.03,2),Vector3(0,.03,2),Vector3(19,.03,2)]:
  g.player.position=where;g._camera_focus=where;g._visual_tick(.1);check(absf(g._camera_focus.x-where.x)<1.5,"camera follows expanded shore "+str(where.x))
 for where in [Vector3(30,.03,30),Vector3(-30,.03,-30),Vector3(1,.03,20)]:
  g.player.position=where;advance(.01);check(g.arena.is_walkable(g.player.position),"all player movement clamped "+str(where))
 for e in g.enemies:e.receive_damage(10000,Vector3.ZERO)
 g.health=60;advance(1.7);check(g.coast.stage=="captain","clearing ordinary enemies advances encounter");check(g.enemies.size()==1 and g.enemies[0].kind=="captain","boss placed once");check(g.health>=60,"boss entry does not harm player")
 var cap=g.enemies[0];advance(.2);check(g.enemies.size()==1,"no duplicate boss")
 cap.receive_damage(10000,Vector3.ZERO);advance(1.2);check(g.mode=="victory" and g.coast.stage=="complete","coast victory");check(g.projectiles.is_empty(),"victory clears hostile shots")
 g.restart();check(g.enemies.size()==10 and g.coast.stage=="ordinary" and g.mode=="combat","coast replay resets");check(g.flasks.charges==3 and g.anatomy.arm_count()==2,"replay restores body and flasks")
 g.shoot(g.player.position+Vector3.UP*.6,Vector3.RIGHT,10);g.anatomy.integrity.head=0;g._sync_body_state();check(g.mode=="dead","coast body death");check(g.projectiles.is_empty(),"death clears hostile shots immediately");g.restart();check(g.enemies.size()==10 and g.mode=="combat","replay after coast death")
 g.start_run(true);check(g.encounter_mode=="" and not g.arena.has_method("shoreline"),"leave coast restores original arena");g.start_captain();check(g.encounter_mode=="captain" and g.enemies[0].kind=="captain","direct captain retained");g.start_coast();g.return_menu();check(g.mode=="menu" and g.enemies.is_empty(),"menu clears exploration")
 g.queue_free();await process_frame;await process_frame;finish()
func finish() -> void:
 print("COAST GAME: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
