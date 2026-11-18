class_name Lantern
extends Node3D
## A hanging lantern for the workshop (Megan, Nov 18): Kay Lousberg's "Hanging Lantern" (CC0,
## content/props/lantern), unchanged, with a warm cream/amber glow added on top:
## * the glass glows (emission from the model's own glass colours only), and a soft warm halo sits in
##   front of it, so it looks lit even with the dynamic light off;
## * the glow breathes gently and irregularly (smooth noise, at most ±10 %: never a flash);
## * now and then one tiny ember rises from the roof and fades;
## * one small warm OmniLight3D (no shadows), only where [param light] is on and [member lights_on] allows.
## It never sways. While a game runs ([member quiet]), the glow holds steady and no embers rise:
## nothing moves on its own beside a task.
## The node's origin is the hang point (top of the chain); the lantern hangs below it.

const MODEL := "res://content/props/lantern/hanging_lantern.glb"
const GLASS_GLOW := preload("res://content/props/lantern/lantern_glass_emission.png")
## The model is 1.41 m tall with its chain; at 0.3 the lantern body is ~19 cm wide, 42 cm with the chain.
const SCALE := 0.3
## The middle of the glass, below the hang point (model: glass y −1.14…−0.80, chain top +0.10).
const GLASS := Vector3(0.0, -1.07 * SCALE, 0.0)
## The roof's vent, where embers leave.
const ROOF := Vector3(0.0, -0.47 * SCALE, 0.0)
const WARM := Color(1.0, 0.70, 0.42)         # cream-amber
const EMBER := Color(1.0, 0.62, 0.30)
const GLOW_ENERGY := 1.5
const FLICKER := 0.10                        # ±10 % at most, smooth
const FLICKER_SPEED := 0.55                  # noise samples per second: slow, irregular
const HALO_SIZE := 0.34
const HALO_ALPHA := 0.32
const LIGHT_ENERGY := 0.6
const LIGHT_RANGE := 1.3
## The lantern's own meshes sit on this render layer, which its light skips (a light 5 cm inside the
## body would blow the iron out to white).
const OWN_LAYER := 1 << 19
const EMBER_EVERY := Vector2(5.0, 11.0)      # seconds between embers (random in this range)
const EMBER_RISE := 0.14
const EMBER_SECONDS := 2.6
## The cauldron's lantern (its glass): this far behind the mouth, to its outer side, and above it (clear
## of the ring, 16 cm over the rim, and its fog, ~64 cm).
const CAULDRON_SPOT := Vector3(0.65, 0.6, 0.61)   # z +0.11 with the bubble menu (ABOVE_RIM 0.16 → 0.27), so it stays above it
## The wall lanterns: how many at most, how far from the wall, and their glass heights above the eyes.
const WALL_MAX := 3
const WALL_OUT := 0.16
const WALL_HEIGHTS: Array[float] = [0.35, 0.12, 0.55]
## Wall lanterns stay out of the middle of the view (the dots' field is ~40° wide), and within this.
const WALL_BEARING := Vector2(40.0, 80.0)
## Any two lanterns at least this far apart as seen from the child's eyes.
const APART_DEG := 22.0
## A wall lantern never shows near the games' ring: at least this far from the cauldron in the view.
const CLEAR_OF_RING_DEG := 30.0

## Which layout the hub hangs: &"high" (beams under the ceiling, small dim lanterns) or &"walls".
static var style := &"high"
## The Quest switch: false = no dynamic lights at all (the glow alone still reads).
static var lights_on := true
## True while a game runs: steady glow, no embers.
static var quiet := false
static var alive: Array[Lantern] = []
## Lanterns the reveal has already lit (Megan, Nov 18: they light up at the reveal, as the workshop wakes),
## with their rafters: the hub takes them on instead of hanging new ones (no pop, no jump).
static var from_reveal: Array[Lantern] = []
static var from_reveal_rafters: Node3D


## Hangs the workshop's lanterns in the current [member style] under [param parent] (unlit: [method appear]).
static func hang_style(parent: Node, mouth: Vector3, eye: Vector3, middle: Vector3) -> Array[Lantern]:
	if style == &"high":
		return hang_high(parent, eye, middle)
	return hang(parent, mouth, eye, middle)


## The reveal's lanterns, if any are still there: hands them (and the rafters) to [param parent] and forgets
## them. Empty when there was no reveal (a DEV jump).
static func take_from_reveal(parent: Node) -> Array[Lantern]:
	var taken: Array[Lantern] = []
	for lantern in from_reveal:
		if is_instance_valid(lantern):
			lantern.reparent(parent)
			taken.append(lantern)
	if is_instance_valid(from_reveal_rafters):
		from_reveal_rafters.reparent(parent)
	from_reveal.clear()
	from_reveal_rafters = null
	return taken

var lit := 1.0                               # 0..1, for fading in
var size := SCALE                            # the model's scale (the high lanterns are smaller)
var glow := 1.0                              # brightness, times GLOW_ENERGY / HALO_ALPHA (the high ones are dimmer)
var embers := true
var light: OmniLight3D
var _glass: StandardMaterial3D
var _halo: ShaderMaterial
var _noise := FastNoiseLite.new()
var _time := 0.0
var _calm := 0.0                             # 0 = breathing, 1 = steady (eases with [member quiet])
var _next_ember := 0.0
var _random := RandomNumberGenerator.new()


static func make(parent: Node, at: Vector3, with_light := true, scale_to := SCALE, brightness := 1.0, with_embers := true) -> Lantern:
	var lantern := Lantern.new()
	lantern.name = "Lantern"
	lantern.size = scale_to
	lantern.glow = brightness
	lantern.embers = with_embers
	parent.add_child(lantern)
	lantern.global_position = at
	lantern._build(with_light)
	return lantern


## Hangs the workshop's lanterns: one behind and above the cauldron, to its outer side (clear of the
## ring and its fog), with the only dynamic light; then up to [constant WALL_MAX] on the scanned walls
## at different heights, out of the middle of the view, each on a small iron bracket. No walls in the
## scan: only the cauldron's.
static func hang(parent: Node, mouth: Vector3, eye: Vector3, middle: Vector3) -> Array[Lantern]:
	var hung: Array[Lantern] = []
	var away := Vector3(mouth.x - eye.x, 0.0, mouth.z - eye.z).normalized()
	var side := away.cross(Vector3.UP).normalized()
	if side.dot(mouth - middle) < 0.0:
		side = -side                         # the cauldron's outer side, away from the table's middle
	var glass := mouth + away * CAULDRON_SPOT.x + side * CAULDRON_SPOT.y + Vector3.UP * CAULDRON_SPOT.z
	hung.append(make(parent, glass - GLASS, true))
	var ahead := Vector3(middle.x - eye.x, 0.0, middle.z - eye.z).normalized()
	var spots := _wall_spots(eye, ahead)
	var count := 0
	for spot: Dictionary in spots:
		if count == WALL_MAX:
			break
		var at: Vector3 = spot.point
		at.y = eye.y + WALL_HEIGHTS[count]
		var near := rad_to_deg((mouth - eye).angle_to(at - eye)) < CLEAR_OF_RING_DEG
		for other in hung:   # well apart in the room AND in the view (no cluster of lanterns)
			var there := other.global_position + GLASS
			near = near or there.distance_to(at) < 0.9 or rad_to_deg((there - eye).angle_to(at - eye)) < APART_DEG
		if near:
			continue
		var lantern := make(parent, at - GLASS, false)
		lantern.add_bracket(spot.normal)
		hung.append(lantern)
		count += 1
	return hung


## The "roof" version (Megan, Nov 18): a few dark wooden beams just under the real ceiling, with small,
## dim lanterns hanging from them, high and spread round the room: seen when the child looks up or around,
## never in the way. No dynamic light, no embers. The ceiling comes from the scan (&"ceiling"), else the
## floor + [constant ROOF_HEIGHT], else a guess from the seated eyes. Beams stop at scanned walls.
const ROOF_HEIGHT := 2.3
const BEAM_SIZE := Vector2(0.10, 0.13)       # width, height
const BEAM_ROWS: Array[float] = [-0.7, 0.7, 2.0]   # metres ahead of the eyes (one behind the child)
const BEAM_LENGTH := 4.4                     # without scanned walls
const BEAM_WOOD := Color(0.30, 0.20, 0.13)
const HIGH_SCALE := 0.2
const HIGH_GLOW := 0.6
const HIGH_DROP := -0.005                    # the chain's top ring (the model's top) just into the beam's underside: flush (Megan, Nov 18; was 0.15, which left the chain 13 cm short of the beam)
## Lantern spots, (row, metres to the side): spread round, none straight ahead.
const HIGH_SPOTS: Array[Vector2] = [Vector2(0, -1.1), Vector2(0, 1.3), Vector2(1, -1.5), Vector2(1, 1.0), Vector2(2, -1.1), Vector2(2, 1.3)]


static func hang_high(parent: Node, eye: Vector3, middle: Vector3) -> Array[Lantern]:
	var ahead := Vector3(middle.x - eye.x, 0.0, middle.z - eye.z).normalized()
	var right := ahead.cross(Vector3.UP).normalized()
	var top := _ceiling(eye) - 0.04
	var beams := Node3D.new()
	beams.name = "Rafters"
	parent.add_child(beams)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = BEAM_WOOD
	wood.roughness = 0.9
	var hung: Array[Lantern] = []
	for row in BEAM_ROWS.size():
		var centre := Vector3(eye.x, top - BEAM_SIZE.y * 0.5, eye.z) + ahead * BEAM_ROWS[row]
		var reach := _beam_reach(centre, right)
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(reach.y - reach.x, BEAM_SIZE.y, BEAM_SIZE.x)
		box.material = wood
		beam.mesh = box
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beams.add_child(beam)
		beam.global_transform = Transform3D(Basis(right, Vector3.UP, right.cross(Vector3.UP)), centre + right * (reach.x + reach.y) * 0.5)
		for spot in HIGH_SPOTS:
			if int(spot.x) != row or spot.y < reach.x + 0.2 or spot.y > reach.y - 0.2:
				continue
			var at := centre + right * spot.y + Vector3.DOWN * (BEAM_SIZE.y * 0.5 + HIGH_DROP)   # the model's top is its origin
			hung.append(make(parent, at, false, HIGH_SCALE, HIGH_GLOW, false))
	return hung


## The ceiling's height: scanned, else the floor + ROOF_HEIGHT, else from the seated eyes.
static func _ceiling(eye: Vector3) -> float:
	for ceiling: Surface in App.reality.surfaces(&"ceiling"):
		return maxf(ceiling.transform.origin.y, eye.y + 0.8)
	for floor_: Surface in App.reality.surfaces(&"floor"):
		return maxf(floor_.transform.origin.y + ROOF_HEIGHT, eye.y + 0.8)
	return eye.y + 1.15


## How far a beam through [param centre] along [param along] can run each way before a scanned wall.
static func _beam_reach(centre: Vector3, along: Vector3) -> Vector2:
	var reach := Vector2(-BEAM_LENGTH * 0.5, BEAM_LENGTH * 0.5)
	for wall: Surface in App.reality.surfaces(&"wall_face"):
		var frame := wall.transform
		var normal := frame.basis.y.normalized()
		var facing := along.dot(normal)
		if absf(facing) < 0.3:
			continue
		var t := (frame.origin - centre).dot(normal) / facing
		if t > 0.0:
			reach.y = minf(reach.y, t - 0.02)
		else:
			reach.x = maxf(reach.x, t + 0.02)
	return reach


## Candidate spots on the scanned walls, left and right in turn, nearer the middle bearing first.
static func _wall_spots(eye: Vector3, ahead: Vector3) -> Array[Dictionary]:
	var left: Array[Dictionary] = []
	var right: Array[Dictionary] = []
	for wall: Surface in App.reality.surfaces(&"wall_face"):
		var frame := wall.transform
		var normal := frame.basis.y.normalized()
		for i in 9:
			var u := lerpf(-0.8, 0.8, i / 8.0)
			var point := frame * Vector3(u * wall.size.x * 0.5, 0.0, 0.0) + normal * WALL_OUT
			var flat := Vector3(point.x - eye.x, 0.0, point.z - eye.z)
			if flat.length() < 0.9:
				continue
			var bearing := rad_to_deg(ahead.signed_angle_to(flat.normalized(), Vector3.UP))
			if absf(bearing) < WALL_BEARING.x or absf(bearing) > WALL_BEARING.y:
				continue
			var spot := {point = point, normal = normal, score = absf(absf(bearing) - 50.0)}
			(left if bearing > 0.0 else right).append(spot)
	left.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score < b.score)
	right.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score < b.score)
	var spots: Array[Dictionary] = []
	for i in maxi(left.size(), right.size()):
		if i < left.size():
			spots.append(left[i])
		if i < right.size():
			spots.append(right[i])
	return spots


static func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## A short iron arm from the wall to the chain's top (wall lanterns only). [param normal]: into the room.
func add_bracket(normal: Vector3) -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.25, 0.28, 0.30)
	iron.roughness = 0.8
	var arm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.018, 0.018, WALL_OUT + 0.01)
	box.material = iron
	arm.mesh = box
	add_child(arm)
	arm.look_at_from_position(global_position - normal * WALL_OUT * 0.5 + Vector3.UP * 0.01, global_position - normal * WALL_OUT, Vector3.UP)
	var plate := MeshInstance3D.new()
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(0.05, 0.08, 0.008)
	plate_box.material = iron
	plate.mesh = plate_box
	add_child(plate)
	plate.look_at_from_position(global_position - normal * WALL_OUT + Vector3.UP * 0.01, global_position - normal * (WALL_OUT + 1.0), Vector3.UP)


## The middle of the glass, from the hang point.
func glass_offset() -> Vector3:
	return GLASS * size / SCALE


## Fades the glow in from dark (on the Quest the model fades in too).
func appear(seconds := 1.5) -> void:
	lit = 0.0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.transparency = 1.0
		create_tween().tween_property(mesh, ^"transparency", 0.0, seconds * 0.6)
	create_tween().tween_property(self, ^"lit", 1.0, seconds).set_trans(Tween.TRANS_SINE)


func _build(with_light: bool) -> void:
	var model: Node3D = load(MODEL).instantiate()
	model.scale = Vector3.ONE * size
	model.position = Vector3(0.0, -0.10 * size, 0.0)
	add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = OWN_LAYER
		var base := mesh.get_active_material(0) as StandardMaterial3D
		if base == null:
			continue
		_glass = base.duplicate() as StandardMaterial3D
		_glass.emission_enabled = true
		_glass.emission_texture = GLASS_GLOW
		_glass.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # (ADD would add the colour everywhere)
		_glass.emission = WARM
		_glass.emission_energy_multiplier = GLOW_ENERGY
		mesh.set_surface_override_material(0, _glass)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * HALO_SIZE
	_halo = ShaderMaterial.new()
	_halo.shader = _halo_shader()
	_halo.set_shader_parameter(&"glow", Onion.soft_dot())
	_halo.set_shader_parameter(&"tint", Color(WARM, HALO_ALPHA))
	quad.material = _halo
	halo.mesh = quad
	halo.name = "halo"
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = glass_offset()
	halo.scale = Vector3.ONE * size / SCALE
	add_child(halo)
	if with_light and lights_on:
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.74, 0.45)
		light.light_energy = LIGHT_ENERGY
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.light_bake_mode = Light3D.BAKE_DISABLED
		light.light_cull_mask = 0xFFFFF & ~OWN_LAYER
		light.position = glass_offset()
		add_child(light)
	_random.randomize()
	_noise.seed = _random.randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_octaves = 2
	_time = _random.randf_range(0.0, 100.0)
	_next_ember = _random.randf_range(EMBER_EVERY.x * 0.5, EMBER_EVERY.y)
	_apply(1.0)


func _enter_tree() -> void:
	alive.append(self)


func _exit_tree() -> void:
	alive.erase(self)


func _process(delta: float) -> void:
	_time += delta * FLICKER_SPEED
	_calm = move_toward(_calm, 1.0 if quiet else 0.0, delta)   # eases over ~1 s
	var breathe := _noise.get_noise_1d(_time) * 1.6   # ~−1..1
	_apply(1.0 + clampf(breathe, -1.0, 1.0) * FLICKER * (1.0 - _calm))
	if quiet or not embers or lit < 1.0 or not is_visible_in_tree():
		return
	_next_ember -= delta
	if _next_ember <= 0.0:
		_next_ember = _random.randf_range(EMBER_EVERY.x, EMBER_EVERY.y)
		_ember()


func _apply(bright: float) -> void:
	var level := bright * lit * glow
	if _glass != null:
		_glass.emission_energy_multiplier = GLOW_ENERGY * level
	if _halo != null:
		_halo.set_shader_parameter(&"tint", Color(WARM, HALO_ALPHA * level))
	if light != null:
		light.light_energy = LIGHT_ENERGY * level


## One tiny ember: rises from the roof with a slight drift, fades, and is gone.
func _ember() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_texture = Onion.soft_dot()
	mat.albedo_color = Color(EMBER, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.014
	quad.material = mat
	var dot := MeshInstance3D.new()
	dot.name = "ember"
	dot.mesh = quad
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.position = ROOF * size / SCALE + Vector3(_random.randf_range(-0.02, 0.02), 0.0, _random.randf_range(-0.02, 0.02))
	add_child(dot)
	var drift := Vector3(_random.randf_range(-0.025, 0.025), EMBER_RISE * _random.randf_range(0.8, 1.1), _random.randf_range(-0.025, 0.025))
	var tween := dot.create_tween().set_parallel()
	tween.tween_property(dot, ^"position", dot.position + drift, EMBER_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, ^"albedo_color:a", 0.9, EMBER_SECONDS * 0.2)
	tween.chain().tween_property(mat, ^"albedo_color:a", 0.0, EMBER_SECONDS * 0.8)
	tween.chain().tween_callback(dot.queue_free)


## A soft warm billboard pulled a little toward the viewer, so the lantern's own body doesn't cut it in half.
static func _halo_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D glow : source_color, filter_linear;
uniform vec4 tint : source_color;
void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 toward = normalize(-centre);
	float size = length(MODEL_MATRIX[0].xyz);
	VERTEX = centre + vec3(VERTEX.xy * size, 0.0) + toward * 0.12;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}
void fragment() {
	vec4 g = texture(glow, UV);
	ALBEDO = tint.rgb * g.a * tint.a;
	ALPHA = 1.0;
}
"""
	return shader
