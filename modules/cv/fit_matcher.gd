class_name FitMatcher
extends RefCounted
## Turn to fit, the last step: decides when the live shape "fits" a target.
## Pure logic: give it the live shape and the time since the last call, it does the rest.
##   * scores are smoothed (a moving average), so one odd frame doesn't count
##   * the best target must beat the next best by MARGIN (look-alike views don't fit)
##   * a fit starts above ENTER and only ends below EXIT (no flicker at the edge)
##   * and it must hold for HOLD seconds before it counts
## The viewpoint is free: whatever mix of turning the cup and moving the head produces
## the target's view counts (Megan, Nov 11).

const ENTER := 0.85
const EXIT := 0.75
const MARGIN := 0.08
const HOLD := 0.5
## Weight of the newest score in the moving average (1 = no smoothing).
const SMOOTH := 0.5

## Emitted once when a target starts fitting, with its index and name.
signal fitted(index: int, name: String)

var names: Array[String] = []
var targets: Array[PackedByteArray] = []
## Smoothed score per target (0..1).
var scores := PackedFloat32Array()
## The target that fits now, or -1.
var fit := -1
## The target being held (above ENTER, waiting for HOLD), or -1.
var candidate := -1
## Seconds the candidate has held.
var held := 0.0
var _started := false


func add_target(target_name: String, shape: PackedByteArray) -> void:
	names.append(target_name)
	targets.append(shape)
	scores.append(0.0)


func reset() -> void:
	fit = -1
	candidate = -1
	held = 0.0
	_started = false
	scores.fill(0.0)


## One live frame. [param shape] is the normalised live shape, or empty when the cup
## wasn't found this frame. [param dt] is seconds since the last call.
## Returns the index of the target that fits now, or -1.
func update(shape: PackedByteArray, dt: float) -> int:
	if targets.is_empty():
		return -1
	for i in targets.size():
		# no cup this frame: let the score fade instead of jumping to 0
		var raw := ShapeCV.iou(shape, targets[i]) if not shape.is_empty() else scores[i] * (1.0 - SMOOTH)
		scores[i] = raw if not _started else SMOOTH * raw + (1.0 - SMOOTH) * scores[i]
	_started = true
	var top := 0
	for i in scores.size():
		if scores[i] > scores[top]:
			top = i
	var second := 0.0
	for i in scores.size():
		if i != top:
			second = maxf(second, scores[i])
	# a fit ends when its score drops below EXIT or another target takes over
	if fit >= 0 and (scores[fit] < EXIT or top != fit):
		fit = -1
	if fit < 0:
		if scores[top] >= ENTER and scores[top] - second >= MARGIN:
			held = held + dt if top == candidate else dt
			candidate = top
			if held >= HOLD:
				fit = top
				fitted.emit(fit, names[fit])
		else:
			candidate = -1
			held = 0.0
	return fit
