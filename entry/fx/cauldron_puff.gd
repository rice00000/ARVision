class_name CauldronPuff
extends Node3D
## Scene 6, the reveal (Megan's scene review, Nov 17): the cauldron answers the light. When the band
## reaches it, a small warm puff leaves its mouth, rises about 20 cm, spreads and thins out, and is gone
## in about 3 s. Soft and slow: a few large translucent warm blobs, no sparkles, no flash. Mixed
## blending (over passthrough an added glow can vanish), like Onion's halo.
##
##   CauldronPuff.play(parent, mouth, mouth_radius)   # then `await puff.finished` if you need the end

signal finished

const SECONDS := 3.0
const RISE := 0.20          # metres the puff's middle rises
const BLOBS := 5
const START_SIZE := 0.05    # a blob's diameter as it leaves the mouth, metres
const END_SIZE := 0.16      # and as it thins out
const PEAK := 0.32          # its most solid (soft: never a flash)
const TINT := Color(1.0, 0.86, 0.62)   # warm, like the reveal's band

var _blobs: Array[Dictionary] = []   # {node, material, from, to, delay}
var _clock := 0.0


## A puff from [param mouth] (the brew's middle, world) under [param parent]; frees itself after.
static func play(parent: Node, mouth: Vector3, radius := 0.04, seed_value := 3) -> CauldronPuff:
	var puff := CauldronPuff.new()
	puff.name = "cauldron_puff"
	parent.add_child(puff)
	puff.global_position = mouth
	puff._make(radius, seed_value)
	return puff


## How solid the puff is now, 0..1 of [constant PEAK] (tests and pictures).
func strength() -> float:
	var most := 0.0
	for b in _blobs:
		most = maxf(most, ((b.material as StandardMaterial3D).albedo_color.a))
	return most / PEAK


func _make(radius: float, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for i in BLOBS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.albedo_texture = Onion.soft_dot()
		material.albedo_color = Color(TINT, 0.0)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = material
		var blob := MeshInstance3D.new()
		blob.mesh = quad
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blob.scale = Vector3.ONE * START_SIZE
		add_child(blob)
		var angle := TAU * i / BLOBS + random.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var from := out * radius * random.randf_range(0.0, 0.5) + Vector3.UP * 0.01
		var to := out * random.randf_range(0.04, 0.08) + Vector3.UP * RISE * random.randf_range(0.8, 1.15)
		blob.position = from
		_blobs.append({node = blob, material = material, from = from, to = to, delay = random.randf_range(0.0, 0.35)})


func _process(delta: float) -> void:
	_clock += delta
	for b in _blobs:
		var life: float = SECONDS - b.delay
		var t := clampf((_clock - b.delay) / life, 0.0, 1.0)
		var blob: Node3D = b.node
		var up := 1.0 - pow(1.0 - t, 2.2)   # leaves the mouth briskly, slows as it spreads
		blob.position = (b.from as Vector3).lerp(b.to, up)
		blob.scale = Vector3.ONE * lerpf(START_SIZE, END_SIZE, up)
		var fade := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.45, 1.0, t))   # in quickly, thins out slowly
		(b.material as StandardMaterial3D).albedo_color.a = PEAK * fade
	if _clock >= SECONDS:
		finished.emit()
		queue_free()
