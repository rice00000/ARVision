extends TestCase
## Profile.adapt: the 2-up / 1-down staircase, its bounds and its file. Levels
## compare as two-decimal strings: steps of 0.1 do not add up exactly.

const SKILL := &"test_skill"


func _run(results: Array, up_after := 2, step := 0.1) -> Array:
	var levels := []
	for success: bool in results:
		levels.append("%.2f" % Profile.adapt(SKILL, success, up_after, step))
	return levels


func test_two_right_in_a_row_step_up_one_miss_steps_down() -> void:
	expect_eq(Profile.level(SKILL), Profile.START_LEVEL, "starts at START_LEVEL")
	expect_eq(_run([true, true, true, false, true, true, false, false]),
		["0.30", "0.40", "0.40", "0.30", "0.30", "0.40", "0.30", "0.20"], "2-up / 1-down")


func test_a_miss_resets_the_streak() -> void:
	expect_eq(_run([true, false, true, true]), ["0.30", "0.20", "0.20", "0.30"], "a success before a miss does not count")


func test_the_level_stays_within_0_and_1() -> void:
	expect_eq(_run([false, false, false, false, false]), ["0.20", "0.10", "0.00", "0.00", "0.00"], "floor at 0")
	var climb := []
	for i in 30:
		climb.append(true)
	expect_eq(_run(climb).back(), "1.00", "ceiling at 1")
	expect_eq(_run([true, true]).back(), "1.00", "stays at 1")


func test_up_after_and_step_come_from_the_def() -> void:
	expect_eq(_run([true, true, true, true, true, true], 3, 0.05), ["0.30", "0.30", "0.35", "0.35", "0.35", "0.40"], "3-up, 0.05")


func test_skills_move_separately() -> void:
	Profile.adapt(&"a", true, 1, 0.1)
	Profile.adapt(&"b", false, 1, 0.1)
	expect(is_equal_approx(Profile.level(&"a"), 0.4), "a went up")
	expect(is_equal_approx(Profile.level(&"b"), 0.2), "b went down")


func test_progress_is_saved_and_wiped() -> void:
	Profile.adapt(SKILL, false, 2, 0.1)
	Profile.adapt(SKILL, true, 2, 0.1)
	Save.write()
	var saved: Dictionary = JSON.to_native(JSON.parse_string(FileAccess.get_file_as_string(Profile.path("save.json"))))
	expect(is_equal_approx(saved.nodes.levels.levels[SKILL], 0.2), "level on disk")
	expect_eq(saved.nodes.levels.streaks[SKILL], 1, "streak on disk, so a relaunch carries on mid-streak")
	Save.reload()
	expect(is_equal_approx(Profile.level(SKILL), 0.2), "read back")
	Profile.wipe()
	expect(not DirAccess.dir_exists_absolute(Profile.path()), "folder gone")
	expect_eq(Profile.level(SKILL), Profile.START_LEVEL, "levels forgotten")
