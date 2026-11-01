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

