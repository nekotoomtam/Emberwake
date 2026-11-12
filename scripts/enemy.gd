extends CharacterBody3D

var crossbow_wound_ticks := 0
var crossbow_wound_time := 0.0
var crossbow_wound_from_player := true
const Attacks=preload("res://scripts/enemy_attacks.gd")
const AttackVisual=preload("res://scripts/enemy_attack_visual.gd")
var attack_visual
var attack_data: Dictionary={}
var attack_angle:=.0
var attack_index:=0
var active_left:=.0
var attack_hit:=false
var _parry_flash:=.0
const MaceArmor=preload("res://scripts/mace_armor.gd")
const MACE_PULL_TIME := .22
const MACE_PULL_CENTER_RADIUS := .34
var mace_armor=MaceArmor.new()
var rifle_mark=preload("res://scripts/rifle_mark.gd").new()
const Art = preload("res://scripts/pixel_art.gd")
var kind: String = "melee"
var health: float = 38.0
var max_health: float = 38.0
var armor_rating: float = 100.0
var armor_break_remaining: float = 0.0
var armor_break_fraction: float = 0.0
var _armor_break_duration: float = 4.0
var dead: bool = false
var state: String = "chase"
var telegraph_left: float = 0.0
var cooldown: float = 0.5
var stagger: float = 0.0
var movement_slow := 0.0
var movement_slow_remaining := 0.0
var movement_slow_duration := 0.0
const ICE_SLOW_PER_HIT := .10
const ICE_SLOW_DURATION := 5.0
const ICE_SLOW_LIMIT := 3
var ice_slow_stacks := 0
var ice_slow_remaining := 0.0
const ICE_ROOT_DURATION := .75
var ice_root_remaining := 0.0
var _mace_pull_target := Vector3.ZERO
var _mace_pull_left := 0.0
var knockback := Vector3.ZERO
var target_point := Vector3.ZERO
var sprite: AnimatedSprite3D
var bar: Sprite3D
var armor_badge: Label3D
var clock: float = 0.0
var death_time: float = 0.0
var _ring_time: float = 0.0
var _hurt_time: float = 0.0
static var bar_textures: Dictionary = {}

func _ready() -> void:
	max_health = {"melee": 38.0, "ranged": 30.0, "elite": 150.0, "dummy": 1000.0}.get(kind, 38.0)
	health = max_health
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33 if kind != "elite" else 0.48
	capsule.height = 1.4
	shape.shape = capsule
	shape.position.y = 0.7
	add_child(shape)
	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = Art.frames(kind)
	sprite.pixel_size = 0.018 * (1.2 if kind == "elite" else 1.0)
	sprite.position.y = 48 * sprite.pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	bar = Sprite3D.new()
	bar.position.y = 2.1 if kind != "elite" else 2.4
	bar.pixel_size = 0.026
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.shaded = false
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(bar)
	armor_badge = Label3D.new()
	armor_badge.position.y = bar.position.y + .25
	armor_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	armor_badge.no_depth_test = true
	armor_badge.font_size = 32
	armor_badge.pixel_size = .009
	armor_badge.modulate = Color("#ffd365")
	armor_badge.outline_size = 7
	add_child(armor_badge)
	attack_visual=AttackVisual.new();add_child(attack_visual)
	update_bar()

func update_bar() -> void:
	if not is_instance_valid(bar):return
	var width:=int(38*maxf(0,health)/max_health)
	var key:=Vector2i(width, int(kind=="elite"))
	if not bar_textures.has(key):
		var image:=Image.create(40,5,false,Image.FORMAT_RGBA8)
		image.fill(Color("#101921"))
		image.fill_rect(Rect2i(1,1,width,3),Color("#e4a85c") if kind=="elite" else Color("#d75d71"))
		bar_textures[key]=ImageTexture.create_from_image(image)
	bar.texture=bar_textures[key];bar.visible=not dead
	if is_instance_valid(armor_badge):armor_badge.visible=false

func effective_armor() -> float:
	if not is_finite(armor_rating) or armor_rating <= 0: return 0.0
	return maxf(1.0, armor_rating * (1.0 - maxf(armor_break_fraction,mace_armor.fraction())))

func calculate_incoming_damage(amount: float, element: String) -> float:
	if dead or not is_finite(amount) or amount <= 0 or not is_finite(armor_rating) or armor_rating < 0: return 0.0
	if not element.is_empty() and element != "physical": return amount
	var actual: float=amount*(100.0/effective_armor() if armor_rating>0 else 1.0)*mace_armor.physical_multiplier()
	return actual if is_finite(actual) else 0.0

func apply_armor_break(fraction: float = .2, duration: float = 4.0) -> bool:
	if dead or not is_finite(armor_rating) or armor_rating <= 0 or not is_finite(fraction) or fraction <= 0 or fraction >= 1 or not is_finite(duration) or duration <= 0: return false
	armor_break_fraction = fraction
	armor_break_remaining = duration
	_armor_break_duration = duration
	update_bar()
	return true

func apply_mace_break(amount: int = 1, fill: bool = false) -> bool:
	if dead or not is_finite(armor_rating) or armor_rating<0 or amount<=0:return false
	mace_armor.add(amount,fill);update_bar();return true

func _clear_armor_break() -> void:
	mace_armor.clear();rifle_mark.clear()
	armor_break_remaining = 0.0
	armor_break_fraction = 0.0

func receive_damage(amount: float, force: Vector3) -> void:
	_receive_hit(amount,force,-1.0,false)
func receive_great_slam(amount: float,force: Vector3,duration: float) -> float:
	if not is_finite(duration) or duration<=0:return 0.0
	return _receive_hit(amount,force,duration,true)
func _receive_hit(amount: float,force: Vector3,duration: float,keep_red: bool) -> float:
	# Amount already resolved by Game; this adds reaction only, never second armor.
	if dead or not is_finite(amount) or amount<=0 or not force.is_finite():return 0.0
	var was_parried:=state=="parried"
	var red_committed:=keep_red and state in ["windup","attack"] and not attack_data.is_empty() and not bool(attack_data.get("parryable",true))
	_parry_flash=0
	health=maxf(0,health-amount)
	var applied:=.0
	if not red_committed:
		knockback+=force
		stagger=duration*(.5 if kind=="elite" else 1.0) if duration>0 else (.24 if force.length()>4 else .15)
		applied=stagger;_hurt_time=.12
		if kind!="dummy":
			state="chase";attack_data={};active_left=0;telegraph_left=0
			cooldown=.4 if was_parried else maxf(cooldown,.4)
	else:_hurt_time=0
	if health<=0:
		dead=true;_clear_armor_break();death_time=0;state="dead";applied=0
	update_bar()
	return applied

func advance_armor_status(delta: float) -> void:
	rifle_mark.advance(delta)
	if not is_finite(delta) or delta <= 0: return
	var mace_was_active: bool=mace_armor.remaining>0
	if not dead:mace_armor.advance(delta)
	if mace_was_active:update_bar()
	if armor_break_remaining > 0 and not dead:
		armor_break_remaining = maxf(0, armor_break_remaining - delta)
		if armor_break_remaining <= 0:
			armor_break_remaining=0;armor_break_fraction=0
		update_bar()

func apply_movement_slow(fraction: float, duration: float) -> void:
	if dead or not is_finite(fraction) or not is_finite(duration) or fraction <= 0.0 or duration <= 0.0: return
	movement_slow = minf(fraction, 1.0)
	movement_slow_remaining = duration
	movement_slow_duration = duration

func apply_ice_slow() -> void:
	if dead: return
	ice_slow_stacks = mini(ice_slow_stacks + 1, ICE_SLOW_LIMIT)
	ice_slow_remaining = ICE_SLOW_DURATION

func ice_slow_fraction() -> float:
	return ice_slow_stacks * ICE_SLOW_PER_HIT

func movement_speed_scale() -> float:
	if ice_root_remaining > 0.0: return 0.0
	return 1.0 - maxf(movement_slow, ice_slow_fraction())

func apply_ice_root() -> void:
	if not dead: ice_root_remaining = ICE_ROOT_DURATION

func gather_to(center: Vector3) -> void:
	var offset := global_position - center
	offset.y = 0.0
	if dead or offset.length_squared() <= MACE_PULL_CENTER_RADIUS ** 2: return
	_mace_pull_target = center + offset.normalized() * MACE_PULL_CENTER_RADIUS
	_mace_pull_left = MACE_PULL_TIME
	knockback = Vector3.ZERO
	stagger = maxf(stagger, MACE_PULL_TIME)

func _advance_mace_pull(delta: float) -> void:
	if _mace_pull_left <= 0.0 or dead: return
	var offset := _mace_pull_target - global_position
	offset.y = 0.0
	var step := minf(delta, _mace_pull_left)
	var collision := move_and_collide(offset * (step / _mace_pull_left), false, .001)
	_mace_pull_left -= step
	if collision == null: return
	if collision.get_normal().y > .7:
		collision = move_and_collide(collision.get_remainder().slide(collision.get_normal()), false, .001)
	if collision != null: _mace_pull_left = 0.0

func advance_combat_status(delta: float) -> void:
	advance_armor_status(delta)
	if not is_finite(delta) or delta <= 0.0: return
	_advance_mace_pull(delta)
	movement_slow_remaining = 0.0 if dead else maxf(0.0, movement_slow_remaining - delta)
	if movement_slow_remaining == 0.0: movement_slow = 0.0
	ice_slow_remaining = 0.0 if dead else maxf(0.0, ice_slow_remaining - delta)
	if ice_slow_remaining == 0.0: ice_slow_stacks = 0
	ice_root_remaining = 0.0 if dead else maxf(0.0, ice_root_remaining - delta)

func tick(delta: float, game, advance_status: bool = true) -> void:
	if not is_finite(delta) or delta <= 0: return
	if advance_status: advance_combat_status(delta)
	clock += delta
	_parry_flash=maxf(0,_parry_flash-delta)
	sprite.global_basis = game.camera.global_basis
	sprite.global_position = global_position + game.camera.global_basis.y * (48 * sprite.pixel_size)
	_hurt_time = maxf(0, _hurt_time - delta)
	sprite.modulate = Color(1.5, 1.5, 1.5) if _hurt_time > 0 else Color.WHITE
	if dead:
		death_time += delta
		sprite.animation = "death"
		sprite.frame = mini(sprite.sprite_frames.get_frame_count("death") - 1, int(death_time * 9))
		sprite.modulate.a = maxf(0.0, 1.0 - maxf(0.0, death_time - 0.3) * 2.0)
		attack_visual.update_view({},0,"dead",0)
		return
	var offset: Vector3 = game.player.position - position
	offset.y = 0
	var distance: float = offset.length()
	var direction: Vector3 = offset.normalized() if distance > 0.01 else Vector3.RIGHT
	sprite.flip_h = game.camera.global_basis.x.dot(direction) < 0
	if kind == "dummy":
		sprite.animation = "hit" if _hurt_time > 0 else "idle"
		sprite.frame = 0
		return
	cooldown = maxf(0, cooldown - delta)
	stagger = maxf(0, stagger - delta)
	_ring_time -= delta
	var speed: float = 2.3 if kind == "melee" else (1.8 if kind == "elite" else 2.0)
	var range_to_attack: float = 1.4 if kind == "melee" else (2.3 if kind == "elite" else 6.0)
	var move := Vector3.ZERO
	if stagger <= 0.0:
		if state=="windup":
			telegraph_left=maxf(0,telegraph_left-delta)
			if telegraph_left<=0:
				state="attack";active_left=attack_data.active;_resolve_attack(game)
		elif state=="attack":
			_resolve_attack(game);active_left=maxf(0,active_left-delta)
			if state=="attack" and active_left<=0:state="recover";cooldown=attack_data.recovery
		elif state in ["recover","parried"]:
			if cooldown<=0:state="chase";attack_data={}
		elif distance<=range_to_attack and cooldown<=0:
			attack_data=Attacks.definition(kind,attack_index,health<max_health*.5);attack_index+=1
			attack_data.parryable = game.enemy_attack_parryable(attack_data.parryable, global_position)
			state="windup";target_point=game.player.position
			attack_angle=atan2(direction.z,direction.x);telegraph_left=attack_data.windup;attack_hit=false
		else:
			if distance>range_to_attack-.2:move=direction*speed
			elif kind=="ranged" and distance<3.3:move=-direction*speed
			for obstacle: Vector3 in game.arena.obstacles:
				var away:=position-obstacle;away.y=0
				if away.length()<1.8:move+=away.normalized()*(1.8-away.length())*4
			for other in game.enemies:
				if other!=self and is_instance_valid(other) and not other.dead:
					var away: Vector3=position-other.position;away.y=0
					if away.length()>.01 and away.length()<.8:move+=away.normalized()*1.5
	knockback = knockback.move_toward(Vector3.ZERO, delta * 14)
	velocity = move * movement_speed_scale() + knockback
	velocity.y = -2.0
	move_and_slide()
	sprite.animation = "hit" if _hurt_time > 0 else ("attack" if state in ["windup","attack","recover"] else ("walk" if move.length() > 0.1 else "idle"))
	sprite.frame = int(clock * 9.0) % sprite.sprite_frames.get_frame_count(sprite.animation)

	if state in ["windup","attack","recover"]:sprite.frame=0 if state=="windup" else (1 if state=="attack" else 2)
	attack_visual.update_view(attack_data,attack_angle,state,telegraph_left)
	if state=="windup" and not attack_data.get("parryable",true):sprite.modulate=Color(1.6,.35,.28)
	elif _parry_flash>0:sprite.modulate=Color(.45,1.5,1.7)

func _resolve_attack(game) -> void:
	if attack_hit or attack_data.is_empty() or dead:return
	if kind=="ranged":
		attack_hit=true
		game.shoot(position+Vector3.UP*.6,Vector3(cos(attack_angle),0,sin(attack_angle)),attack_data.damage,attack_data.parryable,self,attack_data.guard_cost,attack_data.reach,attack_data.get("body_part","torso"),attack_data.get("body_damage",12.0))
		return
	game.check_perfect_evade(self)
	if not Attacks.contains(position,attack_angle,game.player.position,attack_data):return
	var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.65,game.player.position+Vector3.UP*.65,1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():return
	attack_hit=true
	game.incoming_attack(attack_data.damage,position,attack_data.parryable,self,attack_data.guard_cost,attack_data.get("body_part","torso"),attack_data.get("body_damage",12.0))

func receive_parry() -> void:
	if dead:return
	state="parried";stagger=1.0;cooldown=1.0;telegraph_left=0;active_left=0;attack_hit=true
	attack_data={};_parry_flash=.3
	attack_visual.update_view({},0,"parried",0)

func receive_burn(amount: float) -> void:
	if dead or not is_finite(amount) or amount<=0:return
	health=maxf(0,health-amount)
	if health<=0:
		dead=true;_clear_armor_break();death_time=0;state="dead"
	update_bar()

func apply_rifle_mark() -> bool:
	if dead:return false
	return rifle_mark.add()
