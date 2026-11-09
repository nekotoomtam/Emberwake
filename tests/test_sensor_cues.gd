extends SceneTree
const Cues=preload("res://scripts/sense_cues.gd")
var checks:=0
var failures: Array[String]=[]
var game
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func run() -> void:
 var cues=Cues.new();cues.update({8:.4},{},0)
 check(cues.states.size()==1 and cues.states[8].alpha==1,"new persistent direction band")
 check(cues.states[8].flash==.2,"first detection flashes")
 cues.update({8:.4},{},.3);check(cues.states[8].flash==0 and cues.states[8].alpha==1,"band remains after flash")
 var phase: float=cues.states[8].phase;cues.update({8:.4},{},.1)
 check(cues.states[8].phase!=phase,"wave continues independently")
 check(cues.frequency(.9)>cues.frequency(.1) and cues.width(.9)>cues.width(.1),"near cues faster/thicker")
 cues.update({},{8:true},.08);check(cues.states.is_empty(),"reveal removes band immediately")
 cues.update({},{8:true},.09);check(cues.states.is_empty(),"reveal completes fade")
 cues.update({4:.5},{},0);cues.update({},{},.01);check(cues.states.is_empty(),"occlusion/range disappearance clears immediately")
 cues.update({0:.3,4:.8},{},0);cues.reset();check(cues.states.is_empty(),"reset removes bands")
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 game.start_run(true);game.clear_actors();game.test_aim=Vector3.RIGHT;await physics_frame;game._refresh_aim();game._visual_tick(.01)
 var center: Vector2=game.camera.unproject_position(game.player.position+game.camera.global_basis.y*.85)
 var edge: Vector2=game.camera.unproject_position(game.player.position+game.camera.global_basis.y*(.85+1.12)+game.camera.global_basis.x*.72)
 var radii: Vector2=(edge-center).abs()
 for bin in range(16):
  var points: PackedVector2Array=game.vision.cue_points(bin)
  var expanded: PackedVector2Array=game.vision.cue_points(bin,.4)
  var foot: Vector2=game.camera.unproject_position(game.player.position)
  check(points.size()==19,"smooth directional arc samples")
  var outside:=true;var outward:=true
  for i in range(points.size()):
   if ((points[i]-center)/radii).length()<1.095:outside=false
   if expanded[i].distance_to(foot)<points[i].distance_to(foot)+.01:outward=false
  check(outside,"all directions avoid body clarity ellipse")
  check(outward,"wave travels outward")
 var enemy=game.spawn_enemy("melee",game.player.position+Vector3.LEFT*3);enemy.stagger=10
 await physics_frame;game._visual_tick(.01)
 check(game.vision.cues.states.has(8),"real detected rear monster creates band")
 game.test_aim=Vector3.LEFT;game._visual_tick(.08)
 check(game.vision.warnings.is_empty() and game.vision.cues.states.is_empty(),"revealed monster immediately removes cue")
 game._visual_tick(.09);check(game.vision.cues.states.is_empty(),"visible enemy no lingering cue")
 game.test_aim=Vector3.RIGHT;game._visual_tick(.01);enemy.dead=true;game._visual_tick(.01)
 check(game.vision.cues.states.is_empty(),"dead threat clears band immediately")
 game.start_run(true);game.clear_actors();game.test_aim=Vector3.RIGHT
 var old=game.spawn_enemy("melee",game.player.position+Vector3.LEFT*3);game._visual_tick(.01)
 old.dead=true;var newcomer=game.spawn_enemy("melee",game.player.position+Vector3(-3,0,.1))
 game.test_aim=Vector3.LEFT;game._visual_tick(.01)
 check(newcomer.visible and game.vision.cues.states.is_empty(),"visible newcomer cannot preserve dead threat cue")
 game.start_run(true);game.clear_actors();game.test_aim=Vector3.RIGHT
 old=game.spawn_enemy("melee",game.player.position+Vector3.LEFT*3);game._visual_tick(.01)
 old.position.z+=1.5;game.test_aim=Vector3.LEFT;game._visual_tick(.01)
 check(game.vision.cues.states.is_empty(),"same revealed threat removes cue after moving direction bins")
 game._visual_tick(.17);check(game.vision.cues.states.is_empty(),"identity based reveal fade expires")
 game.test_aim=Vector3.RIGHT;game.aim=Vector3.RIGHT
 check(game.vision.cue_segments(0).is_empty(),"front band has no drawn segments")
 check(not game.vision.cue_segments(3).is_empty(),"edge band retains hidden portion")
 var foot: Vector2=game.camera.unproject_position(game.player.position)
 for heading in [0.0,.15,-.15,PI*.5]:
  game.test_aim=Vector3(cos(heading),0,sin(heading))
  for bin in range(16):
   for segment in game.vision.cue_segments(bin):
    for point in segment:
     var ground: Vector2=game.vision.ground(point)
     var offset:=Vector3(ground.x-game.player.position.x,0,ground.y-game.player.position.z).normalized()
     check(offset.dot(game.test_aim)<.501,"all drawn arc samples outside120degree cone")
 game.start_run(true);check(game.vision.cues.states.is_empty(),"retry clears previous directions and contributors")
 game.mode="menu";game.vision.update_view(0);check(game.vision.cues.states.is_empty(),"menu clears presentation")
 game.queue_free();await process_frame
 print("SENSOR CUES: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
