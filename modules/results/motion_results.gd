class_name MotionResults
extends RefCounted
## Results of Wei's motion (dots) game rounds, for the Staff tools Results tab (Graphs chat, Nov 17).
## Ported from the motion lab's tools/motion_lab/results.gd to game rounds. Pure functions over the
## research log (core/log.gd), so the graphs and the tests read exactly the same numbers.
##
## What the game round gives (trials/motion/motion_trial.gd) and how it is read here:
## * Only the FIRST attempt of a round is scored. Wei's rounds retry until right, so later attempts
##   say little.
## * ASSISTED: help was on (help > 0) before the first sweep. Shown, never scored as right or wrong.
## * STOPPED (interrupted): the round ended with no answer at all (skipped, timed out, the scene left),
##   from motion_round_interrupted. A gap, never a wrong answer, never a zero time. A round that
##   ended unwon AFTER a first answer still has that answer: it is scored on it.
## * ELIGIBLE = answered on the first attempt, no help. Only eligible rounds enter "correct k of n",
##   the median and the accuracy-versus-coherence counts.
## * Coherence = coherence_shown of the first attempt (the share of dots really following the flow),
##   binned in 10 % bands, one series per task (the tasks are different conditions). Observed
##   points with 95 % Wilson intervals only: no fitted curve, no threshold.
## * GROUPS kept apart: play, pinned (the adult or a dev panel fixed the level), dev, and unknown
##   (log version 1, from before Nov 17, which did not say). Never pooled with each other.
## Describe, don't diagnose: this is for the adult, never shown to the child.

const Z := 1.959964   # 95 %
## The groups, in the order the tab offers them.
const GROUPS: Array[String] = ["play", "pinned", "dev", "unknown"]
const GROUP_TITLES := {play = "Play", pinned = "Pinned level", dev = "Dev", unknown = "Older logs"}
## Hub review, Nov 17: the view is a grouping key too. A round in a dimmed room (log v3 view_dim > 0)
## goes in "<group>_dim", never pooled with the same group undimmed.
const DIM_SUFFIX := "_dim"
const TASK_TITLES := {motion = "Dots", motion_competing = "Dots, two flows", motion_demo = "Spell wall"}


# -- reading the log -------------------------------------------------------------

## The log lines of [param text] (one JSON object per line) that can concern a motion round.
static func parse_lines(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n", false):
		if not line.contains("motion"):
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	return out


## One record per motion round in [param lines] (one visit = one log file, [param visit] names it),
## in the order the rounds began.
static func rounds_in(lines: Array, visit := "") -> Array:
	var by_key := {}
	var order: Array = []
	var older := 0
	for line: Dictionary in lines:
		var data: Dictionary = line.get("data", {})
		var key: Variant = null
		var round_line := {}
		if line.get("type") == "event" and line.get("what") == "motion_round_interrupted":
			key = int(data.get("round_serial", 0))
			round_line = {reason = data.get("reason", ""), coherence_start = data.get("coherence_start", data.get("coherence_shown")),
				first = data.get("first_attempt", {}), seconds_shown = data.get("seconds_shown")}
		elif line.get("type") == "trial_end" and (data.has("first_attempt_correct") or data.has("round_serial")) \
				and String(data.get("trial", "")).begins_with("motion"):
			if data.has("round_serial"):
				key = int(data.round_serial)
			else:
				older += 1
				key = "v1-%d" % older
			var attempts: Array = data.get("attempts", [])
			var values: Dictionary = data.get("values", {})
			var start: Variant = data.get("coherence_start")
			if start == null and values.has("signal_dots") and float(values.get("dots", 0)) > 0.0:
				start = float(values.signal_dots) / float(values.dots)
			round_line = {won = line.get("success", false), coherence_start = start,
				first = attempts[0] if not attempts.is_empty() else {}}
			if data.get("timed_out", false):
				round_line.reason = "timed_out"
			if not data.has("heading") and values.has("heading"):
				round_line.heading = values.heading
		else:
			continue
		if not by_key.has(key):
			by_key[key] = {visit = visit, key = key, version = int(data.get("log_version", 1)),
				trial = String(data.get("trial", "")), round = int(data.get("round", 0)),
				heading = String(data.get("heading", "")), mode = String(data.get("session_mode", "")),
				pinned = bool(data.get("level_pinned", false)), level_source = String(data.get("level_source", "")),
				view_dim = float(data.get("view_dim", 0.0)),
				won = false, reason = "", first = {}, coherence_start = null, time = line.get("time", 0.0)}
			order.append(key)
		var r: Dictionary = by_key[key]
		for field: String in round_line:
			var value: Variant = round_line[field]
			if field == "first" and (value as Dictionary).is_empty():
				continue
			if value == null or (value is String and value.is_empty()):
				continue
			r[field] = value
	var out: Array = []
	for key: Variant in order:
		out.append(_finish(by_key[key]))
	return out


## Every visit's log file in [param folder], oldest first.
static func visit_paths(folder: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(folder):
		return out
	for name in DirAccess.get_files_at(folder):
		if name.ends_with(".jsonl"):
			out.append(folder.path_join(name))
	out.sort()
	return out


## The rounds of the log files [param paths], in order.
static func load_rounds(paths: Array) -> Array:
	var out: Array = []
	for path: String in paths:
		if FileAccess.file_exists(path):
			out.append_array(rounds_in(parse_lines(FileAccess.get_file_as_string(path)), path.get_file().get_basename()))
	return out


static func _finish(r: Dictionary) -> Dictionary:
	var first: Dictionary = r.first
	r.group = group_of(r)
	if first.is_empty():
		r.status = "stopped"
		r.correct = null
		r.assisted = false
		r.coherence = r.coherence_start
		r.onset_s = null
	else:
		r.assisted = int(first.get("help", 0)) > 0
		r.status = "assisted" if r.assisted else "answered"
		r.correct = bool(first.get("correct", false))
		r.coherence = first.get("coherence_shown", r.coherence_start)
		r.onset_s = first.get("onset_seconds")
	if r.coherence_start == null:
		r.coherence_start = r.coherence
	r.eligible = r.status == "answered"
	return r


## Which group a round belongs to. Dev wins over pinned: a dev run is never real data.
## A dimmed round gets [constant DIM_SUFFIX]: its own group.
static func group_of(r: Dictionary) -> String:
	var base := _base_group(r)
	return base + DIM_SUFFIX if base != "unknown" and float(r.get("view_dim", 0.0)) > 0.0 else base


## The groups to page through: every base group, then each dimmed one that has rounds.
static func groups_in(rounds: Array) -> Array[String]:
	var out: Array[String] = []
	for g: String in GROUPS:
		out.append(g)
		if g != "unknown" and rounds.any(func(r: Dictionary) -> bool: return r.group == g + DIM_SUFFIX):
			out.append(g + DIM_SUFFIX)
	return out


static func group_title(group: String) -> String:
	if group.ends_with(DIM_SUFFIX):
		return "%s, dimmed room" % GROUP_TITLES[group.trim_suffix(DIM_SUFFIX)]
	return GROUP_TITLES[group]


## Coherence levels (10 % bands) with eligible rounds: graph 3 needs two or more.
static func coherence_levels(rounds: Array) -> int:
	var seen := {}
	for r: Dictionary in rounds:
		if r.eligible and r.coherence != null:
			seen[band(float(r.coherence))] = true
	return seen.size()


static func _base_group(r: Dictionary) -> String:
	if int(r.get("version", 1)) < 2:
		return "unknown"
	if r.get("mode", "") == "dev":
		return "dev"
	if r.get("pinned", false):
		return "pinned"
	return "play" if r.get("mode", "") == "play" else "unknown"


static func in_group(rounds: Array, group: String) -> Array:
	return rounds.filter(func(r: Dictionary) -> bool: return r.group == group)


## How many rounds each group has, so the tab can say what else there is.
static func group_counts(rounds: Array) -> Dictionary:
	var out := {}
	for g: String in GROUPS:
		out[g] = 0
	for r: Dictionary in rounds:
		out[r.group] = out.get(r.group, 0) + 1
	return out


# -- graph 1: round outcomes --------------------------------------------------------

## Counts for the outcome caption.
static func summary(rounds: Array) -> Dictionary:
	var out := {correct = 0, eligible = 0, assisted = 0, stopped = 0, rounds = rounds.size()}
	for r: Dictionary in rounds:
		if r.eligible:
			out.eligible += 1
			out.correct += 1 if r.correct else 0
		elif r.status == "assisted":
			out.assisted += 1
		else:
			out.stopped += 1
	return out


## The row an outcome is drawn in: "correct", "wrong", "assisted" or "stopped".
static func outcome(r: Dictionary) -> String:
	if r.status == "answered":
		return "correct" if r.correct else "wrong"
	return r.status


# -- graph 2: time to first sweep ----------------------------------------------------

## Median time to first sweep (s) over eligible rounds, with its n. median_s null when n = 0.
## It runs from the dots appearing to the first sweep, so it includes viewing time: the dots are
## still showing. Not a reaction time, and faster is not better.
static func median_first_sweep(rounds: Array) -> Dictionary:
	var values: Array = []
	for r: Dictionary in rounds:
		if r.eligible and r.onset_s != null:
			values.append(float(r.onset_s))
	values.sort()
	var n := values.size()
	if n == 0:
		return {median_s = null, n = 0}
	var mid := n / 2
	var median: float = values[mid] if n % 2 == 1 else (values[mid - 1] + values[mid]) / 2.0
	return {median_s = snappedf(median, 0.001), n = n}


# -- graph 3: accuracy versus coherence -----------------------------------------------

## 95 % Wilson score interval for k successes out of n. [lo, hi] as proportions; [] when n = 0.
## (As in tools/motion_lab/results.gd: sensible at small n and at 0/n or n/n.)
static func wilson(k: int, n: int) -> Array:
	if n <= 0:
		return []
	var p := float(k) / n
	var z2 := Z * Z
	var denom := 1.0 + z2 / n
	var centre := (p + z2 / (2.0 * n)) / denom
	var half := Z * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n)) / denom
	return [maxf(0.0, centre - half), minf(1.0, centre + half)]


## The 10 % band of a coherence (0..1): 0 = 0–9 %, ..., 9 = 90–100 %.
static func band(coherence: float) -> int:
	return clampi(floori(coherence * 10.0 + 0.000001), 0, 9)


## {task id: [{band, lo_pct, hi_pct, k, n, accuracy, ci}]}, eligible rounds only, bands in order.
static func coherence_series(rounds: Array) -> Dictionary:
	var counts := {}
	for r: Dictionary in rounds:
		if not r.eligible or r.coherence == null:
			continue
		var task: String = r.trial
		if not counts.has(task):
			counts[task] = {}
		var b := band(float(r.coherence))
		var bucket: Dictionary = counts[task].get(b, {k = 0, n = 0})
		bucket.n += 1
		bucket.k += 1 if r.correct else 0
		counts[task][b] = bucket
	var out := {}
	var tasks: Array = counts.keys()
	tasks.sort()
	for task: String in tasks:
		var points: Array = []
		var bands: Array = counts[task].keys()
		bands.sort()
		for b: int in bands:
			var c: Dictionary = counts[task][b]
			points.append({band = b, lo_pct = b * 10, hi_pct = 100 if b == 9 else b * 10 + 9, k = c.k, n = c.n,
				accuracy = float(c.k) / c.n, ci = wilson(c.k, c.n)})
		out[task] = points
	return out


static func task_title(task: String) -> String:
	return TASK_TITLES.get(task, task)
