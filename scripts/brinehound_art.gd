extends RefCounted
const Facing=preload("res://scripts/fisherman_art.gd")
const SHEETS:={
	"left":[preload("res://assets/brinehound/left-run-sheet-128.png"),preload("res://assets/brinehound/left-attack-sheet-128.png")],
	"front":[preload("res://assets/brinehound/front-run-sheet-128.png"),preload("res://assets/brinehound/front-attack-sheet-128.png")],
	"back":[preload("res://assets/brinehound/back-run-sheet-128.png"),preload("res://assets/brinehound/back-attack-sheet-128.png")],
	"right":[preload("res://assets/brinehound/right-run-sheet-128.png"),preload("res://assets/brinehound/right-attack-sheet-128.png")]
}
static var _frames: SpriteFrames
static func direction(vector: Vector3,camera: Camera3D) -> String:return Facing.direction(vector,camera)
static func frames() -> SpriteFrames:
	if _frames!=null:return _frames
	_frames=SpriteFrames.new();_frames.remove_animation("default")
	for view: String in SHEETS:
		for phase_: String in ["idle","run","sequence","hit","death"]:
			var name_:=view+"_"+phase_
			_frames.add_animation(name_);_frames.set_animation_loop(name_,phase_ in ["idle","run"])
			_frames.set_animation_speed(name_,1.0/.09)
			var indices: Array=[0,1,2,3,4,5] if phase_ in ["run","sequence"] else [5]
			for i: int in indices:
				var image: Image=SHEETS[view][0 if phase_=="run" else 1].get_image().get_region(Rect2i(i*128,0,128,128))
				_frames.add_frame(name_,ImageTexture.create_from_image(image))
	return _frames
