extends SceneTree
## Balance proof through the same attack, aim, movement, dodge and tick API as play.
## Never edits health, damage, enemy state, weapon timing or actor positions.
## --fixed-fps 120 --disable-vsync --script res://tests/playthrough_bot.gd
## Optional visible-render capture: -- --output=C:/absolute/path/playthrough.png

const Game = preload("res://scripts/game.gd")
const STEP := 1.0 / 120.0
const TIME_LIMIT := 120.0
var game
var attack_inputs := 0
var dodge_inputs := 0
var heavy_inputs := 0
var last_wave := 0
var output_path := ""
var captured := false
var weapon_family := "rifle"
var use_loadout := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--loadout": use_loadout = true
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--family="):
			weapon_family = argument.trim_prefix("--family=")
	call_deferred("run_trial")

func run_trial() -> void:
	seed(50521)
	Engine.physics_ticks_per_second = 120
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	game.start_run(false)
	if use_loadout:
		game.loadout.save_path = ""
		game.loadout.defaults()
		game.loadout_edited()
	if not use_loadout and not game.set_weapon_family(weapon_family):
		printerr("PLAYTHROUGH FAILED: cannot select family ", weapon_family)
		quit(3)
		return
	while game.mode == "combat" and game.run_time < TIME_LIMIT:
		choose_inputs()
		game.tick(STEP)
		if game.wave != last_wave:
			last_wave = game.wave
			print("PLAYTHROUGH_WAVE: %d time=%.2f health=%.0f kills=%d" % [game.wave, game.run_time, game.health, game.kills])
		if not captured and not output_path.is_empty() and game.wave >= 2 and game.motion.busy and game.motion.sample().phase == "active":
			await capture_frame()
		await physics_frame
	game.move_input = Vector2.ZERO
	if not output_path.is_empty() and not captured:
		await capture_frame()
	var result := {
		"mode": game.mode,
		"weapon_family": game.weapon_family,
		"loadout_mode": game.loadout_mode,
		"victory": game.mode == "victory",
		"dead": game.mode == "dead",
		"seconds": snappedf(game.run_time, 0.01),
		"wave": game.wave,
		"health": game.health,
		"hits": game.hits,
		"kills": game.kills,
		"damage": game.total_damage,
		"attack_inputs": attack_inputs,
		"heavy_inputs": heavy_inputs,
		"dodge_inputs": dodge_inputs,
		"capture": output_path if captured else "",
		"living": living_summary(),
	}
	print("PLAYTHROUGH_RESULT: " + JSON.stringify(result))
	quit(0 if game.mode == "victory" else (1 if game.mode == "dead" else 2))

func choose_inputs() -> void:
	game.move_input = Vector2.ZERO
	var nearest = null
	var nearest_distance := INF
	var danger_direction := Vector3.ZERO
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var offset: Vector3 = enemy.position - game.player.position
		offset.y = 0
		var distance: float = offset.length()
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
		if enemy.state == "windup" and enemy.telegraph_left < 0.18 and distance < 3.0:
			danger_direction -= offset.normalized()
	if nearest == null:
		game.test_aim = Vector3.ZERO
		return
	var toward: Vector3 = nearest.position - game.player.position
	toward.y = 0
	game.test_aim = toward
	# Dodge only through the normal stamina/cooldown/weapon availability gates.
	if not game.motion.busy:
		var away: Vector3 = -toward.normalized()
		if danger_direction.length_squared() > 0.01:
			away = danger_direction.normalized()
		elif game.health < 25.0 and nearest_distance < 1.25:
			# Low health creates breathing room, without replenishing it.
			danger_direction = away
		if danger_direction.length_squared() > 0.01 and game.request_dodge(away):
			dodge_inputs += 1
			return
	if game.motion.busy:
		return
	# Hold feet for the follow-up window, allowing the heavy third hit to occur.
	var chain_available: bool = game._next_combo > 0 and game._idle_time < 0.80
	var attack_range := 2.15 if chain_available else 1.5
	if weapon_family == "mace":
		attack_range = 1.80 if chain_available else 1.35
	var clear_shot := true
	if weapon_family in ["staff", "pistol", "rifle"]:
		attack_range = 5.4 if weapon_family == "staff" else (6.5 if weapon_family == "rifle" else 6.0)
		var muzzle_height: float = 1.58 if weapon_family == "staff" else .80
		var origin: Vector3 = game.player.position + Vector3.UP * muzzle_height
		var target: Vector3 = nearest.position + Vector3.UP * muzzle_height
		clear_shot = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, target, 1)).is_empty()
	if nearest_distance <= attack_range and clear_shot:
		var stage: int = game._next_combo
		if game.request_attack():
			attack_inputs += 1
			if stage == 2:
				heavy_inputs += 1
		return
	# Camera looks down -Z: input X/Y maps to world X/Z. Small obstacle steering
	# retains real collision instead of moving or teleporting the player directly.
	var direction := toward.normalized()
	for obstacle: Vector3 in game.arena.obstacles:
		var away: Vector3 = game.player.position - obstacle
		away.y = 0
		var distance: float = away.length()
		if distance < 1.7 and away.dot(direction) < 0.35:
			direction += away.normalized() * (1.7 - distance) * 2.2
	direction = direction.normalized()
	game.move_input = Vector2(direction.x, direction.z)

func living_summary() -> Array:
	var result := []
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			result.append({"kind": enemy.kind, "health": enemy.health, "state": enemy.state, "distance": snappedf(enemy.position.distance_to(game.player.position), 0.01)})
	return result

func capture_frame() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		var error := image.save_png(output_path)
		captured = error == OK
		print("PLAYTHROUGH_CAPTURE: %s error=%d" % [output_path, error])
