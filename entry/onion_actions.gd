class_name OnionActions
extends Node
## Onion's small physical reactions, so the story can use them: where it looks (the child by
## default, or a thing it is paying attention to), a surprised hop, a lean toward something, and
## the brief ? and ! marks above it. They add to Onion's idle float; they never move it away from
## where the story put it. The Entry's _process reads [member attention], [member hop_y] and
## [member lean].

## The marks: 0 = sage with a cream outline, 1 = cream with a dark sage outline (the default: it
## reads against a bright and a dark room). Size, height and colours: EntryLayout.MARK_*.
var mark_style := EntryLayout.MARK_STYLE

## What Onion looks at: a Node3D, a world position, or null (the child).
var attention: Variant = null
## Added to Onion's height while it hops, metres.
var hop_y := 0.0
## Tilt toward whatever it is looking at, radians (positive: forward).
var lean := 0.0

var _holder: Node3D
var _height := 0.11
var _font: FontVariation


func setup(holder: Node3D, height: float) -> void:
	_holder = holder
	_height = height


## Where Onion looks now, in the world.
func look_point() -> Vector3:
	if attention is Node3D and is_instance_valid(attention):
		return (attention as Node3D).global_position
	if attention is Vector3:
		return attention
	return App.head().global_position


## A small surprised hop (up fast with a little overshoot, back down softly). Plays on [param runner].
func hop(runner: Node) -> void:
	var tween := runner.create_tween()
	tween.tween_property(self, "hop_y", 0.04, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "hop_y", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Leans in toward what it looks at ([param on]) or stands straight again.
func lean_in(runner: Node, on: bool) -> void:
	runner.create_tween().tween_property(self, "lean", 0.35 if on else 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## A ? or ! above Onion for about a second: it grows in with a little overshoot, stays, fades.
## Bold, solid, no flashing, not a target; it supplements the movement and the words.
func mark(runner: Node, symbol: String, hold := 0.9) -> void:
	var label := Label3D.new()
	label.text = symbol
	label.font = _bold()
	var distance := _holder.global_position.distance_to(App.head().global_position)
	label.font_size = EntryLayout.MARK_FONT_SIZE
	label.pixel_size = EntryLayout.mark_pixel_size(distance)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_render_priority = 19
	label.outline_size = roundi(EntryLayout.MARK_FONT_SIZE * EntryLayout.MARK_OUTLINE)
	var colours := EntryLayout.mark_colours(mark_style)
	label.modulate = colours[0]
	label.outline_modulate = colours[1]
	label.modulate.a = 0.0
	label.scale = Vector3.ONE * 0.5
	label.position = Vector3(0.0, EntryLayout.mark_lift(_height, label.pixel_size), 0.0)
	_holder.add_child(label)
	label.add_to_group(&"entry_transient")
	var tween := runner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, EntryLayout.MARK_IN)
	tween.tween_property(label, "scale", Vector3.ONE, EntryLayout.MARK_GROW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(hold)
	tween.chain().tween_property(label, "modulate:a", 0.0, EntryLayout.MARK_OUT)
	tween.chain().tween_callback(label.queue_free)


func _bold() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.9
	return _font
