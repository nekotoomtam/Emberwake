extends SceneTree
const Hero=preload("res://scripts/hero_visual.gd")
const Fixture=preload("res://tests/test_body_parts_visual.gd").AnatomyFixture
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1280,720)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();var settings:=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("303844")
 environment.environment=settings;world.add_child(environment)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,7,13);camera.look_at(Vector3(0,.7,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13.5
 var cases: Array=[
  ["Complete",{},{}],
  ["Missing head",{"head":true},{}],
  ["No arms",{"right_arm":true,"left_arm":true},{}],
  ["One leg",{"right_leg":true},{}],
  ["No legs: crawl",{"right_leg":true,"left_leg":true},{}],
  ["No arms / legs: wriggle",{"right_arm":true,"left_arm":true,"right_leg":true,"left_leg":true},{}],
  ["Arms 0%: still present",{},{"right_arm":0,"left_arm":0}],
  ["Missing left arm",{"left_arm":true},{}]]
 for i in range(cases.size()):
  var hero:=Hero.new();world.add_child(hero)
  hero.position=Vector3(-4.8+(i%4)*3.2,0,-1.6 if i<4 else 2.0)
  var anatomy:=Fixture.new();anatomy.missing=cases[i][1];anatomy.integrity=cases[i][2];hero.anatomy=anatomy
  hero.update_pose(camera,Vector3.BACK,true,{"phase":"idle","paired_body":true},2,0,0,.016)
  hero.weapon.visible=false
  # Show only floor-reaching crawl sleeves in the anatomy reference sheet.
  if anatomy.leg_count()>0:hero.grip_visual.visible=false
  var label:=Label3D.new();label.text=cases[i][0];label.font_size=30;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  label.position=hero.position+Vector3(0,-.23,.18);label.no_depth_test=true;world.add_child(label)
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://tests/body_visual_evidence")
 var screenshot:=root.get_texture().get_image()
 var status:=screenshot.save_png("res://tests/body_visual_evidence/native_parts.png")
 print("NATIVE BODY VISUAL CAPTURE: ",status)
 world.queue_free();await process_frame;quit(status)
