extends Node3D

const BASELINE := preload("res://trials/motion/motion_demo.tres")
const VOLUME_SHADER := preload("res://trials/motion/motion_dots.gdshader")
const FLAT_SHADER := preload("res://tools/motion_lab/flat_dots.gdshader")
const BlockConfig := preload("res://tools/motion_lab/block_config.gd")
const TrialBlock := preload("res://tools/motion_lab/trial_block.gd")
const BlockPanel := preload("res://tools/motion_lab/block_panel.gd")
const BlockSetup := preload("res://tools/motion_lab/block_setup.gd")
const Results := preload("res://tools/motion_lab/results.gd")
const ResultsPanel := preload("res://tools/motion_lab/results_panel.gd")
const DOT_SHADER := preload("res://tools/motion_lab/blur_dot.gdshader")
const DATASET_FILE := "user://motion_lab_records/dataset.txt"

var coherence := 0.9
var heading := 1.0
var flat_mode := false
var current: Dictionary = {}
var cloud: GPUParticles3D
var _backdrop: MeshInstance3D
var _details: Label
## Trial block mode (Nov 9): teaching, a six-trial block, pause/leave and a developer record.
var block_mode := false
var trials: RefCounted
var block_config_name := "preview_rectangle"
var _panel: CanvasLayer
var _fixation: Label3D
var _frames_at_onset := 0
var _note: Label
var dataset_id := ""
## Where records go. The scripted walkthrough uses its own folder and dataset so it can never
## mix into a real review dataset.
var records_dir := "user://motion_lab_records"
var _forced_dataset := ""
var _setup: CanvasLayer
var _results: CanvasLayer
var _sphere: Mesh
var _quad: QuadMesh
var _return_to_setup := false

static func settings(flat: bool, selected_coherence: float, selected_heading: float) -> Dictionary:
	var condition := BASELINE.condition(0.0, 0, false)
	var count := int(condition.value(&"dots"))
	return {
		mode = "flat_centres" if flat else "original_volume",
		dots = count,
		signal_count = roundi(clampf(selected_coherence, 0.0, 1.0) * count),
		half_size = Vector3(condition.value(&"half_width"), condition.value(&"half_height"),
			0.0 if flat else condition.value(&"half_depth")),
		distance = condition.value(&"distance"),
		speed = condition.value(&"speed"),
		dot_lifetime = condition.value(&"dot_lifetime"),
		radius = 0.02,
		seed = 42,
		flow = Vector3.RIGHT if selected_heading >= 0.0 else Vector3.LEFT,
		noise_dimensions = 2 if flat else 3,
	}

func _ready() -> void:
	get_window().size = Vector2i(1280, 900)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.3, 0.0)
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.27, 0.30, 0.34)
	add_child(world)
	_backdrop = MeshInstance3D.new()
	var panel := QuadMesh.new()
	panel.size = Vector2(5.0, 3.0)
	_backdrop.mesh = panel
	var panel_material := StandardMaterial3D.new()
	panel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel_material.albedo_color = Color(0.035, 0.045, 0.055)
	_backdrop.material_override = panel_material
	add_child(_backdrop)
	cloud = GPUParticles3D.new()
	cloud.lifetime = 1000.0
	cloud.explosiveness = 1.0
	cloud.fixed_fps = 0
	cloud.local_coords = true
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dots := SphereMesh.new()
	dots.radius = 0.02
	dots.height = 0.04
	dots.radial_segments = 8
	dots.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.75, 0.95, 1.0)
	dots.material = material
	cloud.draw_pass_1 = dots
	add_child(cloud)
	_fixation = Label3D.new()
	_fixation.text = "+"
	_fixation.font_size = 96
	_fixation.pixel_size = 0.001
	_fixation.modulate = Color(0.85, 0.85, 0.85)
	_fixation.visible = false
	add_child(_fixation)
	_build_controls()
	set_mode(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture.call_deferred(argument.trim_prefix("--capture-dir="))
		elif argument == "--block":
			enter_block_mode.call_deferred()
		elif argument.begins_with("--block-walkthrough="):
			_walkthrough.call_deferred(argument.trim_prefix("--block-walkthrough="))

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.position = Vector2(24, 18)
	layer.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "MOTION STIMULUS LAB — desktop preview, not a research test"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	_button(controls, "3D volume", func() -> void: set_mode(false))
	_button(controls, "Flat field", func() -> void: set_mode(true))
	_button(controls, "Left / right", func() -> void:
		heading = -heading
		set_mode(flat_mode))
	_button(controls, "Coherence", func() -> void:
		coherence = 0.7 if coherence > 0.8 else (0.4 if coherence > 0.5 else 0.9)
		set_mode(flat_mode))
	_button(controls, "Background", func() -> void:
		_backdrop.visible = not _backdrop.visible)
	_button(controls, "Restart seed", func() -> void: set_mode(flat_mode))
	_button(controls, "Trial block", func() -> void:
		if block_mode:
			exit_block_mode()
		else:
			enter_block_mode())
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 17)
	column.add_child(_details)
	_note = Label.new()
	_note.text = "No scoring, answers or participant logs. Both modes use the same sphere mesh.\nFlat centres + XY noise differ from volume + XYZ noise; this is not a one-variable or calibrated comparison."
	column.add_child(_note)

func _button(parent: HBoxContainer, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)

func set_mode(flat: bool) -> void:
	if block_mode:
		return   # the block owns the dots; leave block mode to preview again
	flat_mode = flat
	current = settings(flat, coherence, heading)
	if cloud == null:
		return
	var material := ShaderMaterial.new()
	material.shader = FLAT_SHADER if flat else VOLUME_SHADER
	for key: String in ["half_size", "signal_count", "dot_count", "trial_seed", "flow_direction", "speed", "dot_lifetime"]:
		var source: String = {"dot_count": "dots", "trial_seed": "seed", "flow_direction": "flow"}.get(key, key)
		material.set_shader_parameter(key, current[source])
	cloud.process_material = material
	cloud.amount = current.dots
	cloud.position = Vector3(0.0, 1.3, -current.distance)
	cloud.visibility_aabb = AABB(-current.half_size - Vector3.ONE * 0.1,
		current.half_size * 2.0 + Vector3.ONE * 0.2)
	_backdrop.position = Vector3(0.0, 1.3, -(current.distance + 1.0))
	cloud.restart()
	var width := rad_to_deg(2.0 * atan(current.half_size.x / current.distance))
	var height := rad_to_deg(2.0 * atan(current.half_size.y / current.distance))
	_details.text = "%s | %s | %d/%d signal | %.1f m/s | lifetime %.1f s | seed %d\nCentre %.1f m away | centre-plane extent %.1f x %.1f deg | half-depth %.1f m | noise %dD" % [
		current.mode, "right" if heading >= 0.0 else "left", current.signal_count, current.dots,
		current.speed, current.dot_lifetime, current.seed, current.distance,
		width, height, current.half_size.z, current.noise_dimensions]

func _capture(directory: String) -> void:
	var target := ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(target)
	if error != OK:
		push_error("Cannot create capture directory: %s" % target)
		get_tree().quit(1)
		return
	for flat: bool in [false, true]:
		set_mode(flat)
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		error = get_viewport().get_texture().get_image().save_png(target.path_join(current.mode + ".png"))
		if error != OK:
			push_error("Cannot save capture")
			get_tree().quit(1)
			return
	print("Motion lab captures: ", target)
	get_tree().quit()


# --- Trial block mode (Nov 9 plan) -------------------------------------------------------
# Teaching, a repeatable block of trials, neutral acknowledgement, pause/leave and a
# developer record. Flow and recording live in trial_block.gd, settings in block_config.gd,
# the panel in block_panel.gd. Desktop keys/buttons are a FALLBACK for checking the flow;
# they do not verify the intended hand sweep or Quest presentation.

func enter_block_mode() -> void:
	if block_mode:
		return
	block_mode = true
	_backdrop.visible = true
	cloud.visible = false
	trials = TrialBlock.new()
	trials.save_dir = records_dir
	trials.phase_changed.connect(_on_phase)
	trials.exposure_requested.connect(_on_exposure_requested)
	trials.exposure_ended.connect(_on_exposure_ended)
	trials.message_changed.connect(func(_text: String) -> void: _on_phase(trials.phase))
	if _panel == null:
		_panel = BlockPanel.new()
		add_child(_panel)
		_panel.pressed.connect(_on_panel)
	_panel.visible = true
	_details.visible = false   # the preview's labels describe the preview, not the block
	_note.visible = false
	if _quad == null:
		_quad = QuadMesh.new()
		var dot_material := ShaderMaterial.new()
		dot_material.shader = DOT_SHADER
		_quad.material = dot_material
		_sphere = cloud.draw_pass_1
	cloud.draw_pass_1 = _quad   # block mode draws flat discs that can carry stimulus-only blur
	if _setup == null:
		_setup = BlockSetup.new()
		add_child(_setup)
		_setup.visible = false
		_setup.changed.connect(func(s: Dictionary, t: Dictionary) -> void:
			trials.set_config(s, t)
			_on_phase(trials.phase))
		_setup.action.connect(_on_setup_action)
		_results = ResultsPanel.new()
		add_child(_results)
		_results.visible = false
		_results.closed.connect(func() -> void:
			_panel.visible = true
			_on_phase(trials.phase))
	dataset_id = _load_dataset()
	await _warm_up()
	trials.begin(_stimulus(), BlockConfig.timing(), Time.get_ticks_usec(), -1, _display_info(), dataset_id)


func exit_block_mode() -> void:
	if not block_mode:
		return
	if trials != null and trials.phase != &"left":
		trials.leave(Time.get_ticks_usec())
	block_mode = false
	_fixation.visible = false
	_panel.visible = false
	_setup.visible = false
	_results.visible = false
	cloud.draw_pass_1 = _sphere
	_details.visible = true
	_note.visible = true
	cloud.visible = true
	set_mode(flat_mode)


## Draws the block's dot material once, hidden behind the backdrop, so the first real
## exposure is not delayed by shader compilation (measured: first frame ~410 ms late without it).
func _warm_up() -> void:
	for config_name: String in ["preview_rectangle", "reference_circle_10deg"]:
		var c := BlockConfig.by_name(config_name, coherence)
		var fake := {purpose = "warm_up", coherence = c.coherence, seed = 1, direction = "right"}
		_apply_stimulus(fake, c)
		cloud.position.z -= 50.0
		cloud.restart()
		cloud.visible = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	cloud.visible = false


func _stimulus() -> Dictionary:
	return BlockConfig.by_name(block_config_name, coherence)


func _display_info() -> Dictionary:
	var screen := DisplayServer.screen_get_refresh_rate()
	return {
		app = "ARVision motion lab, trial block (desktop, XR off)",
		godot = Engine.get_version_info().string,
		renderer = RenderingServer.get_current_rendering_driver_name(),
		window = [get_window().size.x, get_window().size.y],
		screen_refresh_hz = snappedf(screen, 0.1) if screen > 0.0 else "unknown",
		camera_fov_deg = get_viewport().get_camera_3d().fov if get_viewport().get_camera_3d() != null else "unknown",
		xr = false,
		verified_on_headset = false,
		input = "desktop fallback (keys/buttons); hand sweep not wired or verified",
	}


func _process(_delta: float) -> void:
	if block_mode and trials != null:
		trials.tick(Time.get_ticks_usec())


func _unhandled_input(event: InputEvent) -> void:
	if not block_mode or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var now := Time.get_ticks_usec()
	match (event as InputEventKey).keycode:
		KEY_LEFT:
			trials.answer(-1, "desktop_key", now)
		KEY_RIGHT:
			trials.answer(1, "desktop_key", now)
		KEY_SPACE, KEY_ENTER:
			if not trials.next(now):
				trials.end_rest(now)
		KEY_P:
			if not trials.pause(now):
				trials.resume(now)
		KEY_ESCAPE:
			trials.leave(now)
		_:
			return
	get_viewport().set_input_as_handled()


func _on_panel(action: StringName) -> void:
	var now := Time.get_ticks_usec()
	match action:
		&"demo": trials.start_demo(now)
		&"practice": trials.start_practice(now)
		&"start", &"repeat": trials.start_block(now)
		&"left": trials.answer(-1, "desktop_button", now)
		&"right": trials.answer(1, "desktop_button", now)
		&"next": trials.next(now)
		&"pause": trials.pause(now)
		&"resume": trials.resume(now)
		&"rest": trials.rest(now)
		&"continue": trials.end_rest(now)
		&"leave": trials.leave(now)
		&"setup":
			open_setup()
		&"change_setup":
			if trials.end_block_for_setup(now):
				open_setup()
		&"results":
			open_results()
	_on_phase(trials.phase)


func _on_phase(phase: StringName) -> void:
	_fixation.visible = block_mode and phase == &"prepare"
	if phase == &"menu" and _return_to_setup:
		_return_to_setup = false
		open_setup.call_deferred()
	if not trials.config.is_empty():
		_fixation.position = Vector3(0.0, 1.3, -float(trials.config.distance_m) + 0.01)
	if _panel != null:
		_panel.show_state(trials)


func _on_exposure_requested(a: Dictionary) -> void:
	_apply_stimulus(a)
	cloud.restart()
	cloud.visible = true
	_fixation.visible = false
	_frames_at_onset = Engine.get_frames_drawn()
	await RenderingServer.frame_post_draw
	trials.note_presented(a.id, Time.get_ticks_usec())


func _on_exposure_ended(a: Dictionary) -> void:
	cloud.visible = false
	var shown := Engine.get_frames_drawn() - _frames_at_onset
	await RenderingServer.frame_post_draw
	trials.note_hidden(a.id, Time.get_ticks_usec(), shown)


func _apply_stimulus(a: Dictionary, given := {}) -> void:
	var c: Dictionary = given if not given.is_empty() else (trials.block.config if a.purpose == "review" else trials.config)
	var dots := int(c.dots)
	var material := ShaderMaterial.new()
	material.shader = FLAT_SHADER
	material.set_shader_parameter("half_size", Vector3(float(c.half_width_m), float(c.half_height_m), 0.0))
	material.set_shader_parameter("signal_count", roundi(clampf(float(a.coherence), 0.0, 1.0) * dots))
	material.set_shader_parameter("dot_count", dots)
	material.set_shader_parameter("trial_seed", int(a.seed))
	material.set_shader_parameter("flow_direction", Vector3.LEFT if a.direction == "left" else Vector3.RIGHT)
	material.set_shader_parameter("speed", float(c.speed_m_s))
	material.set_shader_parameter("dot_lifetime", float(c.dot_lifetime_s))
	material.set_shader_parameter("circular", c.aperture == "circle")
	material.set_shader_parameter("aperture_radius", float(c.aperture_radius_m))
	cloud.process_material = material
	cloud.amount = dots
	var radius := float(c.dot_radius_m)
	var sigma := float(c.distance_m) * tan(deg_to_rad(float(c.get("blur_sigma_deg", 0.0))))
	var half_extent := radius + 3.0 * sigma + 0.002
	if cloud.draw_pass_1 is QuadMesh:
		var quad := cloud.draw_pass_1 as QuadMesh
		quad.size = Vector2.ONE * half_extent * 2.0
		var dot_material := quad.material as ShaderMaterial
		dot_material.set_shader_parameter("radius_m", radius)
		dot_material.set_shader_parameter("sigma_m", sigma)
		dot_material.set_shader_parameter("half_extent_m", half_extent)
	elif cloud.draw_pass_1 is SphereMesh:
		(cloud.draw_pass_1 as SphereMesh).radius = radius
		(cloud.draw_pass_1 as SphereMesh).height = radius * 2.0
	cloud.position = Vector3(0.0, 1.3, -float(c.distance_m))
	var half := Vector3(float(c.half_width_m), float(c.half_height_m), 0.0)
	cloud.visibility_aabb = AABB(-half - Vector3.ONE * 0.1, half * 2.0 + Vector3.ONE * 0.2)
	_backdrop.position = Vector3(0.0, 1.3, -(float(c.distance_m) + 1.0))


## Opens the setup for the next set (only between sets; a running set must be ended first).
func open_setup() -> void:
	if trials.phase not in [&"menu", &"block_end", &"resting"]:
		return
	_setup.set_setup(trials.config, trials.timing)
	_setup.show_dataset(dataset_id)
	_setup.visible = true
	_panel.visible = false


func _on_setup_action(what: StringName) -> void:
	var now := Time.get_ticks_usec()
	match what:
		&"preview":
			_setup.visible = false
			_panel.visible = true
			_return_to_setup = true
			trials.start_setup_preview(now)
		&"start":
			_setup.visible = false
			_panel.visible = true
			trials.start_block(now)
		&"close":
			_setup.visible = false
			_panel.visible = true
		&"new_dataset":
			dataset_id = _new_dataset()
			var keep_config: Dictionary = trials.config
			var keep_timing: Dictionary = trials.timing
			trials.leave(now)   # closes this run's record; the next run belongs to the new dataset
			trials = TrialBlock.new()
			trials.save_dir = records_dir
			trials.phase_changed.connect(_on_phase)
			trials.exposure_requested.connect(_on_exposure_requested)
			trials.exposure_ended.connect(_on_exposure_ended)
			trials.message_changed.connect(func(_text: String) -> void: _on_phase(trials.phase))
			trials.begin(keep_config, keep_timing, now, -1, _display_info(), dataset_id)
			_setup.show_dataset(dataset_id)
	_on_phase(trials.phase)


## Optional results after (or between) sets. Never changes the record.
func open_results() -> void:
	if trials.block.is_empty():
		return
	var dataset := Results.dataset_records(trials.save_dir, dataset_id, trials.record)
	_results.show_results(trials.record, trials.block, dataset)
	_panel.visible = false


func _load_dataset() -> String:
	if _forced_dataset != "":
		return _forced_dataset
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dataset="):
			return argument.trim_prefix("--dataset=")
	if FileAccess.file_exists(DATASET_FILE):
		var saved := FileAccess.get_file_as_string(DATASET_FILE).strip_edges()
		if saved != "":
			return saved
	return _new_dataset()


## A fresh non-identifying label: date plus a random tag. Never a name.
func _new_dataset() -> String:
	var label := "review-%s-%04x" % [Time.get_date_string_from_system(), randi() % 65536]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATASET_FILE.get_base_dir()))
	var file := FileAccess.open(DATASET_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(label)
	return label


## Scripted desktop walkthrough for review: teaching, a full block with a wrong answer,
## early and duplicate input, a pause during exposure, then a second block left early.
## Saves screenshots and a copy of the record to [param directory]. Real clock, real frames.
func _walkthrough(directory: String) -> void:
	var target := ProjectSettings.globalize_path(directory)
	DirAccess.make_dir_recursive_absolute(target)
	records_dir = "user://motion_lab_records/scripted_walkthrough"
	_forced_dataset = "SCRIPTED-WALKTHROUGH-%d" % Time.get_unix_time_from_system()
	await enter_block_mode()
	await _settle(0.5)
	await _shot(target, "00_menu")
	trials.start_demo(Time.get_ticks_usec())
	await _until(&"prepare")
	await _settle(0.3)
	await _shot(target, "01_demo_prepare")
	await _until(&"expose")
	await _settle(0.6)
	await _shot(target, "02_demo_expose")
	await _until(&"acknowledged")
	await _shot(target, "03_demo_reveal")
	trials.next(Time.get_ticks_usec())
	trials.start_practice(Time.get_ticks_usec())
	await _until(&"respond")
	await _shot(target, "04_practice_respond")
	trials.answer(1, "walkthrough", Time.get_ticks_usec())
	await _shot(target, "05_practice_ack")
	trials.next(Time.get_ticks_usec())
	trials.start_block(Time.get_ticks_usec())
	for slot in range(1, 7):
		await _until(&"prepare")
		if slot == 1:
			trials.answer(-1, "walkthrough_early", Time.get_ticks_usec())
			await _shot(target, "06_early_input")
		await _until(&"expose")
		await _settle(0.5)
		if slot == 1:
			await _shot(target, "07_block_expose")
		if slot == 2:
			trials.pause(Time.get_ticks_usec())
			await _shot(target, "09_paused_during_exposure")
			trials.answer(1, "walkthrough_while_paused", Time.get_ticks_usec())
			trials.resume(Time.get_ticks_usec())
			await _until(&"expose")
		await _until(&"respond")
		if slot == 1:
			await _shot(target, "08_block_respond")
		var right_answer := -1 if trials.attempt.direction == "left" else 1
		var given := -right_answer if slot == 1 else right_answer   # slot 1 deliberately wrong
		trials.answer(given, "walkthrough", Time.get_ticks_usec())
		if slot == 1:
			trials.answer(given, "walkthrough_duplicate", Time.get_ticks_usec())
			await _shot(target, "08b_ack_after_duplicate")
		trials.next(Time.get_ticks_usec())
	await _until(&"block_end")
	await _shot(target, "10_block_end")
	open_results()
	await _settle(0.3)
	await _shot(target, "14_results_after_set1")
	_results.visible = false
	_panel.visible = true
	# Setup for set 2: lower coherence and some blur (two changes at once: the record keeps both).
	open_setup()
	var s2 := BlockConfig.customized(trials.config, {coherence = 0.4, blur_sigma_deg = 0.25})
	_setup.set_setup(s2, trials.timing)
	trials.set_config(s2, trials.timing)
	await _settle(0.3)
	await _shot(target, "15_setup_panel")
	_on_setup_action(&"preview")
	await _until(&"expose")
	await _settle(0.5)
	await _shot(target, "16_setup_preview_blurred_dots")
	await _until(&"acknowledged")
	trials.next(Time.get_ticks_usec())
	await _settle(0.3)
	_on_setup_action(&"start")
	for slot in range(1, 7):
		await _until(&"respond")
		var truth := -1 if trials.attempt.direction == "left" else 1
		trials.answer(truth if slot % 2 == 0 or slot == 1 else -truth, "walkthrough", Time.get_ticks_usec())
		trials.next(Time.get_ticks_usec())
	await _until(&"block_end")
	open_results()
	await _settle(0.3)
	await _shot(target, "17_results_set2_this_block")
	_results._scope_dataset = true
	_results._refresh()
	await _settle(0.3)
	await _shot(target, "18_results_set2_whole_dataset")
	_results.visible = false
	_panel.visible = true
	# Set 3 on the reference circle, ended mid-way to change setup, then leave.
	var s3 := BlockConfig.reference_circle(0.9)
	trials.set_config(s3, trials.timing)
	trials.start_block(Time.get_ticks_usec())
	await _until(&"prepare")
	await _settle(0.4)
	await _shot(target, "12_circle_prepare_fixation")
	await _until(&"expose")
	await _settle(0.4)
	await _shot(target, "13_circle_expose")
	trials.pause(Time.get_ticks_usec())
	_on_panel(&"change_setup")
	await _settle(0.3)
	await _shot(target, "19_set_ended_for_setup_change")
	_setup.visible = false
	trials.leave(Time.get_ticks_usec())
	await _settle(0.3)
	await _shot(target, "11_left")
	var copy := target.path_join("example_record.json")
	DirAccess.copy_absolute(trials.saved_path, copy)
	print("Motion lab walkthrough: ", target, " | record ", trials.saved_path)
	get_tree().quit()


func _until(phase: StringName, timeout := 10.0) -> void:
	var waited := 0.0
	while trials.phase != phase and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if trials.phase != phase:
		push_error("Walkthrough: never reached %s (at %s)" % [phase, trials.phase])


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(directory: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name + ".png"))
