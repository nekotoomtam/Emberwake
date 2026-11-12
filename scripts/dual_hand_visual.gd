extends Node3D
## Stable item-to-hand assignment: the inactive weapon never impersonates the active one.
const ReadyPose=preload("res://scripts/ready_pose.gd")
const Dash=preload("res://scripts/dash_visual.gd")
const Carry = preload("res://scripts/paired_carry.gd")
const Stance = preload("res://scripts/weapon_stance.gd")
const Hero = preload("res://scripts/hero_visual.gd")
const Motion = preload("res://scripts/weapon_motion.gd")
const SHOULDER := .22
var rigs: Array = []
var rest_motions: Array = []
var ids: Array[String] = ["", ""]
var poses: Array[Dictionary] = [{}, {}]
var entry: Array[Dictionary] = [{}, {}]
var was_active: Array[bool] = [false,false]
var tags: Array[String] = ["", ""]
var entry_offsets: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]

static func origin(base: Vector3, angle: float, hand: int) -> Vector3:
	return base + Vector3(-sin(angle),0,cos(angle)) * (SHOULDER if hand==0 else -SHOULDER)

static func mirror(pose: Dictionary, angle: float) -> Dictionary:
	var result := pose.duplicate(true)
	if result.has("angle"): result.angle=2*angle-float(result.angle)
	if result.has("body_lean"): result.body_lean=-float(result.body_lean)
	return result

static func weighted_pose(pose: Dictionary, family: String, left: bool) -> Dictionary:
	var result := pose.duplicate(true)
	result.body_lean=float(result.get("body_lean",0))*1.25
	if family!="pistol" or result.get("phase","") not in ["windup","active","recovery"]:return result
	var progress: float=clampf(result.get("progress",0),0,1)
	var kick := 0.0
	if result.phase=="active":
		if progress<.35:
			var rise := progress/.35
			kick=rise*(2-rise)
		else:kick=lerpf(1,.70,(progress-.35)/.65)
	elif result.phase=="recovery":kick=.70*(1-progress*progress*(3-2*progress))
	result.radius=float(result.radius)-.12*kick
	result.pitch=float(result.pitch)+.18*kick
	result.grip_height=float(result.grip_height)+.025*kick
	result.body_lean += (.05 if left else -.05)*kick
	return result

func _ready() -> void:
	for i in range(2):
		var rig := Hero.new();add_child(rig)
		rig.body.visible=false
		for child in rig.get_children():
			if child is MeshInstance3D: child.visible=false
		rig.weapon.render_priority=4 if i==0 else 3
		rigs.append(rig)
		rest_motions.append(Motion.new())

func blend(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	return Stance.blend(a,b,t)

func update_hands(camera: Camera3D, direction: Vector3, item_ids: Array, families: Array, active_hand: int, sample: Dictionary, attacking: bool, delta: float, dead: bool, center_primary: bool=false,body_facing: String="",shoulders: Array=[],dash: Dictionary={},ready_mode: String="") -> void:
	visible=not dead
	var angle := atan2(direction.z,direction.x)
	if body_facing=="":body_facing=Hero.Directions.choose(direction,camera,"front",Hero.Directions.COMBAT_FRONT_HALF_ANGLE)
	for i in range(2):
		var rig = rigs[i]
		var family: String=families[i]
		var changed := ids[i]!=str(item_ids[i])
		if changed:
			ids[i]=str(item_ids[i]);rig.set_weapon_family(family);rest_motions[i].set_family(family);poses[i]={};entry[i]={};was_active[i]=false
		var presenting: bool=dash.is_empty() and ((ready_mode=="guard" and i==0) or (ready_mode=="shield" and family=="shield") or (ready_mode=="aim" and family in ["pistol","rifle"]))
		var rest: Dictionary=ReadyPose.pose(family,angle,ready_mode) if presenting else Dash.tuck(Carry.rest(family,body_facing,i,camera),dash)
		var shoulder: Vector3=shoulders[i] if shoulders.size()==2 else global_position+Vector3.UP*.90+camera.global_basis.x*Carry.side(body_facing,i)*.288
		var carry_root: Vector3=Carry.wrist(shoulder,camera,body_facing,i)
		if not dash.is_empty():carry_root=Dash.wrist(shoulder,camera,Carry.side(body_facing,i),dash.amount)
		var goal: Vector3=global_position if center_primary and i==0 else origin(global_position,angle,i)
		if poses[i].is_empty():
			poses[i]=rest.duplicate(true)
			rig.global_position=carry_root
		if presenting:carry_root=goal
		var acting := attacking and i==active_hand
		if acting:
			var tag: String=sample.get("action_tag","")
			if not was_active[i] or tag!=tags[i]:
				entry[i]=poses[i].duplicate(true)
				entry_offsets[i]=rig.global_position-global_position
			tags[i]=tag
			var weight := 1.0
			if sample.phase in ["windup","reload"]:
				var progress: float=clampf(sample.get("progress",0)/( .15 if sample.phase=="reload" else 1.0),0,1)
				weight=progress*progress*(3-2*progress)
			poses[i]=blend(entry[i],sample,weight) if weight<1 else sample.duplicate(true)
		else:
			poses[i]=blend(poses[i],rest,1-exp(-14*delta))
			poses[i].phase="idle"
			poses[i].trail=false
		rig.weapon.render_priority=5 if acting or presenting else (4 if Carry.front_hand(body_facing,i) else 1)
		was_active[i]=acting
		if acting:
			var approach := 1.0
			if sample.phase in ["windup","reload"]:
				var p: float=clampf(sample.get("progress",0)/( .15 if sample.phase=="reload" else 1.0),0,1)
				approach=p*p*(3-2*p)
			rig.global_position=(global_position+entry_offsets[i]).lerp(goal,approach)
		else:rig.global_position=rig.global_position.lerp(carry_root,1-exp(-14*delta))
		poses[i].stance_managed=true;poses[i].paired_carry=true;poses[i].left_carry=i==1;poses[i].shoulder_world=shoulder
		rig.update_pose(camera,direction,false,poses[i],2.1,0,0,delta,dead)
		rig.grip_visual.render_priority=4 if acting or presenting else (3 if Carry.front_hand(body_facing,i) else 1)

func reset_stance() -> void:
	poses=[{},{}];entry=[{},{}];was_active=[false,false];tags=["",""]
