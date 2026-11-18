extends Node
## Pictures of the three motion results graphs with sample rounds (Graphs chat, Nov 17).
##   xvfb-run -a godot --rendering-driver opengl3 --xr-mode off --path . res://modules/results/results_shots.tscn -- --out=build/graphs
## Writes outcomes.png, timing.png, coherence.png, empty.png. The sample is made up, for the look only.

func _ready() -> void:
	var out := "build/graphs"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var shots := {outcomes = [&"outcomes", sample()], timing = [&"timing", sample()],
		coherence = [&"coherence", sample()], empty = [&"outcomes", []]}
	for name: String in shots:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(ResultsGraph.SIZE)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var graph := ResultsGraph.new()
		viewport.add_child(graph)
		add_child(viewport)
		graph.show_rounds(shots[name][0], shots[name][1], "Play · this visit" if name != "coherence" else "Play · all visits")
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(out.path_join(name + ".png"))
		viewport.queue_free()
	print("RESULTS SHOTS in ", out)
	get_tree().quit()


## Twelve made-up rounds of the spell wall at its two levels: right, wrong, helped and stopped.
static func sample() -> Array:
	var spec := [[true, 0.9, 0, 2.1], [true, 0.9, 0, 1.8], [false, 0.9, 0, 3.4], [true, 0.6, 0, 2.6],
		[null, 0.6, 0, 0.0], [true, 0.6, 1, 4.9], [false, 0.6, 0, 2.2], [true, 0.6, 0, 3.0],
		[true, 0.9, 0, 1.6], [false, 0.6, 0, 5.2], [true, 0.6, 0, 2.4], [true, 0.9, 0, 1.9]]
	var headings := ["left", "right", "right", "left", "right", "left", "left", "right", "left", "right", "left", "right"]
	var lines: Array = []
	for i in spec.size():
		var s: Array = spec[i]
		var stamp := {trial = "motion_demo", round = i, log_version = 2, session_mode = "play", level_pinned = false,
			level_source = "fixed", round_serial = i + 1, heading = headings[i], coherence_start = s[1]}
		if s[0] == null:
			lines.append({type = "event", what = "motion_round_interrupted", data = stamp.merged({coherence_shown = s[1],
				help = 0, seconds_shown = 6.0, reason = "skipped", attempts = 0, first_attempt = {}})})
			continue
		var first := {correct = s[0], help = s[2], coherence_shown = 1.0 if s[2] > 0 else s[1], onset_seconds = s[3]}
		lines.append({type = "trial_end", success = true, data = stamp.merged({attempts = [first], first_attempt_correct = s[0]})})
	return MotionResults.rounds_in(lines)
