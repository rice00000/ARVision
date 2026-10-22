extends Trial
## Real objects: the guide names a real object the camera sees; the child
## points at it and pulls the trigger. Needs the Detector module (CV).
##
## A pick is right when the pointing ray passes within [code]tolerance[/code]
## degrees of the object. Axis: tolerance (degrees, fixed).
## Hints: 1 a marker bobs above the object, 2 the guide says which side it is on.

## Objects the guide may ask for (COCO names).
@export var labels: PackedStringArray = ["cup", "bottle", "book", "apple", "chair", "vase", "tv", "potted plant"]

var _label := ""
var _place := Vector3.ZERO
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
			_place = detection.position


## Asks for one of the wanted objects in [param detections], not the last one asked for when there is a choice.
func _choose(detections: Array) -> void:
	var wanted := detections.filter(func(detection: Detection) -> bool: return detection.label in labels)
	if wanted.is_empty():
		return
	var fresh := wanted.filter(func(detection: Detection) -> bool: return detection.label != _previous)
	var pick: Detection = (fresh if not fresh.is_empty() else wanted).pick_random()
	_label = pick.label
	_previous = _label
	_place = pick.position
	condition.set_value(&"object", _label)
	App.reality.focus_on(_place)
	say("Point at the %s and pull the trigger." % _label)


func _on_selected(_hand: StringName, _target: Target, origin: Vector3, direction: Vector3) -> void:
	if _label.is_empty():
		return
	var angle := rad_to_deg(direction.angle_to(_place - origin))
	_attempts.append({angle = snappedf(angle, 0.1)})
	if angle <= condition.value(&"tolerance", 10.0):
		judge(&"good", _place)
		say("Yes! That's the %s." % _label)
		finish(true, {object = _label, angle = snappedf(angle, 0.1), attempts = _attempts.duplicate()})
		return
	judge(&"bad", origin + direction * origin.distance_to(_place))
	count_try()
	say("Not quite. Find the %s!" % _label)


func _hint(level: int) -> void:
	if _label.is_empty():
		say("Look around the room.")
	elif level == 1:
		_marker = MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.035
		cone.bottom_radius = 0.0
		cone.height = 0.07
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.85, 0.3)
		cone.material = material
		_marker.mesh = cone
		add_child(_marker)
		_marker.global_position = _place + Vector3.UP * 0.2
		var bob := _marker.create_tween().set_loops()
		bob.tween_property(_marker, ^"position:y", _marker.position.y + 0.05, 0.3)
		bob.tween_property(_marker, ^"position:y", _marker.position.y, 0.3)
	else:
		var side := App.head().to_local(_place).x
		say("The %s is on your %s." % [_label, "left" if side < -0.1 else "right" if side > 0.1 else "front"])
	if not _label.is_empty():
		judge(&"hint", _place)


func _teardown() -> void:
	if _marker:
		_marker.queue_free()
		_marker = null


func focus_point() -> Vector3:
	return _place if not _label.is_empty() else super.focus_point()
