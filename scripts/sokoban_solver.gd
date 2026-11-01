class_name SokobanSolver
extends RefCounted

## Automated BFS solver, deadlock analyzer, and hint generator for Pixel Porter levels.
## Implements PRD Section 7 offline verification pipeline & in-game hint economy:
## - Fast precomputed optimal solution lookup (0ms hint generation).
## - High-speed BFS solver using lightweight state allocations.
## - Prunes corner deadlocks and unpushable states.
## - Returns solvability status, minimum moves, minimum pushes, and solution string.

const GridLogicScript = preload("res://scripts/grid_logic.gd")

class SolverResult:
	var is_solvable: bool = false
	var is_deadlock: bool = false
	var timed_out: bool = false
	var moves: int = 0
	var pushes: int = 0
	var solution_str: String = "" # e.g. "uurrddll"
	var states_explored: int = 0
	var time_ms: float = 0.0

	func _to_string() -> String:
		if is_solvable:
			return "SOLVABLE: %d moves, %d pushes (Explored %d states in %.2fms)" % [moves, pushes, states_explored, time_ms]
		if is_deadlock:
			return "DEADLOCK CONFIRMED (Explored %d states in %.2fms)" % [states_explored, time_ms]
		return "UNSOLVABLE or TIMED OUT (Explored %d states in %.2fms)" % [states_explored, time_ms]


static var _solutions_cache: Dictionary = {}
static var _path_states_cache: Dictionary = {}


## Loads and caches verified solutions from res://levels/solutions.json.
static func load_solutions() -> Dictionary:
	if not _solutions_cache.is_empty():
		return _solutions_cache
	var path: String = "res://levels/solutions.json"
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var txt: String = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary:
				_solutions_cache = parsed
	return _solutions_cache


## Returns the verified optimal solution string for a given level (0-indexed).
static func get_solution_for_level(level_index: int) -> String:
	var dict: Dictionary = load_solutions()
	var key: String = str(level_index + 1)
	return dict.get(key, "")


## Precomputes and caches the states along the optimal solution path.
static func get_path_states(level_index: int, level_path: String) -> Array:
	if _path_states_cache.has(level_index):
		return _path_states_cache[level_index]

	var sol_str: String = get_solution_for_level(level_index)
	if sol_str.is_empty() or level_path.is_empty():
		return []

	var sim_grid: GridLogic = GridLogicScript.new()
	if not sim_grid.load_from_file(level_path):
		return []

	var states: Array = []
	for i in range(sol_str.length()):
		var enc: String = encode_state(sim_grid.player_pos, sim_grid.get_crates())
		var ch: String = sol_str.substr(i, 1)
		states.append({
			"enc": enc,
			"move": ch
		})
		var dir: Vector2i = Vector2i.ZERO
		match ch:
			"u": dir = Vector2i.UP
			"d": dir = Vector2i.DOWN
			"l": dir = Vector2i.LEFT
			"r": dir = Vector2i.RIGHT
		sim_grid.move(dir)

	_path_states_cache[level_index] = states
	return states


## Instantly returns the next optimal hint move character ("u", "d", "l", "r") if on the solution path, or "" otherwise.
static func get_next_hint(grid: GridLogic, level_index: int, level_path: String = "") -> String:
	if grid == null or grid.is_won():
		return ""

	if level_path.is_empty():
		level_path = "res://levels/level_%02d.sok" % (level_index + 1)

	var path_states: Array = get_path_states(level_index, level_path)
	if path_states.is_empty():
		return ""

	var current_enc: String = encode_state(grid.player_pos, grid.get_crates())
	for item in path_states:
		if item["enc"] == current_enc:
			return item["move"]

	return ""


## Checks if a position is impassable boundary (wall, out of bounds, or exterior void).
static func is_blocked_tile(pos: Vector2i, grid_or_walls: Variant, w: int = 0, h: int = 0) -> bool:
	if grid_or_walls is GridLogic:
		var grid: GridLogic = grid_or_walls
		return not grid.is_in_bounds(pos) or grid.is_wall(pos) or grid.is_exterior_void(pos)
	elif grid_or_walls is Dictionary:
		var walls: Dictionary = grid_or_walls
		return pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h or walls.has(pos)
	return true


## Checks if a crate at pos is in a fatal corner deadlock (not on a goal and blocked in 2 perpendicular wall directions).
static func is_corner_deadlock(pos: Vector2i, grid_or_walls: Variant, goals: Dictionary = {}, w: int = 0, h: int = 0) -> bool:
	if grid_or_walls is GridLogic:
		var grid: GridLogic = grid_or_walls
		if grid.is_goal(pos):
			return false
		var wall_u: bool = is_blocked_tile(pos + Vector2i.UP, grid)
		var wall_d: bool = is_blocked_tile(pos + Vector2i.DOWN, grid)
		var wall_l: bool = is_blocked_tile(pos + Vector2i.LEFT, grid)
		var wall_r: bool = is_blocked_tile(pos + Vector2i.RIGHT, grid)
		return (wall_u and wall_l) or (wall_u and wall_r) or (wall_d and wall_l) or (wall_d and wall_r)
	elif grid_or_walls is Dictionary:
		var walls: Dictionary = grid_or_walls
		if goals.has(pos):
			return false
		var wall_u: bool = is_blocked_tile(pos + Vector2i.UP, walls, w, h)
		var wall_d: bool = is_blocked_tile(pos + Vector2i.DOWN, walls, w, h)
		var wall_l: bool = is_blocked_tile(pos + Vector2i.LEFT, walls, w, h)
		var wall_r: bool = is_blocked_tile(pos + Vector2i.RIGHT, walls, w, h)
		return (wall_u and wall_l) or (wall_u and wall_r) or (wall_d and wall_l) or (wall_d and wall_r)
	return false


## Checks if placing a crate at pos creates an unresolvable 2x2 solid block of crates and walls.
static func is_2x2_deadlock(pos: Vector2i, grid_or_walls: Variant, moving_from_or_goals: Variant = null, cr_map: Dictionary = {}, moving_from_pos: Vector2i = Vector2i(-999, -999), w: int = 0, h: int = 0) -> bool:
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-1, -1)
	]
	if grid_or_walls is GridLogic:
		var grid: GridLogic = grid_or_walls
		var moving_from: Vector2i = moving_from_or_goals if moving_from_or_goals is Vector2i else Vector2i(-999, -999)
		for off in offsets:
			var c00: Vector2i = pos + off
			var cells: Array[Vector2i] = [c00, c00 + Vector2i(1, 0), c00 + Vector2i(0, 1), c00 + Vector2i(1, 1)]
			var all_solid: bool = true
			var has_non_goal: bool = false
			for c in cells:
				if is_blocked_tile(c, grid):
					continue
				var is_cr: bool = (c == pos) or (grid.has_crate(c) and c != moving_from)
				if is_cr:
					if not grid.is_goal(c):
						has_non_goal = true
				else:
					all_solid = false
					break
			if all_solid and has_non_goal:
				return true
		return false
	elif grid_or_walls is Dictionary:
		var walls: Dictionary = grid_or_walls
		var goals: Dictionary = moving_from_or_goals if moving_from_or_goals is Dictionary else {}
		for off in offsets:
			var c00: Vector2i = pos + off
			var cells: Array[Vector2i] = [c00, c00 + Vector2i(1, 0), c00 + Vector2i(0, 1), c00 + Vector2i(1, 1)]
			var all_solid: bool = true
			var has_non_goal: bool = false
			for c in cells:
				if is_blocked_tile(c, walls, w, h):
					continue
				var is_cr: bool = (c == pos) or (cr_map.has(c) and c != moving_from_pos)
				if is_cr:
					if not goals.has(c):
						has_non_goal = true
				else:
					all_solid = false
					break
			if all_solid and has_non_goal:
				return true
		return false
	return false


## Encodes a state (player_pos and crates list) into a unique string key.
static func encode_state(player_pos: Vector2i, crates: Array[Vector2i]) -> String:
	var sorted_crates: Array[Vector2i] = crates.duplicate()
	sorted_crates.sort_custom(func(a: Vector2i, b: Vector2i):
		if a.y == b.y: return a.x < b.x
		return a.y < b.y
	)
	var crate_parts: PackedStringArray = []
	for c in sorted_crates:
		crate_parts.append("%d,%d" % [c.x, c.y])
	return "%d,%d|%s" % [player_pos.x, player_pos.y, ";".join(crate_parts)]


## Solves a Sokoban level using optimized Breadth-First Search (BFS) to guarantee the shortest move sequence.
static func solve(level_text_or_grid: Variant, max_states: int = 50000) -> SolverResult:
	var start_time: int = Time.get_ticks_msec()
	var grid: GridLogic

	if level_text_or_grid is GridLogic:
		grid = level_text_or_grid.clone()
	elif level_text_or_grid is String:
		grid = GridLogicScript.new()
		if not grid.load_from_text(level_text_or_grid):
			var res: SolverResult = SolverResult.new()
			res.is_solvable = false
			return res
	else:
		var res: SolverResult = SolverResult.new()
		res.is_solvable = false
		return res

	var result: SolverResult = SolverResult.new()

	if grid.is_won():
		result.is_solvable = true
		result.moves = 0
		result.pushes = 0
		result.solution_str = ""
		result.time_ms = float(Time.get_ticks_msec() - start_time)
		return result

	# Quick check if initial state has immediate deadlock
	if grid.has_deadlock():
		result.is_solvable = false
		result.is_deadlock = true
		result.time_ms = float(Time.get_ticks_msec() - start_time)
		return result

	var walls: Dictionary = grid.walls
	var goals: Dictionary = grid.goals
	var w: int = grid.width
	var h: int = grid.height

	var queue: Array[Dictionary] = []
	var visited: Dictionary = {}

	var init_crates: Array[Vector2i] = grid.get_crates()
	visited[encode_state(grid.player_pos, init_crates)] = true
	queue.append({
		"p": grid.player_pos,
		"c": init_crates,
		"m": "",
		"push": 0
	})

	var directions: Array[Dictionary] = [
		{"d": Vector2i.UP, "ch": "u"},
		{"d": Vector2i.DOWN, "ch": "d"},
		{"d": Vector2i.LEFT, "ch": "l"},
		{"d": Vector2i.RIGHT, "ch": "r"}
	]

	var head: int = 0
	while head < queue.size():
		result.states_explored += 1
		if result.states_explored >= max_states:
			result.timed_out = true
			break

		var cur: Dictionary = queue[head]
		head += 1
		if head > 20000:
			queue = queue.slice(head)
			head = 0

		var p: Vector2i = cur["p"]
		var cr: Array[Vector2i] = cur["c"]
		var m: String = cur["m"]
		var push: int = cur["push"]

		# Fast crate lookup map
		var cr_map: Dictionary = {}
		for c in cr:
			cr_map[c] = true

		for d in directions:
			var dir: Vector2i = d["d"]
			var ch: String = d["ch"]
			var np: Vector2i = p + dir

			if is_blocked_tile(np, walls, w, h):
				continue

			var is_push: bool = cr_map.has(np)
			if is_push:
				var nnp: Vector2i = np + dir
				if is_blocked_tile(nnp, walls, w, h) or cr_map.has(nnp):
					continue
				if is_corner_deadlock(nnp, walls, goals, w, h):
					continue
				if is_2x2_deadlock(nnp, walls, goals, cr_map, np, w, h):
					continue

				var ncr: Array[Vector2i] = cr.duplicate()
				var idx: int = ncr.find(np)
				ncr[idx] = nnp

				# Check win condition
				var won: bool = true
				for c in ncr:
					if not goals.has(c):
						won = false
						break
				if won:
					result.is_solvable = true
					result.moves = m.length() + 1
					result.pushes = push + 1
					result.solution_str = m + ch
					result.time_ms = float(Time.get_ticks_msec() - start_time)
					return result

				var enc: String = encode_state(np, ncr)
				if not visited.has(enc):
					visited[enc] = true
					queue.append({
						"p": np,
						"c": ncr,
						"m": m + ch,
						"push": push + 1
					})
			else:
				var enc: String = encode_state(np, cr)
				if not visited.has(enc):
					visited[enc] = true
					queue.append({
						"p": np,
						"c": cr,
						"m": m + ch,
						"push": push
					})

	result.is_solvable = false
	if not result.timed_out:
		result.is_deadlock = true # Queue exhausted without finding any winning path
	result.time_ms = float(Time.get_ticks_msec() - start_time)
	return result
