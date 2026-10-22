extends Trial
## Find it: virtual toys on the real table. The guide names one; the child
## points at it and pulls the trigger, or touches it. Trains objects in clutter.
##
## Axes: clutter (other toys, driven), size (metres), spacing (gap between toy
## centres, in toy sizes: lower = more crowded), same_colour (1 = every toy
## has the target's colour, so only shape tells them apart).
## Hints: 1 the target hops (motion separates an object from clutter),
## 2 it glows and the guide says where it is.

const SHAPES: Array[StringName] = [&"ball", &"block", &"cone", &"drum", &"ring", &"egg"]
const COLOURS: Array[Color] = [Color(0.95, 0.3, 0.25), Color(0.25, 0.55, 0.95), Color(0.98, 0.8, 0.2),
	Color(0.35, 0.8, 0.4), Color(0.75, 0.4, 0.9), Color(0.95, 0.55, 0.2)]

var _rng := RandomNumberGenerator.new()
## Target node -> shape name, for this round's toys.
var _toys: Dictionary[Target, StringName] = {}
var _target: Target
var _target_material: StandardMaterial3D
var _picks: Array[String] = []
var _hop: Tween


func _setup(round_condition: TrialCondition) -> void:
	_clear()
	_rng.randomize()
	round_condition.set_value(&"seed", _rng.seed)
	var size: float = round_condition.value(&"size", 0.07)
	var count := int(round_condition.value(&"clutter", 3.0)) + 1
	var surface := App.reality.work_surface()
	var spots := surface.scatter(count, size * round_condition.value(&"spacing", 1.8), size, _rng)
	var shapes := SHAPES.duplicate()
	shapes.shuffle()
	var target_colour := COLOURS[_rng.randi_range(0, COLOURS.size() - 1)]
	for i in spots.size():
		var shape: StringName = shapes[0] if i == 0 else shapes[1 + (i - 1) % (shapes.size() - 1)]
		var colour: Color = target_colour if i == 0 or round_condition.value(&"same_colour", 0.0) > 0.5 \
			else COLOURS[_rng.randi_range(0, COLOURS.size() - 1)]
		var toy := _make_toy(shape, colour, size, "toy_%d_%s" % [i, shape])
		add_child(toy)
		toy.global_transform = Transform3D(surface.transform.basis, spots[i] + surface.transform.basis.y * size * 0.5)
		_toys[toy] = shape
	_target = _toys.keys()[0]
	_target_material = _target.get_meta(&"material")
	_picks.clear()
	round_condition.set_value(&"target", String(_toys[_target]))
	round_condition.set_value(&"toys", spots.size())
	say("Find the %s!" % _toys[_target])


func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	_pick(target)


func _on_touched(_hand: StringName, target: Target) -> void:
	_pick(target)


func _pick(toy: Target) -> void:
	if not _toys.has(toy):
		return
	_picks.append(String(_toys[toy]))
	if toy == _target:
		judge(&"good", toy.global_position)
		say("Yes! That's the %s." % _toys[toy])
		_stop_hop()
		create_tween().tween_property(toy, ^"position", toy.position + toy.basis.y * 0.12, 0.3)
		finish(true, {picks = _picks.duplicate()})
	else:
		judge(&"bad", toy.global_position)
		count_try()
		say("That's the %s. Find the %s!" % [_toys[toy], _toys[_target]])


func _hint(level: int) -> void:
	if level == 1:
		_hop = create_tween().set_loops()
		var rest := _target.position
		_hop.tween_property(_target, ^"position", rest + _target.basis.y * 0.04, 0.25)
		_hop.tween_property(_target, ^"position", rest, 0.25)
	else:
		_target_material.emission_enabled = true
		_target_material.emission = _target_material.albedo_color
		_target_material.emission_energy_multiplier = 1.5
		var side := App.head().to_local(_target.global_position).x
		say("Look for the %s, on your %s." % [_toys[_target], "left" if side < -0.08 else "right" if side > 0.08 else "front"])
	judge(&"hint", _target.global_position)


func _teardown() -> void:
	_stop_hop()


func _exit_tree() -> void:
	_clear()


func _stop_hop() -> void:
	if _hop:
		_hop.kill()
		_hop = null


func _clear() -> void:
	for toy in _toys:
		toy.queue_free()
	_toys.clear()


func _make_toy(shape: StringName, colour: Color, size: float, toy_id: String) -> Target:
	var toy := Target.sphere(StringName(toy_id), size * 0.7)
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	toy.set_meta(&"material", material)
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh(shape, size)
	instance.material_override = material
	toy.add_child(instance)
	return toy


func _mesh(shape: StringName, size: float) -> Mesh:
	match shape:
		&"ball", &"egg":
			var sphere := SphereMesh.new()
			sphere.radius = size * (0.5 if shape == &"ball" else 0.38)
			sphere.height = size
			return sphere
		&"block":
			var box := BoxMesh.new()
			box.size = Vector3.ONE * size
			return box
		&"ring":
			var ring := TorusMesh.new()
			ring.inner_radius = size * 0.28
			ring.outer_radius = size * 0.5
			return ring
	var cylinder := CylinderMesh.new() # cone, drum
	cylinder.top_radius = 0.0 if shape == &"cone" else size * 0.45
	cylinder.bottom_radius = size * 0.5 if shape == &"cone" else size * 0.45
	cylinder.height = size if shape == &"cone" else size * 0.8
	return cylinder
