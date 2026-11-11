class_name Onion
extends Node3D
## Onion the Wisp, the one guide: its body, light and halo, and how it floats, looks and talks. This node is
## Onion's holder: move it to move Onion. The opening builds one and hands it to the [Workshop]; the room
## intro builds its own. Onion faces what it [member actions] attends to (the child by default), floats
## gently, and glows while the guide's voice speaks (one voice, one guide: any line).
## [method line] speaks a line and waits for its end, one line at a time.
##
## Model: "Onion the Wisp" by Edvin Borkovskij, CC BY 4.0 (credit in entry/assets/CREDITS.md).

const MODEL := preload("res://entry/assets/onion_the_wisp.glb")
## How tall Onion is, metres.
const HEIGHT := 0.11
## The breath after a line the voice has finished, seconds.
const BREATH := 0.25
## Onion's body colour where its texture cannot be read (measured on the desktop).
const BODY_COLOUR := Color(0.57, 0.84, 0.91)

## Where Onion looks, its hop and lean, the ? and ! marks.
var actions := OnionActions.new()
var touch := OnionTouch.new()
var model: Node3D
## A slow breathing glow: "something here".
var cue := false
## A sideways tilt of the body, radians (the sheepish one is 0.28).
var tilt := 0.0

var _face := Vector3.FORWARD   # which way the eyes point, in the holder's space
var _rest_y := 0.0
var _glow := OmniLight3D.new()
var _halo := StandardMaterial3D.new()
var _clock := 0.0
var _said_until := 0.0         # without a Voice module: until when the last line "plays"
var _cheer_until := 0.0
static var _dot: GradientTexture2D


func _init() -> void:
	name = "Onion"
	model = MODEL.instantiate()
	add_child(model)
	# HEIGHT tall, centred on the holder.
	var bounds := _bounds()
	model.scale *= HEIGHT / bounds.size.y
	bounds = _bounds()
	model.position -= bounds.get_center()
	bounds = _bounds()
	_rest_y = model.position.y
	touch.setup(model)
	add_child(touch)
	# Which way the eyes look: from the body's centre to the eyes' centre.
	for mesh: MeshInstance3D in model.find_children("*Eyes*", "MeshInstance3D", true, false):
		var towards := _to_holder(mesh) * mesh.get_aabb().get_center() - bounds.get_center()
		_face = Vector3(towards.x, 0, towards.z).normalized()
	# A soft light, so it glows on the table.
	_glow.light_color = Color(1.0, 0.85, 0.2)
	_glow.omni_range = 0.6
	_glow.light_energy = 0.6
	add_child(_glow)
	# A small soft halo in its own body colour, always facing the child. Normal (mixed) blending: over
	# passthrough an added glow can vanish.
	var tint := _body_colour()
	tint.a = 0.22
	_halo.albedo_color = tint
	_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo.albedo_texture = soft_dot()
	_halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * HEIGHT * 1.5
	quad.material = _halo
	var halo := MeshInstance3D.new()
	halo.mesh = quad
	add_child(halo)
	actions.name = "OnionActions"
	add_child(actions)
	actions.setup(self, HEIGHT)


func _ready() -> void:
	add_to_group(&"onion_holder")   # LineSkip: a press on Onion cuts its line
	Events.said.connect(func(text: String) -> void: _said_until = _clock + maxf(1.5, text.length() * 0.065))


## Onion looks at [param what] (a Node3D or a position), or at the child when null.
func attend(what: Variant) -> void:
	actions.attention = what


## A small satisfied bob.
func cheer() -> void:
	_cheer_until = _clock + 1.2


## True while the guide's voice is speaking.
func talking() -> bool:
	var voice := App.module(&"Voice")
	if voice != null and voice.has_method(&"speaking"):
		return voice.speaking() != ""
	return _clock < _said_until


## Speaks [param text] (baked audio and subtitle) once the voice is quiet, waits for it to end, then a
## breath. A line cut short (the child pressed Onion, or a newer line) returns at once, with no breath.
## Time only counts while [param by] runs (a menu that pauses the game holds the line).
static func line(text: String, by: Node) -> void:
	var voice := App.module(&"Voice")
	if voice == null or not voice.has_signal(&"line_finished"):
		Events.say(text)
		await _hold(by, maxf(1.5, text.length() * 0.07 + 0.6))
		return
	var limit := maxf(6.0, text.length() * 0.2)   # never stuck on a line that cannot end
	var queued := 0.0
	while voice.speaking() != "" and queued < limit:   # one line at a time: a later line waits for an earlier one
		await by.get_tree().process_frame
		if not is_instance_valid(by): return
		if by.can_process():
			queued += by.get_process_delta_time()
	var done := {finished = false, completed = true}
	var on_finished := func(spoken: String, completed: bool) -> void:
		if spoken == text:
			done.finished = true
			done.completed = completed
	voice.line_finished.connect(on_finished)
	Events.say(text)
	var waited := 0.0
	while not done.finished and waited < limit:
		await by.get_tree().process_frame
		if not is_instance_valid(by): return   # the scene (and the app with its voice, in a test) went
		if by.can_process():
			waited += by.get_process_delta_time()
	voice.line_finished.disconnect(on_finished)
	if done.completed:
		await _hold(by, BREATH)


## Waits [param seconds] of [param by]'s own time (it stops while [param by] is paused).
static func _hold(by: Node, seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await by.get_tree().process_frame
		if not is_instance_valid(by): return
		if by.can_process():
			waited += by.get_process_delta_time()


func _process(delta: float) -> void:
	_clock += delta
	var talking_now := talking()
	var bob := sin(_clock * TAU / 4.5) * 0.0035   # story: only a gentle float, 5-8 mm over 4-5 s, talking or not
	if _clock < _cheer_until:
		bob += sin((_cheer_until - _clock) / 1.2 * PI * 2.0) * 0.012
	model.position.y = lerpf(model.position.y, _rest_y + bob + actions.hop_y, minf(1.0, delta * 10.0))
	model.rotation.x = lerpf(model.rotation.x, actions.lean, minf(1.0, delta * 8.0))
	model.rotation.z = lerpf(model.rotation.z, tilt, minf(1.0, delta * 8.0))
	_halo.albedo_color.a = 0.3 if talking_now else 0.22
	if talking_now:
		_glow.light_energy = 0.6 + 0.35 * (0.5 + 0.5 * sin(_clock * 9.0))
	elif cue:
		_glow.light_energy = 0.5 + 0.5 * (0.5 + 0.5 * sin(_clock * 2.0))   # slow: about 3 s a breath
	else:
		_glow.light_energy = 0.6
	var to_look := actions.look_point() - global_position
	to_look.y = 0
	if to_look.length() < 0.01:
		return
	var turn := atan2(_face.x, _face.z) - atan2(to_look.x, to_look.z)
	global_rotation.y = lerp_angle(global_rotation.y, -turn, minf(1.0, delta * 9.0))


## The box around the model's meshes, in the holder's space (it works before Onion is in the tree).
func _bounds() -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := _to_holder(mesh) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _to_holder(node: Node3D) -> Transform3D:
	var to := Transform3D.IDENTITY
	while node != self:
		to = node.transform * to
		node = node.get_parent()
	return to


## Onion's body colour: the average of its texture where the body's UVs fall (light blue), or
## [constant BODY_COLOUR] if the texture can't be read on this device.
func _body_colour() -> Color:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name.contains("Eye"):
			continue
		var material := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var image := material.albedo_texture.get_image()
		if image == null or (image.is_compressed() and image.decompress() != OK):
			break
		var uvs: PackedVector2Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var sum := Color(0, 0, 0, 0)
		var count := 0
		for i in range(0, uvs.size(), 7):
			var x := clampi(int(fposmod(uvs[i].x, 1.0) * image.get_width()), 0, image.get_width() - 1)
			var y := clampi(int(fposmod(uvs[i].y, 1.0) * image.get_height()), 0, image.get_height() - 1)
			sum += image.get_pixel(x, y)
			count += 1
		if count > 0:
			return Color(sum.r / count, sum.g / count, sum.b / count)
	return BODY_COLOUR


## A round, soft-edged dot, made once (Onion's halo, the opening's glints).
static func soft_dot() -> GradientTexture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		var fall := Gradient.new()
		fall.set_color(0, Color(1, 1, 1, 1))
		fall.set_color(1, Color(1, 1, 1, 0))
		_dot.gradient = fall
	return _dot
