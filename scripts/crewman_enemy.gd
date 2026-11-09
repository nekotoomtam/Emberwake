extends "res://scripts/coastal_enemy.gd"
const CrewmanArt=preload("res://scripts/crewman_art.gd")
var _view:="right"
var _committed_view:="right"
var _moved:=Vector3.ZERO
var _walk_clock:=0.0
var throws:=0
func _ready() -> void:
	super._ready()
	_profile={"name":"ลูกเรือขว้างฉมวก","pixel_size":.0275,"foot_pixel":116,"body_radius":.28,"body_height":2.25}
	_profile.body_crop=Rect2i(35,16,54,103)
	sprite.sprite_frames=CrewmanArt.frames();sprite.pixel_size=_profile.pixel_size;sprite.animation="right_idle";sprite.flip_h=false
	nameplate.text=_profile.name
	for child in get_children():
		if child is CollisionShape3D:child.shape.radius=.28;child.shape.height=2.25;child.position.y=1.125
func crewman_direction() -> String:return _view
func projectile_texture() -> Texture2D:return CrewmanArt.projectile()
func projectile_size() -> Vector2:return Vector2(1.4,.35)
func _attack_definition(index: int) -> Dictionary:
	var data:=Roster.attack("harpooner",index)
	data.merge({"id":"hand_harpoon","windup":CrewmanArt.WINDUP,"active":CrewmanArt.ACTIVE,"recovery":CrewmanArt.RECOVERY,"impact":0.0,"variant":false},true)
	return data
func _locked_attack_angle(direction_: Vector3,game) -> float:
	_committed_view=CrewmanArt.direction(direction_,game.camera)
	return atan2(direction_.z,direction_.x)
func tick(delta: float,game,advance_status: bool=true) -> void:
	_moved=Vector3.ZERO;super.tick(delta,game,advance_status)
func _move(displacement: Vector3,game) -> void:
	var before:=global_position;super._move(displacement,game);_moved+=global_position-before
func next_boundary() -> float:return minf(1.0/120.0,super.next_boundary())
func _resolve_attack(game) -> void:
	if dead or attack_hit or attack_data.is_empty():return
	throws+=1;super._resolve_attack(game)
func projectile_launch(game) -> Dictionary:
	var pixel:=CrewmanArt.hand_pixel(_committed_view)
	var origin: Vector3=global_position+game.camera.global_basis.x*((pixel.x-64)*sprite.pixel_size)+game.camera.global_basis.y*((116-pixel.y)*sprite.pixel_size)
	var aim: Vector3=target_point-origin;aim.y=0
	var direction:=aim.normalized() if aim.length_squared()>.000001 else Vector3(cos(attack_angle),0,sin(attack_angle))
	return {"origin":origin,"direction":direction,"angle":atan2(direction.z,direction.x),"reach":_projectile_range(origin,direction)}
func _pose(game) -> void:
	if state in ["windup","attack","recover","parried"]:_view=_committed_view
	elif not dead:
		var facing: Vector3=_moved if _moved.length_squared()>.000001 else game.player.global_position-global_position
		if facing.length_squared()>.000001:_view=CrewmanArt.direction(facing,game.camera)
	sprite.global_basis=game.camera.global_basis
	sprite.global_position=global_position+game.camera.global_basis.y*(52*sprite.pixel_size)
	bar.global_position=global_position+game.camera.global_basis.y*2.4;nameplate.global_position=global_position+game.camera.global_basis.y*2.65
	_update_overhead_visibility(game);sprite.flip_h=false
	sprite.modulate=Color(1.5,1.5,1.5) if _hurt_time>0 else Color.WHITE
	var phase:="idle";var frame_index:=0
	if dead:phase="death";sprite.modulate=Color(.65,.65,.65,maxf(0,1-maxf(0,death_time-.4)*1.5))
	elif _hurt_time>0 or state=="parried":phase="hit"
	elif state in ["windup","attack","recover"]:
		phase=state;frame_index=CrewmanArt.phase_frame(phase,telegraph_left if phase=="windup" else cooldown)
	elif _moved.length_squared()>.000001:
		phase="walk";_walk_clock+=_moved.length()/float(_stats.speed);frame_index=int(_walk_clock/CrewmanArt.WALK_FRAME)%6
	sprite.animation=_view+"_"+phase;sprite.frame=frame_index
	if _parry_flash>0:sprite.modulate=Color(.45,1.5,1.7)
	var guide:=attack_data;var angle:=attack_angle
	attack_visual.position=Vector3.ZERO
	if not attack_data.is_empty():
		var launch:=projectile_launch(game);guide=attack_data.duplicate();guide.reach=launch.reach;guide.telegraph_height=launch.origin.y-global_position.y;angle=launch.angle
		attack_visual.global_position=Vector3(launch.origin.x,global_position.y,launch.origin.z)
	attack_visual.update_view(guide,angle,state,telegraph_left)
	for extra in fan_guides:extra.visible=false
