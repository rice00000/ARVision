extends TestCase
## Pointing at a button says its name (UITarget.speech), for children who
## cannot read yet: after a short aim, once, never over the guide, and every
## name is baked.

const GUIDE_LINE := "Thank you for trying that with me."


func _baked(text: String) -> void:
	var paths := BakedSpeech.paths_for(text)
	expect(not paths.is_empty(), "baked: %s" % text)
	for path in paths:
		expect(ResourceLoader.exists(path), "imported: %s" % path)


func _button(speech: String) -> UITarget:
	var button := UITarget.new()
	button.speech = speech
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	button.add_child(shape)
	app.add_child(button)
	return button


func _said(lines: Array) -> Array:
	return lines.map(func(args: Array) -> String: return args[0])


func test_a_button_says_its_name_after_a_short_aim_once() -> void:
	await boot()
	var said := record(Events.said)
	var button := _button("Harder")
	button.focus(&"right", true)
	await wait(UITarget.SPEAK_AFTER * 0.5)
	expect(said.is_empty(), "not while just passing over it")
	await wait(UITarget.SPEAK_AFTER)
	expect_eq(_said(said), ["Harder"], "its name")
	await wait(1.0)
	expect_eq(said.size(), 1, "once per aim")
	button.focus(&"right", false)
	button.focus(&"right", true)
	await wait(UITarget.SPEAK_AFTER + 0.1)
	expect_eq(said.size(), 2, "again after aiming away and back")


func test_a_name_never_cuts_off_the_guide() -> void:
	await boot()
	var said := record(Events.said)
	Events.say(GUIDE_LINE)
	var button := _button("Easier")
	button.focus(&"right", true)
	await wait(UITarget.SPEAK_AFTER + 0.1)
	expect_eq(_said(said), [GUIDE_LINE], "the guide goes on")
	var other := _button("Confirm")
	await until(func() -> bool: return App.module(&"Voice").speaking().is_empty(), 10.0)
	other.focus(&"right", true)
	await wait(UITarget.SPEAK_AFTER + 0.1)
	expect_eq(_said(said).back(), "Confirm", "once the guide is done, names are said")


func test_a_silent_or_disabled_button_says_nothing() -> void:
	await boot()
	var said := record(Events.said)
	_button("").focus(&"right", true)
	var off := _button("Harder")
	off.collision_layer = 0
	off.focus(&"right", true)
	await wait(UITarget.SPEAK_AFTER + 0.2)
	expect(said.is_empty(), "nothing said")


func test_every_staff_panel_name_is_baked() -> void:
	await boot()
	var facilitator := App.module(&"Facilitator")
	facilitator.toggle()
	await frames(2)
	var names := {}
	for page: Node3D in facilitator.get("_pages").values():
		for target in page.find_children("*", "UITarget", true, false):
			names[(target as UITarget).speech] = true
	for target in facilitator.find_children("*", "UITarget", true, false):
		names[(target as UITarget).speech] = true
	names.erase("")
	expect(names.size() > 40, "every page's buttons: %d names" % names.size())
	expect(names.has("More contrast") and names.has("Previous page"), "signs and numbers get words")
	for text: String in names:
		_baked(text)


func test_every_level_card_name_is_baked() -> void:
	for file in DirAccess.get_files_at("res://content/tasks"):
		var task: Task = load("res://content/tasks/" + file.trim_suffix(".remap"))
		for level in task.levels:
			_baked(level.title)
	_baked("Scroll up")
	_baked("Scroll down")


func test_entry_and_play_buttons_are_baked() -> void:
	for text in ["Replay tutorial", "Play again", "Magic dots", "End session", "More shapes"]:
		_baked(text)
