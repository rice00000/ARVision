extends Module
## Magic for the alchemist story: sparkles where a pick was right, and a potion
## brewed in front of the child each time a level is done. Only looks: nothing
## waits for it. Delete the node to unplug it.
##
## Calm to look at: nothing flashes or flickers, sparkles drift up and fade, and
## the potion stays below the eyes for three seconds.

const GOLD := Color(1.0, 0.85, 0.4)
## Liquid of each potion brewed, in turn.
const POTIONS: Array[Color] = [Color(0.95, 0.35, 0.55), Color(0.3, 0.75, 0.95), Color(0.45, 0.9, 0.45),
	Color(0.7, 0.45, 0.95), Color(1.0, 0.65, 0.25)]
## Where the potion stands: ahead of and below the eyes, metres.
const AHEAD := 0.45
const BELOW := 0.25

var _brewed := 0


func _ready() -> void:
	Events.feedback.connect(func(kind: StringName, at: Vector3) -> void:
		if kind == &"good":
			sparkle(at, GOLD, 24))
	Events.reported.connect(func(what: StringName, _data: Dictionary) -> void:
		if what == &"task_done":
			brew())


## A puff of [param amount] sparkles at [param at] that drift up and fade.
func sparkle(at: Vector3, colour: Color, amount: int) -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.name = "Sparkles"
	puff.one_shot = true
	puff.amount = amount
	puff.lifetime = 1.0
	puff.explosiveness = 0.85
	puff.direction = Vector3.UP
	puff.spread = 60.0
	puff.initial_velocity_min = 0.12
	puff.initial_velocity_max = 0.35
	puff.gravity = Vector3(0.0, -0.1, 0.0)
	puff.damping_min = 0.2
	puff.damping_max = 0.4
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	puff.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = 0.005
	dot.height = 0.01
	dot.radial_segments = 6
	dot.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	dot.material = material
	puff.mesh = dot
	add_child(puff)
	puff.global_position = at
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	return puff


## A flask appears, fills with this potion's colour, turns once, sparkles out of
## its neck and shrinks away.
func brew() -> Node3D:
	var colour := POTIONS[_brewed % POTIONS.size()]
	_brewed += 1
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var flask := Node3D.new()
	flask.name = "Potion"
	add_child(flask)
	flask.global_position = eye.origin + forward * AHEAD + Vector3.DOWN * BELOW
	var liquid := _part(flask, _ball(0.043), colour, Vector3.ZERO)
	_part(flask, _ball(0.05), Color(1.0, 1.0, 1.0, 0.25), Vector3.ZERO)
	_part(flask, _tube(0.016, 0.05), Color(1.0, 1.0, 1.0, 0.25), Vector3(0.0, 0.065, 0.0))
	_part(flask, _tube(0.019, 0.02), Color(0.55, 0.35, 0.2), Vector3(0.0, 0.1, 0.0))
	flask.scale = Vector3.ONE * 0.01
	liquid.scale = Vector3(1.0, 0.05, 1.0)
	var tween := flask.create_tween()
	tween.tween_property(flask, ^"scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(liquid, ^"scale", Vector3.ONE, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: sparkle(flask.global_position + Vector3.UP * 0.11, colour.lightened(0.3), 48))
	tween.tween_property(flask, ^"rotation:y", TAU, 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(flask, ^"scale", Vector3.ONE * 0.01, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(flask.queue_free)
	return flask


func _part(flask: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	flask.add_child(part)
	return part


static func _ball(radius: float) -> SphereMesh:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	return ball


static func _tube(radius: float, height: float) -> CylinderMesh:
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = height
	return tube
