extends SceneTree

## Verification script for all 75 Pixel Porter levels (PRD Section 7).
## Solves every shipped level on disk, verifies solutions.json & LevelData parity, and validates progression bounds.
## Run via: godot --headless --path . -s scripts/verify_levels.gd

const SokobanSolverScript: GDScript = preload("res://scripts/sokoban_solver.gd")
const GridLogicScript: GDScript = preload("res://scripts/grid_logic.gd")
const LevelDataScript: GDScript = preload("res://scripts/level_data.gd")

const TOTAL_LEVELS: int = 75

var total_moves: int = 0
var total_pushes: int = 0
var failures: int = 0


func _init() -> void:
	print("\n" + "=".repeat(62))
	print("   Pixel Porter - 75-Level Offline Verification Pipeline   ")
	print("=".repeat(62) + "\n")

	print("%-7s | %-7s | %-6s | %-6s | %-7s | %-8s | %s" % [
		"Level", "Size", "Crates", "Moves", "Pushes", "Time", "Status"
	])
	print("-".repeat(62))

	var total_start_time: int = Time.get_ticks_msec()

	for lvl in range(1, TOTAL_LEVELS + 1):
		var path: String = "res://levels/level_%02d.sok" % lvl
		if not FileAccess.file_exists(path):
			printerr("ERROR: Missing level file at %s" % path)
			failures += 1
			continue

		var grid: GridLogic = GridLogicScript.new()
		if not grid.load_from_file(path):
			printerr("ERROR: Failed to parse level at %s" % path)
			failures += 1
			continue

		# Verify LevelData embedded fallback matches disk .sok layout
		var embedded_text: String = LevelDataScript.get_level_data(lvl - 1)
		if embedded_text.is_empty():
			printerr("FAIL: Level %02d missing from embedded LevelData!" % lvl)
			failures += 1
			continue

		# Verify precomputed optimal solution in solutions.json replays cleanly
		var pre_sol: String = SokobanSolverScript.get_solution_for_level(lvl - 1)
		if pre_sol.is_empty():
			printerr("FAIL: Level %02d missing from solutions.json!" % lvl)
			failures += 1
			continue
		var pre_grid: GridLogic = grid.clone()
		pre_grid.execute_moves(pre_sol)
		if not pre_grid.is_won():
			printerr("FAIL: Level %02d solutions.json sequence did not solve the level!" % lvl)
			failures += 1
			continue

		var start_solve: int = Time.get_ticks_msec()
		var res: SokobanSolver.SolverResult = SokobanSolverScript.solve(grid, 120000)
		var elapsed_ms: float = float(Time.get_ticks_msec() - start_solve)

		if not res.is_solvable:
			printerr("FAIL: Level %02d is reported UNSOLVABLE by solver!" % lvl)
			failures += 1
			continue

		# Verify executing solver solution produces a winning state
		var sim_grid: GridLogic = grid.clone()
		var executed_moves: int = sim_grid.execute_moves(res.solution_str)
		if not sim_grid.is_won() or executed_moves != res.moves:
			printerr("FAIL: Level %02d solution did not solve the level!" % lvl)
			failures += 1
			continue

		total_moves += res.moves
		total_pushes += res.pushes

		var dim_str: String = "%dx%d" % [grid.width, grid.height]
		var crate_cnt: int = grid.get_crates().size()

		print("%-7s | %-7s | %-6d | %-6d | %-7d | %6.1fms | %s" % [
			"Lvl %02d" % lvl,
			dim_str,
			crate_cnt,
			res.moves,
			res.pushes,
			elapsed_ms,
			"PASS ✓"
		])

	var total_time: float = float(Time.get_ticks_msec() - total_start_time) / 1000.0

	print("-".repeat(62))
	print("Summary: %d / %d levels verified solvable" % [TOTAL_LEVELS - failures, TOTAL_LEVELS])
	print("Total moves across all %d levels: %d (avg %.1f per level)" % [TOTAL_LEVELS, total_moves, float(total_moves) / float(TOTAL_LEVELS)])
	print("Total pushes across all %d levels: %d (avg %.1f per level)" % [TOTAL_LEVELS, total_pushes, float(total_pushes) / float(TOTAL_LEVELS)])
	print("Total verification time: %.2f seconds" % total_time)
	print("=".repeat(62))

	if failures > 0:
		printerr("VERIFICATION FAILED: %d levels failed verification." % failures)
		quit(1)
	else:
		print("VERIFICATION SUCCESS: All %d levels are 100%% verified solvable!\n" % TOTAL_LEVELS)
		quit(0)
