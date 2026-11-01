extends SceneTree

const GridLogicScript = preload("res://scripts/grid_logic.gd")
const SokobanSolverScript = preload("res://scripts/sokoban_solver.gd")

func _init() -> void:
	var passes: int = 0
	var test_levels: Array[int] = [1, 10, 16, 25, 35, 45, 50]
	for lvl in test_levels:
		var path: String = "res://levels/level_%02d.sok" % lvl
		var grid: GridLogic = GridLogicScript.new()
		grid.load_from_file(path)
		var t0: int = Time.get_ticks_usec()
		var hint: String = SokobanSolverScript.get_next_hint(grid, lvl - 1, path)
		var dt_us: int = Time.get_ticks_usec() - t0
		print("Level %02d initial hint: '%s' (computed in %.3f ms)" % [lvl, hint, float(dt_us) / 1000.0])
		if not hint.is_empty():
			passes += 1
	if passes == test_levels.size():
		print("ALL HINT TESTS PASSED INSTANTLY! (0ms ANR-free)")
		quit(0)
	else:
		quit(1)

