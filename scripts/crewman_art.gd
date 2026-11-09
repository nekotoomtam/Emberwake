extends RefCounted
const Facing=preload("res://scripts/fisherman_art.gd")
const WINDUP:=1.2
const ACTIVE:=.25
const RECOVERY:=2.8
const WALK_FRAME:=.20
const SHEETS:={
	"left":[preload("res://assets/crewman/left-walk-sheet-128.png"),preload("res://assets/crewman/left-attack-sheet-128.png"),preload("res://assets/crewman/left-idle-128.png")],
	"front":[preload("res://assets/crewman/front-walk-sheet-128.png"),preload("res://assets/crewman/front-attack-sheet-128.png"),preload("res://assets/crewman/front-idle-128.png")],
	"back":[preload("res://assets/crewman/back-walk-sheet-128.png"),preload("res://assets/crewman/back-attack-sheet-128.png"),preload("res://assets/crewman/back-idle-128.png")],
	"right":[preload("res://assets/crewman/right-walk-sheet-128.png"),preload("res://assets/crewman/right-attack-sheet-128.png"),preload("res://assets/crewman/right-idle-128.png")]
}
static var _frames: SpriteFrames
static var _projectile: Texture2D
static func frames() -> SpriteFrames:
	if _frames!=null:return _frames
	_frames=SpriteFrames.new();_frames.remove_animation("default")
	for view: String in SHEETS:
		for phase: String in ["idle","walk","windup","attack","recover","hit","death"]:
			var name_:=view+"_"+phase;_frames.add_animation(name_)
			_frames.set_animation_loop(name_,phase in ["idle","walk"]);_frames.set_animation_speed(name_,1.0/WALK_FRAME)
			var indices: Array={"idle":[0],"walk":[0,1,2,3,4,5],"windup":[0,1,2],"attack":[3],"recover":[4,5],"hit":[0],"death":[0]}[phase]
			for index: int in indices:
				var still: bool=phase in ["idle","hit","death"]
				var source: Image=SHEETS[view][2 if still else 0 if phase=="walk" else 1].get_image()
				var region:=source if still else source.get_region(Rect2i(index*128,0,128,128))
				_frames.add_frame(name_,ImageTexture.create_from_image(region))
	return _frames
static func direction(vector: Vector3,camera: Camera3D) -> String:return Facing.direction(vector,camera)
static func phase_frame(phase: String,remaining: float) -> int:
	if phase=="windup":return 0 if remaining>.90 else 1 if remaining>.50 else 2
	if phase=="recover":return 0 if remaining>1.25 else 1
	return 0
static func hand_pixel(view: String) -> Vector2:
	return {"left":Vector2(9,37),"right":Vector2(116,40),"front":Vector2(48,42),"back":Vector2(108,33)}.get(view,Vector2(64,48))
static func projectile() -> Texture2D:
	if _projectile!=null:return _projectile
	var im:=Image.create(64,16,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
	im.fill_rect(Rect2i(3,7,49,3),Color("69472e"));im.fill_rect(Rect2i(4,7,47,1),Color("b3925e"))
	for x in range(48,61):
		var half: int=maxi(1,(61-x)/3)
		im.fill_rect(Rect2i(x,8-half,1,half*2+1),Color("a2afa6"))
	im.fill_rect(Rect2i(48,4,3,3),Color("596c68"));im.fill_rect(Rect2i(48,10,3,3),Color("596c68"))
	for x in range(43,48,2):im.fill_rect(Rect2i(x,6,1,5),Color("c2b085"))
	im.fill_rect(Rect2i(1,8,4,1),Color("b6a77b"));_projectile=ImageTexture.create_from_image(im);return _projectile
