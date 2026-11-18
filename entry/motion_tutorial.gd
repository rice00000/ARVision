class_name MotionTutorial
extends Node3D
## An unscored sideways sweep demonstrated with the same dot cloud and wall effect as the rounds.

## The dots have started flying toward the wall.
signal effect_started
## The hand starts to sweep.
signal sweep_started
## The tutorial is over: the effect has settled and the dots are gone.
signal settled
const CLOUD := preload("res://trials/motion/motion_cloud.tscn")
## Seconds the dots take to appear.
const GROW := 0.5
## Seconds of flow alone, before the hand comes.
const WATCH := 1.5
## Seconds from launch until the hand settles, then until the demo ends.
const HAND_SETTLES := 0.8
const SETTLE := 3.2
## The hand sweeps this far, metres, in comfortable hand space (not toward the cloud).
const SWEEP_LENGTH := 0.30
const HAND_AHEAD := 0.38
const HAND_BELOW := 0.22

## &"right" or &"left" (a sweep the child can make with one hand, seated).
var heading := &"right"
## Where the hand sweeps from and to (world).
var hand_from := Vector3.INF
var hand_to := Vector3.INF

var _cloud: MotionCloud
var _demo: DemoHand
var _trail: SweepTrail
var _tween: Tween
var _flow_world := Vector3.RIGHT
var _clock := 0.0
var _sweeping := false


## Starts the example in [param frame] (the cloud's place). Returns at once; [signal settled] says when it is over.
## [param arrived]: the cloud that already came in with Onion's intro (Megan, Nov 18): taken over as it is, all its
## dots turning to move together, with no second appearance.
func play(condition: TrialCondition, frame: Transform3D, arrived: MotionCloud = null) -> void:
	stop()
	var flow := Vector3.LEFT if heading == &"left" else Vector3.RIGHT
	_flow_world = frame.basis * flow
	if arrived != null and is_instance_valid(arrived):
		_cloud = arrived
		_cloud.reparent(self)
		_cloud.global_transform = frame
		_cloud.set_signal_dots(int(condition.value(&"dots")))
	else:
		_cloud = CLOUD.instantiate() as MotionCloud
		add_child(_cloud)
		_cloud.global_transform = frame
		_cloud.show_flow(condition, flow, int(condition.value(&"dots")), 7)
	var eye := App.head().global_position
	var ahead := -frame.basis.z
	hand_from = eye + ahead * HAND_AHEAD + Vector3.DOWN * HAND_BELOW - _flow_world * SWEEP_LENGTH * 0.5
	hand_to = hand_from + _flow_world * SWEEP_LENGTH
	if _demo == null:
		_demo = DemoHand.new()
		add_child(_demo)
		_trail = SweepTrail.new()
		add_child(_trail)
	_tween = create_tween()   # everything it waits on lives on this tween: stop() ends it
	if arrived == null:
		_cloud.scale = Vector3.ONE * 0.001
		_tween.tween_property(_cloud, "scale", Vector3.ONE, GROW)
	_tween.tween_interval(WATCH)
	_tween.tween_callback(_start_sweep)
	_tween.tween_interval(DemoHand.SWEEP_END)   # the hand is across
	_tween.tween_callback(_effect)
	_tween.tween_interval(HAND_SETTLES)
	_tween.tween_callback(_demo.stop)   # the hand settles
	_tween.tween_interval(SETTLE)
	_tween.tween_callback(_finish)


## Cuts it short: the dots and the hand go at once. (Not the effect, if it has started: it ends by itself.)
func stop() -> void:
	if _cloud == null:
		return
	_sweeping = false
	_tween.kill()
	_demo.stop()
	_cloud.queue_free()
	_cloud = null


func _start_sweep() -> void:
	_clock = 0.0
	_sweeping = true
	_demo.sweep(hand_from, hand_to)
	sweep_started.emit()


func _process(delta: float) -> void:
	if not _sweeping:
		return
	_clock += delta
	# The streak the hand leaves, as a child's own sweep leaves one: from where it set off to where it has got.
	if _clock >= DemoHand.SWEEP_START and _clock <= DemoHand.SWEEP_END + 0.2:
		_trail.show_sweep(hand_from, hand_from.lerp(hand_to, smoothstep(DemoHand.SWEEP_START, DemoHand.SWEEP_END, _clock)))


## The same strike as in a successful round, outside the research log.
func _effect() -> void:
	_sweeping = false
	WallBreak.strike_with(_cloud, App.head().global_position, _flow_world, WallBreak.Style.CRACK, false)
	effect_started.emit()


func _finish() -> void:
	_cloud.queue_free()
	_cloud = null
	settled.emit()
