extends RefCounted
const CaptainRules=preload("res://scripts/captain_rules.gd")
static func outline(data: Dictionary,angle: float) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	if data.is_empty():return points
	if data.get("id","") in ["sweep","slam","throw"] and data.has("radius"):return CaptainRules.outline(data,angle)
	if data.shape=="lane":
		var f:=Vector3(cos(angle),0,sin(angle));var side:=Vector3(-f.z,0,f.x);var radius: float=float(data.width)*.5
		for i in range(25):
			var a: float=-PI*.5+PI*i/24;points.append(f*float(data.reach)+(f*cos(a)+side*sin(a))*radius)
		for i in range(25):
			var a: float=PI*.5+PI*i/24;points.append((f*cos(a)+side*sin(a))*radius)
	else:
		var arc: float=float(data.arc)
		var steps:=maxi(24,ceili(arc/TAU*96))
		for i in range(steps+1):
			var a: float=angle-arc*.5+arc*i/steps;points.append(Vector3(cos(a),0,sin(a))*float(data.reach))
		if arc<TAU-.001:points.append(Vector3.ZERO)
	return points
static func progress(data: Dictionary,phase: String,remaining: float) -> float:
	if phase=="attack":return 1.0
	return clampf(1.0-remaining/maxf(.000001,float(data.get("windup",1))),0,1)
