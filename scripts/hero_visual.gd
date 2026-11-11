extends Node3D
const Dash=preload("res://scripts/dash_visual.gd")
const DashArt=preload("res://scripts/dash_art.gd")
var dodge_kind := ""
var dodge_pose: Dictionary={}
const Directions = preload("res://scripts/hero_directions.gd")
var facing: String="front"
const Stance = preload("res://scripts/weapon_stance.gd")
const Grips = preload("res://scripts/body_grips_visual.gd")
const BodyParts = preload("res://scripts/body_parts_visual.gd")
const CombatCutout = preload("res://modular/scripts/combat_cutout.gd")
var anatomy = null
var crawl_ready := false
var ground_shadow: MeshInstance3D
var modular_body
var cutout: CombatCutout
var cutout_tint := Color.WHITE
var cutout_walking := false
var cutout_crawling := false
var cutout_phase := "idle"
const Art = preload("res://scripts/pixel_art.gd")
const SwordArt = preload("res://scripts/sword_art.gd")
const GreatArt = preload("res://scripts/greatsword_art.gd")
const MaceArt = preload("res://scripts/mace_art.gd")
const StaffArt = preload("res://scripts/staff_art.gd")
const PistolArt = preload("res://scripts/pistol_art.gd")
const ShieldArt = preload("res://scripts/shield_art.gd")
const CrossbowArt = preload("res://scripts/crossbow_art.gd")
const BowArt = preload("res://scripts/bow_art.gd")
const RifleArt = preload("res://scripts/rifle_art.gd")
const PIXEL: float = 0.018

func set_leap_height(height: float) -> void:
 position.y = height
 if is_instance_valid(ground_shadow): ground_shadow.position.y = .015 - height
var pair_body_mask: Sprite3D
var back_hair: Sprite3D
var body: AnimatedSprite3D
var weapon: Sprite3D
var hand: Node3D
var spin_ghosts: Array[Sprite3D]=[]
var grip_visual
var _display_pose: Dictionary = {}
var _rest_entry: Dictionary = {}
var _was_rest := true
var _from_rest := false
var clock: float = 0.0
var _display_lean := 0.0
var _display_squash := 0.0
var weapon_family: String = "sword"
var _weapon_pivot := Vector2(12, 8)
var _weapon_tip := Vector2(60, 8)
var _blade_depth := Vector3.ZERO

func _ready() -> void:
 body = AnimatedSprite3D.new()
 body.sprite_frames = Art.frames("player")
 body.pixel_size = PIXEL
 body.position.y = 48 * PIXEL
 body.billboard = BaseMaterial3D.BILLBOARD_DISABLED
 body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
 body.shaded = false
 body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
 body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(body)
 modular_body=BodyParts.new();modular_body.name="SixMajorParts";body.add_child(modular_body)
 modular_body.visible=false
 back_hair=Sprite3D.new();back_hair.pixel_size=PIXEL
 back_hair.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;back_hair.shaded=false
 back_hair.no_depth_test=true;back_hair.render_priority=6;back_hair.visible=false
 body.add_child(back_hair)
 pair_body_mask=Sprite3D.new();pair_body_mask.pixel_size=PIXEL
 pair_body_mask.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;pair_body_mask.shaded=false
 pair_body_mask.no_depth_test=true;pair_body_mask.render_priority=2;pair_body_mask.visible=false
 body.add_child(pair_body_mask)
 var shadow := MeshInstance3D.new()
 ground_shadow = shadow
 var disc := CylinderMesh.new()
 disc.top_radius = 0.38
 disc.bottom_radius = 0.38
 disc.height = 0.007
 disc.radial_segments = 20
 shadow.mesh = disc
 shadow.position.y = 0.015
 var shade := StandardMaterial3D.new()
 shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 shade.albedo_color = Color(0.03, 0.07, 0.11, 0.45)
 shadow.material_override = shade
 add_child(shadow)
 hand = Node3D.new()
 add_child(hand)
 weapon = Sprite3D.new()
 weapon.pixel_size = 0.032
 _apply_weapon_art()
 weapon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
 weapon.shaded = false
 weapon.no_depth_test = true
 weapon.render_priority = 4
 hand.add_child(weapon)
 grip_visual=Grips.new();add_child(grip_visual)
 for i in range(2):
  var ghost := Sprite3D.new();ghost.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
  ghost.shaded=false;ghost.no_depth_test=true;ghost.visible=false
  hand.add_child(ghost);spin_ghosts.append(ghost)

func set_weapon_family(id: String) -> bool:
 if id not in ["sword", "greatsword", "mace", "staff", "pistol", "rifle", "bow", "crossbow", "shield"]:
  return false
 if weapon_family!=id:
  _display_pose={};_rest_entry={};_was_rest=true;_from_rest=false
 weapon_family = id
 if weapon != null:
  _apply_weapon_art()
 return true

func enable_cutout() -> void:
 cutout=CombatCutout.new()
 add_child(cutout)
 grip_visual.draw_sprites=false

func update_cutout(dual) -> void:
 if cutout==null or anatomy==null:return
 var mounts: Array=[]
 var floor_targets: Dictionary={}
 if body.animation!="death":
  if dual!=null and dual.visible:
   for i in range(2):
    var rig=dual.rigs[i]
    if rig.weapon.visible:
     mounts.append(cutout_mount(rig,"r" if i==0 else "l"))
  elif weapon.visible:
   var side: String="l" if grip_visual.primary_arm=="left_arm" else "r"
   mounts.append(cutout_mount(self,side))
  elif cutout_crawling and not crawl_ready:
   floor_targets={"r":grip_visual.wrist_world,"l":grip_visual.support_world}
 cutout.pose(facing,body.animation,body.frame,clock,body.global_transform,cutout_tint,
  anatomy,dodge_pose,cutout_crawling,cutout_walking,cutout_phase,mounts,floor_targets)
 for rig in cutout.mount_offsets:
  rig.hand.global_position+=cutout.mount_offsets[rig]

func cutout_mount(rig,side: String) -> Dictionary:
 var result: Dictionary={"rig":rig,"side":side,"point":rig.grip_visual.wrist_world}
 if rig.grip_visual.support_visible:
  result["other"]="r" if side=="l" else "l"
  result["support"]=rig.grip_visual.support_world
 return result

func _apply_weapon_art() -> void:
 var art: Script = SwordArt
 match weapon_family:
  "greatsword": art = GreatArt
  "mace": art = MaceArt
  "staff": art = StaffArt
  "pistol": art = PistolArt
  "rifle": art = RifleArt
  "bow": art = BowArt
  "crossbow": art = CrossbowArt
  "shield": art = ShieldArt
 weapon.texture = art.texture()
 var geometry: Dictionary = art.geometry()
 _weapon_pivot = geometry.pivot
 _weapon_tip = geometry.tip
 var size := weapon.texture.get_size()
 weapon.offset = Vector2(size.x * 0.5 - _weapon_pivot.x, _weapon_pivot.y - size.y * 0.5)

func get_blade_points() -> Dictionary:
 # Read the actual transformed sprite axes. The billboard omits only depth;
 # restore that physical component for effects and world-space diagnostics.
 return {"grip": _texture_point_world(_weapon_pivot), "tip": _texture_point_world(_weapon_tip) + _blade_depth}

func _texture_point_world(point: Vector2) -> Vector3:
 var size := weapon.texture.get_size()
 var local := Vector3(point.x - size.x * 0.5 + weapon.offset.x, size.y * 0.5 - point.y + weapon.offset.y, 0.0) * weapon.pixel_size
 return weapon.global_transform * local

func update_pose(camera: Camera3D, aim: Vector3, walking: bool, sample: Dictionary, reach: float, hurt: float, dodge: float, delta: float, dead: bool = false,dash: Dictionary={}) -> void:
 dodge_pose=dash if not dead else {}
 dodge_kind=dodge_pose.get("kind","")
 var elbow_push: bool=not dodge_pose.is_empty() and anatomy!=null and anatomy.leg_count()==0
 var push_amount: float=float(dodge_pose.get("amount",0.0)) if elbow_push else 0.0
 var dashing:=not dodge_pose.is_empty() and not elbow_push
 var paired_body: bool=sample.get("paired_body",false)
 sample = _carry_pose(sample,aim,delta)
 sample.paired_body=paired_body
 clock += delta
 var phase: String = sample.get("phase", "idle")
 var facing_left: bool = camera.global_basis.x.dot(aim) < -0.05
 facing=Directions.choose(aim,camera,facing)
 var next_frames: SpriteFrames=DashArt.frames(facing,dodge_kind) if dashing else Directions.frames(facing,sample.get("paired_body",false) and not dead)
 if body.sprite_frames!=next_frames:
  var prior_animation: String=body.animation
  var prior_frame: int=body.frame
  body.sprite_frames=next_frames
  if not next_frames.has_animation(prior_animation):prior_animation="idle";prior_frame=0
  body.animation=prior_animation
  body.frame=mini(prior_frame,next_frames.get_frame_count(prior_animation)-1)
 body.flip_h=false
 var attacking: bool = phase != "idle" and not (walking and sample.get("charge_walk", false))
 var animation: String = "dodge" if dashing else ("death" if dead else ("hit" if hurt > 0.0 else ("attack" if attacking else ("walk" if walking else "idle"))))
 if body.animation != animation:
  body.animation = animation
  if animation == "death": clock = 0
 if dashing:
  body.frame=int(dodge_pose.frame)
 elif animation in ["walk", "idle"]:
  body.frame = int(clock * (10.0 if walking else 2.0)) % body.sprite_frames.get_frame_count(animation)
 elif animation == "attack":
  body.frame = {"windup": 0, "active": 1, "recovery": 2}.get(phase, 0) % body.sprite_frames.get_frame_count(animation)
 elif dead:
  body.frame = mini(2, int(clock * 3.0))
 back_hair.visible=facing=="back" and not dead
 if back_hair.visible:back_hair.texture=DashArt.head(facing,dodge_kind,body.frame) if dashing else Directions.back_head(body.animation,body.frame)
 body.modulate = Color(1.0, 0.48, 0.45) if hurt > 0.0 else (Color(0.6, 1.0, 1.0, 0.6) if dodge > 0.0 else Color.WHITE)
 back_hair.modulate=body.modulate
 pair_body_mask.visible=(sample.get("paired_body",false) or dashing) and not dead
 if pair_body_mask.visible:pair_body_mask.texture=body.sprite_frames.get_frame_texture(body.animation,body.frame)
 pair_body_mask.modulate=body.modulate
 var squash: float = 0.06 if phase == "windup" else (-0.04 if phase == "active" else 0.0)
 var lean: float = float(sample.get("body_lean", 0.0)) * (1.0 if facing_left else -1.0)
 if sample.get("smooth_body",false):
  var weight := 1-exp(-20*delta)
  _display_lean=lerpf(_display_lean,lean,weight)
  _display_squash=lerpf(_display_squash,squash,weight)
  lean=_display_lean;squash=_display_squash
 else:
  _display_lean=lean;_display_squash=squash
 if dashing:
  lean=dodge_pose.lean;squash=dodge_pose.squash
 body.global_basis = camera.global_basis * Basis(Vector3.BACK, lean)
 body.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0)
 # Put the baseline on the ground before leaning; the visible feet are the pivot.
 body.global_position = global_position + body.global_basis.y * (48 * PIXEL) + camera.global_basis.y * (0.025 * sin(clock * 17.0) if walking else 0.0)
 if dashing:body.global_position+=camera.global_basis.y*float(dodge_pose.drop)
 var crawling: bool=anatomy!=null and anatomy.leg_count()==0 and not dead
 if crawling:
  body.scale.y*=.72
  body.global_position=global_position+camera.global_basis.y*(.36+.025*push_amount+(.015*sin(clock*9) if walking else 0.0))
  body.rotate_object_local(Vector3.BACK,.035*sin(clock*9) if walking else .035)
 modular_body.visible=anatomy!=null and cutout==null
 if anatomy!=null:
  var tint:=body.modulate
  if cutout==null:
   modular_body.update_parts(body.sprite_frames.get_frame_texture(body.animation,body.frame),facing,body.animation,body.frame,anatomy,tint,crawling,walking,clock,DashArt.crouch(dodge_kind,body.frame) if dashing else 0)
  else:
   cutout_tint=tint;cutout_crawling=crawling;cutout_walking=walking;cutout_phase=phase
  # Geometry modulate affects this sprite only; independent child sprites keep
  # their own tint. Body remains the transform/frame carrier for weapon rigs.
  body.modulate=Color(1,1,1,0)
  back_hair.visible=false;pair_body_mask.visible=false
 weapon.visible = not dead
 if weapon_family == "crossbow": weapon.texture = CrossbowArt.texture(sample.get("crossbow_loaded", false))
 if weapon_family == "bow": weapon.texture = BowArt.texture(int(sample.get("bow_tier", 0)))
 if dashing:
  sample=Dash.tuck(Stance.rest(weapon_family,atan2(aim.z,aim.x)),dodge_pose)
  # Fan the tucked weapon off the camera axis, avoiding an end-on vanishing blade.
  sample.angle+=.45*dodge_pose.amount*(1 if facing=="front" else (-1 if facing=="back" else 0))
 var angle: float = float(sample.get("angle", atan2(aim.z, aim.x)))
 var direction := Vector3(cos(angle), 0, sin(angle))
 var radius: float = float(sample.get("radius", 0.42 if weapon_family == "rifle" else 0.48))
 if weapon_family in ["sword", "greatsword", "mace", "staff", "pistol", "rifle", "bow", "crossbow", "shield"]:
  var pitch: float = float(sample.get("pitch", 0.0))
  var grip_height: float = float(sample.get("grip_height", 0.80 if weapon_family in ["pistol", "rifle"] else 0.68))
  var blade_length: float = float(sample.get("blade_length", 1.35 if weapon_family == "rifle" else (0.72 if weapon_family == "pistol" else reach - radius)))
  var blade_vector := direction * cos(pitch) + Vector3.UP * sin(pitch)
  var grip_angle: float=sample.get("grip_angle",angle)
  var grip_direction := Vector3(cos(grip_angle),0,sin(grip_angle))
  hand.global_transform = Transform3D(camera.global_basis, global_position + grip_direction * radius + Vector3.UP * grip_height)
  var projected := Vector2(camera.global_basis.x.dot(blade_vector), camera.global_basis.y.dot(blade_vector))
  weapon.rotation.z = atan2(projected.y, projected.x)
  # Spin the already projected gun in the screen plane. The image offset
  # places the tiny hand exactly at this origin, so no orbit is introduced.
  if weapon_family == "pistol":
   weapon.rotation.z += float(sample.get("screen_roll", 0.0))
  weapon.pixel_size = blade_length / (_weapon_tip.x - _weapon_pivot.x)
  # This removes only the camera-depth component. Pitch changes the rigid
  # blade's projection rather than inventing a shorter physical weapon.
  weapon.scale = Vector3(projected.length(), 1.0, 1.0)
  _blade_depth = camera.global_basis.z * camera.global_basis.z.dot(blade_vector) * blade_length
 else:
  hand.global_transform = Transform3D(camera.global_basis, global_position + direction * radius + Vector3(0, 0.68, 0))
  var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction))
  weapon.rotation.z = atan2(projected.y, projected.x)
  weapon.pixel_size = (reach - radius) / 48.0
  weapon.scale = Vector3(projected.length(), 1.0, 1.0)
  _blade_depth = camera.global_basis.z * camera.global_basis.z.dot(direction) * (reach - radius)
 if weapon_family == "shield":
  weapon.rotation.z = 0.0
  weapon.pixel_size = .026
  weapon.scale = Vector3(lerpf(.58, 1.0, absf(camera.global_basis.z.dot(direction))), 1.0, 1.0)
  _blade_depth = Vector3.ZERO
 weapon.modulate = Color("#ffe3a0") if phase == "active" else Color.WHITE

 for i in range(spin_ghosts.size()):
  var ghost: Sprite3D=spin_ghosts[i]
  var blur: float=sample.get("spin_blur",0)
  ghost.visible=not dead and phase=="reload" and weapon_family=="pistol" and blur>.02
  if ghost.visible:
   ghost.texture=weapon.texture;ghost.offset=weapon.offset;ghost.pixel_size=weapon.pixel_size;ghost.scale=weapon.scale
   ghost.rotation.z=weapon.rotation.z-(.55+i*.45)
   ghost.render_priority=weapon.render_priority-1
   ghost.modulate=Color(.68,.88,1,(.18 if i==0 else .08)*blur)
 var dash_anchors: Array=paired_shoulders() if dashing else []
 if dashing:
  hand.global_position=Dash.wrist(dash_anchors[0],camera,-1 if facing=="front" else 1,dodge_pose.amount)
 var primary: Vector3=get_blade_points().grip
 var support_pixel := _weapon_pivot
 match weapon_family:
  "greatsword":support_pixel=Vector2(22,20)
  "staff":support_pixel=Vector2(36,22)
  "rifle":support_pixel=Vector2(72,24)+Vector2(-26,22)*float(sample.get("support_pull",0))
  "pistol":support_pixel=Vector2(13,22)
  "crossbow":support_pixel=Vector2(27, 14) + Vector2(-12, 0) * float(sample.get("support_pull", 0.0))
  "bow":support_pixel=BowArt.string_point(int(sample.get("bow_tier",0)))
 var support: Vector3=_texture_point_world(support_pixel)
 var supported: bool = weapon_family in ["greatsword","staff","rifle","bow","crossbow"] or (weapon_family=="pistol" and not sample.get("paired_carry",false))
 grip_visual.anatomy=anatomy
 grip_visual.primary_arm="left_arm" if sample.get("left_carry",false) else "right_arm"
 var main_anchor: Vector3=dash_anchors[0] if dashing else sample.get("shoulder_world",Vector3.INF)
 var off_anchor: Vector3=dash_anchors[1] if dashing else Vector3.INF
 if anatomy!=null and not main_anchor.is_finite():
  var shoulders:=paired_shoulders();main_anchor=shoulders[0];off_anchor=shoulders[1]
 if crawling and not crawl_ready:
  # Floor-reaching sleeves follow the low shoulders; equipment visibility is
  # resolved by gameplay/dual rigs without changing the weapon's trajectory.
  primary=main_anchor+camera.global_basis.x*(.30+.045*sin(clock*9))+camera.global_basis.y*(-.20)
  support=off_anchor-camera.global_basis.x*(.30-.045*sin(clock*9))+camera.global_basis.y*(-.20)
  if elbow_push:
   # Elbows fold under the low torso, then drive against the floor.
   primary=main_anchor+camera.global_basis.x*(.30-.13*push_amount)-camera.global_basis.y*(.20-.055*push_amount)
   support=off_anchor-camera.global_basis.x*(.30-.13*push_amount)-camera.global_basis.y*(.20-.055*push_amount)
  supported=true
 grip_visual.update_grips(camera,global_position,primary,support,supported,sample.get("paired_carry",false),sample.get("left_carry",false) or facing_left,dead,main_anchor,off_anchor)

func _carry_pose(sample: Dictionary,aim: Vector3,delta: float) -> Dictionary:
 if sample.get("stance_managed",false):return sample
 var idle: bool=sample.get("phase","idle")=="idle"
 var target := sample.duplicate(true)
 if idle:
  target=sample.duplicate(true) if sample.get("ready_carry",false) else Stance.rest(weapon_family,atan2(aim.z,aim.x))
  if _display_pose.is_empty():_display_pose=target.duplicate(true)
  _display_pose=Stance.blend(_display_pose,target,1-exp(-12*delta))
  _was_rest=true;_from_rest=false
 else:
  if _was_rest or (target.get("phase","")=="reload" and _display_pose.get("phase","")!="reload"):
   _rest_entry=_display_pose.duplicate(true);_was_rest=false;_from_rest=true
  if _from_rest and target.get("phase","") in ["windup","reload"] and target.has("progress") and not _rest_entry.is_empty():
   var p: float=clampf(target.get("progress",0)/(.14 if target.phase=="reload" else 1.0),0,1)
   _display_pose=Stance.blend(_rest_entry,target,p*p*(3-2*p))
  else:
   _display_pose=target.duplicate(true);_from_rest=false
 return _display_pose.duplicate(true)

func set_equipment_visible(value: bool) -> void:
 weapon.visible=value
 if not value:
  grip_visual.visible=anatomy!=null and anatomy.leg_count()==0 and not crawl_ready
  for ghost in spin_ghosts:ghost.visible=false

func body_point(pixel: Vector2) -> Vector3:
 return body.global_transform*Vector3((pixel.x-64)*PIXEL,(64-pixel.y)*PIXEL,.0)
func paired_shoulders() -> Array[Vector3]:
 if cutout!=null:
  var pivots: Dictionary=cutout.character.PIVOT_DATA.data[facing]
  var result: Array[Vector3]=[]
  for side in ["r","l"]:
   var pixel: Array=pivots["upper_arm_"+side].pivot_from_ground
   result.append(body.global_transform*Vector3(pixel[0]*CombatCutout.PIXEL_SIZE,-pixel[1]*CombatCutout.PIXEL_SIZE-.864,0))
  return result
 var points: Array[Vector2]=DashArt.shoulders(facing,dodge_kind,body.frame) if not dodge_pose.is_empty() and (anatomy==null or anatomy.leg_count()>0) else Directions.shoulder_pixels(facing,body.animation,body.frame)
 return [body_point(points[0]),body_point(points[1])]
