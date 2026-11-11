extends SceneTree

func _initialize() -> void:
	call_deferred("run")


func valid(attributes: Dictionary) -> bool:
	return attributes.size() == 3 and attributes.values().min() == 3 and attributes.values().max() == 4 and attributes.values().reduce(func(total: int, value: int) -> int: return total + value, 0) == 10


func run() -> void:
	var board = load("res://scripts/opening/boarding_party.gd").new()
	root.add_child(board)
	var first: Dictionary = board.recruits[0].get("attributes", {})
	if not valid(first):
		printerr("Level-one board recruit needs 10 points, minimum 3 in each stat")
		quit(1)
		return
	board.roll()
	assert(board.recruits[0].attributes == first)
	var rolls := {}
	for recruit: Dictionary in board.recruits:
		assert(valid(recruit.attributes))
	var stats = preload("res://data/player_base_stats.tres").duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 185
	for i in 120:
		var attributes: Dictionary = stats.roll_level_one(rng)
		assert(valid(attributes))
		rolls[attributes.find_key(4)] = true
	assert(rolls.size() == 3)
	board.assign(3, 0)
	var entry = load("res://scenes/opening/coastal_combat_entry.tscn").instantiate()
	board.confirmed.connect(func(party: Array[Dictionary]): entry.party = party)
	board.confirm()
	root.add_child(entry)
	var game = entry.game
	game.set_physics_process(false)
	game.start_dungeon(185)
	var leader: Dictionary = board.recruits[3].attributes
	assert(game.stats.attributes == leader)
	assert(game.health == 100 + leader.strength * 3)
	assert(game.stamina == 100 + leader.dexterity * 2)
	if game.frenzy_threshold() != 200:
		printerr("INT must no longer raise the frenzy threshold")
		quit(1)
		return
	assert(game.stats.value("max_mana") == 100 + leader.intelligence)
	assert(game.mana == game.stats.value("max_mana"))
	game.mana -= 20
	var spent_mana: float = game.mana
	game.tick(.1)
	assert(is_equal_approx(game.mana, spent_mana + .05))
	var recovered_mana: float = game.mana
	game.reward_dungeon_clear_health()
	assert(game.mana == recovered_mana)
	for index in game.companions.size():
		var ally = game.companions[index]
		var attributes: Dictionary = entry.party[index + 1].attributes
		assert(ally.stats.attributes == attributes)
		assert(ally.health == 100 + attributes.strength * 3)
		assert(ally.stamina == 100 + attributes.dexterity * 2)
		assert(ally.mana == 100 + attributes.intelligence)
		ally.downed = true
		ally.revive()
		assert(is_equal_approx(ally.health, ally.max_health() * .30))
	game.start_dungeon(202)
	assert(game.stats.attributes == leader)
	assert(game.mana == game.stats.value("max_mana"))
	game.stats_panel.refresh()
	assert(game.stats_panel.attributes_text.text.contains("STR %d" % leader.strength))
	game._visual_tick(0)
	await process_frame
	var vitals: Rect2 = game.ui.vital_panel.get_global_rect()
	var sanity: Rect2 = game.ui.sanity_panel.get_global_rect()
	var body: Rect2 = game.anatomy_panel.compact.get_global_rect()
	var flask: Rect2 = game.ui.flask_button.get_global_rect()
	var viewport: Rect2 = root.get_visible_rect()
	var attached: bool = sanity.position.x <= 12 and sanity.position.y <= 12 and sanity.position.x < vitals.position.x
	attached = attached and sanity.intersects(vitals) and absf(sanity.get_center().y - vitals.get_center().y) <= 2
	attached = attached and game.ui.health_bar.get_global_rect().position.x < sanity.end.x
	if not attached or body.end.y < viewport.end.y - 16 or flask.position.x < body.end.x:
		printerr("HUD should join the sanity dial to the left of the vitals, and body before flasks on the bottom edge")
		quit(1)
		return
	game.add_sanity(50)
	game._visual_tick(0)
	assert(game.ui.sanity_progress.ratio == .5 and game.ui.sanity_overflow.ratio == 0.0)
	assert(game.ui.sanity_wash.get_shader_parameter("violet_fill") == .5)
	game.add_sanity(50)
	game._visual_tick(0)
	assert(game.ui.sanity_progress.ratio == 1.0 and game.ui.sanity_overflow.ratio == 0.0)
	var normal_rim: Color = game.ui.sanity_frame.border_color
	assert(not game.ui.sanity_warning.visible)
	game.add_sanity(50)
	game._visual_tick(0)
	assert(game.ui.sanity_progress.ratio == 1.0 and game.ui.sanity_overflow.ratio == .5)
	assert(game.ui.sanity_wash.get_shader_parameter("violet_fill") == 1.0)
	assert(game.ui.sanity_wash.get_shader_parameter("amber_fill") == .5)
	assert(not game.ui.sanity_warning.visible)
	game.add_sanity(50)
	game._visual_tick(0)
	assert(game.ui.sanity_overflow.ratio == 1.0 and game.ui.sanity_warning.visible)
	assert(game.ui.sanity_frame.border_color == normal_rim)
	assert(not game.frenzy and not game.ui.frenzy_border.visible)
	game.add_sanity(-1)
	game._visual_tick(0)
	assert(game.ui.sanity_overflow.value == 99 and not game.ui.sanity_warning.visible)
	if not game.ui.has_method("_animate_sanity_dial"):
		printerr("Expected a brain pulse and independently rotating gears")
		quit(1)
		return
	game.ui.set_process(false)
	game.ui._sanity_pulse_phase = 0.0
	game.add_sanity(-game.sanity)
	var large_gear_start: float = game.ui.sanity_gear_large.rotation
	var small_gear_start: float = game.ui.sanity_gear_small.rotation
	game.ui._animate_sanity_dial(.20)
	var slow_phase: float = game.ui._sanity_pulse_phase
	var slow_large_travel: float = game.ui.sanity_gear_large.rotation - large_gear_start
	var slow_small_travel: float = small_gear_start - game.ui.sanity_gear_small.rotation
	assert(game.ui.sanity_progress.scale.x > 1.04)
	assert(slow_large_travel > 0.0 and slow_small_travel > 0.0)
	game.ui._animate_sanity_dial(.30)
	assert(game.ui.sanity_progress.scale.x < 1.005)
	game.ui._sanity_pulse_phase = 0.0
	game.add_sanity(195)
	large_gear_start = game.ui.sanity_gear_large.rotation
	small_gear_start = game.ui.sanity_gear_small.rotation
	game.ui._animate_sanity_dial(.20)
	assert(game.ui._sanity_pulse_phase > slow_phase * 4)
	assert(game.ui.sanity_gear_large.rotation - large_gear_start > slow_large_travel * 2)
	assert(small_gear_start - game.ui.sanity_gear_small.rotation > slow_small_travel * 2)
	print("EXPEDITION ATTRIBUTES PASS roster, rolls, party transfer, derived stats, revive, restart and UI")
	quit()
