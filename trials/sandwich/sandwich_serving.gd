extends Node3D

signal completed

const Visuals := preload("res://trials/sandwich/sandwich_visuals.gd")

var phase := "building"
var _stack: Node3D
var _layers: Array[Node3D] = []
var _rests: Array[Vector3] = []
var _rest := Vector3.ZERO
var _sparkles: Array[Node3D] = []
var _halo: MeshInstance3D
var _light: StandardMaterial3D
var _animation: Tween


func start(stack: Node3D, layers: Array[Node3D], sample: Node3D) -> void:
	_stack = stack
	_layers.assign(layers)
	_animation = create_tween()
	_animation.tween_interval(0.28)
	_animation.tween_property(sample, ^"scale", Vector3.ONE * 0.001, 0.43).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_callback(sample.hide)
	_animation.tween_callback(_lift)
	_animation.tween_method(_reveal, 0.0, 1.0, 2.8)
	_animation.tween_callback(_plate)
	_animation.tween_interval(1.22)
	_animation.finished.connect(func() -> void: completed.emit())


func _lift() -> void:
	phase = "showcase"
	Events.report(&"sandwich_serving", {phase = phase})
	Events.play(&"stone", global_position)
	_rest = _stack.position
	for layer in _layers:
		_rests.append(layer.position)
	_light = Visuals.material(Visuals.GOLD, true)
	_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light.albedo_color.a = 0.0
	var rim := TorusMesh.new()
	rim.inner_radius = 0.115
	rim.outer_radius = 0.120
	rim.rings = 36
	rim.ring_segments = 8
	_halo = Visuals.display(self, rim, Vector3.UP * 0.026, _light)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in 12:
		_sparkles.append(Visuals.spark(self, Visuals.GOLD if index % 3 == 0 else Visuals.CREAM))


func _reveal(progress: float) -> void:
	var bloom := smoothstep(0.0, 0.25, progress) * (1.0 - smoothstep(0.68, 1.0, progress))
	_stack.position = _rest + Vector3.UP * (0.092 * bloom)
	_stack.rotation = Vector3(0.07 * bloom, TAU * smoothstep(0.08, 0.96, progress), 0.0)
	for index in _layers.size():
		_layers[index].position = _rests[index] + Vector3.UP * (0.027 * index * bloom)
	_halo.scale = Vector3.ONE * (0.94 + 0.10 * bloom)
	_light.albedo_color.a = 0.78 * bloom
	for index in _sparkles.size():
		var star := _sparkles[index]
		var angle := TAU * (float(index) / _sparkles.size() + progress * 0.75)
		var radius := 0.108 + 0.025 * bloom + 0.012 * sin(index * 2.1)
		star.position = Vector3(cos(angle) * radius, 0.065 + (0.08 + 0.035 * sin(angle + index)) * bloom,
			sin(angle) * radius)
		star.rotation = Vector3(-0.50, 0.0, angle)
		star.scale = Vector3.ONE * maxf(0.001, bloom * (0.55 + 0.55 * sin(angle * 2.0) ** 2))


func _plate() -> void:
	phase = "served"
	Events.report(&"sandwich_serving", {phase = phase})
	Events.play(&"place", global_position)
	_halo.hide()
	for star in _sparkles:
		star.hide()
	var ticket := Node3D.new()
	add_child(ticket)
	ticket.position = Vector3(0, 0.146, -0.064)
	ticket.rotation.x = -0.38
	Visuals.box(ticket, Vector3(0.194, 0.044, 0.005), Vector3.ZERO, Visuals.material(Visuals.DEEP))
	Visuals.box(ticket, Vector3(0.194, 0.002, 0.005), Vector3(0, 0.022, 0), Visuals.material(Visuals.GOLD, true))
	Visuals.label(ticket, "READY TO SERVE", Vector3(0, 0, 0.003), 0.00043)


func stop() -> void:
	if _animation:
		_animation.kill()
