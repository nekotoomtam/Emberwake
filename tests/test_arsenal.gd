extends SceneTree
const Model = preload("res://scripts/loadout_inventory.gd")
var failures: Array[String] = []
var checks := 0
var game
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures.append(why);printerr("FAIL: ",why)
func _initialize() -> void: call_deferred("run")
func loc(index: int) -> Dictionary: return {"kind":"bag","index":index}
func hand(index: int, key: String) -> Dictionary: return {"kind":"slot","set":index,"hand":key}
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;root.push_input(event,true)
func tick(seconds: float) -> void:
	for i in range(int(ceil(seconds*120))):
		await physics_frame
		game.tick(1.0/120)
func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new();motion.position=position;root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=down;root.push_input(event,true)
	await process_frame
func run() -> void:
	var m = Model.new();m.save_path=""
	check(m.valid_state() and m.items.size()==18,"initial item conservation")
	check(m.for_pair()==["sword0","pistol0"],"each click plans main then off")
	var old: Array = m.sets.duplicate(true)
	check(not m.move_item(loc(m.bag.find("rifle0")),hand(0,"off")) and m.sets==old and m.valid_state(),"reject two-hand offhand without losing anything")
	check(m.move_item(loc(m.bag.find("rifle0")),hand(0,"main")),"equip two-handed rifle")
	check(m.sets[0].off=="" and "pistol0" in m.bag and "sword0" in m.bag and m.valid_state(),"two-hand returns previous main and offhand safely")
	check(not m.move_item(loc(m.bag.find("mace0")),hand(0,"off")) and m.valid_state(),"reserved off slot refuses item")
	check(m.unequip(hand(0,"main")) and m.primary(0)=="" and m.valid_state(),"empty set legal")
	check(m.move_item(loc(m.bag.find("pistol0")),hand(0,"main")) and m.move_item(loc(m.bag.find("pistol1")),hand(0,"off")),"identical weapons use two distinct items")
	check(m.for_pair()==["pistol0","pistol1"] and m.valid_state(),"same family still routes individual IDs")
	m.save_path="user://arsenal-test-v24.json";check(m.save_data(),"save loadout")
	var copy = Model.new();copy.save_path=m.save_path
	check(copy.load_data() and copy.bag==m.bag and copy.sets==m.sets,"load equipment and bag")
	var legacy_bag: Array = m.bag.duplicate()
	for id in ["bow0", "bow1", "crossbow0", "crossbow1", "shield0", "shield1"]:
		legacy_bag[legacy_bag.find(id)] = ""
	var legacy_file := FileAccess.open(m.save_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"version": 1, "bag": legacy_bag, "sets": m.sets, "active": m.active}))
	legacy_file.close()
	check(copy.load_data() and copy.sets == m.sets and copy.active == m.active
		and "bow0" in copy.bag and "bow1" in copy.bag and "crossbow0" in copy.bag and "crossbow1" in copy.bag and "shield0" in copy.bag and "shield1" in copy.bag, "v1 retains both sets and gains the new weapons")
	var file := FileAccess.open(m.save_path,FileAccess.WRITE);file.store_string("{invalid");file.close()
	copy.defaults();check(not copy.load_data() and copy.valid_state(),"corrupt JSON retains valid defaults")
	game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.loadout.save_path="";game.loadout.defaults();game.loadout_edited();game.start_run(true)
	game.test_aim=Vector3.RIGHT
	key(KEY_H)
	# One released attack must complete both hands without any second request.
	for index in range(3):
		var ammo: int=game.item_magazines.pistol0.rounds
		check(game.request_attack() and game.weapon_family=="sword" and game.motion.stage==index,"pair starts primary stage %d" % index)
		check(game.pair_strikes.active and not game.request_attack(),"pair refuses overlapping click")
		await tick(.08)
		check(game.item_magazines.pistol0.rounds==ammo,"offhand never fires simultaneously with primary start")
		for i in range(300):
			await tick(1.0/120)
			if game.pair_strikes.active and game.pair_strikes.cursor==1:break
		check(game.active_item=="pistol0" and game.motion.stage==0 and game._next_combo==index,"automatic offhand same combo step; ranged maps to its single action")
		await tick(.8)
		check(not game.pair_strikes.active and game._next_combo==(index+1)%3,"only complete pair advances step")
		check(game.item_magazines.pistol0.rounds==ammo-1,"one offhand round per click")
	# Cancellation cannot dispatch the queued other hand.
	check(game.request_attack(),"cancel fixture starts")
	await tick(.08)
	var ammo: int=game.item_magazines.pistol0.rounds
	key(KEY_SPACE)
	await tick(.8)
	check(not game.pair_strikes.active and game.item_magazines.pistol0.rounds==ammo and game._next_combo==0,"Space cancels pending offhand and resets step")
	for stop_time in [.22,.31,.42,.55]:
		game.start_run(true);game.test_aim=Vector3.RIGHT
		game.request_attack();await tick(stop_time)
		var spent: int=10-game.item_magazines.pistol0.rounds
		check(spent==(1 if stop_time>=.42 else 0),"sequential shot timing before cancellation %.2f" % stop_time)
		key(KEY_SPACE);await tick(.8)
		check(not game.pair_strikes.active and game.item_magazines.pistol0.rounds==10-spent and game._next_combo==0,"cancel keeps only committed hand at %.2f" % stop_time)
	# Mixed melee stages preserve the actual authored moves for BOTH weapons.
	game.loadout.move_item(loc(game.loadout.bag.find("mace0")),hand(0,"off"));game.loadout_edited()
	for index in range(3):
		check(game.request_attack(),"mixed melee pair begins")
		for i in range(300):
			await tick(1.0/120)
			if game.pair_strikes.active and game.pair_strikes.cursor==1:break
		check(game.weapon_family=="mace" and game.motion.stage==index,"offhand uses own matching melee move %d" % index)
		await tick(1.3)
	game.loadout.move_item(loc(game.loadout.bag.find("sword1")),hand(0,"off"));game.loadout_edited()
	for index in range(3):
		check(game.request_attack() and game.active_item=="sword0" and game.motion.stage==index,"identical Sword primary move")
		for i in range(300):
			await tick(1.0/120)
			if game.pair_strikes.active and game.pair_strikes.cursor==1:break
		check(game.active_item=="sword1" and game.motion.stage==index,"identical Sword other hand matches stage")
		await tick(1)
	game.loadout.move_item(loc(game.loadout.bag.find("mace0")),hand(0,"off"));game.loadout_edited()
	# Whole-set swap waits for both hands, then preserves the next stage.
	game.request_attack();key(KEY_Q)
	check(game.pending_set==1 and game.loadout.active==0,"busy Q queues")
	for i in range(300):
		await tick(1.0/120)
		if game.pair_strikes.active and game.pair_strikes.cursor==1:break
	check(game.loadout.active==0,"Q does not split the pair between sets")
	await tick(1.3)
	check(game.loadout.active==1 and game._next_combo==1,"Q swaps after entire pair")
	check(game.request_attack() and not game.pair_strikes.active and game.motion.stage==1,"two-hand weapon still attacks once")
	await tick(.9)
	key(KEY_Q);game._next_combo=0
	key(KEY_F);check(game.skill_active,"F rapid skill retained")
	await tick(.6)
	key(KEY_I);check(game.inventory_open,"I opens inventory")
	var clock: float=game.run_time;await tick(.3)
	check(game.run_time==clock and not game.request_attack(),"inventory pauses world and blocks attacks")
	await process_frame
	var source
	var target
	for slot in game.arsenal.slots:
		if slot.id=="pistol0":source=slot
		if slot.location==hand(0,"off"):target=slot
	await click(source);await click(target)
	check(game.loadout.sets[0].off=="pistol0" and game.loadout.valid_state(),"actual UI click equip retained")
	key(KEY_ESCAPE);check(not game.inventory_open and game.mode=="practice","Escape closes inventory")
	game.loadout.move_item(loc(game.loadout.bag.find("pistol1")),hand(0,"main"));game.loadout_edited()
	game.reset_gun_magazines()
	for i in range(3):game.request_attack();await tick(.9)
	check(game.item_magazines.pistol0.rounds==7 and game.item_magazines.pistol1.rounds==7,"identical pistols fire sequentially once each per click")
	check(game.request_reload(),"item reload starts")
	await tick(.1);key(KEY_SPACE);await tick(.7)
	check(not game.active_magazine().reloading and game.active_magazine().rounds==7,"Space cancels item reload without refill")
	# Empty secondary blocks acceptance and starts its real reload, not a free shot.
	game.item_magazines.pistol0.rounds=0
	var main_ammo: int=game.item_magazines.pistol1.rounds
	check(not game.request_attack() and not game.pair_strikes.active,"dry offhand cannot start half a pair")
	check(game.item_magazines.pistol1.rounds==main_ammo and game.item_magazines.pistol0.reloading,"dry pair reloads without spending main round")
	await tick(.6)
	check(game.request_attack(),"pair usable after real reload")
	game.tick(2.0)
	check(not game.pair_strikes.active and not game.motion.busy,"large frame completes both hands")
	game.queue_free();await process_frame
	print("ARSENAL TESTS: %d/%d passed" % [checks-failures.size(),checks]);quit(0 if failures.is_empty() else 1)
