extends SceneTree

const CityPose := preload("res://modular/scripts/city_npc_pose.gd")


func _initialize() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("user://" + name + ".png") == OK)


func run() -> void:
	var game: Node3D = load("res://scenes/prologue.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	var rig: Node3D = game.shared_seats.player_pose
	assert(not game.world.hero.visible and rig.visible)
	assert(rig.character.joints.size() == 12)
	game.start_arrival()
	game.phase = &"line"
	game.camera.set_view(&"cafe", 0)
	game.world.sip_age = 5.8
	game.tick(0.0)
	assert(game.world.sip_lift == 1.0 and rig.mouth_error < 0.05)
	await capture("blonde-player-intro")

	var bag: Node3D = game.world.plaza.travel_luggage
	game.phase = &"rising"
	game.phase_age = 0.48
	game.tick(0.0)
	assert(rig.visible and not bag.stand_arm.visible)
	assert(bag.grip.global_position.distance_to(rig.right_grip) < 0.002)
	game.tick(0.38)
	var walker: CharacterBody3D = game.walker
	assert(game.phase == &"play" and not rig.visible and walker.sprite.visible)
	assert(walker.modular_look == CityPose.player_look())
	walker.set_physics_process(false)
	var move_by_view := {
		"front": game.camera.global_basis.z,
		"left": -game.camera.global_basis.x,
		"right": game.camera.global_basis.x,
		"back": -game.camera.global_basis.z,
	}
	for view: String in move_by_view:
		var motion: Vector3 = move_by_view[view]
		motion.y = 0.0
		walker.update_art(0.15, motion)
		assert(walker.facing == view and walker.art_action == "walk")
		assert(walker.sprite.texture == CityPose.frame(CityPose.player_look(),
			view, "luggage_walk", walker.art_frame).texture)
		bag.update_carry(walker, game.camera)
		assert(bag.grip.global_position.distance_to(walker.modular_grip()) < 0.002)
	var target: Vector3 = walker.global_position + Vector3.UP
	game.camera.global_position = target + Vector3(1.4, 1.2, 3.9)
	game.camera.look_at(target)
	walker.facing = "right"
	walker.update_art(0.18, game.camera.global_basis.x)
	bag.update_carry(walker, game.camera)
	await capture("blonde-player-walk")
	game.return_title()
	game.tick(0.0)
	assert(game.walker == null and rig.visible and not game.world.hero.visible)
	assert(bag.state == &"resting")
	game.audio.shutdown()
	print("Blonde player: intro sip, rise and suitcase, four walk directions, and return to title.")
	quit()
