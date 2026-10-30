extends Module
## Magic for the alchemist story: sparkles where a pick was right, and a bigger
## puff in front of the child when a level is done. Only looks: nothing waits
## for it. Delete the node to unplug it.
##
## Calm to look at: nothing flashes or flickers, sparkles drift up and fade.

const GOLD := Color(1.0, 0.85, 0.4)
## Where a level's puff shows: ahead of and below the eyes, metres.
const AHEAD := 0.45
const BELOW := 0.25


func _ready() -> void:
	Events.feedback.connect(func(kind: StringName, at: Vector3) -> void:
		if kind == &"good":
			sparkle(at, GOLD, 24))
	Events.reported.connect(func(what: StringName, _data: Dictionary) -> void:
		if what == &"task_done":
			sparkle(_ahead(), GOLD, 32))


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


func _ahead() -> Vector3:
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	return eye.origin + forward * AHEAD + Vector3.DOWN * BELOW
