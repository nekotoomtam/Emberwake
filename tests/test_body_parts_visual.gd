extends SceneTree
const Parts=preload("res://scripts/body_parts_visual.gd")
const Directions=preload("res://scripts/hero_directions.gd")
const Anatomy=preload("res://scripts/anatomy_state.gd")
const Hero=preload("res://scripts/hero_visual.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func pixels(image: Image)->int:
 var count:=0
 for y in image.get_height():
  for x in image.get_width():
   if image.get_pixel(x,y).a>0:count+=1
 return count
func run()->void:
 var world:=Node3D.new();root.add_child(world)
 var camera:=Camera3D.new();world.add_child(camera)
 camera.position=Vector3(0,6,12);camera.look_at(Vector3(0,.7,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=15
 var atlas:=Image.create(128*7,128*4,false,Image.FORMAT_RGBA8);atlas.fill(Color("303844"))
 var row:=0
 for facing: String in Directions.DIRECTIONS:
  var texture:=Directions.frames(facing,true).get_frame_texture("idle",0)
  var layers:=Parts.layers(texture,facing,"idle",0)
  var composed:=Image.create(128,128,false,Image.FORMAT_RGBA8);composed.fill(Color.TRANSPARENT)
  for id: String in ["torso","right_leg","left_leg","right_arm","left_arm","head"]:
   var image: Image=layers[id].get_image()
   check(pixels(image)>0,facing+"/"+id+" native layer contains visible pixels")
   composed.blend_rect(image,Rect2i(0,0,128,128),Vector2i.ZERO)
  atlas.blend_rect(composed,Rect2i(0,0,128,128),Vector2i(0,row*128))
  for i in range(Parts.PARTS.size()):atlas.blend_rect(layers[Parts.PARTS[i]].get_image(),Rect2i(0,0,128,128),Vector2i((i+1)*128,row*128))
  for animation: String in Directions.frames(facing).get_animation_names():
   for frame in range(Directions.frames(facing).get_frame_count(animation)):
    var images:=Parts.layers(Directions.frames(facing).get_frame_texture(animation,frame),facing,animation,frame)
    check(images.size()==6,facing+"/"+animation+str(frame)+" exactly six major parts")
  row+=1
 DirAccess.make_dir_recursive_absolute("user://body_visual_evidence")
 atlas.save_png("user://body_visual_evidence/layers.png")
 var hero:=Hero.new();world.add_child(hero)
 var anatomy:=Anatomy.new();hero.anatomy=anatomy
 for facing: String in Directions.DIRECTIONS:
  var aim: Vector3={"front":Vector3.BACK,"back":Vector3.FORWARD,"left":Vector3.LEFT,"right":Vector3.RIGHT}[facing]
  hero.update_pose(camera,aim,false,{"phase":"idle"},2,0,0,.01)
  for id: String in Parts.PARTS:
   anatomy.reset();anatomy.remove(id)
   hero.update_pose(camera,aim,false,{"phase":"idle"},2,0,0,.01)
   for other: String in Parts.PARTS:check(hero.modular_body.parts[other].visible==((other!=id or id=="torso")),facing+" missing "+id+" actual sprite "+other)
  anatomy.reset()
  check(hero.body.modulate.a==0 and not hero.back_hair.visible and not hero.pair_body_mask.visible,"legacy whole body and overlays suppressed")
 for limb: String in Anatomy.LIMBS:anatomy.remove(limb)
 hero.update_pose(camera,Vector3.BACK,true,{"phase":"idle"},2,0,0,.01)
 check(hero.body.global_position.y<.5,"no legs: body is floor-low")
 check(not hero.grip_visual.primary.visible and not hero.grip_visual.support.visible,"no arms: no procedural sleeves remain")
 anatomy.reset();anatomy.set_integrity("right_forearm",0)
 hero.update_pose(camera,Vector3.BACK,false,{"phase":"idle"},2,0,0,.01)
 check(hero.modular_body.parts.right_arm.visible,"zero integrity arm present but weak")
 check(hero.grip_visual.primary.visible,"zero integrity arm still holds a weapon")
 hero.anatomy=null
 hero.update_pose(camera,Vector3.BACK,false,{"phase":"idle"},2,0,0,.01)
 check(not hero.modular_body.visible and hero.body.modulate.a==1,"null anatomy retains legacy rendering")
 hero.body.visible=false
 check(not hero.modular_body.is_visible_in_tree(),"equipment-only rigs never show a modular whole body")
 world.queue_free();await process_frame
 print("BODY PART VISUALS: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL", " ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
