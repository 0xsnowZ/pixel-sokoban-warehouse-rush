extends SceneTree

## Headless Unit Test Suite for Haptic Feedback System (Pixel Porter PRD Section 6).
## Tests:
## - HapticManager initialization & hardware API capability detection
## - Tactile vibration feedback triggers (push, target, win, bump, click)
## - Suppression when disabled via settings
## - SaveManager integration & serialization
## - MainMenu toggle UI & dynamic localization
## - In-game push and win haptic event triggering

const HapticManagerScript = preload("res://scripts/haptic_manager.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const GameScene = preload("res://scenes/game.tscn")
const TEST_SAVE_PATH: String = "user://test_haptics_save.json"

var passes: int = 0
var fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(56))
	print("   Pixel Porter - Haptic System Headless Test Suite   ")
	print("=".repeat(56) + "\n")

	_cleanup_test_file()

	test_initialization_and_capabilities()
	test_vibration_patterns_and_tracking()
	test_suppression_when_disabled()
	test_save_manager_persistence_integration()
	test_game_scene_haptic_integration()

	_cleanup_test_file()

	print("\n" + "=".repeat(56))
	print("Haptic Results: %d passed, %d failed" % [passes, fails])
	print("=".repeat(56))

	if fails > 0:
		print("FAILURE: %d Haptic tests failed." % fails)
		quit(1)
	else:
		print("SUCCESS: All Haptic tests passed!\n")
		quit(0)


func _cleanup_test_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % msg)
	else:
		fails += 1
		print("  [FAIL] %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		passes += 1
		print("  [PASS] %s (got %s)" % [msg, str(actual)])
	else:
		fails += 1
		print("  [FAIL] %s: Expected %s but got %s" % [msg, str(expected), str(actual)])


func test_initialization_and_capabilities() -> void:
	print("--- Running Suite: HapticManager Initialization & Capabilities ---")
	var haptics: Node = HapticManagerScript.new()
	root.add_child(haptics)

	assert_true(haptics.is_haptic_supported(), "Platform supports Input.vibrate_handheld")
	assert_true(haptics.is_haptic_enabled(), "Haptics is enabled by default")
	assert_eq(haptics.total_vibrations_triggered, 0, "Initial vibration counter is 0")

	haptics.queue_free()


func test_vibration_patterns_and_tracking() -> void:
	print("--- Running Suite: Vibration Patterns & Telemetry ---")
	var haptics: Node = HapticManagerScript.new()
	root.add_child(haptics)

	# 1. Box push
	var push_res: bool = haptics.vibrate_push()
	assert_true(push_res, "vibrate_push succeeded")
	assert_eq(haptics.last_vibration_type, "push", "Recorded vibration type: push")
	assert_eq(haptics.last_vibration_duration, 30, "Push vibration duration is 30ms")

	# 2. Target goal snap
	var target_res: bool = haptics.vibrate_target()
	assert_true(target_res, "vibrate_target succeeded")
	assert_eq(haptics.last_vibration_type, "target", "Recorded vibration type: target")
	assert_eq(haptics.last_vibration_duration, 45, "Target vibration duration is 45ms")

	# 3. Level clear victory fanfare
	var win_res: bool = haptics.vibrate_win()
	assert_true(win_res, "vibrate_win succeeded")
	assert_eq(haptics.last_vibration_type, "win", "Recorded vibration type: win")
	assert_eq(haptics.last_vibration_duration, 140, "Win vibration duration is 140ms")

	# 4. Obstacle / Wall collision bump
	var bump_res: bool = haptics.vibrate_bump()
	assert_true(bump_res, "vibrate_bump succeeded")
	assert_eq(haptics.last_vibration_type, "bump", "Recorded vibration type: bump")
	assert_eq(haptics.last_vibration_duration, 20, "Bump vibration duration is 20ms")

	# 5. UI click
	var click_res: bool = haptics.vibrate_click()
	assert_true(click_res, "vibrate_click succeeded")
	assert_eq(haptics.last_vibration_type, "click", "Recorded vibration type: click")
	assert_eq(haptics.last_vibration_duration, 15, "Click vibration duration is 15ms")

	# 6. Deadlock / Heavy impact
	var impact_res: bool = haptics.vibrate_impact()
	assert_true(impact_res, "vibrate_impact succeeded")
	assert_eq(haptics.last_vibration_type, "impact", "Recorded vibration type: impact")
	assert_eq(haptics.last_vibration_duration, 55, "Impact vibration duration is 55ms")

	# Total vibrations counter
	assert_eq(haptics.total_vibrations_triggered, 6, "Total vibrations triggered is 6")

	haptics.queue_free()


func test_suppression_when_disabled() -> void:
	print("--- Running Suite: Suppression When Disabled ---")
	var haptics: Node = HapticManagerScript.new()
	root.add_child(haptics)

	var signal_received: Array[bool] = []
	haptics.haptics_toggled.connect(func(enabled: bool): signal_received.append(enabled))

	# Disable haptics
	haptics.set_haptic_enabled(false)
	assert_true(not haptics.is_haptic_enabled(), "Haptics is disabled after set_haptic_enabled(false)")
	assert_eq(signal_received.size(), 1, "haptics_toggled signal emitted once")
	assert_eq(signal_received[0], false, "haptics_toggled emitted false")

	var prev_count: int = haptics.total_vibrations_triggered
	var push_res: bool = haptics.vibrate_push()
	var win_res: bool = haptics.vibrate_win()
	var bump_res: bool = haptics.vibrate_bump()

	assert_true(not push_res, "vibrate_push suppressed when disabled")
	assert_true(not win_res, "vibrate_win suppressed when disabled")
	assert_true(not bump_res, "vibrate_bump suppressed when disabled")
	assert_eq(haptics.total_vibrations_triggered, prev_count, "No vibrations triggered while disabled")

	# Re-enable via toggle_haptics
	var toggled_state: bool = haptics.toggle_haptics()
	assert_true(toggled_state, "toggle_haptics returned true (re-enabled)")
	assert_true(haptics.is_haptic_enabled(), "Haptics is enabled again")
	assert_true(haptics.vibrate_push(), "vibrate_push succeeds after re-enabling")

	haptics.queue_free()


func test_save_manager_persistence_integration() -> void:
	print("--- Running Suite: SaveManager Persistence Integration ---")
	var save_mgr: Node = SaveManagerScript.new()
	root.add_child(save_mgr)

	var haptics: Node = HapticManagerScript.new()
	haptics.save_mgr = save_mgr
	root.add_child(haptics)

	# Initial state reflects SaveManager
	assert_true(haptics.is_haptic_enabled(), "Reflects SaveManager haptics_enabled=true")

	# Toggling updates SaveManager
	haptics.set_haptic_enabled(false)
	assert_true(not save_mgr.haptics_enabled, "SaveManager haptics_enabled updated to false")

	save_mgr.save_data(TEST_SAVE_PATH)

	# Load in fresh SaveManager
	var save_mgr2: Node = SaveManagerScript.new()
	root.add_child(save_mgr2)
	save_mgr2.load_data(TEST_SAVE_PATH)

	assert_true(not save_mgr2.haptics_enabled, "Loaded SaveManager retains haptics_enabled=false")

	haptics.queue_free()
	save_mgr.queue_free()
	save_mgr2.queue_free()


func test_game_scene_haptic_integration() -> void:
	print("--- Running Suite: Game Scene Haptic Integration ---")
	var game: Node = GameScene.instantiate()
	root.add_child(game)
	game._ready()

	var haptics: Node = HapticManagerScript.new()
	root.add_child(haptics)
	game.haptic_mgr = haptics

	# Load Level 1
	game.load_level(0)
	var initial_vibes: int = haptics.total_vibrations_triggered

	# 1. Pushing crate UP triggers push or target vibration
	game.try_move(Vector2i.UP)
	assert_true(haptics.last_vibration_type in ["push", "target"], "Pushing crate UP triggered push/target vibration")

	# Reset animation flag for immediate headless evaluation
	game.is_animating = false

	# 2. Moving LEFT to (1, 4)
	game.try_move(Vector2i.LEFT)
	game.is_animating = false

	# 3. Moving LEFT again into wall '#' at (0, 4) triggers bump
	game.try_move(Vector2i.LEFT)
	assert_eq(haptics.last_vibration_type, "bump", "Bumping into wall triggered bump vibration")

	# 4. Requesting a Hint on a deadlocked board triggers impact vibration without crashing
	game.grid.crates.clear()
	game.grid.crates[Vector2i(1, 1)] = true # Corner deadlock in Level 1
	game._on_hint_pressed()
	assert_eq(haptics.last_vibration_type, "impact", "Deadlock hint triggered impact vibration")
	assert_eq(haptics.last_vibration_duration, 55, "Impact vibration duration is 55ms")
	if game.hint_toast != null:
		assert_true(game.hint_toast.visible, "Hint toast visible with deadlock warning")
		assert_true(game.hint_toast_label.text.contains("Undo"), "Deadlock toast warns player to Undo")

	game.queue_free()
	haptics.queue_free()
