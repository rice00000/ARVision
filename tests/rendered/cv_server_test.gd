extends TestCase
## The Detector's remote backend on rendered frames, against tools/cv_server.py --fake
## (one centred "cup" in every frame). Needs a renderer and the server's address:
##
##   python tools/sim/walkthrough.py   (starts the fake server and runs this)

const POINT := preload("res://trials/point_real/point_real.tres")
const CUP := Vector3(-0.35, 0.77, -0.8)


func test_the_fake_servers_cup_lands_where_the_camera_looks() -> void:
	var server := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cv-server="):
			server = arg.trim_prefix("--cv-server=")
	expect(not server.is_empty(), "started with --cv-server=<url>")
	await boot(plan_of(POINT, 1))
	var detector := App.module(&"Detector")
	detector.server = server
	detector.backend = 2 # REMOTE
	var detected := record(Events.detected)
	var errors := record(Events.reported)
	input.look_at(CUP)
	expect(await until(func() -> bool: return not detected.is_empty(), 10.0), "the server answered")
	expect(errors.filter(func(args: Array) -> bool: return args[0] == &"cv_error").is_empty(), "without errors")
	var cup: Detection = detector.find("cup")
	expect(cup != null and is_equal_approx(cup.confidence, 0.9), "the fake cup, at its confidence")
	var eye := App.head().global_transform
	expect((cup.position - eye.origin).normalized().dot(-eye.basis.z) > 0.999, "on the frame's centre ray")
	expect(cup.position.distance_to(CUP) < 0.06, "which meets the real cup: %s" % cup.position)
	App.session.run()
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.get("_label") == "cup", 10.0),
		"the guide names it")
	var ended := record(Events.trial_ended)
	await select(cup.position)
	expect(ended.size() == 1 and ended[0][1], "pointing at it succeeds")
