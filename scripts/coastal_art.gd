extends RefCounted
## Original 64-grid pixel clusters enlarged to128; faces right, feet112.
## Body collision concerns torso only. Weapons and hanging nets are decoration.
const INK := Color("16252b")
const SKIN := Color("839e91")
const PALE := Color("bec9af")
const STEEL := Color("9eafb0")
const RUST := Color("9c7656")
const ROPE := Color("b3a17a")
static var _cache: Dictionary = {}
static var _projectiles: Dictionary = {}
static func profile(kind: String) -> Dictionary:
	var names := {"fisherman":"ชาวประมงจมน้ำ","brinehound":"หมาล่าเนื้อน้ำเค็ม","net_hauler":"คนลากอวน","harpooner":"มือปืนฉมวก","spitter":"ผู้พ่นน้ำเกลือ"}
	return {"pixel_size":.025,"body_radius":.34 if kind == "brinehound" else .34,"body_height":1.35 if kind == "brinehound" else (2.20 if kind == "net_hauler" else 2.10),"foot_pixel":112,"name":names.get(kind,kind)}
## Texture pixel coordinates at active frame1; controller mirrors X for flip_h.
static func muzzle_pixel(kind: String, variant: bool = false) -> Vector2:
	if kind == "harpooner":
		return Vector2(120,50 if variant else 56)
	if kind == "spitter":
		return Vector2(86,44)
	return Vector2(64,64)
static func frames(kind: String) -> SpriteFrames:
	if _cache.has(kind):
		return _cache[kind]
	var out := SpriteFrames.new()
	out.remove_animation("default")
	for a: String in {"idle":2,"walk":4,"windup":4,"attack":3,"recover":3,"hit":2,"death":3,"windup_alt":4,"attack_alt":3,"recover_alt":3}:
		out.add_animation(a)
		out.set_animation_loop(a,a in ["idle","walk"])
		out.set_animation_speed(a,6.0)
		var count: int = {"idle":2,"walk":4,"windup":4,"attack":3,"recover":3,"hit":2,"death":3,"windup_alt":4,"attack_alt":3,"recover_alt":3}[a]
		for i in count:
			var im := _figure(kind,a,i)
			im.resize(128,128,Image.INTERPOLATE_NEAREST)
			out.add_frame(a,ImageTexture.create_from_image(im))
	_cache[kind] = out
	return out
static func _rect(im: Image,x: int,y: int,w: int,h: int,c: Color) -> void:
	im.fill_rect(Rect2i(x,y,w,h).intersection(Rect2i(0,0,64,56)),c)
static func _line(im: Image,a: Vector2,b: Vector2,c: Color,width: int = 1) -> void:
	var steps := maxi(1,ceili(a.distance_to(b)))
	for i in steps+1:
		var p := a.lerp(b,float(i)/steps)
		_rect(im,roundi(p.x)-width/2,roundi(p.y)-width/2,width,width,c)
static func _poly(im: Image,points: Array,c: Color) -> void:
	var pp := PackedVector2Array(points)
	for y in 56:
		for x in 64:
			if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),pp):
				im.set_pixel(x,y,c)
static func _figure(kind: String,anim: String,i: int) -> Image:
	var im := Image.create(64,64,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	var alt := anim.ends_with("_alt")
	var phase := anim.trim_suffix("_alt")
	var load_t := float(i)/3 if phase == "windup" else (1.0-float(i)/2 if phase == "recover" else 0.0)
	var attack := phase == "attack"
	var bob := -i if phase == "idle" else (-1 if phase == "walk" and i%2 else 0)
	var stride: int = [0,3,0,-3][i%4] if phase == "walk" else 0
	var dx: int = roundi(-3*load_t) + ([2,5,3][i] if attack else 0)
	if phase == "hit":
		dx = -4+i*2
		bob = i+1
	if phase == "death":
		# A three-stage collapse keeps all pixels above the same ground baseline.
		var fallen := _figure(kind,"hit",0)
		var height: int = [40,24,12][i]
		fallen.resize(54,height,Image.INTERPOLATE_NEAREST)
		im.blit_rect(fallen,Rect2i(0,0,54,height),Vector2i(5,56-height))
		return im
	if kind == "brinehound":
		_dog(im,phase,i,dx,bob,stride,load_t,attack)
		return im
	var cx: int = 32+dx
	var top := (12 if kind == "net_hauler" else 14)+bob
	var coat := Color("4c5d62")
	if kind == "net_hauler": coat = Color("535c49")
	if kind == "harpooner": coat = Color("374957")
	if kind == "spitter": coat = Color("426c5d")
	# Narrow boots and long asymmetric ragged coat; torso never exceeds24 texture px.
	_line(im,Vector2(cx-3,40+bob),Vector2(29-stride,54),INK,5)
	_line(im,Vector2(cx+3,40+bob),Vector2(35+stride,54),INK,5)
	_rect(im,26-stride,54,6,2,INK)
	_rect(im,33+stride,54,6,2,INK)
	_poly(im,[Vector2(cx-5,top+10),Vector2(cx+5,top+11),Vector2(cx+6,44+bob),Vector2(cx+2,47+bob),Vector2(cx,43+bob),Vector2(cx-5,46+bob),Vector2(cx-6,40+bob)],INK)
	_poly(im,[Vector2(cx-4,top+11),Vector2(cx+3,top+12),Vector2(cx+4,43+bob),Vector2(cx+1,42+bob),Vector2(cx-3,44+bob)],coat)
	_line(im,Vector2(cx,top+15),Vector2(cx-1,42+bob),coat.lightened(.18),1)
	_rect(im,cx-3,top,7,10,INK)
	_rect(im,cx-2,top+2,5,7,SKIN)
	_rect(im,cx+3,top+4,2,3,SKIN)
	_rect(im,cx+2,top+3,1,1,Color("d6d7a8"))
	_rect(im,cx+1,top+7,3,1,INK)
	# Victorian collar, waist belt, three coat buttons.
	_line(im,Vector2(cx-3,top+10),Vector2(cx+1,top+14),PALE)
	_line(im,Vector2(cx+3,top+10),Vector2(cx+1,top+14),PALE)
	_rect(im,cx-4,37+bob,8,2,RUST)
	for yy in [29,32,35]: _rect(im,cx+1,yy+bob,1,1,ROPE)
	if kind in ["fisherman","harpooner"]:
		_rect(im,cx-4,top-1,8,3,coat.darkened(.25))
		_rect(im,cx-5,top+2,11,2,INK)
	if kind == "fisherman":
		var wrist := Vector2(cx+9-12*load_t,35-10*load_t+bob)
		if attack: wrist = Vector2(cx+[8,13,11][i],(29 if alt else [23,34,40][i])+bob)
		_arm(im,Vector2(cx+4,top+13),wrist,coat)
		_arm(im,Vector2(cx-4,top+13),Vector2(cx-8,39+bob),coat)
		var tip := wrist + (Vector2(8,0) if alt and attack else Vector2(3,-12))
		_line(im,wrist,tip,RUST,2)
		_line(im,tip,tip+Vector2(4,2),STEEL,2)
		_line(im,tip+Vector2(4,2),tip+Vector2(3,6),STEEL,2)
		_line(im,tip+Vector2(3,6),tip+Vector2(1,5),STEEL)
	elif kind == "net_hauler":
		var wrist := Vector2(cx+9,31-18*load_t)
		if attack: wrist = Vector2(cx+13,[22,36,43][i] if not alt else 31+i*3)
		_arm(im,Vector2(cx+4,top+13),wrist,coat)
		var tip := wrist + Vector2(5,-17) if not attack else wrist + Vector2(9,-6 if alt else 4)
		_line(im,wrist-Vector2(5,-9),tip,RUST,2)
		_line(im,tip,tip+Vector2(-5,4),STEEL,2)
		# Slender dangling rope-net sack, distinct open diamond lattice.
		var netx: int = cx-11
		_line(im,Vector2(cx-4,top+13),Vector2(netx,35),ROPE,2)
		for row in 4:
			var yy := 34+row*4
			_line(im,Vector2(netx-4,yy),Vector2(netx+3,yy+5),ROPE)
			_line(im,Vector2(netx+3,yy),Vector2(netx-4,yy+5),ROPE)
		_line(im,Vector2(netx-4,34),Vector2(netx-3,51),INK)
	elif kind == "harpooner":
		var aim_y := 37-roundi(load_t*10)
		if attack: aim_y = 27+([0,1,2][i])
		if phase == "recover": aim_y = 31+i*3
		_arm(im,Vector2(cx+4,top+13),Vector2(cx+12,aim_y+1),coat)
		_arm(im,Vector2(cx-4,top+14),Vector2(cx+3,aim_y+3),coat)
		_line(im,Vector2(cx-3,aim_y+2),Vector2(cx+8,aim_y),RUST,3)
		_line(im,Vector2(cx+6,aim_y),Vector2(cx+23,aim_y-(3 if alt else 0)),STEEL,2)
		_rect(im,cx+5,aim_y-3,4,2,INK)
		if attack and i == 1:
			_poly(im,[Vector2(cx+24,aim_y),Vector2(cx+25,aim_y-4),Vector2(cx+24,aim_y),Vector2(cx+25,aim_y+3)],Color("dfc995"))
		if phase == "recover": _line(im,Vector2(cx+5,aim_y+4),Vector2(cx+9,aim_y+9-i*2),ROPE,2)
	elif kind == "spitter":
		# Exposed ribs, seaweed strips and a visibly inflating throat; no coat hat.
		for yy in [29,33,37]: _line(im,Vector2(cx-3,yy+bob),Vector2(cx+3,yy+1+bob),SKIN)
		for side in [-1,1]:
			_arm(im,Vector2(cx+side*4,top+13),Vector2(cx+side*9,43+bob),SKIN)
			_line(im,Vector2(cx+side*4,top+1),Vector2(cx+side*7,top+18),Color("2d5542"),2)
		var bulge := roundi(load_t*4)
		_rect(im,cx+2,top+7,3+bulge,4+bulge,INK)
		_rect(im,cx+3,top+8,1+bulge,2+bulge,Color("a3b780"))
		if attack:
			_rect(im,cx+3,top+5,5,5,INK)
			_line(im,Vector2(cx+6,top+8),Vector2(cx+11+i*2,top+7-(i*2 if alt else 0)),Color("a7c9a0"),2)
	return im
static func _arm(im: Image,shoulder: Vector2,wrist: Vector2,coat: Color) -> void:
	var elbow := shoulder.lerp(wrist,.5)+Vector2(-2,3)
	_line(im,shoulder,elbow,INK,4)
	_line(im,elbow,wrist,INK,4)
	_line(im,shoulder,elbow,coat,2)
	_line(im,elbow,wrist,coat,2)
	_rect(im,int(wrist.x)-1,int(wrist.y)-1,3,3,SKIN)
static func _dog(im: Image,phase: String,i: int,dx: int,bob: int,stride: int,t: float,attack: bool) -> void:
	var yy := 39+bob+roundi(t*3)
	# Long narrow back and tucked belly, four separated hock legs.
	_poly(im,[Vector2(16+dx,yy),Vector2(36+dx,yy-3),Vector2(44+dx,yy+1),Vector2(40+dx,yy+10),Vector2(32+dx,yy+8),Vector2(23+dx,yy+5),Vector2(17+dx,yy+10)],INK)
	_poly(im,[Vector2(18+dx,yy+1),Vector2(36+dx,yy-1),Vector2(41+dx,yy+2),Vector2(38+dx,yy+7),Vector2(25+dx,yy+3)],Color("566d64"))
	for leg in 4:
		var xx: int = [19,24,35,40][leg]+dx
		var footx: int = xx+stride*(1 if leg%2 else -1)
		_line(im,Vector2(xx,yy+6),Vector2(footx-2,51),INK,2)
		_line(im,Vector2(footx-2,51),Vector2(footx,55),SKIN,2)
		_rect(im,footx-1,55,4,1,INK)
	_line(im,Vector2(18+dx,yy+2),Vector2(9+dx,yy-6-i%2),INK,3)
	var headx := 41+dx+roundi(t*-3)
	var heady := yy-7-roundi(t*2)
	_poly(im,[Vector2(headx-5,heady+3),Vector2(headx-3,heady-8),Vector2(headx+1,heady-3),Vector2(headx+4,heady-5),Vector2(headx+6,heady+3),Vector2(headx+12,heady+4),Vector2(headx+11,heady+10),Vector2(headx,heady+11)],INK)
	_rect(im,headx-1,heady,7,7,Color("74897a"))
	_rect(im,headx+5,heady+5,7,3,SKIN)
	_rect(im,headx+4,heady+2,2,1,Color("d4d1a0"))
	_rect(im,headx+7,heady+8,5,2+roundi(t*3)+(2 if attack else 0),INK)
	if t > .2 or attack:
		for tooth in 3: _rect(im,headx+7+tooth*2,heady+8,1,2,PALE)
	for xx in [20,25,30,35]: _line(im,Vector2(xx+dx,yy),Vector2(xx+dx-2,yy+5),Color("79917b"))
static func projectile(kind: String) -> Texture2D:
	if _projectiles.has(kind): return _projectiles[kind]
	var im := Image.create(32 if kind == "harpooner" else 16,16,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	if kind == "harpooner":
		_rect(im,3,7,25,2,RUST)
		_line(im,Vector2(23,4),Vector2(30,7),STEEL,2)
		_line(im,Vector2(30,7),Vector2(23,11),STEEL,2)
		_line(im,Vector2(3,7),Vector2(0,4),ROPE,2)
		_line(im,Vector2(3,8),Vector2(0,11),ROPE,2)
	else:
		for yy in 16:
			for xx in 16:
				if Vector2(xx-8,yy-8).length() < 5:
					im.set_pixel(xx,yy,Color("79a58d") if xx+yy > 13 else Color("bed2ab"))
		_rect(im,1,6,3,2,Color("507e70"))
	_projectiles[kind] = ImageTexture.create_from_image(im)
	return _projectiles[kind]




