extends SceneTree
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
const Appearance=preload("res://scripts/opening/harbor_hero_appearance.gd")
const Luggage=preload("res://scripts/opening/harbor_travel_luggage.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func eye_pair_matches(texture: Texture2D,top_row: int) -> bool:
 var image: Image=texture.get_image().duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST)
 for y in range(top_row,top_row+3):
  for x in [12,13]:
   if image.get_pixel(x,y)!=image.get_pixel(31-x,y):return false
 return true
func run() -> void:
 check(eye_pair_matches(Standing.texture("front"),12),"front eyes have matching size, height, spacing and mirrored lower contours about the face center")
 var before:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/revisions/v107-front-128.png"))
 var after: Image=Standing.texture("front").get_image();var outside_changes:=0
 for y in 128:
  for x in 128:
   if before.get_pixel(x,y)!=after.get_pixel(x,y) and not Rect2i(72,48,12,12).has_point(Vector2i(x,y)):outside_changes+=1
 check(outside_changes==0,"the edit leaves all pixels outside the targeted eye area unchanged")
 for direction in ["right","left","back"]:
  var saved:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/traveler_study/directions/"+direction+"/idle-128.png"))
  check(Standing.texture(direction).get_image().get_data()==saved.get_data(),"preserve the accepted "+direction+" view exactly")
 check(after.get_size()==Vector2i(128,128) and after.get_used_rect().end.y==112,"front body size and foot registration remain intact")
 Appearance.select("traveler")
 check(eye_pair_matches(Appearance.frames("front").get_frame_texture("idle",0),12),"harbor idle frames consume the corrected eyes")
 check(eye_pair_matches(Luggage.carry_texture("front","walk",1),11),"the actual walking/carry body keeps the corrected eyes through its head bob")
 print("FRONT EYE BALANCE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
