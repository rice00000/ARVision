class_name MotionCloud
extends GPUParticles3D
## The same dot field is used for the demonstration and the measured rounds.

const MARGIN := 0.12
const NEAR := 0.6
const ALIGN_SECONDS := 0.6

var _lit_dots: int
var _alignment: Tween
@onready var _material := process_material as ShaderMaterial


static func half_size(condition: TrialCondition) -> Vector3:
	return Vector3(condition.value(&"half_width"), condition.value(&"half_height"), condition.value(&"half_depth"))


static func distance(condition: TrialCondition) -> float:
	return maxf(condition.value(&"distance"), half_size(condition).z + MARGIN + NEAR)


## Configure the lit field and add dots to the fading shell at the same density.
func show_flow(condition: TrialCondition, flow: Vector3, signal_dots: int, seed: int) -> void:
	if _alignment:
		_alignment.kill()
	var half := half_size(condition)
	var outer := half + Vector3.ONE * MARGIN
	_lit_dots = int(condition.value(&"dots"))
	amount = roundi(_lit_dots * (outer.x * outer.y * outer.z) / (half.x * half.y * half.z))
	visibility_aabb = AABB(-outer - Vector3.ONE * 0.3, outer * 2.0 + Vector3.ONE * 0.6)
	_material.set_shader_parameter(&"flow_direction", flow)
	_material.set_shader_parameter(&"competing_flow", condition.value(&"competing") > 0.5)
	_material.set_shader_parameter(&"speed", condition.value(&"speed"))
	_material.set_shader_parameter(&"half_size", half)
	_material.set_shader_parameter(&"margin", MARGIN)
	_material.set_shader_parameter(&"dot_count", amount)
	_material.set_shader_parameter(&"dot_lifetime", condition.value(&"dot_lifetime"))
	_material.set_shader_parameter(&"trial_seed", seed)
	_material.set_shader_parameter(&"alignment", 0.0)
	set_signal_dots(signal_dots)
	restart()


func set_signal_dots(count: int) -> void:
	_material.set_shader_parameter(&"signal_count", roundi(float(count) / _lit_dots * amount))


func align() -> void:
	_alignment = create_tween()
	_alignment.tween_method(func(weight: float) -> void:
		_material.set_shader_parameter(&"alignment", weight), 0.0, 1.0, ALIGN_SECONDS)
