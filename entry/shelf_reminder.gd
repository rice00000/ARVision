class_name ShelfReminder
extends Node
## The first visit's grab-only reminder (brief step 13). If the child waits after Onion's invitation, a
## teaching hand shows how to pick a shape up: it pinches ONE of the things and lifts it at most 5 cm,
## lowers it and loops. It never goes to a cubby and never moves the thing (see [method DemoHand.pinch_lift]
## with straight_down); it only reads Wei's public [method Trial.layout] and his `taken` / `put` reports.
##
## Wei's own help comes later: his first hint wiggles the right sticker, which is the answer, and he starts
## the clock when the round starts (10 s), about 3 s after Onion's last line. [method prepare] gives the
## session a copy of the plan whose trial definition waits [member help_after] seconds for that first hint;
## once the child has taken a shape the copy goes back to Wei's own timing, so a child who is stuck AFTER
## starting gets his normal help. Nothing of Wei's files or of his resources is changed.
##
## It is skipped (or stops) when: any thing is already carried, a `taken` or `put` has been reported (the
## child has shown they can), Wei's hint has begun, or the round is not running.

## Seconds of waiting, after Onion's last line, before the hand shows. 0 = never.
const DELAY := 12.0
## How long Wei's first hint is held back in the first visit (his default is 10 s).
const HELP_AFTER := 40.0

var delay := DELAY
var help_after := HELP_AFTER

var _defs: Array[TrialDef] = []     # the copies made by [method prepare]
var _normal: Array[float] = []      # and Wei's own hint_after for each
var _demo: DemoHand
var _anchor: Node3D                 # stands where the chosen thing is: the hand pinches this
var _chosen: StringName = &""
var _started := false
var _waited := 0.0
var _engaged := false               # the child has shown they can: no reminder, normal help


func _ready() -> void:
	Events.reported.connect(_on_reported)


## A copy of [param plan] whose trial definitions hold Wei's first hint back; the originals (and his
## resources on disk) are untouched.
func prepare(plan: SessionPlan) -> SessionPlan:
	var copy := plan.duplicate() as SessionPlan
	var blocks: Array[Block] = []
	for block in plan.blocks:
		var changed := block.duplicate() as Block
		changed.trial = block.trial.duplicate() as TrialDef
		_defs.append(changed.trial)
		_normal.append(changed.trial.hint_after)
		changed.trial.hint_after = help_after
		blocks.append(changed)
	copy.blocks = blocks
	return copy


## Onion's last line is done: from now the delay counts.
func start() -> void:
	_started = true
	_waited = 0.0


func _process(delta: float) -> void:
	if not _started or _engaged or delay <= 0.0 or App.session == null:
		return
	var trial: Trial = App.session.trial
	if trial == null or not trial.is_running() or not trial.has_method(&"layout"):
		_hide()
		return
	var things: Array = trial.layout().things
	if things.any(func(thing: Dictionary) -> bool: return thing.carried != &""):
		_engage()   # something is in a hand already
		return
	if trial.hint_level > 0:
		_hide()   # Wei's own help has begun: one hint at a time
		return
	_waited += delta
	if _waited >= delay:
		_show(things)


func _show(things: Array) -> void:
	var free := things.filter(func(thing: Dictionary) -> bool: return not thing.placed)
	if free.is_empty():
		return
	var eye := App.head().global_position
	var nearest: Dictionary = free[0]
	for thing: Dictionary in free:   # the thing nearest the child's eyes: easy to reach, and no link to Wei's hint order
		if eye.distance_squared_to(thing.centre) < eye.distance_squared_to(nearest.centre):
			nearest = thing
	if _demo == null:
		_demo = DemoHand.new()
		add_child(_demo)
		_anchor = Node3D.new()
		add_child(_anchor)
	if _chosen != nearest.id:
		_chosen = nearest.id
		_anchor.global_position = nearest.centre
	_demo.pinch_lift(_anchor, true)


func _hide() -> void:
	if _demo != null:
		_demo.stop()
	_chosen = &""


func _on_reported(what: StringName, _data: Dictionary) -> void:
	if what == &"taken" or what == &"put":
		_engage()


## The child can do it: the hand goes, and Wei's help is his own again.
func _engage() -> void:
	if _engaged:
		return
	_engaged = true
	_hide()
	for index in _defs.size():
		if is_instance_valid(_defs[index]):
			_defs[index].hint_after = _normal[index]
