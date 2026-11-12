extends SceneTree
const Skills = preload("res://scripts/sword_skill_motion.gd")
var game
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func fresh() -> void:
	game.start_run(true)
	game.set_physics_process(false)
	game.set_process(false)
	game.test_aim = Vector3.RIGHT
	game.move_input = Vector2.ZERO
	game.stats.flat.critical_chance = -1.0
	for enemy in game.enemies:
		enemy.health = 10000.0
		enemy.max_health = 10000.0
		enemy.position = game.player.position + Vector3.RIGHT * 1.6

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func finish_cast(delta: float = 1.0 / 120.0) -> void:
	var elapsed := 0.0
	while game.skill_active and elapsed < 8.0:
		game.tick(delta)
		elapsed += delta
	check(not game.skill_active and game.motion == game._basic_motion, "cast restores ordinary motion")

func run() -> void:
	Engine.set_meta("harbor_native_qa", true)
	game = load("res://scenes/game.tscn").instantiate()
	game.loadout.save_path = ""
	game.use_cutout_avatar = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	check(Skills.SKILLS.size() == 8, "eight skills")
	fresh()
	for id: String in Skills.SKILLS:
		var tags: Array = Skills.SKILLS[id].get("tags", [])
		check(not tags.is_empty(), "%s has a visible skill category" % id)
		check((&"area" in tags) == (id == "stormcaller"), "%s distinguishes an independent ground area from blade and projectile coverage" % id)
		check(&"ground_impact" not in tags, "%s does not count as a ground slam" % id)
	var catalog = game.sword_skill_ui.catalog_details
	check(catalog["stormcaller"].text.contains("\nพื้นที่ • มีผลบนพื้น"), "the expanding storm ring is listed as ground area")
	check(catalog["storm_blade"].text.contains("\nคลื่นจากฟันปกติ • ลูกยิง"), "the buff lists its projectile effect separately")
	var stance := Skills.new()
	stance.configure("square_off")
	check(stance.definition(1).get("tags", []) == [&"sweep"] and stance.definition(2).get("tags", []) == [&"thrust"], "the two stance followups have independent categories")
	game.mana = 50.0
	game.tick(2.0)
	check(is_equal_approx(game.mana, 51.0), "mana recovers one point in two seconds of play")
	game.inventory_open = true
	game.tick(2.0)
	check(is_equal_approx(game.mana, 51.0), "mana recovery pauses while the inventory is open")
	game.inventory_open = false
	var max_mana: float = game.stats.value("max_mana")
	game.mana = max_mana - 0.25
	game.tick(2.0)
	check(game.mana == max_mana, "mana recovery stops at the current maximum")
	var mana_costs := {
		"impaling_thrust": 16.0, "double_slash": 20.0,
		"square_off": 22.0, "sword_dance": 28.0,
		"spinning_slash": 26.0, "storm_blade": 24.0,
		"stormcaller": 38.0, "vacuum_slice": 34.0,
	}
	for id: String in Skills.SKILLS:
		fresh()
		game.loadout.equip_skill(0, id)
		var before: float = game.stamina
		var before_mana: float = game.mana
		var cost: float = mana_costs[id]
		game.mana = cost - 0.01
		check(not game.request_skill_slot(0) and game.mana == cost - 0.01 and not game.sword_skill_cooldowns.has(id), "low mana prevents " + id)
		game.mana = before_mana
		var start_time: float = game.run_time
		key(KEY_1)
		check(game.skill_active and game.active_skill_id == id, "key 1 starts " + id)
		check(game.mana == before_mana - cost and game.stamina == before, "%s only charges its mana cost" % id)
		if id == "square_off":
			game._choose_square_followup(1)
		var longest_stagger := 0.0
		for frame in range(960):
			if not game.skill_active: break
			game.tick(1.0 / 120.0)
			longest_stagger = maxf(longest_stagger, game.enemies[0].stagger)
		check(not game.skill_active and game.motion == game._basic_motion, "cast restores ordinary motion")
		check(is_equal_approx(game.mana, before_mana - cost + (game.run_time - start_time) * .5), "mana is charged only once for " + id)
		if id == "square_off":
			check(is_equal_approx(longest_stagger, .30), "stance sweep staggers for 0.30 seconds")
		if id == "sword_dance":
			check(is_equal_approx(longest_stagger, .25), "dance finisher staggers for 0.25 seconds")
		check(game.hits > 0 or id in ["storm_blade", "vacuum_slice"], "melee contact for " + id)
		if id == "impaling_thrust":
			check(game.enemies[0].mace_armor.stacks == 1 and game.enemies[0].mace_armor.remaining > 9.0, "the level five thrust applies one shared armor-break stack")
		if id == "storm_blade":
			check(game.staff_flight.shots_fired == 0 and game.sword_wave_buff_left > 0.0, "buff activation has no damaging wave")
		if id == "vacuum_slice":
			check(game.staff_flight.shots_fired == 1, "one wave for " + id)
			for i in range(180): game.tick(1.0 / 120.0)
			check(game.hits == 1, "wave resolves one first-enemy hit for " + id)
		before = game.stamina
		before_mana = game.mana
		check(not game.request_skill_slot(0), "cooldown blocks repeated " + id)
		check(game.stamina == before and game.mana == before_mana, "rejection preserves resources")
	fresh()
	game.loadout.equip_skill(0, "impaling_thrust")
	game.mana = 15.0
	check(not game.request_skill_slot(0) and game.mana == 15.0 and not game.sword_skill_cooldowns.has("impaling_thrust"), "insufficient mana rejects before charging or starting cooldown")
	game.mana = 16.0
	game.stamina = 0.0
	check(game.request_skill_slot(0) and game.mana == 0.0 and game.stamina == 0.0, "exact mana is accepted with zero stamina")
	var target = game.enemies[0]
	var peak_stagger := 0.0
	for frame in range(180):
		if not game.skill_active: break
		game.tick(1.0 / 120.0)
		peak_stagger = maxf(peak_stagger, target.stagger)
	check(game.hits == 1 and is_equal_approx(game.total_damage, 51.0) and is_equal_approx(peak_stagger, 0.20), "thrust deals 51 and staggers the target for 0.20 seconds")
	fresh()
	game.enemies[0].position = game.player.position + Vector3.LEFT * 5.0
	var full_mana: float = game.mana
	var cast_start: float = game.run_time
	check(game.request_skill_slot(0), "cast thrust away from target")
	finish_cast()
	var recovered_mana: float = (game.run_time - cast_start) * 0.5
	check(game.hits == 0 and is_equal_approx(game.mana, full_mana - 16.0 + recovered_mana), "a miss still spends the same mana")
	fresh()
	game.loadout.equip_skill(0, "double_slash")
	game.mana = 19.0
	check(not game.request_skill_slot(0) and game.mana == 19.0 and not game.sword_skill_cooldowns.has("double_slash"), "double slash requires 20 mana before starting")
	game.mana = 20.0
	game.stamina = 0.0
	target = game.enemies[0]
	cast_start = game.run_time
	check(game.request_skill_slot(0) and game.mana == 0.0 and game.stamina == 0.0, "double slash charges once for both cuts")
	var damage_steps: Array[float] = []
	var stagger_steps: Array[float] = []
	for frame in range(180):
		if not game.skill_active: break
		var before_damage: float = game.total_damage
		game.tick(1.0 / 120.0)
		if game.total_damage > before_damage:
			damage_steps.append(game.total_damage - before_damage)
			stagger_steps.append(target.stagger)
	recovered_mana = (game.run_time - cast_start) * 0.5
	check(damage_steps.size() == 2 and is_equal_approx(damage_steps[0], 27.0) and is_equal_approx(damage_steps[1], 31.0) and is_equal_approx(game.mana, recovered_mana), "the two cuts deal 27 and 31 without a second charge")
	check(stagger_steps.size() == 2 and is_equal_approx(stagger_steps[1], .25), "the return cut staggers the same target for 0.25 seconds")
	check(game._double_slash_first_hits.is_empty(), "first-cut targets are cleared after the cast")
	fresh()
	target = game.enemies[0]
	target.position = game.player.position + Vector3.LEFT * 5.0
	check(game.request_skill_slot(0), "start double slash with a first cut that misses")
	peak_stagger = 0.0
	for frame in range(180):
		if not game.skill_active: break
		if game.motion.stage == 1 and game.hits == 0:
			target.position = game.player.position + Vector3.RIGHT * 1.6
		game.tick(1.0 / 120.0)
		peak_stagger = maxf(peak_stagger, target.stagger)
	check(game.hits == 1 and is_equal_approx(game.total_damage, 31.0) and is_equal_approx(peak_stagger, .15), "return cut alone deals its damage and keeps the ordinary hit reaction")
	fresh()
	game.loadout.equip_skill(1, "square_off")
	key(KEY_2)
	game._choose_square_followup(2)
	finish_cast(0.09)
	check(game.hits == 1, "square thrust selected through second slot")
	fresh()
	game.loadout.equip_skill(2, "spinning_slash")
	key(KEY_3)
	finish_cast(0.4)
	check(game.hits == 2, "two spins retain distinct hit ledgers across large frames")
	fresh()
	game.loadout.equip_skill(0, "double_slash")
	check(game.request_skill_slot(0), "cast before cancellation")
	check(game.request_dodge(Vector3.LEFT), "dodge cancels a skill")
	check(not game.skill_active and game.motion == game._basic_motion, "dodge restores ordinary motion")
	check(game.sword_skill_cooldowns.double_slash > 0, "cancellation retains cooldown")
	fresh()
	game.loadout.equip_skill(0, "spinning_slash")
	game.stamina = 0
	check(game.request_skill_slot(0) and game.skill_active and game.stamina == 0.0, "spinning slash can start at zero stamina with enough mana")
	fresh()
	game.loadout.sets[game.loadout.active] = {"main": "greatsword0", "off": ""}
	game.loadout_edited()
	check(not game.sword_skills_available() and not game.request_skill_slot(0), "other weapon disables slots")
	fresh()
	game.loadout.defaults()
	game.loadout_edited()
	game._select_loadout_item("pistol0")
	check(game.request_skill_slot(0) and game.weapon_family == "sword", "skill selects primary sword after offhand attack")
	game._cancel_skill()
	game._hit_stop = 0.0
	game.toggle_sword_skills()
	var before_time: float = game.run_time
	game.tick(0.5)
	check(game.sword_skills_open and game.run_time == before_time, "catalog pauses simulation")
	check(not game.request_skill_slot(0), "catalog blocks gameplay input")
	key(KEY_ESCAPE)
	check(not game.sword_skills_open, "escape closes catalog")
	fresh()
	game.loadout.equip_skill(0, "square_off")
	game.request_skill_slot(0)
	finish_cast()
	check(game.hits == 0, "unselected stance expires without damage")
	fresh()
	game.set_weapon_family("bow")
	check(game._begin_bow(), "bow charge fixture")
	game.tick(0.4)
	game.toggle_sword_skills()
	var before_shots: int = game.staff_flight.shots_fired
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	game._input(release)
	check(game.bow_charge < 0.0 and game.staff_flight.shots_fired == before_shots, "catalog cancels charge and blocks release")
	game.toggle_body_lab()
	check(not game.body_lab_open, "body lab cannot open behind skill catalog")
	game.toggle_sword_skills()
	fresh()
	game.loadout.active = 0
	game.loadout.sets[0].main = "sword0"
	game.loadout.sets[0].off = ""
	game.loadout.items.sword0.sword_power = 24.0
	game.loadout_edited()
	game.loadout.equip_skill(0, "double_slash")
	check(game.request_skill_slot(0), "the equipped stronger sword can use a skill")
	check(is_equal_approx(game.motion.definition(0).damage, 32.4), "the skill reads power from the equipped sword")
	finish_cast()
	check(game.request_attack() and is_equal_approx(game.motion.definition(0).damage, 21.6), "the basic cut uses the same equipped sword power")
	game.queue_free()
	await process_frame
	print("SWORD SKILLS GAME: %d/%d checks passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
