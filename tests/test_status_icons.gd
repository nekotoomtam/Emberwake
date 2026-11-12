extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	printerr("FAIL: ", message)

func run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	game.loadout.save_path = ""
	root.add_child(game)
	game.start_run(true)
	game.set_physics_process(false)
	var enemy = game.enemies[0]
	enemy.apply_movement_slow(.20, 5.0)
	enemy.apply_armor_break(.20, 6.0)
	enemy.apply_mace_break()
	enemy.apply_rifle_mark()
	enemy.crossbow_wound_ticks = 2
	enemy.stagger = .25
	var icons: Array = game.status_icons.icons_for(enemy)
	check(icons.size() == 6 and ["slow", "20%", 1.0] in icons, "slow, both armor effects, mark, wound and stagger coexist")
	enemy.advance_combat_status(2.5)
	icons = game.status_icons.icons_for(enemy)
	check(["slow", "20%", .5] in icons and ["shield", "20%", 3.5 / 6.0] in icons, "enemy timer arcs use the actual effect durations")
	enemy.advance_combat_status(2.5)
	icons = game.status_icons.icons_for(enemy)
	check(not icons.any(func(entry): return entry[0] == "slow") and ["shield", "20%", 1.0 / 6.0] in icons, "slow expires independently")

	game.set_weapon_family("sword")
	check(game._begin_skill("storm_blade"), "storm blade activates through gameplay")
	game.tick(.40)
	game.health = 40.0
	check(game.use_health_flask(), "flask activates through gameplay")
	game.rewards.grant_counter()
	game.readiness.broken_left = .40
	game._iframes = .30
	game.ui.refresh()
	var shown: Array = game.ui.status_view.shown_effects
	for id in ["wind", "heal", "counter", "break", "protected"]:
		check(id in shown, "player displays " + id)
	check(game.ui.status_view.cards.heal.value.text.contains("+5"), "healing card displays the actual regeneration rate")
	game.sword_skills_open = true
	game.ui.refresh()
	check(not game.ui.status_panel.visible, "catalog hides combat status cards")
	game.sword_skills_open = false
	game.tick(5.5)
	check(game.ui.status_view.shown_effects.is_empty(), "expired player effects leave the HUD")
	game.add_sanity(game.frenzy_threshold() - game.STAND_UP_SANITY)
	game._iframes = 0.0
	game.damage_player(game.health + 1.0)
	check(game.stand_up(), "last stand can be entered at 200 sanity")
	game.ui.refresh()
	check("frenzy" in game.ui.status_view.shown_effects and "revelation" in game.ui.status_view.shown_effects, "both active sanity effects get an icon")
	game.queue_free()
	await process_frame
	print("STATUS ICONS: ", failures, " failures")
	quit(0 if failures == 0 else 1)
