extends SceneTree
const STEP := 1.0/120
var game
var output := ""
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var safe := false
var ticks := 0
var drag_passed := false
var last_shots := 0
var shot_trace: Array[Dictionary] = []
func _initialize() -> void:
	root.unfocusable=true;Engine.physics_ticks_per_second=120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	call_deferred("run")
func _process(_delta: float) -> bool:
	if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):
		printerr("FAIL: native window safety");quit(1)
	return false
func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why);printerr("FAIL: ",why)
func key(code: Key) -> void:
	for down in [true,false]:
		var e := InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;root.push_input(e,true)
func pointer(position: Vector2, held: bool = false, relative: Vector2 = Vector2.ZERO) -> void:
	var e := InputEventMouseMotion.new();e.position=position;e.global_position=position;e.relative=relative;e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(e,true)
func button(position: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=position;e.global_position=position;e.pressed=down;root.push_input(e,true)
func click(node: Control) -> void:
	var at := node.get_global_rect().get_center();pointer(at);button(at,true);button(at,false);await process_frame
func find_item(id: String):
	for slot in game.arsenal.slots:
		if slot.id==id:return slot
	return null
func find_hand(index: int, hand: String):
	for slot in game.arsenal.slots:
		if slot.location=={"kind":"slot","set":index,"hand":hand}:return slot
	return null
func tick() -> void:
	await physics_frame
	check(Engine.is_in_physics_frame(),"model outside physics")
	game.tick(STEP);ticks+=1
	if game.staff_flight.shots_fired>last_shots:
		shot_trace.append({"item":game.active_item,"tick":ticks})
		last_shots=game.staff_flight.shots_fired
func finish() -> void:
	for i in range(300):
		await tick()
		if not game.motion.busy and not game.skill_active and game._hit_stop<=0:return
	check(false,"attack completion timeout")
func shot() -> void:
	var point: Vector2=game.camera.unproject_position(game.player.position+Vector3.RIGHT*5)
	pointer(point);button(point,true);button(point,false)
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
	captures.append({"file":name+".png","tick":ticks,"set":game.loadout.active,"item":game.active_item,"family":game.weapon_family,"stage":game.motion.stage,"combo":game._next_combo,"hits":game.hits,"damage":game.total_damage,"inventory":game.inventory_open})
func run() -> void:
	if output=="" or DisplayServer.get_name()=="headless":quit(1);return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.loadout.save_path="";game.loadout.defaults();game.loadout_edited();game.start_run(true)
	await process_frame
	key(KEY_H)
	key(KEY_I);await process_frame
	check(game.inventory_open,"I opens native inventory")
	await capture("01-inventory-default")
	var source=find_item("mace0");var target=find_hand(0,"off")
	var a: Vector2=source.get_global_rect().get_center();var b: Vector2=target.get_global_rect().get_center()
	pointer(a);button(a,true);await process_frame
	var previous := a
	for fraction: float in [.15,.4,.7,1.0]:
		var point := a.lerp(b,fraction);pointer(point,true,point-previous);previous=point;await process_frame
	button(b,false);await process_frame;await process_frame
	drag_passed=game.loadout.sets[0].off=="mace0"
	check(drag_passed,"actual native drag equips offhand mace")
	await capture("02-dragged-mace")
	var time: float=game.run_time
	for i in range(12):await tick()
	check(game.run_time==time and game.hits==0,"UI pauses world; drag does not attack")
	key(KEY_I)
	for index in range(3):
		shot()
		check(game.motion.busy and game.weapon_family=="sword" and game.motion.stage==index,"primary matching combo stage %d" % index)
		for i in range(160):
			await tick()
			if game.current_visual_sample().phase=="active":break
		await capture("03-pair-stage%d-main" % [index+1])
		for i in range(300):
			await tick()
			if game.pair_strikes.cursor==1 and game.current_visual_sample().phase=="active":break
		check(game.pair_strikes.active and game.active_item=="mace0" and game.motion.stage==index,"automatic other-hand matching stage")
		await capture("04-pair-stage%d-off" % [index+1])
		await finish()
		check(game._next_combo==(index+1)%3,"one click advances one combo stage")
	key(KEY_Q);check(game.loadout.active==1 and game.weapon_family=="greatsword","actual Q whole set swap")
	await capture("06-greatsword-set-two")
	shot();key(KEY_Q);check(game.pending_set==0 and game.loadout.active==1,"Q queues at attack boundary")
	await finish();check(game.loadout.active==0 and game._next_combo==1,"queued swap keeps combo")
	await capture("07-queued-swap-completed")
	key(KEY_I);await process_frame
	await click(find_item("pistol0"));await click(find_hand(0,"main"))
	await click(find_item("pistol1"));await click(find_hand(0,"off"))
	check(game.loadout.sets[0].main=="pistol0" and game.loadout.sets[0].off=="pistol1","two identical pistols equipped by actual UI")
	await capture("08-dual-pistol-slots")
	key(KEY_ESCAPE)
	for i in range(3):shot();await finish()
	check(game.item_magazines.pistol0.rounds==7 and game.item_magazines.pistol1.rounds==7,"actual alternating single shots have independent ammo")
	await capture("09-pistols-after-three-shots")
	key(KEY_R)
	check(game.active_magazine().reloading,"actual R reloads active item")
	for i in range(6):await tick()
	key(KEY_SPACE)
	check(not game.active_magazine().reloading,"actual Space cancels item reload")
	for i in range(60):await tick()
	check(game.item_magazines.pistol0.rounds==7,"cancelled item magazine never refills")
	await capture("09b-item-reload-cancelled")
	key(KEY_I);await process_frame
	# Empty both one-hand slots, then equip a two-hand item with real UI clicks.
	await click(find_item("rifle0"));await click(find_hand(0,"main"))
	check(game.loadout.sets[0].off=="" and "pistol1" in game.loadout.bag,"native two-hand equip returns offhand")
	await capture("10-two-hand-reserves-both")
	check(game.loadout.valid_state(),"all twelve items conserved")
	key(KEY_I);shot();check(game.weapon_family=="rifle" and game.motion.busy,"equipped rifle fires")
	await finish();check(game.item_magazines.rifle0.rounds==4,"rifle magazine used")
	await capture("11-rifle-actual-shot")
	check(shot_trace.size()==7,"six pistol bullets plus one rifle round")
	for i in range(1,shot_trace.size()):check(shot_trace[i].tick>shot_trace[i-1].tick,"hands never release on same physics tick")
	var data := {"shot_trace":shot_trace,"failures":failures,"drag_passed":drag_passed,"physics_ticks":ticks,"physics_hz":120,"native_no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"window_position":[20000,20000],"captures":captures,"items_conserved":game.loadout.valid_state(),"pistol_ammo":[game.item_magazines.pistol0.rounds,game.item_magazines.pistol1.rounds],"rifle_ammo":game.item_magazines.rifle0.rounds,"input":"actual viewport I/Q/Escape and LMB click/drag; default original practice dummy; no injected poses, damage, ammo or combo; defaults reset once for reproducible fixture"}
	var file := FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	game.queue_free();await process_frame
	print("ARSENAL NATIVE: %d images; drag=%s; failures=%s" % [captures.size(),drag_passed,JSON.stringify(failures)]);quit(0 if failures.is_empty() else 1)
