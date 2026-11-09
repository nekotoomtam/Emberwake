extends SceneTree
const Standing := preload("res://modular/scripts/city_npc_pose.gd")
const OriginalNPC := preload("res://scripts/opening/harbor_npc.gd")


func _initialize() -> void:
	call_deferred("run")


func shot(game: Node3D, id: String, point: Vector3, offset: Vector3) -> void:
	game.camera.global_position = point + offset
	game.camera.look_at(point + Vector3.UP * 0.75)
	game.camera.fov = 46.0
	game.world.tick(0.0, game.camera)
	game.shared_seats.tick(0.0, game.camera, game.world)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("user://npc-" + id + ".png") == OK)


func run() -> void:
	var game: Node3D = load("res://scenes/prologue.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.ui.hide()
	await physics_frame
	var nodes: Array = game.world.find_children("*", "Node3D", true, false)
	var residents: Array[Node3D] = []
	for node: Node3D in nodes:
		if node is OriginalNPC and not node.modular_look.is_empty():
			residents.append(node)
	assert(residents.size() > 12)
	var looks := {}
	for npc: Node3D in residents:
		var look: Dictionary = npc.modular_look
		assert(look.top.sex == look.sex and look.bottom.sex == look.sex)
		assert(look.top.tier == look.tier and look.bottom.tier == look.tier)
		assert(npc.modular_frame.texture == npc.sprite.texture)
		looks[[look.face, look.hair, look.top.id, look.bottom.id]] = true
	assert(looks.size() >= 12)
	var porter: Node3D = game.world.dock_life.marked_workers[0]
	var watch: Dictionary = porter.modular_look
	for direction: String in ["front", "left", "right", "back"]:
		for action: String in ["walk", "carry_walk", "lift", "place", "painting", "ticket", "hold_tag", "inspect", "portrait_pose"]:
			var pose := Standing.frame(watch, direction, action, 0)
			assert(pose.texture.get_image().get_used_rect().has_area())
			assert(pose.right.is_finite() and pose.left.is_finite())
	var p: Dictionary = Standing.frame(watch, "front", "carry_walk", 0)
	assert(p.right.distance_to(p.left) > 1.0)
	assert(game.shared_seats.npc_views.size() == 5)
	for seated: Dictionary in game.shared_seats.npc_views:
		assert(seated.rig.character.joints.size() == 12)
		assert(not seated.actor.sprite.visible)
	await shot(game, "cafe", Vector3(-44.3, 0.055, -7.7), Vector3(-0.1, 2.5, 5.4))
	await shot(game, "dock", Vector3(-23.8, 0.055, -12.0), Vector3(0.2, 2.1, 5.4))
	await shot(game, "passengers", Vector3(-8.0, 0.055, 3.1), Vector3(0.5, 2.6, 6.5))
	await shot(game, "painter", Vector3(-22.6, 0.055, 0.0), Vector3(0.4, 2.3, 5.5))
	game.audio.shutdown()
	print("New NPCs on the native map: ", residents.size(), " standing/working actors, ",
		looks.size(), " distinct combinations, and 5 live seated actors.")
	quit()

