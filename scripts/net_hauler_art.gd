extends RefCounted
const Facing=preload("res://scripts/fisherman_art.gd")
const WINDUP:=1.65
const ACTIVE:=.09
const RECOVERY:=.80
const WALK_FRAME:=.28
const ROOT_X:={"left":72,"front":56,"back":72,"right":56}
## Authored wooden head bounds in actual128 impact frame, excludes its trail.
const IMPACT_BOX:={"left":Rect2(14,93,29,26),"front":Rect2(54,101,20,20),"back":Rect2(46,94,14,20),"right":Rect2(92,101,26,19)}
const SHEETS:={
	"left":[preload("res://assets/net_hauler/left-walk-sheet-128.png"),preload("res://assets/net_hauler/left-attack-sheet-128.png")],
	"front":[preload("res://assets/net_hauler/front-walk-sheet-128.png"),preload("res://assets/net_hauler/front-attack-sheet-128.png")],
	"back":[preload("res://assets/net_hauler/back-walk-sheet-128.png"),preload("res://assets/net_hauler/back-attack-sheet-128.png")],
	"right":[preload("res://assets/net_hauler/right-walk-sheet-128.png"),preload("res://assets/net_hauler/right-attack-sheet-128.png")]
}
static var _frames: SpriteFrames
static func frames() -> SpriteFrames:
	if _frames!=null:return _frames
	_frames=SpriteFrames.new();_frames.remove_animation("default")
	for view: String in SHEETS:
		for phase: String in ["idle","walk","windup","attack","recover","hit","death"]:
			var name_:=view+"_"+phase;_frames.add_animation(name_)
			_frames.set_animation_loop(name_,phase in ["idle","walk"]);_frames.set_animation_speed(name_,1.0/WALK_FRAME)
			var indices: Array={"idle":[5],"walk":[0,1,2,3,4,5],"windup":[0,1,2],"attack":[3],"recover":[4,5],"hit":[5],"death":[5]}[phase]
			for index: int in indices:
				var image: Image=SHEETS[view][0 if phase=="walk" else 1].get_image().get_region(Rect2i(index*128,0,128,128))
				_frames.add_frame(name_,ImageTexture.create_from_image(image))
	return _frames
static func direction(vector: Vector3,camera: Camera3D) -> String:return Facing.direction(vector,camera)
static func ground_direction(view: String,camera: Camera3D) -> Vector3:return Facing.ground_direction(view,camera)
static func phase_frame(phase: String,left: float) -> int:
	if phase=="windup":return 0 if left>1.35 else 1 if left>.90 else 2
	if phase=="recover":return 0 if left>.55 else 1
	return 0
