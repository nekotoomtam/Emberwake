extends SceneTree
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
const HumanArt=preload("res://scripts/opening/harbor_human_art.gd")
const Appearance=preload("res://scripts/opening/harbor_hero_appearance.gd")
const Luggage=preload("res://scripts/opening/harbor_travel_luggage.gd")
const REFERENCE: Dictionary={"id":"npc_eye_reference","hairstyle":4,"male":false,"cap":false,"hair":"71503b","skin":"ffdfbd","coat":"586f75"}
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func logical(texture: Texture2D) -> Image:
 var image: Image=texture.get_image().duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST);return image
func tokens(image: Image,rect: Rect2i,iris: Color,glint: Color) -> Array:
 var result: Array=[]
 for y in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   var color: Color=image.get_pixel(x,y)
   result.append("o" if color.is_equal_approx(Color("292b36")) else "i" if color.is_equal_approx(iris) else "w" if color.is_equal_approx(glint) else ".")
 return result
func run() -> void:
 var npc:=logical(HumanArt.frame(REFERENCE,"front","idle",0));var hero:=logical(Standing.texture("front"))
 var eye_rect:=Rect2i(11,12,3,2)
 check(tokens(hero,eye_rect,Standing.PALETTE.G,Standing.PALETTE.w)==["o","o","o","w","i","o"],"front eyes fit a compact 3x2 footprint with one iris and one glint pixel")
 var balanced:=true
 for y in range(12,15):
  for x in range(11,15):balanced=balanced and hero.get_pixel(x,y)==hero.get_pixel(31-x,y)
 check(balanced,"Compact eye groups are reflected about this character's own face center")
 var before:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/revisions/v109-front-128.png"))
 var after: Image=Standing.texture("front").get_image();var outside:=0
 for y in 128:
  for x in 128:
   if before.get_pixel(x,y)!=after.get_pixel(x,y) and not Rect2i(44,48,40,12).has_point(Vector2i(x,y)):outside+=1
 check(outside==0,"hair, face outside eyes, clothing and body remain unchanged")
 for direction in ["right","left","back"]:
  var saved:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/directions/"+direction+"/idle-128.png"))
  check(Standing.texture(direction).get_image().get_data()==saved.get_data(),"preserve accepted "+direction+" pixels")
 check(after.get_size()==Vector2i(128,128) and after.get_used_rect().end.y==112,"retain body registration and frame size")
 Appearance.select("traveler")
 check(Appearance.frames("front").get_frame_texture("idle",0).get_image().get_data()==after.get_data(),"actual harbor idle uses the updated eyes")
 var walking:=logical(Luggage.carry_texture("front","walk",1))
 check(tokens(walking,Rect2i(11,11,3,2),Standing.PALETTE.G,Standing.PALETTE.w)==["o","o","o","w","i","o"],"walking/carry head bob retains the compact eyes")
 print("COMPACT FRONT EYES ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
