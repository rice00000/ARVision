class_name PopBurst
extends Node3D
## Hello's playful pop (Effects chat, Nov 17; Megan approved "Playful Pop + subtle clockwork magic"):
## as Onion pops out of the cauldron (pop A), a few small bubbles of the brew lift off the mouth, drift
## up a few centimetres, swell a little and fade. Seven bubbles, under a second, no flash, nothing near
## the eyes. Texture: Kenney's Particle Pack (CC0) when it's in [constant KENNEY], else a soft ring.

const KENNEY := "res://entry/fx/kenney/"
## The Kenney textures tried, in order (the pack's file names); the first one found is used.
const TEXTURES := ["circle_01.png", "circle_02.png"]
const COUNT := 7
const SECONDS := 0.9
const TINT := Color(0.86, 0.97, 0.88)   # the sage brew, lightened

static var _ring: Texture2D


## Bubbles from [param mouth] (the brew's middle) under [param parent]; frees itself.
static func play(parent: Node, mouth: Vector3, radius := 0.04, seed := 1) -> PopBurst:
	var burst := PopBurst.new()
	burst.name = "pop_burst"
	parent.add_child(burst)
	burst.global_position = mouth
	burst._start(radius, seed)
	return burst


static func texture() -> Texture2D:
	for file: String in TEXTURES:
		if ResourceLoader.exists(KENNEY + file):
			return load(KENNEY + file)
	if _ring == null:   # stand-in: a soft ring, like a bubble's edge
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 0.93, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
		var ring := GradientTexture2D.new()
		ring.gradient = gradient
		ring.fill = GradientTexture2D.FILL_RADIAL
		ring.fill_from = Vector2(0.5, 0.5)
		ring.fill_to = Vector2(1.0, 0.5)
		ring.width = 64
		ring.height = 64
		_ring = ring
	return _ring


func _start(radius: float, seed: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var tex := texture()
	for i in COUNT:
		var bubble := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * random.randf_range(0.018, 0.032)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_texture = tex
		material.albedo_color = Color(TINT, 0.0)
		quad.material = material
		bubble.mesh = quad
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bubble)
		var angle := TAU * i / COUNT + random.randf_range(-0.3, 0.3)
		var start := Vector3(cos(angle), 0.0, sin(angle)) * radius * random.randf_range(0.2, 0.7) + Vector3.UP * 0.01
		var end := start * 1.6 + Vector3.UP * random.randf_range(0.05, 0.09)
		bubble.position = start
		bubble.scale = Vector3.ONE * 0.6
		var delay := random.randf_range(0.0, 0.12)
		var seconds := SECONDS * random.randf_range(0.75, 1.0)
		var tween := create_tween().set_parallel()
		tween.tween_property(bubble, "position", end, seconds).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(bubble, "scale", Vector3.ONE * 1.1, seconds).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.85, seconds * 0.2).set_delay(delay)
		tween.tween_property(material, "albedo_color:a", 0.0, seconds * 0.8).set_delay(delay + seconds * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var done := create_tween()
	done.tween_interval(SECONDS + 0.2)
	done.tween_callback(queue_free)
