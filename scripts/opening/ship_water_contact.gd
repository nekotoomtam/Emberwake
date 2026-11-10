extends Node3D
## Sea-level ripples follow the hull's position and heading, independently of its bob.
## Add beside the visual hull, assign hull, then call tick(delta) from its owner.
const Spectrum = preload("res://scripts/opening/harbor_wave_spectrum.gd")
const SEA_LEVEL: float = Spectrum.MEAN
const SIDE_PATCHES: int = 20
const CURVE_STEPS: int = 7
const HullSurface = preload("res://scripts/opening/ship_hull_surface.gd")
const BowWave = preload("res://scripts/opening/ship_bow_wave.gd")
const Ship = preload("res://scripts/opening/departure_ship.gd")

var hull: Node3D
var cruising: float = 0.0
var phase: float = 0.0
var phase_clock: float = 0.0
var intensity: float = .42
var water_height: float = SEA_LEVEL
var contact_count: int = 0
var side_contact_count: int = 0
var bow_contact_count: int = 0
var stern_contact_count: int = 0
var _material: ShaderMaterial
var bow_wave: Node3D
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _outward := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

func _ready() -> void:
 name = "HullWaterContact"
 top_level = true
 _build_contacts()
 bow_wave=BowWave.new();add_child(bow_wave)
 tick(0.0)

func tick(delta: float) -> void:
 phase_clock += maxf(delta, 0.0)
 var drive: float = clampf(cruising, 0.0, 1.0)
 intensity = move_toward(intensity, lerpf(.42, 1.0, drive), maxf(delta, 0.0) * 1.3)
 if is_instance_valid(hull):
  var heading: Vector3 = hull.global_basis.x
  var basis := Basis(Vector3.UP, atan2(-heading.z, heading.x)).scaled_local(Vector3(Ship.LENGTH_SCALE, 1.0, 1.0))
  global_transform = Transform3D(basis, Vector3(hull.global_position.x, SEA_LEVEL, hull.global_position.z))
 else:
  global_position.y = SEA_LEVEL
 water_height = global_position.y
 if is_instance_valid(bow_wave):bow_wave.tick(phase_clock,drive,phase)
 if is_instance_valid(_material):
  _material.set_shader_parameter("clock", phase_clock)
  _material.set_shader_parameter("drive", drive)
  _material.set_shader_parameter("strength", intensity)
  _material.set_shader_parameter("phase_seed", phase)

func _build_contacts() -> void:
 var shader := Shader.new()
 shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float clock = 0.0;
uniform float drive = 0.0;
uniform float strength = 0.42;
uniform float phase_seed = 0.0;
uniform float sea_clock = 0.0;
#include "res://scripts/opening/harbor_sea_waves.gdshaderinc"
varying float patch_phase;
varying float patch_life;
varying float patch_kind;
void vertex() {
 patch_phase = COLOR.r * 6.283185 + phase_seed;
 patch_kind = COLOR.g;
 float cycle = fract(clock * (0.145 + drive * 0.035) + COLOR.r * 1.781 + phase_seed * 0.15915);
 patch_life = pow(max(sin(cycle * 3.141593), 0.0), 0.75);
 float bow = 1.0 - smoothstep(0.01, 0.12, abs(patch_kind - 0.5));
 float reach = (0.19 + drive * 0.50) * (1.0 + bow * drive * 0.65);
 VERTEX.xz += UV2 * (cycle * reach + sin(clock * 0.85 + patch_phase) * 0.022);
 VERTEX.x -= drive * cycle * (0.20 + smoothstep(0.6, 0.9, patch_kind) * 1.05);
 VERTEX.y += sin(clock * 1.1 + patch_phase + UV.x * 3.0) * 0.006;
 vec3 water_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 VERTEX.y += harbor_wave_displacement(water_world.xz, sea_clock) + 0.015;
}
void fragment() {
 float ends = smoothstep(0.0, 0.15, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
 float sides = smoothstep(0.0, 0.11, UV.y) * (1.0 - smoothstep(0.72, 1.0, UV.y));
 float grains = sin(UV.x * 34.0 + patch_phase * 7.0 + sin(UV.x * 13.0 - clock * 0.7));
 grains += 0.32 * sin(UV.x * 77.0 - patch_phase * 11.0 + clock * 0.9);
 float broken = smoothstep(-0.48, 0.38, grains);
 float edge = 0.29 + 0.065 * sin(UV.x * 17.0 + patch_phase + clock * 0.6);
 float foam = (1.0 - smoothstep(0.07, 0.30, abs(UV.y - edge))) * broken;
 float flecks = smoothstep(0.86, 0.99, sin(UV.x * 93.0 + patch_phase * 19.0) * sin(UV.y * 51.0 - clock * 0.5));
 foam = max(foam, flecks * 0.38);
 float bow = 1.0 - smoothstep(0.01, 0.12, abs(patch_kind - 0.5));
 float stern = smoothstep(0.6, 0.9, patch_kind);
 float activity = mix(1.0, 0.43 + drive * 1.05, bow);
 activity *= mix(1.0, 0.10 + drive * 0.95, stern);
 float crest = (1.0 - smoothstep(0.15, 0.75, abs(UV.y - 0.46))) * 0.22;
 ALBEDO = mix(vec3(0.29, 0.60, 0.65), vec3(0.88, 0.95, 0.91), foam * 0.90);
 ALPHA = (crest + foam * 0.94) * ends * sides * patch_life * mix(0.75, 1.0, strength) * activity;
 ROUGHNESS = 0.7;
}
"""
 _material = ShaderMaterial.new()
 _material.shader = shader
 _material.render_priority = 1
 for side in [-1.0, 1.0]:
  for section in SIDE_PATCHES:
   var x: float = -12.65 + section * 1.30
   var seed_: float = fposmod(section * .381966 + (0.21 if side > 0.0 else 0.0), 1.0)
   _side_patch(x, side, 1.01 + .19 * sin(section * 2.3), seed_)
   side_contact_count += 1
  for section in 4:
   _bow_patch(side, section)
   bow_contact_count += 1
  for section in 4:
   _stern_patch(side, section)
   stern_contact_count += 1
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = _vertices
 arrays[Mesh.ARRAY_NORMAL] = _normals
 arrays[Mesh.ARRAY_TEX_UV] = _uvs
 arrays[Mesh.ARRAY_TEX_UV2] = _outward
 arrays[Mesh.ARRAY_COLOR] = _colors
 arrays[Mesh.ARRAY_INDEX] = _indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 var visual := MeshInstance3D.new()
 visual.name = "FoamAndCrests"
 visual.mesh = mesh
 visual.material_override = _material
 visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 visual.custom_aabb = AABB(Vector3(-24.0, -1.2, -8.0), Vector3(42.0, 2.4, 16.0))
 add_child(visual)
 # The shader owns all movement; CPU-side geometry is discarded after upload.
 _vertices.clear(); _normals.clear(); _uvs.clear(); _outward.clear(); _colors.clear(); _indices.clear()

func set_sea_clock(value: float) -> void:
 _material.set_shader_parameter("sea_clock",value)
 bow_wave.material.set_shader_parameter("sea_clock",value)

func _waterline_half_width(x: float) -> float:
 return HullSurface.waterline_half_width(x)

func _side_patch(x: float, side: float, length_: float, seed_: float) -> void:
 var points := PackedVector3Array()
 var normals := PackedVector2Array()
 for step in CURVE_STEPS + 1:
  var t: float = float(step) / CURVE_STEPS
  var along: float = x + (t - .5) * length_
  var curve: float = sin(t * PI) * .105
  var z: float = _waterline_half_width(along) + .025 + curve
  var slope: float = (_waterline_half_width(along + .06) - _waterline_half_width(along - .06)) / .12
  points.append(Vector3(along, 0.0, side * z))
  normals.append(Vector2(-slope, side).normalized())
 _ribbon(points, normals, .67 + .09 * sin(seed_ * TAU), seed_, 0.0)

func _bow_patch(side: float, section: int) -> void:
 var points := PackedVector3Array()
 var normals := PackedVector2Array()
 # Short curved arcs follow the real +X stem's waterline instead of a V panel.
 for step in CURVE_STEPS + 1:
  var t: float = float(step) / CURVE_STEPS
  var parameter: float = .03 + section * .22 + t * .29
  var x: float = 14.18 - parameter * parameter * 1.70
  var z: float = _waterline_half_width(x) + .02
  var slope: float = (_waterline_half_width(x + .012) - _waterline_half_width(x - .012)) / .024
  points.append(Vector3(x, .003, side * z))
  normals.append(Vector2(-slope, side).normalized())
 _ribbon(points, normals, .62, fposmod(section * .317 + (.13 if side > 0.0 else .0), 1.0), .5)

func _stern_patch(side: float, section: int) -> void:
 var points := PackedVector3Array()
 var normals := PackedVector2Array()
 for step in CURVE_STEPS + 1:
  var t: float = float(step) / CURVE_STEPS
  var x: float = -14.1 - section * 1.4 - t * 1.2
  var z: float = side * (.45 + section * .30 + sin(t * PI) * .15 + t * .24)
  points.append(Vector3(x, -.003, z))
  normals.append(Vector2(-.25, side).normalized())
 _ribbon(points, normals, .44, fposmod(section * .27 + (.31 if side > 0.0 else .0), 1.0), 1.0)

func _ribbon(points: PackedVector3Array, normals: PackedVector2Array, width_: float, seed_: float, kind: float) -> void:
 var base: int = _vertices.size()
 for step in points.size():
  var t: float = float(step) / (points.size() - 1)
  var outward: Vector2 = normals[step]
  var tapered: float = width_ * (.35 + .65 * sin(t * PI))
  for edge in 2:
   var offset: Vector3 = Vector3(outward.x, 0.0, outward.y) * tapered * float(edge)
   _vertices.append(points[step] + offset)
   _normals.append(Vector3.UP)
   _uvs.append(Vector2(t, float(edge)))
   _outward.append(outward)
   _colors.append(Color(seed_, kind, .0, 1.0))
  if step < points.size() - 1:
   var at: int = base + step * 2
   _indices.append_array(PackedInt32Array([at, at + 2, at + 1, at + 1, at + 2, at + 3]))
 contact_count += 1
