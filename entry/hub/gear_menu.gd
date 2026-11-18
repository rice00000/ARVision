class_name GearMenu
extends Node3D
## The table gear as the child's menu (Megan, Nov 17: Scene 7 Update 3 / Scene 9 "one gear"): when a hand comes
## near the gear or aims at it, its buttons appear in a row above it: Home (Wei's room), the stones count and
## Finish visit. Showing them on aim or nearness is fine; **choosing needs a press** (a touch or a pinch),
## never a look or a dwell. They fade ~2 s after the hand has gone. Only in the hub: the flow turns it off
## during an activity ([method set_enabled]).

signal chosen(id: StringName)   # &"gear_home", &"gear_finish"

const ABOVE := 0.12        # the row's middle above the gear, metres
const SPACING := 0.11
const NEAR := 0.2          # a fingertip this close to the gear shows the buttons
const LINGER := 2.0        # seconds they stay after the hand has gone
const GROW := 0.25

var buttons: Dictionary[StringName, HubButton] = {}
var shown := false
var enabled := true
var _gear_target: Target
var _eye := Vector3.ZERO
var _since_near := 99.0
var _row: Node3D


## A gear menu over [param gear_at] (the seated gear's middle), facing [param eye]. [param with_home]: the Home
## button is there (it's offered after the first activity, Scene 11).
static func make(parent: Node, gear_at: Vector3, eye: Vector3, with_home := false) -> GearMenu:
	var menu := GearMenu.new()
	menu.name = "GearMenu"
	parent.add_child(menu)
	menu.global_position = gear_at
	menu._eye = eye
	menu._gear_target = Target.sphere(&"hub_gear", 0.075)
	menu.add_child(menu._gear_target)
	menu._row = Node3D.new()
	menu.add_child(menu._row)
	menu._row.position = Vector3.UP * ABOVE
	var face := Vector3(eye.x, menu._row.global_position.y, eye.z)
	if face.distance_to(menu._row.global_position) > 0.01:
		menu._row.look_at(face, Vector3.UP, true)
	for spec: Array in [[&"gear_home", &"home"], [&"gear_stones", &"stones"], [&"gear_finish", &"finish"]]:
		var button := HubButton.make(spec[0], spec[1], HubButton.RADIUS if spec[1] != &"stones" else 0.034)
		button.pinch_only = true   # Megan, Nov 18: the gear's buttons answer only a pinch; a hand resting by the socket touched Finish
		menu._row.add_child(button)
		button.pressed.connect(func(id: StringName) -> void: menu.chosen.emit(id))
		menu.buttons[spec[0]] = button
	menu.set_home(with_home)
	menu._place()
	menu._show(false, true)
	return menu


## Home is offered (after the first activity).
func set_home(on: bool) -> void:
	buttons[&"gear_home"].set_meta(&"offered", on)
	_place()
	if shown:
		_show(true, true)


func has_home() -> bool:
	return buttons[&"gear_home"].get_meta(&"offered", false)


## In the hub only: off during an activity and the closing (hides it at once).
func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_show(false, true)


func set_stones(count: int) -> void:
	buttons[&"gear_stones"].set_count(count)


## Shows the buttons as if a hand came near (tests and pictures).
func reveal() -> void:
	_since_near = 0.0
	_show(true)


func _place() -> void:
	var row: Array[HubButton] = []
	for id: StringName in [&"gear_home", &"gear_stones", &"gear_finish"]:
		if id != &"gear_home" or has_home():
			row.append(buttons[id])
	for id in buttons:
		buttons[id].visible = buttons[id] in row and shown
	for i in row.size():
		row[i].position = Vector3((i - (row.size() - 1) * 0.5) * SPACING, 0, 0)


func _process(delta: float) -> void:
	if not enabled or get_tree().paused:
		return
	_since_near += delta
	if _hand_near():
		_since_near = 0.0
	if _since_near < LINGER and not shown:
		_show(true)
	elif _since_near >= LINGER and shown:
		_show(false)


func _hand_near() -> bool:
	if App.rig == null:
		return false
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if pointer == null:
			continue
		if pointer.aimed == _gear_target:
			return true
		for id in buttons:
			if buttons[id].target != null and pointer.aimed == buttons[id].target:
				return true
		if pointer.tip().distance_to(global_position) < NEAR:
			return true
	return false


func _show(on: bool, at_once := false) -> void:
	shown = on
	_place()
	for id in buttons:
		var button := buttons[id]
		button.set_open(on and button.visible)
		if at_once:
			button.scale = Vector3.ONE if on else Vector3.ONE * 0.01
		else:
			if on:
				button.scale = Vector3.ONE * 0.01
			create_tween().tween_property(button, "scale", Vector3.ONE if on else Vector3.ONE * 0.01, GROW).set_trans(Tween.TRANS_SINE)
