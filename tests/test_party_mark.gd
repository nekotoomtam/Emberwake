extends SceneTree
const Look = preload("res://modular/scripts/city_npc_pose.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var entry = load("res://scenes/opening/coastal_combat_entry.tscn").instantiate()
	var look := Look.player_look()
	var party: Array[Dictionary] = [{"look": look, "weapon":"sword"},
		{"look":look, "weapon":"pistol"}, {"look":look, "weapon":"mace"}]
	entry.party = party
	root.add_child(entry)
	current_scene = entry
	var game = entry.game
	game.set_physics_process(false)
	game.test_aim = Vector3.RIGHT
	game._refresh_aim()
	var distractor = game.spawn_enemy("dummy", Vector3(1.2, .03, 2.0))
	var target = game.spawn_enemy("dummy", Vector3(4.0, .03, 0.0))
	await physics_frame
	ping(game.camera.unproject_position(target.global_position + Vector3.UP * .8))
	var marked: bool = game.party_mark_target == target and game.party_mark_marker.visible
	if not marked:
		printerr("C did not mark the enemy")
		quit(1)
		return
	for frame in 210: game.tick(1.0 / 120.0)
	var focus: bool = target.health < target.max_health and distractor.health == distractor.max_health
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var saved := root.get_texture().get_image().save_png(args[0])
		if saved != OK: quit(saved); return
	target.receive_damage(100000.0, Vector3.ZERO)
	game.tick(1.0 / 120.0)
	var cleared_on_death: bool = game.party_mark_target == null and not game.party_mark_marker.visible
	var point := Vector3(0.0, 0.0, -4.0)
	ping(game.camera.unproject_position(point))
	for frame in 240: game.tick(1.0 / 120.0)
	var moved: bool = game.companions[0].position.distance_to(point) < 1.6 and game.companions[1].position.distance_to(point) < 1.6
	ping(Vector2.ZERO, true)
	var recalled: bool = game.companions[0].recalling() and game.companions[1].recalling() and game.get("party_mark_target") == null
	var passed := focus and moved and recalled and cleared_on_death
	print("PARTY MARK ", "PASS" if passed else "FAIL", " focus=", focus, " move=", moved, " recall=", recalled, " target death clears mark=", cleared_on_death)
	quit(0 if passed else 1)

func ping(at: Vector2, shift: bool = false) -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.position = at
	root.push_input(mouse, true)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.shift_pressed = shift
	key.pressed = true
	root.push_input(key, true)
