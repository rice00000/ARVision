class_name StonesBadge
extends Node3D
## The child's magic stones in the workshop (design chat, Nov 18, `claude/DESIGN_STONES_AND_LEVELS.md` §1–2):
## a pill-shaped badge on the Virtual Workshop house bubble, lower right over its rim (the design said upper right;
## there the arc's bubbles above hid it, Nov 18 pictures): cream with a near-black
## edge, a teal gem on the left, the count on the right in big bold digits (it must read under blur).
##
## After a game the stones rise out of the brew one at a time and arc into it ([method fly_in]): ~0.9 s each,
## ~0.3 s apart, a soft clink as each lands, the count going up by one and the badge swelling to ~115 %.

const TEAL := Color(0.16, 0.66, 0.68)     # Wei's magic_stone look
const FLIGHT := 0.9
const APART := 0.3
const GEM_SIZE := 0.03                    # metres, while flying
const LENGTH := 0.12                      # the pill, in the house bubble's own units (~45 % of its width)
const THICK := 0.052

## The count shown (it lags the inventory while stones are still flying).
var count := 0

var _label: Label3D
var _flying: Array[Node3D] = []
var _target := 0


## A badge on [param house]'s bubble showing [param stones].
static func attach(house: Impression, stones: int) -> StonesBadge:
	var badge := StonesBadge.new()
	badge.name = "stones_badge"
	var on: Node3D = house.bubble if house.bubble != null else house
	on.add_child(badge)
	badge.position = Vector3(0.55, -0.8, 0.85) * Impression.BUBBLE_RADIUS
	badge._build()
	badge.set_count(stones)
	return badge


func _build() -> void:
	var pill := MeshInstance3D.new()
	pill.name = "pill"
	var capsule := CapsuleMesh.new()
	capsule.radius = THICK * 0.5
	capsule.height = LENGTH
	pill.mesh = capsule
	pill.material_override = Impression._lit(Impression.TILE, true)
	pill.rotation.z = PI * 0.5   # lying across
	pill.scale = Vector3(1.0, 1.0, 0.35)   # flat, facing the eyes
	add_child(pill)
	var gem := make_gem(THICK * 0.62)
	gem.position = Vector3(-LENGTH * 0.27, 0.0, 0.012)
	add_child(gem)
	_label = Label3D.new()
	_label.name = "count"
	_label.font = load("res://entry/assets/fonts/luckiest_guy.woff2")
	_label.font_size = 120
	_label.pixel_size = 0.00034   # digits ~60 % of the badge's height
	_label.modulate = Impression.INK
	_label.outline_size = 0
	_label.shaded = false
	_label.double_sided = false
	_label.position = Vector3(LENGTH * 0.17, -0.002, 0.012)
	add_child(_label)


## A teal faceted gem with a dark edge, [param size] across.
static func make_gem(size: float) -> MeshInstance3D:
	var gem := MeshInstance3D.new()
	gem.name = "gem"
	var ball := SphereMesh.new()
	ball.radius = size * 0.5
	ball.height = size * 0.8
	ball.radial_segments = 6
	ball.rings = 2   # facets: a cut stone, not a ball
	gem.mesh = ball
	gem.material_override = Impression._lit(TEAL, true)
	gem.material_override.next_pass.set(&"grow_amount", size * 0.07)
	return gem


func set_count(stones: int) -> void:
	count = stones
	_target = maxi(_target, stones)
	if _label != null:
		_label.text = str(stones)


## Stones still on their way in.
func flying() -> bool:
	return not _flying.is_empty()


## [param stones] stones rise out of [param from] (the brew) one at a time and land in the badge; awaits the last.
## [param clink] is called as each lands (the hub plays the sound). Under [param host] while flying.
func fly_in(host: Node, from: Vector3, stones: int, clink: Callable) -> void:
	_target = count + stones
	for i in stones:
		_fly_one(host, from, clink)
		if i < stones - 1:
			await get_tree().create_timer(APART).timeout
	while flying():
		await get_tree().process_frame


func _fly_one(host: Node, from: Vector3, clink: Callable) -> void:
	var gem := make_gem(GEM_SIZE)
	gem.name = "flying_stone"
	host.add_child(gem)
	gem.global_position = from
	_flying.append(gem)
	var tween := gem.create_tween()
	tween.tween_method(func(k: float) -> void:
		if not is_instance_valid(self):
			return
		var to := global_position
		var lift := from.lerp(to, 0.5) + Vector3.UP * 0.12   # a small upward arc: a short path, easy to follow
		gem.global_position = from.lerp(lift, k).lerp(lift.lerp(to, k), k)
		gem.rotation.y = k * TAU * 0.5, 0.0, 1.0, FLIGHT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_flying.erase(gem)
	gem.queue_free()
	if not is_instance_valid(self):
		return
	set_count(count + 1)
	_swell()
	if clink.is_valid():
		clink.call(global_position)


## Every stone in at once (a game was chosen while they were still flying).
func land_all() -> void:
	for gem in _flying:
		if is_instance_valid(gem):
			gem.queue_free()
	_flying.clear()
	set_count(_target)


func _swell() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.15, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_SINE)


## The count said aloud: "One stone", "Seven stones", "Twenty-three stones".
static func spoken(stones: int) -> String:
	var words := number_words(stones)
	return "%s %s" % [words.substr(0, 1).to_upper() + words.substr(1), "stone" if stones == 1 else "stones"]


static func number_words(n: int) -> String:
	const ONES := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
			"twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
	const TENS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
	if n < 0:
		return "minus " + number_words(-n)
	if n < 20:
		return ONES[n]
	if n < 100:
		return TENS[n / 10] + ("" if n % 10 == 0 else "-" + ONES[n % 10])
	if n < 1000:
		return ONES[n / 100] + " hundred" + ("" if n % 100 == 0 else " and " + number_words(n % 100))
	return str(n)
