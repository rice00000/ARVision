class_name WallBreak
extends Node3D
## Demo effect: the real wall ahead cracks, shards fly the way the flow went and a
## hole into space opens for a few seconds. The wall comes from the room scan
## (a ray against the "reality" layer); with none, it breaks 3 m ahead.

const HOLE_SIZE := Vector2(2.4, 1.7)
const GRID := Vector2i(8, 6)
const GRAVITY := Vector3(0.0, -6.0, 0.0)
const SHARD_SECONDS := 1.6
const HOLE_SECONDS := 6.0
const HOLE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float open = 0.0;
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
	ALBEDO = nebula + vec3(star) * (0.6 + 0.4 * sin(TIME * 6.0 + hash(floor(g)) * 30.0))
		+ vec3(1.0, 0.55, 0.15) * smoothstep(edge - 0.1, edge, r) * 2.5;
}
"""

var _shards: Array[MeshInstance3D] = []
var _velocity: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _age := 0.0
var _hole_material := ShaderMaterial.new()


## Breaks the wall in front of [param eye] along [param look]; shards fly along [param flow] (world).
static func burst(eye: Vector3, look: Vector3, flow: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(eye, eye + look * 6.0, Reality.REALITY_LAYER)
	var hit := App.stage.get_world_3d().direct_space_state.intersect_ray(query)
	var at: Vector3 = hit.position if hit else eye + look * 3.0
	var normal: Vector3 = hit.normal if hit else -look
	var effect := WallBreak.new()
	App.stage.add_child(effect)
	effect.global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD),
		at + normal * 0.02)
	effect._build(effect.global_basis.inverse() * flow)


func _build(flow: Vector3) -> void:
	var hole := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = HOLE_SIZE
	hole.mesh = quad
	_hole_material.shader = Shader.new()
	_hole_material.shader.code = HOLE
	hole.material_override = _hole_material
	add_child(hole)
	create_tween().tween_method(_open, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var cell := HOLE_SIZE / Vector2(GRID)
	var box := BoxMesh.new()
	box.size = Vector3(cell.x * 0.96, cell.y * 0.96, 0.04)
	for x in GRID.x:
		for y in GRID.y:
			var shard := MeshInstance3D.new()
			shard.mesh = box
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.82, 0.8, 0.76).darkened(randf() * 0.25)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shard.material_override = material
			shard.position = Vector3((x + 0.5) * cell.x - HOLE_SIZE.x * 0.5, (y + 0.5) * cell.y - HOLE_SIZE.y * 0.5, 0.03)
			add_child(shard)
			_shards.append(shard)
			# Out of the wall, along the flow, spread from the centre of the break.
			var spread := Vector3(shard.position.x, shard.position.y, 0.0) * 2.0
			_velocity.append(Vector3(0, 0, randf_range(1.2, 3.0)) + flow * randf_range(1.5, 3.5) + spread
				+ Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 1.2), 0.0))
			_spin.append(Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))
	_crash()


func _process(delta: float) -> void:
	_age += delta
	var gravity := global_basis.inverse() * GRAVITY
	var fade := clampf(1.0 - (_age - SHARD_SECONDS * 0.6) / (SHARD_SECONDS * 0.4), 0.0, 1.0)
	for i in _shards.size():
		_velocity[i] += gravity * delta
		_shards[i].position += _velocity[i] * delta
		_shards[i].rotation += _spin[i] * delta
		(_shards[i].material_override as StandardMaterial3D).albedo_color.a = fade
	if _age > SHARD_SECONDS and not _shards.is_empty():
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
