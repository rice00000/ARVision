class_name ResultsView
extends Node3D
## The Staff tools Results tab's graph (Graphs chat, Nov 17): one [ResultsGraph] at a time, drawn in a
## SubViewport onto a quad on the staff panel. The facilitator panel owns the buttons and calls
## [method press]; this keeps what is shown. Reads the log of the save playing now (one file per visit).
##   Rounds / Time / Coherence   which graph
##   This visit / All visits     the scope (graph 3 starts on all visits: one visit has too few rounds)
##   Showing: Play ...           the group: Play, Pinned level, Dev, Older logs. Never pooled.
##   Next task                   graph 3 only, when more than one task has rounds
## The viewport draws once per change, not every frame (cheap on the Quest).

## Size on the panel (m), the graph's own aspect.
const WIDTH := 0.40
const HEIGHT := WIDTH * ResultsGraph.SIZE.y / ResultsGraph.SIZE.x
const GRAPHS := {fac_res_rounds = &"outcomes", fac_res_time = &"timing", fac_res_coherence = &"coherence"}

var graph_kind: StringName = &"outcomes"
var all_visits := {outcomes = false, timing = false, coherence = true}
var group := "play"
var task_index := 0

var _rounds_all: Array = []
var _rounds_visit: Array = []
var _viewport := SubViewport.new()
var _graph := ResultsGraph.new()
var _quad := MeshInstance3D.new()


func _init() -> void:
	name = "ResultsView"
	_viewport.size = Vector2i(ResultsGraph.SIZE)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.add_child(_graph)
	add_child(_viewport)
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	_quad.mesh = quad
	_quad.name = "Graph"
	add_child(_quad)


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # sorted with the panel's other parts
	material.no_depth_test = true
	material.render_priority = 22   # over the panel (20) and button faces (21), under text (23)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_texture = _viewport.get_texture()
	_quad.material_override = material
	_redraw()


## Reads the logs again: every visit of this save, and which one is now.
func reload(folder := "", current := "") -> void:
	if folder.is_empty():
		folder = Profile.path("logs/")
	if current.is_empty():
		current = Log.file_path
	_rounds_all = MotionResults.load_rounds(MotionResults.visit_paths(folder))
	var visit := current.get_file().get_basename()
	_rounds_visit = _rounds_all.filter(func(r: Dictionary) -> bool: return r.visit == visit) if visit != "" else []
	_redraw()


## Uses these rounds instead of the logs (tests and pictures).
func use_rounds(every: Array, this_visit: Array) -> void:
	_rounds_all = every
	_rounds_visit = this_visit
	_redraw()


## A Results button was pressed. False if [param id] isn't one of ours.
func press(id: StringName) -> bool:
	if GRAPHS.has(id):
		if GRAPHS[id] == &"coherence" and not has_coherence():
			return false
		graph_kind = GRAPHS[id]
	elif id == &"fac_res_scope":
		all_visits[graph_kind] = not all_visits[graph_kind]
	elif id == &"fac_res_group":
		var groups := MotionResults.groups_in(_rounds_all)
		group = groups[(groups.find(group) + 1) % groups.size()]
		task_index = 0
	elif id == &"fac_res_task":
		task_index += 1
	else:
		return false
	_redraw()
	return true


func scope_caption() -> String:
	return "All visits" if all_visits[graph_kind] else "This visit"


func group_caption() -> String:
	return "Showing: %s" % MotionResults.group_title(group)


## Hub review, Nov 17: graph 3 is hidden until this group has 2+ coherence levels across all visits
## (Steady Flow is always 90 %: one point can't show a trend).
func has_coherence() -> bool:
	return MotionResults.coherence_levels(MotionResults.in_group(_rounds_all, group)) >= 2


## More than one task to page through on graph 3.
func has_more_tasks() -> bool:
	return graph_kind == &"coherence" and _graph.tasks().size() > 1


## The rounds the graph shows now: one scope, one group.
func shown_rounds() -> Array:
	return MotionResults.in_group(_rounds_all if all_visits[graph_kind] else _rounds_visit, group)


func graph() -> ResultsGraph:
	return _graph


func _redraw() -> void:
	if graph_kind == &"coherence" and not has_coherence():
		graph_kind = &"outcomes"
	var context := "%s · %s" % [MotionResults.group_title(group), "all visits" if all_visits[graph_kind] else "this visit"]
	_graph.show_rounds(graph_kind, shown_rounds(), context, task_index)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
