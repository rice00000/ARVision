class_name GearSpin
extends Node
## Turns parts of a model for ever at steady speeds, while [member running]. The gear's own clip
## does not loop (it ends in a different pose from its start: the carrier turns 72 degrees), but
## every part turns at a constant speed, so the speeds are read from the clip and the parts are
## turned directly: no seam, however long it runs.

var running := false

var _nodes: Array[Node3D] = []
var _start: Array[float] = []   # angle about Y at the start, radians
var _speed: Array[float] = []   # radians a second
var _clock := 0.0


## Reads each rotation track of [param clip] (turning about Y): the part under [param root],
## its angle at the start and its steady speed.
func read(root: Node, clip: Animation) -> void:
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var node := root.get_node_or_null(NodePath(String(clip.track_get_path(track)).get_slice(":", 0))) as Node3D
		if node == null:
			continue
		var steps := 40
		var previous := 0.0
		var first := 0.0
		var total := 0.0
		for i in steps + 1:
			var q := clip.rotation_track_interpolate(track, clip.length * i / float(steps))
			var angle := 2.0 * atan2(q.y, q.w)
			if i == 0:
				first = angle
			else:
				total += fposmod(angle - previous + PI, TAU) - PI
			previous = angle
		_nodes.append(node)
		_start.append(first)
		_speed.append(total / clip.length)


## Adds a part of its own, turning at [param radians_a_second].
func add(node: Node3D, radians_a_second: float) -> void:
	_nodes.append(node)
	_start.append(node.rotation.y)
	_speed.append(radians_a_second)


func _process(delta: float) -> void:
	if not running:
		return
	_clock += delta
	for i in _nodes.size():
		if is_instance_valid(_nodes[i]):
			_nodes[i].quaternion = Quaternion(Vector3.UP, _start[i] + _speed[i] * _clock)
