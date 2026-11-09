extends RefCounted
## Approved pixels; no mirroring. Same six-pose timing as the accepted art study.
const SHEETS := {
	"left": [preload("res://assets/fisherman/left-walk-sheet-128.png"),preload("res://assets/fisherman/left-attack-sheet-128.png")],
	"front": [preload("res://assets/fisherman/front-walk-sheet-128.png"),preload("res://assets/fisherman/front-attack-sheet-128.png")],
	"back": [preload("res://assets/fisherman/back-walk-sheet-128.png"),preload("res://assets/fisherman/back-attack-sheet-128.png")],
	"right": [preload("res://assets/fisherman/right-walk-sheet-128.png"),preload("res://assets/fisherman/right-attack-sheet-128.png")]
}
const WINDUP := 1.6
const ACTIVE := .11
const RECOVERY := .85
const WALK_FRAME := .24
static var _frames: SpriteFrames
static func frames() -> SpriteFrames:
	if _frames != null: return _frames
	_frames=SpriteFrames.new();_frames.remove_animation("default")
	for view: String in SHEETS:
		for phase: String in ["idle","walk","windup","attack","recover","hit","death"]:
			var name_:=view+"_"+phase
			_frames.add_animation(name_);_frames.set_animation_loop(name_,phase in ["idle","walk"])
			_frames.set_animation_speed(name_,1.0/WALK_FRAME)
			var indices: Array=[0]
			if phase=="walk":indices=[0,1,2,3,4,5]
			elif phase=="windup":indices=[0,1,2]
			elif phase=="attack":indices=[3]
			elif phase=="recover":indices=[4,5]
			for index: int in indices:
				# Shader sampler uniforms ignore AtlasTexture regions; sight masks
				# need the same standalone128px alpha image as the visible frame.
				var image: Image=SHEETS[view][0 if phase=="walk" else 1].get_image().get_region(Rect2i(index*128,0,128,128))
				_frames.add_frame(name_,ImageTexture.create_from_image(image))
	return _frames
static func direction(vector: Vector3,camera: Camera3D) -> String:
	var x:=camera.global_basis.x.dot(vector)
	var up:=camera.global_basis.y.dot(vector)
	if absf(x)>=absf(up):return "right" if x>=0 else "left"
	return "back" if up>0 else "front"
static func ground_direction(view: String,camera: Camera3D) -> Vector3:
	var v:=camera.global_basis.x if view in ["left","right"] else camera.global_basis.y
	v.y=0;v=v.normalized()
	return -v if view in ["left","front"] else v
static func phase_frame(phase: String,remaining: float) -> int:
	if phase=="windup":
		var elapsed:=WINDUP-remaining
		return 0 if elapsed<.35 else 1 if elapsed<.8 else 2
	if phase=="recover":return 0 if RECOVERY-remaining<.30 else 1
	return 0
