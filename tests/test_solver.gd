extends SceneTree

## Headless test script for SokobanSolver (Pixel Porter PRD v1.md Section 7).
## Solves and verifies all 10 shipped level files on disk.
## Run via: godot --headless --path . -s tests/test_solver.gd

const SokobanSolverScript = preload("res://scripts/sokoban_solver.gd")
const GridLogicScript = preload("res://scripts/grid_logic.gd")

var _passed_suites: int = 0
var _failed_suites: int = 0
var _total_assertions: int = 0
var _failed_assertions: int = 0


func _init() -> void:
	print("==================================================")
	print("   Pixel Porter - SokobanSolver Headless Tests   ")
	print("==================================================")

	run_suite("All 10 Shipped Levels Verification", test_all_10_levels_solvable)
	run_suite("Unsolvable & Deadlock Detection", test_unsolvable_deadlock)
	run_suite("Walk Pathfinding Around Crates", test_walk_pathfinding)
	run_suite("Next Meaningful Push Plan Tracing", test_next_push_plan)

	print("\n==================================================")
	print("Test Suites: %d passed, %d failed" % [_passed_suites, _failed_suites])
	print("Assertions : %d total, %d failed" % [_total_assertions, _failed_assertions])
	print("==================================================")

	if _failed_assertions > 0 or _failed_suites > 0:
		printerr("FAILED: Test suite had failures.")
		quit(1)
	else:
		print("SUCCESS: All SokobanSolver tests passed successfully!")
		quit(0)


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


func test_all_10_levels_solvable() -> void:
	for i in range(1, 11):
		var path: String = "res://levels/level_%02d.sok" % i
		assert_true(FileAccess.file_exists(path), "Level file %02d exists" % i)

		var grid = GridLogicScript.new()
		var loaded: bool = grid.load_from_file(path)
		assert_true(loaded, "Level %02d loaded successfully" % i)

		var result = SokobanSolverScript.solve(grid)
		print("    Level %02d: %s" % [i, str(result)])
		assert_true(result.is_solvable, "Level %02d is solvable" % i)
		assert_true(result.moves > 0, "Level %02d requires at least 1 move (got %d)" % [i, result.moves])
		assert_true(result.pushes > 0, "Level %02d requires at least 1 push (got %d)" % [i, result.pushes])

		# Verify executing solver solution produces winning state
		var test_grid = grid.clone()
		var executed_count = test_grid.execute_moves(result.solution_str)
		assert_equal(executed_count, result.moves, "Level %02d executed all %d solution moves" % [i, result.moves])
		assert_true(test_grid.is_won(), "Level %02d is WON when executing solver solution" % i)


func test_unsolvable_deadlock() -> void:
	# A level where the crate is trapped in a corner with no goal
	var trapped_text: String = """
#####
#@$ #
# # #
#  .#
#####
"""
	var result = SokobanSolverScript.solve(trapped_text, 1000)
	print("    Trapped level result: %s" % str(result))
	assert_false(result.is_solvable, "Trapped corner crate is correctly pruned and reported unsolvable")


func test_walk_pathfinding() -> void:
	var lvl: String = """
#######
#.$   #
# ### #
#@   .#
#######
"""
	var grid = GridLogicScript.new(lvl)
	var path: Array[Vector2i] = SokobanSolverScript.find_player_walk_path(Vector2i(1, 3), Vector2i(5, 1), grid)
	assert_false(path.is_empty(), "Shortest walk path found around obstacle & crate")
	assert_equal(path.back(), Vector2i(5, 1), "Walk path ends on target tile (5, 1)")

	var blocked: Array[Vector2i] = SokobanSolverScript.find_player_walk_path(Vector2i(1, 3), Vector2i(2, 1), grid)
	assert_true(blocked.is_empty(), "Targeting a crate tile returns empty walk path")


func test_next_push_plan() -> void:
	var grid = GridLogicScript.new()
	assert_true(grid.load_from_file("res://levels/level_01.sok"), "Loaded level_01 for push plan test")
	# Move left first if open, or test from starting state directly so solver walks toward first crate push
	var plan: Dictionary = SokobanSolverScript.get_next_push_plan(grid, 0, "res://levels/level_01.sok", 12)
	assert_false(String(plan.get("first_char", "")).is_empty(), "Push plan returns a valid first move character")
	assert_true(bool(plan.get("has_push", false)), "Push plan reaches an upcoming crate push")
	var waypoints: Array = plan.get("walk_waypoints", [])
	assert_true(waypoints.size() >= 1, "Push plan provides at least 1 walk waypoint")
	assert_true(plan.get("push_dir", Vector2i.ZERO) != Vector2i.ZERO, "Push plan provides non-zero push direction")

	# Verify corner deadlock state reports deadlock without crashing
	var dead_grid = grid.clone()
	dead_grid.execute_moves("rdr")
	var dead_plan: Dictionary = SokobanSolverScript.get_next_push_plan(dead_grid, 0, "res://levels/level_01.sok", 12)
	assert_true(String(dead_plan.get("first_char", "")).is_empty(), "Deadlocked board returns empty first_char")
	assert_true(bool(dead_plan.get("deadlock", false)), "Deadlocked board flags deadlock = true")
