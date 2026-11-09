extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(true)
	game.clear_actors()
	game.test_aim = Vector3.RIGHT
	game._refresh_aim()
	game.set_weapon_family("shield")
	game.readiness.press(false)
	var front: Vector3 = game.player.position + Vector3.RIGHT * 2
	var hp: float = game.health
	game.incoming_attack(20, front, false, null, 1.0, "torso", 0.0, &"area")
	var area: bool = is_equal_approx(game.health, hp - 20) and is_equal_approx(game.stamina, 100)
	game._iframes = 0.0
	game.incoming_attack(20, front, false, null, 1.0, "torso", 0.0)
	var melee: bool = is_equal_approx(game.health, hp - 20) and is_equal_approx(game.stamina, 91)
	game.shoot(front + Vector3.UP * 0.6, Vector3.LEFT, 20.0, false, null, 1.0, 4.0, "torso", 0.0)
	for frame in 64: game.tick(1.0 / 120.0)
	var projectile: bool = is_equal_approx(game.health, hp - 20) and game.stamina < 91.0
	game._iframes = 0.0
	var before_hammer: float = game.health
	var before_stamina: float = game.stamina
	var hauler = game.spawn_enemy("net_hauler", front)
	hauler.attack_data = {"impact_offset": game.player.position - front, "shape": "lane", "reach": 0.0,
		"width": 1.0, "damage": 24.0, "parryable": false, "guard_cost": 1.5, "body_part": "torso", "body_damage": 0.0}
	hauler._resolve_attack(game)
	var hammer: bool = is_equal_approx(game.health, before_hammer - 24.0) and is_equal_approx(game.stamina, before_stamina)
	game._iframes = 0.0
	var before_poison: float = game.health
	game.brine_zones.spawn_lane(front, PI, 3.0, 1.0, hauler)
	game.brine_zones.tick(0.5, game)
	var poison: bool = is_equal_approx(game.health, before_poison - 2.0) and is_equal_approx(game.stamina, before_stamina)
	var passed := area and melee and projectile and hammer and poison
	print("MONSTER DELIVERY ", "PASS" if passed else "FAIL", " area=", area, " melee=", melee, " projectile=", projectile, " hammer=", hammer, " poison=", poison)
	quit(0 if passed else 1)
