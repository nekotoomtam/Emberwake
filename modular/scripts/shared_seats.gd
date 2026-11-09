extends Node
## Live seat interactions. The player and town residents share the same pose driver.
const CityPose := preload("res://modular/scripts/city_npc_pose.gd")
const Pose := preload("res://modular/scripts/shared_seat_pose.gd")
const Plaza := preload("res://scripts/opening/harbor_plaza_profile.gd")
const HANDLE := Vector3(-0.14, 0.01, 0.0)
const CAFE_HIP := Plaza.CAFE + Vector3(0.0, 0.336, -0.07)
const FREE_BENCH := Vector3(-46.6, 0.5275, 2.76)

var npc_views: Array[Dictionary] = []
var player_pose: Node3D
var seat := ""
var sip_time := -1.0


func bind(world: Node3D) -> void:
	for actor: Node3D in world.bench_life.actors:
		add_resident(actor, "Middle", false)
	for actor: Node3D in world.life.coffee_pair:
		add_resident(actor, "Noble", true)


func add_resident(actor: Node3D, tier: String, coffee: bool) -> void:
	var rig := Pose.new()
	add_child(rig)
	rig.dress_look(CityPose.appearance(actor.profile, str(actor.name), tier))
	actor.sprite.hide()
	npc_views.append({"actor": actor, "rig": rig, "coffee": coffee})

func ensure_player_pose() -> void:
	if player_pose == null:
		player_pose = Pose.new()
		add_child(player_pose)
		player_pose.dress_look(CityPose.player_look())


func pose_intro(camera: Camera3D, world: Node3D, rise: float = -1.0) -> void:
	ensure_player_pose()
	player_pose.show()
	if rise < 0.0:
		var cup_before: Vector3 = world.cup.global_position
		pose_player_coffee(camera, world, world.sip_lift)
		for puff: Sprite3D in world.steam:
			puff.global_position += world.cup.global_position - cup_before
		return
	var case_prop: Node3D = world.plaza.travel_luggage
	var standing_center: Vector3 = world.anchors.cafe + Vector3.UP * 0.145 + camera.global_basis.y * 0.864
	var stand_pose := CityPose.frame(CityPose.player_look(), "right", "luggage_idle", 0)
	case_prop.update_stand(rise, world.hero, camera,
		CityPose.right_grip(stand_pose, camera.global_basis, standing_center))
	var end_hip := standing_center - camera.global_basis.y * 0.432
	var hip := CAFE_HIP.lerp(end_hip, smoothstep(0.25, 1.0, rise))
	player_pose.pose(camera, hip, "right", "rise", rise, null, Vector3.ZERO,
		Vector3.ZERO, Vector3.ZERO, case_prop.hand_world)
	case_prop.follow_standing_grip(player_pose.right_grip, camera)


func pose_player_coffee(camera: Camera3D, world: Node3D, lift: float) -> void:
	var palm := Plaza.CAFE + Vector3(0.43, 0.525, 0.27)
	player_pose.pose(camera, CAFE_HIP, "right", "seated_sip", lift,
		world.cup, Plaza.CUP_REST, HANDLE, palm)


func toggle_seat(walker: CharacterBody3D, world: Node3D) -> bool:
	if not seat.is_empty():
		release(walker, world)
		return true
	var cafe_distance := flat_distance(walker.global_position, CAFE_HIP)
	var bench_distance := flat_distance(walker.global_position, FREE_BENCH)
	if minf(cafe_distance, bench_distance) > 1.3:
		return false
	seat = "cafe" if cafe_distance < bench_distance else "bench"
	sip_time = -1.0
	ensure_player_pose()
	player_pose.show()
	walker.velocity = Vector3.ZERO
	walker.enabled = false
	walker.sprite.hide()
	world.plaza.travel_luggage.visual_root.hide()
	return true


func release(walker: CharacterBody3D, world: Node3D) -> void:
	if seat.is_empty():
		return
	seat = ""
	sip_time = -1.0
	world.cup.global_position = Plaza.CUP_REST
	world.plaza.travel_luggage.visual_root.show()
	player_pose.hide()
	if is_instance_valid(walker):
		walker.sprite.show()
		walker.enabled = true


func drink() -> bool:
	if seat != "cafe" or sip_time >= 0.0:
		return false
	sip_time = 0.0
	return true


func tick(delta: float, camera: Camera3D, world: Node3D) -> void:
	for entry: Dictionary in npc_views:
		var actor: Node3D = entry.actor
		var rig: Node3D = entry.rig
		if entry.coffee:
			var sign_x := 1.0 if actor.facing_side == "right" else -1.0
			var hip := actor.global_position + Vector3(0.0, 0.45, 0.0)
			var palm: Vector3 = actor.saucer + Vector3(-0.18 * sign_x, 0.035, 0.19)
			var rest: Vector3 = actor.to_global(actor.cup_rest - actor.position)
			rig.pose(camera, hip, actor.facing_side, actor.action, actor.sip_lift,
				actor.cup, rest, Vector3(-0.14 * sign_x, 0.01, 0.0), palm)
		else:
			rig.pose(camera, actor.hip_anchor.global_position, "front", actor.action,
				0.7 if actor.pose_index != 0 else 0.0)
	if seat == "bench":
		player_pose.pose(camera, FREE_BENCH, "front", "bench_rest", 0.0)
	elif seat == "cafe":
		var lift := 0.0
		if sip_time >= 0.0:
			sip_time += delta
			lift = smoothstep(0.0, 0.65, sip_time) * (1.0 - smoothstep(1.35, 2.05, sip_time))
			if sip_time >= 2.05:
				sip_time = -1.0
		pose_player_coffee(camera, world, lift)


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

