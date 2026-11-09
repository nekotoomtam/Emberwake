extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func close(a: float,b: float,why: String) -> void:check(absf(a-b)<.001,why+" got="+str(a)+" expected="+str(b))
func fresh():
 game.start_run(true);game.clear_actors();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.set_weapon_family("mace");game.test_aim=Vector3.RIGHT;game._refresh_aim()
 var enemy=game.spawn_enemy("dummy",Vector3(2,.03,0));return enemy
func step(t: float) -> void:
 await physics_frame;game.tick(t)
func finish() -> void:
 for i in range(240):
  if not game.motion.busy and not game.pair_strikes.active:return
  await step(1.0/120)
 check(false,"attack completes")
func attack() -> void:
 check(game.request_attack(),"controller accepts attack");await finish()
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var enemy=fresh()
 check(enemy.has_method("apply_mace_break"),"real Enemy has mace status")
 for count in range(1,7):
  check(enemy.apply_mace_break(),"valid debuff applies")
  close(enemy.mace_armor.stacks,mini(count,5),"cap5")
  close(enemy.effective_armor(),100*(1-mini(count,5)*.1),"base armor fraction")
  close(enemy.mace_armor.remaining,10,"each valid application refreshes10s")
  close(enemy.calculate_incoming_damage(20,"physical"),20*100/enemy.effective_armor()*(1.1 if count>=5 else 1.0),"physical resolved exactly once")
  close(enemy.calculate_incoming_damage(20,"fire"),20,"fire bypasses physical vulnerability")
 check(enemy.mace_armor.broken(),"full stacks broken")
 enemy.advance_armor_status(9.9);close(enemy.mace_armor.stacks,5,"no individual stack expiry")
 enemy.apply_mace_break();close(enemy.mace_armor.remaining,10,"cap hit refreshes all")
 enemy.advance_armor_status(10);close(enemy.effective_armor(),100,"expiry restores armor");close(enemy.mace_armor.stacks,0,"expiry clears all stacks");close(enemy.calculate_incoming_damage(20,""),20,"expiry removes vulnerability")
 enemy.armor_rating=0
 for i in range(5):enemy.apply_mace_break()
 close(enemy.effective_armor(),0,"zeroarmor stayszero");close(enemy.calculate_incoming_damage(20,""),22,"zeroarmor fullstack physical+10%");close(enemy.calculate_incoming_damage(20,"fire"),20,"zeroarmor fire unchanged")
 for invalid in [-1.0,NAN,INF]:
  enemy.armor_rating=invalid;check(not enemy.apply_mace_break(),"invalidarmor refusesstatus");close(enemy.calculate_incoming_damage(20,""),0,"invalidarmor refusesdamage")
 enemy.armor_rating=200;enemy.advance_armor_status(10)
 for i in range(3):enemy.apply_mace_break()
 close(enemy.effective_armor(),140,"reduction based on targetbase200 not current armor")
 enemy.apply_armor_break(.2,4);close(enemy.effective_armor(),140,"legacy uses strongest not additive")
 enemy.advance_armor_status(4.1);close(enemy.mace_armor.stacks,3,"legacy expiry cannot erase mace stacks")
 enemy.apply_armor_break(.2,4);enemy.apply_mace_break();enemy.advance_armor_status(4.2);enemy.apply_mace_break();enemy.advance_armor_status(.9)
 check(enemy.mace_armor.stacks==5 and enemy.armor_break_fraction==0,"independent legacy and mace lifecycle")
 enemy.receive_damage(2000,Vector3.ZERO);check(enemy.dead and enemy.mace_armor.stacks==0,"death clearsstatus");check(not enemy.apply_mace_break(),"deadtarget cannotstack")
 enemy=fresh()
 var expected: Array=[34.0,12.0,46.0]
 for stage in range(3):
  var before: float=game.total_damage;var energy: float=game.stamina;await attack()
  close(game.total_damage-before,expected[stage],"firstcombo oldbase damage")
  close(game.stamina,energy-[12,8,18][stage],"originalcost")
  close(enemy.mace_armor.stacks,1 if stage==2 else 0,"only actualthird gainsstack")
 for count in range(2,6):
  game.stamina=100
  for stage in range(3):
   var before: float=game.total_damage
   var multiplier: float=100/enemy.effective_armor()*enemy.mace_armor.physical_multiplier()
   await attack();close(game.total_damage-before,expected[stage]*multiplier,"eachhit uses prehitstack fifthnotretroactive")
  close(enemy.mace_armor.stacks,count,"natural threehit combos stack once each")
 check(not game.ui.mace_status_panel.visible and enemy.mace_armor.broken() and is_instance_valid(game.status_icons) and not enemy.armor_badge.visible,"fullstack status uses icon instead of long HUD")
 close(enemy.calculate_incoming_damage(20,"physical"),44,"fullstack physical baseline2.2x for neutral100armor")
 game.set_weapon_family("sword");close(enemy.mace_armor.stacks,5,"weaponfamily switch preserves targetstatus")
 var before: float=game.total_damage;await attack();close(game.total_damage-before,game.motion.definition(0).damage*2.2,"actual sword benefits afterswitch")
 game.toggle_pause();var left: float=enemy.mace_armor.remaining;await step(10);close(enemy.mace_armor.remaining,left,"pause freezesstatus");game.toggle_pause()
 game._hit_stop=.1;await step(.05);close(enemy.mace_armor.remaining,left,"hitstop freezesstatus")
 enemy.advance_armor_status(10);game.ui.refresh();check(not game.ui.mace_status_panel.visible,"expiry hidesstatusHUD")
 enemy=fresh();enemy.position=Vector3(9,.03,6)
 for i in range(3):await attack()
 close(enemy.mace_armor.stacks,0,"missed third cannotapply")
 enemy=fresh();await attack();await attack();game.stamina=100;check(game.request_attack(),"third windup starts");check(game.request_dodge(Vector3.LEFT),"dodge cuts third");await step(.8);close(enemy.mace_armor.stacks,0,"canceled third cannotapply")
 enemy=fresh();enemy.health=1;game._next_combo=2;game.rewards.combo_left=.7;await attack();check(enemy.dead and enemy.mace_armor.stacks==0,"lethal third never leaves status")
 enemy=fresh();await attack();await attack();game.stamina=100;game.request_attack()
 for i in range(120):
  await step(1.0/120)
  if enemy.mace_armor.stacks>0:break
 var fracture={}
 for entry in game.fx.trails:
  if is_equal_approx(entry.total,.28):fracture=entry
 check(not fracture.is_empty() and fracture.get("sight_point",Vector3.INF)==enemy.position,"fracture carries actual target visibility point")
 game.test_aim=Vector3.LEFT;game._refresh_aim();game._visual_tick(0)
 if not fracture.is_empty():check(not fracture.node.visible,"fracture disappears immediately when hidden")
 check(not game.ui.mace_status_panel.visible,"HUD conceals hidden debuffed target")
 game.start_run(true);check(game.enemies[0].mace_armor.stacks==0,"newrun freshstatus")
 game.queue_free();await process_frame
 print("MACE ARMOR: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

