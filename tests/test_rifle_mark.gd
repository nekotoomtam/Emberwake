extends SceneTree
var game
var checks:=0
var fails: Array[String]=[]
var impacts: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:fails.append(label);printerr("FAIL: ",label)
func close(a: float,b: float,label: String) -> void:check(absf(a-b)<.001,label+" got="+str(a)+" expected="+str(b))
func step(t: float) -> void:
 await physics_frame;game.tick(t)
func fresh():
 game.start_run(true);game.clear_actors();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.set_weapon_family("rifle");game.test_aim=Vector3.RIGHT;game._refresh_aim();game._visual_tick(0)
 var enemy=game.spawn_enemy("dummy",Vector3(2.5,.03,0));enemy.max_health=1000;enemy.health=1000;return enemy
func right(down: bool=true) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;root.push_input(e,true)
func finish() -> void:
 for i in range(500):
  if not game.motion.busy and not game.active_magazine().bolt_active and game.staff_flight.active.is_empty():return
  await step(1.0/120)
 check(false,"shot finishes")
func fire(ads: bool=false) -> void:
 right(ads);check(game.request_attack(),"shot accepted");await finish()
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var enemy=fresh()
 var strip: Control = game.ui.get("rifle_ammo_strip")
 check(is_instance_valid(strip) and strip.visible and strip.get_child_count()==5,"rifle shows five cartridge slots")
 check(not game.ui.ammo_text.text.contains("/"),"rifle keeps reload instructions without a numeric ammo fraction")
 var ammo_hud: Control = game.ui.get("rifle_ammo_hud")
 check(is_instance_valid(ammo_hud) and ammo_hud.anchor_right==1.0 and ammo_hud.anchor_bottom==1.0,"cartridges are anchored at the bottom right")
 check(not game.ui.help_panel.visible and not game.ui.ammo_text.visible,"rifle keeps the bottom right free of explanation strips")
 var gear: Control = game.ui.get("rifle_gear_large")
 for ads in [false,true]:
  enemy=fresh();right(ads)
  check(game.request_attack(),"mode snapshot starts")
  var spec: Dictionary=game.motion.definition(0)
  close(spec.windup+spec.active+spec.recovery,1.2 if ads else .9,"actual mode attacktotal")
  close(spec.damage,52,"base52");close(game.stamina,85 if ads else 90,"10or15paidonce")
  var before_turn := gear.rotation if is_instance_valid(gear) else 0.0
  right(not ads);await finish()
  check(is_instance_valid(gear) and not is_equal_approx(gear.rotation,before_turn),"firing a live round turns the gears")
  if is_instance_valid(strip):
   check(strip.get_child(0).modulate.a<1.0 and strip.get_child(4).modulate.a==1.0,"one fired shot leaves the empty slot on the left")
  close(enemy.rifle_mark.stacks,0,"neither ordinary mode applies a mark")
  check(game.active_magazine().can_fire(),"normal recovery finishes actual bolt")
  close(game.total_damage,52,"first contact no retroactiveMark")
 enemy=fresh()
 for i in range(4):
  var before: float=game.total_damage;await fire(i%2==1)
  close(game.total_damage-before,52.0,"ordinary repeat shots keep base damage")
  close(enemy.rifle_mark.stacks,0,"ordinary repeat shots build no mark")
 for i in range(3):enemy.apply_rifle_mark()
 var before_existing_mark: float=game.total_damage
 await fire(true)
 close(game.total_damage-before_existing_mark,57.2,"ordinary shot consumes a mark for +10%")
 check(enemy.rifle_mark.stacks==0,"the bonus consumes the mark")
 enemy.apply_rifle_mark()
 enemy.advance_armor_status(2);check(enemy.rifle_mark.stacks==1,"mark starts at one")
 check(enemy.apply_rifle_mark() and enemy.rifle_mark.stacks==1,"reapplying refreshes a single mark")
 close(enemy.rifle_mark.remaining,5,"repeat hits restart the full timer")
 enemy.advance_armor_status(5);close(enemy.rifle_mark.multiplier(),1,"expiry removes bonus")
 enemy.apply_rifle_mark();var before: float=game.total_damage;game._projectile_damage(enemy,20,Vector3.ZERO,"physical");close(game.total_damage-before,20,"pistol noMarkbonus")
 enemy.receive_damage(2000,Vector3.ZERO);check(enemy.dead and enemy.rifle_mark.stacks==0,"death clearsMark")
 for ads in [false,true]:
  enemy=fresh();right(ads);game.request_attack();await step(1.2 if ads else .9)
  check(not game.motion.busy and game.active_magazine().can_fire(),"coarse whole shot completes bolt justlike fine steps ADS=%s busy=%s ready=%s elapsed=%.12f"%[str(ads),str(game.motion.busy),str(game.active_magazine().can_fire()),game.motion.elapsed])
  close(game.active_magazine().rounds,4,"coarse one bullet consumed")
 # Mechanical clock: extraction once, canceled motion must repeat full bolt.
 var mag=load("res://scripts/rifle_cycle.gd").new()
 check(mag.consume() and mag.rounds==4 and not mag.can_fire(),"fired round needsbolt")
 mag.start_bolt();mag.tick_bolt(.3);check(mag.events.count("eject")==1,"one spentcaseextraction")
 mag.cancel_bolt();mag.start_bolt();mag.tick_bolt(.65);check(not mag.can_fire(),"interrupt restarts fullbolt")
 mag.tick_bolt(.01);check(mag.can_fire() and mag.events.count("eject")==1,"ready and no duplicatecase")
 mag.reset();mag.configure_shot(true);mag.consume();mag.sync_bolt(.91);check(not mag.can_fire(),"ADSbolt .92")
 mag.sync_bolt(.92);check(mag.can_fire(),"ADSboltfinishes")
 mag.reset();mag.rounds=0;check(mag.start_reload(),"emptyreload starts");close(mag.reload_duration,2.65,"empty total2.65")
 mag.tick(.649);close(mag.rounds,0,"partialround not granted");mag.tick(.001);close(mag.rounds,1,"first completedround at.65")
 mag.cancel_reload();close(mag.rounds,1,"cancel retainscompletedround");check(mag.needs_bolt,"cancelledopen cannotfire")
 mag.start_reload();mag.tick(2.2);check(mag.rounds==5 and mag.can_fire(),"resume fills remaining4 with openclose")
 mag.reset();mag.rounds=2;mag.start_reload();mag.tick(.65);mag.close_reload();mag.tick(.2)
 check(mag.rounds==3 and mag.can_fire(),"stopreload closes and keeps3")
 mag.reset();mag.configure_shot(true);mag.consume();mag.start_reload();mag.close_reload();mag.tick(.4)
 check(not mag.can_fire(),"reloadabort cannot bypass pendingbolt")
 mag.tick(.52);check(mag.can_fire(),"abort close also satisfies mechanicaldebt")
 mag.reset();mag.rounds=1;mag.start_reload();mag.tick(.65)
 var pose: Dictionary=game.RiflePose.reload_pose(mag,0)
 check(pose.progress>=.14 and pose.pitch>.8,"nextinsert keeps rifle raised without restblend snap")
 game.ui.refresh();check(not ("1/3" in game.ui.stage_text.text),"rifle UI has no meleecombo count")
 # Real dash afterrelease remembersbolt; nextclick cannotfireuntil repeating.
 enemy=fresh();right();game.request_attack();await step(.21)
 check(game.staff_flight.shots_fired==1 and game.active_magazine().needs_bolt,"real fired beforedash")
 check(game.request_dodge(Vector3.LEFT),"dash afterrelease")
 await step(.6);check(game.rifle_aiming(),"held right resumes ADSafterdash")
 var count: int=game.staff_flight.shots_fired
 check(not game.request_attack() and game.active_magazine().bolt_active,"nextclick beginsbolt instead ofshoot")
 await step(.91);close(game.staff_flight.shots_fired,count,"no newshot beforebolt")
 await step(.01);close(game.staff_flight.shots_fired,count,"completion frame cannot reuse bolt time forshot")
 await step(.21);close(game.staff_flight.shots_fired,count+1,"queuedshot begins onlyafterready thenwindup")
 # Spread and sight truly differ, shader defaults stay normal.
 enemy=fresh();close(rad_to_deg(game.ReadyRules.spread("rifle",false)),12,"hip spread12")
 close(rad_to_deg(game.ReadyRules.spread("rifle",true)),.5,"ADSspread.5")
 close(game.vision.reach(),10,"normal sight10");close(rad_to_deg(game.vision.half_angle())*2,120,"normalcone120")
 right();await step(.55);close(game.vision.reach(),14,"ADSsight14");close(rad_to_deg(game.vision.half_angle())*2,32,"ADScone32")
 # Actual reload interrupt queue closes before firing and pays onlyatshot.
 enemy=fresh();game.active_magazine().rounds=1;check(game.request_reload(),"real partialreload starts")
 while game.ui._rifle_gear_turn != null:
  await process_frame
 var small_gear: Control = game.ui.rifle_gear_small
 var large_before_insert: float = gear.rotation
 var small_before_insert: float = small_gear.rotation
 await step(.649);close(game.active_magazine().rounds,1,"real incompleteinsert notgranted")
 close(gear.rotation,large_before_insert,"opening the rifle does not turn the gear before an insert")
 await step(.001);close(game.active_magazine().rounds,2,"real firstinsert complete")
 while game.ui._rifle_gear_turn != null:
  await process_frame
 close(gear.rotation,large_before_insert-TAU/12.0,"large gear reverses one step for the inserted cartridge")
 close(small_gear.rotation,small_before_insert+TAU/10.0,"small gear reverses in the opposite direction")
 if is_instance_valid(strip):
  check(strip.get_child(3).modulate.a==1.0 and strip.get_child(2).modulate.a<1.0,"HUD fills one cartridge at the left end of the live queue")
 check(not game.request_attack(),"click duringreload queues instead ofinstantshot")
 var energy: float=game.stamina
 await step(.19);close(game.staff_flight.shots_fired,0,"wait forclose")
 await step(.01);close(game.staff_flight.shots_fired,0,"close completion nofreewindup")
 await step(.17);close(game.staff_flight.shots_fired,1,"queued shot after properwindup")
 close(game.stamina,energy-10,"queue pays onlyonce")
 enemy=fresh();game.active_magazine().rounds=0;game.request_reload();await step(.65)
 check(game.request_dodge(Vector3.LEFT),"dash duringinsert")
 close(game.active_magazine().rounds,1,"dash keeps exactly completedone")
 check(game.active_magazine().needs_bolt and not game.active_magazine().reloading,"dash leaves openactionunready")
 enemy=fresh();game.active_magazine().rounds=2
 while game.ui._rifle_gear_turn != null:
  await process_frame
 large_before_insert=gear.rotation
 check(game.request_reload(),"three-round reload starts")
 await step(1.6)
 while game.ui._rifle_gear_turn != null:
  await process_frame
 close(game.active_magazine().rounds,5,"three cartridges enter even on a coarse frame")
 close(gear.rotation,large_before_insert-3.0*TAU/12.0,"coarse reload preserves one reverse turn per cartridge")
 # Ordinary shots can catch only one close follower in either aim mode.
 game.clear_actors();var targets: Array=[]
 for x in [2.0,2.6,2.95,5.0]:
  var foe=game.spawn_enemy("dummy",Vector3(x,.03,0));foe.health=1000;foe.max_health=1000;targets.append(foe)
 var flight=load("res://scripts/staff_projectiles.gd").new();root.add_child(flight)
 flight.rifle_hit.connect(func(target,amount,_knock):impacts.append(amount);target.health-=amount)
 for ads in [false,true]:
  flight.clear();impacts.clear();game.motion.configure_rifle(ads)
  var spec: Dictionary=game.motion.definition(0)
  close(spec.projectile_range,12.0 if ads else 9.0,"aim still changes maximum firing range")
  check(flight.spawn_fireball(Vector3(0,.8,0),Vector3.RIGHT,spec,game.camera),"ordinary projectile accepted")
  flight.tick(1,targets,null,Callable(),game.camera)
  check(impacts==[52.0,39.0 if ads else 52.0] and flight.active.is_empty(),"ordinary shot hits only the first two close targets")
  close(targets[2].health,1000,"third body stays untouched even when close enough")
  close(targets[3].health,1000,"separated body stays untouched")
  flight.clear();impacts.clear()
  flight.spawn_fireball(Vector3(0,.8,0),Vector3.RIGHT,spec,game.camera)
  flight.tick(1,[targets[0],targets[3]],null,Callable(),game.camera)
  check(impacts==[52.0],"short exit cannot reach a distant follower")
 flight.queue_free()
 enemy=fresh()
 var line: Array = [enemy]
 for x in [4.25,6.0,7.75,9.5]:
  line.append(game.spawn_enemy("dummy",Vector3(x,.03,0)))
 right(true);await step(.56)
 var mana_before: float=game.mana
 var ordinary_icon: Texture2D=strip.get_child(4).texture
 check(game.request_skill_slot(0),"slot one chambers the piercing cartridge")
 close(game.mana,mana_before-16.0,"chambering pays mana once")
 close(game.active_magazine().rounds,5,"chambering converts a round without firing it")
 check(strip.get_child(4).texture!=ordinary_icon and strip.get_child(3).texture==ordinary_icon,"only the next cartridge changes its icon")
 close(game.sword_skill_cooldowns.get(game.RifleMotion.PIERCING_ROUND_ID,0.0),0.0,"cooldown waits for discharge")
 check(game.staff_flight.shots_fired==0,"arming keeps the shot manual")
 await fire(true)
 close(game.active_magazine().rounds,4,"the shot consumes one actual cartridge")
 check(game.active_magazine().next_round().is_empty() and strip.get_child(4).texture==ordinary_icon,"discharge clears the special round and icon")
 for i in line.size():
  close(line[i].max_health-line[i].health,[57.2,51.48,45.76,40.04,0.0][i],"piercing cartridge uses four-contact falloff")
 check(not game.request_skill_slot(0),"the chamber skill is on cooldown after release")
 enemy=fresh()
 var follower = game.spawn_enemy("dummy", Vector3(3.2, .03, 0))
 var armor_id: String = game.RifleMotion.ARMOR_ROUND_ID
 var catalog = game.sword_skill_ui
 var key := InputEventKey.new()
 key.physical_keycode = KEY_K
 key.pressed = true
 root.push_input(key, true)
 check(game.sword_skills_open and catalog.catalog_rows[armor_id].visible
  and catalog.catalog_rows[game.RifleMotion.PIERCING_ROUND_ID].visible
  and not catalog.catalog_rows["impaling_thrust"].visible, "K displays both rifle skills")
 check(not game.request_skill_slot(1), "opening K prevents chambering")
 for entry in catalog.equip_buttons:
  if entry.id == armor_id and entry.slot == 2: entry.button.pressed.emit()
 root.push_input(key, true)
 var mark_id: String = game.RifleMotion.MARK_ROUND_ID
 check(not game.sword_skills_open and game.loadout.rifle_skill_slots == [game.RifleMotion.PIERCING_ROUND_ID, mark_id, armor_id],
  "K moves armor round to slot three and swaps the mark round into slot two")
 mana_before = game.mana
 check(game.request_skill_slot(2), "the newly assigned slot arms armor round")
 close(game.mana, mana_before - 14.0, "the armor round spends its own mana")
 check(strip.get_child(4).texture != ordinary_icon, "armor cartridge shows on the gear side")
 await fire()
 close(enemy.max_health - enemy.health, 52.0, "armor round deals 52 damage before applying the debuff")
 check(enemy.mace_armor.stacks == 1 and enemy.mace_armor.remaining > 9.0, "armor round applies one timed stack")
 close(follower.health, follower.max_health, "armor round stops at first target")
 check(game.sword_skill_cooldowns.get(armor_id, 0.0) > 4.0, "the armor round starts its own cooldown on fire")
 enemy=fresh()
 var cycle = game.active_magazine()
 cycle.rounds=2
 mana_before=game.mana
 check(not game.request_skill_slot(1) and game.mana==mana_before,"two loaded cartridges cannot prepare three marks")
 cycle.rounds=5
 check(game.request_skill_slot(1) and cycle.round_ids()==[mark_id,mark_id,mark_id,"",""],"preparing mark replaces exactly three rounds")
 close(game.mana,mana_before-24.0,"mark pays mana once for the set")
 check(strip.get_child(2).texture!=ordinary_icon and strip.get_child(3).texture!=ordinary_icon
  and strip.get_child(4).texture!=ordinary_icon and strip.get_child(1).texture==ordinary_icon,"three mark icons match the converted rounds")
 for i in range(3):
  var damage_before: float = game.total_damage
  enemy.advance_armor_status(2.0)
  await fire()
  close(game.total_damage-damage_before,49.4,"each mark cartridge deals its own base damage")
  check(cycle.round_ids().count(mark_id)==2-i and cycle.rounds==4-i,"each release spends one marked cartridge")
  check(enemy.rifle_mark.stacks==1 and enemy.rifle_mark.remaining>4.0,"each mark shot refreshes the timer without stacking")
 check(cycle.next_round().is_empty(),"third release clears the batch")
 check(game.request_skill_slot(0),"piercing can be prepared after the mark batch")
 var followup_damage_before: float = game.total_damage
 await fire()
 close(game.total_damage-followup_damage_before,62.92,"piercing gets the mark bonus on the tagged target")
 check(enemy.rifle_mark.stacks==0,"piercing consumes the mark")
 enemy=fresh()
 cycle=game.active_magazine()
 cycle.rounds=3
 var pierce_id: String = game.RifleMotion.PIERCING_ROUND_ID
 check(game.request_skill_slot(1),"three live rounds become a full mark batch")
 var mark_icon: Texture2D=strip.get_child(4).texture
 await fire()
 check(cycle.round_ids()==[mark_id,mark_id],"the first Mark leaves two Mark rounds")
 check(game.request_skill_slot(0) and cycle.round_ids()==[pierce_id,mark_id],"piercing removes the tail and keeps one Mark")
 check(strip.get_child(4).texture!=mark_icon and strip.get_child(3).texture==mark_icon,"new round is closest to the gear")
 check(game.request_attack(),"queued piercing shot fires")
 await step(.20)
 check(strip.get("_feed")!=null and strip.get("_fired_round")==pierce_id,"firing starts the rightward feed with the actual front round")
 await finish()
 close(game.total_damage,112.32,"interleaved pierce consumes the existing mark")
 check(strip.get_child(4).texture==mark_icon and cycle.round_ids()==[mark_id],"remaining Mark moves into the slot by the gear")
 check(game.request_reload(),"reload accepts a mixed queue")
 await step(.66)
 check(cycle.round_ids()==[mark_id,""],"the first reload insert appends a normal round")
 cycle.reset()
 check(cycle.prepare_round(mark_id,3) and cycle.prepare_round(pierce_id) and cycle.prepare_round(pierce_id),
  "several special rounds can be prepared before shooting")
 check(cycle.round_ids()==[pierce_id,pierce_id,mark_id,mark_id,mark_id],
  "same-kind rounds can coexist and only the tail is replaced")
 enemy=fresh()
 enemy.position.x=1.5
 var far_target = game.spawn_enemy("dummy",Vector3(5.5,.03,0))
 var scatter_id: String = game.RifleMotion.SCATTER_ROUND_ID
 check(catalog.catalog_rows.has(scatter_id) and game.loadout.equip_skill(1,scatter_id),"K can equip the fourth rifle skill")
 mana_before=game.mana
 check(game.request_skill_slot(1),"slot two prepares scatter")
 close(game.mana,mana_before-14.0,"scatter prepares once for 14 mana")
 var before_retreat: Vector3 = game.player.position
 enemy.apply_rifle_mark()
 check(game.request_attack(),"the prepared scatter round fires")
 await step(.15)
 check(game.staff_flight.shots_fired==0 and is_zero_approx(game.rifle_recoil_travelled),"retreat waits for the shot")
 await step(.02)
 check(game.staff_flight.shots_fired==5 and game.active_magazine().rounds==4,"five pellets spend one cartridge")
 check(not game.rewards.invulnerable(),"scatter retreat does not grant dodge invulnerability")
 await finish()
 close(game.rifle_recoil_travelled,game.rewards.DODGE_SPEED*game.DashVisual.DURATION,"retreat covers one unobstructed dash")
 close(before_retreat.x-game.player.position.x,game.rifle_recoil_travelled,"retreat goes opposite the shot")
 close(enemy.max_health-enemy.health,57.2,"all five pellets can hit close and consume one mark for the volley")
 close(far_target.max_health-far_target.health,0.0,"pellets leave a far target untouched")
 check(enemy.rifle_mark.stacks==0,"scatter consumes the mark once")
 var pellet_angles: Array[float] = []
 for record in game.staff_flight.resolved:
  pellet_angles.append(rad_to_deg(atan2(record.direction.z,record.direction.x)))
 pellet_angles.sort()
 check(pellet_angles.size()==5 and absf(pellet_angles[0]+12.0)<.01 and absf(pellet_angles[2])<.01
  and absf(pellet_angles[4]-12.0)<.01,"five separate pellets span a centered 24-degree cone")
 enemy=fresh()
 var wall := StaticBody3D.new()
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size=Vector3(.2,3,4)
 shape.shape=box
 wall.add_child(shape)
 game.add_child(wall)
 wall.position=game.player.position+Vector3(-1,1,0)
 await physics_frame
 check(game.request_skill_slot(1),"scatter can be prepared against cover")
 await fire()
 check(game.rifle_recoil_travelled>0.1 and game.rifle_recoil_travelled<1.0,"cover stops retreat before the wall")
 wall.queue_free()
 await physics_frame
 enemy=fresh()
 var split_id: String = game.RifleMotion.SPLIT_ROUND_ID
 check(catalog.catalog_rows.has(split_id) and game.loadout.equip_skill(1,split_id),"K can equip the split round")
 mana_before=game.mana
 check(game.request_skill_slot(1),"split round prepares through the queue")
 close(game.mana,mana_before-18.0,"split round uses 18 mana")
 await fire()
 close(game.total_damage,52.0,"an enemy before the split only takes the parent round")
 check(game.staff_flight.shots_fired==1 and game.active_magazine().rounds==4,"an early contact spends one cartridge and creates no pellets")
 enemy=fresh()
 enemy.position.x=5.9
 far_target=game.spawn_enemy("dummy",Vector3(8,.03,0))
 var cone_edge = game.spawn_enemy("dummy",Vector3(6.8,.03,.72))
 var outside_cone = game.spawn_enemy("dummy",Vector3(6.8,.03,-1.6))
 check(game.request_skill_slot(1),"split round is ready for the distance check")
 await fire()
 check(game.staff_flight.shots_fired==1 and game.active_magazine().rounds==4,"the cone uses a single round")
 var split_event: Dictionary = game.staff_flight.resolved.front()
 check(split_event.reason=="split","the parent bursts into a cone at range")
 close(split_event.travelled,3.5,"the split happens 3.5 meters from the muzzle")
 close(enemy.max_health-enemy.health,83.2,"the center of the cone takes full damage once")
 close(cone_edge.max_health-cone_edge.health,83.2,"the side of the cone also takes full damage once")
 close(outside_cone.max_health-outside_cone.health,0.0,"a nearby target to the side stays outside the cone")
 close(far_target.max_health-far_target.health,0.0,"the cone has a finite reach")
 enemy=fresh()
 enemy.position.x=5.9
 wall=StaticBody3D.new()
 shape=CollisionShape3D.new()
 shape.shape=box
 wall.add_child(shape)
 game.add_child(wall)
 wall.position=game.player.position+Vector3(4,1,0)
 await physics_frame
 check(game.request_skill_slot(1),"split round prepares for the cover check")
 await fire()
 check(game.staff_flight.resolved.front().reason=="cover" and game.staff_flight.shots_fired==1 and game.total_damage==0.0,
  "a wall stops the parent and prevents the split")
 await physics_frame
 enemy=fresh()
 enemy.position.x=6.9
 wall.position=game.player.position+Vector3(6,1,0)
 await physics_frame
 check(game.request_skill_slot(1),"split round prepares for cover past the burst")
 await fire()
 check(game.staff_flight.resolved.front().reason=="split" and game.total_damage==0.0,"cover after the split shields the target from the cone")
 wall.queue_free()
 await physics_frame
 enemy=fresh()
 var refill_id: String=game.RifleMotion.REFILL_SKILL_ID
 check(catalog.catalog_rows.has(refill_id) and game.loadout.equip_skill(1,refill_id),"K lists and equips quick refill")
 cycle=game.active_magazine()
 cycle.rounds=4
 mana_before=game.mana
 check(not game.request_skill_slot(1) and cycle.rounds==4 and game.mana==mana_before,"one free slot cannot spend mana")
 cycle.rounds=3
 check(cycle.prepare_round(mark_id,2),"setup preserves two special rounds")
 check(game.request_skill_slot(1),"quick refill fills two empty slots")
 check(cycle.round_ids()==[mark_id,mark_id,"","",""],"quick refill adds two normal rounds behind the prepared queue")
 close(game.mana,mana_before-12.0,"quick refill spends 12 mana once")
 close(game.sword_skill_cooldowns.get(refill_id,0.0),8.0,"cooldown starts as soon as ammo is added")
 check(strip.get_child(0).modulate.a==1.0 and strip.get_child(1).modulate.a==1.0,"the HUD shows both normal rounds immediately")
 cycle.rounds=2
 check(not game.request_skill_slot(1) and cycle.rounds==2,"cooldown stops a second refill even when there is room")
 enemy=fresh()
 cycle=game.active_magazine()
 cycle.rounds=0
 check(game.request_reload() and cycle.reloading,"empty rifle starts standard reload")
 check(game.request_skill_slot(1) and cycle.round_ids()==["",""] and cycle.can_fire(),"quick refill supplies two ready rounds while the rifle is empty")
 await step(.65)
 check(cycle.rounds==2 and not cycle.reloading,"the interrupted standard reload adds no extra rounds")
 await fire()
 close(game.total_damage,52.0,"a supplied round fires as normal ammo")
 enemy=fresh()
 var rapid_id: String=game.RifleMotion.RAPID_FIRE_ID
 check(catalog.catalog_rows.has(rapid_id) and game.loadout.equip_skill(1,rapid_id),"K lists and equips rapid fire")
 cycle=game.active_magazine()
 check(cycle.prepare_round(pierce_id),"rapid fire test starts with a queued special round")
 var queue_before_rapid: Array[String]=cycle.round_ids()
 mana_before=game.mana
 check(game.request_skill_slot(1) and cycle.round_ids()==queue_before_rapid,"rapid fire starts without changing the ammo queue")
 close(game.mana,mana_before-24.0,"rapid fire costs 24 mana")
 close(game.rifle_rapid_fire_left(),5.0,"rapid fire starts with five seconds")
 close(game.sword_skill_cooldowns.get(rapid_id,0.0),16.0,"rapid fire cooldown starts on activation")
 check("rapid" in game.ui.status_view.shown_effects,"the timed status icon appears")
 var before_spin: float=gear.rotation
 game.ui._process(.05)
 check(angle_difference(before_spin,gear.rotation)>0.2,"large gear spins forward without a shot")
 check(game.request_attack(),"rapid fire can shoot the queued special round")
 var rapid_spec: Dictionary=game.motion.definition(0)
 close(rapid_spec.windup+rapid_spec.active+rapid_spec.recovery,.4,"rapid cadence is 0.4 seconds")
 await step(.401)
 check(not game.motion.busy and cycle.can_fire() and cycle.rounds==4,"first shot spends one cartridge and can fire again without cycling")
 close(game.total_damage,57.2,"rapid fire respects the queued piercing round")
 check(game.request_attack(),"rapid follow-up can start immediately")
 await step(.401)
 check(cycle.rounds==3 and cycle.can_fire() and game.staff_flight.shots_fired==2,"the next shot keeps the normal ammo rules")
 check(game.request_reload(),"rapid fire permits regular reloading")
 await step(.66)
 check(cycle.rounds==4 and game.ui.get("_rifle_gear_turn")!=null,"a completed reload insert starts a reverse gear step")
 var before_reverse: float=gear.rotation
 await create_timer(.08).timeout
 check(angle_difference(before_reverse,gear.rotation)<0.0,"the gear reverses while inserting")
 var reverse_tween: Tween=game.ui.get("_rifle_gear_turn")
 if reverse_tween != null: await reverse_tween.finished
 before_spin=gear.rotation
 game.ui._process(.05)
 check(angle_difference(before_spin,gear.rotation)>0.2,"the gear resumes rapid spin after a reload step")
 await step(5.01)
 check(game.rifle_rapid_fire_left()==0.0 and not "rapid" in game.ui.status_view.shown_effects,"rapid buff and icon expire")
 check(game.request_attack(),"normal fire resumes once the buff expires")
 check(not game.motion.definition(0).rifle_rapid,"a new shot no longer receives rapid timing")
 await step(.2)
 check(cycle.needs_bolt,"ordinary shots require the bolt again")
 enemy=fresh()
 var finisher_id: String=game.RifleMotion.FINISHER_ID
 check(catalog.catalog_rows.has(finisher_id) and game.loadout.equip_skill(1,finisher_id),"K lists and equips the finisher")
 var finisher_line: Array = [enemy]
 for x in [4.0,5.5,7.0,8.5]: finisher_line.append(game.spawn_enemy("dummy",Vector3(x,.03,0)))
 enemy.apply_rifle_mark()
 cycle=game.active_magazine()
 check(cycle.prepare_round(mark_id,3),"finisher setup starts with a Mark batch")
 mana_before=game.mana
 var before_finisher: Vector3=game.player.position
 var base_camera_size: float=game.camera.size
 game.test_aim=Vector3.FORWARD
 game.move_input=Vector2(1,0)
 check(game.request_skill_slot(1) and game.rifle_display_queue()==[finisher_id,mark_id,mark_id,mark_id,""],"finisher starts charging and shows its reserved slot")
 close(game.mana,mana_before-32.0,"finisher costs 32 mana")
 close(game.sword_skill_cooldowns.get(finisher_id,0.0),20.0,"finisher cooldown starts on activation")
 await step(.45)
 check(game.rifle_scope.visible and game.rifle_scope.guide.visible and game.camera.size<base_camera_size-1.0,"charging enters the black scope with a steering guide")
 check(not game.request_dodge() and not game.request_attack(),"charging locks movement and manual shots")
 close(game.player.position.x,before_finisher.x,"held movement does not move the shooter")
 game.move_input=Vector2.ZERO
 game.test_aim=Vector3.RIGHT
 await step(.54)
 check(game.staff_flight.shots_fired==0 and cycle.rounds==5 and absf(game.motion.aim_angle)<.01,"the aim can turn before automatic release")
 check(game.rifle_scope.guide.width>2.0,"the guide flashes at the end of the charge")
 await step(.02)
 check(game.staff_flight.shots_fired==1 and cycle.round_ids()==[mark_id,mark_id,mark_id,""],"automatic fire spends one cartridge from the queue")
 await finish()
 check(not game.rifle_scope.visible and not game.rifle_scope.guide.visible,"the scope fades after the shot")
 close(game.rifle_recoil_travelled,game.rewards.DODGE_SPEED*game.DashVisual.DURATION*1.5,"finisher recoil travels one and a half dashes")
 for i in finisher_line.size():
  close(finisher_line[i].max_health-finisher_line[i].health,125.84 if i==0 else 114.4,"finisher crosses the full line without falloff")
 enemy=fresh()
 var shielded_target = game.spawn_enemy("dummy",Vector3(6,.03,0))
 wall=StaticBody3D.new()
 shape=CollisionShape3D.new()
 shape.shape=box
 wall.add_child(shape)
 game.add_child(wall)
 wall.position=game.player.position+Vector3(4,1,0)
 await physics_frame
 check(game.request_skill_slot(1),"finisher charges against cover")
 await finish()
 close(game.total_damage,114.4,"finisher damages the target in front of the wall")
 close(shielded_target.max_health-shielded_target.health,0.0,"finisher leaves the target behind the wall untouched")
 check(game.staff_flight.resolved.back().reason=="cover","finisher stops at cover")
 wall.queue_free()
 await physics_frame
 await check_rifle_scaling()
 game.queue_free();await process_frame
 print("RIFLE MARK: ",checks," checks; ","PASS" if fails.is_empty() else "FAIL",fails);quit(0 if fails.is_empty() else 1)

func check_rifle_scaling() -> void:
 fresh()
 var rifle = game.RifleMotion
 var model = game.loadout
 model.defaults()
 var bag_index: int = model.bag.find("rifle0")
 check(model.move_item({"kind":"bag","index":bag_index},{"kind":"slot","set":0,"hand":"main"}),"equip the scaled test rifle")
 game.loadout_edited()
 model.items.rifle0.rifle_stats = {"power":57.0,"handling":.10,"reload":.10,"accuracy":.10}
 game.stats.level = 29
 game.stats.attributes = {"dexterity":8,"intelligence":7}
 var pierce: Dictionary = game.rifle_projectile_profile(rifle.PIERCING_ROUND_ID)
 close(pierce.damage,57.0*1.10*1.054*1.64,"piercing uses weapon power, DEX, INT and eight growth steps")
 close(game.rifle_projectile_profile(rifle.ARMOR_ROUND_ID).damage,57.0*1.04*1.64,"armor round scales its damage")
 close(game.rifle_projectile_profile(rifle.MARK_ROUND_ID).damage,57.0*.95*1.04*1.48,"each mark shot scales")
 var scatter: Dictionary = game.rifle_projectile_profile(rifle.SCATTER_ROUND_ID)
 close(scatter.damage,57.0*.20*1.04*1.48,"each pellet uses its share of the weapon power")
 close(scatter.projectile_speed,24.384,"INT increases scatter pellet speed")
 close(scatter.scatter_angles[4]-scatter.scatter_angles[3],30.0,"the pellet cone gains one degree per growth step")
 var split: Dictionary = game.rifle_projectile_profile(rifle.SPLIT_ROUND_ID)
 close(split.damage,57.0*1.04*1.32,"the split parent uses its own scaling")
 close(split.rifle_split.damage,57.0*1.60*1.068*1.32,"the split cone gets the stronger INT coefficient")
 close(rad_to_deg(split.rifle_split.half_angle)*2,60.0,"split cone gains two degrees per level step")
 close(split.projectile_range,3.5,"the split point stays fixed")
 var finisher: Dictionary = game.rifle_projectile_profile(rifle.FINISHER_ID)
 close(finisher.damage,57.0*2.20*1.064*1.24,"finisher multiplies weapon power by its ratio, stats and level growth")
 close(finisher.projectile_radius,.27,"finisher gains radius per level step")
 close(rifle.skill_cost(rifle.ARMOR_ROUND_ID,game.stats.attributes),12.0,"armor round INT discount")
 close(rifle.skill_cost(rifle.MARK_ROUND_ID,game.stats.attributes),22.0,"Mark INT discount applies to the batch")
 close(rifle.skill_cost(rifle.REFILL_SKILL_ID,{"intelligence":50}),9.6,"INT mana discount caps at twenty percent")
 close(rifle.skill_cooldown(rifle.RAPID_FIRE_ID,29),14.8,"rapid cooldown scales every three levels")
 check(rifle.level_steps(rifle.FINISHER_ID,22)==0 and rifle.level_steps(rifle.FINISHER_ID,23)==1,"the first growth step starts three levels after unlock")
 var cycle = game.active_magazine()
 close(game.reload_rate(cycle),1.0/.855,"DEX and weapon reload speed compose")
 check(game.request_attack(),"the equipped scaled rifle fires a normal shot")
 var spec: Dictionary = game.motion.definition(0)
 close(spec.windup,.16*.855,"DEX and handling shorten the windup")
 close(spec.recovery,.66*.855,"DEX and handling shorten recovery")
 close(cycle.bolt_duration,.66*.855,"the bolt matches the scaled recovery")
 await finish()
 close(game.total_damage,59.28,"normal rounds use equipped weapon power and DEX in combat")
 check(game.request_skill_slot(0),"prepare scaled piercing in combat")
 var total_before: float=game.total_damage
 await fire()
 close(game.total_damage-total_before,pierce.damage,"scaled piercing profile is used by the fired projectile")
 cycle.rounds=2
 check(model.equip_skill(1,rifle.REFILL_SKILL_ID),"equip quick refill for the scaled cost check")
 var mana_before: float=game.mana
 check(game.request_skill_slot(1) and cycle.rounds==4,"scaled quick refill still supplies two rounds")
 close(game.mana,mana_before-10.0,"the runtime charges the scaled mana")
 close(game.sword_skill_cooldowns.get(rifle.REFILL_SKILL_ID,0.0),6.4,"the runtime starts the scaled cooldown")
