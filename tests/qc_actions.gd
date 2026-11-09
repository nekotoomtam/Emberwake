extends SceneTree
## Same motion/controller owner in headless and native modes. Native saves actual phase views.
const STEP := 1.0/120
var game
var output := ""
var native := false
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var case_name := ""
var phase_marks: Dictionary = {}
var metrics: Dictionary = {}
var previous_hand := -1
var previous_phase := ""
var ticks := 0
var max_tip_error := 0.0
var native_frames := 0
func _initialize() -> void:
	root.unfocusable=true;Engine.physics_ticks_per_second=120
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	native=DisplayServer.get_name()!="headless"
	call_deferred("run")
func _process(_delta: float) -> bool:
	if native and output!="" and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
	return false
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(case_name+": "+label);printerr("FAIL: ",case_name,": ",label)
func key(code: Key) -> void:
	for down in [true,false]:
		var e := InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true)
func aim() -> void:
	var e := InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+Vector3.RIGHT*5);root.push_input(e,true)
func click() -> void:
	aim()
	for down in [true,false]:
		var e := InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=game.camera.unproject_position(game.player.position+Vector3.RIGHT*5);root.push_input(e,true)
func equip(id: String,hand: String) -> void:
	var source: Dictionary={};var index: int=game.loadout.bag.find(id)
	if index>=0:source={"kind":"bag","index":index}
	else:
		for i in range(2):
			for name in ["main","off"]:
				if game.loadout.sets[i][name]==id:source={"kind":"slot","set":i,"hand":name}
	var target := {"kind":"slot","set":0,"hand":hand}
	if source!=target:check(game.loadout.move_item(source,target),"fixture equip "+id)
func fixture(label: String,main: String,off: String="") -> void:
	case_name=label;phase_marks.clear();metrics.clear();previous_hand=-1;previous_phase=""
	game.loadout.defaults();game.loadout.save_path=""
	game.loadout.unequip({"kind":"slot","set":0,"hand":"off"})
	equip(main,"main")
	if off!="":equip(off,"off")
	game.loadout_edited();game.start_run(true)
	game.enemies[0].position=Vector3(1.8,.03,0)
	aim()
	for i in range(24):await tick(false)
func save(mark: String) -> void:
	if phase_marks.has(mark):return
	phase_marks[mark]=true
	if not native:return
	await process_frame;await RenderingServer.frame_post_draw
	var name := case_name+"-"+mark+".png"
	root.get_texture().get_image().save_png(output.path_join(name))
	captures.append({"case":case_name,"mark":mark,"file":name,"tick":ticks,"item":game.active_item,"stage":game.motion.stage,"phase":game.current_visual_sample().phase,"hits":game.hits,"damage":game.total_damage})
func tick(observe: bool=true) -> void:
	await physics_frame
	check(Engine.is_in_physics_frame(),"model outside physics")
	game.tick(STEP);ticks+=1
	if not observe:return
	var sample: Dictionary=game.current_visual_sample()
	if game.motion.busy:
		var hand: int=1 if game._is_left_hand() else 0
		var number: int = game.skill_cut_index+1 if game.skill_active else game._loadout_attack_index+1
		var mark := "%d-%d-%s" % [number,hand,sample.phase]
		var threshold: float = .5 if sample.phase=="windup" else (.4 if sample.phase=="active" else .05)
		if sample.phase in ["windup","active","recovery"] and float(sample.get("progress",0))>=threshold:await save(mark)
		if game.skill_active and sample.phase=="active":
			var skill_tip: Vector3=game.dual_visual.rigs[0].get_blade_points().tip
			max_tip_error=maxf(max_tip_error,skill_tip.distance_to(game._staff_tip(sample)))
		if game._uses_dual_hands():
			var pose: Dictionary=game.dual_visual.poses[hand]
			var id: String=game.active_item
			if not metrics.has(id):metrics[id]={"min_radius":999.0,"max_radius":-999.0,"min_pitch":999.0,"max_pitch":-999.0,"height_span":0.0}
			metrics[id].min_radius=minf(metrics[id].min_radius,pose.radius);metrics[id].max_radius=maxf(metrics[id].max_radius,pose.radius)
			metrics[id].min_pitch=minf(metrics[id].min_pitch,pose.pitch);metrics[id].max_pitch=maxf(metrics[id].max_pitch,pose.pitch)
			if sample.phase=="active":
				var tip: Vector3=game.dual_visual.rigs[hand].get_blade_points().tip
				max_tip_error=maxf(max_tip_error,tip.distance_to(game._staff_tip(sample)))
func finish() -> void:
	for i in range(600):
		await tick()
		if not game.motion.busy and not game.pair_strikes.active and not game.skill_active and game._hit_stop<=0:return
	check(false,"action timeout")
func normal_case(main: String,off: String="") -> void:
	await fixture(main+"_"+(off if off!="" else "solo"),main,off)
	var launch: Array=[]
	for stage in range(3):
		click()
		check(game.motion.busy,"LMB starts stage")
		await finish()
		launch.append(game.staff_flight.shots_fired)
	check(game.hits==(6 if off!="" else 3),"expected contact count")
	var entry := {"case":case_name,"kind":"basic","phase_views":phase_marks.size(),"hits":game.hits,"damage":game.total_damage,"metrics":metrics.duplicate(true),"shots":launch}
	for id: String in metrics:
		if game.loadout.items[id].family=="pistol":
			var travel: float=metrics[id].max_radius-metrics[id].min_radius
			check(travel>.10,"pistol hand has readable extension/recoil, not a fixed grip: "+id)
	cases.append(entry)
func specials() -> void:
	for code in [KEY_F,KEY_E]:
		await fixture("skill-"+("F" if code==KEY_F else "E"),"sword0","pistol0")
		key(code);check(game.skill_active,"skill starts");await tick()
		check(game.dual_visual.visible and game.dual_visual.rigs[1].weapon.visible,"skill retains equipped offhand")
		await finish();check(game.hits==2,"skill delivers two contacts")
		cases.append({"case":case_name,"kind":"skill","phase_views":phase_marks.size(),"hits":game.hits})
	for family: String in ["sword","mace","pistol","greatsword","staff","rifle"]:
		await fixture("dodge-"+family,family+"0")
		key(KEY_SPACE);check(game._dodge_left>0,"dodge starts");await tick(false);await save("dodge")
		for i in range(42):await tick(false)
		check(game._dodge_left==0 and not game.motion.busy,"dodge returns idle")
		cases.append({"case":case_name,"kind":"dodge"})
	for family: String in ["pistol","rifle"]:
		await fixture("reload-"+family,family+"0")
		click();await finish();key(KEY_R);check(game.active_magazine().reloading,"reload starts after actual shot")
		for i in range(3):
			for j in range(12):await tick(false)
			await save("reload%d" % i)
		for j in range(150):await tick(false)
		check(not game.active_magazine().reloading and game.active_magazine().rounds==game.active_magazine().capacity,"reload completes")
		cases.append({"case":case_name,"kind":"reload"})
func paired_reload(main: String,off: String) -> void:
	await fixture("reload-pair-"+main+"_"+off,main,off)
	click();await finish();key(KEY_R)
	check(game.active_magazine().reloading,"mixed-pair R finds equipped gun even after a melee finish")
	check(game.dual_visual.visible and game.dual_visual.rigs[0].weapon.visible and game.dual_visual.rigs[1].weapon.visible,"both weapons remain during reload")
	for i in range(3):
		for j in range(12):await tick(false)
		await save("paired-reload%d" % i)
	for j in range(80):await tick(false)
	check(game.active_magazine().rounds==game.active_magazine().capacity,"paired reload finishes")
	if main=="pistol0" and off=="pistol1":
		key(KEY_R);check(game.active_item=="pistol0" and game.active_magazine().reloading,"second R selects other depleted pistol")
		for i in range(3):
			for j in range(12):await tick(false)
			await save("other-gun-reload%d" % i)
		for j in range(80):await tick(false)
		check(game.item_magazines.pistol0.rounds==10 and game.item_magazines.pistol1.rounds==10,"both guns reload independently")
	cases.append({"case":case_name,"kind":"paired-reload","phase_views":phase_marks.size()})

func run() -> void:
	if native:
		if output=="":quit(1);return
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
	if output!="":DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	for a in ["sword","mace","pistol"]:
		for b in ["sword","mace","pistol"]:await normal_case(a+"0",b+("1" if a==b else "0"))
	for family in ["sword","mace","pistol","greatsword","staff","rifle"]:await normal_case(family+"0")
	await specials()
	await paired_reload("sword0","pistol0")
	await paired_reload("pistol0","sword0")
	await paired_reload("pistol0","pistol1")
	check(max_tip_error<.0001,"active weapon physical alignment")
	if output!="":
		var file := FileAccess.open(output.path_join("qc-manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"cases":cases,"captures":captures,"failures":failures,"ticks":ticks,"physics_hz":120,"native":native,"max_tip_error":max_tip_error},"\t"));file.close()
	game.queue_free();await process_frame
	print("ACTION QC: %d cases / %d native phase views; failures=%s" % [cases.size(),captures.size(),JSON.stringify(failures)]);quit(0 if failures.is_empty() else 1)
