class_name WallBreak
extends Node3D
## Voronoi wall pieces animated together on the GPU. See docs/home.md for sources.

enum Style {CRACK, SPACE}
const HOLE_SIZE := Vector2(2.4, 1.7)
const FULL_SIZE_AT := 3.0
const STAY_SECONDS := {Style.CRACK: 3.0, Style.SPACE: 6.0}
const SHARDS := preload("res://trials/motion/wall_shatter.gdshader")
const IMPACT := preload("res://trials/motion/wall_impact.gdshader")
var piece_count := 0
var _style := Style.CRACK
var _age := 0.0
var _material := ShaderMaterial.new()
var _impact := ShaderMaterial.new()


static func burst(eye: Vector3, look: Vector3, flow: Vector3, style := Style.CRACK) -> void:
	var hit := App.reality.hit(eye, look)
	var at: Vector3 = hit.position if hit else eye + look * 3.0
	var normal: Vector3 = hit.normal if hit else -look
	var effect := WallBreak.new()
	effect._style = style
	App.stage.add_child(effect)
	effect.global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD), at + normal * 0.025)
	var hole := HOLE_SIZE * clampf(eye.distance_to(at) / FULL_SIZE_AT, 0.4, 1.0)
	effect._build(hole, effect.global_basis.inverse() * flow, App.reality.camera_frame())
	Events.report(&"wall_break", {found = not hit.is_empty(), at = at, normal = normal, distance = eye.distance_to(at),
		hole = hole, style = Style.keys()[style].to_lower(), pieces = effect.piece_count, renderer = "gpu_voronoi"})


func _build(size: Vector2, flow: Vector3, frame: CameraFrame) -> void:
	_material.shader = SHARDS
	_material.set_shader_parameter(&"flow", flow)
	_material.set_shader_parameter(&"gravity", global_basis.inverse() * Vector3(0, -2.6, 0))
	_material.set_shader_parameter(&"size", size)
	if frame:
		_material.set_shader_parameter(&"has_picture", true)
		_material.set_shader_parameter(&"picture", ImageTexture.create_from_image(frame.image))
	var body := MeshInstance3D.new()
	body.name = "Shards"
	body.mesh = _mesh(size, frame)
	body.material_override = _material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.extra_cull_margin = 4.0
	add_child(body)
	_impact.shader = IMPACT
	_impact.set_shader_parameter(&"space", _style == Style.SPACE)
	var patch := MeshInstance3D.new()
	patch.name = "Impact"
	patch.mesh = QuadMesh.new()
	(patch.mesh as QuadMesh).size = size
	patch.material_override = _impact
	patch.position.z = -0.008
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(patch)
	_crash()


func _mesh(size: Vector2, frame: CameraFrame) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 43619
	var seeds: Array[Vector2] = []
	for y in 5:
		for x in 7:
			seeds.append((Vector2(x + rng.randf_range(0.15, 0.85), y + rng.randf_range(0.15, 0.85)) / Vector2(7, 5) - Vector2.ONE * 0.5) * size)
	var rim := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		rim.append(Vector2(cos(a), sin(a)) * size * 0.47)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for seed_point in seeds:
		var polygon := rim.duplicate()
		for other in seeds:
			if other == seed_point: continue
			polygon = _clip(polygon, (other + seed_point) * 0.5, other - seed_point)
			if polygon.is_empty(): break
		if polygon.size() < 3: continue
		piece_count += 1
		var centre := Vector2.ZERO
		for p in polygon: centre += p
		centre /= polygon.size()
		var random := rng.randf()
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			_vertex(tool, centre, 0, centre, random, 1, 1.0, frame)
			_vertex(tool, b, 0, centre, random, 0, 1.0, frame)
			_vertex(tool, a, 0, centre, random, 0, 1.0, frame)
			for part in [[a, 0.0], [b, 0.0], [b, -0.045], [a, 0.0], [b, -0.045], [a, -0.045]]:
				_vertex(tool, part[0], part[1], centre, random, 0.5, 0.42, frame)
	return tool.commit()


static func _clip(polygon: PackedVector2Array, midpoint: Vector2, normal: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var da := (a - midpoint).dot(normal)
		var db := (b - midpoint).dot(normal)
		if da <= 0: out.append(a)
		if (da <= 0) != (db <= 0): out.append(a.lerp(b, da / (da - db)))
	return out


func _vertex(tool: SurfaceTool, point: Vector2, z: float, centre: Vector2, random: float, edge: float, shade: float, frame: CameraFrame) -> void:
	var p := Vector3(point.x, point.y, z)
	tool.set_custom(0, Color(centre.x, centre.y, 0, random))
	tool.set_color(Color(shade, shade, shade))
	tool.set_uv(frame.uv(global_transform * p) if frame else Vector2.ZERO)
	tool.set_uv2(Vector2(edge, 0))
	tool.set_normal(Vector3.BACK)
	tool.add_vertex(p)


func _process(delta: float) -> void:
	_age += delta
	_material.set_shader_parameter(&"age", _age)
	_impact.set_shader_parameter(&"age", _age)
	_impact.set_shader_parameter(&"opacity", clampf((STAY_SECONDS[_style] + 0.5 - _age) / 0.5, 0, 1))
	if _age > STAY_SECONDS[_style] + 0.5: queue_free()


func _crash() -> void:
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(int(rate * 0.8) * 2)
	for i in samples.size() / 2:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0) * exp(-t * 7.0)
		var rumble := sin(TAU * (90.0 - 50.0 * t) * t) * exp(-t * 4.0)
		samples.encode_s16(i * 2, int(clampf(noise * 0.6 + rumble * 0.5, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = 4.0
	add_child(player)
	player.play()
