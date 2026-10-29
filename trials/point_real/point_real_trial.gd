extends Trial
## Real objects: the guide names a real object the camera sees; the child
## points at it and pinches. Needs the Detector module (CV).
##
## A pick goes to the seen object whose outline the pointing ray misses least.
## It is right when that is the named one, missed by at most
## [code]tolerance[/code] degrees: a pick aimed at the plant just beside the cup
## is the plant. A ray through the named object's outline is always right, even
## when another object lies on the same line: without depth, either was meant.
## Axis: tolerance (degrees, fixed).
## Hints: 1 a marker bobs above the object, 2 the guide says which side it is on.

## The marker's height as seen from the eyes, degrees: as easy to see far as near.
const MARKER_DEGREES := 6.0

## Objects the guide may ask for (COCO names).
@export var labels: PackedStringArray = ["cup", "bottle", "book", "apple", "chair", "vase", "tv", "potted plant"]

var _label := ""
## The named object as last seen.
var _named: Detection
var _previous := ""
var _attempts: Array[Dictionary] = []
var _marker: MeshInstance3D


func _ready() -> void:
	super._ready()
	Events.detected.connect(_on_detected)


func _setup(_round_condition: TrialCondition) -> void:
	_label = ""
	_attempts.clear()
	_choose(App.module(&"Detector").detections)
	if _label.is_empty():
		say("Look around the room.")


func _on_detected(detections: Array) -> void:
	if not is_running():
		return
	if _label.is_empty():
		_choose(detections)
		return
	for detection: Detection in detections:
		if detection.label == _label:
			_named = detection


## Asks for one of the wanted objects in [param detections], not the last one asked for when there is a choice.
func _choose(detections: Array) -> void:
	var wanted := detections.filter(func(detection: Detection) -> bool: return detection.label in labels)
	if wanted.is_empty():
		return
	var fresh := wanted.filter(func(detection: Detection) -> bool: return detection.label != _previous)
	var pick: Detection = (fresh if not fresh.is_empty() else wanted).pick_random()
	_label = pick.label
	_previous = _label
	_named = pick
	condition.set_value(&"object", _label)
	App.reality.focus_on(_named.position)
	say("Point at the %s and pinch your fingers." % _label)


func _on_selected(_hand: StringName, _target: Target, origin: Vector3, direction: Vector3) -> void:
	if _label.is_empty():
		return
	var picked := _named
	var angle := _named.miss(origin, direction)
	for detection: Detection in App.module(&"Detector").detections:
		if detection.label == _label:
			continue
		var off := detection.miss(origin, direction)
		if off < angle:
			picked = detection
			angle = off
	_attempts.append({object = picked.label, angle = snappedf(angle, 0.1)})
	var close: bool = angle <= condition.value(&"tolerance", 10.0)
	pick(_label, picked.label if close else "nothing")
	if picked == _named and close:
		judge(&"good", _named.position)
		say("Yes! That's the %s." % _label)
		finish(true, {object = _label, angle = snappedf(angle, 0.1), attempts = _attempts.duplicate()})
		return
	count_try()
	if close:
		judge(&"bad", picked.position)
		say("That's the %s. Find the %s!" % [picked.label, _label])
		return
	judge(&"bad", origin + direction * origin.distance_to(_named.position))
	say("Not quite. Find the %s!" % _label)


func _hint(level: int) -> void:
	if _label.is_empty():
		say("Look around the room.")
	elif level == 1:
		var height := App.head().global_position.distance_to(_named.position) * tan(deg_to_rad(MARKER_DEGREES))
		_marker = MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = height * 0.5
		cone.bottom_radius = 0.0
		cone.height = height
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.85, 0.3)
		cone.material = material
		_marker.mesh = cone
		add_child(_marker)
		_marker.global_position = _named.position + Vector3.UP * (0.15 + height)
		var bob := _marker.create_tween().set_loops()
		bob.tween_property(_marker, ^"position:y", _marker.position.y + height * 0.7, 0.3)
		bob.tween_property(_marker, ^"position:y", _marker.position.y, 0.3)
	else:
		var side := App.head().to_local(_named.position).x
		say("The %s is on your %s." % [_label, "left" if side < -0.1 else "right" if side > 0.1 else "front"])
	if not _label.is_empty():
		judge(&"hint", _named.position)


func _teardown() -> void:
	if _marker:
		_marker.queue_free()
		_marker = null


func focus_point() -> Vector3:
	return _named.position if not _label.is_empty() else super.focus_point()
