class_name ResultsGraph
extends Control
## One motion results graph, drawn flat for the Staff tools Results tab (Graphs chat, Nov 17).
## The tab renders it in a SubViewport onto the panel ([ResultsView]); the picture scripts and tests
## draw it the same way. Grown-up look (UI style B, core/ui_style.gd): slate and sage.
##   &"outcomes"  graph 1: each round's first try, in rows (right / wrong / helped / stopped)
##   &"timing"    graph 2: time to first sweep, the dots still showing; median of counted rounds
##   &"coherence" graph 3: right on first try per 10 % coherence band, 95 % Wilson bars, no fit
## Meaning is carried by shape and words, never colour alone. Gaps stay gaps; nothing is fitted.
## Readable at arm's length: drawn at [constant SIZE] for a 0.40 m wide quad (×1.2) at 0.55 m, so
## the smallest text (28 px) is about 1 degree tall and the main text about 1.4 degrees.

const SIZE := Vector2(1000, 600)
## Most rounds graph 1 and 2 show (the latest ones).
const MAX_ROUNDS := 10

const BACK := Color(0.17, 0.19, 0.24)
const INK := Color(0.94, 0.94, 0.9)
const MUTED := Color(0.68, 0.71, 0.74)
const GRID := Color(1, 1, 1, 0.13)
## Checked with the dataviz validator on the slate surface (dark): both pass every check.
const RIGHT := Color("#3A8FC4")
const WRONG := Color("#D2702A")
const ARROWS := {left = "←", right = "→", toward = "↓", away = "↑"}

var kind: StringName = &"outcomes"
## The rounds to show (already one group and one scope), oldest first.
var rounds: Array = []
## Shown top right, e.g. "Play · this visit".
var context := ""
## Graph 3: which task's series (index into the sorted task ids).
var task_index := 0

var _font: Font


func _init() -> void:
	size = SIZE
	_font = ThemeDB.fallback_font


func show_rounds(graph_kind: StringName, shown: Array, context_text: String, task := 0) -> void:
	kind = graph_kind
	rounds = shown
	context = context_text
	task_index = task
	queue_redraw()


## Task ids graph 3 has a series for.
func tasks() -> Array:
	return MotionResults.coherence_series(rounds).keys()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BACK)
	match kind:
		&"outcomes": _draw_outcomes()
		&"timing": _draw_timing()
		&"coherence": _draw_coherence()


# -- graph 1 -----------------------------------------------------------------------

func _draw_outcomes() -> void:
	var s := MotionResults.summary(rounds)
	_header("Round outcomes · first try",
		"Right %d of %d counted · %d helped · %d stopped" % [s.correct, s.eligible, s.assisted, s.stopped])
	if rounds.is_empty():
		_empty("No dots rounds yet")
		return
	var shown := rounds.slice(maxi(0, rounds.size() - MAX_ROUNDS))
	var rows := [["correct", "Right"], ["wrong", "Wrong"], ["assisted", "Helped"], ["stopped", "Stopped"]]
	var left := 250.0
	var top := 170.0
	var row_h := 62.0
	var col_w := (SIZE.x - left - 30.0) / MAX_ROUNDS
	for i in rows.size():
		var y := top + row_h * (i + 0.5)
		_text(Vector2(70, y + 13), rows[i][1], 36, INK)
		_mark(rows[i][0], Vector2(40, y), 12.0)
		draw_line(Vector2(left - 10, y), Vector2(SIZE.x - 20, y), GRID, 2.0)
	for c in shown.size():
		var r: Dictionary = shown[c]
		var x: float = left + col_w * (c + 0.5)
		var row := rows.map(func(pair: Array) -> String: return pair[0]).find(MotionResults.outcome(r))
		_mark(rows[row][0], Vector2(x, top + row_h * (row + 0.5)), 15.0)
		var base := top + row_h * rows.size() + 44.0
		_text_centred(Vector2(x, base), str(rounds.size() - shown.size() + c + 1), 34, INK)
		_text_centred(Vector2(x, base + 40), ARROWS.get(String(r.heading), "·"), 34, MUTED)
		if r.coherence_start != null:
			_text_centred(Vector2(x, base + 76), "%d%%" % roundi(float(r.coherence_start) * 100.0), 28, MUTED)
	var foot := "Round · direction · coherence"
	if rounds.size() > MAX_ROUNDS:
		foot += "   (last %d of %d)" % [MAX_ROUNDS, rounds.size()]
	_text(Vector2(24, SIZE.y - 18), foot, 28, MUTED)


# -- graph 2 -----------------------------------------------------------------------

func _draw_timing() -> void:
	var median := MotionResults.median_first_sweep(rounds)
	_header("Time to first sweep", "Dots still showing · not reaction time · faster isn't better")
	if rounds.is_empty():
		_empty("No dots rounds yet")
		return
	var shown := rounds.slice(maxi(0, rounds.size() - MAX_ROUNDS))
	var top_s := 2.0
	for r: Dictionary in shown:
		if r.onset_s != null:
			top_s = maxf(top_s, float(r.onset_s))
	var step := 1.0 if top_s <= 6.0 else (2.0 if top_s <= 12.0 else 5.0)
	top_s = ceilf(top_s / step) * step
	var plot := Rect2(130, 150, SIZE.x - 260, 310)   # room on the right for the median's tag
	var y_of := func(seconds: float) -> float: return plot.end.y - plot.size.y * seconds / top_s
	var tick := 0.0
	while tick <= top_s + 0.001:
		var y: float = y_of.call(tick)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID, 2.0)
		_text_right(Vector2(plot.position.x - 14, y + 11), "%d s" % roundi(tick), 30, MUTED)
		tick += step
	var col_w := plot.size.x / MAX_ROUNDS
	for c in shown.size():
		var r: Dictionary = shown[c]
		var x := plot.position.x + col_w * (c + 0.5)
		if r.onset_s == null:
			_mark("stopped", Vector2(x, plot.end.y + 66), 12.0) # stopped: a gap under the axis, never a zero time
		else:
			_mark(MotionResults.outcome(r), Vector2(x, y_of.call(float(r.onset_s))), 14.0)
		_text_centred(Vector2(x, plot.end.y + 40), str(rounds.size() - shown.size() + c + 1), 32, INK)
	if median.n > 0:
		var y: float = y_of.call(float(median.median_s))
		_dashed(Vector2(plot.position.x, y), Vector2(plot.end.x, y), INK)
		_text(Vector2(plot.end.x + 12, y - 8), "median", 28, INK)
		_text(Vector2(plot.end.x + 12, y + 22), "%.1f s" % median.median_s, 28, INK)
		_text(Vector2(plot.end.x + 12, y + 52), "n %d" % median.n, 28, MUTED)
	_text(Vector2(24, SIZE.y - 18), "Round   ● right  ✕ wrong  □ helped  – stopped (no time)", 28, MUTED)


# -- graph 3 -----------------------------------------------------------------------

func _draw_coherence() -> void:
	var series := MotionResults.coherence_series(rounds)
	var ids := series.keys()
	var task: String = ids[task_index % ids.size()] if not ids.is_empty() else ""
	var subtitle := "%s · counted rounds · 95 %% intervals, no fit" % MotionResults.task_title(task) if task else \
		"Counted rounds · 95 % intervals, no fit"
	if ids.size() > 1:
		subtitle += " · %d of %d tasks" % [task_index % ids.size() + 1, ids.size()]
	_header("Right on first try vs coherence", subtitle)
	var plot := Rect2(130, 160, SIZE.x - 170, 330)
	for pct in [0, 50, 100]:
		var y: float = plot.end.y - plot.size.y * pct / 100.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID, 2.0)
		_text_right(Vector2(plot.position.x - 14, y + 11), "%d%%" % pct, 30, MUTED)
	var band_w := plot.size.x / 10.0
	for b in 11:
		var x := plot.position.x + band_w * b
		draw_line(Vector2(x, plot.end.y), Vector2(x, plot.end.y + 10), MUTED, 2.0)
		if b % 2 == 0:
			_text_centred(Vector2(x, plot.end.y + 44), "%d" % (b * 10), 30, MUTED)
	if task == "":
		_empty("No counted rounds yet")
		return
	for p: Dictionary in series[task]:
		var x: float = plot.position.x + band_w * (p.band + 0.5)
		var lo: float = p.ci[0]
		var hi: float = p.ci[1]
		var y_lo := plot.end.y - plot.size.y * lo
		var y_hi := plot.end.y - plot.size.y * hi
		draw_line(Vector2(x, y_lo), Vector2(x, y_hi), INK, 3.0)
		draw_line(Vector2(x - 12, y_lo), Vector2(x + 12, y_lo), INK, 3.0)
		draw_line(Vector2(x - 12, y_hi), Vector2(x + 12, y_hi), INK, 3.0)
		var at := Vector2(x, plot.end.y - plot.size.y * float(p.accuracy))
		draw_circle(at, 15.0, BACK)
		draw_circle(at, 12.0, RIGHT)
		_text_centred(Vector2(x, maxf(y_hi - 14, 150.0)), "%d/%d" % [p.k, p.n], 32, INK)
	_text(Vector2(24, SIZE.y - 18), "Coherence (%, in 10 % bands) · the bar is how unsure we are", 28, MUTED)


# -- pieces ------------------------------------------------------------------------

func _header(title: String, subtitle: String) -> void:
	draw_rect(Rect2(0, 0, SIZE.x, 8), UIStyle.STAFF_HEADER)
	_text(Vector2(24, 62), title, 44, INK)
	_text(Vector2(24, 110), subtitle, 30, MUTED)
	if context != "":
		_text_right(Vector2(SIZE.x - 24, 62), context, 32, UIStyle.STAFF_HEADER)


func _empty(message: String) -> void:
	_text_centred(Vector2(SIZE.x * 0.5, SIZE.y * 0.55), message, 40, MUTED)


## A round's mark: ● right, ✕ wrong, □ helped, – stopped.
func _mark(what: String, at: Vector2, radius: float) -> void:
	match what:
		"correct":
			draw_circle(at, radius, RIGHT)
		"wrong":
			var d := radius * 0.9
			draw_line(at + Vector2(-d, -d), at + Vector2(d, d), WRONG, 6.0)
			draw_line(at + Vector2(-d, d), at + Vector2(d, -d), WRONG, 6.0)
		"assisted":
			draw_rect(Rect2(at - Vector2.ONE * radius * 0.9, Vector2.ONE * radius * 1.8), MUTED, false, 4.0)
		_:
			draw_line(at + Vector2(-radius, 0), at + Vector2(radius, 0), MUTED, 4.0)


func _dashed(from: Vector2, to: Vector2, colour: Color) -> void:
	draw_dashed_line(from, to, colour, 3.0, 14.0)


func _text(at: Vector2, text: String, font_size: int, colour: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _text_centred(at: Vector2, text: String, font_size: int, colour: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _text_right(at: Vector2, text: String, font_size: int, colour: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
