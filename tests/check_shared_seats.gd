extends SceneTree
const Shared := preload("res://modular/scripts/shared_seats.gd")

func _initialize() -> void:
	call_deferred("run")


func key(game: Node3D, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_key_input(event)


func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("user://" + path + ".png") == OK)


func run() -> void:
	var game: Node3D = load("res://scenes/prologue.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	game.start_arrival()
	game.skip_arrival()
	assert(game.phase == &"play")
	game.walker.set_physics_process(false)
	game.walker.global_position = Shared.CAFE_HIP + Vector3(0, -0.40, 0.70)
	assert(game.shared_seats.npc_views.size() == 5)
	key(game, KEY_E)
	assert(game.shared_seats.seat == "cafe" and not game.walker.sprite.visible)
	var actor: Node3D = game.shared_seats.player_pose
	assert(actor.character.joints.size() == 12)
	var target: Vector3 = Shared.CAFE_HIP + Vector3(0.45, 0.46, 0.0)
	game.camera.global_position = target + Vector3(2.2, 1.8, 4.2)
	game.camera.look_at(target)
	game.shared_seats.tick(0.0, game.camera, game.world)
	var cup_rest: Vector3 = game.world.cup.global_position
	var palm_error: float = actor.left_grip.distance_to(actor.left_target)
	var rest_error: float = actor.right_grip.distance_to(cup_rest + Shared.HANDLE)
	assert(rest_error < 0.04 and palm_error < 0.04)
	print("Cup at rest grip error ", rest_error, ", table palm error ", palm_error)
	await capture("v115-shared-cafe-rest")
	key(game, KEY_F)
	for i: int in range(10):
		game.shared_seats.tick(0.08, game.camera, game.world)
	assert(game.world.cup.global_position.distance_to(cup_rest) > 0.1)
	assert((game.world.cup.global_position + Shared.HANDLE).distance_to(actor.right_grip) < 0.001)
	assert(actor.mouth_error < 0.05)
	print("Grip at sip is within ", actor.mouth_error, " metres of its target.")
	await capture("v115-shared-cafe-sip")
	for i: int in range(18):
		game.shared_seats.tick(0.08, game.camera, game.world)
	assert(game.world.cup.global_position.distance_to(cup_rest) < 0.001)
	key(game, KEY_E)
	assert(game.shared_seats.seat.is_empty() and game.walker.sprite.visible)
	game.walker.global_position = Shared.FREE_BENCH + Vector3(0, -0.47, 0.72)
	key(game, KEY_E)
	assert(game.shared_seats.seat == "bench")
	target = Shared.FREE_BENCH + Vector3(0.0, 0.52, 0.0)
	game.camera.global_position = target + Vector3(1.5, 1.6, 4.2)
	game.camera.look_at(target)
	game.shared_seats.tick(0.0, game.camera, game.world)
	await capture("v115-shared-bench")
	key(game, KEY_E)
	assert(game.walker.enabled and game.walker.sprite.visible)
	game.audio.shutdown()
	print("v115 shared seating: 5 NPCs, player cafe and bench, hand-held cup lift and return.")
	quit()
