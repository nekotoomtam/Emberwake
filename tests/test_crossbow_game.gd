extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var entry = load("res://scenes/opening/coastal_combat_entry.tscn").instantiate()
	root.add_child(entry)
	current_scene = entry
	var game = entry.game
	game.set_physics_process(false)
	game.start_run(true)
	game.clear_actors()
	game.mode = "combat"
	if not game.set_weapon_family("crossbow"):
		printerr("Crossbow cannot be equipped")
		quit(1)
		return
	game.test_aim = Vector3.RIGHT
	await physics_frame
	await physics_frame
	var magazine = game.crossbow_magazine()
	var target = game.spawn_enemy("dummy", game.player.position + Vector3.RIGHT * 2.0)
	var before: float = target.health
	var passed: bool = not game.request_attack() and game.request_reload()
	for frame in 35: game.tick(1.0 / 120.0)
	passed = passed and not game.request_attack() and game.request_dodge(Vector3.FORWARD)
	passed = passed and not magazine.reloading and magazine.rounds == 0
	for frame in 65: game.tick(1.0 / 120.0)
	game.player.position = target.position - Vector3.RIGHT * 2.0
	passed = passed and game.request_reload()
	for frame in 150: game.tick(1.0 / 120.0)
	passed = passed and magazine.can_fire()
	game.set_weapon_family("sword")
	game.set_weapon_family("crossbow")
	passed = passed and game.request_attack() and not game.request_attack()
	for frame in 28: game.tick(1.0 / 120.0)
	var impact_health: float = target.health
	passed = passed and impact_health < before and target.crossbow_wound_ticks == 4
	for frame in 510: game.tick(1.0 / 120.0)
	passed = passed and target.health < impact_health and target.crossbow_wound_ticks == 0
	var wound_damage: float = impact_health - target.health
	game.start_dungeon(173)
	var room: Dictionary = game.dungeon.rooms[game.dungeon.current]
	var path: Vector2i = room.links.keys()[0]
	passed = passed and not game.crossbow_magazine().can_fire() and game.request_reload()
	for frame in 150: game.tick(1.0 / 120.0)
	passed = passed and game.crossbow_magazine().can_fire()
	game.dungeon.enter(game, game.dungeon.current + path, -path)
	passed = passed and game.crossbow_magazine().can_fire()
	print("Crossbow ", "PASS" if passed else "FAIL", " impact=", before - impact_health, " wound=", wound_damage)
	quit(0 if passed else 1)
