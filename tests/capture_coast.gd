extends SceneTree
## Native-only, offscreen, unfocusable capture harness. Input events travel through
## the real viewport. Movement explicitly uses Input.action_press, not OS WASD.
## Attack selection/placement and lethal callbacks are labeled controlled fixtures.
const STEP := 1.0 / 120.0
const Roster = preload("res://scripts/coastal_roster.gd")
const MOVES := [["fisherman",0],["fisherman",1],["brinehound",0],["net_hauler",0],["net_hauler",1],["harpooner",0],["spitter",0],["spitter",1]]
var game
var output := ""
var safe := false
var failures: Array[String] = []
var frames: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var checks := 0
var current_case := "bootstrap"
var fixture_kind := ""
var input_method := "none"
var tick_index := 0
var fixed_camera := false
var fixed_focus := Vector3.ZERO
var target
var fixture_clock := 0.0
var projectile_seen := false
var action_log: Array[Dictionary] = []

func _initialize() -> void:
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	call_deferred("run")

func _process(_delta: float) -> bool:
	if safe and (not root.unfocusable or not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) or DisplayServer.window_get_position() != Vector2i(20000, 20000)):
		failures.append("window safety invariant lost")
		printerr("COAST CAPTURE: window safety invariant lost")
		manifest()
		quit(1)
	return false

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(current_case + ": " + why)
		printerr("FAIL: ", current_case, ": ", why)

func vec3(value: Vector3) -> Array: return [value.x, value.y, value.z]
func vec2(value: Vector2) -> Array: return [value.x, value.y]

func button(which: int, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.position = game._mouse_position
	root.push_input(event, true)
	Input.flush_buffered_events()
	action_log.append({"case":current_case,"tick":tick_index,"method":"viewport mouse event","button":which,"pressed":down})

func key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		Input.flush_buffered_events()
	action_log.append({"case":current_case,"tick":tick_index,"method":"viewport key event","physical_keycode":code})

func action(name: String, down: bool) -> void:
	if down: Input.action_press(name)
	else: Input.action_release(name)
	Input.flush_buffered_events()
	action_log.append({"case":current_case,"tick":tick_index,"method":"Input.action_press/release simulation; not OS keyboard","action":name,"pressed":down})

func release_inputs() -> void:
	for name in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(name)
	if is_instance_valid(game):
		button(MOUSE_BUTTON_LEFT, false)
		button(MOUSE_BUTTON_RIGHT, false)
	Input.flush_buffered_events()

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null

func click_ui(control: Button) -> void:
	check(control != null, "coast menu button exists")
	if control == null: return
	await process_frame
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		root.push_input(event, true)
		Input.flush_buffered_events()
	action_log.append({"case":current_case,"tick":tick_index,"method":"viewport menu pointer click","text":control.text,"position":vec2(at)})
	await process_frame

func apply_camera() -> void:
	if not fixed_camera: return
	game._camera_focus = fixed_focus
	game.camera.position = fixed_focus + game.CAMERA_OFFSET
	game.camera.look_at(fixed_focus)
	game.camera.size = 11.5

func aim_at_target() -> void:
	if not is_instance_valid(target) or target.dead: return
	var direction: Vector3 = target.position - game.player.position
	direction.y = 0
	game.test_aim = direction.normalized()
	var event := InputEventMouseMotion.new()
	event.position = game.camera.unproject_position(target.position + Vector3.UP * .6)
	root.push_input(event, true)
	Input.flush_buffered_events()

func advance(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		aim_at_target()
		game.tick(STEP)
		apply_camera()
		if is_instance_valid(target) and target.has_method("coastal_projectile_style"):
			target.tick(.00000001, game)
		game.vision.update_view(0)
		tick_index += 1
		fixture_clock += STEP

func advance_to(seconds: float) -> void:
	var amount := maxi(0, ceili((seconds - fixture_clock) / STEP - .000001))
	await advance(amount)

func neutral_stats() -> void:
	# Explicit fixture normalization: isolated resource, no equipment modifiers,
	# no critical rolls. Production data/resources and saved loadout are untouched.
	game.stats.reset_modifiers()
	game.stats.flat.critical_chance = -1.0
	game.combat_rng.seed = 6201
	game.shot_rng.seed = 6202

func fresh_coast() -> void:
	release_inputs()
	target = null
	fixed_camera = false
	game.loadout.defaults()
	game.loadout.unequip({"kind":"slot","set":0,"hand":"off"})
	game.loadout_edited()
	game.start_coast()
	game.set_physics_process(false)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT
	game.debug_range = false
	neutral_stats()
	fixture_clock = 0

func freeze_all() -> void:
	for enemy in game.enemies:
		if is_instance_valid(enemy): enemy.stagger = 999

func prepare(kind: String, index: int, left: bool, distance: float = 4.2) -> void:
	fresh_coast()
	game.clear_actors()
	game.spawn_enemy(kind, Vector3(0, .03, 0))
	target = game.enemies[0]
	target.home_position = target.position
	var angle := PI if left else 0.0
	var forward := Vector3(cos(angle), 0, sin(angle))
	game.player.position = target.position + forward * distance
	target.attack_data = Roster.attack(kind, index)
	target.attack_angle = angle
	target.target_point = game.player.global_position
	target.state = "windup"
	target.telegraph_left = target.attack_data.windup
	target.active_left = 0
	target.elapsed = 0
	target.cooldown = 0
	target.stagger = 0
	target.attack_hit = false
	target.lunge_travel = 0
	target.engaged = true
	target.returning = false
	fixed_camera = true
	fixed_focus = target.position + forward * .8
	apply_camera()
	aim_at_target()
	target.tick(.00000001, game)
	game.vision.update_view(0)

func enemy_record(enemy) -> Dictionary:
	if not is_instance_valid(enemy): return {}
	var result := {"kind":enemy.kind,"state":enemy.state,"dead":enemy.dead,"health":enemy.health,"position":vec3(enemy.global_position),"screen":vec2(game.camera.unproject_position(enemy.global_position)),"animation":enemy.sprite.animation,"frame":enemy.sprite.frame,"flip_h":enemy.sprite.flip_h,"sprite_position":vec3(enemy.sprite.global_position),"pixel_size":enemy.sprite.pixel_size,"attack":enemy.attack_data.duplicate(true),"attack_angle":enemy.attack_angle,"telegraph_left":enemy.telegraph_left,"active_left":enemy.active_left,"cooldown":enemy.cooldown,"stagger":enemy.stagger}
	if enemy.has_method("coastal_projectile_style"):
		result.elapsed = enemy.elapsed
		result.home_position = vec3(enemy.home_position)
		result.contacts = enemy.contact_count
		result.foot_anchor_error = enemy.sprite.global_position.distance_to(enemy.global_position + game.camera.global_basis.y * 1.2)
		var collision = enemy.get_node_or_null("BodyCollision")
		if collision != null:
			result.collision_radius = collision.shape.radius
			result.collision_height = collision.shape.height
			result.collision_center = vec3(collision.global_position)
		var texture: Texture2D = enemy.sprite.sprite_frames.get_frame_texture(enemy.sprite.animation, enemy.sprite.frame)
		var used := texture.get_image().get_used_rect()
		result.alpha_pixel_bounds = [used.position.x, used.position.y, used.size.x, used.size.y]
		result.visible_world_height = used.size.y * enemy.sprite.pixel_size
		if enemy.has_method("projectile_launch") and int(enemy.attack_data.get("projectiles", 0)) > 0:
			var launch: Dictionary = enemy.projectile_launch(game)
			result.muzzle = {"origin":vec3(launch.origin),"screen":vec2(game.camera.unproject_position(launch.origin)),"direction":vec3(launch.direction),"reach":launch.reach,"locked_target":vec3(enemy.target_point)}
	return result

func projectile_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for entry in game.projectiles:
		if not is_instance_valid(entry.node): continue
		var texture: Texture2D = null
		if entry.node.material_override is StandardMaterial3D: texture = entry.node.material_override.albedo_texture
		var image: Image = texture.get_image() if texture != null else null
		var nonempty := image != null and image.get_used_rect().has_area()
		records.append({"position":vec3(entry.node.global_position),"screen":vec2(game.camera.unproject_position(entry.node.global_position)),"direction":vec3(entry.direction),"life":entry.life,"quad_mesh":entry.node.mesh is QuadMesh,"has_albedo_texture":texture != null,"texture_has_pixels":nonempty,"texture_size":[texture.get_width(),texture.get_height()] if texture != null else [],"owner_kind":entry.owner_enemy.kind if is_instance_valid(entry.owner_enemy) else "freed"})
	return records

func shot(mark: String) -> void:
	apply_camera()
	game.ui.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := output.path_join(current_case)
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory ready")
	var relative := current_case + "/" + mark + ".png"
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "native render has image pixels")
	if image == null: return
	check(image.save_png(output.path_join(relative)) == OK, "save " + relative)
	var enemies: Array[Dictionary] = []
	for enemy in game.enemies: enemies.append(enemy_record(enemy))
	var bolts := projectile_records()
	for bolt in bolts:
		check(bolt.quad_mesh and bolt.has_albedo_texture and bolt.texture_has_pixels, "actual coastal shot uses a textured nonempty QuadMesh")
		projectile_seen = true
	var record := {"case":current_case,"fixture":fixture_kind,"input_method":input_method,"camera_method":"fixed inspection camera; natural camera follow untested in this fixture" if fixed_camera else "production camera follow","file":relative,"tick":tick_index,"simulation_seconds":tick_index * STEP,"fixture_seconds":fixture_clock,"player":vec3(game.player.position),"player_health":game.health,"stamina":game.stamina,"flasks":game.flasks.charges,"anatomy":game.anatomy.integrity.duplicate(),"missing_parts":game.anatomy.missing.duplicate(),"mode":game.mode,"encounter":game.encounter_mode,"coast_stage":game.coast.stage,"living":game.coast.living(game),"inventory_open":game.inventory_open,"loadout_set":game.loadout.active,"weapon_family":game.weapon_family,"debug_range":game.debug_range,"move_input":vec2(game.move_input),"camera_focus":vec3(game._camera_focus),"camera_position":vec3(game.camera.global_position),"camera_size":game.camera.size,"aim":vec3(game.aim),"target":enemy_record(target),"enemies":enemies,"projectiles":bolts,"fixture_stats":{"critical_chance":game.stats.value("critical_chance"),"normalization":"duplicated stats resource; reset modifiers and flat critical chance -1 only"},"viewport":[image.get_width(),image.get_height()],"window_safety":{"unfocusable":root.unfocusable,"no_focus_flag":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"position":vec2(Vector2(DisplayServer.window_get_position()))},"failures_at_capture":failures.duplicate()}
	frames.append(record)
	write_json(output.path_join(current_case + "/" + mark + ".json"), record)

func write_json(path: String, data) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "open JSON " + path.get_file())
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func manifest() -> void:
	if output.is_empty(): return
	write_json(output.path_join("capture-manifest.json"), {"native_no_focus":safe,"native_renderer":DisplayServer.get_name(),"checks":checks,"frame_count":frames.size(),"expected_total_images":127,"expected_attack_images":96,"movement_method":"Input.action_press/release simulation through production _movement(); not OS WASD","pointer_key_method":"root.push_input InputEventMouseButton/InputEventKey; not OS hardware","attack_selection_scope":"controlled start/positions and direction; subsequent phases and projectile release use actual Game.tick; natural AI selection not claimed","stats_scope":"per-instance duplicated resource, equipment modifiers reset, critical chance disabled for reproducible fixtures","save_scope":"game.loadout.save_path empty before add_child; user loadout never read/written","projectile_seen":projectile_seen,"cases":cases,"frames":frames,"actions":action_log,"failures":failures})

func capture_move(kind: String, index: int, left: bool) -> void:
	current_case = "move-" + kind + "-" + str(index) + ("-left" if left else "-right")
	fixture_kind = "controlled attack selection, direction, actor/home/player positions; real game-clock windup/impact/projectiles/recovery, no natural AI-selection claim"
	input_method = "no attack input; controlled enemy attack-start fixture"
	prepare(kind, index, left)
	var data: Dictionary = target.attack_data.duplicate(true)
	var w: float = data.windup
	var a: float = data.active
	var first := frames.size()
	var stages := [["windup25", w * .25], ["windup75", w * .75], ["active-pre", w + a * maxf(.05, float(data.impact) - .08)], ["impact", w + a * float(data.impact) + STEP], ["active-post", w + a * .85], ["recovery50", w + a + float(data.recovery) * .5]]
	for stage in stages:
		await advance_to(float(stage[1]))
		await shot(stage[0])
		if stage[0] == "impact" and int(data.projectiles) > 0:
			check(game.projectiles.size() == int(data.projectiles), "actual release creates specified shot count")
			check(not projectile_records().is_empty(), "release snapshots retain visible textured shots")
	check(target.state == "recover", "real game ticks reach recovery")
	check(frames.size() - first == 6, "six phase snapshots captured")
	cases.append({"case":current_case,"type":"controlled move phases","frames":6,"attack_definition":data,"first_record":first})
	manifest()

func movement_and_shore() -> void:
	current_case = "movement-camera"
	fixture_kind = "ten ordinary actors frozen for isolated movement/camera inspection; starting x10.8 placement fixture"
	input_method = "Input.action_press/release simulation; move_input remains zero; not OS WASD"
	fresh_coast()
	freeze_all()
	game.player.position = Vector3(10.8, .03, -6)
	game._camera_focus = game.player.position
	game.camera.position = game._camera_focus + game.CAMERA_OFFSET
	game.camera.look_at(game._camera_focus)
	await shot("before-action")
	action("move_right", true)
	await advance(96)
	await shot("moving")
	await advance(108)
	action("move_right", false)
	await advance(24)
	check(game.move_input == Vector2.ZERO, "movement did not use move_input fixture override")
	check(game.player.position.x > 16, "input action moves player beyond old arena x11.6")
	check(game._camera_focus.x > 14, "production camera follows beyond old x limit")
	check(not Input.is_action_pressed("move_right"), "movement action released")
	await shot("released-beyond-old-boundary")
	for x in [-19.0, -3.0, 17.0]:
		current_case = "shore-clamp-" + str(int(x))
		fixture_kind = "selected shoreline start fixture; ten enemies frozen; action simulation pushes toward physical sea barrier and production clamp"
		var z: float = game.arena.shoreline(x)
		game.player.position = Vector3(x, .03, z - .65)
		game._camera_focus = game.player.position
		action("move_down", true)
		await advance(42)
		action("move_down", false)
		check(game.arena.is_walkable(game.player.position), "production movement retains legal wet-sand band")
		check(game.player.position.z <= game.arena.shoreline(game.player.position.x) - .449, "production sea clamp respects .45 margin")
		check(game.player.position.z >= game.arena.shoreline(game.player.position.x) - .56, "seaward input actually reaches the clamp band")
		await shot("held-seaward-clamped")
	manifest()

func input_combat() -> void:
	current_case = "actual-lmb"
	fixture_kind = "stationary ordinary fisherman, recover/stagger999; player within sword reach; actual viewport LMB routing"
	input_method = "viewport mouse input"
	prepare("fisherman", 0, true, 1.0)
	target.state = "recover"
	target.cooldown = 999
	target.stagger = 999
	target.tick(.00000001, game)
	var before: float = target.health
	await shot("before")
	button(MOUSE_BUTTON_LEFT, true)
	button(MOUSE_BUTTON_LEFT, false)
	await advance(20)
	await shot("swing")
	await advance(85)
	check(game.hits > 0 and target.health < before, "actual LMB damages ordinary fisherman")
	await shot("contact-result")
	current_case = "actual-rmb-parry"
	fixture_kind = "controlled fisherman active hook, player frontal at1.2; impact due in .077s; actual viewport RMB inside real parry window"
	prepare("fisherman", 0, true, 1.2)
	target.state = "attack"
	target.elapsed = .07
	target.active_left = float(target.attack_data.active) - target.elapsed
	target.telegraph_left = 0
	target.tick(.00000001, game)
	await shot("before-rmb")
	button(MOUSE_BUTTON_RIGHT, true)
	await advance(12)
	check(game.readiness.parries == 1 and target.state == "parried", "actual RMB parries real enemy contact")
	await shot("parry-contact")
	button(MOUSE_BUTTON_RIGHT, false)
	await advance(24)
	await shot("parry-settled")
	current_case = "actual-space-dash"
	fixture_kind = "fresh coast, enemies frozen, player at0,-4; actual viewport SPACE dash; production camera follow"
	input_method = "viewport physical_keycode SPACE event; not OS hardware"
	fresh_coast()
	freeze_all()
	game.player.position = Vector3(0, .03, -4)
	game._camera_focus = game.player.position
	game.camera.position = game._camera_focus + game.CAMERA_OFFSET
	game.camera.look_at(game._camera_focus)
	game.test_aim = Vector3.RIGHT
	var start: Vector3 = game.player.position
	await advance(2)
	await shot("before")
	key(KEY_SPACE)
	await advance(6)
	check(game._dodge_left > 0, "actual SPACE starts dash")
	await shot("dash-active")
	await advance(36)
	check(game.player.position.distance_to(start) > 1.5, "actual dash displaces player on beach")
	await shot("dash-end")
	current_case = "inventory-and-q"
	fixture_kind = "same coast after completed dash; real inventory and weapon-set input routing"
	input_method = "viewport I and Q physical_keycode events; not OS hardware"
	key(KEY_I)
	check(game.inventory_open, "I opens inventory in coast mode")
	await shot("inventory-open")
	key(KEY_I)
	check(not game.inventory_open, "I closes inventory")
	var active: int = game.loadout.active
	key(KEY_Q)
	await advance(4)
	check(game.loadout.active != active, "Q changes active weapon set on beach")
	await shot("q-swapped")
	manifest()

func replay_checks() -> void:
	check(game.encounter_mode == "coast" and game.mode == "combat", "T retains coast mode")
	check(game.coast.stage == "ordinary" and game.coast.living(game) == 10, "T restores ten ordinary enemies")
	check(game.flasks.charges == 3, "T restores three flasks")
	var intact := true
	for part in game.anatomy.PARTS:
		intact = intact and game.anatomy.present(part) and is_equal_approx(float(game.anatomy.integrity[part]), 100.0)
	check(intact, "T restores all six intact body parts")
	check(game.projectiles.is_empty(), "T clears hostile shots")

func kill_ordinary_callback() -> void:
	for enemy in game.enemies.duplicate():
		if is_instance_valid(enemy) and enemy.kind != "captain": enemy.receive_damage(10000, Vector3.ZERO)
	await advance(216)
	check(game.coast.stage == "captain" and game.coast.living(game) == 1, "ordinary callback deaths advance to single Captain")
	var captain_count := 0
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.kind == "captain":
			captain_count += 1
			target = enemy
	check(captain_count == 1, "only the existing Captain survives stage transition")

func lifecycle() -> void:
	current_case = "ordinary-to-captain"
	fixture_kind = "direct lethal damage callbacks on ten ordinary actors; real encounter wait/transition; not player kills"
	input_method = "direct lethal callbacks then actual Game.tick"
	fresh_coast()
	freeze_all()
	await shot("ten-before-callbacks")
	await kill_ordinary_callback()
	if is_instance_valid(target):
		target.stagger = 999
		game.player.position = target.position + Vector3(-4, 0, 0)
		await advance(42)
	fixture_kind += "; observer/player repositioned near Captain for production follow-camera inspection; Captain frozen"
	await shot("captain-only")
	current_case = "captain-reach"
	fixture_kind = "controlled active phase of existing Captain, H diagnostic on, fixed camera; longer reach visual/contact inspection"
	input_method = "phase placement fixture, not attack AI selection"
	fixed_camera = true
	fixed_focus = target.position + Vector3(-1,0,0)
	apply_camera()
	game.debug_range = true
	for id in ["sweep","throw","slam"]:
		target.attack_data = target.Rules.definition(id)
		target.attack_angle = PI
		target.sprite.flip_h = true
		if id == "throw": target.configure_throw_launch()
		target.state = "attack"
		target.elapsed = .8 if id == "throw" else float(target.attack_data.active) * .5
		target.active_left = float(target.attack_data.active) - target.elapsed
		target.tick(.00000001,game)
		game._visual_tick(0)
		check(absf(float(target.attack_data.reach)-float({"sweep":1.9,"throw":5.2,"slam":2.0}[id])*1.15)<.0001,"rendered Captain definition uses longer reach "+id)
		await shot(id+"-longer-reach")
	game.debug_range = false
	fixed_camera = false
	current_case = "captain-stage-t-replay"
	fixture_kind = "actual viewport T restart from Captain stage"
	input_method = "viewport T physical_keycode event"
	key(KEY_T)
	target = null
	await advance(2)
	replay_checks()
	freeze_all()
	await shot("ten-restored")
	current_case = "head-injury-death"
	fixture_kind = "hostile-shot setup followed by direct hit_body_part(head,10000); validates real head-death/UI/projectile cleanup path, not enemy-earned death"
	input_method = "labeled head injury callback"
	game.shoot(game.player.position + Vector3(2, .6, 0), Vector3.LEFT, 10)
	check(game.projectiles.size() == 1, "hostile shot exists immediately before head-death callback")
	game.hit_body_part("head", 10000)
	check(game.projectiles.is_empty(), "head death immediately clears hostile shots")
	await advance(2)
	check(game.mode == "dead" and game.anatomy.dead(), "head injury opens actual death state")
	check(game.projectiles.is_empty(), "no hostile shots survive while dead")
	await shot("death-screen")
	current_case = "death-t-replay"
	fixture_kind = "actual viewport T replay after labeled head injury"
	input_method = "viewport T physical_keycode event"
	key(KEY_T)
	await advance(2)
	replay_checks()
	freeze_all()
	await shot("alive-six-parts-ten-enemies")
	current_case = "coast-victory"
	fixture_kind = "direct ordinary lethal callbacks then Captain lethal callback; real waits and coast victory UI; not complete player-won run"
	input_method = "direct lethal callbacks then Game.tick"
	await kill_ordinary_callback()
	if is_instance_valid(target):
		target.stagger = 999
		game.player.position = target.position + Vector3(-4, 0, 0)
		await advance(32)
	await shot("captain-before-lethal")
	if is_instance_valid(target): target.receive_damage(10000, Vector3.ZERO)
	await advance(12)
	await shot("captain-death")
	await advance(204)
	check(game.mode == "victory" and game.coast.stage == "complete", "Captain callback reaches coast victory UI")
	check(game.projectiles.is_empty(), "victory clears hostile projectiles")
	target = null
	await shot("victory-screen")
	current_case = "victory-t-replay"
	fixture_kind = "actual viewport T replay after coast victory"
	input_method = "viewport T physical_keycode event"
	key(KEY_T)
	await advance(2)
	replay_checks()
	freeze_all()
	await shot("fresh-coast")
	manifest()

func run() -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty() or not output.is_absolute_path():
		printerr("COAST CAPTURE requires native renderer and --output=<absolute path>; headless intentionally rejected")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1280, 800)
	root.size = Vector2i(1280, 800)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safe = true
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("Cannot create capture output directory")
		quit(1)
		return
	game = load("res://scenes/game.tscn").instantiate()
	game.loadout.save_path = ""
	game.stats = game.stats.duplicate(true)
	root.add_child(game)
	game.set_physics_process(false)
	neutral_stats()
	current_case = "menu-entry"
	fixture_kind = "real beach menu pointer selection, standard Game scene; subsequent physics manually clocked"
	input_method = "viewport menu pointer click"
	await shot("menu")
	await click_ui(find_button(game.ui, "ชายหาดร้าง • สำรวจและต่อสู้"))
	check(game.encounter_mode == "coast" and game.mode == "combat", "menu pointer selects coastal exploration")
	check(game.coast.living(game) == 10, "standard menu path creates ten ordinary enemies")
	await advance(2)
	await shot("initial-playground")
	await movement_and_shore()
	await input_combat()
	for move in MOVES:
		for left in [false, true]: await capture_move(move[0], move[1], left)
	await lifecycle()
	release_inputs()
	check(projectile_seen, "at least one actual textured coastal projectile captured")
	manifest()
	# T replay just requested its equip WAV. Native AudioServer releases stopped
	# playback on its mixer tick; stopping and draining before teardown prevents
	# an active AudioStreamWAV/AudioStreamPlaybackWAV pair surviving process exit.
	game.audio.set_enabled(false)
	await create_timer(.2).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("COAST QC NATIVE: ", frames.size(), " images; ", checks, " checks; failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
