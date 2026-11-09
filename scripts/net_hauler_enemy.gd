extends "res://scripts/coastal_enemy.gd"
const NetArt=preload("res://scripts/net_hauler_art.gd")
var _view:="right"
var _committed_view:="right"
var _moved:=Vector3.ZERO
var _walk_clock:=0.0
func _ready() -> void:
	super._ready();_stats.speed=.85
	_profile={"name":"ลูกเรือลากอวน","pixel_size":.03,"foot_pixel":120,"body_radius":.34,"body_height":2.7,"body_crop":Rect2i(23,20,63,101)}
	sprite.sprite_frames=NetArt.frames();sprite.pixel_size=_profile.pixel_size;sprite.animation="right_idle";sprite.frame=0;sprite.flip_h=false
	nameplate.text=_profile.name
	for child in get_children():
		if child is CollisionShape3D:child.shape.radius=.34;child.shape.height=2.7;child.position.y=1.35
func net_hauler_direction() -> String:return _view
func impact_geometry(view: String,camera: Camera3D) -> Dictionary:
	var box: Rect2=NetArt.IMPACT_BOX[view]
	var pixel:=Vector2(box.get_center().x,box.end.y)
	var offset: Vector3=camera.global_basis.x*((pixel.x-float(NetArt.ROOT_X[view]))*sprite.pixel_size)+camera.global_basis.y*((120-pixel.y)*sprite.pixel_size)
	var ray:=camera.global_basis.z.normalized();offset+=ray*(-offset.y/ray.y)
	# Head footprint plus the player's physical contact radius, also drawn by
	# the warning. It is not extra hidden weapon reach.
	return {"offset":offset,"radius":maxf(box.size.x,box.size.y)*sprite.pixel_size*.5+.35}
func _attack_definition(index: int) -> Dictionary:
	var data:=Roster.attack("net_hauler",index)
	var parryable:=posmod(index,3)!=2
	data.merge({"id":"net_overhead","shape":"lane","width":.1,"reach":0.0,"trigger":3.0,"windup":NetArt.WINDUP,"active":NetArt.ACTIVE,"recovery":NetArt.RECOVERY,"impact":0.0,"damage":24.0,"parryable":parryable,"base_parryable":parryable,"variant":false,"impact_offset":Vector3.ZERO},true)
	return data
func _can_begin_attack(direction_: Vector3,_data: Dictionary,game) -> bool:
	var geometry:=impact_geometry(NetArt.direction(direction_,game.camera),game.camera)
	var landing: Vector3=global_position+geometry.offset
	return landing.distance_to(game.enemy_target_for(self).global_position)<=float(geometry.radius) and _landing_line_clear(landing,game.enemy_target_for(self).global_position)
func _locked_attack_angle(direction_: Vector3,game) -> float:
	_committed_view=NetArt.direction(direction_,game.camera)
	var geometry:=impact_geometry(_committed_view,game.camera)
	attack_data.width=geometry.radius*2;attack_data.impact_offset=geometry.offset
	return atan2(geometry.offset.z,geometry.offset.x)
func threatens(point: Vector3) -> bool:
	var landing: Vector3=global_position+attack_data.get("impact_offset",Vector3.ZERO)
	return not attack_data.is_empty() and Attacks.contains(landing,attack_angle,point,attack_data) and _landing_line_clear(landing,point)
func _landing_line_clear(landing: Vector3,point: Vector3) -> bool:
	if landing.distance_squared_to(point)<.000001:return true
	var query:=PhysicsRayQueryParameters3D.create(landing+Vector3.UP*.65,point+Vector3.UP*.65,1)
	query.hit_from_inside=true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func _steer(move: Vector3,game) -> Vector3:
	var relative: Vector3=game.enemy_target_for(self).global_position-global_position;relative.y=0
	# A fixed image-registered hammer landing is not a centered radial attack.
	# Approach its valid strike position rather than oscillating along diagonals.
	if relative.length()<3.6:
		var geometry:=impact_geometry(NetArt.direction(relative,game.camera),game.camera)
		var desired: Vector3=relative-geometry.offset;desired.y=0
		if desired.length_squared()>.000001:move=desired.normalized()*float(_stats.speed)
	return super._steer(move,game)
func tick(delta: float,game,advance_status: bool=true) -> void:
	_moved=Vector3.ZERO;super.tick(delta,game,advance_status)
func _move(displacement: Vector3,game) -> void:
	var before:=global_position;super._move(displacement,game);_moved+=global_position-before
func _advance(delta: float,game) -> void:
	var was_windup:=state=="windup";super._advance(delta,game)
	if was_windup and state=="attack":_resolve_attack(game)
func _resolve_attack(game) -> void:
	if dead or attack_hit or attack_data.is_empty():return
	attack_hit=true
	var landing: Vector3=global_position+attack_data.impact_offset
	if game.vision.can_see(landing):game.audio.play("slam");game.fx.burst(landing+Vector3.UP*.05,Color("b9a480"),8)
	game.check_perfect_evade(self)
	game.damage_companions_in_attack(self)
	if not threatens(game.player.global_position) or not line_of_sight(game.player.global_position):return
	contact_count+=1
	game.incoming_attack(attack_data.damage,global_position,attack_data.parryable,self,attack_data.guard_cost,attack_data.body_part,attack_data.body_damage,&"area")
func image_hurt_regions(height: float) -> Array:
	var crop: Rect2i={"left":Rect2i(48,20,68,101),"front":Rect2i(24,20,66,101),"back":Rect2i(56,20,56,101),"right":Rect2i(23,20,63,101)}[_view]
	if state=="windup" and sprite.frame>=1:crop.position.y=45;crop.size.y=76
	var regions:=ImageHurt.regions(sprite,crop,height)
	return regions if not regions.is_empty() else super.image_hurt_regions(height)
func _pose(game) -> void:
	if state in ["windup","attack","recover","parried"]:_view=_committed_view
	elif not dead:
		var facing: Vector3=_moved if _moved.length_squared()>.000001 else game.player.global_position-global_position
		if facing.length_squared()>.000001:_view=NetArt.direction(facing,game.camera)
	sprite.global_basis=game.camera.global_basis;sprite.offset=Vector2(64-int(NetArt.ROOT_X[_view]),0)
	sprite.global_position=global_position+game.camera.global_basis.y*((120-64)*sprite.pixel_size)
	bar.global_position=global_position+game.camera.global_basis.y*2.9;nameplate.global_position=global_position+game.camera.global_basis.y*3.15
	_update_overhead_visibility(game);sprite.flip_h=false
	sprite.modulate=Color(1.5,1.5,1.5) if _hurt_time>0 else Color.WHITE
	var phase:="idle";var frame_index:=0
	if dead:phase="death";sprite.modulate=Color(.65,.65,.65,maxf(0,1-maxf(0,death_time-.4)*1.5))
	elif _hurt_time>0 or state=="parried":phase="hit"
	elif state in ["windup","attack","recover"]:
		phase=state;frame_index=NetArt.phase_frame(phase,telegraph_left if phase=="windup" else cooldown)
	elif _moved.length_squared()>.000001:
		phase="walk";_walk_clock+=_moved.length()/float(_stats.speed);frame_index=int(_walk_clock/NetArt.WALK_FRAME)%6
	sprite.animation=_view+"_"+phase;sprite.frame=frame_index
	if state=="windup" and not attack_data.get("parryable",true):sprite.modulate=Color(1.6,.35,.28)
	elif _parry_flash>0:sprite.modulate=Color(.45,1.5,1.7)
	attack_visual.global_position=global_position+attack_data.get("impact_offset",Vector3.ZERO)
	attack_visual.update_view(attack_data,attack_angle,state,telegraph_left)
	for extra in fan_guides:extra.visible=false
