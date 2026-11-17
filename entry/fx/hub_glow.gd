class_name HubGlow
extends Node3D
## The workshop's quiet magic between tasks (Effects chat, Nov 17; Megan: "C + a short A"):
## * A, [method afterglow]: a soft warm pool round the seated gear as the reveal ends, breathing very
##   slowly (one breath in 4 s), gone by itself after a few seconds;
## * C, [method offer]: each impression on a still pool of light while it waits; the pool brightens as a
##   hand comes near ([method near]). It doubles as the "you can touch this" cue.
## Rule: nothing of it is lit while a task runs. The Hub calls [code]await HubGlow.quiet_all()[/code]
## before every activity starts; tests check that it leaves nothing lit.

const TINT := Color(1.0, 0.86, 0.55)
const BREATH_SECONDS := 4.0
## Every glow alive now (for [method quiet_all]).
static var _alive: Array[HubGlow] = []

var _impressions: Array[Impression] = []
var _pool: MeshInstance3D
var _pool_light: StandardMaterial3D
var _quieting := false


func _enter_tree() -> void:
	_alive.append(self)


func _exit_tree() -> void:
	_alive.erase(self)
	for impression in _impressions:
		if is_instance_valid(impression):
			impression.set_waiting(0.0)


## Fades every glow out and frees it. Await it before a task starts.
static func quiet_all(seconds := 0.8) -> void:
	var glows := _alive.duplicate()
	for glow: HubGlow in glows:
		glow.quiet(seconds)
	if not glows.is_empty():
		await (glows[0] as Node).get_tree().create_timer(seconds + 0.05).timeout


## True while any glow is lit (for tests and the Hub's checks).
static func any_lit() -> bool:
	return _alive.any(func(glow: HubGlow) -> bool: return glow.is_lit())


## Glow A: a breathing pool round [param socket] for [param seconds], then it fades and frees itself.
static func afterglow(parent: Node, socket: Vector3, seconds := 3.0) -> HubGlow:
	var glow := HubGlow.new()
	glow.name = "hub_glow_afterglow"
	parent.add_child(glow)
	glow._make_pool(socket, 0.36)
	var tween := glow.create_tween()
	tween.tween_method(glow._breathe, 0.0, seconds, seconds)
	tween.tween_callback(glow.quiet.bind(0.8))
	return glow


## Glow C: [param impressions] wait on their pools of light (fading in over [param seconds]).
static func offer(parent: Node, impressions: Array[Impression], seconds := 0.6) -> HubGlow:
	var glow := HubGlow.new()
	glow.name = "hub_glow_offer"
	parent.add_child(glow)
	glow._impressions = impressions
	glow.create_tween().tween_method(func(f: float) -> void:
		for impression in glow._impressions:
			if is_instance_valid(impression):
				impression.set_waiting(f), 0.0, 1.0, seconds)
	return glow


## A hand is [param amount] near [param impression] (0 far .. 1 touching): its pool brightens.
func near(impression: Impression, amount: float) -> void:
	if not _quieting and impression in _impressions:
		impression.set_near(amount)


## Fades this glow out over [param seconds] and frees it.
func quiet(seconds := 0.8) -> void:
	if _quieting:
		return
	_quieting = true
	var start := _pool_light.albedo_color.a if _pool_light else 0.0
	var tween := create_tween()
	tween.tween_method(func(f: float) -> void:
		if _pool_light:
			_pool_light.albedo_color.a = start * f
		for impression in _impressions:
			if is_instance_valid(impression):
				impression.set_waiting(f), 1.0, 0.0, seconds)
	tween.tween_callback(queue_free)


func is_lit() -> bool:
	if _pool_light and _pool_light.albedo_color.a > 0.003:
		return true
	return _impressions.any(func(i: Impression) -> bool: return is_instance_valid(i) and i._waiting > 0.0)


func _breathe(t: float) -> void:
	if _quieting:
		return
	var rise := clampf(t / 1.0, 0.0, 1.0)   # fades in over 1 s (no step over 10 % in 0.1 s)
	_pool_light.albedo_color.a = rise * (0.55 + 0.12 * sin(TAU * t / BREATH_SECONDS))


func _make_pool(at: Vector3, size: float) -> void:
	_pool = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.orientation = PlaneMesh.FACE_Y
	_pool_light = StandardMaterial3D.new()
	_pool_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_light.albedo_texture = Onion.soft_dot()
	_pool_light.albedo_color = Color(TINT, 0.0)
	quad.material = _pool_light
	_pool.mesh = quad
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)
	_pool.global_position = at + Vector3.UP * 0.004
