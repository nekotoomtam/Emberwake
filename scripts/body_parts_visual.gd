extends Node3D
## Six independent, removable sprites. Pixel clusters come from the accepted
## character frames; the clothing under hair/arms is restored using its palette.
const Art = preload("res://scripts/pixel_art.gd")
const Directions = preload("res://scripts/hero_directions.gd")
const PARTS := ["head", "torso", "right_arm", "left_arm", "right_leg", "left_leg"]
static var cache: Dictionary = {}
var parts: Dictionary = {}

func _ready() -> void:
 for id in PARTS:
  var sprite := Sprite3D.new()
  sprite.name = id
  sprite.pixel_size = .018
  sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
  sprite.shaded = false
  sprite.no_depth_test = true
  sprite.render_priority = 6 if id == "head" else (2 if id.ends_with("arm") else 1)
  add_child(sprite)
  parts[id] = sprite

static func layers(texture: Texture2D, facing: String, animation: String, frame: int, dip: int = 0) -> Dictionary:
 var key := str(texture.get_instance_id()) + facing + animation + str(frame) + ":" + str(dip)
 if cache.has(key):return cache[key]
 if animation == "death" and frame == 2:
  var previous := layers(Directions.frames(facing).get_frame_texture("death",1),facing,"death",1)
  var fallen: Dictionary = {}
  for id in PARTS:
   var image: Image = previous[id].get_image().duplicate()
   image.resize(32,32,Image.INTERPOLATE_NEAREST)
   image = Art._fallen(image)
   image.resize(128,128,Image.INTERPOLATE_NEAREST)
   fallen[id] = ImageTexture.create_from_image(image)
  cache[key] = fallen
  return fallen
 var source: Image = texture.get_image().duplicate()
 source.resize(32,32,Image.INTERPOLATE_NEAREST)
 var result: Dictionary = {}
 for id in PARTS:
  var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
  image.fill(Color.TRANSPARENT)
  result[id] = image
 var bob := -frame if animation == "idle" else (-1 if animation == "walk" and frame % 2 == 1 else 0)
 if animation == "hit" and facing in ["left", "right"]:bob = 1
 if animation == "death":bob = frame*2
 var split := 18 + bob + dip
 var mirror := facing == "left"
 # Preserve every native face/hair pixel, including the low ponytail and braid.
 var hair_colors := [Color("a44260"),Color("c55372"),Color("ed7b8d"),Color("ffb0a8")]
 if animation == "hit":
  for i in range(hair_colors.size()):hair_colors[i]=hair_colors[i].lerp(Color("ffd6c7"),.36)
 for y in range(32):
  for x in range(32):
   var color := source.get_pixel(x,y)
   if color.a == 0:continue
   var hair: bool = matches_palette(color,hair_colors)
   if not hair and y >= split:
    for dy in range(-1,2):
     for dx in range(-1,2):
      var p := Vector2i(x+dx,y+dy)
      if p.x>=0 and p.x<32 and p.y>=0 and p.y<32 and matches_palette(source.get_pixelv(p),hair_colors):
       var outline := Color("262333").lerp(Color("ffd6c7"),.36) if animation == "hit" else Color("262333")
       if matches_palette(color,[outline]):hair = true
   var id := "torso"
   if y < split or hair:id = "head"
   elif y >= 24 + dip:
    id = "right_leg" if x < 17 else "left_leg"
    if facing == "back":id = "left_leg" if x < 17 else "right_leg"
    if mirror:id = "left_leg" if x < 15 else "right_leg"
   elif y >= 20 + dip and y < 24 + dip:
    var logical_x := 31-x if mirror else x
    if logical_x <= 12:id = "right_arm" if facing == "front" else "left_arm"
    elif logical_x >= 20:id = "left_arm" if facing == "front" else "right_arm"
   result[id].set_pixel(x,y,color)
 # A complete tunic under the separated head, sleeves and belt. This avoids
 # transparent holes when hair or a shoulder is removed.
 var tunic := Image.create(32,32,false,Image.FORMAT_RGBA8)
 tunic.fill(Color.TRANSPARENT)
 var lean: int = [0,2,1][mini(frame,2)] if animation == "attack" else (-1 if animation == "hit" else 0)
 var x_offset := int(lean/2.0) if facing != "back" else 0
 Art._stamp(tunic,["..oo.cc.oo..",".oTTTccTTTo.","oTTtTTTTtTTo","oTTtTTTTtTTo",".oTTbbbbTTo.","..oDDDDDDoo.",".oDDdDDDdDo.","..oDDDDDDDo."],Vector2i(10+x_offset,18+dip),{"o":Color("262333"),"c":Color("e8d9bc"),"T":Color("2f5869"),"t":Color("50888c"),"b":Color("b38c5d"),"D":Color("24394c"),"d":Color("385568")})
 if mirror:tunic.flip_x()
 # Only the central garment belongs to the torso. The lower hem stays with
 # the torso, so losing both boots never leaves a floating open rectangle.
 for y in range(18+dip,mini(26+dip,32)):
  for x in range(32):
   var logical_x := 31-x if mirror else x
   if logical_x >= 13+x_offset and logical_x <= 19+x_offset:
    var c := tunic.get_pixel(x,y)
    if c.a > 0:result.torso.set_pixel(x,y,c)
 for id in PARTS:
  result[id].resize(128,128,Image.INTERPOLATE_NEAREST)
  result[id] = ImageTexture.create_from_image(result[id])
 cache[key] = result
 return result

static func matches_palette(color: Color, palette: Array) -> bool:
 for candidate: Color in palette:
  if absf(color.r-candidate.r)+absf(color.g-candidate.g)+absf(color.b-candidate.b)<.015:return true
 return false

func update_parts(texture: Texture2D, facing: String, animation: String, frame: int, anatomy, tint: Color, crawling: bool, moving: bool, clock: float, dip: int = 0) -> void:
 var images := layers(texture,facing,animation,frame,dip)
 for id in PARTS:
  var sprite: Sprite3D = parts[id]
  sprite.texture = images[id]
  sprite.visible = anatomy.present(id)
  sprite.modulate = tint
  sprite.position = Vector3.ZERO
  sprite.rotation = Vector3.ZERO
  sprite.scale = Vector3.ONE
  if crawling:
   # The torso is belly-low and the head stays readable; arms reach along
   # the floor instead of leaving an upright character hovering over no legs.
   var stroke := sin(clock * 9.0) if moving else 0.0
   if id == "head":
    sprite.position.y = -.18
    sprite.scale.y = 1.0/.72
   if id == "torso":sprite.position.y = -.04 + absf(stroke)*.018
   if id.ends_with("arm"):
    sprite.position.x = (.10 if id == "right_arm" else -.10) * stroke
    sprite.position.y = -.16
   if id.ends_with("leg"):
    sprite.position.y = .18
    sprite.position.x = .04 if id == "right_leg" else -.04
  elif id.ends_with("arm") and not anatomy.functional(id):
   # Present at zero integrity remains visible, tucked against the tunic.
   sprite.position.y = -.07
   sprite.position.x = -.035 if id == "right_arm" else .035
