class_name GearSpin
extends Node
## Turns the gear parts at steady speeds while [member running].

var running := false
## 1 = full speed; the closing slows the gears to a stop by lowering it.
var rate := 1.0

var _nodes: Array[Node3D] = []
var _start: Array[float] = []   # angle about Y at the start, radians
var _speed: Array[float] = []   # radians a second
var _clock := 0.0


## Adds a part of its own, turning at [param radians_a_second].
func add(node: Node3D, radians_a_second: float) -> void:
	_nodes.append(node)
	_start.append(node.rotation.y)
	_speed.append(radians_a_second)


func _process(delta: float) -> void:
	if not running:
		return
	_clock += delta * rate
	for i in _nodes.size():
		if is_instance_valid(_nodes[i]):
			_nodes[i].quaternion = Quaternion(Vector3.UP, _start[i] + _speed[i] * _clock)
