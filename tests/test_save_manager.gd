extends SceneTree

## Headless test script for SaveManager (Pixel Porter PRD v1.md Sections 2, 6, & 11).
## Run via: godot --headless --path . -s tests/test_save_manager.gd

const SaveManagerScript = preload("res://scripts/save_manager.gd")
const TEST_SAVE_PATH: String = "user://test_save_manager_data.json"

var _passed_suites: int = 0
var _failed_suites: int = 0
var _total_assertions: int = 0
var _failed_assertions: int = 0


func _init() -> void:
	print("==================================================")
	print("   Pixel Porter - SaveManager Headless Tests     ")
	print("==================================================")

	_cleanup_test_file()

	run_suite("Default State & Unlock Rules", test_defaults_and_unlocks)
	run_suite("Score Recording & Best Move Tracking", test_score_recording)
	run_suite("3-Star Rating Calculations & Tracking", test_star_rating_system)
	run_suite("Warehouse Chapters Progression (Phase 2)", test_warehouse_chapters_progression)
	run_suite("Porter Locker Cosmetics & Star Economy (Phase 3)", test_porter_locker_cosmetics)
	run_suite("Persistence (Save & Load to Disk)", test_persistence)
	run_suite("Corrupt & Missing File Resilience", test_corrupt_and_missing_file)

	_cleanup_test_file()

	print("\n==================================================")
	print("Test Suites: %d passed, %d failed" % [_passed_suites, _failed_suites])
	print("Assertions : %d total, %d failed" % [_total_assertions, _failed_assertions])
	print("==================================================")

	if _failed_assertions > 0 or _failed_suites > 0:
		printerr("FAILED: Test suite had failures.")
		quit(1)
	else:
		print("SUCCESS: All SaveManager tests passed successfully!")
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


func test_defaults_and_unlocks() -> void:
	var mgr = SaveManagerScript.new()
	assert_equal(mgr.unlocked_level, 0, "Initial unlocked level is 0 (first level)")
	assert_true(mgr.is_level_unlocked(0), "Level 0 is unlocked by default")
	assert_false(mgr.is_level_unlocked(1), "Level 1 is locked by default")
	assert_false(mgr.is_level_unlocked(5), "Level 5 is locked by default")
	assert_true(mgr.sound_enabled, "Sound is enabled by default")
	assert_true(mgr.music_enabled, "Music is enabled by default")
	assert_true(mgr.haptics_enabled, "Haptics is enabled by default")
	assert_equal(mgr.language, "en", "Default language is 'en'")

	# Signal tracking
	var unlocked_signals: Array[int] = []
	mgr.level_unlocked.connect(func(lvl: int): unlocked_signals.append(lvl))

	# Unlocking
	var ok: bool = mgr.unlock_level(1)
	assert_true(ok, "Unlocking level 1 returns true")
	assert_equal(mgr.unlocked_level, 1, "Unlocked level updated to 1")
	assert_true(mgr.is_level_unlocked(1), "Level 1 is now unlocked")
	assert_equal(unlocked_signals.size(), 1, "level_unlocked signal fired once")
	assert_equal(unlocked_signals[0], 1, "level_unlocked emitted with index 1")

	# Downgrade attempt
	var downgraded: bool = mgr.unlock_level(0)
	assert_false(downgraded, "Attempting to unlock an already lower level returns false")
	assert_equal(mgr.unlocked_level, 1, "Unlocked level remains 1")
	mgr.free()


func test_score_recording() -> void:
	var mgr = SaveManagerScript.new()
	assert_false(mgr.is_level_completed(0), "Level 0 not completed initially")

	# Record first completion: 15 moves, 8 pushes
	mgr.record_level_completion(0, 15, 8, TEST_SAVE_PATH)
	assert_true(mgr.is_level_completed(0), "Level 0 is now marked completed")
	assert_true(mgr.is_level_unlocked(1), "Level 1 unlocked after beating level 0")

	var rec: Dictionary = mgr.get_level_record(0)
	assert_equal(rec.get("best_moves"), 15, "Best moves is 15")
	assert_equal(rec.get("best_pushes"), 8, "Best pushes is 8")

	# Better run: 10 moves, 6 pushes
	mgr.record_level_completion(0, 10, 6, TEST_SAVE_PATH)
	rec = mgr.get_level_record(0)
	assert_equal(rec.get("best_moves"), 10, "Best moves improved to 10")
	assert_equal(rec.get("best_pushes"), 6, "Best pushes improved to 6")
	assert_equal(rec.get("last_moves"), 10, "Last moves is 10")

	# Worse run: 18 moves, 9 pushes
	mgr.record_level_completion(0, 18, 9, TEST_SAVE_PATH)
	rec = mgr.get_level_record(0)
	assert_equal(rec.get("best_moves"), 10, "Best moves preserved at 10")
	assert_equal(rec.get("best_pushes"), 6, "Best pushes preserved at 6")
	assert_equal(rec.get("last_moves"), 18, "Last moves updated to 18")
	mgr.free()


func test_star_rating_system() -> void:
	var mgr = SaveManagerScript.new()

	assert_equal(mgr.get_optimal_moves(0), 9, "Level 0 optimal moves is 9")
	assert_equal(mgr.calculate_stars(0, 20), 1, "20 moves earns 1 star on Level 0")
	assert_equal(mgr.calculate_stars(0, 14), 2, "14 moves earns 2 stars on Level 0")
	assert_equal(mgr.calculate_stars(0, 10), 3, "10 moves earns 3 stars on Level 0")

	mgr.record_level_completion(0, 20, 8, TEST_SAVE_PATH)
	assert_equal(mgr.get_level_stars(0), 1, "Level 0 stars is 1")
	assert_equal(mgr.get_total_stars(), 1, "Total stars is 1")

	mgr.record_level_completion(0, 9, 4, TEST_SAVE_PATH)
	assert_equal(mgr.get_level_stars(0), 3, "Level 0 stars improved to 3")
	assert_equal(mgr.get_total_stars(), 3, "Total stars is 3")
	mgr.free()


func test_persistence() -> void:
	var mgr1 = SaveManagerScript.new()
	mgr1.sound_enabled = false
	mgr1.haptics_enabled = false
	mgr1.language = "fr"
	mgr1.music_volume = 0.42
	mgr1.sfx_volume = 0.65
	mgr1.selected_bgm_track = 1
	mgr1.control_scheme = 2
	mgr1.record_level_completion(0, 8, 4, TEST_SAVE_PATH)
	mgr1.record_level_completion(1, 14, 7, TEST_SAVE_PATH)
	mgr1.last_played_level = 1
	var saved: bool = mgr1.save_data(TEST_SAVE_PATH)
	assert_true(saved, "Data saved successfully to disk")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "Save file exists on filesystem")

	# Load with brand new instance
	var mgr2 = SaveManagerScript.new()
	var loaded: bool = mgr2.load_data(TEST_SAVE_PATH)
	assert_true(loaded, "Data loaded successfully from disk")
	assert_equal(mgr2.unlocked_level, 2, "Loaded unlocked level is 2")
	assert_equal(mgr2.last_played_level, 1, "Loaded last played level is 1")
	assert_false(mgr2.sound_enabled, "Sound setting (false) persisted correctly")
	assert_false(mgr2.haptics_enabled, "Haptics setting (false) persisted correctly")
	assert_equal(mgr2.language, "fr", "Language ('fr') persisted correctly")
	assert_equal(mgr2.music_volume, 0.42, "Music volume (0.42) persisted correctly")
	assert_equal(mgr2.sfx_volume, 0.65, "SFX volume (0.65) persisted correctly")
	assert_equal(mgr2.selected_bgm_track, 1, "Selected BGM track (1) persisted correctly")
	assert_equal(mgr2.control_scheme, 2, "Control scheme (2 = Dual) persisted correctly")
	assert_equal(mgr2.get_control_scheme_name(), "DUAL", "Control scheme name is DUAL")
	mgr2.cycle_control_scheme()
	assert_equal(mgr2.control_scheme, 0, "Cycled control scheme to 0 = SWIPE")
	assert_true(mgr2.is_level_completed(0), "Level 0 completion persisted")
	assert_true(mgr2.is_level_completed(1), "Level 1 completion persisted")

	var rec0: Dictionary = mgr2.get_level_record(0)
	assert_equal(rec0.get("best_moves"), 8, "Persisted best moves for Level 0 is 8")
	assert_equal(rec0.get("best_pushes"), 4, "Persisted best pushes for Level 0 is 4")

	var rec1: Dictionary = mgr2.get_level_record(1)
	assert_equal(rec1.get("best_moves"), 14, "Persisted best moves for Level 1 is 14")
	assert_equal(rec1.get("best_pushes"), 7, "Persisted best pushes for Level 1 is 7")

	# Test reset_all_progress
	mgr2.reset_all_progress(TEST_SAVE_PATH)
	assert_equal(mgr2.unlocked_level, 0, "Unlocked level reset to 0")
	assert_true(mgr2.sound_enabled, "Sound reset to true")
	assert_true(mgr2.haptics_enabled, "Haptics reset to true")
	assert_equal(mgr2.language, "en", "Language reset to 'en'")
	assert_equal(mgr2.music_volume, 0.7, "Music volume reset to 0.7")
	assert_equal(mgr2.sfx_volume, 0.8, "SFX volume reset to 0.8")
	assert_equal(mgr2.selected_bgm_track, 0, "Selected BGM track reset to 0")
	assert_equal(mgr2.control_scheme, 0, "Control scheme reset to 0")
	assert_false(mgr2.is_level_completed(0), "Completed levels cleared on reset")

	mgr1.free()
	mgr2.free()


func test_corrupt_and_missing_file() -> void:
	var mgr = SaveManagerScript.new()
	var missing_ok: bool = mgr.load_data("user://non_existent_file_abc123.json")
	assert_false(missing_ok, "Loading missing file returns false without error")

	# Write corrupt text to file
	var bad_path: String = "user://corrupt_test_data.json"
	var f = FileAccess.open(bad_path, FileAccess.WRITE)
	f.store_string("{ this is not valid json : [ }")
	f.close()

	var corrupt_ok: bool = mgr.load_data(bad_path)
	assert_false(corrupt_ok, "Loading corrupt JSON returns false gracefully")
	DirAccess.remove_absolute(bad_path)
	mgr.free()


func test_warehouse_chapters_progression() -> void:
	var mgr = SaveManagerScript.new()

	# 1. Level to Chapter index mappings
	assert_equal(mgr.get_chapter_index(0), 0, "Level 0 maps to Chapter 0 (Cargo Bay)")
	assert_equal(mgr.get_chapter_index(14), 0, "Level 14 maps to Chapter 0 (Cargo Bay)")
	assert_equal(mgr.get_chapter_index(15), 1, "Level 15 maps to Chapter 1 (Cold Storage)")
	assert_equal(mgr.get_chapter_index(34), 1, "Level 34 maps to Chapter 1 (Cold Storage)")
	assert_equal(mgr.get_chapter_index(35), 2, "Level 35 maps to Chapter 2 (Cyber Depot)")
	assert_equal(mgr.get_chapter_index(49), 2, "Level 49 maps to Chapter 2 (Cyber Depot)")

	# 2. Chapter metadata
	var ch0: Dictionary = mgr.get_chapter_info(0)
	assert_equal(ch0.get("name"), "Cargo Bay", "Chapter 0 is named Cargo Bay")
	assert_equal(ch0.get("icon"), "📦", "Chapter 0 icon is 📦")
	assert_equal(ch0.get("start_level"), 0, "Chapter 0 starts at 0")
	assert_equal(ch0.get("end_level"), 14, "Chapter 0 ends at 14")

	var ch1: Dictionary = mgr.get_chapter_info(1)
	assert_equal(ch1.get("name"), "Cold Storage", "Chapter 1 is named Cold Storage")
	assert_equal(ch1.get("icon"), "❄", "Chapter 1 icon is ❄")

	var ch2: Dictionary = mgr.get_chapter_info(2)
	assert_equal(ch2.get("name"), "Cyber Depot", "Chapter 2 is named Cyber Depot")
	assert_equal(ch2.get("icon"), "⚡", "Chapter 2 icon is ⚡")

	# 3. Chapter stars & completion tracking
	assert_equal(mgr.get_chapter_stars(0), 0, "Initial Chapter 0 stars is 0")
	assert_false(mgr.is_chapter_completed(0), "Initial Chapter 0 is not completed")

	mgr.record_level_completion(0, 8, 3, TEST_SAVE_PATH)
	assert_true(mgr.get_chapter_stars(0) >= 1, "Chapter 0 stars updated after completing level 0")
	assert_false(mgr.is_chapter_completed(0), "Chapter 0 not completed until all 15 levels are done")

	mgr.free()


func test_porter_locker_cosmetics() -> void:
	var mgr = SaveManagerScript.new()

	# 1. Defaults
	assert_equal(mgr.selected_worker_skin, "classic", "Default worker skin is 'classic'")
	assert_equal(mgr.selected_crate_skin, "classic_wood", "Default crate skin is 'classic_wood'")
	assert_true(mgr.is_worker_skin_unlocked("classic"), "Classic worker skin is unlocked (0 stars)")
	assert_true(mgr.is_crate_skin_unlocked("classic_wood"), "Classic wood crate is unlocked (0 stars)")

	# 2. Locked status with 0 stars
	assert_false(mgr.is_worker_skin_unlocked("safety_vest"), "Safety Vest is locked initially (needs 25 stars)")
	assert_false(mgr.is_worker_skin_unlocked("foreman"), "Foreman uniform is locked initially (needs 60 stars)")
	assert_false(mgr.is_worker_skin_unlocked("golden_porter"), "Golden Master is locked initially (needs 120 stars)")
	assert_false(mgr.is_crate_skin_unlocked("steel_container"), "Steel Container is locked initially (needs 40 stars)")
	assert_false(mgr.is_crate_skin_unlocked("hazard_box"), "Hazard Crate is locked initially (needs 80 stars)")

	# 3. Equipping locked item fails
	var equip_locked_ok: bool = mgr.equip_worker_skin("safety_vest")
	assert_false(equip_locked_ok, "Cannot equip locked worker skin")
	assert_equal(mgr.selected_worker_skin, "classic", "Equipped worker skin remains classic")

	# 4. Award stars and unlock thresholds
	for i in range(10): # 10 levels with 3 stars = 30 stars
		mgr.completed_levels[str(i)] = { "stars": 3, "best_moves": 5, "best_pushes": 2 }

	assert_equal(mgr.get_total_stars(), 30, "Total stars is now 30")
	assert_true(mgr.is_worker_skin_unlocked("safety_vest"), "Safety Vest (25 stars) is now unlocked")
	assert_false(mgr.is_crate_skin_unlocked("steel_container"), "Steel Container (40 stars) is still locked")

	# 5. Equipping unlocked skin succeeds
	var equip_ok: bool = mgr.equip_worker_skin("safety_vest")
	assert_true(equip_ok, "Equipping unlocked Safety Vest returns true")
	assert_equal(mgr.selected_worker_skin, "safety_vest", "Equipped worker skin is now safety_vest")

	# 6. Reach 45 stars -> Steel Container unlocked
	for i in range(10, 15): # +5 levels with 3 stars = 45 stars total
		mgr.completed_levels[str(i)] = { "stars": 3, "best_moves": 5, "best_pushes": 2 }
	assert_equal(mgr.get_total_stars(), 45, "Total stars is now 45")
	assert_true(mgr.is_crate_skin_unlocked("steel_container"), "Steel Container (40 stars) is now unlocked")

	var crate_equip_ok: bool = mgr.equip_crate_skin("steel_container")
	assert_true(crate_equip_ok, "Equipping unlocked Steel Container returns true")
	assert_equal(mgr.selected_crate_skin, "steel_container", "Equipped crate skin is now steel_container")

	# 7. Persistence
	mgr.save_data(TEST_SAVE_PATH)
	var mgr2 = SaveManagerScript.new()
	mgr2.load_data(TEST_SAVE_PATH)
	assert_equal(mgr2.selected_worker_skin, "safety_vest", "Equipped worker skin persisted across save/load")
	assert_equal(mgr2.selected_crate_skin, "steel_container", "Equipped crate skin persisted across save/load")

	# 8. Reset restores defaults
	mgr2.reset_all_progress(TEST_SAVE_PATH)
	assert_equal(mgr2.selected_worker_skin, "classic", "Reset restores default classic worker skin")
	assert_equal(mgr2.selected_crate_skin, "classic_wood", "Reset restores default classic crate skin")

	mgr.free()
	mgr2.free()

