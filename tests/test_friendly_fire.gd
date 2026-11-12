extends SceneTree

class StationaryCompanion extends "res://scripts/expedition_companion.gd":
	func tick(_delta: float, _game) -> void:
		pass

var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	printerr("FAIL: ", message)

func close(actual: float, expected: float, message: String) -> void:
	check(is_equal_approx(actual, expected), "%s (got %s, expected %s)" % [message, actual, expected])

func ally_at(at: Vector3) -> StationaryCompanion:
	var ally := StationaryCompanion.new()
	game.add_child(ally)
	game.companions.append(ally)
	ally.position = at
	return ally

func shoot(profile: Dictionary) -> void:
	var origin := Vector3(0, .85, 0)
	check(game.staff_flight.spawn_fireball(origin, Vector3.RIGHT, profile, game.camera), "projectile spawns")
	game.staff_flight.tick(1.0, game.enemies, game.get_world_3d(), Callable(), game.camera, game.companions)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.loadout.save_path = ""
	game.set_physics_process(false)
	game.start_run(true)
	game.clear_actors()
	game.stats.flat.critical_chance = -.05
	var ally := ally_at(Vector3(2, .03, 0))
	var enemy = game.spawn_enemy("dummy", Vector3(4, .03, 0))
	var ally_hp := ally.health
	var enemy_hp: float = enemy.health
	var bullet := {"element":"physical", "damage":20.0, "projectile_speed":15.0}
	await physics_frame
	shoot(bullet)
	close(ally.health, ally_hp - 4.0, "ordinary projectile deals twenty percent to the ally")
	close(enemy.health, enemy_hp, "ordinary projectile stops before the enemy")
	close(ally.hurt_left, 0.0, "friendly damage adds no hit reaction timer")
	check(game.hits == 0 and game.kills == 0, "ally damage does not count as enemy hits or kills")

	ally.health = ally_hp
	var rifle := bullet.duplicate()
	rifle.merge({"projectile_visual":"rifle", "pierce_after_exit":.55, "max_targets":2, "block_on_ally":true})
	shoot(rifle)
	close(ally.health, ally_hp - 4.0, "ordinary rifle can hit the ally despite its short enemy pierce")
	close(enemy.health, enemy_hp, "ordinary rifle stops at an ally")

	ally.health = ally_hp
	rifle.block_on_ally = false
	rifle.pierce_after_exit = 7.0
	rifle.max_targets = 1
	rifle.rifle_falloff = .25
	shoot(rifle)
	close(ally.health, ally_hp - 4.0, "piercing skill damages the ally once")
	close(enemy.health, enemy_hp - 20.0, "the ally uses no enemy penetration limit or falloff")

	ally.health = ally_hp
	enemy.health = enemy_hp
	var companion_bullet := bullet.duplicate()
	companion_bullet.companion_shot = true
	shoot(companion_bullet)
	close(ally.health, ally_hp, "companion projectiles keep targeting enemies")
	close(enemy.health, enemy_hp - 20.0, "companion projectile still reaches the enemy")

	ally.position = Vector3(4, .03, .9)
	var outside := ally_at(Vector3(4, .03, 4))
	var outside_hp := outside.health
	var ice := {"element":"ice", "center":enemy.position, "radius":1.6, "damage":10.0}
	var impacts: Array[Dictionary] = [ice]
	game._resolve_staff_ground_impacts(impacts)
	close(ally.health, ally_hp - 2.0, "area deals twenty percent to an ally inside it")
	close(outside.health, outside_hp, "area leaves an ally outside its radius alone")
	check(enemy.ice_root_remaining > 0.0 and ally.hurt_left == 0.0 and ally.retreat_left == 0.0, "ice roots enemies and deals only HP damage to allies")

	ally.position = Vector3(1.45, .03, 0)
	game.test_aim = Vector3.RIGHT
	game.set_weapon_family("sword")
	var melee_hp := ally.health
	check(game.request_attack(), "normal sword attack starts")
	var base_damage: float = game.motion.definition(game.motion.stage).damage
	for index in range(70): game.tick(.01)
	close(ally.health, melee_hp - base_damage * .2, "actual sword sweep hits the ally once")
	close(outside.health, outside_hp, "sword leaves the ally outside the swing alone")
	game.queue_free()
	await process_frame
	print("FRIENDLY FIRE: ", checks - failures, "/", checks, " passed")
	quit(0 if failures == 0 else 1)
