class_name PlaceSignal
extends Node3D
## "Found its place" (Effects chat, Nov 17): one soft warm ring that spreads a few centimetres over the
## surface where something has just settled, plus the seat click: a tiny version of the reveal's band,
## so the child learns once what a win looks like. Used for the gear seating, each shape that fits, the
## gear going home and (quietly, without the click) an impression being touched. Slow, no flash: peak
## alpha 0.35, 0.9 s, one ring, then it frees itself.

const SECONDS := 0.9


## Plays the signal at [param at] on a surface facing [param normal]; [param parent] holds it.
static func play(parent: Node, at: Vector3, normal := Vector3.UP, radius := 0.08, click := true) -> PlaceSignal:
	var signal_fx := PlaceSignal.new()
	signal_fx.name = "place_signal"
	parent.add_child(signal_fx)
	signal_fx._start(at, normal, radius, click)
	return signal_fx


func _start(at: Vector3, normal: Vector3, radius: float, click: bool) -> void:
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	global_transform = Transform3D(Basis(side, up, side.cross(up)), at + up * 0.004)
	var material := ShaderMaterial.new()
	material.shader = RevealFx.FRONT
	material.set_shader_parameter(&"origin", global_position)
	material.set_shader_parameter(&"tint", RevealFx.TINT)
	material.set_shader_parameter(&"band", radius * 0.18)
	material.set_shader_parameter(&"strength", 0.35)
	material.set_shader_parameter(&"afterglow", 0.12)
	material.set_shader_parameter(&"edge_width", 0.0)
	material.set_shader_parameter(&"half_size", Vector2.ONE * radius * 1.6)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * radius * 3.2
	mesh.material = material
	plane.mesh = mesh
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	if click:
		var sounds := Sounds.new()
		add_child(sounds)
		sounds.play(&"place", at)
	var tween := create_tween().set_parallel()
	tween.tween_method(func(r: float) -> void: material.set_shader_parameter(&"radius", r), radius * 0.2, radius * 1.4, SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(f: float) -> void: material.set_shader_parameter(&"fade", f), 1.0, 0.0, SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_interval(0.6)   # the click's tail
	tween.chain().tween_callback(queue_free)
