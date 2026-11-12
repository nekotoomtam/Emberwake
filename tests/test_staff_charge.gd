extends SceneTree
const ChargedFireArt = preload("res://scripts/staff_charged_fire_art.gd")
const BasicStaffArt = preload("res://scripts/staff_basic_projectile_art.gd")
const IceVolleyArt = preload("res://scripts/staff_ice_volley_art.gd")
const StaffLv10Art = preload("res://scripts/staff_lv10_art.gd")
const StaffLv15Art = preload("res://scripts/staff_lv15_art.gd")
const StaffLv20Art = preload("res://scripts/staff_lv20_art.gd")
var game
var checks:=0
var failures: Array[String]=[]
var total_burn:=.0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func close(a: float,b: float,why: String) -> void:check(absf(a-b)<.001,why+" got="+str(a)+" expected="+str(b))
func step(t: float) -> void:
 await physics_frame;game.tick(t)
func fresh():
 game.start_run(true);game.clear_actors();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.set_weapon_family("staff");game.test_aim=Vector3.RIGHT;game._refresh_aim();game._visual_tick(0)
 var enemy=game.spawn_enemy("dummy",Vector3(3,.03,0));enemy.max_health=1000;enemy.health=1000;return enemy
func load_units(count: int) -> void:
 check(game.begin_staff_load(),"RMB preparation starts")
 await step(count*.45+.000001);game.staff_energy.stop_load()
 close(game.staff_energy.units,count,"prepared requested units")
func finish() -> void:
 for i in range(300):
  if not game.motion.busy and game.staff_flight.active.is_empty():return
  await step(1.0/120)
 check(false,"cast/projectile complete")
func cast(hold: float) -> void:
 check(game.begin_staff_cast(),"LMB begins concentration")
 if hold>0:await step(hold)
 check(game.release_staff_cast(),"LMB release commits")
 await finish()
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var enemy=fresh()
 check(not game.request_staff_basic() and not game.motion.busy,"ordinary fire requires a matching orb")
 check(game.begin_staff_load(),"begin empty fill");await step(.44)
 close(game.staff_energy.units,0,"partial fill doesnot grant ammo");close(game.stamina,100,"partial fill doesnot pay yet")
 await step(.01);close(game.staff_energy.units,1,"first unit at.45");close(game.stamina,86,"14 per prepared unit")
 await step(1.8);close(game.staff_energy.units,5,"five charges fill the reserve");close(game.stamina,30,"five charges cost 70 stamina")
 check(not game.staff_energy.loading,"full stops fill")
 await step(.1);close(game.staff_energy.units,5,"held full cannot overflow")
 check(not game.ui.charge_panel.visible and game.staff_orbs.orbs.size()==5 and game.staff_orbs.orbs.all(func(orb): return orb.visible),"five visible orbs show the reserve")
 var energy: float=game.stamina
 check(game.begin_staff_cast(),"ready cast")
 await step(.20)
 check(game.staff_orbs.gathered.texture==ChargedFireArt.frame(ChargedFireArt.CHARGE,0),"early charge uses the first drawn frame")
 await step(.699);check(not game.staff_energy.cast_ready(),"the fixed cast is not ready before .9")
 check(game.staff_orbs.gathered.texture==ChargedFireArt.frame(ChargedFireArt.CHARGE,3),"the gathered flame advances as charge grows")
 await step(.001);check(game.staff_energy.cast_ready(),"the fixed cast is ready at .9")
 close(game.staff_energy.units,5,"concentration does not consume early");close(game.stamina,energy,"no second stamina charge")
 var fire_mana: float = game.mana
 check(game.release_staff_cast(),"release full")
 close(game.mana,fire_mana-22,"charged fire spends 22 mana")
 close(game.staff_energy.units,2,"full cast spends three and preserves the last two")
 close(game.motion.definition(0).damage,155.25,"three matching fire orbs boost full direct damage")
 check(game.motion.definition(0).ground_fire,"only full marks ground")
 for i in range(40):
  if not game.staff_flight.active.is_empty(): break
  await step(.01)
 var drawn_shot=game.staff_flight.active[0].node
 var shot_ground_y: float=game.staff_flight.active[0].splash_ground_y
 check(drawn_shot.charged_art and drawn_shot.flame.texture==ChargedFireArt.frame(ChargedFireArt.FLIGHT,0),"charged release uses the drawn flight atlas")
 await step(.065)
 check(is_instance_valid(drawn_shot) and drawn_shot.flame.texture==ChargedFireArt.frame(ChargedFireArt.FLIGHT,1),"flight switches the drawn frame while in motion")
 for i in range(70):
  if not game.fx.fire_blasts.is_empty(): break
  await step(.01)
 var drawn_blast=game.fx.fire_blasts[0]
 check(drawn_blast._sprite.texture==ChargedFireArt.frame(ChargedFireArt.IMPACT,0),"ground blast starts with the tight contact frame")
 close(drawn_blast.global_position.y,shot_ground_y+.045,"blast is anchored to ground at the end of the pierce")
 await step(.21)
 check(drawn_blast._sprite.texture==ChargedFireArt.frame(ChargedFireArt.IMPACT,2),"ground blast advances to the wide ring frame")
 await finish();close(game.staff_flight.shots_fired,1,"one release one projectile")
 close(game.total_damage,155.25,"the first direct target takes one hit before the distant fire patch")
 check(game.ground_fire.zones.size()==1,"fullactual projectile creates groundpatch")
 await step(5);check(game.ground_fire.zones.is_empty(),"real patch expires")
 enemy=fresh();await load_units(2);energy=game.stamina
 check(not game.begin_staff_cast() and game.staff_energy.units==2,"the spell requires three orbs")
 enemy=fresh();await load_units(3)
 check(game.begin_staff_cast(),"three orbs can begin the spell")
 await step(.4)
 check(not game.release_staff_cast() and not game.staff_energy.casting and game.staff_energy.units==3,"early release cancels without spending orbs")
 enemy=fresh();await load_units(2)
 var change := InputEventKey.new()
 change.physical_keycode = KEY_R
 change.pressed = true
 root.push_input(change, true)
 check(game.staff_energy.switching and game.staff_energy.element=="fire","R begins the flourish before changing color")
 await step(.12)
 check(game.current_visual_sample().get("staff_switch",false),"the rendered staff uses the swap pose")
 check(not game.cycle_staff_element(),"repeated R is rejected during the cooldown")
 await step(.05)
 check(game.staff_energy.element=="ice","R selects ice for the next stored orb")
 check(not game.cycle_staff_element(),"changing color does not end the cooldown early")
 await step(.24)
 check(not game.staff_energy.switching and game.staff_energy.switch_left==0.0,"swap finishes at the end of the cooldown")
 check(game.begin_staff_load(),"ice orb begins filling")
 await step(.25)
 check(game.staff_energy.load_elapsed>.20 and game.ui.staff_reserve_hud.visible,"the corner HUD can show an incomplete charge")
 await step(.66)
 game.staff_energy.stop_load()
 check(game.staff_energy.slots==["fire","fire","ice","ice",""],"changing element keeps previously stored fire")
 root.push_input(change, true)
 await step(.41)
 check(game.staff_energy.element=="lightning","R selects lightning next")
 check(game.begin_staff_load(),"lightning orb begins filling")
 await step(.46)
 check(game.staff_energy.slots==["fire","fire","ice","ice","lightning"],"the five slots accept mixed elements")
 await cast(.9)
 check(game.staff_energy.slots==["ice","lightning","","",""],"the cast spends the first three mixed orbs")
 close(game.total_damage,141.75,"two fire orbs and one opposing ice orb produce a net five-percent bonus")
 enemy=fresh()
 var side=game.spawn_enemy("dummy",Vector3(4.5,.03,1.75))
 game.staff_energy.slots.assign(["fire","ice","lightning","fire",""])
 check(game.begin_staff_cast(),"a mixed cast starts")
 await step(.91)
 check(game.staff_energy.casting_slots()==[0,1,2] and game.release_staff_cast(),"the cast reserves and spends the left three")
 var powered: Dictionary=game.motion.definition(0)
 close(powered.splash_radius,2.02,"the neutral lightning orb widens the blast by one percent")
 await finish()
 close(enemy.max_health-enemy.health,135,"matching fire and opposing ice cancel on the direct hit")
 close(side.max_health-side.health,65,"matching fire and opposing ice cancel on the blast")
 check(game.staff_energy.slots==["fire","","","",""],"the fourth orb stays behind the spent prefix")
 enemy=fresh()
 game.staff_energy.slots.assign(["fire","ice","lightning","",""])
 var click := InputEventMouseButton.new()
 click.button_index = MOUSE_BUTTON_LEFT
 click.pressed = true
 for element in ["fire", "ice", "lightning"]:
  var before: int = game.staff_energy.units
  root.push_input(click, true)
  check(game.motion.busy and not game.staff_energy.casting,"ordinary click starts immediately at " + element)
  check(game.staff_energy.units==before-1 and not game.staff_energy.slots.has(element),"ordinary click spends one matching " + element)
  for i in range(40):
   if not game.staff_flight.active.is_empty(): break
   await step(.01)
  var projectile=game.staff_flight.active[0].node
  check(projectile.flame.texture==BasicStaffArt.frame(element,0),"ordinary projectile shows the matching first frame for " + element)
  await step(.065)
  check(is_instance_valid(projectile) and projectile.flame.texture==BasicStaffArt.frame(element,1),"ordinary projectile animates while flying for " + element)
  await finish()
  check(game.staff_flight.resolved.back().element==element,"the launched projectile keeps its " + element + " damage type")
  root.push_input(change, true)
  await step(.41)
 close(game.total_damage,126,"the three elemental ordinary shots each deal 42")
 enemy=fresh()
 game.staff_energy.slots.assign(["fire","ice","lightning","fire",""])
 root.push_input(change, true)
 await step(.41)
 root.push_input(click, true)
 check(game.staff_energy.slots==["fire","lightning","fire","",""],"taking the middle orb preserves survivor order and closes the gap")
 var travelling: Array = game.ui.staff_reserve_hud.get("_travelling")
 check(travelling.any(func(orb): return orb.slot==1 and orb.element=="lightning")
  and travelling.any(func(orb): return orb.slot<0 and orb.element=="ice"),
  "the HUD animates both the spent orb and the shift into its slot")
 await finish()
 check(game.begin_staff_load(),"the staff can charge again after spending a middle orb")
 await step(.46)
 game.staff_energy.stop_load()
 check(game.staff_energy.slots==["fire","lightning","fire","ice",""],"the next charged orb joins the tail")
 enemy=fresh()
 game.staff_energy.slots.assign(["fire","ice","fire","",""])
 root.push_input(change, true)
 await step(.41)
 root.push_input(change, true)
 await step(.41)
 root.push_input(click, true)
 check(not game.motion.busy and game.staff_energy.units==3,"an empty selected element does not spend the other colors")
 var skill := InputEventKey.new()
 skill.physical_keycode = KEY_1
 skill.pressed = true
 root.push_input(skill, true)
 check(game.staff_energy.casting,"slot one starts the charged fire spell")
 await step(.9)
 check(game.staff_energy.casting_slots()==[0,1,2],"the current charge highlights the first three slots")
 skill.pressed = false
 root.push_input(skill, true)
 await finish()
 check(game.staff_flight.resolved.back().element=="fire" and game.staff_energy.units==0,"slot release uses the first three orbs regardless of color")
 enemy=fresh();game.stamina=13;check(game.begin_staff_load(),"attemptlowenergy");await step(.46)
 close(game.staff_energy.units,0,"no ammo withoutenergy");close(game.stamina,13,"no negative energy")
 enemy=fresh();game.stats.flat.attack_speed=1;game.begin_staff_load();await step(.225001);game.staff_energy.stop_load();close(game.staff_energy.units,1,"attack_speed scalesbasefill")
 check(not game.begin_staff_cast(),"one orb cannot begin a cast even with increased speed")
 enemy=fresh();await load_units(3);check(game.begin_staff_cast(),"cancelchargefixture");await step(.5)
 check(game.request_dodge(Vector3.LEFT),"dash overrides castchannel");close(game.staff_energy.units,3,"uncommitted concentration retainsammo");check(not game.staff_energy.casting,"dash cancelschannel")
 await step(.6);check(not game.motion.busy and game.staff_flight.shots_fired==0,"cancel emitsnothing")
 game.stamina=100;game.begin_staff_cast();await step(.91);game.release_staff_cast();check(game.request_dodge(Vector3.LEFT),"dash overrides committedwindup")
 close(game.staff_energy.units,0,"committed ammo notrefunded");await step(.6);close(game.staff_flight.shots_fired,0,"windup cancel no lateprojectile")
 enemy=fresh();await load_units(1);game.request_staff_basic();await step(.29)
 check(game.staff_flight.shots_fired==1,"projectile released beforedash");check(game.request_dodge(Vector3.LEFT),"dash afterrelease");await finish();close(game.staff_flight.shots_fired,1,"releasedprojectile survivesdash")
 enemy=fresh();await load_units(3);game.begin_staff_cast();game.toggle_pause();await step(1)
 check(not game.staff_energy.casting and game.staff_energy.units==3,"pause cancelschannel keepsammo");game.toggle_pause()
 game.begin_staff_load();await step(.1);game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
 check(not game.staff_energy.loading and game.staff_energy.units==3,"focus cancelsfraction not completedammo")
 # Independent model binding simulates different item IDs without transferring ammo.
 var model=game.staff_energy;model.bind("staffA");model.units=2;model.bind("staffB");close(model.units,0,"otherstaff starts empty");model.units=1;model.bind("staffA");close(model.units,2,"perstaff pool survives swapping")
 # Standalone ground manager deterministic pulse, overlap and no reaction.
 var field=load("res://scripts/ground_fire.gd").new();root.add_child(field)
 field.damage_hit.connect(func(target,amount):total_burn+=amount;target.receive_burn(amount))
 enemy=fresh();enemy.health=1000;enemy.state="windup";enemy.attack_data=enemy.Attacks.definition("melee",0);enemy.telegraph_left=.4
 field.spawn_patch(enemy.position);field.spawn_patch(enemy.position)
 field.tick(.499,[enemy,enemy]);close(total_burn,0,"burn waits.5")
 field.tick(.001,[enemy,enemy]);close(total_burn,2,"overlap/doublearray burns once")
 check(enemy.state=="windup" and enemy.stagger==0,"burn doesnotinterruptattack")
 field.tick(4.5,[enemy]);close(total_burn,20,"10ticks in5s includingexpiry endpoint");check(field.zones.is_empty(),"expiredfields removed")
 close(enemy.health,980,"twopatches not40damage")
 field.tick(10,[enemy]);close(total_burn,20,"no damage afterexpiry")
 field.spawn_patch(Vector3(9,0,9));field.tick(.5,[enemy]);close(total_burn,20,"outsidecircle no damage")
 field.clear();total_burn=0;enemy.position=Vector3(4,.03,0)
 var wall:=StaticBody3D.new();wall.collision_layer=1
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,2,2);shape.shape=box;wall.add_child(shape);wall.position=Vector3(3.5,1,0);root.add_child(wall)
 await physics_frame;await physics_frame
 field.spawn_patch(Vector3(3,.03,0));field.tick(.5,[enemy],game.player.get_world_3d());close(total_burn,0,"cover blocks groundburn through wall")
 wall.queue_free();await physics_frame;await physics_frame
 field.tick(.5,[enemy],game.player.get_world_3d());close(total_burn,2,"uncovered target insidepatch burns")
 field.clear();field.spawn_patch(enemy.position);enemy.health=1;field.tick(.5,[enemy]);check(enemy.dead,"burn cankill")
 field.clear();check(field.zones.is_empty(),"resetclearsfire")
 field.queue_free()
 enemy=fresh()
 enemy.position=Vector3(1.0,.03,0)
 game.staff_energy.slots.assign(["ice","fire","lightning","",""])
 game.mana=25
 check(not game.request_skill_slot(1),"ice volley requires 26 mana")
 game.mana=game.stats.value("max_mana")
 check(game.request_skill_slot(1),"slot two begins the ice volley")
 check(game.staff_energy.casting_slots()==[0,1],"ice volley selects the left two orbs")
 await step(.649)
 var ice_mana: float = game.mana
 game.release_charged_skill_slot(1)
 close(game.mana,ice_mana,"early ice release keeps mana")
 close(game.staff_energy.units,3,"early ice release keeps all three orbs")
 check(game.request_skill_slot(1),"ice volley can retry after early release")
 await step(.65)
 check(game.staff_orbs.gathered.texture==IceVolleyArt.frame(IceVolleyArt.CHARGE,3),"ice volley shows its own full charge art")
 ice_mana=game.mana
 game.release_charged_skill_slot(1)
 close(game.mana,ice_mana-26,"ice volley pays once at release")
 check(game.staff_energy.slots==["lightning","","","",""],"ice volley spends two and compacts")
 close(game.motion.definition(0).damage,25.2,"matching ice boosts each projectile")
 close(game.motion.definition(0).projectile_radius,.2121,"neutral fire increases projectile radius")
 for i in range(40):
  if game.staff_flight.shots_fired==3: break
  await step(.01)
 var ice_contacts: Array=game.fx.particles.filter(func(entry): return entry.get("spell_art")==IceVolleyArt)
 check(ice_contacts.size()==3,"each ice pellet creates a sprite at contact")
 if not ice_contacts.is_empty():
  var ice_contact: Sprite3D=ice_contacts[0].node
  check(ice_contact.texture==IceVolleyArt.frame(IceVolleyArt.IMPACT,0),"ice impact begins with a flash")
  await step(.065)
  check(ice_contact.texture==IceVolleyArt.frame(IceVolleyArt.IMPACT,1),"ice impact advances to shattering fragments")
 await finish()
 close(game.staff_flight.shots_fired,3,"ice volley launches exactly three projectiles")
 close(enemy.health,924.4,"all three projectiles can hit a close target")
 close(enemy.movement_speed_scale(),.7,"three ice hits stack to 30 percent")
 enemy.advance_combat_status(4.0)
 enemy.apply_ice_slow()
 close(enemy.movement_speed_scale(),.7,"repeat ice hit is capped")
 close(enemy.ice_slow_remaining,5,"repeat ice hit refreshes the timer")
 enemy.apply_movement_slow(.2,8)
 enemy.advance_combat_status(5.0)
 close(enemy.movement_speed_scale(),.8,"ice expires and an independent slow remains")
 enemy=fresh()
 var staff = game.StaffMotion
 enemy.position=Vector3(2.8,.03,0)
 var near=game.spawn_enemy("dummy",Vector3(3.5,.03,1.1))
 var far=game.spawn_enemy("dummy",Vector3(5.6,.03,1.5))
 var spare=game.spawn_enemy("dummy",Vector3(7.7,.03,1.5))
 for dummy in [near,far,spare]:
  dummy.max_health=1000
  dummy.health=1000
 game.staff_energy.slots.assign(["lightning","fire","ice","fire",""])
 check(game.request_skill_slot(2),"slot three starts chain lightning")
 await step(.75)
 check(game.staff_orbs.gathered.texture==StaffLv10Art.frame(StaffLv10Art.CHARGE,3),"chain lightning uses its drawn charge frame")
 var chain_mana: float=game.mana
 game.release_charged_skill_slot(2)
 close(game.mana,chain_mana-32,"chain lightning spends 32 mana")
 close(game.motion.definition(0).chain_radius,3.03,"ice extends the chain jump")
 for i in range(40):
  if not game.staff_flight.active.is_empty(): break
  await step(.01)
 check(game.staff_flight.active[0].node.flame.texture==StaffLv10Art.frame(StaffLv10Art.FLIGHT,0),"chain lightning uses its drawn projectile")
 await finish()
 close(enemy.health,940,"primary lightning target takes 60")
 close(near.health,955,"nearest target takes the first jump")
 close(far.health,966,"second jump reaches the next unique target")
 close(spare.health,1000,"the chain stops after two jumps")

 enemy=fresh()
 enemy.position=Vector3(2,.03,0)
 near=game.spawn_enemy("dummy",Vector3(2,.03,1.4))
 far=game.spawn_enemy("dummy",Vector3(3.5,.03,0))
 spare=game.spawn_enemy("dummy",Vector3(2.4,.03,.5))
 spare.health=1000
 spare.max_health=1000
 var near_health: float=near.health
 var far_health: float=far.health
 check(game.loadout.equip_skill(1,staff.FIRE_BREATH_ID),"fire breath can be equipped")
 game.staff_energy.slots.assign(["fire","ice","lightning","lightning","fire"])
 var breath_mana: float=game.mana
 var breath_key:=InputEventKey.new()
 breath_key.physical_keycode=KEY_2
 breath_key.pressed=true
 game._unhandled_input(breath_key)
 breath_key.pressed=false
 game._input(breath_key)
 check(game._staff_breath_slot==1 and game._staff_breath_ticks==0,"skill key arms breath without firing")
 close(game.mana,breath_mana,"arming does not pay mana")
 close(game.staff_energy.units,5,"arming does not consume orbs")
 var breath_click:=InputEventMouseButton.new()
 breath_click.button_index=MOUSE_BUTTON_LEFT
 breath_click.pressed=true
 game._unhandled_input(breath_click)
 close(game.mana,breath_mana-34,"left mouse pays 34 mana at onset")
 check(game.staff_energy.slots==["fire","","","",""],"breath spends four and preserves the tail")
 await step(.07)
 var breath_sprite: Sprite3D=game.fx._staff_breath_sprite
 check(is_instance_valid(breath_sprite) and breath_sprite.visible and breath_sprite.texture==StaffLv10Art.breath_frame(1),"fire breath draws and animates its flame sprite")
 await step(.18)
 close(enemy.health,970,"one quarter second applies one fire tick")
 breath_click.pressed=false
 game._input(breath_click)
 check(not breath_sprite.visible,"fire sprite hides immediately on left release")
 var damage_on_release: float=game.total_damage
 await step(.5)
 close(game.total_damage,damage_on_release,"mouse release stops damage immediately")
 check(game._staff_breath_slot<0,"mouse release returns to ordinary actions")
 game.staff_energy.slots.assign(["fire","ice","lightning","lightning","fire"])
 check(game.request_skill_slot(1) and game._start_staff_breath(),"breath can be started again")
 await step(1.5)
 close(enemy.health,820,"a full channel deals exactly six fire ticks")
 close(spare.health,820,"breath can hit two targets in the cone")
 close(near.health,near_health,"target outside the cone is safe")
 close(far.health,far_health,"target beyond the cone is safe")
 check(game._staff_breath_slot<0 and game.staff_flight.shots_fired==0,"full channel ends without auto-firing")
 enemy=fresh()
 game.test_aim=Vector3.ZERO
 var center:=Vector3(3,.03,0)
 game._mouse_position=game.camera.unproject_position(center)
 near=game.spawn_enemy("dummy",Vector3(3,.03,4.0))
 near.health=1000
 near.max_health=1000
 far=game.spawn_enemy("dummy",Vector3(7,.03,0))
 far.health=1000
 far.max_health=1000
 check(game.loadout.equip_skill(1,staff.ICE_CRYSTAL_ID),"ice crystals can be equipped")
 game.staff_energy.slots.assign(["ice","ice","lightning","fire","fire"])
 check(game.request_skill_slot(1),"crystal cast begins")
 await step(.65)
 game._mouse_position=game.camera.unproject_position(center)
 game._update_staff_ground_preview()
 var preview: MeshInstance3D=game._staff_ground._preview
 check(is_instance_valid(preview) and preview.visible,"crystal shows a ground preview during charge")
 close(preview.global_position.x,3,"preview follows the mouse on the ground")
 close(preview.scale.x,3.232,"fire widens the crystal preview")
 var crystal_mana: float=game.mana
 game.release_charged_skill_slot(1)
 close(game.mana,crystal_mana-38,"ice crystals pay 38 mana")
 close(game.staff_energy.units,1,"ice crystals spend four orbs")
 await step(.99)
 close(enemy.health,1000,"ice crystals wait before triggering")
 near.position=Vector3(3,.03,2)
 await step(.01)
 close(enemy.health,900.25,"ice crystals deal scaled damage once")
 close(near.health,900.25,"enemy entering before eruption takes damage")
 close(far.health,1000,"enemy outside eruption radius takes no damage")
 close(enemy.movement_speed_scale(),0,"ice crystals root a survivor")
 var erupting: Array=game.fx.particles.filter(func(entry): return entry.get("spell_art")==StaffLv15Art)
 check(erupting.size()==1,"ice field plays one drawn eruption at detonation")
 if not erupting.is_empty():
  var ice_sprite: Sprite3D=erupting[0].node
  check(ice_sprite.texture==StaffLv15Art.frame(StaffLv15Art.IMPACT,0),"ice field begins with low crystals")
  game.fx.tick(.25)
  check(ice_sprite.texture==StaffLv15Art.frame(StaffLv15Art.IMPACT,2),"ice field advances to the tall crystals")
 check(game.status_icons.icons_for(enemy).any(func(icon): return icon[0]=="root"),"root shows its status icon")
 await step(.75)
 close(enemy.movement_speed_scale(),1,"root expires after .75 seconds")

 enemy=fresh()
 game.test_aim=Vector3.ZERO
 game._mouse_position=game.camera.unproject_position(center)
 check(game.loadout.equip_skill(2,staff.MANA_FIELD_ID),"mana field can be equipped")
 game.staff_energy.slots.assign(["lightning","lightning","ice","fire","ice"])
 check(game.request_skill_slot(2),"mana field cast begins")
 await step(.65)
 game._mouse_position=game.camera.unproject_position(center)
 var field_mana: float=game.mana
 game.release_charged_skill_slot(2)
 close(game.mana,field_mana-36,"mana field pays 36 mana")
 check(game.staff_energy.slots==["fire","ice","","",""],"mana field spends the first three orbs")
 close(game._staff_ground.time_to_boundary(),14,"two lightning orbs add two seconds")
 close(game._staff_ground._mana_field.radius,4.725,"ice orb expands the field")
 var mana_ring: Sprite3D=game._staff_ground._mana_field.ring
 check(mana_ring.texture==StaffLv15Art.ring_frame(0),"mana field starts with the drawn ground ring")
 game._staff_ground.advance(.13,game.camera)
 check(mana_ring.texture==StaffLv15Art.ring_frame(1),"mana field lightning travels around the ring")
 close(mana_ring.pixel_size*StaffLv15Art.RING_DIAMETER,9.45,"ring scales to the real mana field diameter")
 game.player.position=Vector3(-4,.03,0)
 game.enemy_hit(enemy,2000,Vector3.ZERO)
 close(game.mana,field_mana-28,"player kill inside field refunds eight mana from outside it")
 game.enemy_hit(enemy,2000,Vector3.ZERO)
 close(game.mana,field_mana-28,"same dead target cannot refund twice")
 var ally_target=game.spawn_enemy("dummy",Vector3(3,.03,1))
 game._companion_projectile_damage(ally_target,1000,Vector3.ZERO,"fire",false)
 check(ally_target.dead,"companion projectile still deals damage")
 close(game.mana,field_mana-28,"companion kill does not refund player mana")
 var outside=game.spawn_enemy("dummy",Vector3(8,.03,0))
 game.enemy_hit(outside,1000,Vector3.ZERO)
 close(game.mana,field_mana-28,"kill outside the field grants no mana")
 var fire_orbs: Array[String]=["fire","fire","fire"]
 check(staff.ground_spell(staff.MANA_FIELD_ID,fire_orbs).duration==9,"three fire orbs remove three seconds")
 game._staff_ground.advance(14.0)
 check(not mana_ring.visible,"expired mana field removes the visible ring")
 var expired=game.spawn_enemy("dummy",Vector3(3,.03,0))
 game.enemy_hit(expired,1000,Vector3.ZERO)
 close(game.mana,field_mana-28,"expired field grants no mana")
 enemy=fresh()
 check(game.loadout.equip_skill(0,staff.FOCUS_ID),"staff focus can be equipped")
 game.loadout.equip_skill(1,staff.FIRE_BREATH_ID)
 game.loadout.equip_skill(2,staff.CHAIN_LIGHTNING_ID)
 game.staff_energy.slots.assign(["fire","ice","lightning","",""])
 var focus_mana: float=game.mana
 check(game.request_skill_slot(0),"staff focus activates immediately")
 close(game.mana,focus_mana-40,"staff focus pays full activation cost")
 close(game.staff_energy.focus_left,10,"staff focus lasts ten seconds")
 close(game.sword_skill_cooldowns[staff.FOCUS_ID],25,"cooldown starts at activation")
 check(game.staff_energy.slots==["neutral","neutral","fire","ice","lightning"],"focus inserts two black orbs at the front")
 check(not game.request_skill_slot(0),"focus cannot be restarted during cooldown")
 game._visual_tick(0)
 check(game.staff_orbs.focus_orb.visible,"focus displays an orbiting black orb")
 check(game.staff_orbs.orbs[0].texture==game.staff_orbs.focus_orb.texture,"neutral reserve orb uses the drawn black art")
 check(game.fx.particles.any(func(entry): return entry.get("art_row")==StaffLv20Art.FOCUS_FLASH),"focus shows a drawn activation flash")
 game.staff_energy.slots.assign(["neutral","neutral","neutral","",""])
 check(game.request_skill_slot(2),"focus permits chain lightning with black orbs")
 await step(.74)
 var discounted_mana: float=game.mana
 game.release_charged_skill_slot(2)
 close(game.mana,discounted_mana,"early release has no payment or refund")
 check(game.staff_energy.units==3,"early release leaves the original reserve")
 check(game.request_skill_slot(2),"chain lightning can retry")
 await step(.75)
 discounted_mana=game.mana
 game.release_charged_skill_slot(2)
 close(game.mana,discounted_mana-16,"chain lightning costs half mana during focus")
 check(game.staff_energy.slots==["neutral","","","",""],"chain lightning spends three and returns one")
 close(game.motion.definition(0).damage,69,"black orbs grant full matching lightning bonus")
 close(game.motion.definition(0).chain_radius,3,"black orbs do not count toward neutral area bonuses")
 await finish()
 game.staff_energy.slots.assign(["neutral","neutral","neutral","neutral","ice"])
 check(game.request_skill_slot(1),"focus permits fire breath")
 discounted_mana=game.mana
 check(game._start_staff_breath(),"fire breath commits under focus")
 close(game.mana,discounted_mana-17,"breath costs half mana")
 close(game._staff_breath_bonus.x,1.2,"black orbs match fire for breath")
 check(game.staff_energy.slots==["ice","neutral","neutral","",""],"four-orb cast returns two black orbs")
 game._stop_staff_breath()
 var remaining_focus: float=game.staff_energy.focus_left
 await step(remaining_focus+.01)
 close(game.staff_energy.focus_left,0,"focus expires at ten seconds")
 close(game.staff_skill_cost(staff.CHAIN_LIGHTNING_ID),32,"mana returns to normal after focus")
 check(game.staff_energy.slots==["ice","neutral","neutral","",""],"unused black orbs remain after expiration")
 check(not game.staff_orbs.focus_orb.visible,"separate orbit effect ends with focus")
 var black_orbs: Array[String]=["neutral","neutral","neutral"]
 close(staff.ground_spell(staff.MANA_FIELD_ID,black_orbs).duration,15,"black orbs match lightning for field duration")
 enemy=fresh()
 game.staff_energy.slots.assign(["ice","fire","lightning","fire",""])
 check(game.request_skill_slot(0),"focus can activate when reserve has one slot left")
 check(game.staff_energy.slots==["neutral","neutral","ice","fire","lightning"],"focus ejects only one orb when one slot was free")
 enemy=fresh()
 game.staff_energy.slots.assign(["lightning","ice","fire","ice","fire"])
 check(game.request_skill_slot(0),"focus can activate with a full reserve")
 check(game.staff_energy.slots==["neutral","neutral","lightning","ice","fire"],"focus drops the last two orbs and preserves the first three")
 check(game.request_skill_slot(2),"the next cast can use the newly inserted orbs")
 check(game.staff_energy.casting_elements()==["neutral","neutral","lightning"],"the next cast prioritizes both black orbs")
 enemy=fresh()
 check(game.loadout.equip_skill(2,staff.METEOR_ID),"meteor can be equipped")
 game.test_aim=Vector3.ZERO
 near=game.spawn_enemy("dummy",Vector3(3,.03,3.72))
 far=game.spawn_enemy("dummy",Vector3(7,.03,0))
 spare=game.spawn_enemy("dummy",Vector3(3,.03,-4.2))
 var third_spark=game.spawn_enemy("dummy",Vector3(7,.03,2.7))
 for dummy in [near,far,spare,third_spark]:
  dummy.max_health=1000
  dummy.health=1000
 game.staff_energy.slots.assign(["neutral","fire","ice","lightning","lightning"])
 game._mouse_position=game.camera.unproject_position(center)
 check(game.request_skill_slot(2),"five orbs begin the meteor")
 await step(.85)
 game._mouse_position=game.camera.unproject_position(center)
 var meteor_mana: float=game.mana
 game.release_charged_skill_slot(2)
 close(game.mana,meteor_mana-48,"meteor spends 48 mana")
 close(game.staff_energy.units,0,"meteor spends all five orbs")
 var meteor_field: Dictionary=game._staff_ground._delayed_fields[0]
 close(meteor_field.radius,3.78,"ice widens the actual meteor radius")
 var falling: Node3D=meteor_field.meteor
 var start_height:=falling.position.y
 check(falling.texture==StaffLv20Art.frame(StaffLv20Art.FLIGHT,0),"meteor starts with its molten sprite")
 await step(.79)
 check(falling.position.y<start_height,"meteor moves down toward the warning circle")
 close(enemy.health,1000,"meteor does not damage during the warning")
 await step(.01)
 check(game.fx.particles.any(func(entry): return entry.get("spell_art")==StaffLv20Art and entry.art_row==StaffLv20Art.IMPACT),"meteor impact shows the drawn shockwave")
 close(enemy.health,802,"fire and a black orb each add five percent impact damage")
 close(near.health,802,"the added radius reaches the inner edge")
 close(far.health,968,"first edge target receives one spark")
 close(spare.health,968,"second lightning orb hits a different edge target")
 close(third_spark.health,1000,"meteor only emits the number of sparks supplied")
 close(enemy.ice_root_remaining,0,"meteor impact does not apply ice-crystal root")
 enemy=fresh()
 game.staff_energy.slots.assign(["fire","fire","lightning","ice","ice"])
 check(game.request_skill_slot(0) and game.request_skill_slot(2),"focus can lead into meteor")
 await step(.85)
 meteor_mana=game.mana
 game.release_charged_skill_slot(2)
 close(game.mana,meteor_mana-24,"meteor costs half under focus")
 check(game.staff_energy.slots==["neutral","neutral","","",""],"five-orb meteor returns two under focus")
 for id in [staff.CHARGED_FIRE_ID,staff.ICE_VOLLEY_ID,staff.CHAIN_LIGHTNING_ID,staff.FIRE_BREATH_ID,staff.ICE_CRYSTAL_ID,staff.METEOR_ID]:
  var unlock: int=staff.SKILLS[id].level
  close(staff.scaling(id,42,3,unlock+2).x,1,"damage stays at base before the next rank")
  close(staff.scaling(id,42,13,unlock+3).x,1.188,"INT and the first damage rank multiply")
 close(staff.scaling("",46,3,30).x,46.0/42.0,"weapon power scales basic damage without skill rank")
 close(staff.charge_speed(100),1.2,"INT charge speed bonus caps at 20 percent")
 close(staff.focus_cooldown(50),20,"focus cooldown caps at 20 seconds")
 close(staff.mana_refund(50),12,"mana field refund caps at 12")
 enemy=fresh()
 game.stats.level=23
 game.stats.attributes={"intelligence":13}
 game.staff_energy.slots.assign(["lightning","lightning","lightning","lightning","lightning"])
 check(game.request_skill_slot(2),"Lv23 meteor starts with INT scaling")
 close(game.staff_energy.cast_time,.85/1.1,"INT changes actual meteor charging time")
 await step(.78)
 var scaled_mana: float=game.mana
 game.release_charged_skill_slot(2)
 close(game.mana,scaled_mana-48,"staff scaling leaves the base mana cost unchanged")
 var scaled_meteor: Dictionary=game._staff_ground._delayed_fields[0]
 close(scaled_meteor.damage,213.84,"Lv23 INT13 meteor has 213.84 base damage")
 close(scaled_meteor.spark_damage,38.016,"meteor sparks receive the same damage scaling")
 close(scaled_meteor.radius,3.672,"meteor radius grows by two percent on first rank")
 enemy=fresh()
 game.stats.level=23
 game.stats.attributes={"intelligence":13}
 game.loadout.equip_skill(2,staff.MANA_FIELD_ID)
 game.staff_energy.slots.assign(["lightning","lightning","lightning","",""])
 game.test_aim=Vector3.ZERO
 game._mouse_position=game.camera.unproject_position(center)
 check(game.request_skill_slot(2),"Lv23 mana field starts")
 await step(.60)
 game._mouse_position=game.camera.unproject_position(center)
 game.release_charged_skill_slot(2)
 var scaled_field: Dictionary=game._staff_ground._mana_field
 close(scaled_field.radius,4.68,"mana field radius grows two percent per rank")
 scaled_mana=game.mana
 game.enemy_hit(enemy,2000,Vector3.ZERO)
 close(game.mana,scaled_mana+10,"Lv23 mana field refunds ten mana per qualifying kill")
 check(game.request_skill_slot(0),"Lv23 focus starts after placing the mana field")
 close(game.sword_skill_cooldowns[staff.FOCUS_ID],24,"Lv23 focus uses its scaled cooldown")
 close(game.staff_energy.focus_left,10,"focus duration stays ten seconds")
 game.queue_free();await process_frame
 print("STAFF CHARGE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
