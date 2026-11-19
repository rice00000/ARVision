class_name RoundDots
extends Node3D
## A row of dots, one per round of a level, up and to the right of the view
## (mirroring Replay tutorial on the left): gold for a round solved, grey for
## one not, a ring round the one being played, dim for those to come. Children
## who cannot count rounds yet still see how much is left. The Session makes
## one per block of more than one round.

const SIZE := 0.026
const GAP := 0.012
const DONE := Color("#f3d28a")
const MISSED := Color("#8a96a3")
const TO_COME := Color(0.55, 0.6, 0.66)
const RING := Color("#ffffff")
## The dark plate behind the row, as behind subtitles: clear on any wall.
const PLATE := Color(0.05, 0.06, 0.08, 0.72)

var _dots: Array[MeshInstance3D] = []
var _ring := MeshInstance3D.new()


func _init(rounds: int) -> void:
	name = "RoundDots"
	var width := rounds * SIZE + (rounds - 1) * GAP
	var plate := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width + 0.03, SIZE + 0.024)
	plate.mesh = quad
	plate.material_override = _flat(PLATE, 30)
	add_child(plate)
	for i in rounds:
		var dot := MeshInstance3D.new()
		var disc := SphereMesh.new()
		disc.radius = SIZE * 0.5
		disc.height = SIZE
		dot.mesh = disc
		dot.material_override = _flat(TO_COME, 31)
		dot.position.z = 0.002
		dot.scale = Vector3(1.0, 1.0, 0.3)
		dot.position.x = -width * 0.5 + SIZE * 0.5 + i * (SIZE + GAP)
		add_child(dot)
		_dots.append(dot)
	var torus := TorusMesh.new()
	torus.inner_radius = SIZE * 0.62
	torus.outer_radius = SIZE * 0.78
	_ring.mesh = torus
	_ring.material_override = _flat(RING, 32)
	_ring.rotation.x = PI / 2.0
	_ring.position.z = 0.003
	_ring.visible = false
	add_child(_ring)


## Stands the row in [param frame] (Trial.in_front), right of centre.
func place(frame: Transform3D) -> void:
	global_transform = frame.translated_local(Vector3(0.42, 0.0, 0.0))
	look_at(App.head().global_position, Vector3.UP, true)


func show_round(index: int) -> void:
	if index < _dots.size():
		_ring.position = _dots[index].position + Vector3(0.0, 0.0, 0.001)
		_ring.visible = true


func finish_round(index: int, solved: bool) -> void:
	if index < _dots.size():
		(_dots[index].material_override as StandardMaterial3D).albedo_color = DONE if solved else MISSED
	_ring.visible = false


## Gold dots so far: tests and the layout read this.
func solved() -> int:
	return _dots.filter(func(dot: MeshInstance3D) -> bool:
		return (dot.material_override as StandardMaterial3D).albedo_color == DONE).size()


static func _flat(colour: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	material.albedo_color = colour
	return material
