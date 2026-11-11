extends RefCounted
## The motion lab's trial flow, without any drawing (Nov 9 build plan). Isolated from the
## production motion task: nothing here touches trials/motion, Session, scoring or the
## continue-until-correct practice logic.
##
## Teaching (an unscored demonstration and response practice, both repeatable) and blocks of
## review trials. Every attempt runs
##     prepare -> expose -> respond -> acknowledged -> deliberate Next
## One post-exposure left/right answer is accepted, whatever its correctness. Early and
## duplicate inputs are logged, never counted. There is no response timeout: the attempt waits
## for an answer, Pause or Leave.
##
## Times are microseconds from Time.get_ticks_usec(); tests pass a fake clock. The scene shows
## the dots on exposure_requested, hides them on exposure_ended and reports what was actually
## drawn with note_presented() / note_hidden(). The record stores milliseconds since begin().

signal phase_changed(phase: StringName)
signal exposure_requested(attempt: Dictionary)
signal exposure_ended(attempt: Dictionary)
## The message changed within the same phase (early or duplicate input).
signal message_changed(text: String)

const BlockConfig := preload("res://tools/motion_lab/block_config.gd")
const SCHEMA := "arvision_motion_lab_record/2"
const LATENCY_DEFINITION := "Time to registered answer: from response enabled (dots-off state change) to the accepted answer, on the app's monotonic clock (Time.get_ticks_usec). Post-exposure response latency, NOT motion-onset reaction time; includes deciding, moving and input recognition."
const COHERENCE_DEFINITION := "coherence = signal dots / all dots. Requested is the setting; realized = round(requested x dots) / dots, which differs when the dot count is small."
const RUNNING_PHASES: Array[StringName] = [&"prepare", &"expose", &"respond"]

var phase: StringName = &"idle"
var record: Dictionary = {}
var block: Dictionary = {}
var attempt: Dictionary = {}
var config: Dictionary = {}
var timing: Dictionary = {}
## What the participant panel says now (neutral wording only).
var message := ""
## Where records go. A file per run, plus latest.json.
var save_dir := "user://motion_lab_records"
var saved_path := ""

var _start_usec := 0
var _phase_usec := 0
var _resume_to: StringName = &""
var _rng := RandomNumberGenerator.new()
var _order_rng := RandomNumberGenerator.new()


## Starts a run (one record). [param session_seed] < 0 picks one from the clock; it is recorded.
## [param dataset_id] is a NON-IDENTIFYING label for one review dataset (one person / one review
## context); results only ever accumulate within one dataset.
func begin(stimulus: Dictionary, block_timing: Dictionary, now_usec: int, session_seed := -1,
		display := {}, dataset_id := "dev-review") -> void:
	config = stimulus.duplicate(true)
	timing = block_timing.duplicate(true)
	_start_usec = now_usec
	var seed_used := session_seed if session_seed >= 0 else int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	_rng.seed = seed_used
	var created := Time.get_datetime_string_from_system(true)
	record = {
		schema = SCHEMA,
		created_utc = created,
		file_stem = "motion_block_" + created.replace(":", "-").replace("T", "_"),
		purpose = "developer / usability review of the isolated motion lab; no participant data",
		participant = "none recorded (no identifying data)",
		dataset_id = dataset_id,
		clock = "Time.get_ticks_usec (monotonic); ms since this run began",
		latency_definition = LATENCY_DEFINITION,
		coherence_definition = COHERENCE_DEFINITION,
		session_seed = seed_used,
		display = display.duplicate(true),
		timing_note = "requested_* times come from the flow's clock; presented_ms / hidden_ms / frames_drawn are measured by the app after a frame was drawn. Neither proves what a headset display showed.",
		teaching = [],
		blocks = [],
		events = [],
		ended = {},
	}
	_set_phase(&"menu", now_usec, "Watch an example, practise answering, or start the trials.")


## Changes the stimulus (and optionally timing) for the NEXT block. Only outside a block; an
## active block keeps the snapshot it started with (see end_block_for_setup).
func set_config(stimulus: Dictionary, block_timing := {}) -> bool:
	if phase not in [&"menu", &"block_end", &"resting"]:
		return false
	config = stimulus.duplicate(true)
	if not block_timing.is_empty():
		timing = block_timing.duplicate(true)
	return true


## A setup change asked for in the middle of a block (from Pause): the block is closed as
## "ended_for_setup_change" (its open attempt interrupted), and the next block is a new one.
func end_block_for_setup(now_usec: int) -> bool:
	if phase != &"paused" or block.is_empty() or block.status != "running":
		return false
	if not attempt.is_empty() and attempt.status == "running":
		attempt.status = "interrupted"
	block.status = "ended_for_setup_change"
	block.ended_ms = _ms(now_usec)
	record.events.append({event = "block_ended_for_setup_change", t_ms = _ms(now_usec), block = block.id})
	attempt = {}
	_set_phase(&"menu", now_usec, "Setup can be changed. The next set starts fresh.")
	save()
	return true


func start_demo(now_usec: int) -> bool:
	return _start_teaching("demo", now_usec)


func start_practice(now_usec: int) -> bool:
	return _start_teaching("practice", now_usec)


## A brief unscored look at the PENDING setup (its coherence, speed, blur, exposure), with the
## direction revealed afterwards. Never part of a block or of any result.
func start_setup_preview(now_usec: int) -> bool:
	return _start_teaching("setup_preview", now_usec)


## Starts a block of review trials: half left, half right, shuffled, fresh dot seeds.
func start_block(now_usec: int) -> bool:
	if phase not in [&"menu", &"block_end", &"resting"]:
		return false
	var n := int(timing.trials)
	var order_seed := _rng.randi()
	_order_rng.seed = order_seed
	var planned: Array = []
	for i in n:
		planned.append("left" if i < n / 2 else "right")
	if n % 2 == 1:
		planned[n - 1] = "left" if _order_rng.randf() < 0.5 else "right"
	for i in range(n - 1, 0, -1):   # Fisher-Yates
		var j := _order_rng.randi_range(0, i)
		var swap: String = planned[i]
		planned[i] = planned[j]
		planned[j] = swap
	block = {
		id = "B%d" % (record.blocks.size() + 1),
		kind = "review",
		status = "running",
		trials_planned = n,
		completed = 0,
		order_seed = order_seed,
		planned = planned,
		config = config.duplicate(true),
		timing = timing.duplicate(true),
		condition_key = BlockConfig.condition_key(config, timing, record.display),
		condition_label = BlockConfig.condition_label(config, timing),
		input = String(config.get("input", "unknown")),
		started_ms = _ms(now_usec),
		attempts = [],
	}
	record.blocks.append(block)
	_new_attempt("review", planned[0], 1, now_usec)
	return true


## Advances the flow's clock: prepare -> expose -> respond.
func tick(now_usec: int) -> void:
	if attempt.is_empty():
		return
	var elapsed := (now_usec - _phase_usec) / 1000000.0
	if phase == &"prepare" and elapsed >= float(attempt.requested.prepare_s):
		attempt.times.requested_onset_ms = _ms(now_usec)
		_set_phase(&"expose", now_usec, "")
		exposure_requested.emit(attempt)
	elif phase == &"expose" and elapsed >= float(attempt.requested.expose_s):
		attempt.times.requested_offset_ms = _ms(now_usec)
		exposure_ended.emit(attempt)
		if attempt.purpose in ["demo", "setup_preview"]:
			attempt.status = "shown"
			attempt.assistance.append("answer_revealed")
			var what := "Example" if attempt.purpose == "demo" else "Preview of this setup"
			_set_phase(&"acknowledged", now_usec, "%s: those dots went %s. Nothing is scored. Press Next." % [what, String(attempt.direction).to_upper()])
		else:
			attempt.times.response_enabled_ms = _ms(now_usec)
			_set_phase(&"respond", now_usec, "Which way did the dots go? Left or right?")


## A left (-1) or right (+1) answer from [param source] ("desktop_key", "desktop_button", ...).
## Returns &"accepted", &"early", &"duplicate" or &"ignored".
func answer(direction: int, source: String, now_usec: int) -> StringName:
	if record.is_empty():
		return &"ignored"
	var side := "left" if direction < 0 else "right"
	var input := {t_ms = _ms(now_usec), answer = side, source = source, phase = String(phase)}
	match phase:
		&"respond":
			attempt.answer = side
			attempt.answer_source = source
			attempt.input_modality = source
			attempt.times.answered_ms = input.t_ms
			attempt.latency_ms = snappedf(float(input.t_ms) - float(attempt.times.response_enabled_ms), 0.1)
			attempt.correct = side == attempt.direction   # stored; never shown, never gates Next
			attempt.status = "answered"
			var text := "Answer received: %s. Press Next when ready." % side.to_upper()
			if attempt.purpose == "practice":
				attempt.assistance.append("answer_revealed_after_response")
				text = "Answer received: %s. (Practice: the dots went %s.) Press Next." % [side.to_upper(), String(attempt.direction).to_upper()]
			else:
				block.completed = int(block.completed) + 1
			_set_phase(&"acknowledged", now_usec, text)
			save()
			return &"accepted"
		&"prepare", &"expose":
			attempt.early_inputs.append(input)
			message = "Too early: wait until the dots are gone, then answer."
			message_changed.emit(message)
			save()
			return &"early"
		&"acknowledged":
			attempt.duplicate_inputs.append(input)
			message = "Already received. Press Next when ready."
			message_changed.emit(message)
			return &"duplicate"
	input.event = "stray_input"
	record.events.append(input)
	return &"ignored"


## Deliberate continuation after an acknowledgement.
func next(now_usec: int) -> bool:
	if phase != &"acknowledged":
		return false
	if attempt.purpose != "review":
		attempt = {}
		_set_phase(&"menu", now_usec, "Watch the example again, practise again, or start the trials.")
		return true
	if int(block.completed) >= int(block.trials_planned):
		_finish_block(now_usec)
		return true
	var slot := int(block.completed) + 1
	_new_attempt("review", block.planned[slot - 1], slot, now_usec)
	return true


## Pause is available throughout. Pausing before an answer interrupts the attempt: it never
## fills a trial slot, and resuming starts a fresh attempt (new identity and dot seed).
func pause(now_usec: int) -> bool:
	if phase in RUNNING_PHASES:
		attempt.status = "interrupted"
		attempt.interrupted = {phase = String(phase), t_ms = _ms(now_usec)}
		if phase == &"expose":
			attempt.times.requested_offset_ms = _ms(now_usec)
			exposure_ended.emit(attempt)
		_resume_to = &"fresh_attempt"
	elif phase in [&"acknowledged", &"menu", &"block_end", &"resting"]:
		_resume_to = phase
	else:
		return false
	record.events.append({event = "pause", t_ms = _ms(now_usec), during = String(phase), attempt = attempt.get("id", "")})
	_set_phase(&"paused", now_usec, "Paused. Resume when ready, or Leave.")
	save()
	return true


func resume(now_usec: int) -> bool:
	if phase != &"paused":
		return false
	record.events.append({event = "resume", t_ms = _ms(now_usec)})
	if _resume_to == &"fresh_attempt":
		if attempt.purpose == "review":
			_new_attempt("review", attempt.direction, int(attempt.slot), now_usec)
		else:
			attempt = {}
			_set_phase(&"menu", now_usec, "Watch the example again, practise again, or start the trials.")
	else:
		var back := _resume_to
		_set_phase(back, now_usec, {
			&"acknowledged": "Press Next when ready.",
			&"menu": "Watch an example, practise answering, or start the trials.",
			&"block_end": _end_text(),
			&"resting": "Resting. Press Continue when ready.",
		}.get(back, ""))
	return true


## Local exit at any point. Never requires finishing the block.
func leave(now_usec: int) -> void:
	if phase == &"left":
		return
	if not attempt.is_empty() and attempt.status == "running":
		attempt.status = "abandoned"
		if phase == &"expose":
			attempt.times.requested_offset_ms = _ms(now_usec)
			exposure_ended.emit(attempt)
	if not block.is_empty() and block.status == "running":
		block.status = "left_early"
		block.ended_ms = _ms(now_usec)
	record.ended = {how = "left", t_ms = _ms(now_usec), during = String(phase)}
	_set_phase(&"left", now_usec, "You left the activity. Thank you.")
	save()


func rest(now_usec: int) -> bool:
	if phase != &"block_end":
		return false
	record.events.append({event = "rest", t_ms = _ms(now_usec)})
	_set_phase(&"resting", now_usec, "Resting. Press Continue when ready.")
	return true


func end_rest(now_usec: int) -> bool:
	if phase != &"resting":
		return false
	record.events.append({event = "rest_end", t_ms = _ms(now_usec)})
	_set_phase(&"block_end", now_usec, _end_text())
	return true


## The app measured the dots' first drawn frame for [param attempt_id].
func note_presented(attempt_id: String, now_usec: int) -> void:
	var a := _find(attempt_id)
	if not a.is_empty():
		a.times.presented_ms = _ms(now_usec)


## The app measured the first frame drawn without dots, and how many frames had dots.
func note_hidden(attempt_id: String, now_usec: int, frames_drawn: int) -> void:
	var a := _find(attempt_id)
	if a.is_empty():
		return
	a.times.hidden_ms = _ms(now_usec)
	a.frames_drawn = frames_drawn
	if a.times.has("presented_ms"):
		a.measured_exposure_ms = snappedf(float(a.times.hidden_ms) - float(a.times.presented_ms), 0.1)
	save()


## Writes the record (a file per run plus latest.json) and returns the absolute path.
func save() -> String:
	if record.is_empty():
		return ""
	var dir := ProjectSettings.globalize_path(save_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var text := JSON.stringify(record, "\t", false)
	for name: String in [String(record.file_stem) + ".json", "latest.json"]:
		var file := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
		if file == null:
			push_error("Motion lab: cannot write the record to %s" % dir)
			return ""
		file.store_string(text)
	saved_path = dir.path_join(String(record.file_stem) + ".json")
	return saved_path


static func load_record(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func summary() -> String:
	if block.is_empty():
		return "no block yet"
	return "%s %s: %d/%d completed" % [block.id, block.status, int(block.completed), int(block.trials_planned)]


func _start_teaching(kind: String, now_usec: int) -> bool:
	if phase not in [&"menu", &"block_end", &"resting"]:
		return false
	_new_attempt(kind, "left" if _rng.randf() < 0.5 else "right", 0, now_usec)
	return true


func _new_attempt(purpose: String, direction: String, slot: int, now_usec: int) -> void:
	# A review attempt reads only its block's snapshot, so nothing changes mid-block.
	var t: Dictionary = block.timing if purpose == "review" else timing
	var expose: float = t.demo_expose_s if purpose == "demo" else t.expose_s
	var coherence: float = block.config.coherence if purpose == "review" else (
		float(config.coherence) if purpose == "setup_preview" else float(t.teach_coherence))
	var dots := int(block.config.dots if purpose == "review" else config.dots)
	var signal_n := roundi(clampf(coherence, 0.0, 1.0) * dots)
	var id: String
	if purpose == "review":
		var tries := 1
		for earlier: Dictionary in block.attempts:
			if int(earlier.slot) == slot:
				tries += 1
		id = "%s-T%d-A%d" % [block.id, slot, tries]
	else:
		var count := 1
		for earlier: Dictionary in record.teaching:
			if earlier.purpose == purpose:
				count += 1
		id = "%s-%d" % [purpose, count]
	attempt = {
		id = id,
		purpose = purpose,
		scored = purpose == "review",
		block = block.id if purpose == "review" else "",
		slot = slot,
		direction = direction,
		seed = _rng.randi_range(1, 999999),
		coherence = coherence,
		coherence_requested = coherence,
		signal_dots = signal_n,
		total_dots = dots,
		coherence_realized = snappedf(float(signal_n) / maxf(dots, 1), 0.0001),
		config_name = config.get("name", ""),
		requested = {prepare_s = t.prepare_s, expose_s = expose},
		times = {prepare_ms = _ms(now_usec)},
		status = "running",
		answer = "",
		answer_source = "",
		correct = null,
		early_inputs = [],
		duplicate_inputs = [],
		assistance = [],
	}
	if purpose == "review":
		block.attempts.append(attempt)
	else:
		record.teaching.append(attempt)
	_set_phase(&"prepare", now_usec, {"review": "Get ready…", "demo": "Example: get ready…",
		"practice": "Practice: get ready…", "setup_preview": "Setup preview: get ready…"}[purpose])


func _finish_block(now_usec: int) -> void:
	block.status = "complete"
	block.ended_ms = _ms(now_usec)
	attempt = {}
	_set_phase(&"block_end", now_usec, _end_text())
	save()


func _end_text() -> String:
	return "All %d done. Rest, do another set, or leave." % int(block.get("trials_planned", 0))


func _find(attempt_id: String) -> Dictionary:
	if not attempt.is_empty() and attempt.id == attempt_id:
		return attempt
	for b: Dictionary in record.get("blocks", []):
		for a: Dictionary in b.attempts:
			if a.id == attempt_id:
				return a
	for a: Dictionary in record.get("teaching", []):
		if a.id == attempt_id:
			return a
	return {}


func _set_phase(next_phase: StringName, now_usec: int, text: String) -> void:
	phase = next_phase
	_phase_usec = now_usec
	message = text
	phase_changed.emit(phase)


func _ms(now_usec: int) -> float:
	return snappedf((now_usec - _start_usec) / 1000.0, 0.1)
