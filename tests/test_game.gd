extends SceneTree

var checks := 0
var failures: Array[String] = []
var game: Node3D
const STEP := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	# Removing the playable owner script must fail before scene setup.
	_check(FileAccess.file_exists("res://scripts/game.gd"), "playable main game exists")
	if not failures.is_empty():
		_finish()
		return
	var scene = load("res://scenes/game.tscn")
	_check(scene is PackedScene, "playable scene loads")
	if not scene is PackedScene:
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	_check(game.mode == "menu", "launch opens the menu")
	_check(game.player is CharacterBody3D, "player uses a real collision body")
	_check(game.camera is Camera3D, "play space uses the real game camera")
	await _test_movement_and_aim()
	await _test_physical_input()
	_test_attack_timing_and_combo()
	_test_misses()
	_test_dodge()
	_test_enemy_telegraph()
	_test_pause_and_death()
	await _test_wave_progression()
	game.queue_free()
	await process_frame
	_finish()


func _fresh(practice: bool = true) -> void:
	game.start_run(practice)
	game.set_weapon_family("sword")
	game.set_physics_process(false)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT


func _step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var dt: float = minf(STEP, remaining)
		game.tick(dt)
		remaining -= dt


func _dummy() -> Node3D:
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null


func _wait_for_sword_recovery() -> bool:
	for frame_index in range(300):
		if not game.motion.busy:
			return true
		game.tick(STEP)
	return false


func _test_movement_and_aim() -> void:
	# A missing move_and_slide call or screen-space aim inversion breaks these.
	_fresh()
	var from: Vector3 = game.player.position
	game.move_input = Vector2(1.0, 0.0)
	for index in range(24):
		await physics_frame
		game.tick(STEP)
	_check(game.player.position.distance_to(from) > 0.35, "WASD input moves the real player body")
	_check(game.player.position.x > from.x, "right input moves toward arena right")
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.ZERO
	var target: Vector3 = game.player.global_position + Vector3(2.0, 0.0, 1.0)
	var mouse := InputEventMouseMotion.new()
	mouse.position = game.camera.unproject_position(target)
	mouse.global_position = mouse.position
	root.push_input(mouse)
	game.tick(STEP)
	var expected: Vector3 = (target - game.player.global_position).normalized()
	var actual: Vector3 = game.aim.normalized()
	_check(actual.dot(expected) > 0.97, "camera projects mouse position into a ground-plane aim direction")
	var stopped: Vector3 = game.player.position
	for index in range(8):
		await physics_frame
		game.tick(STEP)
	_check(game.player.position.distance_to(stopped) < 0.12, "releasing movement input stops player movement")


func _test_physical_input() -> void:
	# Broken actual key/mouse bindings must not hide behind the direct control API.
	_fresh()
	var from: Vector3 = game.player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for frame_index in range(16):
		await physics_frame
		game._physics_process(STEP)
	var key_release: InputEventKey = key.duplicate()
	key_release.pressed = false
	Input.parse_input_event(key_release)
	Input.flush_buffered_events()
	_check(game.player.position.x > from.x + 0.25, "physical D key drives actual movement binding")
	_fresh()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(700, 400)
	click.global_position = click.position
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	_check(game.motion.busy, "physical left mouse click starts the sword attack (mode=%s)" % game.mode)
	var click_release: InputEventMouseButton = click.duplicate()
	click_release.pressed = false
	Input.parse_input_event(click_release)
	Input.flush_buffered_events()
	_wait_for_sword_recovery()
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	var initial: float = game.stamina
	Input.parse_input_event(space)
	Input.flush_buffered_events()
	await process_frame
	_check(game.stamina < initial - 5.0, "physical Space key starts the dodge binding")
	var space_release: InputEventKey = space.duplicate()
	space_release.pressed = false
	Input.parse_input_event(space_release)
	Input.flush_buffered_events()


func _test_attack_timing_and_combo() -> void:
	# Removing windup, hit-once tracking, recovery, or the finisher breaks these.
	_fresh()
	var target := _dummy()
	_check(target != null, "practice creates an actual damageable target")
	if target == null:
		return
	_check(game.request_attack(), "first sword attack starts")
	var initial: float = target.health
	_step(0.10)
	_check(is_equal_approx(target.health, initial), "sword windup cannot deal instant damage")
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	_check(not game.request_dodge(Vector3.LEFT), "unaffordable dodge preserves opening sword windup")
	_step(0.17)
	var first_damage: float = initial - target.health
	_check(is_equal_approx(first_damage, 18.0), "first active sword sweep deals 18 damage")
	_step(0.05)
	_check(is_equal_approx(initial - target.health, 18.0), "one sword sweep cannot damage the target twice")
	_check(_wait_for_sword_recovery(), "first sword strike reaches the end of recovery")
	_check(game.request_attack(), "second combo strike starts after first recovery")
	var before_second: float = target.health
	_step(0.28)
	var second_damage: float = before_second - target.health
	_check(is_equal_approx(second_damage, 19.0), "second combo strike deals 19 damage")
	_check(_wait_for_sword_recovery(), "second sword strike reaches the end of recovery")
	_check(game.request_attack(), "third combo strike starts after second recovery")
	var before_third: float = target.health
	_step(0.16)
	_check(is_equal_approx(target.health, before_third), "heavy finisher preserves its longer windup")
	_step(0.29)
	var third_damage: float = before_third - target.health
	_check(is_equal_approx(third_damage, 34.0), "heavy third strike deals 34 damage")
	_check(third_damage > first_damage and third_damage > second_damage, "combo finisher is materially stronger than basic strikes")
	_check(_wait_for_sword_recovery(), "heavy finisher reaches the end of recovery")
	_step(0.30)
	_check(is_instance_valid(_dummy()), "practice target remains available after the combo")
	_check(is_equal_approx(_dummy().health, 1000.0), "practice target restores health between attempts")
	game.enemy_hit(_dummy(), 2000.0, Vector3.ZERO)
	_step(1.2)
	_check(is_instance_valid(_dummy()), "lethal practice damage automatically restores a target")
	if is_instance_valid(_dummy()):
		_check(is_equal_approx(_dummy().health, 1000.0), "restored practice target has full health")


func _test_misses() -> void:
	# A radius-only or unbounded sword hit check breaks these.
	_fresh()
	var target := _dummy()
	if target == null:
		return
	var initial: float = target.health
	game.test_aim = Vector3.LEFT
	game.request_attack()
	_step(0.24)
	_check(is_equal_approx(target.health, initial), "aiming away from the target makes the sword miss")
	_fresh()
	target = _dummy()
	if target == null:
		return
	# Preserve this far-miss fixture outside v15's doubled4.2 search radius.
	target.position = Vector3(4.4, 0.0, 0.0)
	initial = target.health
	game.request_attack()
	_step(0.24)
	_check(is_equal_approx(target.health, initial), "a sword attack cannot hit beyond its physical reach")


func _test_dodge() -> void:
	# Free/repeat dodges or damage during invulnerability break these.
	_fresh()
	var initial_stamina: float = game.stamina
	_check(game.request_dodge(Vector3.LEFT), "dodge starts while player is idle")
	_check(game.stamina < initial_stamina - 5.0, "dodge pays a visible stamina cost")
	_check(not game.request_dodge(Vector3.LEFT), "an active dodge cannot be started again")
	var initial_health: float = game.health
	game.damage_player(12.0)
	_check(is_equal_approx(game.health, initial_health), "dodge invulnerability prevents incoming damage")
	_step(0.8)
	game.damage_player(12.0)
	_check(is_equal_approx(game.health, initial_health - 12.0), "damage resumes after dodge invulnerability ends")
	_step(4.0)
	_check(game.stamina > initial_stamina - 2.0, "stamina recovers after a dodge")
	game.stamina = 0.0
	_check(not game.request_dodge(Vector3.LEFT), "empty stamina prevents dodge")


func _test_enemy_telegraph() -> void:
	# Immediate enemy damage or a telegraph that never resolves breaks these.
	_fresh(false)
	for enemy in game.enemies:
		if is_instance_valid(enemy):
			enemy.position = Vector3(12.0, 0.0, 12.0)
	var attacker: Node3D = game.spawn_enemy("melee", game.player.position + Vector3(1.0, 0.0, 0.0))
	var initial: float = game.health
	var saw_windup := false
	for index in range(180):
		game.tick(STEP)
		if attacker.state == "windup":
			saw_windup = true
			break
	_check(saw_windup, "nearby enemy visibly enters a telegraphed attack")
	_check(is_equal_approx(game.health, initial), "enemy telegraph precedes player damage")
	if saw_windup:
		var lead_time: float = attacker.telegraph_left
		_check(lead_time >= 0.20, "enemy telegraph gives a readable reaction window")
		_step(maxf(lead_time - 0.03, 0.0))
		_check(is_equal_approx(game.health, initial), "player stays unharmed until the enemy windup ends")
		_step(0.10)
		_check(game.health < initial, "committed enemy attack deals real player damage")


func _test_pause_and_death() -> void:
	# Lost pause guards or restart failing to reset run state breaks these.
	_fresh(false)
	game.toggle_pause()
	_check(game.mode == "paused", "pause changes the run to paused mode")
	var initial: float = game.health
	_step(2.0)
	_check(is_equal_approx(game.health, initial), "paused run cannot receive enemy tick damage")
	_check(not game.request_attack(), "paused run cannot start a sword attack")
	game.toggle_pause()
	_check(game.mode == "combat", "unpause restores combat")
	game.damage_player(1000.0)
	_check(game.mode == "dead", "lethal damage enters the defeat state")
	_check(is_zero_approx(game.health), "player health clamps at zero on defeat")
	_check(not game.request_attack(), "defeated player cannot start attacks")
	game.restart()
	_check(game.mode == "combat", "restart begins a fresh combat run")
	_check(is_equal_approx(game.health, 100.0), "restart restores full player health")
	_check(game.wave == 1 and game.kills == 0, "restart resets wave and kill progression")


func _test_wave_progression() -> void:
	# Premature victory, missing spawns, or stalled next-wave transitions break these.
	_fresh(false)
	_check(game.wave == 1, "combat starts at the first wave")
	_check(game.enemies.size() == 3, "first wave creates three real enemies")
	var observed_waves: Array[int] = [game.wave]
	for round_index in range(18):
		if game.mode == "victory":
			break
		var targets: Array = game.enemies.duplicate()
		for enemy in targets:
			if is_instance_valid(enemy) and not enemy.dead:
				game.enemy_hit(enemy, enemy.health + 1.0, Vector3.ZERO)
		_step(2.5)
		await process_frame
		if not observed_waves.has(game.wave):
			observed_waves.append(game.wave)
	_check(observed_waves == [1, 2, 3], "combat progresses through all three configured waves")
	_check(game.mode == "victory", "clearing the final real enemy completes the run")
	_check(game.kills == 11, "victory counts all eleven defeated wave enemies")
	_check(not game.request_attack(), "completed run does not keep accepting combat input")


func _finish() -> void:
	print("GAME TESTS: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
