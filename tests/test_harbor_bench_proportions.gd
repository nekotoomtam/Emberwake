extends SceneTree
## Player-referenced source pixels and their native world projection.
## A private seated downscale or extended shins must fail independently of art metadata.
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:call_deferred("_run")
func _check(condition: bool,label: String) -> void:
 checks+=1
 if not condition:failures.append(label);push_error(label)
func _has_property(object: Object,label: String) -> bool:
 for property in object.get_property_list():
  if property.name==label:return true
 return false
func _bounds(image: Image,area: Rect2i,colors: Array=[]) -> Rect2i:
 var minimum:=Vector2i(999,999);var maximum:=Vector2i(-1,-1)
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   var color:=image.get_pixel(x,y)
   if color.a<.5:continue
   var matched:=colors.is_empty()
   for target: Color in colors:
    if absf(color.r-target.r)<.005 and absf(color.g-target.g)<.005 and absf(color.b-target.b)<.005:matched=true
   if not matched:continue
   minimum=minimum.min(Vector2i(x,y));maximum=maximum.max(Vector2i(x,y))
 return Rect2i(minimum,maximum-minimum+Vector2i.ONE) if maximum.x>=0 else Rect2i()
func _logical(texture: Texture2D) -> Image:
 var image:=texture.get_image();image.resize(32,32,Image.INTERPOLATE_NEAREST);return image
func _run() -> void:
 var Bench=load("res://scripts/opening/harbor_bench_life.gd")
 var Hero=load("res://scripts/hero_directions.gd")
 var Appearance=load("res://scripts/opening/npc_appearance.gd")
 var scene:=Node3D.new();root.add_child(scene)
 var life=Bench.new();scene.add_child(life)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-33,5.8,10);camera.look_at(Vector3(-33,.7,2.5))
 await process_frame
 life.tick(1.0/120.0,camera,0.0)
 var hero: Image=Hero.draw("front","idle",0)
 var hero_head:=_bounds(hero,Rect2i(0,0,32,18))
 var hero_face:=_bounds(hero,Rect2i(0,0,32,18),[Color("ffddbc"),Color("e7a183")])
 var hero_torso:=_bounds(hero,Rect2i(0,18,32,8),[Color("2f5869"),Color("50888c"),Color("24394c"),Color("385568")])
 var hero_boot:=_bounds(hero,Rect2i(8,25,8,3),[Color("18293a"),Color("5b6c7c")])
 print("CANONICAL HEAD/FACE/TORSO/BOOT ",hero_head," ",hero_face," ",hero_torso," ",hero_boot)
 _check(hero_head.size==Vector2i(19,16) and hero_face.size==Vector2i(11,9) and hero_torso.size==Vector2i(10,7) and hero_boot.size==Vector2i(3,2),"canonical player metrics are independently measured from its normal front pixels")
 for actor in life.actors:
  var complete:=_has_property(actor,"sprite")
  _check(complete,"resident owns one coherent player-scale sprite: "+actor.name)
  var sprite: Sprite3D=actor.get("sprite") if complete else actor.get("upper_sprite")
  var image:=_logical(sprite.texture)
  var skin:=Color(actor.profile.skin)
  var head:=_bounds(image,Rect2i(0,0,32,18))
  var face:=_bounds(image,Rect2i(0,0,32,18),[skin,skin.darkened(.2)])
  var coat:=Color(actor.profile.coat)
  var torso:=_bounds(image,Rect2i(0,18,32,8),[coat,coat.lightened(.18),coat.darkened(.28),coat.darkened(.1),coat.darkened(.12)])
  var source_pixel:=sprite.pixel_size*4.0
  _check(is_equal_approx(source_pixel,.072),"effective source pixel equals the protagonist's .072m: "+actor.name)
  _check(float(head.size.x)*source_pixel>=float(hero_head.size.x)*.072*.9 and float(head.size.x)*source_pixel<=float(hero_head.size.x)*.072*1.1,"head width belongs to the canonical player family: "+actor.name)
  _check(float(face.size.y)*source_pixel>=float(hero_face.size.y)*.072*.8 and float(face.size.y)*source_pixel<=float(hero_face.size.y)*.072*1.3,"full face height matches the protagonist while retaining its original male/female fringe: "+actor.name)
  _check(float(torso.size.y)*source_pixel>=float(hero_torso.size.y)*.072*.85 and float(torso.size.y)*source_pixel<=float(hero_torso.size.y)*.072*1.2,"torso retains normal player scale below the full head: "+actor.name)
  var normal: Image=Appearance.draw(int(actor.profile.hairstyle),bool(actor.profile.male),"front",-1,"idle",0,actor.profile)
  normal.resize(32,32,Image.INTERPOLATE_NEAREST)
  _check(image.get_region(Rect2i(0,0,32,18)).get_data()==normal.get_region(Rect2i(0,0,32,18)).get_data(),"original resident hair/skin/head pixels survive intact: "+actor.name)
  if not complete:continue
  var boots:=Color(actor.profile.boots)
  var boot:=_bounds(image,Rect2i(8,25,8,7),[boots,boots.lightened(.21)])
  _check(boot.size.y>=hero_boot.size.y and boot.size.y<=3,"seated boot retains the protagonist's compact two-to-three source rows: "+actor.name)
  _check(_bounds(image,Rect2i(0,25,32,7)).size.y<=5,"folded knees, shins and boots total at most five rows: "+actor.name)
  for angle in [0.0,-.62]:
   camera.rotation=Vector3(angle,0,0);life.tick(0.0,camera,0.0)
   var painted_hip: Vector3=sprite.global_transform*Vector3(0.0,-.648,0.0)
   _check(painted_hip.distance_to(actor.hip_anchor.global_position)<.0001,"actual hip pixel remains on native seat at camera pitch "+str(angle)+": "+actor.name)
   _check(sprite.global_basis.orthonormalized().is_equal_approx(camera.global_basis.orthonormalized()),"complete seated body uses the normal camera basis: "+actor.name)
   _check(actor.feet[0].global_position.y>actor.global_position.y and actor.feet[1].global_position.y>actor.global_position.y,"short player-scale legs dangle naturally above paving: "+actor.name)
   # Native bench geometry: last slat centre=.19, half-depth=.05; front=.24.
   # Test actual opaque knee/shin texels, not a marker that can disagree with art.
   var knees_clear_timber:=true;var knee_pixels:=0
   for y in range(25,27):
    for x in range(11,22):
     if image.get_pixel(x,y).a<.5:continue
     knee_pixels+=1
     var source_centre:=Vector2(float(x)+.5,float(y)+.5)*4.0
     var pixel_local:=Vector3((source_centre.x-64.0)*.018,(64.0-source_centre.y)*.018,0.0)
     var pixel_world: Vector3=sprite.global_transform*pixel_local
     knees_clear_timber=knees_clear_timber and pixel_world.z>actor.global_position.z+.24
   _check(knee_pixels>=16 and knees_clear_timber,"actual folded knee/shin pixels clear the existing front slat at camera pitch "+str(angle)+": "+actor.name)
 _check(life.couple[1].position.x-life.couple[0].position.x>=1.399,"full-size couple heads have readable separation within the existing bench")
 scene.queue_free();await process_frame
 print("HARBOR BENCH PROPORTIONS v93 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL "+str(failures))
 quit(0 if failures.is_empty() else 1)
