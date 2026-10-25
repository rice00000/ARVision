class_name WallBreak
extends Node3D
## Demo effect: the real wall ahead cracks with glowing seams, its pieces burst
## out the way the flow went and a hole into space opens for a few seconds.
## [method Reality.hit] finds the wall (room scan, else the live depth); with
## nothing found it breaks 3 m ahead. The pieces wear the camera's picture of
## that wall, so it is the real wall that seems to break.

## Hole size at 3 m; nearer walls get a smaller hole, so it fills about the same view.
const HOLE_SIZE := Vector2(2.4, 1.7)
const FULL_SIZE_AT := 3.0
const GRID := Vector2i(9, 7)
## Pieces this far inside the hole's rim (1 = the rim) break out.
const INSIDE := 0.8
const THICKNESS := 0.04
const GAP := 0.06
const WALL_COLOUR := Color(0.82, 0.8, 0.76)
const GRAVITY := Vector3(0.0, -6.0, 0.0)
const CRACK_SECONDS := 0.3
const SHARD_SECONDS := 1.6
const HOLE_SECONDS := 6.0
const HOLE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float open = 0.0;
uniform float crack = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float edge = (0.82 + 0.1 * sin(a * 7.0 + 1.3) * sin(a * 3.0 + TIME * 0.5)) * open;
	if (r > edge) discard;
	vec2 g = UV * 48.0;
	float star = step(0.982, hash(floor(g))) * (1.0 - smoothstep(0.0, 0.4, length(fract(g) - 0.5)));
	vec3 nebula = mix(vec3(0.01, 0.0, 0.05), vec3(0.3, 0.05, 0.55), smoothstep(1.0, 0.0, r))
		+ vec3(0.0, 0.35, 0.6) * pow(max(0.0, 1.0 - r), 3.0) * (0.6 + 0.4 * sin(TIME * 2.0 + uv.x * 5.0));
	vec3 space = nebula + vec3(star) * (0.6 + 0.4 * sin(TIME * 6.0 + hash(floor(g)) * 30.0))
		+ vec3(1.0, 0.55, 0.15) * smoothstep(edge - 0.1, edge, r) * 2.5;
	vec3 seam = vec3(1.0, 0.75, 0.35) * (2.0 + sin(TIME * 40.0));
	ALBEDO = mix(space, seam, crack);
}
"""

var _shards: Array[MeshInstance3D] = []
var _velocity: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _age := 0.0
var _flying := false
var _hole_material := ShaderMaterial.new()
var _shard_material := StandardMaterial3D.new()
var _dust := CPUParticles3D.new()


## Breaks the wall in front of [param eye] along [param look]; pieces fly along [param flow] (world).
static func burst(eye: Vector3, look: Vector3, flow: Vector3) -> void:
	var hit := App.reality.hit(eye, look)
	var at: Vector3 = hit.position if hit else eye + look * 3.0
	var normal: Vector3 = hit.normal if hit else -look
	var effect := WallBreak.new()
	App.stage.add_child(effect)
	effect.global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD),
		at + normal * 0.02)
	var hole := HOLE_SIZE * clampf(eye.distance_to(at) / FULL_SIZE_AT, 0.4, 1.0)
	Events.report(&"wall_break", {found = not hit.is_empty(), at = at, normal = normal,
		distance = eye.distance_to(at), hole = hole})
	effect._build(hole, effect.global_basis.inverse() * flow, App.reality.camera_frame())


func _build(hole_size: Vector2, flow: Vector3, frame: CameraFrame) -> void:
	var hole := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = hole_size
	hole.mesh = quad
	_hole_material.shader = Shader.new()
	_hole_material.shader.code = HOLE
	_hole_material.set_shader_parameter(&"open", 1.0)
	_hole_material.set_shader_parameter(&"crack", 1.0)
	hole.material_override = _hole_material
	add_child(hole)
	_shard_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shard_material.vertex_color_use_as_albedo = true
	_shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shard_material.texture_repeat = false
	if frame:
		_shard_material.albedo_texture = ImageTexture.create_from_image(frame.image)
	else:
		_shard_material.albedo_color = WALL_COLOUR
	for triangle in _pieces(hole_size):
		_add_shard(triangle, flow, hole_size, frame)
	_add_dust(hole_size)
	_crash()


## Triangles of a jittered grid over the hole, those well inside its rim.
func _pieces(hole_size: Vector2) -> Array[PackedVector2Array]:
	var cell := hole_size / Vector2(GRID)
	var corners: Array[Vector2] = []
	for y in GRID.y + 1:
		for x in GRID.x + 1:
			var corner := Vector2(x, y) * cell - hole_size * 0.5
			if x > 0 and y > 0 and x < GRID.x and y < GRID.y:
				corner += Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35)) * cell
			corners.append(corner)
	var pieces: Array[PackedVector2Array] = []
	for y in GRID.y:
		for x in GRID.x:
			var a := corners[y * (GRID.x + 1) + x]
			var b := corners[y * (GRID.x + 1) + x + 1]
			var c := corners[(y + 1) * (GRID.x + 1) + x]
			var d := corners[(y + 1) * (GRID.x + 1) + x + 1]
			var halves := [PackedVector2Array([a, b, d]), PackedVector2Array([a, d, c])] if randf() < 0.5 \
				else [PackedVector2Array([a, b, c]), PackedVector2Array([b, d, c])]
			for triangle: PackedVector2Array in halves:
				var centre := (triangle[0] + triangle[1] + triangle[2]) / 3.0
				if (centre / (hole_size * 0.5)).length() < INSIDE:
					pieces.append(triangle)
	return pieces


## One piece: a thin prism around its centre, the camera's picture on it.
func _add_shard(triangle: PackedVector2Array, flow: Vector3, hole_size: Vector2, frame: CameraFrame) -> void:
	var centre := (triangle[0] + triangle[1] + triangle[2]) / 3.0
	var shade := randf_range(0.85, 1.0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for corner in triangle:
		var local := (corner - centre) * (1.0 - GAP)
		front.append(Vector3(local.x, local.y, 0.0))
		uvs.append(frame.uv(global_transform * Vector3(corner.x, corner.y, -0.02)) if frame else Vector2.ZERO)
	var back: Array[Vector3] = []
	back.assign(front.map(func(point: Vector3) -> Vector3: return point + Vector3(0.0, 0.0, -THICKNESS)))
	var side := Color(shade * 0.55, shade * 0.55, shade * 0.55)
	_face(tool, front, uvs, Color(shade, shade, shade))
	_face(tool, [back[0], back[2], back[1]], [uvs[0], uvs[2], uvs[1]], side)
	for i in 3:
		var j := (i + 1) % 3
		_face(tool, [front[i], back[i], back[j]], [uvs[i], uvs[i], uvs[j]], side)
		_face(tool, [front[i], back[j], front[j]], [uvs[i], uvs[j], uvs[j]], side)
	var shard := MeshInstance3D.new()
	shard.mesh = tool.commit()
	shard.material_override = _shard_material
	shard.position = Vector3(centre.x, centre.y, 0.03)
	add_child(shard)
	_shards.append(shard)
	# Out of the wall, along the flow, spread from the centre of the break.
	var spread := Vector3(centre.x, centre.y, 0.0) / (hole_size.x * 0.5) * 2.4
	_velocity.append(Vector3(0, 0, randf_range(1.2, 3.0)) + flow * randf_range(1.5, 3.5) + spread
		+ Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 1.2), 0.0))
	_spin.append(Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))


func _face(tool: SurfaceTool, corners: Array, uvs: Array, colour: Color) -> void:
	for i in 3:
		tool.set_color(colour)
		tool.set_uv(uvs[i])
		tool.add_vertex(corners[i])


func _add_dust(hole_size: Vector2) -> void:
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var round := GradientTexture2D.new()
	round.gradient = soft
	round.fill = GradientTexture2D.FILL_RADIAL
	round.fill_from = Vector2(0.5, 0.5)
	round.fill_to = Vector2(0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = round
	var puff := QuadMesh.new()
	puff.size = Vector2(0.25, 0.25)
	puff.material = material
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.8, 0.77, 0.72, 0.4), Color(0.8, 0.77, 0.72, 0.0)])
	_dust.mesh = puff
	_dust.color_ramp = fade
	_dust.one_shot = true
	_dust.emitting = false
	_dust.amount = 40
	_dust.lifetime = 1.4
	_dust.explosiveness = 0.9
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(hole_size.x * 0.35, hole_size.y * 0.35, 0.02)
	_dust.direction = Vector3.BACK
	_dust.spread = 50.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.4
	_dust.damping_min = 1.0
	_dust.damping_max = 2.0
	_dust.gravity = Vector3(0.0, -0.6, 0.0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.4
	_dust.position = Vector3(0.0, 0.0, 0.05)
	add_child(_dust)


func _process(delta: float) -> void:
	_age += delta
	if not _flying:
		# The seams glow while the pieces tremble in place.
		for shard in _shards:
			shard.position.z = 0.03 + randf_range(0.0, 0.01)
		if _age >= CRACK_SECONDS:
			_flying = true
			_dust.emitting = true
			create_tween().tween_method(func(amount: float) -> void:
				_hole_material.set_shader_parameter(&"crack", amount), 1.0, 0.0, 0.4)
		return
	var flight := _age - CRACK_SECONDS
	var gravity := global_basis.inverse() * GRAVITY
	_shard_material.albedo_color.a = clampf(1.0 - (flight - SHARD_SECONDS * 0.6) / (SHARD_SECONDS * 0.4), 0.0, 1.0)
	for i in _shards.size():
		_velocity[i] += gravity * delta
		_shards[i].position += _velocity[i] * delta
		_shards[i].rotation += _spin[i] * delta
	if flight > SHARD_SECONDS and not _shards.is_empty():
		for shard in _shards:
			shard.queue_free()
		_shards.clear()
	if _age > HOLE_SECONDS:
		var close := create_tween()
		close.tween_method(_open, 1.0, 0.0, 0.5)
		close.tween_callback(queue_free)
		set_process(false)


func _open(amount: float) -> void:
	_hole_material.set_shader_parameter(&"open", amount)


## A short crash: falling-pitch rumble under a burst of noise.
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
