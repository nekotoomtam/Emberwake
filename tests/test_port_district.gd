extends SceneTree
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var port=g.world.backdrop.get("district")
 check(port!=null,"city has an authored port district")
 if port!=null:
  check(port.berths.size()==5,"five additional working piers")
  check(port.boats.size()>=6,"varied moored fleet")
  check(g.world.backdrop.coast_length>=220,"expanded city shoreline")
  check(port.couriers.size()>=3,"ship-to-shore transfer workers")
  check(port.workers.size()>=10,"background has people at original human scale")
  var kinds: Dictionary={};var before: Array=[];var identity: Array=[]
  for berth in port.berths:
   kinds[berth.kind]=true
   check(berth.width>=3.2 and berth.length>=10,"human-sized pier "+berth.kind)
   check(berth.path_clearance>=1.4,"usable center cargo lane "+berth.kind)
   check(berth.end.x<=24,"eastern ocean remains open "+berth.kind)
  check(kinds.size()==5,"five distinct pier purposes")
  for i in port.berths.size():
   for j in range(i+1,port.berths.size()):
    check(absf(port.berths[i].start.z-port.berths[j].start.z)>=30,"navigable water spacing %d %d"%[i,j])
  for worker in port.workers:
   check(is_equal_approx(worker.sprite.pixel_size,.018),"same human pixel scale "+worker.name)
   before.append(worker.position);identity.append(worker.profile.duplicate(true))
  for i in 300:g.tick(1.0/60)
  var moved:=0
  for i in port.workers.size():
   if port.workers[i].position.distance_to(before[i])>.2:moved+=1
   check(port.workers[i].profile==identity[i],"worker identity remains stable "+port.workers[i].name)
  check(moved>=5,"working port has actual moving porters")
  check(g.world.townspeople.size()==8 and g.world.crew.size()==4 and g.world.pigeons.size()==6,"original foreground cast retained")
 g.free();await process_frame
 print("PORT DISTRICT ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
