class_name MotionTutorial
extends Node3D
## The unscored example before the child's first motion round (story: "Watch what happens when they move
## together." / "Here, let me show you."): a cloud of dots at full coherence flowing sideways, the teaching hand
## sweeping the same way (with the same white streak the child's own sweeps leave), then the dots all go
## together and Wei's wall effect plays once. It is NOT a round: there is no Trial and no Session, nothing is
## judged, nothing goes to the research log (no trial_start / trial_end / motion_attempt / wall_break) and there
## is no response timer. Wei's stimulus is reused as it is: his scene's cloud (his shader, his dot look, his
## parameters at the easiest level) is built into a separate instance and driven directly.
##
## Use: add it to the scene, [method play] it with the frame the cloud stands in (level, its -Z pointing away
## from the child, like Wei's own: where the dots sit is the layout chat's) and wait for [signal settled].
## Onion's lines are the story's: [signal sweep_started] and [signal effect_started] say when to turn and look.

## The effect has been played; the tutorial's dots are still there until [signal settled].
signal effect_started
## The hand starts to sweep.
signal sweep_started
## The tutorial is over: the effect has settled and the dots are gone.
signal settled
## [method stop] cut it short.
signal stopped

const DEF := preload("res://trials/motion/motion.tres")
const Motion := preload("res://trials/motion/motion_trial.gd")
## Seconds the dots take to appear and to go.
const GROW := 0.5
## Seconds of flow alone, before the hand comes.
const WATCH := 1.5
## Seconds from the effect until the hand settles, and until the dots go, for each look of the effect.
const HAND_SETTLES := 0.8
const SETTLE := {WallBreak.Style.CRACK: 3.2, WallBreak.Style.SPACE: 6.0}
## The flow in the cloud's own frame (+X is the child's right).
const FLOWS := {&"right": Vector3.RIGHT, &"left": Vector3.LEFT}
## The hand sweeps this far, metres, in comfortable hand space (not toward the cloud).
const SWEEP_LENGTH := 0.30
const HAND_AHEAD := 0.38
const HAND_BELOW := 0.22

var style := WallBreak.Style.CRACK
## &"right" or &"left" (a sweep the child can make with one hand, seated).
var heading := &"right"
## Where the hand sweeps from and to (world). INF: worked out from the eyes when [method play] is called.
var hand_from := Vector3.INF
var hand_to := Vector3.INF

var _cloud: GPUParticles3D
var _demo: DemoHand
var _trail: SweepTrail
var _tween: Tween
var _flow_world := Vector3.RIGHT
var _clock := 0.0
var _sweeping := false
var _playing := false


## Starts the example in [param frame] (the cloud's place). Returns at once; [signal settled] says when it is over.
func play(frame: Transform3D) -> void:
	stop()
	_playing = true
	var condition := DEF.condition(0.0, 0, false, {&"direction": 1.0})   # the easiest level, a sideways flow
	var dots := int(condition.value(&"dots"))
	var half := Vector3(condition.value(&"half_width"), condition.value(&"half_height"), condition.value(&"half_depth"))
	_cloud = _build_cloud()
	add_child(_cloud)
	_cloud.global_transform = frame
	_cloud.amount = dots
	_cloud.visibility_aabb = AABB(-half - Vector3.ONE * 0.3, half * 2.0 + Vector3.ONE * 0.6)
	var material := _cloud.process_material as ShaderMaterial
	var flow: Vector3 = FLOWS[heading]
	_flow_world = frame.basis * flow
	material.set_shader_parameter(&"flow_direction", flow)
	material.set_shader_parameter(&"competing_flow", false)
	material.set_shader_parameter(&"speed", condition.value(&"speed"))
	material.set_shader_parameter(&"half_size", half)
	material.set_shader_parameter(&"dot_count", dots)
	material.set_shader_parameter(&"dot_lifetime", condition.value(&"dot_lifetime"))
	material.set_shader_parameter(&"trial_seed", 7)
	material.set_shader_parameter(&"alignment", 0.0)
	material.set_shader_parameter(&"signal_count", dots)   # every dot follows the flow: nothing to find
	_cloud.restart()
	if hand_from == Vector3.INF or hand_to == Vector3.INF:
		var eye := App.head().global_position
		var ahead := Vector3(-frame.basis.z.x, 0.0, -frame.basis.z.z).normalized()
		hand_from = eye + ahead * HAND_AHEAD + Vector3.DOWN * HAND_BELOW - _flow_world * SWEEP_LENGTH * 0.5
		hand_to = hand_from + _flow_world * SWEEP_LENGTH
	if _demo == null:
		_demo = DemoHand.new()
		add_child(_demo)
		_trail = SweepTrail.new()
		add_child(_trail)
	_cloud.scale = Vector3.ONE * 0.001
	_tween = create_tween()   # everything it waits on lives on this tween: stop() ends it
	_tween.tween_property(_cloud, "scale", Vector3.ONE, GROW)
	_tween.tween_interval(WATCH)
	_tween.tween_callback(_start_sweep)
	_tween.tween_interval(DemoHand.SWEEP_END)   # the hand is across
	_tween.tween_callback(_effect)
	_tween.tween_interval(HAND_SETTLES)
	_tween.tween_callback(_demo.stop)   # the hand settles
	_tween.tween_interval(SETTLE[style])
	_tween.tween_property(_cloud, "scale", Vector3.ONE * 0.001, GROW)
	_tween.tween_callback(_finish)


## Cuts it short: the dots and the hand go at once. (Not the effect, if it has started: it ends by itself.)
func stop() -> void:
	if not _playing:
		return
	_playing = false
	_sweeping = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _demo != null:
		_demo.stop()
	if is_instance_valid(_cloud):
		_cloud.queue_free()
	_cloud = null
	stopped.emit()


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


## The dots all go together and the wall breaks, as in Wei's round when the sweep goes the right way: the same
## call, except that the research log is not told.
func _effect() -> void:
	_sweeping = false
	var tween := create_tween()
	tween.tween_method(func(amount: float) -> void:
		if is_instance_valid(_cloud):
			(_cloud.process_material as ShaderMaterial).set_shader_parameter(&"alignment", amount), 0.0, 1.0, Motion.ALIGN_SECONDS)
	var eye := App.head().global_position
	WallBreak.burst(eye, (_cloud.global_position - eye).normalized(), _flow_world, style, false)
	effect_started.emit()


func _finish() -> void:
	_playing = false
	if is_instance_valid(_cloud):
		_cloud.queue_free()
	_cloud = null
	settled.emit()


## A separate copy of Wei's cloud (his scene's, with his shader and his dot look), never added to a tree
## with his trial code: it has no listeners and judges nothing.
func _build_cloud() -> GPUParticles3D:
	var trial_scene := DEF.scene.instantiate()
	var cloud := trial_scene.get_node(^"Cloud") as GPUParticles3D
	trial_scene.remove_child(cloud)
	trial_scene.free()
	return cloud
