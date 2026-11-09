extends CanvasLayer
## Own-player pixel fire orbs. Projected after fog, with no numeric charge UI.
var orbs: Array[Sprite2D]=[]
var forming: Sprite2D
var gathered: Sprite2D
var clock:=.0
var textures: Array[Texture2D]=[]
func _ready() -> void:
 layer=9
 for f in range(4):textures.append(_texture(f))
 for i in range(3):
  var orb:=Sprite2D.new();orb.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(orb);orbs.append(orb)
 forming=Sprite2D.new();forming.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(forming)
 gathered=Sprite2D.new();gathered.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(gathered)
func _texture(frame: int) -> ImageTexture:
 var image:=Image.create(18,22,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 for y in range(11):
  for x in range(9):
   var d:=Vector2(x-4,y-6).length_squared()
   var color:=Color.TRANSPARENT
   if d<=13:color=Color("#b63b2d")
   if d<=9:color=Color("#ff7229")
   if d<=4:color=Color("#ffce59")
   if d<=1:color=Color("#fff5c5")
   if y<4 and y>0 and x==4+((frame+y)%3-1):color=Color("#ffb13a")
   if color.a>0:image.fill_rect(Rect2i(x*2,y*2,2,2),color)
 return ImageTexture.create_from_image(image)
func update_view(game,delta: float) -> void:
 clock+=maxf(0,delta)
 var show: bool=game.primary_family()=="staff" and game.mode in ["practice","combat"] and not game.inventory_open and not game.stats_open
 visible=show
 if not show:return
 var model=game.staff_energy
 var tip: Vector3=game._staff_tip(game.current_visual_sample())
 var center: Vector2=game.camera.unproject_position(tip)
 var tier: int=model.level()
 var texture: Texture2D=textures[int(clock*12)%4]
 for i in range(3):
  var a:=clock*.75+i*TAU/3-PI/2
  var at:=center+Vector2(cos(a)*21,sin(a)*15)
  orbs[i].visible=i<model.units
  orbs[i].texture=texture;orbs[i].scale=Vector2.ONE
  orbs[i].modulate=Color.WHITE
  if model.casting and i<tier:
   var threshold: float=[0.0,model.CAST_MID,model.CAST_FULL][i]
   var merge:=clampf((model.cast_elapsed-threshold)/.12,0,1)
   at=at.lerp(center,merge);orbs[i].modulate.a=1-merge
  orbs[i].position=at.round()
 forming.visible=model.loading and model.units<3
 if forming.visible:
  var a: float=clock*.75+model.units*TAU/3-PI/2
  var progress: float=clampf(model.load_elapsed/model.LOAD_TIME,0,1)
  forming.texture=texture;forming.position=(center+Vector2(cos(a)*21,sin(a)*15)).round()
  forming.scale=Vector2.ONE*(.35+.65*progress);forming.modulate=Color(1,1,1,.2+.8*progress)
 gathered.visible=model.casting or model.empty_flash>0
 if gathered.visible:
  gathered.texture=texture;gathered.position=center.round()
  gathered.scale=Vector2.ONE*([1.0,1.6,2.15][maxi(0,tier-1)] if model.casting else .65)
  gathered.modulate=Color.WHITE if model.casting else Color(1,.25,.18,.8)

