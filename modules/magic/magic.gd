extends Module
## Sparkles for right picks and a short celebration for completed levels.

const GOLD := Color(1.0, 0.85, 0.4)
const TROPHY := preload("res://modules/magic/trophy_winner.png")
const CELEBRATION_SECONDS := 1.5


func _ready() -> void:
	Events.scene_changing.connect(func() -> void:
		for node in get_children():
			node.free())
	Events.feedback.connect(func(kind: StringName, at: Vector3) -> void:
		if kind == &"good":
			sparkle(at, GOLD, 24))
	Events.level_won.connect(_celebrate)


func _celebrate(_task: StringName, _level: int, _stones: int) -> void:
	if not Events.celebrate:
		return
	var clip := Sprite3D.new()
	clip.name = "LevelCelebration"
	clip.texture = TROPHY
	clip.hframes = 6
	clip.vframes = 6
	clip.pixel_size = 0.0026
	clip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	clip.no_depth_test = true
	clip.render_priority = 5 # Keep the guide's subtitles in front.
	add_child(clip)
	var eye := App.head().global_transform
	clip.global_position = eye.origin - eye.basis.z * 0.8 + Vector3.DOWN * 0.035
	var playback := clip.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	playback.tween_property(clip, ^"frame", clip.hframes * clip.vframes - 1, CELEBRATION_SECONDS)
	playback.tween_callback(clip.queue_free)


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
