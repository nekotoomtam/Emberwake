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
 check(g.has_method("remove_body_part"),"body integration absent")
 if not g.has_method("remove_body_part"):g.queue_free();await process_frame;print("BODY GAME: FAIL",failures);quit(1);return
 fresh("pistol0","pistol1");g.remove_body_part("right_arm");close(g.max_health(),90,"maxHP90");close(g.health,90,"clamp not doublesubtract");check(g.request_attack(),"remainingleft canattack");advance(.6);check(g.item_magazines.pistol0.rounds==10 and g.item_magazines.pistol1.rounds==9,"onlyleft bulletspends");close(g.attack_rate(),1,"singlefunctionalhand no dualpenalty")
 fresh("greatsword0");g.remove_body_part("left_arm");check(not g.request_attack(),"twohand requiresbotharms")
 fresh("pistol0","pistol1");g.request_attack();advance(.03);g.remove_body_part("right_arm");advance(.9);check(g.item_magazines.pistol0.rounds==10 and g.item_magazines.pistol1.rounds==10,"lostarm cancelswindup no ghostshots")
 fresh("pistol0");g.remove_body_part("left_leg");close(g.anatomy.dash_multiplier(),.6,"onelegdashshort");check(g.request_dodge(Vector3.RIGHT),"onelegdash allowed")
 fresh("pistol0");g.remove_body_part("left_leg");g.remove_body_part("right_leg");check(g.request_dodge(Vector3.RIGHT),"noleg elbow dash");advance(.5);g.move_input=Vector2.RIGHT;advance(.1);check(not g.request_attack(),"crawl moving cannotattack");g.move_input=Vector2.ZERO;advance(.1);check(not g.request_attack(),"crawl stance wait");advance(.16);check(g.request_attack(),"crawl .25stance thenattack");g.move_input=Vector2.RIGHT;var before: Vector3=g.player.position;advance(.15);check(g.player.position.distance_to(before)<.05,"crawl shooting stationary");check(g.avatar.weapon.visible,"crawl committedweapon staysvisible withmovementinput")
 fresh("pistol0");g.remove_body_part("right_arm");g.remove_body_part("left_arm");check(not g.request_attack(),"armless no weapons");g.remove_body_part("right_leg");g.remove_body_part("left_leg");check(g.anatomy.move_multiplier()>0,"limbless canwriggle");close(g.max_health(),50,"fourlimb max50")
 g.restore_body();check(g.anatomy.arm_count()==2 and g.anatomy.leg_count()==2 and g.max_health()==100,"restore fullbody")
 g.set_debug_health_zero();check(g.mode=="practice" and g.health==0,"HP0 alive");check(g.request_attack(),"HP0 canact");advance(.6)
 g.set_body_integrity("torso",0);check(g.mode=="practice","torso0 alive");g.hit_body_part("torso",20);close(g.anatomy.integrity.head,80,"game spillhead");g.set_body_integrity("head",0);check(g.mode=="dead","head0 fatal")
 g.restart();check(g.mode=="practice" and g.anatomy.arm_count()==2 and g.anatomy.leg_count()==2 and g.health==100,"T restartfull")
 g.toggle_body_lab();var t: float=g.run_time;advance(.5);close(g.run_time,t,"labpauses");g.toggle_body_lab()
 var key:=InputEventKey.new();key.physical_keycode=KEY_B;key.pressed=true;root.push_input(key,true);check(g.body_lab_open,"B openslab viarealinput")
 key=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,true);check(not g.body_lab_open and g.mode=="practice","Escape closeslab withoutpause")
 edge_cases()
 sanity_cases()
 g.queue_free();await process_frame
 print("BODY GAME: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

func edge_cases() -> void:
 fresh("sword0");g.set_debug_health_zero();var e=g.spawn_enemy("melee",g.player.position+Vector3.RIGHT*1.1);e.cooldown=0;advance(1.0/120);check(e.state=="windup" and e.attack_data.parryable,"HP0 keeps normal windup parryable")
 fresh("rifle0");g.remove_body_part("right_leg");g.remove_body_part("left_leg");advance(.26);var before: Vector3=g.player.position;check(g.request_attack(),"prone rifle ready");advance(1.2);check(Vector2(g.player.position.x-before.x,g.player.position.z-before.z).length()<.001,"prone rifle cannot move byrecoil")
 fresh("pistol0","pistol1");g.set_body_integrity("right_arm",25);g.incoming_attack(10,g.player.position+Vector3.RIGHT,false,null,1,"right_arm",30);check(not g.anatomy.present("right_arm"),"real redincomingseverscriticalarm");close(g.health,90,"realhit no doubledHP subtraction")
 fresh("sword0");right(true);advance(.2);g.incoming_attack(10,g.player.position+Vector3.RIGHT,true,null,1,"torso",20);close(g.anatomy.integrity.torso,81.333333,"guard reducesbodydamage30percent");close(g.health,93,"guard HPdamage30percent")
 fresh("sword0");g.set_body_integrity("right_arm",25);g.set_debug_health_zero();right(true);g.incoming_attack(10,g.player.position+Vector3.RIGHT,true,null,1,"right_arm",50);check(g.anatomy.present("right_arm") and g.readiness.parries==1,"HP0 can parry a normal attack")
 fresh("pistol0","pistol1");g.item_magazines.pistol0.rounds=5;g.item_magazines.pistol1.rounds=7;g.remove_body_part("right_arm");check(g.request_reload(),"leftreload accepted");advance(.51);check(g.item_magazines.pistol0.rounds==5 and g.item_magazines.pistol1.rounds==10,"missinghand cannotreload itsgun")

func sanity_cases() -> void:
 fresh("sword0")
 g.clear_actors()
 g.add_sanity(198)
 g.health = 3
 g.damage_player(10, Vector3.INF, 1.0, "physical", "left_lower_leg", 8.0)
 check(g.health == 0 and g.sanity == 198 and not g.frenzy, "hit that empties HP does not grant sanity")
 g._iframes = 0.0
 var enemy = g.spawn_enemy("melee", g.player.position + Vector3.RIGHT * 1.1)
 enemy.cooldown = 0.0
 enemy.tick(.01, g)
 check(enemy.state == "windup" and enemy.attack_data.parryable, "critical windup remains parryable")
 g.shoot(g.player.position + Vector3.BACK * 8.0, Vector3.RIGHT, 10.0, true)
 g.damage_player(10, Vector3.INF, 1.0, "physical", "left_lower_leg", 8.0)
 check(g.sanity == 203 and g.frenzy and g.health == 0, "next real body hit adds 5 and triggers frenzy")
 enemy.tick(.01, g)
 g._update_projectiles(.01)
 check(enemy.attack_data.parryable and g.projectiles[0].parryable, "committed windup and flying shot keep their old tells")
 g._visual_tick(0)
 check(g.ui.frenzy_border.visible and g.ui.flask_button.disabled, "frenzy border and flask gate are visible")
 check(not g.use_health_flask(), "frenzy rejects manual flask")
 var red = g.spawn_enemy("melee", g.player.position + Vector3.LEFT * 1.1)
 red.cooldown = 0.0
 red.tick(.01, g)
 check(red.state == "windup" and not red.attack_data.parryable, "next nearby windup commits red")
 check(g.enemy_attack_parryable(true, g.player.global_position + Vector3.RIGHT * 30), "distant windup keeps authored defense")
 g._iframes = 0.0
 g.receive_forest_poison(4.0, 1.0)
 check(g.sanity == 203 and g.anatomy.integrity.head < 100, "poison still hurts parts but grants no sanity in frenzy")
 g.clear_actors()
 g.mode = "combat"
 g.reward_dungeon_clear_health()
 check(g.sanity == 173 and not g.frenzy and g.health == 0 and g.anatomy.integrity.left_lower_leg < 100, "clear returns prior zero HP and retains injury")
 g.add_sanity(-500)
 check(g.sanity == 100, "marked sanity never recovers below 100")
 g._iframes = 0.0
 g.receive_forest_poison(4.0, 1.0)
 check(g.sanity == 105, "poison hit across all parts grants 5 only once")
 g._iframes = 0.0
 g.damage_player(4.0, Vector3.INF, 1.0, "physical", "torso", 0.0)
 check(g.sanity == 105, "HP0 without part damage grants no sanity")

 g.start_dungeon(185)
 var direction: Vector2i = g.dungeon.rooms[g.dungeon.start].links.keys()[0]
 var target: Vector2i = g.dungeon.rooms[g.dungeon.start].links[direction]
 g.dungeon.enter(g, target, -direction)
 g.clear_actors()
 g.health = 35.0
 check(g.use_health_flask() and g.flasks.rate() > 0.0, "ongoing flask fixture")
 g.health = 35.0
 g.stats.flat["intelligence"] = 12
 var threshold := 200
 g.add_sanity(threshold)
 check(not g.frenzy and g.frenzy_threshold() == threshold, "INT does not move the fixed frenzy threshold")
 g.add_sanity(1)
 check(g.frenzy and g.health == 0 and g.flasks.rate() == 0.0, "exceeding tolerance cancels an ongoing flask")
 g.stats.flat["health_regen"] = 2.0
 g.tick(.10)
 check(g.health == 0, "passive regen cannot raise frenzy HP")
 g.stats.flat.erase("health_regen")
 g.dungeon.rooms[target].enemies.clear()
 g.dungeon.tick(g, 0.0)
 check(g.dungeon.rooms[target].cleared and g.sanity == threshold - 29 and g.health == 35, "real room clear restores prior HP with no stacked reward")
 g.dungeon.tick(g, 0.0)
 check(g.sanity == threshold - 29 and g.health == 35, "cleared room cannot apply recovery twice")
 g.add_sanity(70)
 g.reward_dungeon_clear_health()
 check(g.sanity == threshold + 11 and g.frenzy and g.health == 0, "one clear may leave frenzy active")
 g.stats.flat.erase("intelligence")
 g.start_dungeon(185)
 check(g.sanity == 0 and not g.frenzy and g.health == g.max_health(), "new run resets combat sanity state")
