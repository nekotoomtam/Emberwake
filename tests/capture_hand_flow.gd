extends SceneTree
const STEP := 1.0/120
var game
var output := ""
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var safe := false
var ticks := 0
var shots: Array[Dictionary] = []
var last_shots := 0
var max_tip_error := 0.0
var max_idle_turn := 0.0
var last_angles: Array = []
var name := ""
var direction := Vector3.RIGHT
var rig_ids: Array = []
func _initialize() -> void:
	root.unfocusable=true;Engine.physics_ticks_per_second=120
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")
func _process(_delta: float) -> bool:
	if safe and (DisplayServer.window_get_position()!=Vector2i(20000,20000) or not root.unfocusable):quit(1)
	return false
func check(ok: bool,why: String) -> void:
	if not ok:failures.append(name+": "+why);printerr("FAIL: ",name,": ",why)
func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=game.camera.unproject_position(game.player.position+direction*5);root.push_input(event,true)
func aim() -> void:
	var event := InputEventMouseMotion.new();event.position=game.camera.unproject_position(game.player.position+direction*5);root.push_input(event,true)
func equip(id: String,hand: String) -> void:
	var source: Dictionary={}
	var index: int=game.loadout.bag.find(id)
	if index>=0:source={"kind":"bag","index":index}
	else:
		for i in range(2):
			for key in ["main","off"]:
				if game.loadout.sets[i][key]==id:source={"kind":"slot","set":i,"hand":key}
	var target := {"kind":"slot","set":0,"hand":hand}
	if source!=target:check(game.loadout.move_item(source,target),"fixture equipment move")
func tick() -> void:
	await physics_frame
	check(Engine.is_in_physics_frame(),"outside actual physics")
	game.tick(STEP);ticks+=1
	var visual=game.dual_visual
	check(visual.rigs[0].get_instance_id()==rig_ids[0] and visual.rigs[1].get_instance_id()==rig_ids[1],"persistent hand nodes")
	check(visual.ids==[game.loadout.sets[0].main,game.loadout.sets[0].off],"items stay assigned to their own hands")
	if game.motion.busy and game.current_visual_sample().phase=="active":
		var hand: int=1 if game._is_left_hand() else 0
		var tip: Vector3=visual.rigs[hand].get_blade_points().tip
		max_tip_error=maxf(max_tip_error,tip.distance_to(game._staff_tip(game.current_visual_sample())))
	for i in range(2):
		var angle: float=visual.poses[i].angle
		if not last_angles.is_empty() and not visual.was_active[i]:max_idle_turn=maxf(max_idle_turn,absf(wrapf(angle-last_angles[i],-PI,PI)))
	if last_angles.is_empty():last_angles=[0.0,0.0]
	for i in range(2):last_angles[i]=float(visual.poses[i].angle)
	if game.staff_flight.shots_fired>last_shots:
		shots.append({"tick":ticks,"item":game.active_item,"origin":game._hand_origin(),"muzzle":game._staff_tip(game.current_visual_sample())})
		last_shots=game.staff_flight.shots_fired
func snapshot() -> Dictionary:
	var row := {"tick":ticks,"stage":game.motion.stage,"item":game.active_item,"phase":game.current_visual_sample().phase,"damage":game.total_damage,"hits":game.hits,"hands":[]}
	for i in range(2):
		var rig=game.dual_visual.rigs[i]
		row.hands.append({"id":game.dual_visual.ids[i],"angle":game.dual_visual.poses[i].angle,"active":game.dual_visual.was_active[i],"grip":rig.get_blade_points().grip,"tip":rig.get_blade_points().tip})
	return row
func run_case(label: String,main: String,off: String,face: Vector3) -> void:
	name=label;direction=face
	game.loadout.defaults();game.loadout.save_path="";equip(main,"main");equip(off,"off");game.loadout_edited();game.start_run(true)
	game.enemies[0].position=direction*1.8+Vector3.UP*.03
	aim();last_shots=0;shots.clear();last_angles.clear();max_tip_error=0;max_idle_turn=0
	rig_ids=[game.dual_visual.rigs[0].get_instance_id(),game.dual_visual.rigs[1].get_instance_id()]
	for i in range(60):aim();await tick()
	DirAccess.make_dir_recursive_absolute(output.path_join(label))
	var frames: Array[Dictionary]=[]
	var released := false
	for index in range(120):
		aim()
		if index==5:mouse(true)
		for sub in range(4):
			await tick()
			if not released and game.pair_strikes.active and game.pair_strikes.stage==2:mouse(false);released=true
		await process_frame;await RenderingServer.frame_post_draw
		var file := label+"/frame_%03d.png" % index
		root.get_texture().get_image().save_png(output.path_join(file))
		var state := snapshot();state.file=file;state.frame=index;frames.append(state)
	check(released and not game.pair_strikes.active,"three paired clicks complete")
	check(game.hits==6,"six sequential contacts")
	check(max_tip_error<.0001,"real rendered active tip matches physical hand")
	check(max_idle_turn<.35,"inactive hand returns without a handoff snap")
	if main=="pistol0" and off=="pistol1":
		check(shots.size()==6,"six separate bullets")
		for i in range(shots.size()):check(shots[i].item==("pistol0" if i%2==0 else "pistol1"),"alternating pistol identities")
		check(game.item_magazines.pistol0.rounds==7 and game.item_magazines.pistol1.rounds==7,"ammo per gun")
	cases.append({"case":label,"frames":frames,"damage":game.total_damage,"hits":game.hits,"shots":shots.duplicate(true),"max_tip_error":max_tip_error,"max_inactive_turn_per_tick":max_idle_turn})
func run() -> void:
	if output=="" or DisplayServer.get_name()=="headless":quit(1);return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	await run_case("sword-pistol-right","sword0","pistol0",Vector3.RIGHT)
	await run_case("pistol-sword-right","pistol0","sword0",Vector3.RIGHT)
	await run_case("pistols-right","pistol0","pistol1",Vector3.RIGHT)
	await run_case("sword-pistol-left","sword0","pistol0",Vector3.LEFT)
	var file := FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases":cases,"failures":failures,"physics_hz":120,"physics_ticks":ticks,"frames_per_case":120,"fps":30,"native_no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"input":"actual viewport LMB hold/release and mouse aim; fixed original dummy; fixture uses inventory equip API only; no supplied poses/damage/ammo"},"\t"));file.close()
	game.queue_free();await process_frame
	print("HAND FLOW NATIVE: %d cases / 480 consecutive frames; failures=%s" % [cases.size(),JSON.stringify(failures)]);quit(0 if failures.is_empty() else 1)
