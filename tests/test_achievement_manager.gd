extends SceneTree

## Headless test script for AchievementManager (Phase 4: Achievements & Google Play Games).
## Run via: godot --headless --path . -s tests/test_achievement_manager.gd

const AchievementManagerScript = preload("res://scripts/achievement_manager.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const TEST_SAVE_PATH: String = "user://test_achievements_save.json"

var _passed_suites: int = 0
var _failed_suites: int = 0
var _total_assertions: int = 0
var _failed_assertions: int = 0


func _init() -> void:
	print("==================================================")
	print("   Pixel Porter - AchievementManager Headless Tests")
	print("==================================================")

	_cleanup_test_file()

	run_suite("Achievement Catalog & Metadata", test_achievement_catalog)
	run_suite("Unlocking Mechanics & Idempotency", test_unlock_mechanics)
	run_suite("Progression Evaluation Milestones", test_progression_evaluation)
	run_suite("Persistence Across Save/Load & Reset", test_persistence_and_reset)

	_cleanup_test_file()

	print("\n==================================================")
	print("Test Suites: %d passed, %d failed" % [_passed_suites, _failed_suites])
	print("Assertions : %d total, %d failed" % [_total_assertions, _failed_assertions])
	print("==================================================")

	if _failed_assertions > 0 or _failed_suites > 0:
		printerr("FAILED: AchievementManager test suite had failures.")
		quit(1)
	else:
		print("SUCCESS: All AchievementManager tests passed successfully!")
		quit(0)


func _cleanup_test_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func run_suite(suite_name: String, test_callable: Callable) -> void:
	print("\n--- Running Suite: %s ---" % suite_name)
	var prev_failures: int = _failed_assertions
	test_callable.call()
	if _failed_assertions == prev_failures:
		_passed_suites += 1
	else:
		_failed_suites += 1


func assert_true(condition: bool, message: String) -> void:
	_total_assertions += 1
	if condition:
		print("  [PASS] %s" % message)
	else:
		_failed_assertions += 1
		printerr("  [FAIL] Assertion failed: %s" % message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_total_assertions += 1
	if actual == expected:
		print("  [PASS] %s (got %s)" % [message, str(actual)])
	else:
		_failed_assertions += 1
		printerr("  [FAIL] %s - Expected: %s, Got: %s" % [message, str(expected), str(actual)])


func test_achievement_catalog() -> void:
	var ach_mgr = AchievementManagerScript.new()
	var all_achs = ach_mgr.get_all_achievements()

	assert_equal(all_achs.size(), 10, "All 10 achievements registered in catalog")

	var first_shift = ach_mgr.get_achievement_info("first_shift")
	assert_false(first_shift.is_empty(), "First Shift achievement exists")
	assert_equal(first_shift["name"], "First Shift", "First Shift title matches")
	assert_equal(first_shift["icon"], "📦", "First Shift icon is 📦")

	var unstoppable = ach_mgr.get_achievement_info("depot_cleared")
	assert_false(unstoppable.is_empty(), "Unstoppable Porter achievement exists")
	assert_equal(unstoppable["name"], "Unstoppable Porter", "Unstoppable Porter title matches")
	assert_equal(unstoppable["icon"], "🏆", "Unstoppable Porter icon is 🏆")

	ach_mgr.free()


func test_unlock_mechanics() -> void:
	var save_mgr = SaveManagerScript.new()
	var ach_mgr = AchievementManagerScript.new()

	assert_equal(ach_mgr.get_unlocked_count(save_mgr), 0, "Initial unlocked count is 0")
	assert_false(ach_mgr.is_unlocked("first_shift", save_mgr), "First shift is locked initially")

	var signal_received: Dictionary = { "fired": false, "id": "" }
	ach_mgr.achievement_unlocked.connect(func(id: String, _info: Dictionary):
		signal_received["fired"] = true
		signal_received["id"] = id
	)

	# 1. First unlock succeeds
	var unlocked: bool = ach_mgr.unlock("first_shift", save_mgr)
	assert_true(unlocked, "unlock returns true on new achievement")
	assert_true(ach_mgr.is_unlocked("first_shift", save_mgr), "First shift is now unlocked")
	assert_equal(ach_mgr.get_unlocked_count(save_mgr), 1, "Unlocked count incremented to 1")
	assert_true(signal_received["fired"], "achievement_unlocked signal fired")
	assert_equal(signal_received["id"], "first_shift", "Signal received correct achievement ID")

	# 2. Idempotent unlock returns false and does not re-increment
	signal_received["fired"] = false
	var re_unlocked: bool = ach_mgr.unlock("first_shift", save_mgr)
	assert_false(re_unlocked, "unlock returns false when already unlocked")
	assert_equal(ach_mgr.get_unlocked_count(save_mgr), 1, "Unlocked count remains 1")
	assert_false(signal_received["fired"], "Signal does not re-fire on duplicate unlock")

	ach_mgr.free()
	save_mgr.free()


func test_progression_evaluation() -> void:
	var save_mgr = SaveManagerScript.new()
	var ach_mgr = AchievementManagerScript.new()

	# 1. Complete level 0 -> triggers first_shift
	save_mgr.record_level_completion(0, 5, 3, TEST_SAVE_PATH)
	var new_unlocked = ach_mgr.evaluate_progress(save_mgr)
	assert_true("first_shift" in new_unlocked, "evaluate_progress unlocks first_shift upon beating Level 1")

	# 2. Complete all of Chapter 0 (Levels 0 to 14)
	for lvl in range(1, 15):
		save_mgr.record_level_completion(lvl, 8, 3, TEST_SAVE_PATH)
	new_unlocked = ach_mgr.evaluate_progress(save_mgr)
	assert_true("cargo_master" in new_unlocked, "evaluate_progress unlocks cargo_master upon completing Chapter 1")

	# 3. Equip a cosmetic
	save_mgr.selected_worker_skin = "safety_vest"
	new_unlocked = ach_mgr.evaluate_progress(save_mgr)
	assert_true("stylin_porter" in new_unlocked, "evaluate_progress unlocks stylin_porter when cosmetic equipped")

	# 4. Push 100 crates
	save_mgr.total_crates_pushed = 100
	new_unlocked = ach_mgr.evaluate_progress(save_mgr)
	assert_true("heavy_lifter" in new_unlocked, "evaluate_progress unlocks heavy_lifter at 100 crates pushed")

	ach_mgr.free()
	save_mgr.free()


func test_persistence_and_reset() -> void:
	var save_mgr = SaveManagerScript.new()
	var ach_mgr = AchievementManagerScript.new()

	ach_mgr.unlock("first_shift", save_mgr)
	ach_mgr.unlock("stylin_porter", save_mgr)
	save_mgr.save_data(TEST_SAVE_PATH)

	# Load in fresh SaveManager
	var save_mgr2 = SaveManagerScript.new()
	save_mgr2.load_data(TEST_SAVE_PATH)
	assert_equal(ach_mgr.get_unlocked_count(save_mgr2), 2, "Persisted 2 unlocked achievements across save/load")
	assert_true(ach_mgr.is_unlocked("first_shift", save_mgr2), "first_shift persisted")
	assert_true(ach_mgr.is_unlocked("stylin_porter", save_mgr2), "stylin_porter persisted")

	# Reset
	save_mgr2.reset_all_progress(TEST_SAVE_PATH)
	assert_equal(ach_mgr.get_unlocked_count(save_mgr2), 0, "Achievements cleared on reset_all_progress")
	assert_false(ach_mgr.is_unlocked("first_shift", save_mgr2), "first_shift is locked after reset")

	ach_mgr.free()
	save_mgr.free()
	save_mgr2.free()
