extends SceneTree
const Roster=preload("res://scripts/coastal_roster.gd")
const Enemy=preload("res://scripts/coastal_enemy.gd")
var count:=0
var failures: Array=[]
var g
class Fixture extends Node3D:
 var player:=Node3D.new()
 var camera:=Camera3D.new()
 var health:=100.0
 var debug_range:=false
 var enemies: Array=[]
 var arena=null
 var hits: Array=[]
 var shots: Array=[]
 var evades:=0
 var parry:=false
 var dodge:=false
 func _ready() -> void:add_child(player);add_child(camera)
 func incoming_attack(damage,source,parryable,owner,guard,part,injury) -> void:
  hits.append({"damage":damage,"source":source,"parryable":parryable,"guard":guard,"part":part,"injury":injury})
  if parry and parryable:owner.receive_parry()
  elif not dodge:health-=damage
 func shoot(where,direction,damage,parryable,owner,guard,reach,part,injury) -> void:
  shots.append({"where":where,"direction":direction,"damage":damage,"parryable":parryable,"owner":owner,"guard":guard,"reach":reach,"part":part,"injury":injury})
 func check_perfect_evade(_enemy) -> void:evades+=1
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 count+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func close(a: float,b: float,label: String) -> void:check(absf(a-b)<.002,label+" got="+str(a))
func spawn(kind: String):
 var e=Enemy.new();e.kind=kind;g.add_child(e);g.enemies.append(e);return e
func clear() -> void:
 for e in g.enemies:e.free()
 g.enemies.clear();g.hits.clear();g.shots.clear();g.health=100;g.parry=false;g.dodge=false
func commit(e,index: int=0) -> void:
 e.attack_data=Roster.attack(e.kind,index);e.state="windup";e.telegraph_left=e.attack_data.windup;e.cooldown=0;e.attack_hit=false;e.attack_angle=0;e.elapsed=0;e.engaged=true;e.target_point=e.global_position+Vector3.RIGHT*4
func run() -> void:
 for kind in Roster.kinds():
  var data: Dictionary=Roster.stats(kind)
  check(data.health>=60 and data.health<=120,kind+" ordinary health")
  for i in range(2):
   var a: Dictionary=Roster.attack(kind,i)
   check(a.windup>=.85 and a.windup<=1.3,kind+" readable windup")
   check(a.active>0 and a.recovery>=1,kind+" recovery opening")
   check(a.body_damage>0 and a.body_part!="",kind+" player injury contract")
   check(a.shape in ["lane","sector"],kind+" compatible footprint")
 for kind in Roster.kinds():
  check(Roster.attack(kind,5).body_part=="head",kind+" six part player head target")
 check(Roster.attack("harpooner",0).damage>Roster.attack("spitter",0).damage,"ranged roles differ")
 check(Roster.attack("harpooner",0).recovery>Roster.attack("spitter",0).recovery,"strong shot longer opening")
 g=Fixture.new();root.add_child(g)
 for kind in Roster.kinds():
  clear();var e=spawn(kind);g.player.position=Vector3(.75,0,0);commit(e)
  close(e.health,Roster.stats(kind).health,kind+" instantiated hp")
  check(e.hurt_regions().size()==1 and e.hurt_regions()[0].id=="body",kind+" body only no cut")
  check(not e.has_method("register_melee_contact"),kind+" no limb-cut mechanics")
  e.tick(float(e.attack_data.windup)-.05,g)
  check(g.hits.is_empty() and g.shots.is_empty(),kind+" windup harmless")
  e.tick(.075,g)
  check(g.hits.is_empty() and g.shots.is_empty(),kind+" early active harmless")
  e.tick(.2,g)
  if kind in ["harpooner","spitter"]:
   check(g.shots.size()==1,kind+" one delayed shot")
   check(g.shots[0].owner==e and g.shots[0].injury>0,kind+" projectile defense injury contract")
   var end: Vector3=g.shots[0].where+g.shots[0].direction*g.shots[0].reach;end.y=e.global_position.y
   close(end.distance_to(e.global_position),e.attack_data.reach,kind+" bounded projectile endpoint")
  else:
   check(g.hits.size()==1,kind+" one delayed hit")
   check(g.hits[0].injury>0 and g.hits[0].part!="",kind+" melee injury contract")
  if kind in ["harpooner","spitter"]:
   close(e.attack_data.width,.8,kind+" guide width equals contact diameter")
   var launch: Dictionary=e.projectile_launch(g);var pixel: Vector2=e.CoastalArt.muzzle_pixel(kind,false)
   var expected: Vector3=e.global_position+g.camera.global_basis.x*((pixel.x-64)*e.sprite.pixel_size)+g.camera.global_basis.y*((112-pixel.y)*e.sprite.pixel_size)
   check(g.shots[0].where.distance_to(expected)<.001,kind+" physical projectile leaves painted muzzle")
   var locked_direction: Vector3=launch.direction;g.player.position=Vector3(-8,0,6);check(e.projectile_launch(g).direction.distance_to(locked_direction)<.001,kind+" release target stays committed after player moves")
  var events: int=g.hits.size()+g.shots.size();e.tick(.6,g)
  check(g.hits.size()+g.shots.size()==events,kind+" once only active contact")
  check(e.state=="recover",kind+" recovery opening")
  check(e.attack_visual.get_children()[0].visible==false,kind+" ground guides hidden")
  e.hurt_regions()[0].position=e.global_position
  var frozen: float=e.clock;e.tick(0,g);close(e.clock,frozen,kind+" zero tick freezes")
  e.receive_parry();e.tick(.1,g);check(e.state=="parried",kind+" inherited parry interruption")
  e.apply_rifle_mark();e.apply_mace_break();check(e.rifle_mark.remaining>0 and e.mace_armor.remaining>0,kind+" marks and armor remain usable")
  e.receive_damage(2,Vector3.ZERO);check(e.state=="chase" and e.stagger>0,kind+" injury interrupts")
  e.receive_damage(1000,Vector3.ZERO);e.tick(.2,g);check(e.dead and e.sprite.animation=="death",kind+" death lifecycle")
 clear();var boundary_enemy=spawn("fisherman");g.player.position=Vector3(1,0,0);commit(boundary_enemy)
 var before_micro: float=boundary_enemy.clock;boundary_enemy.tick(.000001,g);close(boundary_enemy.clock,before_micro+.000001,"microtick advances clock");check(boundary_enemy.clock>before_micro,"microtick not discarded");boundary_enemy.telegraph_left=.0000005;boundary_enemy.tick(.000001,g);check(boundary_enemy.state=="attack","submicro boundary transitions phase");commit(boundary_enemy)
 close(boundary_enemy.next_boundary(),1.0,"boundary exposes remaining windup");boundary_enemy.tick(1.0,g);close(boundary_enemy.next_boundary(),.147,"boundary exposes active impact");boundary_enemy.tick(.15,g);check(boundary_enemy.next_boundary()>.2,"boundary advances beyond impact");g.debug_range=true;boundary_enemy.tick(.01,g);check(boundary_enemy.attack_visual.get_children()[0].is_visible_in_tree(),"debug guides actually visible in tree");g.debug_range=false
 clear();var awake=spawn("fisherman");g.player.position=Vector3(9,0,0);awake.tick(.1,g);check(not awake.engaged,"sniped actor initially outside detection");awake.receive_damage(1,Vector3.ZERO);check(awake.engaged,"nonlethal distant damage wakes enemy");awake.receive_parry();var parry_stagger: float=awake.stagger;awake.tick(.1,g);check(awake.state=="parried" and awake.stagger<parry_stagger and awake.stagger>.8,"damage wake preserves subsequent parry timer")
 clear();var nohp=spawn("fisherman");g.health=0;g.player.position=Vector3(1,0,0);nohp.tick(.7,g);check(nohp.state=="windup" and not nohp.attack_data.parryable,"HPzero bodylab keeps AI attacking with red tell");check(nohp.attack_visual.cue.is_visible_in_tree(),"HPzero red cue actually visible in tree")
 clear();var dog=spawn("brinehound");g.player.position=Vector3(.9,0,0);commit(dog);dog.tick(.8,g);close(dog.position.x,0,"snarl stationary");dog.tick(.7,g);close(dog.bar.position.y,1.5,"dog bar above profileheight");close(dog.nameplate.position.y,1.75,"dog label above profileheight");check(dog.position.x>0 and dog.position.x<=.6501,"bounded active lunge x="+str(dog.position.x))
 clear();var spit=spawn("spitter");g.player.position=Vector3(5,0,0);commit(spit,1);spit.tick(1.5,g);check(g.shots.size()==3,"fan three projectiles once");check(g.shots[0].direction.z<0 and g.shots[2].direction.z>0,"fan diverges into three lanes");g.debug_range=true;spit.tick(.01,g);check(spit.fan_guides.size()==2 and spit.fan_guides[0].get_children()[0].is_visible_in_tree() and spit.fan_guides[1].get_children()[0].is_visible_in_tree(),"fan three actual visible diagnostic lanes");check(not spit.fan_guides[0].cue.is_visible_in_tree(),"fan no duplicate floating cue");g.debug_range=false;spit.tick(.01,g);check(not spit.fan_guides[0].get_children()[0].is_visible_in_tree(),"fan guides hidden outside diagnostics")
 clear();var fish=spawn("fisherman");g.player.position=Vector3(1,0,0);commit(fish);g.parry=true;fish.tick(1.4,g);check(fish.state=="parried" and g.health==100,"actual owner parry cancels active")
 clear();fish=spawn("fisherman");g.player.position=Vector3(1,0,0);commit(fish);g.dodge=true;fish.tick(1.4,g);check(g.health==100 and g.evades>0,"contact delegates dodge and reward")
 clear();fish=spawn("fisherman");g.player.position=Vector3(20,0,0);fish.tick(.2,g);check(fish.state=="idle" and not fish.engaged,"distant enemies idle")
 fish.position=Vector3(16,0,0);fish.engaged=true;fish.tick(.2,g);check(fish.returning and not fish.engaged and fish.position.x<16,"leash returns toward home")
 clear();fish=spawn("fisherman");g.player.position=Vector3(1,0,0)
 var wall:=StaticBody3D.new();wall.collision_layer=1
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.1,2,4);shape.shape=box;wall.add_child(shape);wall.position=Vector3(.45,.9,0);g.add_child(wall)
 await physics_frame;await physics_frame
 fish.tick(.1,g);check(not fish.engaged,"wall blocks activation LOS")
 commit(fish);fish.tick(1.5,g);check(g.hits.is_empty(),"wall blocks melee contact")
 clear();dog=spawn("brinehound");g.player.position=Vector3(.9,0,0);commit(dog);dog.tick(1.4,g);check(dog.position.x<.17,"swept lunge cannot tunnel wall")
 wall.free();clear();g.free()
 await actual_game_checks()
 print("COASTAL COMBAT: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)



var actual
func right(on: bool) -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=on;root.push_input(event,true)
func real_advance(duration: float) -> void:
 var left:=duration
 while left>.000001:
  var dt:=minf(left,1.0/120);actual.tick(dt);left-=dt
func real_fresh(kind: String,distance: float=1.0,index: int=0):
 right(false);actual.loadout.defaults();actual.loadout_edited();actual.start_run(true);actual.clear_actors()
 actual.test_aim=Vector3.RIGHT;actual.move_input=Vector2.ZERO
 var e=Enemy.new();e.kind=kind;e.position=actual.player.position+Vector3.RIGHT*distance;actual.add_child(e);actual.enemies.append(e)
 commit(e,index);e.attack_angle=PI;e.target_point=actual.player.global_position
 return e
func actual_game_checks() -> void:
 actual=load("res://scenes/game.tscn").instantiate()
 # Disable persistence before _ready; resource duplication is owned by Game.
 actual.loadout.save_path="";root.add_child(actual);actual.set_physics_process(false)
 var fish=real_fresh("fisherman");real_advance(1.10);right(true);real_advance(.13)
 check(actual.readiness.parries==1 and actual.health==100 and fish.state=="parried","Game late melee parry uses live attacker")
 fish=real_fresh("fisherman");right(true);real_advance(1.17)
 check(actual.health<100 and actual.health>86 and actual.readiness.parries==0,"Game early held press becomes guard at impact hp="+str(actual.health)+" stamina="+str(actual.stamina)+" parries="+str(actual.readiness.parries))
 fish=real_fresh("fisherman");real_advance(1.1);check(actual.request_dodge(Vector3.FORWARD),"Game coastal dodge accepted");real_advance(.25)
 check(actual.health==100 and actual.rewards.refunded,"Game coastal precise dodge reward at contact")
 fish=real_fresh("fisherman");real_advance(1.4);close(actual.health,86,"Game ordinary contact HP damage")
 check(actual.anatomy.integrity.right_upper_arm<100,"Game ordinary contact injures selected player arm")
 var before: float=actual.health;real_advance(.4);close(actual.health,before,"Game ordinary active damages once")
 var hauler=real_fresh("net_hauler");real_advance(1.42);right(true);real_advance(.2)
 check(actual.health<100 and actual.health>76 and actual.readiness.parries==0,"Game red hauler guard works without parry")
 check(hauler.state!="parried","red overhead cannot stagger by parry")
 for kind in ["harpooner","spitter"]:
  var shooter=real_fresh(kind,4)
  real_advance(float(shooter.attack_data.windup)+float(shooter.attack_data.active)*.35+.045)
  check(actual.projectiles.size()==1,kind+" Game release emits once")
  check(actual.health==100,kind+" Game projectile has travel time")
  var waited:=0.0
  while not actual.projectiles.is_empty() and actual.projectiles[0].node.position.distance_to(actual.player.position+Vector3.UP*.6)>1.0 and waited<1:
   real_advance(1.0/120);waited+=1.0/120
  right(true);real_advance(.22)
  check(actual.health==100 and actual.readiness.parries==1 and shooter.state=="parried",kind+" Game late projectile parry owner reaction")
  check(actual.projectiles.is_empty(),kind+" Game parry consumes projectile")
 var fan=real_fresh("spitter",4,1);real_advance(float(fan.attack_data.windup)+.22)
 check(actual.projectiles.size()==3,"Game fan release has exactly three globs")
 real_advance(.2);check(actual.projectiles.size()==3,"Game fan does not repeat during remaining active")
 fish=real_fresh("fisherman");real_advance(.5);var frozen: float=fish.telegraph_left;var position_before: Vector3=fish.position
 actual.toggle_pause();real_advance(.5);close(fish.telegraph_left,frozen,"Game pause freezes coastal attack");check(fish.position==position_before,"Game pause freezes coastal position")
 actual.toggle_pause();actual.queue_free();await process_frame








