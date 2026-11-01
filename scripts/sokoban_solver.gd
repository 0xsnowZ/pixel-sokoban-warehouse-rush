class_name SokobanSolver
extends RefCounted

## Automated BFS solver and deadlock analyzer for Pixel Porter levels.
## Implements PRD Section 7 offline verification pipeline:
## - Finds the shortest path solution (minimum moves / pushes).
## - Prunes corner deadlocks and unpushable states.
## - Returns solvability status, minimum moves, minimum pushes, and solution string.

const GridLogicScript = preload("res://scripts/grid_logic.gd")

class SolverResult:
	var is_solvable: bool = false
	var moves: int = 0
	var pushes: int = 0
	var solution_str: String = "" # e.g. "uurrddll"
	var states_explored: int = 0
	var time_ms: float = 0.0

	func _to_string() -> String:
		if is_solvable:
			return "SOLVABLE: %d moves, %d pushes (Explored %d states in %.2fms)" % [moves, pushes, states_explored, time_ms]
		return "UNSOLVABLE or TIMED OUT (Explored %d states in %.2fms)" % [states_explored, time_ms]


## Checks if a position is impassable boundary (wall, out of bounds, or exterior void).
static func is_blocked_tile(pos: Vector2i, grid: GridLogic) -> bool:
	return not grid.is_in_bounds(pos) or grid.is_wall(pos) or grid.is_exterior_void(pos)


## Checks if a crate at pos is in a fatal corner deadlock (not on a goal and blocked in 2 perpendicular wall directions).
static func is_corner_deadlock(pos: Vector2i, grid: GridLogic) -> bool:
	if grid.is_goal(pos):
		return false # Crates on goals are allowed in corners

	var wall_up: bool = is_blocked_tile(pos + Vector2i.UP, grid)
	var wall_down: bool = is_blocked_tile(pos + Vector2i.DOWN, grid)
	var wall_left: bool = is_blocked_tile(pos + Vector2i.LEFT, grid)
	var wall_right: bool = is_blocked_tile(pos + Vector2i.RIGHT, grid)

	if (wall_up and wall_left) or (wall_up and wall_right) or (wall_down and wall_left) or (wall_down and wall_right):
		return true

	return false


## Checks if placing a crate at pos creates an unresolvable 2x2 solid block of crates and walls.
static func is_2x2_deadlock(pos: Vector2i, grid: GridLogic, moving_from_pos: Vector2i) -> bool:
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-1, -1)
	]

	for off in offsets:
		var c00: Vector2i = pos + off
		var cells: Array[Vector2i] = [
			c00,
			c00 + Vector2i(1, 0),
			c00 + Vector2i(0, 1),
			c00 + Vector2i(1, 1)
		]

		var all_solid: bool = true
		var has_non_goal_crate: bool = false

		for c in cells:
			if is_blocked_tile(c, grid):
				continue
			var is_crate_here: bool = (c == pos) or (grid.has_crate(c) and c != moving_from_pos)
			if is_crate_here:
				if not grid.is_goal(c):
					has_non_goal_crate = true
			else:
				all_solid = false
				break

		if all_solid and has_non_goal_crate:
			return true

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


## Solves a Sokoban level using Breadth-First Search (BFS) to guarantee the shortest move sequence.
static func solve(level_text_or_grid: Variant, max_states: int = 50000) -> SolverResult:
	var start_time: int = Time.get_ticks_msec()
	var grid: GridLogic

	if level_text_or_grid is GridLogic:
		grid = level_text_or_grid.clone()
	elif level_text_or_grid is String:
		grid = GridLogicScript.new()
		if not grid.load_from_text(level_text_or_grid):
			var res = SolverResult.new()
			res.is_solvable = false
			return res
	else:
		var res = SolverResult.new()
		res.is_solvable = false
		return res

	var result = SolverResult.new()

	if grid.is_won():
		result.is_solvable = true
		result.moves = 0
		result.pushes = 0
		result.solution_str = ""
		result.time_ms = float(Time.get_ticks_msec() - start_time)
		return result

	# BFS Queue stores: Dictionary { "grid": GridLogic, "moves": String, "pushes": int }
	var queue: Array[Dictionary] = []
	var visited: Dictionary = {} # String(encoded_state) -> bool

	var initial_state: String = encode_state(grid.player_pos, grid.get_crates())
	visited[initial_state] = true

	queue.append({
		"grid": grid,
		"moves": "",
		"pushes": 0
	})

	var directions: Array[Dictionary] = [
		{"dir": Vector2i.UP, "char": "u"},
		{"dir": Vector2i.DOWN, "char": "d"},
		{"dir": Vector2i.LEFT, "char": "l"},
		{"dir": Vector2i.RIGHT, "char": "r"}
	]

	var queue_head: int = 0
	while queue_head < queue.size():
		result.states_explored += 1
		if result.states_explored >= max_states:
			break # State space limit reached to prevent infinite loops

		var current: Dictionary = queue[queue_head]
		queue_head += 1
		if queue_head > 25000:
			queue = queue.slice(queue_head)
			queue_head = 0
		var cur_grid: GridLogic = current["grid"]
		var cur_moves: String = current["moves"]
		var cur_pushes: int = current["pushes"]

		for d_info in directions:
			var dir: Vector2i = d_info["dir"]
			var move_char: String = d_info["char"]

			var target_pos: Vector2i = cur_grid.player_pos + dir
			if not cur_grid.is_in_bounds(target_pos) or cur_grid.is_wall(target_pos):
				continue

			var is_push: bool = cur_grid.has_crate(target_pos)
			if is_push:
				var behind_pos: Vector2i = target_pos + dir
				if not cur_grid.is_in_bounds(behind_pos) or cur_grid.is_wall(behind_pos) or cur_grid.has_crate(behind_pos):
					continue
				# Deadlock checks: corner and 2x2 block deadlocks
				if is_corner_deadlock(behind_pos, cur_grid):
					continue
				if is_2x2_deadlock(behind_pos, cur_grid, target_pos):
					continue

			# Clone state and execute move
			var next_grid: GridLogic = cur_grid.clone()
			next_grid.move(dir)

			if next_grid.is_won():
				result.is_solvable = true
				result.moves = cur_moves.length() + 1
				result.pushes = cur_pushes + (1 if is_push else 0)
				result.solution_str = cur_moves + move_char
				result.time_ms = float(Time.get_ticks_msec() - start_time)
				return result

			var next_encoded: String = encode_state(next_grid.player_pos, next_grid.get_crates())
			if not visited.has(next_encoded):
				visited[next_encoded] = true
				queue.append({
					"grid": next_grid,
					"moves": cur_moves + move_char,
					"pushes": cur_pushes + (1 if is_push else 0)
				})

	result.is_solvable = false
	result.time_ms = float(Time.get_ticks_msec() - start_time)
	return result
