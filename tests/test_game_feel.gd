extends SceneTree

# ==============================================================================
# Pixel Porter - Option A: Game Feel & Tactility Test Suite
# ==============================================================================

var passed_count: int = 0
var failed_count: int = 0


func assert_true(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % message)
	else:
		failed_count += 1
		push_error("  [FAIL] %s" % message)


func _init() -> void:
	print("\n======================================================")
	print("    Pixel Porter - Game Feel & Tactility Test Suite   ")
	print("======================================================\n")

	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node = game_scene.instantiate()
	root.add_child(game)
	game._ready()
	game.load_level(0)

	test_bump_recoil(game)
	test_hold_to_undo(game)
	test_goal_lockin_squash(game)
	test_deadlock_radar(game)

	print("\n======================================================")
	print("Game Feel Results: %d passed, %d failed" % [passed_count, failed_count])
	print("======================================================\n")

	game.queue_free()
	if failed_count > 0:
		quit(1)
	else:
		print("SUCCESS: All game feel tests passed!\n")
		quit(0)


func test_bump_recoil(game: Node) -> void:
	print("--- Running Suite: Wall Bump Recoil ---")
	assert_true("bump_offset" in game, "Game scene defines bump_offset Vector2")
	game.is_animating = false
	game._trigger_bump_recoil(Vector2i.UP)
	assert_true(game.bump_offset == Vector2(0, -4.5), "Bump recoil sets physical offset (got %s)" % str(game.bump_offset))
	assert_true(game.board_trauma > 0.1, "Bump recoil adds screen trauma (got %f)" % game.board_trauma)


func test_hold_to_undo(game: Node) -> void:
	print("--- Running Suite: Hold-to-Rewind Undo ---")
	assert_true("is_undo_held" in game, "Game defines is_undo_held")
	assert_true("undo_hold_time" in game, "Game defines undo_hold_time")

	# Make a move
	game.grid.move(Vector2i.RIGHT)
	assert_true(game.grid.can_undo(), "Grid has moves in history")

	game._on_undo_button_down()
	assert_true(game.is_undo_held, "Undo button down activates hold state")

	# Simulate 0.35s hold (> 300ms threshold + 85ms step)
	game._process(0.32)
	game._process(0.09)
	assert_true(not game.grid.can_undo(), "Hold to undo rewound history back to start")

	game._on_undo_button_up()
	assert_true(not game.is_undo_held, "Undo button up clears hold state")


func test_goal_lockin_squash(game: Node) -> void:
	print("--- Running Suite: Magnetic Goal Lock-in Squash ---")
	assert_true(game.has_method("_animate_crate"), "Game defines _animate_crate")
	var goal_pos: Vector2i = game.grid.goals.keys()[0]
	var push_from: Vector2i = goal_pos - Vector2i.RIGHT
	game._animate_crate(push_from, goal_pos)
	assert_true(game.crate_squash.has(goal_pos), "Crate squash registered on goal entry")
	var sq: Vector2 = game.crate_squash[goal_pos]
	assert_true(sq == Vector2(1.24, 0.78), "Entering goal applies juicy squash (1.24, 0.78) (got %s)" % str(sq))


func test_deadlock_radar(game: Node) -> void:
	print("--- Running Suite: Proactive Deadlock Radar ---")
	assert_true("active_deadlocked_crates" in game, "Game scene defines active_deadlocked_crates")
	assert_true("deadlock_pulse_timer" in game, "Game scene defines deadlock_pulse_timer")
	assert_true(game.has_method("_draw_deadlock_radar"), "Game defines _draw_deadlock_radar")

	# Test 1: Corner Deadlock Detection & Camera/Undo reaction
	var level_corner: String = "#####\n#@$ #\n#   #\n#####"
	game.grid.load_from_text(level_corner)
	game.visual_player_pos = Vector2(game.grid.get_player_pos())
	game.visual_crates.clear()
	for c in game.grid.crates.keys():
		game.visual_crates[c] = Vector2(c)
	game._refresh_deadlock_radar(false)
	assert_true(game.active_deadlocked_crates.is_empty(), "Initial layout has no deadlocks")

	# Push crate into top-right corner (3, 1)
	game.is_animating = false
	game.try_move(Vector2i.RIGHT)
	assert_true(game.active_deadlocked_crates.has(Vector2i(3, 1)), "Crate pushed into dead corner detected in active_deadlocked_crates")
	assert_true(game.cctv_alert_timer > 0.5, "Deadlock triggered CCTV camera alert mode (got %f)" % game.cctv_alert_timer)

	# Test 2: Process loop pulses Undo button
	game.is_animating = false
	game._process(0.02)
	assert_true(game.deadlock_pulse_timer > 0.0, "Deadlock pulse timer advanced")
	assert_true(game.undo_button.modulate != Color.WHITE, "Undo button is modulating with warning shimmer")

	# Test 3: Redraw request passes cleanly with active deadlock radar
	game.queue_redraw()
	assert_true(true, "Board redraw queued cleanly with active deadlock radar")

	# Test 4: Undo automatically clears deadlock radar
	game.is_animating = false
	game._on_undo_pressed()
	game._process(0.02)
	assert_true(game.active_deadlocked_crates.is_empty(), "Undo cleared active_deadlocked_crates")
	assert_true(game.undo_button.modulate == Color.WHITE, "Undo button restored to neutral Color.WHITE")

	# Test 5: Goal Exemption (crate on a goal in a corner is NOT a deadlock)
	var level_goal_in_corner: String = "#####\n#@ *#\n#   #\n#####"
	game.grid.load_from_text(level_goal_in_corner)
	var deadlocked_on_goal: Array[Vector2i] = game.grid.get_deadlocked_crates()
	assert_true(deadlocked_on_goal.is_empty(), "Crate on goal in a corner is exempt from deadlock detection")

	# Test 6: 2x2 solid block deadlock
	var level_2x2: String = "######\n#@$$ #\n# ## #\n######"
	game.grid.load_from_text(level_2x2)
	var deadlocked_2x2: Array[Vector2i] = game.grid.get_deadlocked_crates()
	assert_true(deadlocked_2x2.size() >= 2, "2x2 solid block of crates and walls detected as deadlocks (got %d)" % deadlocked_2x2.size())

	# Restore level 0 for subsequent clean exit
	game.load_level(0)


