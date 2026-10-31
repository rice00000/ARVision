class_name LineSkip
extends Node
## A deliberate press on Onion cuts the line it is speaking short, so a child can move things along
## instead of waiting through every line (the Voice module reports a cut-off line as
## line_finished(text, false), and the stories' say() move on at once).
##
## What counts as a press on Onion: a pinch whose ray, or a fingertip going in, lands within [constant RADIUS]
## of Onion's middle, AND that lands on nothing else: a press on a Target (the cauldron, a button), on the
## gear or on a shape is never a skip, and where Onion and another thing are both in reach the press goes to
## whichever it is aimed at more closely. On a desktop the mouse hand's own ray can start beyond Onion, so the
## whole line through the hand counts (as for the cauldron).
##
## It never cuts an instruction the child still needs: the stories register [member guards], each says
## "an instruction is being asked for and not done yet". It cuts the CURRENT line only; the lines after it
## play as usual, so an instruction that follows is still said, once.
## A child (or a kitten) waving a hand through Onion is not a press on it in a headset: the hand has to go
## IN (once), and a skip needs 0.5 s to pass since the last one.

## How near to Onion's middle a press must land, metres (its body is about 11 cm tall).
const RADIUS := 0.07
## Seconds that must pass between two skips.
const COOLDOWN := 0.5
## A press that took the gear or a shape within this long of the press is not a skip.
const TOOK_WINDOW := 0.3

## () -> bool: true while an instruction the child still needs is being said.
var guards: Array[Callable] = []
## (origin, direction) -> float: how closely a press along this line is aimed at something else that takes
## presses, as distance over its reach (below Onion's own ratio means that thing wins); INF for nothing.
var rival_line := Callable()
## (point) -> float: the same for a fingertip.
var rival_point := Callable()

var _took_at := -10.0
var _last := -10.0
var _in: Dictionary = {}   # side -> a fingertip is inside Onion's reach


func _ready() -> void:
	Events.selected.connect(_on_selected)
	Events.reported.connect(func(what: StringName, _data: Dictionary) -> void:
		if what == &"taken" or what == &"put":
			took_something())


## The gear or a shape was just taken by the press in progress: that press is not a skip.
func took_something() -> void:
	_took_at = _now()


## Cuts the line being spoken, if one is and no instruction is needed. True if it did.
func skip() -> bool:
	var voice := App.module(&"Voice")
	if voice == null or not voice.has_method(&"skip") or _now() - _last < COOLDOWN or voice.speaking() == "":
		return false
	guards = guards.filter(func(guard: Callable) -> bool: return guard.is_valid())
	for guard in guards:
		if guard.call():
			return false
	_last = _now()
	return voice.skip()


func _process(_delta: float) -> void:
	if App.xr == null or App.rig == null:
		return   # only a headset's fingertip pokes; on a desktop only a click presses
	var centre := _onion()
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		var inside := false
		var ratio := INF
		if centre != Vector3.INF and pointer.tracked():
			ratio = pointer.tip().distance_to(centre) / RADIUS
			inside = ratio <= 1.0
		var was: bool = _in.get(side, false)
		_in[side] = inside
		if inside and not was:
			_press(ratio, rival_point.call(pointer.tip()) if rival_point.is_valid() else INF)


func _on_selected(_side: StringName, target: Target, origin: Vector3, direction: Vector3) -> void:
	if target != null:
		return   # a press on a Target is never a skip
	var centre := _onion()
	if centre == Vector3.INF or direction.length() < 0.001:
		return
	var line := direction.normalized()
	var to_onion := centre - origin
	if App.xr != null and to_onion.dot(line) < -RADIUS:
		return   # a real hand's ray goes one way only
	var off := to_onion.cross(line).length()
	if off > RADIUS:
		return
	_press(off / RADIUS, rival_line.call(origin, line) if rival_line.is_valid() else INF)


func _press(onion_ratio: float, rival_ratio: float) -> void:
	if rival_ratio <= onion_ratio or _now() - _took_at < TOOK_WINDOW:
		return
	skip()


## Onion's middle (the holder the opening and the workshop both move), or INF.
func _onion() -> Vector3:
	var holder := get_tree().get_first_node_in_group(&"onion_holder") as Node3D
	return holder.global_position if holder != null and holder.is_inside_tree() else Vector3.INF


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
