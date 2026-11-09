extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(true)
	game.test_aim = Vector3.RIGHT
	game._refresh_aim()
	if not game.set_weapon_family("shield"):
		printerr("Shield cannot be equipped")
		quit(1)
		return
	var max_hp: float = game.health
	var front: Vector3 = game.player.position + Vector3.RIGHT * 2
	game.readiness.press(false)
	game.stamina = 40
	game.damage_player(20, front)
	var absorbed: bool = is_equal_approx(game.health, max_hp) and is_equal_approx(game.stamina, 31.0)
	game.stamina = 4
	game.damage_player(20, front)
	var overflow: bool = is_equal_approx(game.health, max_hp - 5) and is_zero_approx(game.stamina)
	game.damage_player(20, front)
	var exhausted: bool = is_equal_approx(game.health, max_hp - 14) and game.right_action() == "guard"
	game.stamina = 40
	game.damage_player(20, game.player.position - Vector3.RIGHT * 2)
	var rear: bool = is_equal_approx(game.health, max_hp - 34) and is_equal_approx(game.stamina, 40.0)
	game._iframes = 0
	game.set_weapon_family("sword")
	game.damage_player(20, front)
	var sword: bool = is_equal_approx(game.health, max_hp - 48) and is_equal_approx(game.stamina, 40.0)
	game.loadout.save_path = ""
	game.loadout.defaults()
	game.loadout.move_item({"kind":"bag","index":game.loadout.bag.find("shield0")},{"kind":"slot","set":0,"hand":"off"})
	game.loadout_edited()
	game.readiness.release()
	var combo: bool = game.request_attack() and not game.pair_strikes.active and game.weapon_family == "sword"
	var passed := absorbed and overflow and exhausted and rear and sword and combo
	print("Shield ", "PASS" if passed else "FAIL", " absorption=", absorbed, " overflow=", overflow, " exhausted=", exhausted, " rear=", rear, " sword=", sword, " paired=", combo)
	quit(0 if passed else 1)
