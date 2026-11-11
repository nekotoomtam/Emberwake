extends "res://scripts/enemy.gd"
const BODY_SCALE:=1.6
const Pose=preload("res://scripts/captain_pose.gd")
var nameplate: Label3D
const Rules=preload("res://scripts/captain_rules.gd")
const CaptainArt=preload("res://scripts/captain_art.gd")
var arm_hp:=108.0
var arm_cut:=false
var elapsed:=.0
var last_tip:=Vector3.ZERO
var view_right:=Vector3.RIGHT
var captain_view
var contact_count:=0
var landed_count:=0
var _return_hit:=false
func _ready() -> void:
 super._ready();max_health=680;health=max_health;armor_rating=100
 for child in get_children():
  if child is CollisionShape3D:child.name="BodyCollision";child.shape.radius=CaptainArt.BODY_RADIUS*BODY_SCALE;child.shape.height=1.72*BODY_SCALE;child.position.y=.86*BODY_SCALE
 sprite.sprite_frames=CaptainArt.frames();sprite.animation="idle";sprite.frame=0;sprite.pixel_size=.018*BODY_SCALE;bar.position.y=3.0
 attack_visual.visible=false
 captain_view=preload("res://scripts/captain_attack_view.gd").new();captain_view.captain=self;add_child(captain_view)
 nameplate=Label3D.new();nameplate.text="นายท้ายผู้ลากสมอ";nameplate.position.y=3.25;nameplate.billboard=BaseMaterial3D.BILLBOARD_ENABLED;nameplate.no_depth_test=true;nameplate.font_size=32;nameplate.pixel_size=.008
 var font:=SystemFont.new();font.font_names=PackedStringArray(["Tahoma"]);nameplate.font=font;add_child(nameplate);update_bar()
func hurt_regions() -> Array:
 var side: float=-1 if sprite.flip_h else 1
 var regions: Array=[]
 if not arm_cut:
  var point: Vector2=CaptainArt.arm_center_pixel(sprite.animation,sprite.frame)
  regions.append({"id":"chain_arm","position":global_position+view_right*(point.x-64)*sprite.pixel_size*side,"radius":CaptainArt.ARM_RADIUS*BODY_SCALE})
 regions.append({"id":"body","position":global_position,"radius":CaptainArt.BODY_RADIUS*BODY_SCALE});return regions
func register_melee_contact(region: String,amount: float,family: String) -> bool:
 if dead or arm_cut or region!="chain_arm" or family not in ["sword","greatsword"] or not is_finite(amount) or amount<=0:return false
 arm_hp=maxf(0,arm_hp-amount)
 if arm_hp>0:return false
 arm_cut=true;sprite.sprite_frames=CaptainArt.frames(true)
 if attack_data.get("id","")=="throw":state="recover";cooldown=.75;attack_data={};active_left=0
 return true
func _receive_hit(amount: float,force: Vector3,duration: float,keep_red: bool) -> float:
 var old_state:=state;var old_data:=attack_data;var old_cd:=cooldown;var old_tell:=telegraph_left;var old_active:=active_left
 var keep: bool=state!="parried" and duration<=0
 var result: float=super._receive_hit(amount,force*.08,duration*.5 if duration>0 else duration,keep_red)
 if not dead and keep:state=old_state;attack_data=old_data;cooldown=old_cd;telegraph_left=old_tell;active_left=old_active;stagger=0;knockback=Vector3.ZERO
 return result
func threatens(target: Vector3) -> bool:return not attack_data.is_empty() and Rules.contains(position,attack_angle,target,attack_data)
func tick(delta: float,game,advance_status: bool=true) -> void:
 if delta<=0 or not is_finite(delta):return
 if advance_status:advance_combat_status(delta)
 view_right=game.camera.global_basis.x;view_right.y=0;view_right=view_right.normalized()
 clock+=delta;_hurt_time=maxf(0,_hurt_time-delta);_parry_flash=maxf(0,_parry_flash-delta)
 sprite.global_basis=game.camera.global_basis;sprite.global_position=global_position+game.camera.global_basis.y*(.864*BODY_SCALE)
 bar.global_position=global_position+game.camera.global_basis.y*3.02
 nameplate.global_position=global_position+game.camera.global_basis.y*3.25
 sprite.modulate=Color(1.5,1.5,1.5) if _hurt_time>0 else Color.WHITE
 if dead:
  death_time+=delta;sprite.animation="death";sprite.frame=mini(2,int(death_time*5));sprite.modulate.a=maxf(0,1-maxf(0,death_time-.35)*2);captain_view.update_view(game);return
 cooldown=maxf(0,cooldown-delta);stagger=maxf(0,stagger-delta)
 var offset: Vector3=game.enemy_target_for(self).global_position-global_position;offset.y=0
 var direction:=offset.normalized();var distance:=offset.length();var move:=Vector3.ZERO
 if state=="chase":sprite.flip_h=view_right.dot(direction)<0;attack_angle=atan2(direction.z,direction.x)
 if stagger<=0:
  if state=="windup":
   if telegraph_left>.35:attack_angle=lerp_angle(attack_angle,atan2(direction.z,direction.x),minf(1,delta*3))
   telegraph_left=maxf(0,telegraph_left-delta)
   if telegraph_left<=0:state="attack";elapsed=0;active_left=attack_data.active;last_tip=position+Rules.tip(attack_data,attack_angle,0)
  elif state=="attack":
   var previous:=elapsed;elapsed=minf(float(attack_data.active),elapsed+delta);active_left=maxf(0,float(attack_data.active)-elapsed)
   if attack_data.id=="throw" and previous<float(attack_data.return_start) and elapsed>=float(attack_data.return_start):
    attack_hit=false
    attack_data.erase("companions_hit")
   var tip: Vector3=position+Rules.tip(attack_data,attack_angle,elapsed)
   if Rules.damaging(attack_data,elapsed) and Rules.contact(last_tip,tip,game.rewards.dodge_origin,attack_data):game.check_perfect_evade(self)
   if attack_data.id=="slam":
    if previous<float(attack_data.active)*float(attack_data.impact) and Rules.damaging(attack_data,elapsed):game.fx.ring(tip,float(attack_data.radius),Color(1,.7,.4,.8),.22)
   if Rules.damaging(attack_data,elapsed) and not game.companions.is_empty():
    game.damage_companions_in_attack(self, func(point: Vector3) -> bool: return Rules.contact(last_tip,tip,point,attack_data))
   if not attack_hit and Rules.damaging(attack_data,elapsed) and Rules.contact(last_tip,tip,game.player.position,attack_data):
    attack_hit=true;contact_count+=1
    var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.65,game.player.position+Vector3.UP*.65,1)
    if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
     var delivery: StringName = &"area" if attack_data.id=="slam" else (&"projectile" if attack_data.id=="throw" else &"melee")
     var hp: float=game.health
     game.incoming_attack(attack_data.damage,position,attack_data.parryable,self,attack_data.guard_cost,attack_data.body_part,attack_data.body_damage,delivery)
     if game.health<hp:landed_count+=1
   last_tip=tip
   if state=="attack" and active_left<=0:state="recover";cooldown=attack_data.recovery
  elif state in ["recover","parried"]:
   if cooldown<=0:state="chase";attack_data={}
  elif cooldown<=0:
   var names: Array=["sweep","throw","slam"] if not arm_cut else ["sweep","slam"]
   var id: String=names[attack_index%names.size()]
   if not arm_cut and distance>3:id="throw"
   var trigger: float=Rules.definition(id).trigger
   if distance<=trigger:
    attack_data=Rules.definition(id);attack_data.parryable=game.enemy_attack_parryable(attack_data.base_parryable, global_position);attack_index+=1;state="windup";telegraph_left=attack_data.windup;attack_angle=atan2(direction.z,direction.x);attack_hit=false;elapsed=0
   else:
    move = direction * 1.8
    if game.get("encounter_mode") == "dungeon":
     move = game.arena.steer_around_cover(position,move*1.35,distance)
 if state in ["windup","attack","recover"]:
  var across: float=view_right.dot(Vector3(cos(attack_angle),0,sin(attack_angle)))
  if absf(across)>.08:sprite.flip_h=across<0
 if not attack_data.is_empty() and attack_data.id=="throw" and (state=="windup" or (state=="attack" and elapsed<float(attack_data.release))):configure_throw_launch()
 velocity=move*movement_speed_scale();velocity.y=-2;move_and_slide()
 var pose: Dictionary=Pose.sample(attack_data,state,telegraph_left,elapsed,cooldown,attack_angle)
 sprite.animation=pose.animation if state in ["windup","attack","recover","parried"] else ("hit" if _hurt_time>0 else "walk" if move.length()>.1 else "idle")
 sprite.frame=int(pose.frame) if state in ["windup","attack","recover","parried"] else int(clock*(8 if move.length()>.1 else 2))%sprite.sprite_frames.get_frame_count(sprite.animation)
 if _parry_flash>0:sprite.modulate=Color(.5,1.5,1.7)
 captain_view.update_view(game)

func pixel_world(point: Vector2) -> Vector3:
 if sprite.flip_h:point.x=128-point.x
 return sprite.global_transform*Vector3((point.x-64)*sprite.pixel_size,(64-point.y)*sprite.pixel_size,0)
func chain_wrist() -> Vector3:
 return pixel_world(CaptainArt.hand_pixel(sprite.animation,sprite.frame,arm_cut))

func configure_throw_launch() -> void:
 if attack_data.is_empty() or attack_data.id!="throw":return
 var hand: Vector2=CaptainArt.hand_pixel("throw_active",3,false)
 var side: float=-1 if sprite.flip_h else 1
 attack_data.launch=view_right*(hand.x-64)*sprite.pixel_size*side
 attack_data.launch_lift=(112-hand.y)*sprite.pixel_size-(64-CaptainArt.anchor_ring_pixel().y)*Rules.ANCHOR_PIXEL_SIZE-Rules.VISUAL_HEIGHT
