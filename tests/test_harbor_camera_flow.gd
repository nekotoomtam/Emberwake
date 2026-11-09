extends SceneTree
## Actual camera travel, not a duplicate of the rail's interpolation formula.
const Camera=preload("res://scripts/opening/harbor_camera.gd")
const Plaza=preload("res://scripts/opening/harbor_plaza_profile.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var camera=Camera.new();root.add_child(camera)
 var start: Transform3D=camera.transform
 camera.start_flyin();camera.tick(0)
 check(camera.transform.is_equal_approx(start),"Start retains the menu's actual ship composition without a cut")
 var step:=1.0/120.0;var last: Vector3=camera.position
 var previous_velocity:=Vector3.ZERO;var previous_forward: Vector3=-camera.basis.z
 var minimum_speed:=INF;var maximum_speed:=0.0;var maximum_acceleration:=0.0;var maximum_turn:=0.0
 var total_steps: int=roundi(camera.intro_duration/step)
 for frame in total_steps:
  camera.tick(step)
  var at: float=(frame+1)*step
  var velocity: Vector3=(camera.position-last)/step
  if at>=2 and at<=camera.intro_duration-3.1:
   minimum_speed=minf(minimum_speed,velocity.length());maximum_speed=maxf(maximum_speed,velocity.length())
   maximum_acceleration=maxf(maximum_acceleration,(velocity-previous_velocity).length()/step)
  maximum_turn=maxf(maximum_turn,previous_forward.angle_to(-camera.basis.z)/step)
  last=camera.position;previous_velocity=velocity;previous_forward=-camera.basis.z
 check(minimum_speed>.8,"the camera never parks at intermediate ship/city/pan waypoints")
 check(maximum_speed/maxf(.0001,minimum_speed)<1.15,"middle travel maintains even speed instead of restarting ease at each waypoint")
 check(maximum_acceleration<18,"no velocity corner when changing from ship to city to cafe")
 check(maximum_turn<deg_to_rad(45),"attention turns smoothly without a sudden look-direction snap")
 camera.tick(.01)
 check(not camera.flying and camera.view_id==&"cafe" and camera.position.distance_to(Plaza.CAFE_CAMERA)<.001,"flight lands exactly at the existing coffee composition")
 var finish: Transform3D=camera.transform;var finish_fov: float=camera.fov
 camera.set_view(&"cafe",0)
 check(camera.transform.is_equal_approx(finish) and is_equal_approx(camera.fov,finish_fov),"dialogue's cafe handoff introduces no transform or lens pop")
 camera.set_view(&"lighthouse",0);camera.start_flyin();camera.tick(5.7)
 var coarse: Transform3D=camera.transform
 camera.set_view(&"lighthouse",0);camera.start_flyin()
 for frame in 570:camera.tick(.01)
 check(camera.transform.is_equal_approx(coarse),"camera travel depends on elapsed time, not frame rate")
 camera.set_view(&"cafe",0)
 var before_follow: Vector3=-camera.basis.z
 camera.follow_actor(Plaza.CAFE+Vector3.UP*.1,1.0/60)
 check(before_follow.angle_to(-camera.basis.z)<deg_to_rad(.6),"first controllable frame blends into follow instead of snapping the look direction")
 camera.free()
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 var initial_ship: Vector3=g.world.arrival.position
 g.tick(3)
 var moving_ship: Vector3=g.world.arrival.position
 var menu_camera: Transform3D=g.camera.transform
 check(moving_ship.x<initial_ship.x-4 and g.world.arrival.wake_intensity>.5,"menu shows the ship advancing in open water with a wake")
 g.ui.start_button.pressed.emit()
 check(g.camera.transform.is_equal_approx(menu_camera) and g.world.arrival.position.is_equal_approx(moving_ship),"Start preserves both camera framing and the moving ship position")
 g.tick(7)
 var paused: Transform3D=g.camera.transform;var age: float=g.camera._age;var clock: float=g.world.clock
 g.ui.open_settings();g.tick(3)
 check(g.camera.transform.is_equal_approx(paused) and is_equal_approx(g.camera._age,age) and is_equal_approx(g.world.clock,clock),"settings pause camera and world together without silently advancing the shot")
 g.ui.close_settings();g.tick(.1)
 check(is_equal_approx(g.camera._age,age+.1) and g.camera.position.distance_to(paused.origin)<.5,"resume continues from the retained location instead of catching up with a jump")
 for skip_time in [0.0,6.0,15.0,27.7]:
  g.return_title();g.ui.start_button.pressed.emit();g.tick(skip_time)
  var event:=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.pressed=true
  g._unhandled_key_input(event)
  check(g.phase==&"play" and g.walker!=null and g.walker.carrying_luggage and not g.camera.flying,"Space at "+str(skip_time)+"s reaches the real playable actor without a stale cinematic")
  event.physical_keycode=KEY_ESCAPE;g._unhandled_key_input(event)
  var preview_eye: Vector3=g.world.arrival.position+Camera.OPEN_WATER_EYE
  check(g.phase==&"title" and g.walker==null and g.ui.menu.visible and g.camera.position.distance_to(preview_eye)<.001,"Escape after skip restores the open-water ship preview for another run")
 g.audio.shutdown();g.free();await process_frame
 print("CAMERA FLOW ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 print("MOTION speed=",minimum_speed,"..",maximum_speed," acceleration=",maximum_acceleration," max_turn_deg=",rad_to_deg(maximum_turn))
 quit(0 if failures.is_empty() else 1)
