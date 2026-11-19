class_name HubGlow
extends Node3D
## A soft pool of light around the gear after the reveal. The hub fades it and the menu halos before a game.

const TINT := Color(1.0, 0.86, 0.55)
const BREATH_SECONDS := 4.0
## Every glow alive now (for [method quiet_all]).
static var _alive: Array[HubGlow] = []

var _pool_light: StandardMaterial3D
var _quieting := false


func _enter_tree() -> void:
	_alive.append(self)


func _exit_tree() -> void:
	_alive.erase(self)


## Fades every glow out and frees it. Await it before a task starts.
static func quiet_all(seconds := 0.8) -> void:
	var glows := _alive.duplicate()
	for glow: HubGlow in glows:
		glow.quiet(seconds)
	var rings := ImpressionRing.alive.duplicate()
	for ring: ImpressionRing in rings:   # the hub's ring of choices: its halos too
		ring.quiet(seconds)
	var any: Node = glows[0] if not glows.is_empty() else (rings[0] if not rings.is_empty() else null)
	if any:
		await any.get_tree().create_timer(seconds + 0.05).timeout


## True while any glow is lit (for tests and the Hub's checks).
static func any_lit() -> bool:
	return _alive.any(func(glow: HubGlow) -> bool: return glow.is_lit()) \
			or ImpressionRing.alive.any(func(ring: ImpressionRing) -> bool: return ring.is_lit())


## A breathing pool round [param socket] for [param seconds], then it fades and frees itself.
static func afterglow(parent: Node, socket: Vector3, seconds := 3.0) -> HubGlow:
	var glow := HubGlow.new()
	glow.name = "hub_glow_afterglow"
	parent.add_child(glow)
	glow._make_pool(socket, 0.36)
	var tween := glow.create_tween()
	tween.tween_method(glow._breathe, 0.0, seconds, seconds)
	tween.tween_callback(glow.quiet.bind(0.8))
	return glow


## Fades this glow out over [param seconds] and frees it.
func quiet(seconds := 0.8) -> void:
	if _quieting:
		return
	_quieting = true
	var tween := create_tween()
	tween.tween_property(_pool_light, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(queue_free)


func is_lit() -> bool:
	return _pool_light.albedo_color.a > 0.003


func _breathe(t: float) -> void:
	if _quieting:
		return
	var rise := clampf(t / 1.0, 0.0, 1.0)   # fades in over 1 s (no step over 10 % in 0.1 s)
	_pool_light.albedo_color.a = rise * (0.55 + 0.12 * sin(TAU * t / BREATH_SECONDS))


func _make_pool(at: Vector3, size: float) -> void:
	var pool := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.orientation = PlaneMesh.FACE_Y
	_pool_light = StandardMaterial3D.new()
	_pool_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_light.albedo_texture = Onion.soft_dot()
	_pool_light.albedo_color = Color(TINT, 0.0)
	quad.material = _pool_light
	pool.mesh = quad
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	pool.global_position = at + Vector3.UP * 0.004
