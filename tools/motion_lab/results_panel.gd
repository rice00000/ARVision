extends CanvasLayer
## Optional post-block results (Nov 10 plan): three small graphs, in this order of importance.
##   1. Trial outcomes: trial number vs correct / incorrect (the primary view).
##   2. Time to registered answer: trial number vs seconds (secondary).
##   3. Accuracy versus coherence: observed points with 95 % Wilson intervals.
## Shapes and text carry the meaning, never colour alone. Gaps stay gaps. Nothing is fitted.
## Opening the panel never changes a record.

const Results := preload("res://tools/motion_lab/results.gd")

signal closed

var _title: Label
var _graphs: Array = []
var _footer: Label
var _scope_button: Button
var _series_button: Button
var _block := {}
var _record := {}
var _dataset: Array = []
var _scope_dataset := false
var _series_index := 0


func _ready() -> void:
	layer = 3
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.07, 0.09, 1.0)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	add_child(shade)
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 24.0
	box.offset_top = 20.0
	box.offset_right = -24.0
	box.offset_bottom = -16.0
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 17)
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for kind: StringName in [&"outcomes", &"timing", &"coherence"]:
		var graph := Graph.new()
		graph.kind = kind
		graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(graph)
		_graphs.append(graph)
	_footer = Label.new()
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_font_size_override("font_size", 14)
	_footer.modulate = Color(0.85, 0.85, 0.85)
	box.add_child(_footer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_scope_button = _button(buttons, "Coherence graph: this block", func() -> void:
		_scope_dataset = not _scope_dataset
		_series_index = 0
		_refresh())
	_series_button = _button(buttons, "Next condition series", func() -> void:
		_series_index += 1
		_refresh())
	_button(buttons, "Close results", func() -> void:
		visible = false
		closed.emit())


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Shows the results for [param block] of [param record]. [param dataset] = every record of the
## same dataset (see Results.dataset_records).
func show_results(record: Dictionary, block: Dictionary, dataset: Array) -> void:
	_record = record
	_block = block
	_dataset = dataset
	_scope_dataset = false
	_series_index = 0
	visible = true
	_refresh()


func _refresh() -> void:
	var c: Dictionary = _block.get("config", {})
	var t: Dictionary = _block.get("timing", {})
	_title.text = "Results for %s (%s) · dataset \"%s\"\nSettings: %s · coherence %d %% requested · input: %s · %d trials planned. Six trials describe this block only: not an ability estimate." % [
		_block.get("id", "?"), _block.get("status", "?"), _record.get("dataset_id", "?"),
		_block.get("condition_label", "?"), roundi(float(c.get("coherence", 0.0)) * 100.0),
		_block.get("input", "?"), int(_block.get("trials_planned", 0))]
	var rows := Results.outcome_rows(_block)
	var summary := Results.block_summary(_block)
	var median := Results.median_latency(_block)
	var only := "" if _scope_dataset else "%s/%s" % [_record.get("file_stem", "?"), _block.get("id", "?")]
	var series := Results.coherence_series(_dataset, String(_record.get("dataset_id", "")), only)
	var keys: Array = series.keys()
	var key: String = ""
	if not keys.is_empty():
		# Default to this block's own condition; "Next condition series" steps through the others.
		var own: String = _block.get("condition_key", "")
		var start := maxi(keys.find(own), 0)
		key = keys[(start + _series_index) % keys.size()]
	_scope_button.text = "Coherence graph: %s" % ("whole dataset" if _scope_dataset else "this block")
	_series_button.visible = keys.size() > 1
	_graphs[0].set_data({rows = rows, summary = summary})
	_graphs[1].set_data({rows = rows, median = median})
	_graphs[2].set_data({series = series.get(key, {}), count = keys.size(), index = keys.find(key),
		scope = "whole dataset" if _scope_dataset else "this block"})
	_footer.text = "Correct: %d of %d eligible (unassisted, completed). Not counted: %d interrupted, %d abandoned, %d with no answer, %d assisted. Time to registered answer = from response enabled (dots off) to the accepted answer: a post-exposure response latency, not motion-onset reaction time; faster is not automatically better. Accuracy points pool only matching conditions in this dataset, with 95 %% Wilson intervals; no fitted curve and no threshold." % [
		summary.correct, summary.eligible, summary.interrupted, summary.abandoned, summary.missing, summary.assisted]


class Graph extends Control:
	var kind: StringName
	var data := {}
	const INK := Color(0.92, 0.94, 0.96)
	const MUTED := Color(0.6, 0.63, 0.68)
	const GOOD := Color(0.45, 0.8, 1.0)
	const BAD := Color(1.0, 0.72, 0.4)

	func set_data(d: Dictionary) -> void:
		data = d
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.04))
		var title: String = {&"outcomes": "1 · Trial outcomes", &"timing": "2 · Time to registered answer",
			&"coherence": "3 · Accuracy versus coherence"}[kind]
		draw_string(font, Vector2(10, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
		var plot := Rect2(Vector2(54, 64), size - Vector2(70, 150))
		match kind:
			&"outcomes": _outcomes(font, plot)
			&"timing": _timing(font, plot)
			&"coherence": _coherence(font, plot)
		_legend(font, Vector2(10, size.y - 12))

	func _legend(font: Font, at: Vector2) -> void:
		_mark(at + Vector2(6, -5), true)
		draw_string(font, at + Vector2(16, 0), "correct", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		_mark(at + Vector2(86, -5), false)
		draw_string(font, at + Vector2(96, 0), "incorrect", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		if kind != &"coherence":
			draw_rect(Rect2(at + Vector2(176, -10), Vector2(10, 10)), MUTED, false, 2.0)
			draw_string(font, at + Vector2(192, 0), "assisted   – no answer (gap)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)

	## Filled circle = correct; X = incorrect (shape, not just colour).
	func _mark(at: Vector2, correct: bool) -> void:
		if correct:
			draw_circle(at, 6.0, GOOD)
		else:
			draw_line(at + Vector2(-6, -6), at + Vector2(6, 6), BAD, 3.0)
			draw_line(at + Vector2(-6, 6), at + Vector2(6, -6), BAD, 3.0)

	func _axes(font: Font, plot: Rect2, x_label: String, y_label: String) -> void:
		draw_line(plot.position + Vector2(0, plot.size.y), plot.end, MUTED, 1.0)
		draw_line(plot.position, plot.position + Vector2(0, plot.size.y), MUTED, 1.0)
		draw_string(font, Vector2(plot.position.x, plot.end.y + 50), x_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		draw_string(font, Vector2(4, plot.position.y - 6), y_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)

	func _slot_x(plot: Rect2, slot: int, count: int) -> float:
		return plot.position.x + plot.size.x * (float(slot) - 0.5) / maxf(count, 1)

	func _outcomes(font: Font, plot: Rect2) -> void:
		var rows: Array = data.get("rows", [])
		_axes(font, plot, "trial number (direction · realized coherence below)", "")
		var y_ok := plot.position.y + plot.size.y * 0.25
		var y_no := plot.position.y + plot.size.y * 0.75
		draw_string(font, Vector2(4, y_ok + 5), "correct", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		draw_string(font, Vector2(4, y_no + 5), "incorr.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		if rows.is_empty():
			draw_string(font, plot.get_center() - Vector2(90, 0), "No trials in this block.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
			return
		for row: Dictionary in rows:
			var x := _slot_x(plot, row.slot, rows.size())
			draw_string(font, Vector2(x - 4, plot.end.y + 16), str(row.slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
			var below := "%s" % ("L" if row.direction == "left" else "R")
			if row.coherence_pct != null:
				below += " %d%%" % roundi(float(row.coherence_pct))
			draw_string(font, Vector2(x - 14, plot.end.y + 30), below, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
			if not row.answered:
				draw_string(font, Vector2(x - 4, plot.get_center().y + 5), "–", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MUTED)
			elif not row.eligible:
				draw_rect(Rect2(Vector2(x - 6, plot.get_center().y - 6), Vector2(12, 12)), MUTED, false, 2.0)
			else:
				_mark(Vector2(x, y_ok if row.correct == true else y_no), row.correct == true)
		var s: Dictionary = data.get("summary", {})
		draw_string(font, Vector2(plot.position.x, plot.position.y - 24), "correct %d of %d eligible" % [s.get("correct", 0), s.get("eligible", 0)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)

	func _timing(font: Font, plot: Rect2) -> void:
		var rows: Array = data.get("rows", [])
		var top := 2.0
		for row: Dictionary in rows:
			if row.latency_s != null:
				top = maxf(top, ceilf(float(row.latency_s)))
		_axes(font, plot, "trial number", "seconds")
		for i in int(top) + 1:
			var y := plot.end.y - plot.size.y * i / top
			draw_line(Vector2(plot.position.x - 4, y), Vector2(plot.position.x, y), MUTED)
			draw_string(font, Vector2(plot.position.x - 22, y + 5), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
		var any := false
		for row: Dictionary in rows:
			var x := _slot_x(plot, row.slot, rows.size())
			draw_string(font, Vector2(x - 4, plot.end.y + 16), str(row.slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
			if row.latency_s == null:
				continue   # a gap, never a zero
			any = true
			var y := plot.end.y - plot.size.y * float(row.latency_s) / top
			if not row.eligible:
				draw_rect(Rect2(Vector2(x - 6, y - 6), Vector2(12, 12)), MUTED, false, 2.0)
			else:
				_mark(Vector2(x, y), row.correct == true)
		var m: Dictionary = data.get("median", {})
		if m.get("median_s") != null:
			var y := plot.end.y - plot.size.y * float(m.median_s) / top
			for x in range(int(plot.position.x), int(plot.end.x), 12):
				draw_line(Vector2(x, y), Vector2(x + 6, y), MUTED, 1.0)
			draw_string(font, Vector2(plot.position.x + 4, y - 6), "median %.2f s (n = %d eligible)" % [m.median_s, m.n],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		if not any:
			draw_string(font, plot.get_center() - Vector2(90, 0), "No registered answers yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)

	func _coherence(font: Font, plot: Rect2) -> void:
		_axes(font, plot, "tested coherence (%, realized)", "accuracy %")
		for v: int in [0, 25, 50, 75, 100]:
			var y := plot.end.y - plot.size.y * v / 100.0
			draw_string(font, Vector2(plot.position.x - 30, y + 5), str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
			var x := plot.position.x + plot.size.x * v / 100.0
			draw_string(font, Vector2(x - 8, plot.end.y + 16), str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
		var series: Dictionary = data.get("series", {})
		draw_string(font, Vector2(plot.position.x, plot.position.y - 22), "scope: %s · series %d of %d" % [
			data.get("scope", "?"), int(data.get("index", 0)) + 1, int(data.get("count", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		if series.is_empty():
			draw_string(font, plot.get_center() - Vector2(130, 10), "No eligible judgments yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
			draw_string(font, plot.get_center() - Vector2(130, -12), "Complete a block to add a point.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
			return
		draw_string(font, Vector2(plot.position.x + 60, plot.position.y - 6), String(series.label), HORIZONTAL_ALIGNMENT_LEFT, plot.size.x - 60, 11, MUTED)
		for p: Dictionary in series.points:
			var x := plot.position.x + plot.size.x * float(p.coherence_pct) / 100.0
			var lo: float = p.ci[0]
			var hi: float = p.ci[1]
			var y_lo := plot.end.y - plot.size.y * lo
			var y_hi := plot.end.y - plot.size.y * hi
			draw_line(Vector2(x, y_lo), Vector2(x, y_hi), INK, 2.0)
			draw_line(Vector2(x - 6, y_lo), Vector2(x + 6, y_lo), INK, 2.0)
			draw_line(Vector2(x - 6, y_hi), Vector2(x + 6, y_hi), INK, 2.0)
			var y := plot.end.y - plot.size.y * float(p.accuracy)
			draw_circle(Vector2(x, y), 6.0, GOOD)
			draw_string(font, Vector2(x + 9, y + 5), "%d/%d" % [p.k, p.n], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
