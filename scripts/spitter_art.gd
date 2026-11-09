extends RefCounted
const Facing=preload("res://scripts/fisherman_art.gd")
const WALK=preload("res://assets/spitter/walk.png")
const ATTACK=preload("res://assets/spitter/attack.png")
const FRONT=preload("res://assets/spitter/front.png")
const BACK=preload("res://assets/spitter/back.png")
const MOUTHS:=[Vector2(78.825,40.78),Vector2(63.12,29.3),Vector2(86.9,55.95),Vector2(91.33,65.255),Vector2(84.645,62.59),Vector2(80.11,39.655)]
static var cache: SpriteFrames
static func frames() -> SpriteFrames:
 if cache!=null:return cache
 cache=SpriteFrames.new();cache.remove_animation("default")
 for view in ["left","right","front","back"]:
  for phase in ["idle","walk","windup","attack","recover","hit","death"]:
   var name_: String=view+"_"+phase;cache.add_animation(name_);cache.set_animation_loop(name_,false)
   var indices: Array={"idle":[5],"walk":[0,1,2,3,4,5],"windup":[0,1],"attack":[2,3,4],"recover":[5],"hit":[5],"death":[5]}[phase]
   for index: int in indices:
    var image: Image
    if view in ["front","back"]:image=(FRONT if view=="front" else BACK).get_image()
    else:image=(WALK if phase=="walk" else ATTACK).get_image().get_region(Rect2i(index*128,0,128,128))
    cache.add_frame(name_,ImageTexture.create_from_image(image))
 return cache
static func direction(v: Vector3,camera: Camera3D) -> String:return Facing.direction(v,camera)
