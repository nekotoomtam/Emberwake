extends SceneTree
var g
var count:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 count+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func head(e) -> Vector2:
 var direction: Vector3=-e.captain_view.anchor.global_basis.y
 return Vector2(direction.dot(g.camera.global_basis.x),direction.dot(g.camera.global_basis.y)).normalized()
func phase(id: String,angle: float,time: float) -> Variant:
 g.start_captain();var e=g.enemies[0];e.position=Vector3.ZERO;e.attack_angle=angle;e.sprite.flip_h=angle>PI*.5 and angle<PI*1.5;e.state="attack";e.attack_data=e.Rules.definition(id)
 if id=="throw":e.configure_throw_launch()
 e.elapsed=time;e.active_left=e.attack_data.active-time;e.tick(.000001,g);return e
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path=""
 var e=phase("throw",0,.5);var right:=head(e);e=phase("throw",PI,.5);var left:=head(e)
 check(right.x>.65 and left.x<-.65,"outgoing heavy head follows actual right/left throw, not same sine tilt")
 check(absf(right.y-left.y)<.15,"mirrored throw has matching vertical lean")
 e=phase("sweep",0,0);e.state="windup";e.telegraph_left=.525;e.tick(.000001,g);var wr:=head(e);e=phase("sweep",PI,0);e.state="windup";e.telegraph_left=.525;e.tick(.000001,g);check(wr.x*head(e).x<-.10,"windup sway mirrors with facing")
 var seen: Array[Vector2]=[]
 for i in range(8):
  var angle:=TAU*i/8;e=phase("throw",angle,.5);var d: Dictionary=e.attack_data;var v: Vector3=e.Rules.tip(d,angle,.51)-e.Rules.tip(d,angle,.49)+g.camera.global_basis.y*(e.Rules.visual_lift(d,.51)-e.Rules.visual_lift(d,.49));var projected:=Vector2(v.dot(g.camera.global_basis.x),v.dot(g.camera.global_basis.y)).normalized()
  check(head(e).dot(projected)>.70,"head follows projected outbound direction "+str(i));seen.append(head(e))
  check(e.captain_view.anchor.global_position.distance_to(e.position+e.Rules.tip(d,angle,e.elapsed)+g.camera.global_basis.y*(e.Rules.VISUAL_HEIGHT+e.Rules.visual_lift(d,e.elapsed)))<.00001,"rotation does not move damaging center "+str(i))
  check(e.captain_view.chain_end.distance_to(e.captain_view.anchor_ring_world())<.00001,"chain stays on rotated ring "+str(i))
 check(seen[0].distance_to(seen[4])>1.3,"opposite directions visibly differ")
 for angle in [0.0,PI]:
  e=phase("throw",angle,1.20);var away: Vector3=e.captain_view.anchor.global_position-e.chain_wrist();var radial:=Vector2(away.dot(g.camera.global_basis.x),away.dot(g.camera.global_basis.y)).normalized();check(head(e).dot(radial)>.85,"return pulls ring first and head trails "+str(angle))
  e=phase("throw",angle,1.54999);var prior: Vector3=e.captain_view.anchor.global_position;e.tick(.00002,g);check(prior.distance_to(e.captain_view.anchor.global_position)<.01,"no catch position snap "+str(prior)+" -> "+str(e.captain_view.anchor.global_position));check(head(e).distance_to(Vector2.UP)<.002,"upright at catch");check(e.captain_view.anchor_ring_world().distance_to(e.chain_wrist())<.001,"catch ring in hand")
 var moving: Array[Vector2]=[]
 for t in [.08,.23,.44]:
  e=phase("sweep",0,t);moving.append(head(e))
 check(moving[0].distance_to(moving[2])>.5,"sweep anchor visibly turns through arc")
 e=phase("slam",0,.05);var pa: Dictionary=e.Pose.sample(e.attack_data,"attack",0,.049,0,0);var pb: Dictionary=e.Pose.sample(e.attack_data,"attack",0,.051,0,0);var velocity: Vector3=Vector3(pb.tip)-Vector3(pa.tip)+g.camera.global_basis.y*(float(pb.lift)-float(pa.lift));var down:=Vector2(velocity.dot(g.camera.global_basis.x),velocity.dot(g.camera.global_basis.y)).normalized();check(down.y<0 and head(e).dot(down)>.95,"slam head follows actual longer downward trajectory")
 for id in ["sweep","throw","slam"]:
  for i in range(8):
   var angle:=TAU*i/8;e=phase(id,angle,0);e.state="windup";e.telegraph_left=.000002;e.tick(.000001,g);var a:=head(e);e.tick(.000002,g);check(a.dot(head(e))>.999,"view release rotation continuous "+id+str(i))
   e=phase(id,angle,float(e.Rules.definition(id).active)-.000002);a=head(e);e.tick(.000003,g);check(a.dot(head(e))>.999,"view active/recover rotation continuous "+id+str(i))
   e.cooldown=.000002;e.tick(.000001,g);a=head(e);e.tick(.000003,g);check(a.dot(head(e))>.999,"view recovery/idle rotation continuous "+id+str(i))
 for id in ["sweep","throw","slam"]:
  for i in range(8):
   e=phase(id,TAU*i/8,0);var previous_head:=head(e);var smallest:=1.0;var worst:=""
   for frame_index in range(320):
    e.tick(1.0/60,g);var current_head:=head(e);if previous_head.dot(current_head)<smallest:smallest=previous_head.dot(current_head);worst=e.state+" elapsed="+str(e.elapsed)+" cd="+str(e.cooldown)
    previous_head=current_head
    if e.state=="chase":break
   check(smallest>.70,"no intermediate rotation flip "+id+str(i)+" min_dot="+str(smallest)+" "+worst)
 g.queue_free();await process_frame;await process_frame
 print("CAPTAIN ORIENTATION: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
