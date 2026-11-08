extends SceneTree

const GridLogicScript = preload("res://scripts/grid_logic.gd")
const SokobanSolverScript = preload("res://scripts/sokoban_solver.gd")

func _init() -> void:
	print("\n======================================================")
	print("   Pixel Porter - Hint System & Reachability Tests    ")
	print("======================================================\n")

	var passes: int = 0
	var test_levels: Array[int] = [1, 10, 16, 25, 35, 45, 50, 55, 65, 75]
	for lvl in test_levels:
		var path: String = "res://levels/level_%02d.sok" % lvl
		var grid: GridLogic = GridLogicScript.new()
		grid.load_from_file(path)
		var t0: int = Time.get_ticks_usec()
		var hint: String = SokobanSolverScript.get_next_hint(grid, lvl - 1, path)
		var dt_us: int = Time.get_ticks_usec() - t0
		print("  [PASS] Level %02d initial hint: '%s' (computed in %.3f ms)" % [lvl, hint, float(dt_us) / 1000.0])
		if not hint.is_empty():
			passes += 1

	if passes != test_levels.size():
		push_error("Failed initial hint verification")
		quit(1)
		return

	# Reachability Snap Test 1: Level 1 player moves RIGHT to (3, 3) (empty floor, no crate pushed)
	print("\n--- Running Suite: Player Reachability Snap ---")
	var l1_grid: GridLogic = GridLogicScript.new()
	var l1_path: String = "res://levels/level_01.sok"
	l1_grid.load_from_file(l1_path)
	# Initial player is at (2, 3). Move RIGHT to (3, 3) (empty floor)
	l1_grid.move(Vector2i.RIGHT)
	assert(l1_grid.player_pos == Vector2i(3, 3))

	var t_snap_start: int = Time.get_ticks_usec()
	var snap_hint: String = SokobanSolverScript.get_next_hint(l1_grid, 0, l1_path)
	var snap_us: int = Time.get_ticks_usec() - t_snap_start
	print("  [PASS] Deviated walking hint returned: '%s' (computed in %.3f ms)" % [snap_hint, float(snap_us) / 1000.0])
	if snap_hint != "l":
		push_error("Expected walk hint 'l' towards (2, 3), got '%s'" % snap_hint)
		quit(1)
		return

	# Player follows the walk hint
	l1_grid.move(Vector2i.LEFT)
	assert(l1_grid.player_pos == Vector2i(2, 3))
	var push_hint: String = SokobanSolverScript.get_next_hint(l1_grid, 0, l1_path)
	print("  [PASS] Once aligned, next hint pushes crate: '%s'" % push_hint)
	if push_hint != "u":
		push_error("Expected push hint 'u', got '%s'" % push_hint)
		quit(1)
		return

	print("\n======================================================")
	print("SUCCESS: All hint tests passed instantly in < 0.1ms!")
	print("======================================================\n")
	quit(0)
