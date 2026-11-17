class_name Impression
extends Node3D
## The small, solid stand-in for one hub activity (Effects chat, Nov 17): what the child touches to choose
## it. Big (12-16 cm), solid, one strong colour each with a dark outline, and a silhouette of its own, so
## telling them apart is never a vision test: the shelf is a square frame, the dots token a round disc,
## the cup a cup with a handle. Their sounds differ too (see [method touched]).
##
## The Hub chat asks for one through [method make] from [code]Summonable.make_impression()[/code].

## &"shelf", &"dots" or &"turn_to_fit".
var kind := &""
## The size it stands at (the mesh's own size is its full size).
var size := Vector3.ONE

## Not selectable yet (see [method set_sealed]).
var sealed := false
const SEALED_SCALE := 0.75
var _band: MeshInstance3D
var _waiting := 0.0
var _near := 0.0
var _sounds: Sounds
var _halo: MeshInstance3D
var _halo_light: StandardMaterial3D
var _body: Node3D

const OUTLINE := Color(0.06, 0.05, 0.05)
const WOOD := Color(0.42, 0.25, 0.12)
const CREAM := Color(0.97, 0.93, 0.82)
const NAVY := Color(0.10, 0.14, 0.34)
const CUP := Color(0.96, 0.95, 0.92)   # near-white: the orange first tried had the table's brightness (lost without colour)
const CUP_INSIDE := Color(0.86, 0.42, 0.22)
const BASE := Color(0.33, 0.5, 0.38)   # sage, darker than the cup
const GLOW := Color(1.0, 0.86, 0.55)


## A new impression of [param of_kind], standing on its base at its origin, front (+Z) to the child.
static func make(of_kind: StringName) -> Impression:
	var impression := Impression.new()
	impression.kind = of_kind
	impression.name = "impression_%s" % of_kind
	impression._body = Node3D.new()
	impression.add_child(impression._body)
	match of_kind:
		&"shelf":
			impression._shelf()
		&"dots":
			impression._dots()
		&"turn_to_fit":
			impression._cup()
	impression._make_halo()
	return impression


## Its base on the table, metres (x across, y = depth), for the hub's spacing.
static func footprint(of_kind: StringName) -> Vector2:
	match of_kind:
		&"shelf":
			return Vector2(0.16, 0.08)
		&"dots":
			return Vector2(0.15, 0.05)
		&"turn_to_fit":
			return Vector2(0.16, 0.16)
	return Vector2(0.16, 0.16)


## The soft pool of light under it while it waits to be chosen (glow C); 0 = off.
func set_waiting(strength: float) -> void:
	_waiting = clampf(strength, 0.0, 1.0)
	_update_halo()


## 0..1 as a hand comes close: the pool brightens (the "that one" cue). Choosing stays a press.
func set_near(amount: float) -> void:
	_near = clampf(amount, 0.0, 1.0)
	_update_halo()


## The child touched it: its own sound and a short warm pulse, the "I heard you" acknowledgement.
func touched() -> void:
	if _sounds == null:
		_sounds = Sounds.new()
		add_child(_sounds)
	_sounds.play(StringName("impression_%s" % kind), global_position)
	var pulse := create_tween()
	pulse.tween_property(_body, "scale", Vector3.ONE * 1.08, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(_body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	PlaceSignal.play(self, global_position, Vector3.UP, 0.1, false)


## Sealed (story chat, Nov 17: shown but not selectable yet): it sits smaller inside a brass band and
## gets no glow. The difference is size, a solid band and no light, never a faint or greyed look (that
## would make "can I pick it?" a contrast test). [method unseal] opens it with a sound and a pulse.
func set_sealed(on: bool) -> void:
	sealed = on
	_body.scale = Vector3.ONE * (SEALED_SCALE if on else 1.0)
	if on and _band == null:
		_band = MeshInstance3D.new()
		var torus := TorusMesh.new()
		var radius := maxf(footprint(kind).x, footprint(kind).y) * 0.5 + 0.02
		torus.inner_radius = radius
		torus.outer_radius = radius + 0.014
		_band.mesh = torus
		_band.material_override = _lit(Color(0.72, 0.55, 0.25), true)
		_band.position.y = 0.007
		add_child(_band)
	if _band:
		_band.visible = on
	_update_halo()


## Opens a sealed impression: the band drops away, it grows to full size, its sound and a pulse.
func unseal(seconds := 0.8) -> void:
	if not sealed:
		return
	sealed = false
	var open := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	open.tween_property(_body, "scale", Vector3.ONE, seconds)
	if _band:
		open.tween_property(_band, "scale", Vector3(1.3, 0.2, 1.3), seconds * 0.6)
		open.chain().tween_callback(func() -> void: _band.visible = false; _band.scale = Vector3.ONE)
	touched()
	_update_halo()


func _update_halo() -> void:
	if sealed:
		_halo.visible = false
		return
	var alpha := 0.5 * _waiting + 0.35 * _near * _waiting
	_halo.visible = alpha > 0.0
	_halo_light.albedo_color.a = alpha


# --- Looks ---------------------------------------------------------------------------------------

func _shelf() -> void:
	# A chunky square frame with four cream cubbies: Wei's shelf, simplified (no shapes inside: detail).
	var w := 0.16
	var h := 0.15
	var d := 0.08
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), WOOD)
	var cell := Vector2((w - 0.036) * 0.5, (h - 0.036) * 0.5)
	for col in 2:
		for row in 2:
			var x := (col - 0.5) * (cell.x + 0.012)
			var y := 0.012 + cell.y * 0.5 + row * (cell.y + 0.012)
			_box(Vector3(cell.x, cell.y, 0.012), Vector3(x, y, d * 0.5 - 0.004), CREAM, false)


func _dots() -> void:
	# A round token standing on its edge: navy with seven big cream dots (still, never moving).
	var r := 0.075
	var disc := _mesh(_cylinder(r, r, 0.035), NAVY)
	disc.rotation.x = PI * 0.5
	disc.position = Vector3(0, r + 0.012, 0)
	var foot := _box(Vector3(0.08, 0.012, 0.05), Vector3(0, 0.006, 0), NAVY.darkened(0.3))
	var spots := [Vector2.ZERO]
	for i in 6:
		spots.append(Vector2.from_angle(i * TAU / 6.0 + PI / 6.0) * r * 0.58)
	for spot: Vector2 in spots:
		var dot := _mesh(_cylinder(0.014, 0.014, 0.006), CREAM, false)
		dot.rotation.x = PI * 0.5
		dot.position = Vector3(spot.x, r + 0.012 + spot.y, 0.019)


func _cup() -> void:
	# A white cup with a handle on a round sage base: "the game", never mistaken for the real cup
	# that stands on the table while Turn to fit is offered (Megan's default, Nov 17).
	_mesh(_cylinder(0.075, 0.08, 0.022), BASE).position.y = 0.011
	_mesh(_cylinder(0.05, 0.04, 0.10), CUP).position.y = 0.022 + 0.05
	var inside := _mesh(_cylinder(0.043, 0.043, 0.004), CUP_INSIDE, false)
	inside.position.y = 0.022 + 0.099
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.018
	torus.outer_radius = 0.03
	handle.mesh = torus
	handle.material_override = _lit(CUP, true)
	handle.rotation = Vector3(PI * 0.5, 0, 0)
	handle.rotation.y = PI * 0.5
	handle.position = Vector3(0.055, 0.022 + 0.055, 0)
	handle.scale = Vector3(1.0, 1.0, 1.3)
	_body.add_child(handle)


func _make_halo() -> void:
	_halo = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.26
	quad.orientation = PlaneMesh.FACE_Y
	_halo_light = StandardMaterial3D.new()
	_halo_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_light.albedo_color = Color(GLOW, 0.0)
	_halo_light.albedo_texture = Onion.soft_dot()
	quad.material = _halo_light
	_halo.mesh = quad
	_halo.position.y = 0.002
	_halo.visible = false
	add_child(_halo)


# --- Helpers -------------------------------------------------------------------------------------

func _box(extent: Vector3, at: Vector3, colour: Color, outlined := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = extent
	var mesh := _mesh(box, colour, outlined)
	mesh.position = at
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 48
	return mesh


func _mesh(mesh: Mesh, colour: Color, outlined := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _lit(colour, outlined)
	_body.add_child(instance)
	return instance


## A plain lit colour with, optionally, a dark outline drawn behind it (an inverted hull, 5 mm).
static func _lit(colour: Color, outlined: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.6
	if outlined:
		var outline := StandardMaterial3D.new()
		outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.albedo_color = OUTLINE
		outline.cull_mode = BaseMaterial3D.CULL_FRONT
		outline.grow = true
		outline.grow_amount = 0.005
		material.next_pass = outline
	return material
