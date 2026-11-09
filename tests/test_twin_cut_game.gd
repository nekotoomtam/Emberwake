extends SceneTree
## Controller regressions: real Q/Space input, automatic legacy cuts, priority cancellation.
const STEP := 1.0 / 120.0
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func run_tests() -> void:
	Engine.physics_ticks_per_second = 120
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	check(game.has_method("request_skill"), "controller provides Twin Cut request API")
	if game.has_method("request_skill"):
		await automatic_cuts()
		await gates_and_continuation()
		await skill_cancellation()
		await rejected_dodges()
	await ordinary_cancellation()
	await reload_and_projectiles()
	game.queue_free()
	await process_frame
	print("TWIN CUT GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
func fresh(family: String = "sword", distance: float = 1.2) -> void:
	mouse(false)
	game.start_run(true)
	game.set_physics_process(false)
	check(game.set_weapon_family(family), "fixture selects " + family)
	game.test_aim = Vector3.RIGHT
	game.move_input = Vector2.ZERO
	dummy().position = game.player.position + Vector3(distance, 0, 0)
	await tick()
func dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead: return enemy
	return null
func tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)
func step(seconds: float) -> void:
	for i in range(int(ceil(seconds / STEP))): await tick()
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	Input.flush_buffered_events()
func press(code: Key) -> void:
	key(code, true)
	key(code, false)
func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = game.camera.unproject_position(game.player.position + game.aim * 4.0)
	event.global_position = event.position
	root.push_input(event, true)
	Input.flush_buffered_events()
func seek_phase(phase: String, cut: int = -1) -> bool:
	for i in range(250):
		if game.motion.busy and game.motion.sample().phase == phase and (cut < 0 or game.skill_cut_index == cut): return true
		await tick()
	check(false, "reaches phase %s cut %d" % [phase, cut])
	return false
func automatic_cuts() -> void:
	await fresh()
	var before: float = dummy().health
	var stamina: float = game.stamina
	press(KEY_F)
	check(game.skill_active and game.skill_cut_index == 0, "physical Q press starts first legacy cut")
	check(not game.request_skill() and not game.request_attack(), "busy skill refuses duplicate Q and ordinary attack")
	await step(.04)
	check(game.hits == 0 and dummy().health == before, "first scaled windup has no early damage")
	await step(.08)
	check(game.hits == 1 and game.total_damage == 18.0, "first cut deals old 18 damage once")
	await step(.30)
	check(not game.skill_active and game.skill_cut_index == -1, "one released Q completes both cuts automatically")
	check(game.hits == 2 and game.total_damage == 37.0 and dummy().health == before - 37.0, "same enemy receives each of two cuts once for 37 total")
	check(game.stamina == stamina, "skill spends no stamina")
	await step(.5)
	check(game.hits == 2, "no held repeat or third cut after released Q")
	check(game.request_skill(), "skill reusable immediately after completion without cooldown")
	await fresh("sword", 8.0)
	press(KEY_F)
	await tick(.349)
	check(game.skill_active, "two-cut phase clock remains active before .350 seconds")
	await tick(.0011)
	check(not game.skill_active, "scaled two-cut clock completes at .350 seconds without contacts")
	await fresh()
	press(KEY_F)
	await tick(.95)
	check(not game.skill_active and game.hits == 2 and game.total_damage == 37.0, "one large bounded tick crosses both cuts without dropping or duplicating hits")
func gates_and_continuation() -> void:
	for family in ["greatsword", "mace", "staff", "pistol", "rifle"]:
		await fresh(family)
		press(KEY_F)
		check(not game.skill_active and not game.request_skill() and not game.motion.busy, family + " refuses Sword-only Q")
	await fresh()
	mouse(true)
	mouse(false)
	check(game.motion.busy and not game.skill_active, "physical LMB keeps ordinary sword attack")
	check(not game.request_skill(), "ordinary busy attack refuses Q")
	await step(.8)
	check(game.hits == 1 and game.total_damage == 18.0 and game._next_combo == 1, "ordinary first attack retains current 18 damage and earned combo")
	press(KEY_F)
	await step(1.3)
	check(game._next_combo == 0, "ordinary combo expires during long skill delay")
	game.move_input = Vector2.RIGHT
	await step(.3)
	game.move_input = Vector2.ZERO
	check(game._next_combo == 0, "walking cannot restore expired combo")
	mouse(true)
	mouse(false)
	check(game.motion.stage == 0, "LMB starts first move after combo expiry")
	await fresh("sword", 8.0)
	press(KEY_F)
	var angle: float = game.motion.aim_angle
	var origin: Vector3 = game.player.position
	game.test_aim = Vector3.LEFT
	game.move_input = Vector2.RIGHT
	await step(.25)
	check(is_equal_approx(game.motion.aim_angle, angle), "both automatic cuts retain committed aim")
	check(game.player.position.distance_to(origin) > .1, "skill retains ordinary constrained movement")
	await fresh("sword", 8.0)
	check(game.request_dodge(), "idle dodge fixture begins")
	press(KEY_F)
	check(not game.skill_active and not game.request_skill(), "Q cannot replace active dodge")
	await fresh("sword", 8.0)
	game.health = 0
	check(not game.request_skill() and not game.request_dodge(), "zero health refuses both actions even before mode transition")
	for mode in ["paused", "dead", "menu"]:
		await fresh()
		game.mode = mode
		press(KEY_F)
		check(not game.request_skill() and not game.skill_active, mode + " refuses Q")
func skill_cancellation() -> void:
	for cut in [0, 1]:
		for phase in ["windup", "active", "recovery"]:
			await fresh()
			press(KEY_F)
			if not await seek_phase(phase, cut): continue
			var hits: int = game.hits
			press(KEY_SPACE)
			check(not game.skill_active and not game.motion.busy and game._next_combo == 0, "Space cancels skill cut %d %s and clears chain" % [cut, phase])
			check(game._hit_stop == 0 and game._dodge_left > 0, "Space immediately clears hitstop and begins dodge")
			await step(1.1)
			check(game.hits == hits, "cancelled skill leaves no queued hit or second cut")
	await fresh()
	press(KEY_F)
	for i in range(120):
		await tick()
		if game._hit_stop > 0: break
	check(game._hit_stop > 0, "contact creates actual skill hitstop")
	var health: float = dummy().health
	press(KEY_SPACE)
	check(game._hit_stop == 0 and not game.skill_active and dummy().health == health, "hitstop Space cancels immediately and retains applied damage")
func ordinary_cancellation() -> void:
	for family in ["sword", "greatsword", "mace", "staff", "pistol", "rifle"]:
		for stage in ([0, 1] if family == "mace" else [0]):
			for phase in ["windup", "active", "recovery"]:
				await fresh(family, 8.0)
				game._next_combo = stage
				game.rewards.combo_left = .7
				check(game.request_attack(), family + " cancellation fixture starts")
				if not await seek_phase(phase): continue
				press(KEY_SPACE)
				check(not game.motion.busy and game._next_combo == 0 and game._dodge_left == .24, "%s stage%d %s Space cancels" % [family, stage, phase])
				check(is_equal_approx(game.stamina, 70.0) and game._dodge_recharge == .42 and game._iframes == 0 and game.rewards.invulnerable() and game.rewards.DODGE_IFRAMES == .16, "successful cancel retains cost/movement with approved0.16 iframe")
				var shots: int = game.staff_flight.shots_fired
				var lunge: float = game.mace_dash_travelled
				var recoil: float = game.rifle_recoil_travelled
				await step(.7)
				check(game.staff_flight.shots_fired == shots, family + " cancelled action has no delayed release")
				check(game.mace_dash_travelled == lunge and game.rifle_recoil_travelled == recoil, family + " cancelled action has no remaining lunge/recoil")
func rejected_dodges() -> void:
	for reason in ["stamina", "recharge", "paused", "dead", "menu", "already"]:
		await fresh("sword", 8.0)
		press(KEY_F)
		await step(.05)
		if reason == "stamina": game.stamina = 0
		elif reason == "recharge": game._dodge_recharge = .2
		elif reason == "already": game._dodge_left = .1
		else: game.mode = reason
		var elapsed: float = game.motion.elapsed
		var stamina: float = game.stamina
		var next: int = game._next_combo
		check(not game.request_dodge(), reason + " rejects dodge")
		press(KEY_SPACE)
		check(game.skill_active and game.motion.busy and game.motion.elapsed == elapsed and game._next_combo == next and game.stamina == stamina, reason + " rejected Space preserves action and resources")
func reload_and_projectiles() -> void:
	for family in ["pistol", "rifle"]:
		await fresh(family, 8.0)
		var magazine = game.active_magazine()
		magazine.rounds = 3
		check(game.request_reload(), family + " partial magazine reload starts")
		await step(.1)
		game.stamina = 0
		check(not game.request_dodge() and magazine.reloading, "unaffordable dodge preserves active reload")
		game.stamina = 100
		press(KEY_SPACE)
		check(not magazine.reloading and magazine.rounds == 3, family + " Space cancels reload without refill/refund")
		await step(.7)
		check(magazine.rounds == 3 and not magazine.reloading, family + " cancelled partial reload never completes later")
		await fresh(family, 8.0)
		check(game.request_attack(), family + " pending shot starts")
		await step(.04)
		press(KEY_SPACE)
		await step(.7)
		check(game.staff_flight.shots_fired == 0 and game.active_magazine().rounds == game.active_magazine().capacity and game.casing_fx.spawned_count == 0, family + " unreleased cancellation consumes no ammo, emits no bullet or casing")
		await fresh(family, 8.0)
		game.request_attack()
		for i in range(100):
			await tick()
			if game.staff_flight.shots_fired > 0: break
		check(game.staff_flight.active.size() == 1 and game.casing_fx.active.size() == 1, family + " released fixture has live bullet and casing")
		var shots: int = game.staff_flight.shots_fired
		var rounds: int = game.active_magazine().rounds
		press(KEY_SPACE)
		check(game.staff_flight.active.size() == 1 and game.casing_fx.active.size() == 1 and game.active_magazine().rounds == rounds, family + " cancellation preserves already released bullet, casing, spent ammo")
		await step(.1)
		check(game.staff_flight.shots_fired == shots and not game.casing_fx.active.is_empty(), family + " existing casing survives without replacement shot")
