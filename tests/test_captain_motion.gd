extends SceneTree
var checks:=0
var failures: Array=[]
func check(v: bool,s: String) -> void:
 checks+=1
 if not v:failures.append(s);printerr("FAIL: ",s)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 if not ResourceLoader.exists("res://scripts/captain_pose.gd"):check(false,"phase pose sampler missing");finish();return
 var p=load("res://scripts/captain_pose.gd");var r=load("res://scripts/captain_rules.gd")
 for id in ["sweep","throw","slam"]:
  var d: Dictionary=r.definition(id);var seen: Dictionary={}
  for i in range(5):
   var pose: Dictionary=p.sample(d,"windup",d.windup*(1.0-float(i)/4),0,0,0);seen[pose.frame]=true
   check(pose.animation==id+"_windup","specific tell "+id);check(pose.tip.is_finite() and is_finite(pose.lift),"finite pose")
  check(seen.size()==5,"five windup poses "+id)
  var before: Dictionary=p.sample(d,"windup",0,0,0,0);var active: Dictionary=p.sample(d,"attack",0,0,0,0)
  check(before.tip.distance_to(active.tip)<.001 and absf(before.lift-active.lift)<.001,"continuous release "+id)
  for i in range(51):
   var t: float=d.active*i/50;var pose: Dictionary=p.sample(d,"attack",0,t,0,0)
   if r.damaging(d,t):check(pose.tip.distance_to(r.tip(d,0,t))<.001 and absf(float(pose.lift)-r.visual_lift(d,t))<.001,"damaging anchor exactly matches visual "+id)
 var sl: Dictionary=r.definition("slam");check(not r.damaging(sl,0),"overhead slam not yet damaging");check(r.damaging(sl,sl.active*.4),"slam impact gate")
 var g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path="";g.start_captain();var e=g.enemies[0]
 check(e.sprite.pixel_size>=.028,"large slender sprite");var body: CollisionShape3D=e.get_node("BodyCollision");check(absf(body.shape.radius-.4)<.001 and absf(body.shape.height-2.752)<.001,"matching enlarged capsule")
 e.position=Vector3.ZERO;e.attack_data=r.definition("sweep");e.state="windup";e.telegraph_left=.4;e.tick(.01,g)
 check(e.sprite.animation=="sweep_windup" and e.sprite.frame>0,"actor uses authored windup frames")
 g.debug_range=false;e.captain_view.update_view(g);check(e.captain_view.fill.get_surface_count()==0 and e.captain_view.edges.get_surface_count()==0,"default no ground telegraph")
 g.debug_range=true;e.captain_view.update_view(g);check(e.captain_view.fill.get_surface_count()>0,"H retains diagnostic footprint")
 g.debug_range=false;e.attack_data=r.definition("slam");e.state="windup";e.captain_view.cue.modulate=Color.WHITE;e.captain_view.update_view(g);check(e.captain_view.cue.visible and e.captain_view.cue.modulate.r>e.captain_view.cue.modulate.g*2,"red attack cue independent of H")
 check(e.captain_view.chain_links>=12,"visible articulated chain links")
 var arm: Dictionary=e.hurt_regions()[0];var hand: Vector2=e.CaptainArt.arm_center_pixel(e.sprite.animation,e.sprite.frame)
 var side: float=-1 if e.sprite.flip_h else 1
 check(absf((arm.position-e.position).dot(e.view_right)-(hand.x-64)*e.sprite.pixel_size*side)<.001,"arm region follows art pose")
 g.test_aim=Vector3.RIGHT;g.vision.update_view(0)
 check(g.vision.material.get_shader_parameter("actor_enabled")!=null and float(g.vision.material.get_shader_parameter("actor_enabled"))>0,"visible tall actor alpha protected from ground fog")
 g.test_aim=Vector3.LEFT;g.vision.update_view(0)
 check(g.vision.material.get_shader_parameter("actor_enabled")!=null and float(g.vision.material.get_shader_parameter("actor_enabled"))==0,"hidden actor no sharp mask")
 g.test_aim=Vector3.RIGHT;var wall:=StaticBody3D.new();wall.collision_layer=1;var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,2.5,3);collider.shape=box;wall.add_child(collider);wall.position=Vector3(-1.5,1,0);g.add_child(wall);await physics_frame;await physics_frame;g.vision.update_view(0)
 check(float(g.vision.material.get_shader_parameter("actor_enabled"))==0,"wall occlusion disables actor mask")
 g.queue_free();await process_frame;finish()
func finish() -> void:
 print("CAPTAIN MOTION: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
