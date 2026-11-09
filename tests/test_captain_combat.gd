extends SceneTree
var g
var count:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 count+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func close(a: float,b: float,label: String) -> void:check(absf(a-b)<.001,label+" got="+str(a))
func equip(id: String,hand: String) -> void:
 var index: int=g.loadout.bag.find(id)
 var src: Dictionary={"kind":"bag","index":index}
 if index<0:
  for i in range(2):
   for h in ["main","off"]:
    if g.loadout.sets[i][h]==id:src={"kind":"slot","set":i,"hand":h}
 var dst:={"kind":"slot","set":0,"hand":hand}
 if src!=dst:check(g.loadout.move_item(src,dst),"equip fixture")
func fresh(main: String,off: String="") -> void:
 g.loadout.defaults();g.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 g.loadout_edited();g.start_run(true);g.test_aim=Vector3.RIGHT;g.move_input=Vector2.ZERO;g.stats.base.critical_chance=0
 for e in g.enemies:e.position=Vector3(100,0,100)
func advance(t: float) -> void:
 while t>.0000001:
  var dt: float=minf(t,1.0/120);g.tick(dt);t-=dt
func right(on: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=on;root.push_input(e,true)
func attack(id: String,point: Vector3) -> void:
 right(false);g.start_captain();g.test_aim=Vector3.LEFT;g.move_input=Vector2.ZERO
 var e=g.enemies[0];e.position=Vector3(0,.03,0);g.player.position=point;e.attack_data=e.Rules.definition(id);e.attack_angle=0;e.state="windup";e.telegraph_left=e.attack_data.windup;e.cooldown=0;e.attack_hit=false;e.elapsed=0
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path="";fresh("sword0")
 attack("sweep",Vector3(1.9,.03,0));advance(1);close(g.health,100,"windup no instantdamage");advance(.42);close(g.health,82,"sweep actualcontact once");advance(.2);close(g.health,82,"sweep no repeated damage")
 attack("sweep",Vector3(1.0,.03,0));advance(1.6);close(g.health,100,"sweep inner gap safe")
 var outer: Dictionary=g.enemies[0].Rules.definition("sweep");attack("sweep",Vector3(float(outer.reach)+float(outer.radius)+.08,.03,0));advance(1.6);close(g.health,100,"beyond current anchor reach misses")
 attack("throw",Vector3(3,.03,0));advance(1.35+1.65);close(g.health,52,"throw out and back each once");check(g.enemies[0].contact_count==2,"two visible passes")
 attack("throw",Vector3(-2,.03,0));g.enemies[0].telegraph_left=.30;advance(2);close(g.health,100,"late locked lane dodge safe")
 attack("slam",Vector3(2,.03,0));advance(1.35);close(g.health,100,"airborne slam cannot damage");advance(.04);close(g.health,70,"slam damages at visible ground impact")
 attack("slam",Vector3(2,.03,0));right(true);advance(1.5);close(g.health,79,"redslam guard reduction");check(g.readiness.parries==0,"red cannot parry")
 attack("sweep",Vector3(1.9,.03,0));advance(1.14);right(true);advance(.18);close(g.health,100,"timed parry no damage");check(g.readiness.parries==1 and g.enemies[0].state=="parried","actualparry interrupts mini")
 attack("sweep",Vector3(1.9,.03,0));advance(1.16);g.request_dodge(Vector3.FORWARD);advance(.2);close(g.health,100,"dash iframe or movement evades");check(g.rewards.refunded,"precise realcontact refund")
 attack("sweep",Vector3(1.9,.03,0));advance(1.40);g.request_dodge(Vector3.FORWARD);advance(.02);check(not g.rewards.refunded,"late dodge after anchor passed no refund")
 attack("sweep",Vector3(1,.03,0));g.tick(1.05);g.tick(.46);close(g.health,100,"coarse sweep innergap safe")
 attack("throw",Vector3(3,.03,0));g.tick(1.35);g.tick(1.65);close(g.health,52,"coarse throw bothpasses same as fine")
 g.queue_free();await process_frame
 print("CAPTAIN COMBAT: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
