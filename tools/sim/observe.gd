extends RefCounted
## Engine facts for the sim client: poses, the session, the running trial's
## stimuli, the room, detections and the facilitator panel. Read-only: nothing
## here changes the game. The client decides what a child could perceive.


static func everything(clock: float, seq: int) -> Dictionary:
	var detector := App.module(&"Detector")
	var facilitator := App.module(&"Facilitator")
	return Log.plain({
		t = clock, seq = seq, paused = App.get_tree().paused, profile = Profile.id,
		profile_dir = ProjectSettings.globalize_path(Profile.path()),
		log_path = ProjectSettings.globalize_path(Log.file_path) if not Log.file_path.is_empty() else "",
		modules = App.get_tree().get_nodes_in_group(Module.GROUP).map(func(node: Node) -> String: return node.name),
		reality = App.reality.kind(),
		rig = frame(App.rig.global_transform),
		head = head(),
		hands = {left = hand(&"left"), right = hand(&"right")},
		view = App.reality.view.to_log(),
		focus = App.reality.get("_focus"), # where a spotlight view is centred
		work_surface = surface(App.reality.work_surface()),
		session = session(),
		levels = levels(),
		stimuli = stimuli(),
		real_objects = real_objects(),
		detections = detector.detections.map(func(found: Detection) -> Dictionary: return found.to_log()) if detector else [],
		facilitator = panel(facilitator) if facilitator else null,
		world = world(),
		subtitle = subtitle(),
	})


static func frame(pose: Transform3D) -> Dictionary:
	return {position = pose.origin, x = pose.basis.x, y = pose.basis.y, z = pose.basis.z, forward = -pose.basis.z}


static func head() -> Dictionary:
	var camera := App.head()
	var result := frame(camera.global_transform)
	result.fov = camera.fov
	return result


static func hand(side: StringName) -> Dictionary:
	var controller := App.rig.hand(side)
	var pointer := App.rig.pointer(side)
	var result := frame(controller.global_transform)
	var aimed := pointer.cast() # what a trigger pull would select now (Pointer.aimed lags a frame)
	result.merge({tracked = controller.get_has_tracking_data(), tip = pointer.tip(), aimed = aimed.id if aimed else ""})
	return result


static func surface(found: Surface) -> Dictionary:
	var result := frame(found.transform)
	result.merge({kind = found.kind, size = found.size})
	return result


static func session() -> Dictionary:
	var running := App.session
	var result := {running = running.running, block_index = running.block_index,
		blocks = running.plan.blocks.size() if running.plan else 0,
		pinned = null if is_nan(running.pinned) else running.pinned, block = null, level = null, trial = null}
	if running.block:
		var block := running.block
		result.block = {trial = block.trial.id, title = block.trial.title, skill = block.trial.skill, rounds = block.rounds,
			probe = block.probe, difficulty = block.difficulty, pins = block.pins,
			view = block.view.title if block.view else "Normal", pause_between = block.pause_between}
		result.level = running.level()
	var trial := running.trial
	if trial and trial.condition:
		result.trial = {id = trial.condition.trial, running = trial.is_running(), round = trial.condition.round_index,
			tries = trial.tries, hint = trial.hint_level, seconds = trial.seconds(), condition = trial.condition.to_log(),
			hint_after = trial.def.hint_after, hint_fade = trial.def.hint_fade, max_hint = trial.def.max_hint,
			time_limit = trial.def.time_limit}
	return result


## Staircase level of every skill the plan (or the adventure's tasks) trains.
static func levels() -> Dictionary:
	var plans: Array[SessionPlan] = []
	if App.session.plan:
		plans.append(App.session.plan)
	else:
		for place in App.world.adventure.places:
			plans.append_array(place.tasks.map(func(task: Task) -> SessionPlan: return task.plan))
	var result := {}
	for plan in plans:
		for block in plan.blocks:
			result[block.trial.skill] = Profile.level(block.trial.skill)
	return result


## The adventure: progress, the guide and the open task menu with its buttons.
static func world() -> Dictionary:
	var world := App.world
	var guide: Node3D = world.get("_guide")
	var result := {done = world.done, colour = world.colour,
		place = world.place.title if world.place else "", guide = {visible = guide.visible, position = guide.global_position},
		menu = null}
	if world.menu and world.menu.is_inside_tree():
		var buttons := []
		for button: Target in world.menu.find_children("task_*", "Target", false, false):
			var entry: Array = world.menu.get("_buttons")[button]
			buttons.append({id = button.id, position = button.global_position, normal = button.global_basis.z,
				open = world.can_play(entry[0], entry[1]), done = world.is_done(entry[0], entry[1])})
		result.menu = {open = world.menu.get("_open"), buttons = buttons}
	return result


## What the running trial shows: its Targets, any plain markers, a dot cloud.
static func stimuli() -> Dictionary:
	var trial := App.session.trial
	if trial == null:
		return {targets = [], markers = [], cloud = null, named = ""}
	var targets := []
	var markers := []
	for node: Node3D in trial.find_children("*", "Node3D", true, false):
		if node is Target:
			targets.append(target(node))
		elif node is MeshInstance3D and not node.get_parent() is Target:
			markers.append({position = node.global_position, visible = node.is_visible_in_tree()})
	var named := ""
	if trial.condition:
		named = String(trial.condition.value(&"target", trial.condition.value(&"object", "")))
	var cloud: GPUParticles3D = trial.get_node_or_null(^"Cloud")
	return {targets = targets, markers = markers, named = named, cloud = dots(cloud) if cloud else null}


static func target(node: Target) -> Dictionary:
	var box := AABB()
	var glow := false
	var colour := Color.TRANSPARENT
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
		var material := mesh.material_override as StandardMaterial3D
		glow = glow or (material != null and material.emission_enabled)
		if material:
			colour = material.albedo_color
	var radius := 0.0
	for shape: CollisionShape3D in node.find_children("*", "CollisionShape3D", false, false):
		if shape.shape is SphereShape3D:
			radius = (shape.shape as SphereShape3D).radius
		elif shape.shape is BoxShape3D:
			radius = (shape.shape as BoxShape3D).size.length() * 0.5
	return {id = node.id, position = node.global_position, centre = box.get_center(), extent = box.size,
		radius = radius, glow = glow, colour = colour, visible = node.is_visible_in_tree()}


static func dots(cloud: GPUParticles3D) -> Dictionary:
	var material := cloud.process_material as ShaderMaterial
	var flow: Vector3 = material.get_shader_parameter(&"flow_direction")
	var result := frame(cloud.global_transform)
	result.merge({amount = cloud.amount, flow = flow, flow_world = cloud.global_basis * flow,
		dot_count = material.get_shader_parameter(&"dot_count"), signal_count = material.get_shader_parameter(&"signal_count"),
		half_size = material.get_shader_parameter(&"half_size"), competing = material.get_shader_parameter(&"competing_flow"),
		alignment = material.get_shader_parameter(&"alignment"), speed = material.get_shader_parameter(&"speed")})
	return result


## The simulated room's recognisable things, with whether the eyes have a clear line to them.
static func real_objects() -> Array:
	var eye := App.head().global_position
	var space := App.head().get_world_3d().direct_space_state
	var found := []
	for object in (App.reality as SimReality).objects():
		var centre := object.centre()
		var box := object.box()
		var query := PhysicsRayQueryParameters3D.create(eye, centre, Reality.REALITY_LAYER, object.bodies())
		var hit := space.intersect_ray(query)
		found.append({label = object.label, centre = centre, extent = box.size, clear = hit.is_empty(),
			blocker = _name(hit.collider) if hit else ""})
	return found


static func panel(facilitator: Node) -> Dictionary:
	var result := {open = facilitator.is_open, status = "", playing = "", name = "", buttons = []}
	if facilitator.is_open:
		var node := facilitator.get_node(^"FacilitatorPanel")
		result.status = (facilitator.get("_status") as Label3D).text
		result.playing = (facilitator.get("_playing") as Label3D).text
		result.name = (facilitator.get("_name") as Label3D).text
		var disabled: Dictionary = facilitator.get("_disabled")
		for button: Target in node.find_children("*", "Target", true, false):
			result.buttons.append({id = button.id, position = button.global_position, normal = button.global_basis.z,
				text = (button.find_children("*", "Label3D", false, false)[0] as Label3D).text,
				disabled = disabled.get(button, false)})
	return result


static func subtitle() -> Variant:
	var voice := App.module(&"Voice")
	if voice == null:
		return null
	var label: Label3D = voice.get("_label")
	return {text = label.text, visible = label.visible, position = label.global_position}


## Sweeps a sphere of [param radius] along [param points] against the real room.
static func sweep(points: Array, radius: float) -> Dictionary:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = Reality.REALITY_LAYER
	var space := App.head().get_world_3d().direct_space_state
	for i in points.size():
		var at := Vector3(points[i][0], points[i][1], points[i][2])
		query.transform.origin = at
		query.motion = Vector3.ZERO
		var hits := space.intersect_shape(query, 1)
		if not hits.is_empty():
			return {clear = false, segment = i, at = at, blocker = _name(hits[0].collider)}
		if i + 1 < points.size():
			query.motion = Vector3(points[i + 1][0], points[i + 1][1], points[i + 1][2]) - at
			var fraction := space.cast_motion(query)
			if fraction[0] < 1.0:
				query.transform.origin = at + query.motion * fraction[1]
				query.motion = Vector3.ZERO
				var blockers := space.intersect_shape(query, 1)
				return {clear = false, segment = i, at = query.transform.origin,
					blocker = _name(blockers[0].collider) if blockers else ""}
	return {clear = true}


## A real object's collider is its child "Body"; name the object.
static func _name(collider: Object) -> String:
	var node := collider as Node
	return String(node.get_parent().name if node.name == &"Body" else node.name)
