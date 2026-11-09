extends Node3D
## A playable, bounded combat trial: pixel bodies, independently weighted blade.
const Motion = preload("res://scripts/weapon_motion.gd")
const Hero = preload("res://scripts/hero_visual.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Arena = preload("res://scripts/arena.gd")
const Effects = preload("res://scripts/effects.gd")
const HUD = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio.gd")
const ShortLunge = preload("res://scripts/short_lunge.gd")
const StaffFlight = preload("res://scripts/staff_projectiles.gd")
const Magazine = preload("res://scripts/magazine.gd")
const CasingFX = preload("res://scripts/casing_fx.gd")

var player: CharacterBody3D
var camera: Camera3D
var avatar: Node3D
var arena: Node3D
var fx: Node3D
var ui: CanvasLayer
var audio: Node
var enemies: Array = []
var projectiles: Array[Dictionary] = []
var motion = Motion.new()
var weapon_family: String = "rifle"
var staff_flight: Node3D
var pistol_magazine = Magazine.new()
var rifle_magazine = Magazine.new()
var casing_fx: Node3D
var rifle_recoil_travelled := 0.0
var _rifle_recoil = ShortLunge.new()
var mace_dash_travelled: float = 0.0
var _short_lunge = ShortLunge.new()
var mode: String = "menu"
var wave: int = 0
var kills: int = 0
var hits: int = 0
var health: float = 100.0
var stamina: float = 100.0
var total_damage: float = 0.0
var run_time: float = 0.0
var move_input := Vector2.ZERO
var test_aim := Vector3.ZERO
var aim := Vector3.RIGHT
var debug_range: bool = false
var _held: bool = false
var _practice: bool = true
var _next_combo: int = 0
var _idle_time: float = 0.0
var _dummy_idle: float = 0.0
var _hit_stop: float = 0.0
var _hit_targets: Dictionary = {}
var _hurt: float = 0.0
var _iframes: float = 0.0
var _dodge_left: float = 0.0
var _dodge_dir := Vector3.RIGHT
var _dodge_recharge: float = 0.0
var _shake: float = 0.0
var _wave_wait: float = 0.0
var _previous_mode: String = "practice"
var _camera_focus := Vector3.ZERO
var _range_clock: float = 0.0
var _trail_clock: float = 0.0
var _mouse_position := Vector2.ZERO
const CAMERA_OFFSET := Vector3(0, 12.5, 11.5)

func _ready() -> void:
	_bind_inputs()
	motion.set_family("pistol")
	pistol_magazine.configure(motion.definition(0))
	motion.set_family("rifle")
	rifle_magazine.configure(motion.definition(0))
	arena = Arena.new()
	add_child(arena)
	fx = Effects.new()
	add_child(fx)
	casing_fx = CasingFX.new()
	add_child(casing_fx)
	staff_flight = StaffFlight.new()
	add_child(staff_flight)
	staff_flight.damage_hit.connect(_projectile_damage)
	staff_flight.impact_element.connect(_projectile_impact)
	player = CharacterBody3D.new()
	player.name = "Ember"
	player.collision_layer = 4
	player.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.35
	collision.shape = shape
	collision.position.y = 0.68
	player.add_child(collision)
	add_child(player)
	avatar = Hero.new()
	player.add_child(avatar)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	camera.current = true
	add_child(camera)
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	audio = Audio.new()
	audio.ambient_enabled = false
	audio.volume_db = -14.0
	add_child(audio)
	ui = HUD.new()
	ui.game = self
	add_child(ui)
	set_weapon_family("rifle")
	_mouse_position = get_viewport().get_visible_rect().size * Vector2(0.65, 0.5)
	_visual_tick(0)
	DisplayServer.window_set_title("Emberwake — Rifle v09")

func _bind_inputs() -> void:
	for entry in [["move_left", KEY_A], ["move_right", KEY_D], ["move_up", KEY_W], ["move_down", KEY_S]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		InputMap.action_add_event(entry[0], event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_held = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_position = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_held = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if mode in ["practice", "combat"]:
			_held = true
			_refresh_aim()
			request_attack()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		match key:
			KEY_SPACE: request_dodge()
			KEY_ESCAPE: toggle_pause()
			KEY_R: request_reload()
			KEY_T: restart()
			KEY_H: debug_range = not debug_range
			KEY_M: audio.set_enabled(not audio.enabled)
			KEY_G: cycle_weapon()

func cycle_weapon() -> bool:
	var families: Array[String] = ["rifle", "pistol", "staff", "mace", "greatsword", "sword"]
	return set_weapon_family(families[(families.find(weapon_family) + 1) % families.size()])

func set_weapon_family(value: String) -> bool:
	if value not in ["sword", "greatsword", "mace", "staff", "pistol", "rifle"] or mode not in ["menu", "practice", "combat"] or motion.busy or _dodge_left > 0 or guns_reloading():
		return false
	if not motion.set_family(value): return false
	if not avatar.set_weapon_family(value): return false
	weapon_family = value
	motion.reset()
	_next_combo = 0
	_idle_time = 0
	_held = false
	_hit_targets.clear()
	_short_lunge.reset()
	mace_dash_travelled = 0
	_rifle_recoil.reset()
	rifle_recoil_travelled = 0
	if is_instance_valid(ui): ui.refresh()
	return true

func start_run(practice: bool = false) -> void:
	clear_actors()
	_practice = practice
	mode = "practice" if practice else "combat"
	wave = 0
	kills = 0
	hits = 0
	total_damage = 0
	health = 100
	stamina = 100
	reset_gun_magazines()
	run_time = 0
	motion.reset()
	_short_lunge.reset()
	mace_dash_travelled = 0
	_next_combo = 0
	_idle_time = 0
	_dummy_idle = 0
	_held = false
	_dodge_left = 0
	_dodge_recharge = 0
	_iframes = 0
	_hurt = 0
	_hit_stop = 0
	_shake = 0
	_wave_wait = 0
	_hit_targets.clear()
	player.position = Vector3(0, 0.03, 0)
	player.velocity = Vector3.ZERO
	aim = Vector3.RIGHT
	_camera_focus = Vector3.ZERO
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	if practice:
		spawn_enemy("dummy", Vector3(2, 0.03, 0))
	else:
		spawn_wave()
	ui.show_mode(mode)
	_visual_tick(0)

func clear_actors() -> void:
	if is_instance_valid(staff_flight): staff_flight.clear()
	if is_instance_valid(casing_fx): casing_fx.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):
			remove_child(enemy)
			enemy.queue_free()
	enemies.clear()
	for entry in projectiles:
		if is_instance_valid(entry.node): entry.node.queue_free()
	projectiles.clear()

func restart() -> void:
	start_run(_practice)

func return_menu() -> void:
	clear_actors()
	reset_gun_magazines()
	mode = "menu"
	motion.reset()
	_held = false
	_shake = 0
	_hurt = 0
	health = 100
	stamina = 100
	ui.show_mode(mode)

func toggle_pause() -> void:
	_held = false
	if mode in ["combat", "practice"]:
		_previous_mode = mode
		mode = "paused"
	elif mode == "paused":
		mode = _previous_mode
	else:
		return
	ui.show_mode(mode)

func _refresh_aim() -> void:
	if motion.busy: return
	if test_aim.length_squared() > 0.001:
		aim = Vector3(test_aim.x, 0, test_aim.z).normalized()
	else:
		var origin := camera.project_ray_origin(_mouse_position)
		var ray := camera.project_ray_normal(_mouse_position)
		if absf(ray.y) > 0.001:
			var point: Vector3 = origin + ray * (-origin.y / ray.y)
			var direction := point - player.global_position
			direction.y = 0
			if direction.length_squared() > 0.1: aim = direction.normalized()
	motion.rebase_idle_aim(atan2(aim.z, aim.x))

func _reset_idle_combo() -> void:
	if motion.busy: return
	if _movement().length_squared() > 0.01 or _idle_time > 0.85:
		_next_combo = 0
		if weapon_family in ["greatsword", "mace"] and motion.stage >= 0: motion.reset()

func request_attack() -> bool:
	if mode not in ["practice", "combat"] or motion.busy or _dodge_left > 0 or guns_reloading(): return false
	if weapon_family in ["pistol", "rifle"] and not active_magazine().can_fire():
		request_reload()
		return false
	_reset_idle_combo()
	_refresh_aim()
	if weapon_family in ["staff", "pistol", "rifle"]: _next_combo = 0
	if not motion.start(_next_combo, atan2(aim.z, aim.x)): return false
	if weapon_family == "rifle":
		_rifle_recoil.reset()
		rifle_recoil_travelled = 0
	if weapon_family == "mace" and _next_combo in [0, 1]:
		_short_lunge.reset()
		mace_dash_travelled = 0
	_idle_time = 0
	_dummy_idle = 0
	_hit_targets.clear()
	if weapon_family not in ["pistol", "rifle"]: audio.play("windup" if _next_combo == 2 else "equip")
	return true

func request_reload() -> bool:
	if weapon_family not in ["pistol", "rifle"] or mode not in ["practice", "combat"] or motion.busy or _dodge_left > 0:
		return false
	if not active_magazine().start_reload(): return false
	audio.play("reload")
	_visual_tick(0)
	return true

func request_dodge(direction: Vector3 = Vector3.ZERO) -> bool:
	if mode not in ["practice", "combat"] or motion.busy or guns_reloading() or _dodge_left > 0 or stamina < 30 or _dodge_recharge > 0:
		return false
	var movement := _movement()
	_dodge_dir = direction.normalized() if direction.length_squared() > 0.001 else (movement.normalized() if movement.length_squared() > 0.001 else aim)
	_dodge_dir.y = 0
	stamina -= 30
	_dodge_left = 0.24
	_dodge_recharge = 0.42
	_iframes = 0.25
	_next_combo = 0
	audio.play("dodge")
	fx.ring(player.position, 0.6, Color(0.5, 0.9, 0.9, 0.5), 0.22)
	return true

func _movement() -> Vector3:
	var input := move_input if move_input.length_squared() > 0 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0
	forward.y = 0
	return (right.normalized() * input.x - forward.normalized() * input.y).limit_length(1)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	_shake = maxf(0, _shake - delta * 0.65)
	if mode not in ["combat", "practice"]:
		if mode != "paused":
			fx.tick(delta)
			_visual_tick(delta)
		return
	run_time += delta
	fx.tick(delta)
	casing_fx.tick(delta, camera)
	if _hit_stop > 0:
		_hit_stop -= delta
		_visual_tick(delta)
		return
	_hurt = maxf(0, _hurt - delta)
	_iframes = maxf(0, _iframes - delta)
	_dodge_recharge = maxf(0, _dodge_recharge - delta)
	_dodge_left = maxf(0, _dodge_left - delta)
	stamina = minf(100, stamina + delta * (26 if _dodge_recharge <= 0 else 3))
	for magazine in [pistol_magazine, rifle_magazine]:
		if magazine.tick(delta): audio.play("reload_done")
	_refresh_aim()
	var movement := _movement()
	if not motion.busy:
		_idle_time += delta
		_reset_idle_combo()
		if weapon_family in ["pistol", "rifle"] and active_magazine().rounds == 0: request_reload()
		if _held: request_attack()
	var prior_sample: Dictionary = motion.sample()
	var step: Dictionary = motion.advance(delta)
	var sample: Dictionary = motion.sample()
	var rifle_release: Dictionary = {}
	if weapon_family == "rifle" and motion.stage == 0:
		_apply_rifle_recoil(sample.get("recoil_offset", 0.0))
	if weapon_family in ["staff", "pistol", "rifle"] and step.get("projectile_ready", false):
		if weapon_family == "rifle":
			rifle_release = step.release_pose
		else:
			_release_ranged(step.release_pose)
	var mace_dash: bool = weapon_family == "mace" and motion.stage == 1
	if mace_dash:
		var desired: float = sample.get("lunge_offset", 0.0)
		if step.get("damage_ready", false) and not step.get("contact_pose", {}).is_empty():
			desired = step.contact_pose.lunge_offset
		_apply_mace_travel(desired)
	if step.entered_active and weapon_family not in ["staff", "pistol", "rifle"]:
		audio.play(("guard" if mace_dash else "heavy") if weapon_family == "mace" else ("heavy" if motion.stage == 2 else "sword"))
	if step.active and weapon_family not in ["staff", "pistol", "rifle"]:
		var definition: Dictionary = motion.definition(motion.stage)
		var blade_direction := Vector3(cos(step.current_angle), 0, sin(step.current_angle))
		var slam: bool = definition.get("kind", "sweep") == "slam"
		var vertical: bool = definition.get("kind", "sweep") in ["lift", "slam"]
		if _trail_clock <= 0 and vertical:
			fx.blade_ribbon(player.position, motion.aim_angle, sample.radius, sample.blade_length, prior_sample.get("pitch", 0.0), sample.pitch, prior_sample.get("grip_height", 0.8), sample.grip_height, Color(1, 0.79, 0.42, 0.65), 0.11)
			_trail_clock = 0.016
		elif _trail_clock <= 0:
			var color := Color(1, 0.76, 0.32, 0.75) if motion.stage == 2 else Color(0.55, 0.95, 0.91, 0.7)
			var swing_sign: float = signf(float(step.current_angle) - float(step.previous_angle))
			if swing_sign != 0:
				fx.sector(player.position + Vector3(0, 0.68, 0), definition.reach, step.current_angle - swing_sign * 0.72, step.current_angle, color, definition.reach * 0.5, 0.12)
				fx.sector(player.position + Vector3(0, 0.69, 0), definition.reach, step.current_angle - swing_sign * 0.4, step.current_angle, Color(1, 1, 0.85, 0.9), definition.reach - 0.07, 0.09)
			_trail_clock = 0.02
		if step.get("damage_ready", step.active):
			if slam:
				var tip: Vector3 = player.position + Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle)) * definition.reach
				fx.lane(player.position, motion.aim_angle, definition.reach, definition.width, Color(1, 0.78, 0.38, 0.24), 0.14)
				fx.burst(tip + Vector3(0, 0.07, 0), Color("#ffd18b"), 12)
				audio.play("slam")
				_shake = maxf(_shake, 0.025)
			for enemy in enemies:
				if not is_instance_valid(enemy) or enemy.dead or _hit_targets.has(enemy.get_instance_id()): continue
				if motion.is_target_hit(player.position, enemy.position, 0.36 if enemy.kind != "elite" else 0.55, step.previous_angle, step.current_angle):
					_hit_targets[enemy.get_instance_id()] = true
					var force: float = definition.get("knockback", 7.0 if motion.stage == 2 else 3.5)
					var hit_direction: Vector3 = Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle)) if weapon_family == "mace" or slam else blade_direction
					enemy_hit(enemy, definition.damage, hit_direction * force)
					_hit_stop = (0.02 if mace_dash else 0.055) if weapon_family == "mace" else (0.065 if motion.stage == 2 else 0.035)
					_shake = (0.025 if mace_dash else 0.09) if weapon_family == "mace" else (0.11 if motion.stage == 2 else 0.045)
	if mace_dash:
		_apply_mace_travel(sample.get("lunge_offset", 0.0))
	if step.finished:
		_next_combo = 0 if weapon_family in ["staff", "pistol", "rifle"] else (motion.stage + 1) % 3
		_idle_time = 0
		if weapon_family in ["pistol", "rifle"] and active_magazine().rounds == 0: request_reload()
	_trail_clock -= delta
	_range_clock -= delta
	if debug_range and motion.busy and _range_clock <= 0:
		var definition: Dictionary = motion.definition(motion.stage)
		if weapon_family in ["staff", "pistol", "rifle"]:
			var muzzle: Vector3 = _staff_tip(sample)
			fx.lane(Vector3(muzzle.x, player.position.y, muzzle.z), motion.aim_angle, definition.projectile_range, definition.projectile_radius * 2.0, Color(1.0, 0.53, 0.2, 0.16), 0.06)
		elif definition.get("kind", "sweep") in ["lift", "lunge", "slam"]:
			fx.lane(player.position, motion.aim_angle, definition.reach, definition.width, Color(0.3, 0.9, 0.8, 0.14), 0.06)
		else:
			fx.sector(player.position + Vector3(0, 0.035, 0), definition.reach, motion.aim_angle - definition.arc * 0.5, motion.aim_angle + definition.arc * 0.5, Color(0.3, 0.9, 0.8, 0.14), 0.3, 0.06)
		_range_clock = 0.04
	var speed: float = 4.7
	if motion.busy: speed = 0.5 if sample.phase == "active" else 1.0
	if weapon_family == "mace" and (motion.busy or step.finished): speed = 0.0
	if weapon_family == "rifle" and (motion.busy or step.finished): speed = 0.0
	player.velocity = movement * speed
	if motion.busy and sample.phase == "active" and weapon_family not in ["mace", "staff", "pistol", "rifle"]:
		player.velocity += Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle)) * (2.6 if motion.stage == 2 else 1.1)
	if _dodge_left > 0: player.velocity = _dodge_dir * 10.5
	player.velocity.y = -2
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -11.6, 11.6)
	player.position.z = clampf(player.position.z, -9.0, 9.0)
	# Recoil's swept movement can leave a tiny vertical floor correction for
	# move_and_slide. Fire from the settled rifle muzzle shown this same frame.
	if not rifle_release.is_empty():
		_release_ranged(rifle_release)
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy): continue
		enemy.tick(delta, self)
		if enemy.dead and enemy.death_time > 0.75:
			enemies.erase(enemy)
			enemy.queue_free()
	_update_projectiles(delta)
	staff_flight.tick(delta, enemies, get_world_3d(), Callable(), camera)
	if mode == "practice":
		if not motion.busy:
			_dummy_idle += delta
			if _dummy_idle > 0.2:
				for enemy in enemies:
					if enemy.kind == "dummy" and not enemy.dead and enemy.health < enemy.max_health:
						enemy.health = enemy.max_health
						enemy.update_bar()
		if enemies.is_empty(): spawn_enemy("dummy", Vector3(2, 0.03, 0))
	elif mode == "combat":
		var living: int = 0
		for enemy in enemies:
			if not enemy.dead: living += 1
		if living == 0:
			_wave_wait += delta
			if _wave_wait > 1.0:
				if wave >= 3:
					mode = "victory"
					staff_flight.clear()
					casing_fx.clear()
					reset_gun_magazines()
					_held = false
					audio.play("victory")
					ui.show_mode(mode)
				else:
					spawn_wave()
	_visual_tick(delta)

func _apply_mace_travel(desired: float) -> void:
	var direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	var before: float = _short_lunge.travelled
	_short_lunge.advance(player, direction, desired, enemies, motion.definition(1).get("lunge_distance", 0.75))
	mace_dash_travelled = _short_lunge.travelled
	if _short_lunge.travelled > before + 0.001 and _trail_clock <= 0:
		fx.burst(player.position + Vector3(0, 0.06, 0), Color(0.55, 0.62, 0.61, 0.5), 2)
		_trail_clock = 0.04

func _staff_tip(pose: Dictionary) -> Vector3:
	# The same rigid vector drives the sprite endpoints and the launch point.
	var direction := Vector3(cos(float(pose.angle)), 0, sin(float(pose.angle)))
	return player.position + direction * float(pose.radius) + Vector3.UP * float(pose.grip_height) + (direction * cos(float(pose.pitch)) + Vector3.UP * sin(float(pose.pitch))) * float(pose.blade_length)

func _apply_rifle_recoil(desired: float) -> void:
	var backwards := -Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	_rifle_recoil.advance(player, backwards, desired, enemies, motion.definition(0).get("recoil_distance", .22))
	rifle_recoil_travelled = _rifle_recoil.travelled

func active_magazine():
	return rifle_magazine if weapon_family == "rifle" else pistol_magazine

func guns_reloading() -> bool:
	return pistol_magazine.reloading or rifle_magazine.reloading

func reset_gun_magazines() -> void:
	pistol_magazine.reset()
	rifle_magazine.reset()
	_rifle_recoil.reset()
	rifle_recoil_travelled = 0

func _release_ranged(pose: Dictionary) -> void:
	var definition: Dictionary = motion.definition(0)
	# A physics step can end slightly past release, already showing recoil.
	# Start a normal bullet at that visible muzzle; hitches crossing the whole
	# release interval retain the exact authored release snapshot.
	if weapon_family in ["pistol", "rifle"] and motion.sample().phase == "active":
		pose = motion.sample()
	var muzzle := _staff_tip(pose)
	var direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	# Check the short path along the staff too, so close targets/cover cannot
	# be skipped merely because they stand between the character and muzzle.
	definition.launch_origin = Vector3(player.position.x, muzzle.y, player.position.z)
	if staff_flight.spawn_fireball(muzzle, direction, definition, camera):
		if weapon_family in ["pistol", "rifle"]:
			active_magazine().consume()
			fx.burst(muzzle, Color("#ffe5a3"), 8 if weapon_family == "rifle" else 4)
			audio.play("rifle" if weapon_family == "rifle" else "gun")
			if weapon_family == "rifle":
				casing_fx.spawn(player.position + direction * .65 + Vector3.UP * .82, direction, camera)
		else:
			fx.burst(muzzle, Color("#ffb64a"), 5)
			fx.ring(Vector3(muzzle.x, player.position.y, muzzle.z), .22, Color(1, .63, .2, .5), .12)
			audio.play("fire_cast")

func _projectile_damage(enemy, damage: float, knock: Vector3, element: String) -> void:
	enemy_hit(enemy, damage, knock, element)

func _projectile_impact(where: Vector3, reason: String, element: String) -> void:
	fx.burst(where, Color("#ffb347") if element == "fire" else Color("#ffe5a3"), 8 if reason == "enemy" else 4)
	if reason != "range": audio.play("fire_impact" if element == "fire" else "bullet_impact")

func current_visual_sample() -> Dictionary:
	var sample: Dictionary = motion.sample()
	if weapon_family == "pistol" and pistol_magazine.reloading:
		sample.phase = "reload"
		sample.screen_roll = TAU * pistol_magazine.progress()
		sample.body_lean = 0.0
	if weapon_family == "rifle" and rifle_magazine.reloading:
		var action: float = sin(PI * rifle_magazine.progress())
		sample.phase = "reload"
		sample.pitch = .30 * action
		sample.radius = .42 - .10 * action
		sample.grip_height = .80 - .10 * action
		sample.body_lean = -.02 * action
	return sample

func _visual_tick(delta: float) -> void:
	var focus := player.position + aim * 0.45
	focus.x = clampf(focus.x, -3.0, 3.0)
	focus.z = clampf(focus.z, -2.7, 2.7)
	focus.y = 0
	_camera_focus = _camera_focus.lerp(focus, 1.0 - exp(-5 * delta))
	camera.position = _camera_focus + CAMERA_OFFSET + Vector3(randf_range(-_shake, _shake), 0, randf_range(-_shake, _shake))
	camera.look_at(_camera_focus)
	var sample: Dictionary = current_visual_sample()
	if not motion.busy and (weapon_family == "sword" or motion.stage < 0):
		sample.angle = atan2(aim.z, aim.x) + (0.0 if weapon_family in ["mace", "staff", "pistol", "rifle"] else 0.35)
	var reach: float = motion.definition(motion.stage).get("reach", 2.1)
	avatar.update_pose(camera, aim, _movement().length_squared() > 0.01 and mode in ["practice", "combat"], sample, reach, _hurt, _dodge_left, delta, mode == "dead")
	ui.refresh()

func spawn_enemy(kind: String, where: Vector3) -> Node3D:
	var enemy := Enemy.new()
	enemy.kind = kind
	enemy.position = where
	add_child(enemy)
	enemies.append(enemy)
	fx.ring(where, 0.55 if kind != "elite" else 0.85, Color(0.9, 0.5, 0.25, 0.6), 0.55)
	return enemy

func spawn_wave() -> void:
	wave += 1
	_wave_wait = 0
	health = minf(100, health + 16)
	stamina = 100
	var types: Array = ["melee", "melee", "melee"] if wave == 1 else (["melee", "melee", "ranged", "ranged"] if wave == 2 else ["elite", "melee", "melee", "ranged"])
	var locations: Array[Vector3] = [Vector3(-4.0, 0.03, -3.5), Vector3(4.5, 0.03, -3.0), Vector3(3.8, 0.03, 3.2), Vector3(-4.0, 0.03, 3.5)]
	for i in range(types.size()): spawn_enemy(types[i], locations[i])
	fx.number(Vector3(0, 2.4, -1.5), "WAVE %d" % wave, true)
	audio.play("warning")

func enemy_hit(enemy, damage: float, knock: Vector3, element: String = "") -> void:
	if not is_instance_valid(enemy) or enemy.dead: return
	var heavy: bool = (element == "physical" and damage >= 45.0) or (element.is_empty() and (motion.stage == 2 or damage >= 100 or (weapon_family == "mace" and motion.stage == 0)))
	enemy.receive_damage(damage, knock)
	hits += 1
	total_damage += damage
	var damage_text: String = str(int(damage)) if is_equal_approx(damage, roundf(damage)) else "%.1f" % damage
	fx.number(enemy.position + Vector3(0, 1.4, 0), damage_text, heavy)
	fx.burst(enemy.position + Vector3(0, 0.75, 0), Color("#ffb347") if element == "fire" else (Color("#ffe5a3") if element == "physical" else (Color("#ffcc80") if heavy else Color("#8ce9db"))), 16 if heavy else 8)
	audio.play("enemy_hit")
	if enemy.dead:
		if enemy.kind != "dummy": kills += 1
		audio.play("enemy_death")
		fx.burst(enemy.position + Vector3(0, 0.6, 0), Color("#ef9f60"), 14)

func damage_player(amount: float) -> void:
	if mode not in ["combat", "practice"] or _iframes > 0 or amount <= 0: return
	health = maxf(0, health - amount)
	_iframes = 0.5
	_hurt = 0.17
	_shake = 0.1
	fx.number(player.position + Vector3(0, 1.7, 0), "-%d" % int(amount), true)
	audio.play("hit")
	if health <= 0:
		mode = "dead"
		staff_flight.clear()
		casing_fx.clear()
		reset_gun_magazines()
		motion.reset()
		_held = false
		audio.play("death")
		ui.show_mode(mode)

func shoot(where: Vector3, direction: Vector3, damage: float) -> void:
	var bolt := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.2
	bolt.mesh = mesh
	bolt.material_override = fx.tint(Color("#f4a07e"))
	bolt.position = where
	add_child(bolt)
	direction.y = 0
	projectiles.append({"node": bolt, "direction": direction.normalized(), "damage": damage, "life": 3.0})
	audio.play("enemy_attack")

func _update_projectiles(delta: float) -> void:
	for entry in projectiles.duplicate():
		var old: Vector3 = entry.node.position
		entry.node.position += entry.direction * delta * 5.5
		entry.life -= delta
		var query := PhysicsRayQueryParameters3D.create(old, entry.node.position, 1)
		var blocker: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		var target := Vector3(player.position.x, old.y, player.position.z)
		var end: Vector3 = blocker.position if not blocker.is_empty() else entry.node.position
		var near := Geometry3D.get_closest_point_to_segment(target, old, end)
		if near.distance_to(target) < 0.4:
			damage_player(entry.damage)
			entry.node.position = near
			entry.life = 0
		elif not blocker.is_empty():
			entry.node.position = blocker.position
			entry.life = 0
			fx.burst(blocker.position, Color("#e9ae80"), 3)
		if entry.life <= 0:
			entry.node.queue_free()
			projectiles.erase(entry)
