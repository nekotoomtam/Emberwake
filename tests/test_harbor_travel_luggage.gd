extends SceneTree
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const Directions=preload("res://scripts/hero_directions.gd")
const Walker=preload("res://scripts/opening/harbor_walker.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var path:="res://scripts/opening/harbor_travel_luggage.gd"
 check(ResourceLoader.exists(path),"existing cafe suitcase has a reusable rest/lift/carry owner")
 if not ResourceLoader.exists(path):finish();return
 var stage:=Node3D.new();root.add_child(stage)
 var camera:=Camera3D.new();stage.add_child(camera);camera.position=Profile.CAFE_CAMERA;camera.look_at(Profile.CAFE_LOOK)
 var hero:=Sprite3D.new();stage.add_child(hero);hero.pixel_size=.018;hero.global_basis=camera.global_basis;hero.position=Profile.CAFE+camera.global_basis.y*.864
 var bag=load(path).new();stage.add_child(bag)
 var visual_id: int=bag.visual_root.get_instance_id()
 check(bag.state==&"resting" and bag.floor_body.collision_layer==1,"seated suitcase blocks only its original floor footprint")
 check(bag.visual_root.position.distance_to(Vector3(-43.85,.295,-8.55))<.001,"resting suitcase retains the original cafe position")
 check(bag.floor_body.get_child(0).shape.size.distance_to(Vector3(.6,.46,.3))<.001,"resting blocker matches the original case body")
 var floor_grip: Vector3=bag.grip.global_position
 bag.update_stand(.30,hero,camera)
 check(bag.state==&"lifting" and bag.floor_body.collision_layer==0,"taking handle releases floor collision before movement")
 bag.update_stand(.65,hero,camera)
 check(bag.grip.global_position.y>floor_grip.y and bag.grip.global_position.distance_to(bag.hand_world)<.002,"midstand same handle stays inside the visible reaching hand")
 check(bag.stand_arm.visible and bag.stand_arm.texture!=null,"standup has a rendered sleeve and gripping fingers")
 bag.update_stand(1,hero,camera)
 var walker=Walker.new();walker.camera=camera;walker.carrying_luggage=true;walker.position=Profile.CAFE+Vector3.UP*.1;stage.add_child(walker);walker.set_physics_process(false)
 var before: Dictionary={}
 for facing in ["front","back","left","right"]:before[facing]=Directions.frames(facing).get_frame_texture("walk",1).get_image().get_data()
 var hand_positions: Dictionary={}
 for facing in ["front","back","left","right"]:
  walker.facing=facing;walker.clock=.13;walker.update_art(0,Vector3.ZERO);bag.update_carry(walker,camera)
  check(bag.state==&"carried" and bag.carry_facing==facing,"carry tracks "+facing+" facing without a duplicate bag")
  check(bag.grip.global_position.distance_to(bag.hand_world)<.002,"native handle meets the "+facing+" rendered hand")
  var pixel: Vector2=bag.carry_hand_pixel(facing,"idle",0)
  var image: Image=walker.sprite.texture.get_image();var skin: Color=image.get_pixel(int(pixel.x*4),int(pixel.y*4))
  check(skin.r>.80 and skin.g>.45 and skin.b<.85,"visible "+facing+" fingers occupy actual handle contact")
  check(walker.sprite.texture!=Directions.frames(facing).get_frame_texture("idle",0),"harbor carry pose uses private "+facing+" art")
  check(image.get_pixel(64,48)==Directions.frames(facing).get_frame_texture("idle",0).get_image().get_pixel(64,48),"carry preserves original "+facing+" face and hair")
  hand_positions[facing]=bag.hand_world
 check(hand_positions.front.distance_to(hand_positions.back)>.8 and hand_positions.left.distance_to(hand_positions.right)>.8,"turning puts luggage on the corresponding visible side")
 var idle_transform: Transform3D=bag.visual_root.global_transform
 walker.clock=.19;walker.update_art(0,Vector3(3,0,0));bag.update_carry(walker,camera)
 check(bag.grip.global_position.distance_to(bag.hand_world)<.002 and not bag.visual_root.global_transform.is_equal_approx(idle_transform),"walking sways the case around its attached handle")
 check(bag.floor_body.collision_layer==0 and bag.floor_body.position.distance_to(Vector3(-43.85,.295,-8.55))<.001,"carried luggage never drags a floor collider")
 for facing in before:check(before[facing]==Directions.frames(facing).get_frame_texture("walk",1).get_image().get_data(),"shared combat art remains unchanged for "+facing)
 bag.reset_resting()
 check(bag.state==&"resting" and bag.floor_body.collision_layer==1 and not bag.stand_arm.visible,"menu reset restores one grounded suitcase and removes reaching arm")
 check(bag.visual_root.get_instance_id()==visual_id and bag.visual_root.position.distance_to(Vector3(-43.85,.295,-8.55))<.001,"rest lift carry reset reuses the exact original visual object")
 check(bag.geometry_count>=7 and bag.visual_root.get_child_count()>0,"native case straps buckles label and handle remain rendered")
 stage.free();finish()
func finish() -> void:
 print("HARBOR TRAVEL LUGGAGE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
