class_name GridLogic
extends RefCounted

## Pure logic class for Sokoban grid mechanics in Pixel Porter (Godot 4).
## Implements the core gameplay rules from PRD Sections 4 and 5:
## - 4-directional turn-based movement (Up, Down, Left, Right), one tile per move.
## - Pushes crates one tile if the tile behind is empty floor or a goal.
## - Two crates cannot be pushed at once; crates cannot be pulled.
## - Walls and boundaries block movement.
## - Level is won when every crate sits on a goal tile.
## - Supports restart/reset and tracks move/push counts.

signal player_moved(from_pos: Vector2i, to_pos: Vector2i)
signal crate_pushed(from_pos: Vector2i, to_pos: Vector2i)
signal move_undone(player_pos: Vector2i, had_crate: bool, crate_from: Vector2i, crate_to: Vector2i)
signal level_won
signal level_reset

# Standard Sokoban characters:
# '#' = Wall
# ' ' = Floor / empty
# '.' = Goal
# '$' = Crate
# '*' = Crate on Goal
# '@' = Player
# '+' = Player on Goal

var width: int = 0
var height: int = 0

var player_pos: Vector2i = Vector2i.ZERO
var walls: Dictionary = {}   # Dictionary[Vector2i, bool]
var goals: Dictionary = {}   # Dictionary[Vector2i, bool]
var crates: Dictionary = {}  # Dictionary[Vector2i, bool]
var interior_floor: Dictionary = {} # Dictionary[Vector2i, bool] - Reachable playable floor

var moves_count: int = 0
var pushes_count: int = 0
var last_move_pushed_crate: bool = false
var history: Array[Dictionary] = []

# Snapshot of the initial state for level restart
var _initial_player_pos: Vector2i = Vector2i.ZERO
var _initial_crates: Dictionary = {}
var _raw_level_text: String = ""


func _init(level_text: String = "") -> void:
	if not level_text.is_empty():
		load_from_text(level_text)


## Clears all existing board state.
func clear() -> void:
	width = 0
	height = 0
	player_pos = Vector2i.ZERO
	walls.clear()
	goals.clear()
	crates.clear()
	interior_floor.clear()
	moves_count = 0
	pushes_count = 0
	last_move_pushed_crate = false
	history.clear()
	_initial_player_pos = Vector2i.ZERO
	_initial_crates.clear()
	_raw_level_text = ""


## Loads a level from standard Sokoban text format.
## Returns true on success, false if the level is invalid (e.g. no player or empty).
func load_from_text(level_text: String) -> bool:
	clear()
	_raw_level_text = level_text

	var normalized_text: String = level_text.replace("\r\n", "\n").replace("\r", "\n")
	var raw_lines: PackedStringArray = normalized_text.split("\n")

	# Collect map lines, skipping comment lines that start with ';'
	var map_lines: Array[String] = []
	for line in raw_lines:
		if line.begins_with(";"):
			continue
		map_lines.append(line)

	# Trim leading and trailing completely empty lines
	while not map_lines.is_empty() and map_lines[0].strip_edges().is_empty():
		map_lines.pop_front()
	while not map_lines.is_empty() and map_lines[map_lines.size() - 1].strip_edges().is_empty():
		map_lines.pop_back()

	if map_lines.is_empty():
		push_warning("GridLogic: Level text contains no map data.")
		return false

	height = map_lines.size()
	width = 0
	for line in map_lines:
		if line.length() > width:
			width = line.length()

	var found_player: bool = false

	for y in range(height):
		var line: String = map_lines[y]
		for x in range(line.length()):
			var char_code: String = line[x]
			var pos: Vector2i = Vector2i(x, y)

			match char_code:
				"#":
					walls[pos] = true
				".":
					goals[pos] = true
				"$":
					crates[pos] = true
				"*":
					crates[pos] = true
					goals[pos] = true
				"@":
					player_pos = pos
					found_player = true
				"+":
					player_pos = pos
					goals[pos] = true
					found_player = true
				" ", "-", "_":
					# Floor / empty space
					pass
				_:
					# Any unrecognized characters are treated as empty space
					pass

	if not found_player:
		push_warning("GridLogic: Level has no player starting position ('@' or '+').")
		return false

	_initial_player_pos = player_pos
	_initial_crates = crates.duplicate()
	moves_count = 0
	pushes_count = 0
	last_move_pushed_crate = false

	_compute_interior_floor()

	return true


## Computes playable interior floor cells via flood-fill from player, crates, and goals.
## Ensures non-square levels with exterior void are properly distinguished.
func _compute_interior_floor() -> void:
	interior_floor.clear()
	var queue: Array[Vector2i] = []
	if is_in_bounds(player_pos):
		queue.append(player_pos)
	for c in crates.keys():
		if not queue.has(c):
			queue.append(c)
	for g in goals.keys():
		if not queue.has(g):
			queue.append(g)

	for seed_pos in queue:
		interior_floor[seed_pos] = true

	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = cur + dir
			if is_in_bounds(nxt) and not is_wall(nxt) and not interior_floor.has(nxt):
				interior_floor[nxt] = true
				queue.append(nxt)


const LevelDataScript = preload("res://scripts/level_data.gd")

## Loads a level from a file containing standard Sokoban text.
## Falls back to embedded LevelData if file is not directly readable.
func load_from_file(file_path: String) -> bool:
	if FileAccess.file_exists(file_path):
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var text: String = file.get_as_text()
			if not text.is_empty():
				return load_from_text(text)

	# Fallback to embedded LevelData
	var regex: RegEx = RegEx.new()
	regex.compile("level_(\\d+)\\.sok")
	var result: RegExMatch = regex.search(file_path)
	if result:
		var lvl_num: int = result.get_string(1).to_int()
		var fallback_text: String = LevelDataScript.get_level_text(lvl_num)
		if not fallback_text.is_empty():
			return load_from_text(fallback_text)

	push_error("GridLogic: Failed to load level from file or fallback: %s" % file_path)
	return false


## Converts a direction variant into a normalized cardinal Vector2i.
## Supports Vector2i, Vector2, and direction strings ("up", "down", "left", "right", "u", "d", "l", "r", "w", "s", "a", "d").
static func parse_direction(direction: Variant) -> Vector2i:
	if direction is Vector2i:
		return direction
	elif direction is Vector2:
		return Vector2i(int(round(direction.x)), int(round(direction.y)))
	elif direction is String:
		var s: String = direction.strip_edges().to_lower()
		match s:
			"up", "u", "w":
				return Vector2i.UP
			"down", "d", "s":
				return Vector2i.DOWN
			"left", "l", "a":
				return Vector2i.LEFT
			"right", "r":
				return Vector2i.RIGHT
	return Vector2i.ZERO


## Attempts to move the player in the specified direction.
## Follows PRD rules:
## - 1 tile move per turn.
## - Moving into wall or out of bounds is blocked.
## - Moving into a crate pushes it if the tile behind is empty floor or goal.
## - Cannot push two crates at once. Crates cannot be pulled.
## Returns true if the move was successfully made, false if blocked.
func move(direction: Variant) -> bool:
	last_move_pushed_crate = false
	var dir: Vector2i = parse_direction(direction)

	if dir != Vector2i.UP and dir != Vector2i.DOWN and dir != Vector2i.LEFT and dir != Vector2i.RIGHT:
		return false

	var target_pos: Vector2i = player_pos + dir

	# Bounds, void and wall check for player destination
	if not is_in_bounds(target_pos) or is_wall(target_pos) or (not interior_floor.is_empty() and not is_interior_floor(target_pos)):
		return false

	var pushed: bool = false
	var c_from: Vector2i = Vector2i.ZERO
	var c_to: Vector2i = Vector2i.ZERO

	# Check if target tile has a crate
	if has_crate(target_pos):
		var behind_pos: Vector2i = target_pos + dir

		# Bounds, void and wall check for crate destination
		if not is_in_bounds(behind_pos) or is_wall(behind_pos) or (not interior_floor.is_empty() and not is_interior_floor(behind_pos)):
			return false

		# Rule: Two crates cannot be pushed at once
		if has_crate(behind_pos):
			return false

		# Push the crate
		crates.erase(target_pos)
		crates[behind_pos] = true
		pushes_count += 1
		last_move_pushed_crate = true
		pushed = true
		c_from = target_pos
		c_to = behind_pos
		crate_pushed.emit(target_pos, behind_pos)

	# Move the player
	var old_pos: Vector2i = player_pos
	player_pos = target_pos
	moves_count += 1

	history.append({
		"player_from": old_pos,
		"player_to": target_pos,
		"pushed_crate": pushed,
		"crate_from": c_from,
		"crate_to": c_to,
		"dir": dir
	})

	player_moved.emit(old_pos, target_pos)

	if is_won():
		level_won.emit()

	return true


## Returns true if there is at least one move in history to undo.
func can_undo() -> bool:
	return not history.is_empty()


## Undoes the last move, reverting player and crate positions, and updating counters.
## Returns true if a move was undone, false if history is empty.
func undo() -> bool:
	if history.is_empty():
		return false

	var entry: Dictionary = history.pop_back()
	var prev_player_pos: Vector2i = entry["player_from"]
	var had_crate: bool = entry["pushed_crate"]
	var c_from: Vector2i = entry.get("crate_from", Vector2i.ZERO)
	var c_to: Vector2i = entry.get("crate_to", Vector2i.ZERO)

	if had_crate:
		crates.erase(c_to)
		crates[c_from] = true
		pushes_count = max(0, pushes_count - 1)

	player_pos = prev_player_pos
	moves_count = max(0, moves_count - 1)
	last_move_pushed_crate = false

	move_undone.emit(player_pos, had_crate, c_from, c_to)
	return true


## Restarts the level back to its initial loaded state.
## Resets player position, crates, moves_count, and pushes_count.
func restart() -> void:
	player_pos = _initial_player_pos
	crates = _initial_crates.duplicate()
	moves_count = 0
	pushes_count = 0
	last_move_pushed_crate = false
	history.clear()
	level_reset.emit()


## Alias for restart().
func reset() -> void:
	restart()


## Reports whether the level is won according to PRD Section 4:
## "A level is complete when every crate sits on a goal tile."
func is_won() -> bool:
	if crates.is_empty():
		return false
	for crate_pos in crates.keys():
		if not is_goal(crate_pos):
			return false
	return true


## Returns true if the position is within the rectangular grid bounds.
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


## Returns true if the position is a wall tile.
func is_wall(pos: Vector2i) -> bool:
	return walls.has(pos)


## Returns true if the position is a goal tile.
func is_goal(pos: Vector2i) -> bool:
	return goals.has(pos)


## Returns true if a crate currently occupies this position.
func has_crate(pos: Vector2i) -> bool:
	return crates.has(pos)


## Returns true if the position is inside bounds, not a wall, not occupied by a crate or player.
func is_empty_tile(pos: Vector2i) -> bool:
	return is_in_bounds(pos) and not is_wall(pos) and not has_crate(pos) and pos != player_pos and (interior_floor.is_empty() or is_interior_floor(pos))


## Returns true if the position is an interior playable floor tile.
func is_interior_floor(pos: Vector2i) -> bool:
	return interior_floor.has(pos)


## Returns true if the position is exterior void (outside level boundary walls).
func is_exterior_void(pos: Vector2i) -> bool:
	return is_in_bounds(pos) and not is_wall(pos) and not is_interior_floor(pos)


## Returns the player's current position.
func get_player_pos() -> Vector2i:
	return player_pos


## Returns an Array of all crate positions.
func get_crates() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for pos in crates.keys():
		list.append(pos)
	return list


## Returns an Array of all goal positions.
func get_goals() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for pos in goals.keys():
		list.append(pos)
	return list


## Returns an Array of all wall positions.
func get_walls() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for pos in walls.keys():
		list.append(pos)
	return list


## Returns the total number of crates.
func get_crate_count() -> int:
	return crates.size()


## Returns the total number of goals.
func get_goal_count() -> int:
	return goals.size()


## Returns how many crates are currently resting on goal tiles.
func get_crates_on_goal_count() -> int:
	var count: int = 0
	for crate_pos in crates.keys():
		if is_goal(crate_pos):
			count += 1
	return count


## Executes a sequence of moves (either a String like "uurrddll" or Array of directions).
## Standard notation: 'u'=UP, 'd'=DOWN, 'l'=LEFT, 'r'=RIGHT (case-insensitive).
## Returns the number of successful moves executed.
func execute_moves(move_sequence: Variant) -> int:
	var success_count: int = 0
	if move_sequence is String:
		for i in range(move_sequence.length()):
			var char_move: String = move_sequence[i]
			var dir: Vector2i = Vector2i.ZERO
			match char_move.to_lower():
				"u": dir = Vector2i.UP
				"d": dir = Vector2i.DOWN
				"l": dir = Vector2i.LEFT
				"r": dir = Vector2i.RIGHT
				_: continue
			if move(dir):
				success_count += 1
	elif move_sequence is Array:
		for dir_item in move_sequence:
			if move(dir_item):
				success_count += 1
	return success_count


## Exports the current board state back to standard Sokoban ASCII format.
func to_text() -> String:
	var result_lines: PackedStringArray = []
	for y in range(height):
		var row_chars: PackedStringArray = []
		for x in range(width):
			var pos: Vector2i = Vector2i(x, y)
			var has_w: bool = walls.has(pos)
			var has_g: bool = goals.has(pos)
			var has_c: bool = crates.has(pos)
			var is_p: bool = (pos == player_pos)

			if has_w:
				row_chars.append("#")
			elif is_p and has_g:
				row_chars.append("+")
			elif is_p:
				row_chars.append("@")
			elif has_c and has_g:
				row_chars.append("*")
			elif has_c:
				row_chars.append("$")
			elif has_g:
				row_chars.append(".")
			else:
				row_chars.append(" ")
		result_lines.append("".join(row_chars).rstrip(" "))
	return "\n".join(result_lines)


## Returns true if any crate is trapped in an unresolvable corner deadlock or 2x2 block.
func has_deadlock() -> bool:
	for c in crates.keys():
		if is_goal(c):
			continue
		# Corner check
		var wall_u: bool = not is_in_bounds(c + Vector2i.UP) or is_wall(c + Vector2i.UP) or is_exterior_void(c + Vector2i.UP)
		var wall_d: bool = not is_in_bounds(c + Vector2i.DOWN) or is_wall(c + Vector2i.DOWN) or is_exterior_void(c + Vector2i.DOWN)
		var wall_l: bool = not is_in_bounds(c + Vector2i.LEFT) or is_wall(c + Vector2i.LEFT) or is_exterior_void(c + Vector2i.LEFT)
		var wall_r: bool = not is_in_bounds(c + Vector2i.RIGHT) or is_wall(c + Vector2i.RIGHT) or is_exterior_void(c + Vector2i.RIGHT)
		if (wall_u and wall_l) or (wall_u and wall_r) or (wall_d and wall_l) or (wall_d and wall_r):
			return true

		# 2x2 block check
		var offsets: Array[Vector2i] = [
			Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)
		]
		for off in offsets:
			var c00: Vector2i = c + off
			var cells: Array[Vector2i] = [c00, c00 + Vector2i(1, 0), c00 + Vector2i(0, 1), c00 + Vector2i(1, 1)]
			var all_solid: bool = true
			var has_non_goal: bool = false
			for cell in cells:
				var is_b: bool = not is_in_bounds(cell) or is_wall(cell) or is_exterior_void(cell)
				if is_b:
					continue
				if has_crate(cell):
					if not is_goal(cell):
						has_non_goal = true
				else:
					all_solid = false
					break
			if all_solid and has_non_goal:
				return true
	return false


## Creates an independent clone of the current GridLogic instance.
func clone() -> RefCounted:
	var copy = (get_script() as GDScript).new()
	copy.width = width
	copy.height = height
	copy.player_pos = player_pos
	copy.walls = walls.duplicate()
	copy.goals = goals.duplicate()
	copy.crates = crates.duplicate()
	copy.moves_count = moves_count
	copy.pushes_count = pushes_count
	copy.last_move_pushed_crate = last_move_pushed_crate
	copy.interior_floor = interior_floor.duplicate()
	copy._initial_player_pos = _initial_player_pos
	copy._initial_crates = _initial_crates.duplicate()
	copy._raw_level_text = _raw_level_text
	return copy
