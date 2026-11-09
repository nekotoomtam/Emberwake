extends Node3D
## Keep each original articulated pixel sleeve on its own removable node.
const Grips = preload("res://scripts/holding_grips.gd")
var anatomy = null
var primary_arm := "right_arm"
var primary
var support
var support_visible := false
var grip_count := 0
var shoulder_world := Vector3.ZERO
var wrist_world := Vector3.ZERO
var support_world := Vector3.ZERO
var draw_sprites := true
var render_priority := 2:
 set(value):
  render_priority = value
  if primary != null:primary.render_priority = value
  if support != null:support.render_priority = value

func _ready() -> void:
 primary = Grips.new();primary.name = "PrimaryArm";add_child(primary)
 support = Grips.new();support.name = "SupportArm";add_child(support)

func update_grips(camera: Camera3D,origin: Vector3,primary_point: Vector3,support_point: Vector3,use_support: bool,paired: bool,left: bool,dead: bool,anchor: Vector3=Vector3.INF,support_anchor: Vector3=Vector3.INF) -> void:
 visible = not dead
 var side := -1.0 if left else 1.0
 var shoulder := origin+Vector3.UP*.88+camera.global_basis.x*(.0 if paired else .13*side)
 if anchor.is_finite():shoulder = anchor
 var shoulder2 := origin+Vector3.UP*.88-camera.global_basis.x*.14*side
 if support_anchor.is_finite():shoulder2 = support_anchor
 shoulder_world = shoulder;wrist_world = primary_point;support_world = support_point
 var other := "left_arm" if primary_arm == "right_arm" else "right_arm"
 var primary_usable: bool=not dead and (anatomy == null or anatomy.functional(primary_arm))
 support_visible=not dead and use_support and (anatomy == null or anatomy.functional(other))
 grip_count = int(primary_usable) + int(support_visible)
 if draw_sprites:
  primary.update_grips(camera,origin,primary_point,primary_point,false,paired,left,dead,shoulder)
  support.update_grips(camera,origin,support_point,support_point,false,paired,not left,dead,shoulder2)
 primary.visible=draw_sprites and primary_usable
 support.visible=draw_sprites and support_visible
