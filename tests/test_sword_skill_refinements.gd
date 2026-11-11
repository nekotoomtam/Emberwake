extends SceneTree
class Target:
	extends "res://scripts/enemy.gd"
	var forces: Array[Vector3] = []
	func receive_damage(amount: float, force: Vector3) -> void:
		forces.append(force)
		super.receive_damage(amount, force)

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func advance(time: float) -> void:
	var elapsed := 0.0
	while elapsed < time:
		var delta := minf(1.0 / 120.0, time - elapsed)
		game.tick(delta)
		elapsed += delta

func fresh() -> void:
	game.start_run(true)
	game.set_physics_process(false)
	game.set_process(false)
	game.set_weapon_family("sword")
	game.test_aim = Vector3.RIGHT
	game.stats.flat.critical_chance = -1
	game.clear_actors()

func target(at: Vector3) -> Target:
	var enemy := Target.new()
	enemy.kind = "dummy"
	game.add_child(enemy)
	enemy.position = at
	enemy.health = 10000
	enemy.max_health = 10000
	game.enemies.append(enemy)
	return enemy

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.loadout.save_path = ""
	root.add_child(game)
	fresh()
	var single_rate: float = game.attack_rate()
	check(game._begin_skill("storm_blade"), "buff can activate")
	advance(0.7)
	check(game.staff_flight.shots_fired == 0, "activation is a harmless flourish")
	check(game.sword_wave_buff_left > 4.0 and game.sword_wave_buff_left < 5.0, "five second timer starts at activation")
	check(is_equal_approx(game.attack_rate(), single_rate * 1.10), "buff increases one-handed sword attack speed by ten percent")
	check(game.request_attack(), "normal attack during buff")
	for frame in range(60):
		if game.staff_flight.shots_fired > 0: break
		game.tick(1.0 / 120.0)
	check(game.staff_flight.shots_fired == 1, "one wave emitted per ordinary swing")
	check(not game.staff_flight.active.is_empty() and is_equal_approx(game.staff_flight.active[0].radius, .7), "buff wave uses wider contact radius")
	advance(0.8)
	check(game.request_dodge(Vector3.LEFT), "dodge during buff")
	check(game.sword_wave_buff_left > 0, "dodge retains timed buff")
	advance(0.6)
	game.set_weapon_family("pistol")
	var shots: int = game.staff_flight.shots_fired
	check(game.request_attack(), "other weapon can still attack")
	advance(0.5)
	check(game.staff_flight.shots_fired == shots + 1, "other weapon has only its own projectile")
	game.set_weapon_family("sword")
	advance(6.0)
	check(game.sword_wave_buff_left == 0, "buff expires")
	shots = game.staff_flight.shots_fired
	check(game.request_attack(), "ordinary sword after expiry")
	advance(0.6)
	check(game.staff_flight.shots_fired == shots, "expired buff emits no waves")
	var wave_counts: Array[int] = []
	for delta: float in [0.2, 1.0 / 120.0]:
		fresh()
		game.loadout.defaults()
		game.loadout_edited()
		check(game._begin_skill("storm_blade"), "default loadout sword receives the buff")
		advance(0.5)
		game.sword_wave_buff_left = .2
		check(game.request_attack(), "one-handed attack starts near the buff boundary")
		var time := 0.0
		while time < .2 - .0000001:
			var part := minf(delta, .2 - time)
			game.tick(part)
			time += part
		wave_counts.append(game.staff_flight.shots_fired)
	check(wave_counts == [1, 1], "buffed swing emits the same wave before expiry on large and small frames")
	fresh()
	game.loadout.defaults()
	var second_sword: int = game.loadout.bag.find("sword1")
	check(game.loadout.move_item({"kind": "bag", "index": second_sword}, {"kind": "slot", "set": 0, "hand": "off"}), "equip two swords")
	game.loadout_edited()
	check(game._begin_skill("storm_blade"), "buff can activate with two swords")
	advance(0.5)
	check(game._storm_blade_item == "sword0", "cast binds to the first sword")
	check(game.available_body_items() == ["sword0"] and not game.dual_visual.visible and game._storm_blade_coated_rig() == game.avatar, "only the coated sword is held while the buff lasts")
	check(is_equal_approx(game.attack_rate(), single_rate * 1.10), "the single-sword stance uses the buffed one-handed rate")
	check(game.request_attack() and not game.pair_strikes.active, "attack uses only the coated sword")
	advance(0.7)
	check(game.active_item == "sword0" and game.staff_flight.shots_fired == 1, "one one-handed cut releases one wave")
	game.sword_wave_buff_left = 0.04
	check(game.request_attack(), "start a final cut just before buff expiry")
	game.tick(0.05)
	check(is_equal_approx(game.motion.elapsed, single_rate * (0.04 * 1.10 + 0.01)), "swing speed returns to normal exactly at expiry")
	check(game.sword_wave_buff_left == 0.0 and game.motion.busy and not game.dual_visual.visible, "a cut started one-handed finishes one-handed")
	advance(0.7)
	check(game.dual_visual.visible and game.available_body_items() == ["sword0", "sword1"], "both swords automatically return after the last cut")
	check(game.request_attack() and game.pair_strikes.active, "the next attack resumes paired strikes")
	advance(1.1)
	check(game.staff_flight.shots_fired == 1, "neither expired attack releases a wave")
	fresh()
	game.loadout_edited()
	check(game._begin_skill("storm_blade"), "buff can activate before switching swords")
	advance(0.5)
	check(game.loadout.unequip({"kind": "slot", "set": 1, "hand": "main"}), "free the second set's main slot")
	check(game.loadout.move_item({"kind": "slot", "set": 0, "hand": "off"}, {"kind": "slot", "set": 1, "hand": "main"}), "move the other sword into a second set")
	check(game.activate_loadout(1), "switch to a different sword during the buff")
	check(game._storm_blade_coated_rig() == null and game.request_attack(), "the different sword can swing without the coat")
	advance(0.8)
	check(game.staff_flight.shots_fired == 0, "switching swords does not transfer the buff")
	fresh()
	var enemy := target(game.player.position + Vector3.RIGHT * 1.6)
	var storm_origin: Vector3 = game.player.position
	check(game._begin_skill("stormcaller"), "expanding storm can start")
	advance(5.0)
	check(absf(game.player.position.x - storm_origin.x - .35) < .01 and absf(game.player.position.z - storm_origin.z) < .001, "only the opening step moves without input")
	check(enemy.forces.size() == 3, "each ring hits target once")
	if enemy.forces.size() == 3:
		check(enemy.forces[0].length() < 2 and enemy.forces[1].length() < 2, "first two rings have light push")
		check(enemy.forces[2].length() >= 8.9 and enemy.forces[2].x > 0, "last ring pushes radially outward")
	fresh()
	check(game._begin_skill("stormcaller"), "storm with between-spin steps can start")
	var steps := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var opening := Vector3.ZERO
	var locked_travel := 0.0
	for frame in range(420):
		if not game.skill_active: break
		var stage: int = game.motion.stage
		var pose: Dictionary = game.motion.sample()
		var before: Vector3 = game.player.position
		game.move_input = Vector2.RIGHT if stage == 0 else Vector2.UP
		var delta := 1.0 / 120.0
		var sweep: Dictionary = game.motion.definition(stage)
		for boundary in [sweep.windup, sweep.windup + sweep.active, sweep.windup + sweep.active + sweep.recovery]:
			var phase_left: float = boundary - game.motion.elapsed
			if phase_left > 0.00000001:
				delta = minf(delta, phase_left / game.attack_rate())
				break
		game.tick(delta)
		var travel: Vector3 = game.player.position - before
		travel.y = 0.0
		if pose.phase == "recovery" and stage < 2:
			steps[stage] += travel
		elif stage == 0 and pose.phase == "windup":
			opening += travel
		else:
			locked_travel += travel.length()
	check(absf(opening.x - .35) < .01 and absf(opening.z) < .01, "the opening step follows aim during windup")
	check(locked_travel < .001, "storm holds position during all spins and the final recovery")
	check(absf(steps[0].x - game.STORM_STEP_DISTANCE) < .01 and absf(steps[0].z) < .01, "first gap steps right")
	check(absf(steps[1].z + game.STORM_STEP_DISTANCE) < .01 and absf(steps[1].x) < .01, "second gap accepts a different step direction")
	check(not game.skill_active and game._dodge_left == 0.0, "two steps finish with the cast and do not trigger a normal dodge")
	game.move_input = Vector2.ZERO
	fresh()
	enemy = target(game.player.position + Vector3.RIGHT * 4.0)
	check(game._begin_skill("vacuum_slice"), "vacuum skill can start")
	advance(1.35)
	check(game.staff_flight.shots_fired == 1, "vacuum launches distinct projectile")
	game._cancel_skill()
	game.set_weapon_family("mace")
	advance(0.3)
	check(game.hits == 1 and enemy.stagger > 0.0, "vacuum impact retains stagger after weapon changes")
	enemy.state = "windup"
	enemy.attack_data = {"parryable": false}
	enemy.stagger = 0
	game._sword_wave_damage(enemy, 10.0, Vector3.RIGHT, "vacuum_wave")
	check(enemy.state == "windup" and enemy.stagger == 0, "committed red attacks keep existing stagger resistance")
	fresh()
	game.stats.attributes = {"dexterity": 8, "intelligence": 8}
	game.mana = 31.49
	check(not game._begin_skill("vacuum_slice") and not game.sword_skill_cooldowns.has("vacuum_slice"), "vacuum rejects mana below its discounted cost")
	game.mana = 31.5
	check(game._begin_skill("vacuum_slice") and game.mana == 0, "vacuum spends the exact discounted cost")
	advance(1.35)
	check(game.staff_flight.active.size() == 1, "scaled vacuum releases one projectile")
	if not game.staff_flight.active.is_empty():
		var wave: Dictionary = game.staff_flight.active[0]
		check(is_equal_approx(wave.damage, 68.8) and is_equal_approx(wave.speed, 8.4), "vacuum carries scaled damage and speed")
		check(wave.max_range == 13.0 and wave.radius == .8, "scaled vacuum keeps its range and contact width")
	fresh()
	game.stats.attributes = {"intelligence": 8}
	game.mana = 21.5
	check(game._begin_skill("storm_blade") and game.mana == 0, "storm blade spends the discounted cost once")
	advance(0.5)
	check(game.request_attack(), "normal attack releases the scaled buff wave")
	for frame in range(60):
		if game.staff_flight.shots_fired > 0: break
		game.tick(1.0 / 120.0)
	check(game.staff_flight.active.size() == 1, "scaled buff releases one wave per cut")
	if not game.staff_flight.active.is_empty():
		var wave: Dictionary = game.staff_flight.active[0]
		check(is_equal_approx(wave.damage, 12.9) and is_equal_approx(wave.speed, 12.6), "buff wave uses the cast's INT scaling")
	fresh()
	game.stats.attributes = {"strength": 8, "dexterity": 8}
	target(game.player.position + Vector3.RIGHT * 1.6)
	check(game._begin_skill("impaling_thrust"), "scaled melee skill starts normally")
	advance(.8)
	check(game.hits == 1 and is_equal_approx(game.total_damage, 43.0 * 1.1125), "melee contact applies combined STR and DEX scaling")
	game.queue_free()
	await process_frame
	print("SWORD SKILL REFINEMENTS: %d/%d checks passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
