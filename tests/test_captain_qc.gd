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
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path="";g.start_captain();var e=g.enemies[0]
 e.attack_data=e.Rules.definition("throw");e.state="windup";e.telegraph_left=1.1;e.active_left=0;e.cooldown=0
 e.receive_damage(1,Vector3.ZERO);close(e.telegraph_left,1.1,"normalhit preserves remainingtell");advance(.001);check(e.state=="windup","normalhit no instant release")
 e.attack_data=e.Rules.definition("throw");e.state="attack";e.elapsed=.5;e.active_left=1.15;e.receive_damage(1,Vector3.ZERO);close(e.active_left,1.15,"normalhit preserves active clock")
 for mirror in [false,true]:
  g.start_captain();e=g.enemies[0];e.position=Vector3.ZERO;e.sprite.flip_h=mirror;e.attack_angle=PI if mirror else 0;e.attack_data=e.Rules.definition("throw");e.state="windup";e.telegraph_left=1.1;e.cooldown=0;g.player.position=Vector3(3 if mirror else -3,.03,0);advance(.7)
  var forward:=Vector3(cos(e.attack_angle),0,sin(e.attack_angle));check(e.sprite.flip_h==(e.view_right.dot(forward)<0),"tracked body matches committed facing "+str(mirror))
 g.queue_free();await process_frame
 print("CAPTAIN QC: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
