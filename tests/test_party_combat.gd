extends SceneTree
const Look = preload("res://modular/scripts/city_npc_pose.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var entry = load("res://scenes/opening/coastal_combat_entry.tscn").instantiate()
	var look := Look.player_look()
	var party: Array[Dictionary] = [{"look":look, "weapon":"sword"},
		{"look":look, "weapon":"pistol"}, {"look":look, "weapon":"mace"}]
	entry.party = party
	root.add_child(entry)
	current_scene = entry
	var game = entry.game
	game.set_physics_process(false)
	game.start_dungeon(173)
	game.mode = "combat"
	var size: Vector2 = game.arena.HALF * 2
	var members: Variant = game.get("companions")
	if size.x * size.y < 1250 or not members is Array or members.size() != 2:
		printerr("Expected a roughly double-sized room and two active companions")
		quit(1)
		return
	game.clear_actors()
	game.dungeon.rooms[game.dungeon.current].enemies.clear()
	game.dungeon.rooms[game.dungeon.current].cleared = true
	var gunner = members[0]
	var guard = members[1]
	var dummy = game.spawn_enemy("dummy", guard.position + Vector3.RIGHT)
	var hp: float = dummy.health
	await physics_frame
	for frame in 360: game.tick(1.0/120.0)
	var fought: bool = dummy.health < hp and gunner.attacks_committed > 0 and guard.attacks_committed > 0
	game.recall_companions()
	for frame in 60: game.tick(1.0/120.0)
	var recalled: bool = gunner.recalling() and guard.recalling() and gunner.position.distance_to(game.player.position) < 3.5
	var health: float = guard.health
	var enemy = game.spawn_enemy("fisherman", guard.position - Vector3.RIGHT)
	enemy.attack_angle = 0.0
	enemy.attack_data = {"shape":"lane", "width":1.0, "reach":1.65, "projectiles":0, "damage":12.0,
		"parryable":false, "guard_cost":1.0, "body_part":"torso", "body_damage":0.0}
	enemy._resolve_attack(game)
	game.ui.refresh()
	var hurt: bool = guard.health == health - 12.0 and game.ui.companion_bars[1].value == guard.health
	guard.hurt_left = 0.0
	guard.receive_hit(100.0)
	var old_room: Dictionary = game.dungeon.rooms[game.dungeon.current]
	var direction: Vector2i = old_room.links.keys()[0]
	game.dungeon.enter(game, game.dungeon.current + direction, -direction)
	# Exercise reviving away from the doorway that starts a room transition.
	game.player.position = Vector3(0.0, .03, 0.0)
	game.place_companions()
	game.clear_actors()
	game.dungeon.rooms[game.dungeon.current].cleared = true
	var carries_down: bool = guard.get("downed") == true and guard.visible and gunner.visible
	var start: Vector3 = game.player.position
	game.player.position += Vector3.RIGHT * 4.0
	press_revive()
	for frame in 200: game.tick(1.0 / 120.0)
	var distant_rejected: bool = is_zero_approx(guard.health)
	press_revive(false)
	game.player.position = guard.position + Vector3.LEFT * 0.8
	press_revive()
	for frame in 90: game.tick(1.0 / 120.0)
	if not guard.downed:
		printerr("Revive completed before 1.5 seconds")
		quit(1)
		return
	press_revive(false)
	for frame in 110: game.tick(1.0 / 120.0)
	var release_resets: bool = guard.downed and is_zero_approx(game.revive_elapsed)
	press_revive()
	for frame in 75: game.tick(1.0 / 120.0)
	game.player.position = guard.position + Vector3.RIGHT * 3.0
	game.tick(1.0 / 120.0)
	game.player.position = guard.position + Vector3.LEFT * .8
	for frame in 200: game.tick(1.0 / 120.0)
	var distance_resets: bool = guard.downed and is_zero_approx(game.revive_elapsed)
	press_revive(false)
	press_revive()
	for frame in 75: game.tick(1.0 / 120.0)
	var hp_before: float = game.health
	game.damage_player(2.0, Vector3.INF, 1.0, "physical", "torso", 0.0)
	for frame in 110: game.tick(1.0 / 120.0)
	var hit_resets: bool = game.health < hp_before and guard.downed and is_zero_approx(game.revive_elapsed)
	press_revive(false)
	press_revive()
	for frame in 179: game.tick(1.0 / 120.0)
	var waits_full_duration: bool = guard.downed and game.revive_elapsed > 1.48
	game.tick(1.0 / 120.0)
	press_revive(false)
	var revived: bool = waits_full_duration and is_equal_approx(guard.health, guard.max_health() * .50) and guard.sanity == 40 and not guard.downed
	game.player.position = start
	game.clear_actors()
	game.dungeon.rooms[game.dungeon.current].cleared = true
	gunner.place(game.player.position + Vector3.LEFT * 1.4)
	gunner.cooldown = 0.0
	var close_target = game.spawn_enemy("dummy", gunner.position + Vector3.RIGHT * .9)
	var shots: int = gunner.attacks_committed
	var close_health: float = close_target.health
	await physics_frame
	for frame in 54: game.tick(1.0 / 120.0)
	var fired_under_pressure: bool = gunner.attacks_committed > shots and close_target.health < close_health
	gunner.hurt_left = 0.0
	var retreat_health: float = gunner.max_health() * .20
	gunner.receive_hit(gunner.health - retreat_health)
	var took_cover: bool = gunner.recalling() and is_equal_approx(gunner.health, retreat_health)
	shots = gunner.attacks_committed
	for frame in 360: game.tick(1.0/120.0)
	var waited: bool = gunner.recalling() and gunner.attacks_committed == shots
	for frame in 340: game.tick(1.0/120.0)
	var reengaged: bool = not gunner.recalling() and gunner.attacks_committed > shots and is_equal_approx(gunner.health, retreat_health)
	game.clear_actors()
	game.player.position = Vector3(0.0, .03, 0.0)
	gunner.place(Vector3(1.0, .03, 0.0))
	guard.place(Vector3(0.0, .03, -3.0))
	var attacker = game.spawn_enemy("fisherman", Vector3(-.15, .03, 0.0))
	attacker.attack_data = attacker._attack_definition(0)
	attacker.attack_angle = 0.0
	attacker.state = "windup"
	attacker.telegraph_left = .20
	var wall := StaticBody3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(.2, 2.0, .8)
	var wall_collision := CollisionShape3D.new()
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	game.add_child(wall)
	wall.position = Vector3(2.4, .9, 0.0)
	var origin: Vector3 = gunner.position
	var dodge_health: float = gunner.health
	var starting_stamina: float = gunner.stamina
	var attacks_before: int = gunner.attacks_committed
	await physics_frame
	await physics_frame
	for frame in 22: game.tick(1.0/120.0)
	var started: bool = gunner.dash_left > 0.0 and is_equal_approx(gunner.stamina, starting_stamina - 30.0)
	var exited_hitbox: bool = gunner.position.distance_to(origin) > 1.0 and not attacker.threatens(gunner.position)
	var avoided_wall: bool = absf(gunner.position.z - origin.z) > .6
	for frame in 26: game.tick(1.0/120.0)
	var safe: bool = is_equal_approx(gunner.health, dodge_health)
	for frame in 300: game.tick(1.0/120.0)
	var resumed: bool = gunner.attacks_committed > attacks_before
	var passed := fought and recalled and hurt and carries_down and distant_rejected and release_resets and distance_resets and hit_resets and revived and fired_under_pressure and took_cover and waited and reengaged and started and exited_hitbox and avoided_wall and safe and resumed
	print("PARTY COMBAT ", "PASS" if passed else "FAIL", " room=", size, " both attack=", fought, " recall=", recalled, " damage=", hurt, " downed=", carries_down, " distant rejected=", distant_rejected, " reset(release, distance, hit)=", [release_resets, distance_resets, hit_resets], " revived=", revived, " close shot=", fired_under_pressure, " low HP retreat=", took_cover and waited, " reengaged=", reengaged, " dash=", started, " outside=", exited_hitbox, " avoided wall=", avoided_wall, " safe=", safe, " resumed=", resumed)
	quit(0 if passed else 1)

func press_revive(pressed: bool = true) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = pressed
	root.push_input(key, true)
