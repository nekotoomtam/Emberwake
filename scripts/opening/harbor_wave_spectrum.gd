extends RefCounted
## Deterministic multi-directional sea state; dominant energy travels toward -X.
const MEAN: float=-.85
const LIMIT: float=1.10
const WAVES: Array=[
 [-0.991655617,0.128915230,0.289547710,0.250000000,1.205985664,0.310000000],
 [-0.955157326,-0.296098771,0.439383588,0.180000000,1.640518357,2.140000000],
 [-0.865031189,0.501718090,0.690459924,0.115000000,2.046640165,4.920000000],
 [-0.992876838,-0.119145221,0.997331001,0.075000000,2.607130833,1.180000000],
 [-0.921982106,0.387232484,1.495996502,0.045000000,3.324436670,5.670000000],
 [-0.716994919,-0.697078393,2.243994753,0.025000000,4.106657064,3.830000000],
 [-0.998752339,0.049937617,0.200740745,0.120000000,0.971126013,5.130000000],
 [-0.901523057,-0.432731068,0.541653906,0.065000000,1.810716227,1.910000000],
]
static func shelter(p: Vector2) -> float:
 var land: float=maxf(p.x+19.55,p.y-17.5)
 var d:=Vector2(absf(p.x-1.225)-20.775,absf(p.y-8.75)-6.65)
 var quay: float=Vector2(maxf(d.x,0),maxf(d.y,0)).length()+minf(maxf(d.x,d.y),0)
 var pier_z:=INF
 for z in [-29.0,-72.0,-110.0,-148.0,-186.0]:pier_z=minf(pier_z,absf(p.y-z))
 var pier: float=maxf(absf(p.x-1.65)-21.35,pier_z-4.2)
 var distance_: float=minf(land,minf(quay,pier))
 return lerpf(.45,1.0,smoothstep(2.0,20.0,distance_))
static func height(p: Vector2,time: float) -> float:
 var value:=0.0
 for row in WAVES:
  var direction:=Vector2(row[0],row[1]);var along: float=p.dot(direction)
  var across: float=p.dot(Vector2(-direction.y,direction.x))
  var phase: float=along*row[2]-time*row[4]+row[5]
  var group: float=.68+.32*sin(across*.113+along*.027-time*.173+row[5]*2.13)
  value+=row[3]*group*(sin(phase)+.23*sin(phase*2.0))
 var factor:=shelter(p);value*=factor
 if value>0:
  var crest: float=.23*(1.0-exp(-value/.23))
  value=lerpf(crest,value,(factor-.45)/.55)
 return MEAN+value
