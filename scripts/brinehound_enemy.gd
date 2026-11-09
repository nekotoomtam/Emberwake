extends "res://scripts/coastal_enemy.gd"
const Rules=preload("res://scripts/brinehound_rules.gd")
const DogArt=preload("res://scripts/brinehound_art.gd")
var phase:=-1
var phase_left:=0.0
var _view:="right"
var _locked_view:="right"
var _moved:=Vector3.ZERO
var _run_clock:=0.0
var _pounce_total:=0.0
var _pounce_used:=0.0
var _sequence_index:=0
var bite_attempts:=0
var _windup_preview_key: Array=[]
var _windup_landing:=Vector3.ZERO
func _ready() -> void:
	super._ready()
	_stats.speed=Rules.SPEED;health=Rules.HEALTH;max_health=health
	_profile={"name":"หมาล่าเนื้อน้ำเค็ม","pixel_size":.026,"foot_pixel":115,"body_radius":.38,"body_height":1.65}
	_profile.body_crop=Rect2i(27,40,85,78)
	sprite.sprite_frames=DogArt.frames();sprite.pixel_size=_profile.pixel_size;sprite.animation="right_idle";sprite.frame=0;sprite.flip_h=false
	for child in get_children():
		if child is CollisionShape3D:child.shape.radius=.38;child.shape.height=1.3;child.position.y=.65
	update_bar()
func brinehound_direction() -> String:return _view
func tick(delta: float,game,advance_status: bool=true) -> void:
	_moved=Vector3.ZERO;super.tick(delta,game,advance_status)
func _move(displacement: Vector3,game) -> void:
	var before:=global_position;super._move(displacement,game);_moved+=global_position-before
func _clear_sequence() -> void:
	phase=-1;phase_left=0;_pounce_total=0;_pounce_used=0
func _advance(delta: float,game) -> void:
	clock+=delta;_hurt_time=maxf(0,_hurt_time-delta);_parry_flash=maxf(0,_parry_flash-delta)
	if dead:_clear_sequence();death_time+=delta;return
	cooldown=maxf(0,cooldown-delta);stagger=maxf(0,stagger-delta)
	if phase>=0 and (attack_data.is_empty() or state=="parried"):_clear_sequence()
	if global_position.distance_to(home_position)>float(_stats.leash):
		_clear_sequence();attack_data={};returning=true;engaged=false;state="chase"
	if stagger<=0:
		if phase>=0:_advance_sequence(delta,game)
		elif returning:
			var home:=home_position-global_position;home.y=0
			if home.length()<.25:returning=false;state="idle"
			else:_move(home.normalized()*Rules.SPEED*delta,game)
		elif state=="parried":
			if cooldown<=0:state="chase"
		else:
			var combat_target: Vector3=game.enemy_target_for(self).global_position
			var offset: Vector3=combat_target-global_position;offset.y=0
			var distance:=offset.length()
			if not engaged and distance<=float(_stats.detection) and line_of_sight(combat_target):engaged=true
			if engaged:
				state="chase"
				if not _advance_distant_chase(delta,game,offset):
					if distance<=Rules.TRIGGER and cooldown<=0 and line_of_sight(combat_target):_begin(game,offset)
					elif distance>.9:_move(_steer(offset.normalized()*float(_stats.speed),game)*delta,game)
			else:state="idle"
	knockback=knockback.move_toward(Vector3.ZERO,delta*14)
	if knockback.length_squared()>.001:_move(knockback*delta,game)
func _begin(game,offset: Vector3) -> void:
	var direction_:=offset.normalized() if offset.length_squared()>.000001 else Vector3.RIGHT
	attack_angle=atan2(direction_.z,direction_.x);target_point=global_position+offset
	_locked_view=DogArt.direction(direction_,game.camera);_view=_locked_view
	_sequence_index=attack_index;attack_index+=1;bite_attempts=0
	_enter_phase(0,game)
func _enter_phase(index: int,game) -> void:
	if index>=6:
		_clear_sequence();attack_data={};state="chase";cooldown=.5;telegraph_left=0;active_left=0;return
	phase=index;phase_left=Rules.DURATIONS[index];attack_data=Rules.attack(_sequence_index,index)
	attack_data.parryable=game.health>0
	state="windup" if index in [0,3] else "recover" if index==5 else "attack"
	telegraph_left=phase_left if state=="windup" else 0.0
	active_left=phase_left if state=="attack" else 0.0
	if index==5:cooldown=phase_left
	attack_hit=false
	if index==1:
		var offset:=target_point-global_position;offset.y=0
		_pounce_total=Rules.pounce_distance(offset.length());_pounce_used=0
	if index in [2,4]:_bite(game)
func _advance_sequence(delta: float,game) -> void:
	var left:=delta
	while left>.000000001 and phase>=0 and not dead and not attack_data.is_empty():
		var dt:=minf(left,phase_left)
		if phase==1 and _pounce_total>0:
			var travel:=minf(_pounce_total-_pounce_used,_pounce_total*dt/float(Rules.DURATIONS[1]))
			if travel>0:_move(Vector3(cos(attack_angle),0,sin(attack_angle))*travel,game);_pounce_used+=travel
		phase_left=maxf(0,phase_left-dt);left=maxf(0,left-dt)
		telegraph_left=phase_left if state=="windup" else 0.0
		active_left=phase_left if state=="attack" else 0.0
		if phase==5:cooldown=phase_left
		if phase_left<=.000000001:_enter_phase(phase+1,game)
func _bite(game) -> void:
	if dead or attack_hit or attack_data.is_empty():return
	attack_hit=true;bite_attempts+=1
	game.audio.play("enemy_attack")
	game.check_perfect_evade(self)
	game.damage_companions_in_attack(self)
	if not threatens(game.player.global_position) or not line_of_sight(game.player.global_position):return
	contact_count+=1
	game.incoming_attack(attack_data.damage,global_position,attack_data.parryable,self,attack_data.guard_cost,attack_data.body_part,attack_data.body_damage)
func windup_threatens(target: Vector3) -> bool:
	if attack_data.is_empty(): return false
	var origin := global_position
	if phase == 0:
		var direction := Vector3(cos(attack_angle), 0, sin(attack_angle))
		origin += direction * Rules.pounce_distance(origin.distance_to(target_point))
	return Attacks.contains(origin, attack_angle, target, attack_data)

func threatens(target: Vector3) -> bool:
	return phase in [2,4] and not attack_data.is_empty() and Attacks.contains(global_position,attack_angle,target,attack_data)
func receive_parry() -> void:
	super.receive_parry();_clear_sequence()
func _receive_hit(amount: float,force: Vector3,duration: float,keep_red: bool) -> float:
	var result: float=super._receive_hit(amount,force,duration,keep_red)
	if dead or attack_data.is_empty():_clear_sequence()
	return result
func next_boundary() -> float:
	if dead:return INF
	# Keep player defense timers and swept approach/pounce on the same clock,
	# including the first tick that starts a new sequence after an idle/chase.
	var boundary: float=stagger if stagger>0 else maxf(.000001,phase_left) if phase>=0 else INF
	return minf(boundary,1.0/120.0)
func _pose(game) -> void:
	if phase>=0:_view=_locked_view
	elif not dead and _hurt_time<=0 and state!="parried":
		var facing: Vector3=_moved if _moved.length_squared()>.000001 else game.player.global_position-global_position
		if facing.length_squared()>.000001:_view=DogArt.direction(facing,game.camera)
	sprite.global_basis=game.camera.global_basis
	sprite.global_position=global_position+game.camera.global_basis.y*((115-64)*sprite.pixel_size)+game.camera.global_basis.x*(4*sprite.pixel_size)
	bar.global_position=global_position+game.camera.global_basis.y*1.8;nameplate.global_position=global_position+game.camera.global_basis.y*2.0
	_update_overhead_visibility(game);sprite.flip_h=false
	sprite.modulate=Color(1.5,1.5,1.5) if _hurt_time>0 else Color.WHITE
	var animation_:="idle";var frame_index:=0
	if dead:animation_="death";sprite.modulate=Color(.65,.65,.65,maxf(0,1-maxf(0,death_time-.4)*1.5))
	elif _hurt_time>0 or state=="parried":animation_="hit"
	elif phase>=0:animation_="sequence";frame_index=phase
	elif _moved.length_squared()>.000001:
		animation_="run";_run_clock+=_moved.length()/Rules.SPEED;frame_index=int(_run_clock/Rules.RUN_FRAME)%6
	sprite.animation=_view+"_"+animation_;sprite.frame=frame_index
	if state=="windup" and game.health<=0:sprite.modulate=Color(1.6,.35,.28)
	elif _parry_flash>0:sprite.modulate=Color(.45,1.5,1.7)
	var guide:=attack_data.duplicate()
	attack_visual.position=Vector3.ZERO
	var guide_phase:=state
	if phase in [0,1] and not guide.is_empty():
		# Travel itself is harmless. Preview the actual bite at the landing,
		# including the same capsule wall stop AND remainder slide as _move.
		attack_visual.position=_guide_landing(game)-global_position
		guide.windup=Rules.DURATIONS[phase];guide_phase="windup"
	attack_visual.update_view(guide,attack_angle,guide_phase,telegraph_left if phase!=1 else phase_left)
	for extra in fan_guides:extra.visible=false
func _guide_landing(game) -> Vector3:
	if phase!=0 or not attack_visual.cache_static_walls:
		return _predicted_landing(game)
	var key: Array=[global_transform,target_point,attack_angle]
	if key!=_windup_preview_key:
		_windup_preview_key=key
		_windup_landing=_predicted_landing(game)
	return _windup_landing
func _predicted_landing(game) -> Vector3:
	var total:=Rules.pounce_distance(global_position.distance_to(target_point)) if phase==0 else _pounce_total
	var remaining:=total if phase==0 else maxf(0,_pounce_total-_pounce_used)
	if remaining<.000001:return global_position
	var virtual:=global_transform
	var direction:=Vector3(cos(attack_angle),0,sin(attack_angle))
	var collision:=KinematicCollision3D.new();var slide_collision:=KinematicCollision3D.new()
	# Game uses <=1/120s pounce steps. Simulate transforms without moving the
	# actual body so edge/corner slides also agree with the eventual landing.
	var step_length:=total/(float(Rules.DURATIONS[1])*120.0)
	while remaining>.000001:
		var length_:=minf(remaining,step_length);var step:=direction*length_
		if test_move(virtual,step,collision):
			virtual.origin+=collision.get_travel()
			var slide:=collision.get_remainder().slide(collision.get_normal())
			if slide.length_squared()>.00000001:
				virtual.origin+=slide_collision.get_travel() if test_move(virtual,slide,slide_collision) else slide
		else:virtual.origin+=step
		if is_instance_valid(game.arena) and game.arena.has_method("clamp_point"):virtual.origin=game.arena.clamp_point(virtual.origin)
		remaining-=length_
	return virtual.origin
