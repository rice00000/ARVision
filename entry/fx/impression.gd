class_name Impression
extends Node3D
## The small, solid stand-in for one hub activity (Effects chat, Nov 17): what the child touches to choose
## it. Big (12-16 cm), solid, one strong colour each with a dark outline, and a silhouette of its own, so
## telling them apart is never a vision test: the shelf is a square frame, the dots a cloud,
## the cup a cup with a handle. Their sounds differ too (see [method touched]).
##
## The hub asks for one through [method make] from [code]Summonable.make_impression()[/code]. In the
## hub they float in a ring above the cauldron ([ImpressionRing], Megan Nov 17): a soft halo behind the
## front one (waiting), a softer one on any the hand aims at or comes near ([method set_near]).

## &"shelf", &"dots" or &"turn_to_fit".
var kind := &""
## Its own name, when it isn't its kind's (a level in a game's row: "Size Match"); see [method label].
var title := ""
## The single level this bubble represents, if any.
var level: TaskLevel
## A look bubble's look (&"normal", &"high_contrast", &"edges", &"black_white"), or &"".
var look := &""
## The shelf piece's rows (1..4): it grows a row with each shelf level finished (design chat, Nov 18).
var rows := 2
## The size it stands at (the mesh's own size is its full size).
var size := Vector3.ONE

## Not selectable yet (see [method set_sealed]).
var sealed := false
const SEALED_SCALE := 0.75
var _band: MeshInstance3D
var _waiting := 0.0
var _near := 0.0
var _sounds: Sounds
var _halo: MeshInstance3D
var _halo_light: StandardMaterial3D
var _body: Node3D
## Its bubble in the hub's menu (Megan, Nov 18): a frosted backing, a clear shell, a pale rim and one still
## highlight round the piece. Null until [method add_bubble].
var bubble: Node3D
var _shell_light: StandardMaterial3D
var _frost_light: StandardMaterial3D
var _difficulty_bar: MeshInstance3D
## The hover cue (Megan, Nov 18 5:29, option B): a warm glow round the outside of the bubble, its rim turning gold,
## and the bubble swelling a little ([member swell], applied by the ring). The old halo sat behind the frost, unseen.
const HOVER_GOLD := Color(0.79, 0.54, 0.12)          # the rim at full hover (#C98A1E)
const HOVER_BRASS := Color(1.0, 0.80, 0.38)          # the house's brass rim, brightened
const HOVER_SWELL := 0.08                            # +8 % at full hover
var _rim_light: StandardMaterial3D
var _rim_colour: Color
var _outer_glow: MeshInstance3D
var _outer_glow_light: ShaderMaterial
## 0..1, eased toward how near the hand is: the ring scales the bubble by 1 + HOVER_SWELL * swell.
var swell := 0.0
## The size the ring last placed it at (before the swell).
var base_size := 0.0
## What a pinch or touch hits: id [code]impression_<kind>[/code] (the hub hears it through
## [signal Events.selected] / [signal Events.touched] and passes it to [method ImpressionRing.press]).
var target: Target
## The target's layer while the piece is visible.
var target_layer := Pointer.TARGET_LAYER

const OUTLINE := Color(0.06, 0.05, 0.05)
const WOOD := Color(0.42, 0.25, 0.12)
const CREAM := Color(0.97, 0.93, 0.82)
const NAVY := Color(0.10, 0.14, 0.34)
const NIGHT := Color(0.13, 0.15, 0.24)   # the dots icon's cloud: the dimmed room of the dots game
const ICE := Color(0.78, 0.94, 1.0)      # the dots game's own pale icy-blue dots
const CUP := Color(0.96, 0.95, 0.92)   # near-white: the orange first tried had the table's brightness (lost without colour)
const CUP_INSIDE := Color(0.86, 0.42, 0.22)
const GLOW := Color(1.0, 0.86, 0.55)


## A new impression of [param of_kind], standing on its base at its origin, front (+Z) to the child.
static func make(of_kind: StringName) -> Impression:
	var impression := Impression.new()
	impression.kind = of_kind
	impression.name = "impression_%s" % of_kind
	impression._body = Node3D.new()
	impression.add_child(impression._body)
	match of_kind:
		&"shelf":
			impression._shelf()
		&"dots":
			impression._dots_cloud()
		&"turn_to_fit":
			impression._cup()
		&"house":
			impression._house()
		&"butterflies":
			impression._butterfly()
		&"stop", &"finish":
			impression._cross()
		&"help":
			impression._question()
		&"eye":
			impression._eye()
	impression._make_halo()
	impression.target = Target.sphere(StringName("impression_%s" % of_kind), 0.1)
	impression.target.position.y = 0.075
	impression.add_child(impression.target)
	return impression


func _ready() -> void:
	visibility_changed.connect(_sync_target)
	_sync_target()


func _sync_target() -> void:
	target.collision_layer = target_layer if is_visible_in_tree() else 0


## A game's impression drawn from a level's card ([param picture], LevelPiece.drawn): the games made from Wei's
## tasks (TaskActivity) that have no piece of their own.
static func make_drawn(of_kind: StringName, picture: Texture2D) -> Impression:
	var impression := make(of_kind)
	impression._body.add_child(LevelPiece.drawn(picture, of_kind))
	return impression


## Its base on the table, metres (x across, y = depth), for the hub's spacing.
static func footprint(of_kind: StringName) -> Vector2:
	match of_kind:
		&"shelf":
			return Vector2(0.16, 0.08)
		&"dots":
			return Vector2(0.19, 0.05)
		&"turn_to_fit":
			return Vector2(0.16, 0.12)
		&"house":
			return Vector2(0.12, 0.06)
		&"stop", &"finish", &"help", &"eye", &"look":
			return Vector2(0.12, 0.03)
		&"butterflies":
			return Vector2(0.15, 0.04)
	return Vector2(0.16, 0.16)


## The soft halo behind it while it waits to be chosen (the ring's front one); 0 = off.
func set_waiting(strength: float) -> void:
	_waiting = clampf(strength, 0.0, 1.0)
	_update_halo()


## 0..1 as the hand aims at it or comes close (the "that one" cue): a softer halo, on any choice,
## side ones too. Choosing stays a press.
func set_near(amount: float) -> void:
	_near = clampf(amount, 0.0, 1.0)
	_update_halo()


## Just its own sound (the ring plays it when a turn brings this one to the front).
func sound() -> void:
	if _sounds == null:
		_sounds = Sounds.new()
		add_child(_sounds)
	_sounds.play(StringName("impression_%s" % kind), global_position)


## The child chose it: its own sound and a short warm pulse, the "I heard you" acknowledgement.
func touched() -> void:
	sound()
	var pulse := create_tween()
	pulse.tween_property(_body, "scale", Vector3.ONE * 1.08, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(_body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	PlaceSignal.play(self, global_position, Vector3.UP, 0.1, false)


## Sealed (story chat, Nov 17: shown but not selectable yet): it sits smaller inside a brass band and
## gets no glow. The difference is size, a solid band and no light, never a faint or greyed look (that
## would make "can I pick it?" a contrast test). [method unseal] opens it with a sound and a pulse.
func set_sealed(on: bool) -> void:
	sealed = on
	_body.scale = Vector3.ONE * (SEALED_SCALE if on else 1.0)
	if bubble != null:   # in the bubble menu: a closed bubble, frostier, with a padlock badge (Megan, Nov 18)
		_shell_light.albedo_color.a = 0.45 if on else 0.12
		_frost_light.albedo_color.a = 0.85 if on else 0.6
		if on and _lock == null:
			_make_lock()
		if _lock != null:
			_lock.visible = on
		_update_halo()
		return
	if on and _band == null:
		_band = MeshInstance3D.new()
		var torus := TorusMesh.new()
		var radius := maxf(footprint(kind).x, footprint(kind).y) * 0.5 + 0.02
		torus.inner_radius = radius
		torus.outer_radius = radius + 0.014
		_band.mesh = torus
		_band.material_override = _lit(Color(0.72, 0.55, 0.25), true)
		_band.position.y = 0.007
		add_child(_band)
	if _band:
		_band.visible = on
	_update_halo()


## Opens a sealed impression: the band drops away, it grows to full size, its sound and a pulse.
func unseal(seconds := 0.8) -> void:
	if not sealed:
		return
	sealed = false
	if _sounds == null:
		_sounds = Sounds.new()
		add_child(_sounds)
	if _lock != null and _lock.visible:
		# The unlock, made explicit (Megan, Nov 18): the shackle clicks open, the lock drops away and fades;
		# then the frost clears and the piece grows to full size with its sparkle (below).
		_sounds.play(&"lock_click", global_position)   # the shackle springs open
		var click := create_tween()
		click.tween_property(_shackle, "position:y", _shackle.position.y + 0.012, 0.25).set_trans(Tween.TRANS_SINE)
		click.parallel().tween_property(_shackle, "rotation:y", 0.9, 0.25)
		click.tween_interval(0.15)
		var start := _lock.position
		click.tween_method(func(m: float) -> void:
			_lock.position = start + Vector3.DOWN * 0.09 * m * m
			for mesh: GeometryInstance3D in _lock.find_children("*", "GeometryInstance3D", true, false):
				mesh.transparency = m, 0.0, 1.0, 0.7)
		click.tween_callback(func() -> void:
			_lock.visible = false
			_lock.position = start
			_shackle.position.y -= 0.012
			_shackle.rotation.y = 0.0
			for mesh: GeometryInstance3D in _lock.find_children("*", "GeometryInstance3D", true, false):
				mesh.transparency = 0.0)
		await get_tree().create_timer(0.4).timeout
	_sounds.play(&"unlock", global_position)   # a sparkly "it opened"
	var open := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	open.tween_property(_body, "scale", Vector3.ONE, seconds)
	if bubble != null:   # the bubble clears
		open.tween_property(_shell_light, "albedo_color:a", 0.12, seconds)
		open.tween_property(_frost_light, "albedo_color:a", 0.6, seconds)
	if _band:
		open.tween_property(_band, "scale", Vector3(1.3, 0.2, 1.3), seconds * 0.6)
		open.chain().tween_callback(func() -> void: _band.visible = false; _band.scale = Vector3.ONE)
	touched()
	_update_halo()


func _update_halo() -> void:
	if bubble != null and _rim_light != null:
		var hover := 0.0 if sealed else _near
		_outer_glow.visible = hover > 0.01
		_outer_glow_light.set_shader_parameter(&"strength", hover)
		_rim_light.albedo_color = _rim_colour.lerp(HOVER_BRASS if kind == &"house" else HOVER_GOLD, hover)
	if sealed:
		_halo.visible = false
		return
	var alpha := 0.5 * _waiting + 0.3 * _near
	_halo.visible = alpha > 0.0
	_halo_light.albedo_color.a = alpha


# --- The bubble (the hub's menu, Megan Nov 18) -----------------------------------------------------

const BUBBLE_RADIUS := 0.125        # round the piece's middle (pieces 12-16 cm wide, up to 8 cm deep: they fit inside from any side; Megan, Nov 18: the shelf poked out at 0.11)
const MIDDLE := Vector3(0.0, 0.075, 0.0)
const DIFFICULTY_ARC := preload("res://entry/fx/bubble_difficulty.gdshader")
const FROST := Color(0.96, 0.97, 0.96)
const RIM := Color(0.36, 0.36, 0.35)
const BRASS := Color(0.74, 0.56, 0.24)   # the house's porthole rim: a place, not a game
const POP_DROPS := 7
## What the chosen bubble's title says (and the sound label).
const TITLES := {&"shelf": "Find Objects", &"dots": "The Dots", &"turn_to_fit": "Turn to Fit", &"house": "Virtual Workshop", &"butterflies": "Butterflies",
		&"real_life": "Real Life", &"odd_color": "Odd Color",
		&"stop": "Stop", &"finish": "Finish", &"help": "Help", &"eye": "Looks"}
## The looks the eye offers (design chat, Nov 18, DESIGN_STONES_AND_LEVELS §6): their names, said and shown.
const LOOK_TITLES := {&"normal": "Normal", &"high_contrast": "High contrast", &"edges": "Edges", &"black_white": "Black and white",
		&"greyscale": "Greyscale", &"dim": "Dim room", &"spotlight": "Spotlight"}
const INK := Color(0.114, 0.114, 0.133)   # #1D1D22 (design chat, Nov 18)
const TILE := Color(0.953, 0.918, 0.824)  # #F3EAD2


## Its name, shown and said: its own [member title], else its kind's.
func label() -> String:
	return title if title != "" else title_for(kind)


## The name shown and said for [param of_kind].
static func title_for(of_kind: StringName) -> String:
	return TITLES.get(of_kind, String(of_kind).capitalize())


## Puts the piece in its menu bubble: a milky frosted backing behind it (figure-ground on any wall; the piece's
## own dark outline does the rest), a nearly clear shell, a thin darker rim and one still highlight. No colour
## of its own, no shimmer, no wobble.
func add_bubble() -> void:
	if bubble != null:
		return
	bubble = Node3D.new()
	bubble.name = "bubble"
	add_child(bubble)
	bubble.position = MIDDLE
	_frost_light = _flat(FROST, 0.6)
	var frost := _disc(BUBBLE_RADIUS * 0.94, _frost_light)
	frost.position.z = -0.045
	bubble.add_child(frost)
	_shell_light = StandardMaterial3D.new()
	_shell_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_light.albedo_color = Color(0.92, 0.97, 0.96, 0.12)
	_shell_light.roughness = 0.1
	_shell_light.metallic_specular = 1.0
	_shell_light.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var shell := MeshInstance3D.new()
	shell.name = "shell"
	var ball := SphereMesh.new()
	ball.radius = BUBBLE_RADIUS
	ball.height = BUBBLE_RADIUS * 2.0
	ball.radial_segments = 40
	ball.rings = 20
	shell.mesh = ball
	shell.material_override = _shell_light
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.scale.z = 0.72   # a lens more than a ball, deep enough that the piece never pokes out
	bubble.add_child(shell)
	var rim := MeshInstance3D.new()
	rim.name = "rim"
	var torus := TorusMesh.new()
	torus.inner_radius = BUBBLE_RADIUS * 0.97
	torus.outer_radius = BUBBLE_RADIUS * 1.02
	rim.mesh = torus
	if kind == &"house":
		torus.inner_radius = BUBBLE_RADIUS * 0.95
		torus.outer_radius = BUBBLE_RADIUS * 1.06   # a thicker brass porthole
	_rim_light = _lit(BRASS, true) if kind == &"house" else _flat(RIM, 1.0)
	_rim_colour = _rim_light.albedo_color
	rim.material_override = _rim_light
	rim.rotation.x = PI * 0.5   # in the bubble's face
	bubble.add_child(rim)
	_outer_glow = _make_outer_glow()
	bubble.add_child(_outer_glow)
	var shine := _disc(BUBBLE_RADIUS * 0.12, _flat(Color.WHITE, 0.85))
	shine.position = Vector3(-0.45, 0.45, 0.6) * BUBBLE_RADIUS
	bubble.add_child(shine)
	(target.get_child(0) as CollisionShape3D).shape.set(&"radius", BUBBLE_RADIUS)   # the whole bubble answers
	_halo.position = MIDDLE + Vector3(0.0, 0.0, -0.05)
	if level != null and not level.staircase().is_empty():
		_refresh_difficulty_bar()
		Events.reported.connect(_on_difficulty_changed)


func _on_difficulty_changed(what: StringName, _data: Dictionary) -> void:
	match what:
		&"level", &"level_set", &"vision_changed":
			_refresh_difficulty_bar()


## A gold arc under the picture shows the child's current position on this level's staircase.
func _refresh_difficulty_bar() -> void:
	var climbed := level.climbed()
	if climbed < 0.0 or not level.played():
		if _difficulty_bar != null:
			_difficulty_bar.hide()
		return
	if _difficulty_bar == null:
		_difficulty_bar = MeshInstance3D.new()
		_difficulty_bar.name = "DifficultyBar"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * BUBBLE_RADIUS * 2.0
		_difficulty_bar.mesh = quad
		var paint := ShaderMaterial.new()
		paint.shader = DIFFICULTY_ARC
		paint.set_shader_parameter(&"track_colour", INK)
		paint.set_shader_parameter(&"fill_colour", HOVER_BRASS)
		_difficulty_bar.material_override = paint
		_difficulty_bar.position.z = 0.025
		_difficulty_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble.add_child(_difficulty_bar)
	var paint := _difficulty_bar.material_override as ShaderMaterial
	paint.set_shader_parameter(&"progress", climbed)
	_difficulty_bar.show()


## The hover glow: a soft warm ring just outside the bubble's rim, fading out over ~6 cm (at scale 1).
func _make_outer_glow() -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = "hover_glow"
	var quad := QuadMesh.new()
	var reach := BUBBLE_RADIUS * 1.5
	quad.size = Vector2.ONE * reach * 2.0
	glow.mesh = quad
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 colour : source_color = vec4(1.0, 0.78, 0.44, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.66;   // the rim, as a share of the quad's half-width
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float ring = smoothstep(inner - 0.03, inner + 0.01, d) * (1.0 - smoothstep(inner, 1.0, d));
	ALBEDO = colour.rgb;
	ALPHA = colour.a * strength * 0.85 * ring;
}
"""
	_outer_glow_light = ShaderMaterial.new()
	_outer_glow_light.shader = shader
	_outer_glow_light.set_shader_parameter(&"inner", BUBBLE_RADIUS * 0.99 / reach)
	glow.material_override = _outer_glow_light
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.z = -0.02
	glow.visible = false
	return glow


## The chosen bubble pops (Megan, Nov 18): the shell swells a little and bursts into a ring of small droplets
## that fly out a few centimetres and vanish (~0.3 s), with a bright pop. The piece stays still in place.
func pop() -> void:
	if bubble == null:
		return
	if _sounds == null:
		_sounds = Sounds.new()
		add_child(_sounds)
	_sounds.play(&"bubble_pop", global_position)
	var drops := Node3D.new()
	drops.name = "pop_drops"
	add_child(drops)
	drops.position = MIDDLE
	var drop_light := _lit(FROST, true)
	for i in POP_DROPS:
		var drop := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.009
		ball.height = 0.018
		drop.mesh = ball
		drop.material_override = drop_light
		var angle := TAU * i / POP_DROPS + 0.3
		drop.position = Vector3(cos(angle), sin(angle), 0.0) * BUBBLE_RADIUS * 0.95
		drops.add_child(drop)
	var burst := create_tween()
	burst.tween_method(func(k: float) -> void:
		for i in drops.get_child_count():
			var angle := TAU * i / POP_DROPS + 0.3
			var drop := drops.get_child(i) as Node3D
			drop.position = Vector3(cos(angle), sin(angle), 0.0) * BUBBLE_RADIUS * lerpf(0.95, 1.45, k)
			drop.scale = Vector3.ONE * (1.0 - k), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_callback(drops.queue_free)
	var tween := create_tween().set_parallel()
	tween.tween_property(bubble, "scale", Vector3.ONE * 1.12, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shell_light, "albedo_color:a", 0.0, 0.12)
	tween.tween_property(_frost_light, "albedo_color:a", 0.0, 0.12)
	tween.chain().tween_callback(func() -> void:
		bubble.visible = false
		bubble.scale = Vector3.ONE
		_shell_light.albedo_color.a = 0.12
		_frost_light.albedo_color.a = 0.6)


## The bubble back (after a pop), for the next time the menu opens.
func reset_bubble() -> void:
	if bubble != null:
		bubble.visible = true


func _disc(radius: float, light: StandardMaterial3D) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.001
	mesh.radial_segments = 48
	disc.mesh = mesh
	disc.material_override = light
	disc.rotation.x = PI * 0.5   # faces +Z, the child
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc


static func _flat(colour: Color, alpha: float) -> StandardMaterial3D:
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color(colour, alpha)
	if alpha < 1.0:
		light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return light


# --- Looks ---------------------------------------------------------------------------------------

func _shelf() -> void:
	# A chunky wooden shelf of cream cubbies, two across: Wei's shelf, simplified. Megan, Nov 17 late: the cubbies
	# show big dark shapes like Wei's (square, triangle, circle, one empty). Design chat, Nov 18: one row of
	# cubbies more for each shelf level finished ([member rows], 1..4); the whole piece keeps its middle at MIDDLE.
	var w := 0.16
	var d := 0.08
	var cell := Vector2((w - 0.036) * 0.5, 0.048)
	var h := 0.012 + rows * (cell.y + 0.012)
	var base := MIDDLE.y - h * 0.5
	_box(Vector3(w, h, d), Vector3(0, base + h * 0.5, 0), WOOD)
	var shapes := [&"square", &"triangle", &"circle", &"", &"triangle", &"square", &"", &"circle"]
	for row in rows:
		for col in 2:
			var x := (col - 0.5) * (cell.x + 0.012)
			var y := base + 0.012 + cell.y * 0.5 + (rows - 1 - row) * (cell.y + 0.012)
			_box(Vector3(cell.x, cell.y, 0.012), Vector3(x, y, d * 0.5 - 0.004), CREAM, false)
			var front := Vector3(x, y, d * 0.5 + 0.004)
			match shapes[(row * 2 + col) % shapes.size()]:
				&"square":
					_box(Vector3(0.03, 0.03, 0.006), front, OUTLINE, false)
				&"triangle":
					var prism := PrismMesh.new()
					prism.size = Vector3(0.034, 0.03, 0.006)
					_mesh(prism, OUTLINE, false).position = front
				&"circle":
					var dot := _mesh(_cylinder(0.016, 0.016, 0.006), OUTLINE, false)
					dot.rotation.x = PI * 0.5
					dot.position = front


## The shelf grows to [param count] rows (1..4), over [param seconds] (0 = at once), from its middle.
func set_rows(count: int, seconds := 0.0) -> void:
	count = clampi(count, 1, 4)
	if kind != &"shelf" or count == rows:
		return
	rows = count
	for child in _body.get_children():
		child.queue_free()
	_shelf()
	if seconds > 0.0:
		_body.scale = Vector3(1.0, 0.8, 1.0)
		_body.position.y = MIDDLE.y * 0.2
		var grow := create_tween().set_parallel()
		grow.tween_property(_body, "scale", Vector3.ONE, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		grow.tween_property(_body, "position:y", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _dots_cloud() -> void:
	# A puffy cloud (four round lobes, flat front) with five big dots on it: "a cloud of dots". In the dots
	# game's own colours (Megan, Nov 18): a night-blue cloud like the dimmed room, pale icy-blue dots like the
	# game's dots (it was cream with navy dots, the game's look reversed).
	for lobe: Array in [[Vector2(-0.05, 0.05), 0.04], [Vector2(0.0, 0.075), 0.052], [Vector2(0.05, 0.055), 0.042], [Vector2(0.0, 0.035), 0.045]]:
		var puff := _mesh(_sphere(lobe[1]), NIGHT)
		puff.position = Vector3(lobe[0].x, lobe[0].y + 0.02, 0)
		puff.scale = Vector3(1, 1, 0.45)
	for spot: Vector2 in [Vector2(-0.045, 0.07), Vector2(0.0, 0.1), Vector2(0.045, 0.075), Vector2(-0.018, 0.05), Vector2(0.025, 0.045)]:
		var dot := _mesh(_cylinder(0.012, 0.012, 0.006), ICE, false)
		dot.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # they glow a little, as in the game
		dot.rotation.x = PI * 0.5
		dot.position = Vector3(spot.x, spot.y + 0.01, 0.024)


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _cup() -> void:
	# A white cup with a handle, orange inside. No base (Megan, Nov 17): floating in the ring above the
	# cauldron it can't be taken for the real cup on the table.
	_mesh(_cylinder(0.06, 0.048, 0.12), CUP).position.y = 0.06   # as big as the others without its base
	var inside := _mesh(_cylinder(0.052, 0.052, 0.004), CUP_INSIDE, false)
	inside.position.y = 0.119
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.022
	torus.outer_radius = 0.036
	handle.mesh = torus
	handle.material_override = _lit(CUP, true)
	handle.rotation = Vector3(PI * 0.5, 0, 0)
	handle.rotation.y = PI * 0.5
	handle.position = Vector3(0.066, 0.065, 0)
	handle.scale = Vector3(1.0, 1.0, 1.3)
	_body.add_child(handle)


## Wei's butterflies (Megan, Nov 18): a big orange butterfly, wings open, dark body and spots, its own silhouette.
func _butterfly() -> void:
	var wing_colour := Color(0.94, 0.55, 0.16)
	for side: float in [-1.0, 1.0]:
		var upper := _mesh(_sphere(0.042), wing_colour)
		upper.scale = Vector3(1.0, 1.15, 0.25)
		upper.position = Vector3(side * 0.04, 0.095, 0)
		upper.rotation.z = side * -0.35
		var lower := _mesh(_sphere(0.03), wing_colour)
		lower.scale = Vector3(1.0, 1.1, 0.25)
		lower.position = Vector3(side * 0.03, 0.045, 0)
		lower.rotation.z = side * 0.4
		var spot := _mesh(_sphere(0.011), OUTLINE, false)
		spot.scale = Vector3(1, 1, 0.3)
		spot.position = Vector3(side * 0.046, 0.1, 0.011)
	var body := _mesh(_cylinder(0.009, 0.007, 0.1), OUTLINE, false)
	body.position = Vector3(0, 0.072, 0.006)
	for side: float in [-1.0, 1.0]:
		var feeler := _mesh(_cylinder(0.002, 0.002, 0.035), OUTLINE, false)
		feeler.position = Vector3(side * 0.008, 0.135, 0.006)
		feeler.rotation.z = side * -0.4


## The ✕ (design chat, Nov 18, `DESIGN_EXIT_AND_HELP.md`): a cream square tile with a near-black edge and a
## near-black ✕ of two thick strokes, facing the child. Square on purpose (every other piece is round). In a
## game it stops the game ("Stop"); in the places row it finishes the visit after Onion asks ("Finish").
func _cross() -> void:
	_box(Vector3(0.12, 0.12, 0.02), Vector3(0, 0.075, 0), TILE)
	for turn: float in [PI * 0.25, -PI * 0.25]:
		var stroke := _box(Vector3(0.088, 0.022, 0.008), Vector3(0, 0.075, 0.012), INK, false)
		stroke.rotation.z = turn


var _lock: Node3D
var _shackle: MeshInstance3D


## The padlock badge on a locked bubble's lower right edge (Megan, Nov 18: "make it explicit they're not yet
## accessible"): a cream disc with a near-black rim, a brass lock body with a keyhole and its shackle.
func _make_lock() -> void:
	_lock = Node3D.new()
	_lock.name = "lock"
	bubble.add_child(_lock)
	_lock.position = Vector3(0.62, -0.62, 0.8) * BUBBLE_RADIUS
	var disc := _disc(0.045, _lit(TILE, false))
	_lock.add_child(disc)
	var rim := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.042
	ring_mesh.outer_radius = 0.049
	rim.mesh = ring_mesh
	rim.material_override = _flat(INK, 1.0)
	rim.rotation.x = PI * 0.5
	_lock.add_child(rim)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.044, 0.034, 0.012)
	body.mesh = box
	body.material_override = _lit(BRASS, true)
	body.position = Vector3(0, -0.006, 0.008)
	_lock.add_child(body)
	var hole := _disc(0.005, _flat(INK, 1.0))
	hole.position = Vector3(0, -0.004, 0.0145)
	_lock.add_child(hole)
	_shackle = MeshInstance3D.new()
	var loop := TorusMesh.new()
	loop.inner_radius = 0.011
	loop.outer_radius = 0.0175
	_shackle.mesh = loop
	_shackle.material_override = _lit(INK, false)
	_shackle.rotation.x = PI * 0.5
	_shackle.position = Vector3(0, 0.014, 0.008)
	_lock.add_child(_shackle)


## The ? (design chat, Nov 18): a bold near-black "?" in the bubble; a press plays the controls tour ("Help").
func _question() -> void:
	var mark := Label3D.new()
	mark.text = "?"
	mark.font = load("res://entry/assets/fonts/luckiest_guy.woff2")
	mark.font_size = 160
	mark.pixel_size = 0.00075
	mark.modulate = INK
	mark.outline_modulate = TILE
	mark.outline_size = 18
	mark.shaded = false
	mark.double_sided = false
	mark.position = Vector3(0, 0.075, 0.01)
	_body.add_child(mark)


## How faded the piece and its bubble are (the help tour dims what it isn't showing: 0 = full, 0.5 = half).
func set_dim(amount: float) -> void:
	for mesh: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		if mesh != _halo:
			mesh.transparency = clampf(amount, 0.0, 1.0)


## The Virtual Workshop (Wei's room; Megan, Nov 18: "a house not a door"): a little cream house with a
## terracotta roof and a navy door, in the menu's lower "places" row. Dark outline like the others.
func _house() -> void:
	_box(Vector3(0.1, 0.075, 0.06), Vector3(0, 0.0375, 0), CREAM)
	var roof := PrismMesh.new()
	roof.size = Vector3(0.125, 0.06, 0.07)
	var top := _mesh(roof, Color(0.72, 0.33, 0.22))
	top.position = Vector3(0, 0.105, 0)
	_box(Vector3(0.028, 0.048, 0.006), Vector3(0, 0.024, 0.031), NAVY, false)
	_box(Vector3(0.022, 0.02, 0.006), Vector3(0.03, 0.048, 0.031), NAVY, false)
	_box(Vector3(0.022, 0.02, 0.006), Vector3(-0.03, 0.048, 0.031), NAVY, false)


func _make_halo() -> void:
	_halo = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.3
	_halo_light = StandardMaterial3D.new()
	_halo_light.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_light.albedo_color = Color(GLOW, 0.0)
	_halo_light.albedo_texture = Onion.soft_dot()
	quad.material = _halo_light
	_halo.mesh = quad
	_halo.position = Vector3(0.0, 0.075, -0.06)   # behind its middle: it glows round the edges
	_halo.visible = false
	add_child(_halo)


# --- Helpers -------------------------------------------------------------------------------------

func _box(extent: Vector3, at: Vector3, colour: Color, outlined := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = extent
	var mesh := _mesh(box, colour, outlined)
	mesh.position = at
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 48
	return mesh


func _mesh(mesh: Mesh, colour: Color, outlined := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _lit(colour, outlined)
	_body.add_child(instance)
	return instance


## A plain lit colour with, optionally, a dark outline drawn behind it (an inverted hull, 5 mm).
static func _lit(colour: Color, outlined: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.6
	if outlined:
		var outline := StandardMaterial3D.new()
		outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.albedo_color = OUTLINE
		outline.cull_mode = BaseMaterial3D.CULL_FRONT
		outline.grow = true
		outline.grow_amount = 0.005
		material.next_pass = outline
	return material


## The eye (design chat, Nov 18): an almond outline with a round pupil, near-black on a cream tile like the ✕'s.
## "Looks": a row of visual looks for the real room.
func _eye() -> void:
	_box(Vector3(0.12, 0.12, 0.02), Vector3(0, 0.075, 0), TILE)
	var lid := MeshInstance3D.new()
	var almond := TorusMesh.new()
	almond.inner_radius = 0.036
	almond.outer_radius = 0.045
	lid.mesh = almond
	lid.material_override = _flat(INK, 1.0)
	lid.rotation.x = PI * 0.5
	lid.scale = Vector3(1.0, 1.0, 0.55)   # flattened top to bottom: an almond
	lid.position = Vector3(0, 0.075, 0.012)
	_body.add_child(lid)
	var pupil := _mesh(_cylinder(0.015, 0.015, 0.006), INK, false)
	pupil.rotation.x = PI * 0.5
	pupil.position = Vector3(0, 0.075, 0.012)
	var shine := _disc(0.005, _flat(TILE, 1.0))
	shine.position = Vector3(0.006, 0.081, 0.0155)
	_body.add_child(shine)


## A look bubble: [param id]'s little picture (the same wall, window, table and cup in that look), framed.
static func make_look(id: StringName) -> Impression:
	var piece := Impression.new()
	piece.kind = &"look"
	piece.look = id
	piece.title = LOOK_TITLES.get(id, String(id).capitalize())
	piece.name = "impression_look_%s" % id
	piece._body = Node3D.new()
	piece.add_child(piece._body)
	piece._box(Vector3(0.16, 0.124, 0.012), Vector3(0, 0.075, -0.004), INK, false)
	var picture := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.1125)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_texture = load("res://entry/assets/looks/%s.png" % id)
	quad.material = paint
	picture.mesh = quad
	picture.position = Vector3(0, 0.075, 0.003)
	piece._body.add_child(picture)
	piece._make_halo()
	piece.target = Target.sphere(StringName("impression_look_%s" % id), 0.1)
	piece.target.position.y = 0.075
	piece.add_child(piece.target)
	return piece


var _picked_ring: MeshInstance3D


## The current look's thick near-black ring (~0.6 cm) round its bubble.
func set_picked(on: bool) -> void:
	if on and _picked_ring == null and bubble != null:
		_picked_ring = MeshInstance3D.new()
		_picked_ring.name = "picked"
		var torus := TorusMesh.new()
		torus.inner_radius = BUBBLE_RADIUS * 1.02
		torus.outer_radius = BUBBLE_RADIUS * 1.02 + 0.016   # ~0.6 cm at the row's scale
		_picked_ring.mesh = torus
		_picked_ring.material_override = _flat(INK, 1.0)
		_picked_ring.rotation.x = PI * 0.5
		bubble.add_child(_picked_ring)
	if _picked_ring != null:
		_picked_ring.visible = on


## True while it shows the current look's ring.
func is_picked() -> bool:
	return _picked_ring != null and _picked_ring.visible
