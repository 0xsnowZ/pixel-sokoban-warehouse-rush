extends SceneTree

## Headless test script for GridLogic (Pixel Porter PRD v1.md Sections 4 & 5).
## Run via: godot --headless --path . -s tests/test_grid_logic.gd

const GridLogicScript = preload("res://scripts/grid_logic.gd")

var _passed_suites: int = 0
var _failed_suites: int = 0
var _total_assertions: int = 0
var _failed_assertions: int = 0


func _init() -> void:
	print("==================================================")
	print("  Pixel Porter - GridLogic Headless Test Suite   ")
	print("==================================================")

	run_suite("Level 1 (Single Crate Tutorial)", test_level_1_single_crate_tutorial)
	run_suite("Level 2 (Two Crates & Partial Completion)", test_level_2_two_crates_and_partial_completion)
	run_suite("Level 3 (PRD Rules Verification & 3 Crates)", test_level_3_prd_rules_edge_cases_and_multi_crate)
	run_suite("Sokoban Symbols Parsing & to_text Export", test_sokoban_symbols_parsing)
	run_suite("Undo Mechanics & History Stack", test_undo_mechanics)
	run_suite("Undo Last Push Rewind", test_undo_last_push_rewind)

	print("\n==================================================")
	print("Test Suites: %d passed, %d failed" % [_passed_suites, _failed_suites])
	print("Assertions : %d total, %d failed" % [_total_assertions, _failed_assertions])
	print("==================================================")

	if _failed_assertions > 0 or _failed_suites > 0:
		printerr("FAILED: Test suite had failures.")
		quit(1)
	else:
		print("SUCCESS: All tests passed successfully!")
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


const TEST_LEVEL_1_FIXTURE: String = """
######
#   .#
# $  #
# @  #
#    #
######
"""

## Test 1: Level 1 (6x6, 1 crate)
## - Loading from standard Sokoban text format
## - Verifying dimensions, initial positions, and win condition = false
## - Testing player movement, signals, and crate push
## - Testing win detection when crate reaches goal
func test_level_1_single_crate_tutorial() -> void:
	var grid = GridLogicScript.new()
	var loaded: bool = grid.load_from_text(TEST_LEVEL_1_FIXTURE)
	assert_true(loaded, "Level 1 loaded from text successfully")
	assert_equal(grid.width, 6, "Level 1 width is 6")
	assert_equal(grid.height, 6, "Level 1 height is 6")
	assert_equal(grid.get_player_pos(), Vector2i(2, 3), "Player initial position is (2, 3)")
	assert_equal(grid.get_crate_count(), 1, "Level has 1 crate")
	assert_equal(grid.get_goal_count(), 1, "Level has 1 goal")
	assert_true(grid.has_crate(Vector2i(2, 2)), "Crate is at (2, 2)")
	assert_true(grid.is_goal(Vector2i(4, 1)), "Goal is at (4, 1)")
	assert_false(grid.is_won(), "Level 1 is not won initially")

	# Test signals using a Dictionary reference to capture mutations in GDScript lambdas
	var signal_stats: Dictionary = {
		"player_moved": 0,
		"crate_pushed": 0,
		"level_won": 0,
		"level_reset": 0
	}

	grid.player_moved.connect(func(_from: Vector2i, _to: Vector2i): signal_stats["player_moved"] += 1)
	grid.crate_pushed.connect(func(_from: Vector2i, _to: Vector2i): signal_stats["crate_pushed"] += 1)
	grid.level_won.connect(func(): signal_stats["level_won"] += 1)
	grid.level_reset.connect(func(): signal_stats["level_reset"] += 1)

	# Also test loading from file
	var grid_file = GridLogicScript.new()
	var file_loaded: bool = grid_file.load_from_file("res://levels/level_01.sok")
	assert_true(file_loaded, "Level 1 loaded from res://levels/level_01.sok")
	assert_true(grid_file.is_in_bounds(grid_file.get_player_pos()), "File loaded player position is in bounds")

	# Test fallback to embedded LevelData when .sok path is missing
	var grid_fallback = GridLogicScript.new()
	var fallback_loaded: bool = grid_fallback.load_from_file("res://levels/missing_dir/level_01.sok")
	assert_true(fallback_loaded, "Missing level_01.sok falls back cleanly to embedded LevelData")
	assert_equal(grid_fallback.get_player_pos(), grid_file.get_player_pos(), "Fallback Level 1 player position matches disk file")
	assert_equal(grid_fallback.get_crate_count(), grid_file.get_crate_count(), "Fallback Level 1 crate count matches disk file")

	# Test wall collision: moving down to floor (2, 4), then attempting to enter wall (2, 5)
	assert_true(grid.move(Vector2i.DOWN), "Player moves down to (2, 4)")
	assert_equal(signal_stats["player_moved"], 1, "player_moved signal emitted once")
	assert_equal(grid.get_player_pos(), Vector2i(2, 4), "Player is at (2, 4)")
	assert_equal(grid.moves_count, 1, "moves_count incremented to 1")

	# Trying to walk into wall at (2, 5)
	assert_false(grid.move(Vector2i.DOWN), "Player cannot move into wall at (2, 5)")
	assert_equal(grid.get_player_pos(), Vector2i(2, 4), "Player position remains (2, 4)")
	assert_equal(grid.moves_count, 1, "moves_count not incremented on blocked move")

	# Test restart / reset
	grid.restart()
	assert_equal(signal_stats["level_reset"], 1, "level_reset signal emitted")
	assert_equal(grid.get_player_pos(), Vector2i(2, 3), "Player position restored to (2, 3) on restart")
	assert_equal(grid.moves_count, 0, "moves_count reset to 0")
	assert_equal(grid.pushes_count, 0, "pushes_count reset to 0")
	assert_false(grid.is_won(), "is_won is false after restart")

	# Reset signal counters for solving phase
	signal_stats["player_moved"] = 0
	signal_stats["crate_pushed"] = 0

	# Execute optimal solution: ulurr (Up, Left, Up, Right, Right)
	# 1. 'u': Up -> pushes crate (2,2) -> (2,1), player moves to (2,2)
	assert_true(grid.move("u"), "Move 'u': push crate up")
	assert_equal(signal_stats["crate_pushed"], 1, "crate_pushed signal emitted")
	assert_true(grid.last_move_pushed_crate, "last_move_pushed_crate is true")
	assert_equal(grid.get_player_pos(), Vector2i(2, 2), "Player at (2, 2)")
	assert_true(grid.has_crate(Vector2i(2, 1)), "Crate pushed to (2, 1)")
	assert_equal(grid.pushes_count, 1, "pushes_count is 1")
	assert_equal(grid.moves_count, 1, "moves_count is 1")
	assert_false(grid.is_won(), "Not won yet")

	# 2. 'l': Left -> player moves to (1, 2)
	assert_true(grid.move("l"), "Move 'l': player moves left")
	assert_equal(signal_stats["crate_pushed"], 1, "No extra crate_pushed signal on move 'l'")
	assert_false(grid.last_move_pushed_crate, "last_move_pushed_crate is false")
	assert_equal(grid.get_player_pos(), Vector2i(1, 2), "Player at (1, 2)")
	assert_true(grid.has_crate(Vector2i(2, 1)), "Crate unmoved at (2, 1)")

	# 3. 'u': Up -> player moves to (1, 1)
	assert_true(grid.move("u"), "Move 'u': player moves up to (1, 1)")
	assert_equal(grid.get_player_pos(), Vector2i(1, 1), "Player at (1, 1)")

	# 4. 'r': Right -> pushes crate from (2, 1) to (3, 1)
	assert_true(grid.move("r"), "Move 'r': push crate right to (3, 1)")
	assert_equal(signal_stats["crate_pushed"], 2, "crate_pushed emitted 2nd time")
	assert_equal(grid.get_player_pos(), Vector2i(2, 1), "Player at (2, 1)")
	assert_true(grid.has_crate(Vector2i(3, 1)), "Crate at (3, 1)")
	assert_equal(grid.pushes_count, 2, "pushes_count is 2")
	assert_false(grid.is_won(), "Not won yet")

	# 5. 'r': Right -> pushes crate from (3, 1) to (4, 1) [Goal!]
	assert_true(grid.move("r"), "Move 'r': push crate into goal at (4, 1)")
	assert_equal(signal_stats["crate_pushed"], 3, "crate_pushed emitted 3rd time")
	assert_equal(grid.get_player_pos(), Vector2i(3, 1), "Player at (3, 1)")
	assert_true(grid.has_crate(Vector2i(4, 1)), "Crate at goal (4, 1)")
	assert_equal(grid.pushes_count, 3, "pushes_count is 3")
	assert_equal(grid.moves_count, 5, "moves_count is 5")

	# Verify Level Won!
	assert_true(grid.is_won(), "Level 1 is WON: every crate sits on a goal tile")
	assert_equal(signal_stats["level_won"], 1, "level_won signal was emitted")


## Test 2: Level 2 (7x7, 2 crates)
## - Testing multi-crate puzzle
## - Verifying partial completion does not report won
## - Solving with execute_moves()
const TEST_LEVEL_2_FIXTURE: String = """
#######
# . $ #
#  $  #
#  .  #
#  @  #
#     #
#######
"""

const TEST_LEVEL_3_FIXTURE: String = """
########
#  . . #
#  $$$ #
#   @. #
########
"""

## Test 2: Two Crates & Partial Completion
## - Verifying clone() independent behavior
func test_level_2_two_crates_and_partial_completion() -> void:
	var grid = GridLogicScript.new()
	var loaded: bool = grid.load_from_text(TEST_LEVEL_2_FIXTURE)
	assert_true(loaded, "Level 2 fixture loaded successfully")
	assert_equal(grid.get_crate_count(), 2, "Level 2 has 2 crates")
	assert_equal(grid.get_goal_count(), 2, "Level 2 has 2 goals")
	assert_equal(grid.get_crates_on_goal_count(), 0, "Initially 0 crates on goal")
	assert_false(grid.is_won(), "Level 2 is not won initially")

	# Test clone() creates independent instance
	var grid_clone = grid.clone()
	assert_equal(grid_clone.get_player_pos(), grid.get_player_pos(), "Clone has identical player pos")
	assert_equal(grid_clone.get_crate_count(), 2, "Clone has 2 crates")

	# In Level 2 fixture, solution is "ururulld" (8 moves):
	# Steps 1 to 7: player maneuvers and pushes 1 crate onto goal at (2, 1)
	var first_7_moves = "ururull"
	var executed: int = grid.execute_moves(first_7_moves)
	assert_equal(executed, 7, "Executed 7 moves of solution")

	# At this point, exactly 1 crate is on a goal
	assert_equal(grid.get_crates_on_goal_count(), 1, "Exactly 1 crate is on a goal")
	# PRD Section 4: "A level is complete when every crate sits on a goal tile."
	assert_false(grid.is_won(), "Level is NOT won when only 1 of 2 crates is on a goal")

	# Verify clone was unaffected by original's moves
	assert_equal(grid_clone.moves_count, 0, "Clone moves_count remains 0")
	assert_equal(grid_clone.get_crates_on_goal_count(), 0, "Clone crate positions unchanged")

	# Execute final move: "d" pushes second crate to goal at (3, 3)
	assert_true(grid.move("d"), "Move 'd': pushes second crate onto goal")

	# Both crates now on goals
	assert_equal(grid.get_crates_on_goal_count(), 2, "All 2 crates are on goals")
	assert_equal(grid.moves_count, 8, "Total moves count is 8")
	assert_true(grid.is_won(), "Level 2 is WON: all crates on goals")


## Test 3: Level 3 (8x5, 3 crates)
## - PRD Section 4 rule: Two crates cannot be pushed at once
## - PRD Section 4 rule: Pushing crate into wall is blocked
## - PRD Section 4 rule: Crates cannot be pulled
## - PRD Section 4 rule: Turn-based orthogonal moves only
## - Full solve of 3-crate puzzle
func test_level_3_prd_rules_edge_cases_and_multi_crate() -> void:
	var grid = GridLogicScript.new()
	var loaded: bool = grid.load_from_text(TEST_LEVEL_3_FIXTURE)
	assert_true(loaded, "Level 3 fixture loaded successfully")
	assert_equal(grid.get_crate_count(), 3, "Level 3 has 3 crates")
	assert_equal(grid.get_goal_count(), 3, "Level 3 has 3 goals")
	assert_false(grid.is_won(), "Level 3 is not won initially")

	# In Level 3:
	# Row 2: #  $$$ # -> Crates at (3, 2), (4, 2), (5, 2)
	# Row 3: #   @. # -> Player at (4, 3), Goal at (5, 3)
	assert_true(grid.has_crate(Vector2i(3, 2)), "Crate 1 at (3, 2)")
	assert_true(grid.has_crate(Vector2i(4, 2)), "Crate 2 at (4, 2)")
	assert_true(grid.has_crate(Vector2i(5, 2)), "Crate 3 at (5, 2)")
	assert_equal(grid.get_player_pos(), Vector2i(4, 3), "Player starts at (4, 3)")

	# Rule Test 1: PUSHING TWO CRATES AT ONCE IS BLOCKED
	# Move player to (2, 2) to face the crate row:
	# From (4, 3): left to (3, 3), left to (2, 3), up to (2, 2)
	assert_true(grid.move("l"), "Move left to (3, 3)")
	assert_true(grid.move("l"), "Move left to (2, 3)")
	assert_true(grid.move("u"), "Move up to (2, 2)")
	assert_equal(grid.get_player_pos(), Vector2i(2, 2), "Player positioned at (2, 2)")

	# From (2, 2), moving RIGHT targets crate at (3, 2).
	# Behind (3, 2) is (4, 2), which ALSO has a crate!
	# Rule: "two crates cannot be pushed at once."
	var two_crates_push = grid.move("r")
	assert_false(two_crates_push, "Pushing two crates at once is BLOCKED and returns false")
	assert_equal(grid.get_player_pos(), Vector2i(2, 2), "Player remains at (2, 2)")
	assert_true(grid.has_crate(Vector2i(3, 2)), "Crate at (3, 2) did not move")
	assert_true(grid.has_crate(Vector2i(4, 2)), "Crate at (4, 2) did not move")

	# Rule Test 2: CRATES CANNOT BE PULLED
	# Move player LEFT away from the crate at (3, 2):
	# Player is at (2, 2), crate is at (3, 2). Moving left moves player to (1, 2).
	assert_true(grid.move("l"), "Player moves away (left) to (1, 2)")
	assert_equal(grid.get_player_pos(), Vector2i(1, 2), "Player moved to (1, 2)")
	assert_true(grid.has_crate(Vector2i(3, 2)), "Crate remained at (3, 2) (crates cannot be pulled)")

	# Rule Test 3: PUSHING CRATE INTO A WALL IS BLOCKED
	# Let's restart and push crate at (3, 2) UP to (3, 1)
	grid.restart()
	assert_equal(grid.get_player_pos(), Vector2i(4, 3), "Player reset to (4, 3)")

	# Move player to (3, 3) then up to push crate from (3, 2) to (3, 1)
	assert_true(grid.move("l"), "Move left to (3, 3)")
	assert_true(grid.move("u"), "Push crate from (3, 2) up to (3, 1)")
	assert_equal(grid.get_player_pos(), Vector2i(3, 2), "Player now at (3, 2)")
	assert_true(grid.has_crate(Vector2i(3, 1)), "Crate now at (3, 1)")

	# Behind (3, 1) is (3, 0), which is a wall '#'
	# Trying to push crate at (3, 1) UP into wall (3, 0)
	var push_into_wall = grid.move("u")
	assert_false(push_into_wall, "Pushing crate into wall is BLOCKED and returns false")
	assert_equal(grid.get_player_pos(), Vector2i(3, 2), "Player position remains (3, 2)")
	assert_true(grid.has_crate(Vector2i(3, 1)), "Crate remains at (3, 1)")

	# Rule Test 4: DIAGONAL / INVALID MOVES ARE REJECTED
	assert_false(grid.move(Vector2i(1, 1)), "Diagonal direction Vector2i(1, 1) rejected")
	assert_false(grid.move("invalid"), "Invalid string direction rejected")
	assert_false(grid.move(123), "Invalid type rejected")

	# Reset and solve Level 3 to win
	grid.restart()
	assert_equal(grid.moves_count, 0, "moves_count reset to 0")
	assert_equal(grid.pushes_count, 0, "pushes_count reset to 0")

	# Full solution sequence for Level 3: "ludrrululdllurddrr" (18 moves)
	var l3_solution = "ludrrululdllurddrr"
	var solved_moves: int = grid.execute_moves(l3_solution)
	assert_equal(solved_moves, 18, "Executed all 18 moves of Level 3 solution")

	# Verify Level 3 is WON
	assert_equal(grid.get_crates_on_goal_count(), 3, "All 3 crates are on goals")
	assert_true(grid.is_won(), "Level 3 is WON!")


## Test 4: Verify parser handling of '*' (crate on goal) and '+' (player on goal)
func test_sokoban_symbols_parsing() -> void:
	var map_with_all_symbols: String = """
#####
#+* #
#####
"""
	var grid = GridLogicScript.new()
	var loaded: bool = grid.load_from_text(map_with_all_symbols)
	assert_true(loaded, "Map with '+' and '*' loaded successfully")

	# '+' means player on goal
	assert_equal(grid.get_player_pos(), Vector2i(1, 1), "Player parsed at (1, 1)")
	assert_true(grid.is_goal(Vector2i(1, 1)), "Goal exists under player at (1, 1)")

	# '*' means crate on goal
	assert_true(grid.has_crate(Vector2i(2, 1)), "Crate parsed at (2, 1)")
	assert_true(grid.is_goal(Vector2i(2, 1)), "Goal exists under crate at (2, 1)")

	# Because the crate is already on the goal, is_won should be true
	assert_true(grid.is_won(), "Level with crate starting on goal reports is_won() == true")

	# Test to_text() export preserves characters
	var exported: String = grid.to_text()
	assert_true(exported.contains("+"), "Exported map contains '+' for player on goal")
	assert_true(exported.contains("*"), "Exported map contains '*' for crate on goal")


## Test 5: Verify Undo mechanics, history stack, and crate position rollbacks
func test_undo_mechanics() -> void:
	var grid = GridLogicScript.new()
	grid.load_from_text(TEST_LEVEL_1_FIXTURE)

	assert_false(grid.can_undo(), "can_undo() is false initially")
	assert_false(grid.undo(), "undo() returns false when history is empty")

	var init_player: Vector2i = grid.get_player_pos()

	# Move DOWN (empty floor, no crate)
	grid.move("d")
	assert_true(grid.can_undo(), "can_undo() is true after move")
	assert_equal(grid.moves_count, 1, "moves_count is 1")
	assert_equal(grid.pushes_count, 0, "pushes_count is 0")
	assert_equal(grid.get_player_pos(), init_player + Vector2i.DOWN, "Player moved down")

	# Undo move
	var undone: bool = grid.undo()
	assert_true(undone, "undo() returns true")
	assert_equal(grid.get_player_pos(), init_player, "Player returned to initial position")
	assert_equal(grid.moves_count, 0, "moves_count restored to 0")
	assert_false(grid.can_undo(), "can_undo() is false after undoing back to start")

	# Push crate from (2, 2) to (2, 1)
	grid.move(Vector2i.UP)
	assert_equal(grid.moves_count, 1, "moves_count is 1 after push")
	assert_equal(grid.pushes_count, 1, "pushes_count is 1 after push")
	assert_true(grid.has_crate(Vector2i(2, 1)), "Crate moved to (2, 1)")
	assert_false(grid.has_crate(Vector2i(2, 2)), "Old crate tile (2, 2) is now empty")

	# Undo push
	undone = grid.undo()
	assert_true(undone, "undo() succeeds on crate push")
	assert_equal(grid.moves_count, 0, "moves_count restored to 0")
	assert_equal(grid.pushes_count, 0, "pushes_count restored to 0")
	assert_equal(grid.get_player_pos(), init_player, "Player restored to (2, 3)")
	assert_true(grid.has_crate(Vector2i(2, 2)), "Crate restored to (2, 2)")
	assert_false(grid.has_crate(Vector2i(2, 1)), "Destination tile (2, 1) is no longer a crate")
	assert_false(grid.can_undo(), "can_undo() is false after rolling back all moves")


func test_undo_last_push_rewind() -> void:
	var lvl: String = """
########
#@ $  .#
########
"""
	var grid = GridLogicScript.new(lvl)
	assert_false(grid.can_undo_push(), "No push in history initially")
	assert_equal(grid.undo_last_push(), 0, "undo_last_push returns 0 without prior push")

	# Walk 1 step right, push twice ('r','r'), walk 'l','r' -> 2 pushes total
	grid.execute_moves("rrrlr")
	assert_true(grid.has_crate(Vector2i(5, 1)), "Crate now at (5, 1) after 2 pushes")
	assert_true(grid.can_undo_push(), "can_undo_push() is true after pushing crate")

	# First Rewind Push rewinds trailing 'r','l' + 2nd push (3 moves), leaving push #1 intact
	var rewound: int = grid.undo_last_push()
	assert_equal(rewound, 3, "undo_last_push rewound 2nd push plus trailing walk steps")
	assert_true(grid.has_crate(Vector2i(4, 1)), "Crate restored to intermediate position (4, 1)")
	assert_equal(grid.get_player_pos(), Vector2i(3, 1), "Player restored right behind (4, 1)")
	assert_equal(grid.pushes_count, 1, "Push count restored to 1")
	assert_true(grid.can_undo_push(), "First push remains undoable in history")

	# Second Rewind Push rewinds push #1 back to initial crate position (3, 1)
	var rewound2: int = grid.undo_last_push()
	assert_equal(rewound2, 1, "Second undo_last_push rewound push #1")
	assert_true(grid.has_crate(Vector2i(3, 1)), "Crate restored to initial position (3, 1)")
	assert_equal(grid.get_player_pos(), Vector2i(2, 1), "Player restored to (2, 1)")
	assert_equal(grid.pushes_count, 0, "Push count restored to 0")
	assert_false(grid.can_undo_push(), "No push left in history after rewinding both pushes")
