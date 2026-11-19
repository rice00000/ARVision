class_name TrialAxis
extends Resource
## One difficulty dimension of a trial: clutter, size, coherence...
##
## Maps the skill's single 0-1 level onto a real value. Only a [member driven]
## axis follows the level; the others stay at a fixed value and are logged
## anyway, so a failed round stays attributable to one variable.

## Read with [method TrialCondition.value], e.g. &"clutter".
@export var name: StringName = &""
## Value at level 0. May be larger than [member hard] (contrast goes down as it gets harder).
@export var easy := 0.0
## Value at level 1.
@export var hard := 1.0
## Follows the level. Keep one driven axis per trial unless the notes say why.
@export var driven := false
## Value while not driven. NAN = [member easy].
@export var fixed := NAN
## Grows with the child's vision profile: &"size" = times [member Vision.size_scale].
## Pinned values are taken as they are.
@export var scaled_by: StringName = &""
## Highest value scaling may reach (the thing must still fit its place); INF = none.
@export var scaled_max := INF


func resolve(level: float) -> float:
	if not driven:
		return easy if is_nan(fixed) else fixed
	return lerpf(easy, hard, clampf(level, 0.0, 1.0))


## [method resolve] grown by [param scale], up to [member scaled_max].
func scaled(level: float, scale: float) -> float:
	return grown(resolve(level), scale)


## [param value] grown by [param scale], up to [member scaled_max].
func grown(value: float, scale: float) -> float:
	return minf(value * scale, maxf(value, scaled_max))
