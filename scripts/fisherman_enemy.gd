extends "res://scripts/coastal_enemy.gd"
const FishermanArt=preload("res://scripts/fisherman_art.gd")
var _game
var _view:="right"
var _committed_view:="right"
var _moved:=Vector3.ZERO
var _walk_clock:=0.0
func _ready() -> void:
	super._ready()
	_stats.speed=1.0
	_profile={"name":"ชาวประมงจมน้ำ","pixel_size":.0275,"foot_pixel":119,"body_radius":.28,"body_height":2.25}
	_profile.body_crop=Rect2i(35,16,54,105)
	sprite.sprite_frames=FishermanArt.frames();sprite.pixel_size=_profile.pixel_size
	sprite.animation="right_idle";sprite.frame=0;sprite.flip_h=false
	for child in get_children():
		if child is CollisionShape3D:
			child.shape.radius=_profile.body_radius;child.shape.height=_profile.body_height;child.position.y=float(_profile.body_height)*.5
func fisherman_direction() -> String:return _view
func _attack_definition(index: int) -> Dictionary:
	var data:=Roster.attack("fisherman",index)
	data.merge({"id":"fisherman_downward","shape":"lane","width":.8,"reach":1.25,"trigger":1.10,"windup":FishermanArt.WINDUP,"active":FishermanArt.ACTIVE,"recovery":FishermanArt.RECOVERY,"impact":0.0,"damage":14.0,"variant":false},true)
	return data
func _locked_attack_angle(direction_: Vector3,game) -> float:
	_committed_view=FishermanArt.direction(direction_,game.camera)
	var forward:=FishermanArt.ground_direction(_committed_view,game.camera)
	return atan2(forward.z,forward.x)
func _can_begin_attack(direction_: Vector3,data: Dictionary,game) -> bool:
	var view:=FishermanArt.direction(direction_,game.camera)
	var forward:=FishermanArt.ground_direction(view,game.camera)
	return Attacks.contains(global_position,atan2(forward.z,forward.x),game.enemy_target_for(self).global_position,data)
func tick(delta: float,game,advance_status: bool=true) -> void:
	_game=game;_moved=Vector3.ZERO
	super.tick(delta,game,advance_status)
func _move(displacement: Vector3,game) -> void:
	var before:=global_position
	super._move(displacement,game)
	_moved+=global_position-before
func _resolve_attack(game) -> void:
	if dead or attack_hit or attack_data.is_empty():return
	game.audio.play("enemy_attack")
	super._resolve_attack(game)
	# A downward impact is one event even when it missed. Recovery cannot catch
	# someone walking into the lane after the painted hook already landed.
	attack_hit=true
func _pose(game) -> void:
	if state in ["windup","attack","recover","parried"]:_view=_committed_view
	elif not dead:
		var facing: Vector3=_moved if _moved.length_squared()>.000001 else game.player.global_position-global_position
		if facing.length_squared()>.000001:_view=FishermanArt.direction(facing,game.camera)
	sprite.global_basis=game.camera.global_basis
	sprite.global_position=global_position+game.camera.global_basis.y*((float(_profile.foot_pixel)-64)*sprite.pixel_size)
	bar.global_position=global_position+game.camera.global_basis.y*(float(_profile.body_height)+.15)
	nameplate.global_position=global_position+game.camera.global_basis.y*(float(_profile.body_height)+.4)
	_update_overhead_visibility(game)
	sprite.flip_h=false;sprite.modulate=Color(1.5,1.5,1.5) if _hurt_time>0 else Color.WHITE
	var phase:="idle";var frame_index:=0
	if dead:
		phase="death";sprite.modulate=Color(.65,.65,.65,maxf(0,1-maxf(0,death_time-.4)*1.5))
	elif _hurt_time>0 or state=="parried":phase="hit"
	elif state in ["windup","attack","recover"]:
		phase=state;frame_index=FishermanArt.phase_frame(phase,telegraph_left if phase=="windup" else cooldown)
	elif _moved.length_squared()>.000001:
		phase="walk";_walk_clock+=_moved.length()/float(_stats.speed)
		frame_index=int(_walk_clock/FishermanArt.WALK_FRAME)%6
	sprite.animation=_view+"_"+phase;sprite.frame=frame_index
	if state=="windup" and not attack_data.get("parryable",true):sprite.modulate=Color(1.6,.35,.28)
	elif _parry_flash>0:sprite.modulate=Color(.45,1.5,1.7)
	attack_visual.update_view(attack_data,attack_angle,state,telegraph_left)
	for extra in fan_guides:extra.visible=false
