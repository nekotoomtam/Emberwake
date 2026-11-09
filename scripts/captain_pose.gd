extends RefCounted
const Rules=preload("res://scripts/captain_rules.gd")
static func sample(data: Dictionary,state: String,left: float,elapsed: float,cooldown: float,angle: float) -> Dictionary:
 var forward:=Vector3(cos(angle),0,sin(angle));var rest:=forward*.75
 var result:={"animation":"hit" if state=="parried" else "idle","frame":0,"tip":rest,"lift":0.0,"slack":.42,"whip":.0,"roll":.0,"progress":.0,"held":false,"grip":0.0,"beat":"rest"}
 if data.is_empty():return result
 var id: String=data.id
 if state=="windup":
  var p:=clampf(1-left/float(data.windup),0,1);result.animation=id+"_windup";result.frame=mini(4,int(p*5));result.progress=p
  result.slack=lerpf(.48,.025,smoothstep(.15,.9,p));result.whip=.12*sin(PI*p)
  if id=="sweep":
   var start:=Rules.tip(data,angle,0)
   result.tip=rest.lerp(start*.78,smoothstep(0,.55,p)) if p<.55 else start*.78+start*.22*smoothstep(.55,.9,p)
   result.roll=-.55*sin(PI*p)
  elif id=="throw":
   result.grip=smoothstep(0,.35,p);result.tip=rest.lerp(Vector3(data.launch),result.grip);result.lift=float(data.launch_lift)*result.grip;result.held=true;result.slack=.15;result.whip=.025;result.roll=0.0;result.beat="load"
  else:
   result.tip=rest.lerp(forward*.35,smoothstep(0,.7,p));result.lift=2.7*smoothstep(0,.8,p);result.slack=.18;result.roll=-.25*p
 elif state=="attack":
  var p:=clampf(elapsed/float(data.active),0,1);result.animation=id+"_active";result.frame=mini(2 if id=="slam" else 3,int(p*(3 if id=="slam" else 4)));result.progress=p
  result.tip=Rules.tip(data,angle,elapsed);result.slack=.025;result.whip=.08*sin(PI*p);result.roll=.65*p;result.beat="strike"
  if id=="throw":
   result.lift=Rules.visual_lift(data,elapsed);result.roll=0.0
   if elapsed<data.release:
    result.frame=mini(3,int(elapsed/float(data.release)*4));result.held=true;result.grip=1.0;result.beat="cast";result.slack=.10
   elif elapsed<data.return_start:
    result.frame=3;result.beat="outbound" if elapsed<data.out_end else "turn"
    if elapsed<data.out_end:result.roll=.6*sin(PI*(elapsed-float(data.release))/float(data.out_end-data.release))
   elif elapsed<data.catch_time:
    var reel: float=(elapsed-float(data.return_start))/float(data.catch_time-data.return_start)
    result.animation="throw_reel";result.frame=mini(5,int(reel*6));result.roll=-.4*sin(PI*reel);result.beat="reel"
   else:result.animation="throw_reel";result.frame=5;result.held=true;result.grip=1.0;result.slack=.12;result.beat="catch"
  if id=="slam":
   result.roll=lerpf(-.25,.65,p)
   result.frame=mini(2,floori(minf(1,p/float(data.impact))*2+.000001))
   if not Rules.damaging(data,elapsed):
    var drop:=smoothstep(0,float(data.impact),p);result.tip=(forward*.35).lerp(Rules.tip(data,angle,elapsed),drop);result.lift=2.7*(1-drop)
 elif state=="recover":
  var p:=clampf(1-cooldown/float(data.recovery),0,1);var settle:=smoothstep(0,.85,p)
  result.animation=id+"_recover";result.frame=mini(5,int(p*6));result.progress=p;result.beat="recover"
  result.tip=Rules.tip(data,angle,data.active).lerp(rest,settle);result.lift=Rules.visual_lift(data,data.active)*(1-settle)
  result.roll=(0.0 if id=="throw" else .65)*(1-settle);result.slack=lerpf(.025,.42,p);result.whip=.08*(1-p)
 return result
