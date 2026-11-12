extends CanvasLayer
## Own-player pixel fire orbs. Projected after fog, with no numeric charge UI.
const Charge = preload("res://scripts/staff_charge.gd")
const ChargedFireArt = preload("res://scripts/staff_charged_fire_art.gd")
const IceVolleyArt = preload("res://scripts/staff_ice_volley_art.gd")
const StaffLv10Art = preload("res://scripts/staff_lv10_art.gd")
const StaffLv20Art = preload("res://scripts/staff_lv20_art.gd")
const StaffMotion = preload("res://scripts/staff_motion.gd")
const ORBIT_SIZE := Vector2(34, 23)
var orbs: Array[Sprite2D]=[]
var forming: Sprite2D
var gathered: Sprite2D
var focus_orb: Sprite2D
var clock:=.0
var textures: Dictionary = {}
func _ready() -> void:
 layer=9
 for element in Charge.ELEMENTS:
  var frames: Array[Texture2D] = []
  for frame in 4: frames.append(_texture(frame, element))
  textures[element] = frames
 for i in range(Charge.MAX_UNITS):
  var orb:=Sprite2D.new();orb.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(orb);orbs.append(orb)
 forming=Sprite2D.new();forming.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(forming)
 gathered=Sprite2D.new();gathered.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(gathered)
 focus_orb=Sprite2D.new();focus_orb.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(focus_orb)
func _texture(frame: int, element: String) -> ImageTexture:
 var image:=Image.create(18,22,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var tint: Color = Charge.ELEMENT_COLORS[element]
 for y in range(11):
  for x in range(9):
   var d:=Vector2(x-4,y-6).length_squared()
   var color:=Color.TRANSPARENT
   if d<=13:color=tint.darkened(.55)
   if d<=9:color=tint
   if d<=4:color=tint.lightened(.40)
   if d<=1:color=tint.lightened(.80)
   if y<4 and y>0 and x==4+((frame+y)%3-1):color=tint.lightened(.20)
   if color.a>0:image.fill_rect(Rect2i(x*2,y*2,2,2),color)
 return ImageTexture.create_from_image(image)
func update_view(game,delta: float) -> void:
 clock+=maxf(0,delta)
 var show: bool=game.primary_family()=="staff" and game.mode in ["practice","combat"] and not game.inventory_open and not game.stats_open
 visible=show
 if not show:return
 var model=game.staff_energy
 var pose: Dictionary=game.current_visual_sample()
 var tip: Vector3=game._staff_tip(pose)
 if game.avatar.cutout != null and game.avatar.facing in ["front", "back"]:
  if pose.phase == "idle" or pose.get("staff_loading", false):
   tip=game.avatar.get_blade_points().tip
 var center: Vector2=game.camera.unproject_position(tip)
 var frame := int(clock * 12) % 4
 focus_orb.visible = model.focus_left > 0.0
 if focus_orb.visible:
  focus_orb.texture = StaffLv20Art.frame(StaffLv20Art.FOCUS_ORB, frame)
  focus_orb.offset = StaffLv20Art.offset(StaffLv20Art.FOCUS_ORB, frame)
  var body_center: Vector2 = game.camera.unproject_position(game.player.global_position + Vector3.UP * 1.15)
  var outward := (center - body_center).normalized() * 15.0
  focus_orb.position = (center + outward + _orbit_offset(0).rotated(clock * 1.3)).round()
  focus_orb.scale = Vector2.ONE * .145
 var casting_slots: Array[int] = model.casting_slots()
 for i in orbs.size():
  var at:=center+_orbit_offset(i)
  var element: String = model.slots[i]
  orbs[i].visible = not element.is_empty()
  if element.is_empty(): continue
  if element == Charge.NEUTRAL:
   orbs[i].texture=StaffLv20Art.frame(StaffLv20Art.FOCUS_ORB,frame)
   orbs[i].offset=StaffLv20Art.offset(StaffLv20Art.FOCUS_ORB,frame)
   orbs[i].scale=Vector2.ONE*.085
  else:
   orbs[i].texture=textures[element][frame];orbs[i].offset=Vector2.ZERO;orbs[i].scale=Vector2.ONE
  orbs[i].modulate=Color.WHITE
  if i in casting_slots:
   var merge:=smoothstep(0.0,1.0,model.cast_elapsed/model.cast_time)
   at=at.lerp(center,merge);orbs[i].modulate.a=1-merge
  orbs[i].position=at.round()
 forming.visible=model.loading and model.units<Charge.MAX_UNITS
 if forming.visible:
  var progress: float=clampf(model.load_elapsed/model.LOAD_TIME,0,1)
  forming.texture=textures[model.element][frame];forming.position=(center+_orbit_offset(model.slots.find(""))).round()
  forming.scale=Vector2.ONE*(.35+.65*progress);forming.modulate=Color(1,1,1,.2+.8*progress)
 gathered.visible=model.casting or model.empty_flash>0
 if gathered.visible:
  gathered.offset=Vector2.ZERO
  gathered.texture=textures[model.cast_element if model.casting else model.element][frame];gathered.position=center.round()
  gathered.scale=Vector2.ONE*(lerpf(.75,2.15,model.cast_elapsed/model.cast_time) if model.casting else .65)
  gathered.modulate=Color.WHITE if model.casting else Color(1,.25,.18,.8)
  var spell_art: Script
  if game._staff_charge_skill in [StaffMotion.CHARGED_FIRE_ID, StaffMotion.METEOR_ID]: spell_art = ChargedFireArt
  elif game._staff_charge_skill in [StaffMotion.ICE_VOLLEY_ID, StaffMotion.ICE_CRYSTAL_ID]: spell_art = IceVolleyArt
  elif game._staff_charge_skill in [StaffMotion.CHAIN_LIGHTNING_ID, StaffMotion.MANA_FIELD_ID]: spell_art = StaffLv10Art
  if model.casting and spell_art != null:
   var progress: float=clampf(model.cast_elapsed/model.cast_time,0,1)
   var charge_frame:=mini(int(progress*spell_art.FRAME_COUNT),spell_art.FRAME_COUNT-1)
   gathered.texture=spell_art.frame(spell_art.CHARGE,charge_frame)
   gathered.offset=spell_art.offset(spell_art.CHARGE,charge_frame)
   gathered.scale=Vector2.ONE*(.23 + .035*progress + .012*sin(clock*22))

func _orbit_offset(index: int) -> Vector2:
 var angle:=clock*.75+index*TAU/Charge.MAX_UNITS-PI/2
 return Vector2(cos(angle),sin(angle))*ORBIT_SIZE

