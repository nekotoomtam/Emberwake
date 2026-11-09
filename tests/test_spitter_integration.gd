extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(time: float) -> void:
 while time>.0000001:
  var dt:=minf(time,1.0/120);g.tick(dt);time-=dt
func run() -> void:
 check(ResourceLoader.exists("res://scripts/spitter_enemy.gd"),"dedicated illustrated spitter exists")
 if not failures.is_empty():finish();return
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false)
 check(g.has_method("start_spitter_trial"),"trial route")
 g.start_spitter_trial();var e=g.enemies[0];e.cooldown=0
 advance(.01);check(e.state=="windup","AI starts windup")
 var origin: Vector3=e.lane_origin;var direction:=Vector3(cos(e.attack_angle),0,sin(e.attack_angle));var side:=Vector3(-direction.z,0,direction.x)
 for distance in [.2,1.8,3.6]:
  check(e.threatens(origin+direction*distance),"full lane threat "+str(distance))
 check(not e.threatens(origin+direction*1.8+side*.57),"outside width safe")
 check(not e.threatens(origin+direction*4.4),"past end safe")
 g.player.position=origin+direction*1.8
 advance(.96);check(g.health==100,"no windup damage")
 advance(.06);check(g.health==91,"first flow hits middle of lane9")
 check(g.brine_zones.zones.size()==1 and g.projectiles.is_empty(),"one wet lane not glob projectile")
 var zone: Dictionary=g.brine_zones.zones[0]
 check(zone.origin.distance_to(origin)<.001,"visual ground origin shares contact origin")
 check(is_equal_approx(zone.reach,e.lane_reach),"wet lane shares reach")
 check(is_equal_approx(zone.width,1.1),"wet width matches threat")
 var lock: float=e.attack_angle;g.player.position=origin+side*2
 advance(.3);check(e.attack_angle==lock,"flow never tracks target")
 g.player.position=origin+direction*.2;g._iframes=0
 advance(1.05);check(g.health<91,"near section takes residual damage")
 e.stagger=100
 var before: float=g.health;g.player.position=origin+direction*3.6;g._iframes=0;advance(.55)
 check(g.health<before,"far section takes residual damage")
 g.player.position=origin+side*2;before=g.health;advance(.55);check(g.health==before,"outside lane no poison")
 e.queue_free();g.enemies.clear();g.drill_kind="";g.mode="combat";g._wave_wait=-100
 advance(2.1);check(g.brine_zones.zones.is_empty(),"expires3sec after emission")
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;advance(1.1)
 check(not g.brine_zones.zones.is_empty(),"second fixture emitted")
 g.toggle_pause();var remaining: float=g.brine_zones.zones[0].remaining;advance(.6);check(g.brine_zones.zones[0].remaining==remaining,"pause freezes poison");g.toggle_pause()
 g.restart();check(g.drill_kind=="spitter" and g.brine_zones.zones.is_empty(),"restart clears ground and restores trial")
 # Full defensive, receiving, and timing fixtures.
 for view in ["right","left","front","back"]:
  g.start_spitter_trial();e=g.enemies[0];e.cooldown=0
  var facing: Vector3=load("res://scripts/fisherman_art.gd").ground_direction(view,g.camera)
  g.player.position=e.position+facing*2.5;g.test_aim=-facing
  advance(.02);check(e.spitter_direction()==view,view+" locked facing")
  check(e.sprite.sprite_frames.get_frame_texture(view+"_attack",0).get_size()==Vector2(128,128),view+" actual128 texture")
  advance(1.0);check(g.health==91,view+" attack actually damages")
  check(not e.image_hurt_regions(e.position.y+.7).is_empty(),view+" body image receiving regions")
  var mouth: Vector3=e.mouth_world();check(mouth.is_finite() and mouth.distance_to(e.position)<4,view+" attached finite mouth")
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;advance(.02)
 origin=e.lane_origin;direction=Vector3(cos(e.attack_angle),0,sin(e.attack_angle));g.player.position=origin+direction*1.5
 advance(.94);g.request_dodge(Vector3.BACK);advance(.11)
 check(g.health==100,"dash iframe avoids stream")
 check(g.rewards.refunded,"perfect dodge against lane grants reward")
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;g.test_aim=(e.position-g.player.position).normalized();advance(.95)
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;root.push_input(event,true);Input.flush_buffered_events()
 advance(.1);check(g.health>91 and g.health<100 and g.readiness.parries==0,"stream is red, guardable but never parryable")
 event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=false;root.push_input(event,true);Input.flush_buffered_events()
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;advance(.4);e.receive_damage(1,Vector3.ZERO);advance(.7)
 check(g.brine_zones.zones.is_empty(),"interrupted windup leaves no phantom poison")
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;advance(.1)
 var wall:=StaticBody3D.new();wall.collision_layer=1
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,4,5);shape.shape=box;wall.add_child(shape);wall.position=(e.position+g.player.position)*.5+Vector3.UP*1.5;g.add_child(wall)
 await physics_frame;await physics_frame
 check(not e.threatens(g.player.position),"inserted wall removes stream threat")
 advance(1.0);check(g.health==100,"wall blocks direct flow")
 check(not g.brine_zones.covers(g.brine_zones.zones[0],g.player.position),"wall blocks residual poison")
 wall.free()
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;advance(1.1)
 var first_zone: Dictionary=g.brine_zones.zones[0];e.receive_damage(1000,Vector3.ZERO);advance(.05)
 check(not g.brine_zones.zones.is_empty() and not first_zone.flowing,"caster death stops liquid but preserves wet floor")
 # Independent duplicate lanes must not double the periodic damage.
 g.start_spitter_trial();e=g.enemies[0];e.stagger=100
 origin=g.player.position-Vector3.RIGHT
 var z1: Dictionary=g.brine_zones.spawn_lane(origin,0,3.8,1.1,e)
 var z2: Dictionary=g.brine_zones.spawn_lane(origin,0,3.8,1.1,e)
 g.brine_zones.tick(.5,g)
 check(g.health==98,"overlapping poison deduplicates pulse")
 check(g.brine_zones.covers(z1,origin+Vector3.RIGHT*3.8+Vector3.BACK*.54),"wet capsule inside boundary")
 check(not g.brine_zones.covers(z1,origin+Vector3.RIGHT*3.8+Vector3.BACK*.56),"wet capsule outside boundary")
 g.return_menu();check(g.brine_zones.zones.is_empty(),"all hazards cleared")
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;advance(1.86)
 var fine_remaining: float=g.brine_zones.zones[0].remaining
 g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;g.tick(1.86)
 check(absf(g.brine_zones.zones[0].remaining-fine_remaining)<.02,"coarse tick preserves full3sec tail")
 var dot_health: Array=[]
 for coarse in [false,true]:
  g.start_spitter_trial();e=g.enemies[0];e.cooldown=0;advance(1.1)
  var patch: Dictionary=g.brine_zones.zones[0]
  g.player.position=patch.origin+Vector3(cos(patch.angle),0,sin(patch.angle))*2
  e.queue_free();g.enemies.clear();g.mode="combat";g._wave_wait=-100
  advance(.02);g._iframes=0
  if coarse:g.tick(2.01)
  else:advance(2.01)
  dot_health.append(g.health)
 check(is_equal_approx(dot_health[0],dot_health[1]),"caster gone coarse DOT matches fine pulses")
 for coarse in [false,true]:
  g.start_spitter_trial();e=g.enemies[0];e.dead=true;e.state="idle"
  var residual: Dictionary=g.brine_zones.spawn_lane(g.player.position-Vector3.RIGHT,0,3.8,1.1,e)
  residual.flowing=false;residual.remaining=3;g.enemies.clear();g.mode="combat";g._wave_wait=-100
  if coarse:g.tick(3)
  else:advance(3)
  check(is_equal_approx(g.health,88),"dead owner full six poison pulses coarse="+str(coarse)+" hp="+str(g.health))
  e.queue_free()
 g.start_coast();var count:=0
 for mob in g.enemies:
  if mob.kind=="spitter":count+=1;check(mob.has_method("spitter_direction"),"coast uses illustrated spitter")
 check(count>0,"coast includes spitter")
 g.return_menu();check(g.brine_zones.zones.is_empty(),"menu cleanup")
 g.free();await process_frame;finish()
func finish() -> void:
 print("SPITTER ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)


