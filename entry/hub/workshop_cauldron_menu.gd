class_name WorkshopCauldronMenu
extends Node3D
## The hub's cauldron targets, engraved menu sign and glow.

const TINT := Color(1.0, 0.86, 0.55)

var target: Target
var sign_target: Target
var engraving: Node3D
var radius: float
var glow := 0.0
var _glow_light: StandardMaterial3D
var _glow_quad: MeshInstance3D
var _groove_light: StandardMaterial3D


func set_targetable(on: bool) -> void:
	var layer := Pointer.TARGET_LAYER if on else 0
	target.collision_layer = layer
	sign_target.collision_layer = layer


func is_lit() -> bool:
	return glow > 0.003


func update_glow(want: float, delta: float) -> void:
	_groove_light.emission_energy_multiplier = glow * 0.8
	glow = move_toward(glow, want, delta * (3.0 if want > glow else 1.5))
	_glow_light.albedo_color.a = glow * 0.35
	_glow_quad.visible = is_lit()


func slide(offset: Vector3, seconds: float) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for part: Node3D in [target, _glow_quad, sign_target]:
		tween.tween_property(part, "global_position", part.global_position + offset, seconds)


func build(pot: Node3D, mouth: Vector3, eye: Vector3) -> void:
	var width := 0.3
	if pot != null:
		width = maxf(0.2, (mouth.y - pot.global_position.y) * 2.0 + 0.1)
	radius = width * 0.5
	target = Target.sphere(&"hub_cauldron", radius)
	add_child(target)
	target.global_position = (pot.global_position + mouth) * 0.5 if pot != null else mouth
	_glow_light = StandardMaterial3D.new()
	_glow_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_light.albedo_texture = Onion.soft_dot()
	_glow_light.albedo_color = Color(TINT, 0.0)
	_glow_light.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.24
	quad.material = _glow_light
	_glow_quad = MeshInstance3D.new()
	_glow_quad.name = "cauldron_glow"
	_glow_quad.mesh = quad
	_glow_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow_quad)
	_glow_quad.global_position = mouth + Vector3.UP * 0.01
	_glow_quad.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # lies on the brew
	_build_engraving(pot, mouth, eye)


## The engraving follows the pot as it moves. Its target stays in the hub.
func _build_engraving(pot: Node3D, mouth: Vector3, eye: Vector3) -> void:
	engraving = Node3D.new()
	engraving.name = "menu_engraving"
	var toward := Vector3(eye.x - mouth.x, 0.0, eye.z - mouth.z).normalized()
	var belly := mouth + Vector3.DOWN * 0.05
	var belly_radius := 0.06
	if pot != null:
		var box := _bounds(pot)
		if box.size != Vector3.ZERO:
			# Measured without the legs and handles: the belly's middle is a little under the rim, and its radius
			# is the narrower of the pot's two widths (the handles stick out sideways).
			belly = Vector3(mouth.x, mouth.y - (mouth.y - box.position.y) * 0.32, mouth.z)   # the belly's widest band
			belly_radius = _surface_toward(pot, belly, toward, minf(box.size.x, box.size.z) * 0.5)
		pot.add_child(engraving)
	else:
		add_child(engraving)
	engraving.global_position = belly + toward * (belly_radius - 0.002)   # on the surface, cut in a little
	engraving.look_at(engraving.global_position + toward, Vector3.UP, true)
	_groove_light = StandardMaterial3D.new()
	_groove_light.albedo_color = Color(0.16, 0.13, 0.1)   # a dark cut in the pale pot
	_groove_light.roughness = 0.9
	_groove_light.emission_enabled = true
	_groove_light.emission = TINT
	_groove_light.emission_energy_multiplier = 0.0
	var size := clampf(belly_radius * 0.55, 0.022, 0.045)
	for row in 3:
		var groove := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = size * 0.11
		capsule.height = size
		groove.mesh = capsule
		groove.material_override = _groove_light
		groove.rotation.z = PI * 0.5   # lying across
		groove.scale = Vector3(1.0, 1.0, 0.45)   # cut into the surface, not standing on it
		groove.position = Vector3(0.0, (1 - row) * size * 0.36, 0.0)
		engraving.add_child(groove)
	sign_target = Target.sphere(&"hub_menu_sign", 0.04)
	add_child(sign_target)   # under the hub, not the pot: the workshop itself carries no touch targets
	sign_target.global_position = engraving.global_position


## How far the pot's own surface reaches from [param centre] along [param toward], at that height: its mesh points
## within a band around the line (the legs and handles stick out elsewhere). [param fallback] when none.
func _surface_toward(node: Node3D, centre: Vector3, toward: Vector3, fallback: float) -> float:
	var best := 0.0
	var side := toward.cross(Vector3.UP)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var faces := mesh.mesh.get_faces()
		var xf := mesh.global_transform
		for point in faces:
			var p := xf * point - centre
			if absf(p.y) < 0.015 and absf(p.dot(side)) < 0.02:
				best = maxf(best, p.dot(toward))
	return best if best > 0.01 else fallback


## The world box round every mesh under [param node].
func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
