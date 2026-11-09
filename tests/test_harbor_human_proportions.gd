extends SceneTree
## Player-referenced source and actual actor checks, independent of furniture height.
const Hero=preload("res://scripts/hero_directions.gd")
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const HumanArt=preload("res://scripts/opening/harbor_human_art.gd")
const SocialArt=preload("res://scripts/opening/harbor_social_art.gd")
const BenchArt=preload("res://scripts/opening/harbor_bench_art.gd")
var checks:=0
var failures: Array=[]
var metrics: Array=[]
var output:=""
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,key: String) -> bool:
 for entry in object.get_property_list():
  if entry.name==key:return true
 return false
func humans(node: Node) -> Array:
 var result: Array=[]
 if has_property(node,"profile") and has_property(node,"sprite") and node.get("sprite") is Sprite3D:result.append(node)
 for child in node.get_children():result.append_array(humans(child))
 return result
func logical(texture: Texture2D) -> Image:
 var image:=texture.get_image().duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST);return image
func matches(color: Color,colors: Array) -> bool:
 if colors.is_empty():return true
 for reference: Color in colors:
  if absf(color.r-reference.r)<=1.01/255 and absf(color.g-reference.g)<=1.01/255 and absf(color.b-reference.b)<=1.01/255:return true
 return false
func bounds(image: Image,roi: Rect2i,colors: Array=[]) -> Rect2i:
 var low:=Vector2i(32,32);var high:=Vector2i(-1,-1)
 for y in range(roi.position.y,roi.end.y):
  for x in range(roi.position.x,roi.end.x):
   var color:=image.get_pixel(x,y)
   if color.a>.5 and matches(color,colors):
    low.x=mini(low.x,x);low.y=mini(low.y,y);high.x=maxi(high.x,x);high.y=maxi(high.y,y)
 return Rect2i(low,high-low+Vector2i.ONE) if high.x>=0 else Rect2i()
func rect_array(rect: Rect2i) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func metric(id: String,texture: Texture2D,pixel_size: float,skin: Color,coat: Color,boots: Color) -> Dictionary:
 var image:=logical(texture)
 var skin_colors: Array=[skin,skin.darkened(.18),skin.darkened(.2)]
 if id.begins_with("normal_player"):skin_colors.append(Color("e7a183"))
 var result: Dictionary={"id":id,"texture_size":[texture.get_width(),texture.get_height()],"pixel_size":pixel_size,"logical_pixel_world":pixel_size*4,"alpha":rect_array(bounds(image,Rect2i(0,0,32,32))),"head":rect_array(bounds(image,Rect2i(0,0,32,18))),"face":rect_array(bounds(image,Rect2i(0,0,32,18),skin_colors)),"torso_band":rect_array(bounds(image,Rect2i(0,18,32,8))),"lower_band":rect_array(bounds(image,Rect2i(0,25,32,7))),"coat_shoulders":rect_array(bounds(image,Rect2i(0,18,32,4),[coat,coat.lightened(.18),coat.lightened(.19),coat.darkened(.28),coat.darkened(.30),coat.darkened(.12),coat.darkened(.14)])),"boots":rect_array(bounds(image,Rect2i(0,24,32,8),[boots,boots.lightened(.21),Color("5b6c7c")]))}
 metrics.append(result);return result
func same_region(a: Image,b: Image,region: Rect2i) -> bool:
 return a.get_region(region).get_data()==b.get_region(region).get_data()
func pixel_world(sprite: Sprite3D,point: Vector2) -> Vector3:
 var extent:=Vector2(sprite.texture.get_width(),sprite.texture.get_height())*.5
 return sprite.global_transform*Vector3((point.x-extent.x)*sprite.pixel_size,(extent.y-point.y)*sprite.pixel_size,0)
func identity_snapshot(actors: Array) -> Dictionary:
 var result: Dictionary={}
 for actor in actors:result[str(actor.get_instance_id())]={"id":str(actor.profile.id),"profile":actor.profile.duplicate(true)}
 return result
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 await physics_frame;await physics_frame
 var bench=g.world.get("bench_life")
 check(bench!=null and bench.actors.size()==3,"actual world contains the original three bench identities")
 if bench==null:await finish(g);return
 # This reference is the unchanged normal standing protagonist, not carry art,
 # cafe art or a resident sprite resized to match the furniture.
 var player_texture: Texture2D=Hero.frames("front").get_frame_texture("idle",0)
 var player:=metric("normal_player_front",player_texture,.018,Color("ffddbc"),Color("2f5869"),Color("18293a"))
 check(player.head[2]==19 and player.head[3]==16 and player.face[2]==11 and player.face[3]==9,"source player exposes the established 19x16 head and 11x9 face reference")
 check(player.torso_band[3]==8 and player.lower_band[3]==3,"source player's normal torso and lower limb are eight and three source rows")
 var all_humans:=humans(g.world)
 var original_identities:=identity_snapshot(all_humans)
 var source_player_hash:=hash(player_texture.get_image().get_data())
 var ordinary:=0;var social:=0
 for actor in all_humans:
  if actor.get_meta("bench_life_owned",false):continue
  check(is_equal_approx(actor.sprite.pixel_size*actor.sprite.global_basis.x.length(),.018) and is_equal_approx(actor.sprite.pixel_size*actor.sprite.global_basis.y.length(),.018),"standing/social actor retains normal player effective pixel scale: "+str(actor.profile.id))
  if actor.get_meta("social_life_owned",false):social+=1
  else:ordinary+=1
 check(ordinary>20 and social==4,"audit reaches shared villagers, crew, cargo/background people and all four social actors")
 var human_cache_before: int=HumanArt.cache.size();var social_cache_before: int=SocialArt.cache.size()
 var first_textures: Array=[]
 for actor in bench.actors:
  var sprite=actor.get("sprite")
  check(sprite is Sprite3D,"seated resident is one coherent native sprite: "+str(actor.profile.id))
  if not sprite is Sprite3D:continue
  actor.tick(0,g.camera,-actor.phase)
  first_textures.append(sprite.texture)
  var p: Dictionary=actor.profile
  var seated:=metric(str(p.id),sprite.texture,sprite.pixel_size,Color(p.skin),Color(p.coat),Color(p.boots))
  var standing: Image=Appearance.draw(int(p.hairstyle),bool(p.male),"front",-1,"idle",0,p);standing.resize(32,32,Image.INTERPOLATE_NEAREST)
  var image:=logical(sprite.texture)
  check(sprite.texture.get_width()==player_texture.get_width() and sprite.texture.get_height()==player_texture.get_height(),"seated art uses the player's unchanged 128px texture basis: "+str(p.id))
  check(is_equal_approx(sprite.pixel_size,.018),"seated source pixel is the normal player's .072 world units: "+str(p.id))
  check(same_region(image,standing,Rect2i(0,0,32,18)),"resident's normal head and face pixels survive the seated pose: "+str(p.id))
  check(seated.head[2]>=player.head[2]-1 and seated.head[2]<=player.head[2]+3 and seated.head[3]>=player.head[3]-1 and seated.head[3]<=player.head[3]+2,"resident head belongs to the player's body family with hairstyle allowance: "+str(p.id))
  check(seated.coat_shoulders[2]>=9 and seated.coat_shoulders[2]<=13 and seated.torso_band[3]==player.torso_band[3],"seated shoulders and eight-row torso retain the normal body language: "+str(p.id))
  var lower:=bounds(image,Rect2i(0,26,32,6))
  check(lower.size.y>0 and lower.size.y<=player.lower_band[3]+2 and seated.boots[3]>0 and seated.boots[3]<=player.lower_band[3]+1,"folded lower limb and boots stay short relative to the source player: "+str(p.id))
  check(absf(actor.hip_anchor.global_position.y-.5275)<.005,"hip remains on the original native bench top: "+str(p.id))
  check(pixel_world(sprite,Vector2(64,100)).distance_to(actor.hip_anchor.global_position)<.006,"actual hip pixel meets the physical seat anchor in the current camera: "+str(p.id))
  check(not actor.is_processing() and not actor.is_physics_processing(),"bench owner alone advances each resident: "+str(p.id))
 # The same actual objects must register correctly under both a front lens and
 # the usual elevated follow lens. Ground contact is not a leg-length target.
 var original_camera: Transform3D=g.camera.transform
 for camera_pose in [[Vector3(-36.2,2.2,8),Vector3(-36.2,.9,2.5)],[Vector3(-33.3,7.855,12.7),Vector3(-33.3,1.755,-.7)]]:
  g.camera.position=camera_pose[0];g.camera.look_at(camera_pose[1])
  for actor in bench.actors:
   if not actor.get("sprite") is Sprite3D:continue
   for frame in ceili(.2*Engine.physics_ticks_per_second):actor.tick(1.0/Engine.physics_ticks_per_second,g.camera,float(frame)/Engine.physics_ticks_per_second)
   check(actor.sprite.global_basis.orthonormalized().is_equal_approx(g.camera.global_basis),"whole seated pose uses the same camera basis as the normal player: "+str(actor.profile.id))
   check(pixel_world(actor.sprite,Vector2(64,100)).distance_to(actor.hip_anchor.global_position)<.006,"idle pose keeps hip-to-seat contact across camera changes: "+str(actor.profile.id))
 g.camera.transform=original_camera
 check(HumanArt.cache.size()==human_cache_before and SocialArt.cache.size()==social_cache_before,"bench animation leaves all established standing and social caches untouched")
 check(identity_snapshot(humans(g.world))==original_identities,"proportion checks retain all original actor instances, IDs and appearance profiles")
 check(hash(player_texture.get_image().get_data())==source_player_hash,"source player bitmap remains unchanged")
 if not output.is_empty():
  DirAccess.make_dir_recursive_absolute(output)
  var file:=FileAccess.open(output+"/proportion-metrics.json",FileAccess.WRITE)
  check(file!=null,"write independent source and actual actor metrics")
  if file!=null:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"actual_human_count":all_humans.size(),"ordinary_count":ordinary,"social_count":social,"physics_ticks_per_second":Engine.physics_ticks_per_second},"  "));file.close()
 await finish(g)
func finish(g) -> void:
 g.audio.shutdown();g.free();await process_frame
 print("HARBOR HUMAN PROPORTIONS v93 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
