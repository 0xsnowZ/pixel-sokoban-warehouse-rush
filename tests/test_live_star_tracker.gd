extends SceneTree

# ==============================================================================
# Pixel Porter - Option C: Live HUD 3★ Tracker & Worker Micro-Interactions Test Suite
# Tests:
#   1. StarGauge label presence & default '★★★' state
#   2. Dynamic real-time star degradation (★★★ -> ★★☆ -> ★☆☆)
#   3. Undo restoration of lost stars
#   4. Worker idle time accumulation & reset on locomotion
#   5. Consecutive wall bump sweat drop trigger (3 bumps = sweat drop)
#   6. Sweat drop timer decay & manual trigger
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
	print("  Pixel Porter - Option C Live Star & Worker Tests    ")
	print("======================================================\n")

	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node = game_scene.instantiate()
	root.add_child(game)
	game._ready()
	game.load_level(0)

	test_star_gauge_initialization(game)
	test_star_degradation_and_undo(game)
	test_worker_idle_simulation(game)
	test_wall_bump_sweat_drop(game)

	print("\n======================================================")
	print("Option C Results: %d passed, %d failed" % [passed_count, failed_count])
	print("======================================================\n")

	game.queue_free()
	if failed_count > 0:
		quit(1)
	else:
		print("SUCCESS: All live star tracker & worker tests passed!\n")
		quit(0)


func test_star_gauge_initialization(game: Node) -> void:
	print("--- Running Suite: Star Gauge HUD Initialization ---")
	assert_true(game.star_gauge != null, "StarGauge label initialized in TopBar")
	assert_true(game.star_gauge.text == "★★★", "Initial star gauge displays '★★★' (got %s)" % game.star_gauge.text)
	assert_true(game._prev_live_stars == 3, "Initial live star count is 3")


func test_star_degradation_and_undo(game: Node) -> void:
	print("--- Running Suite: Live Star Degradation & Undo Restoration ---")
	var targets: Dictionary = game.save_mgr.get_star_targets(0)
	var s3: int = targets.get("three_star", targets.get("star_3", 14))
	var s2: int = targets.get("two_star", targets.get("star_2", 21))

	# Move until exceeding s3
	while game.grid.moves_count <= s3:
		# Alternate moves between UP/DOWN or valid spaces
		if not game.grid.move(Vector2i.DOWN):
			game.grid.move(Vector2i.UP)

	game._update_ui()
	assert_true(game.star_gauge.text == "★★☆", "Star gauge degrades to '★★☆' when moves exceed 3-star target (%d moves > %d target)" % [game.grid.moves_count, s3])
	assert_true(game._prev_live_stars == 2, "Live stars internal tracking updated to 2")

	# Move until exceeding s2
	while game.grid.moves_count <= s2:
		if not game.grid.move(Vector2i.DOWN):
			game.grid.move(Vector2i.UP)

	game._update_ui()
	assert_true(game.star_gauge.text == "★☆☆", "Star gauge degrades to '★☆☆' when moves exceed 2-star target (%d moves > %d target)" % [game.grid.moves_count, s2])
	assert_true(game._prev_live_stars == 1, "Live stars internal tracking updated to 1")

	# Undo back until moves <= s3
	while game.grid.moves_count > s3:
		game.grid.undo()

	game._update_ui()
	assert_true(game.star_gauge.text == "★★★", "Undo restored star gauge back to '★★★' (moves = %d <= %d)" % [game.grid.moves_count, s3])
	assert_true(game._prev_live_stars == 3, "Live stars restored to 3")


func test_worker_idle_simulation(game: Node) -> void:
	print("--- Running Suite: Worker Idle Time & Locomotion Reset ---")
	game.load_level(0)
	assert_true("player_idle_time" in game, "Game scene defines player_idle_time")
	game.player_idle_time = 0.0
	game.is_animating = false

	game._process(3.0)
	assert_true(game.player_idle_time >= 3.0, "Player idle time accumulated during wait (got %f)" % game.player_idle_time)

	# Locomotion resets idle time
	game.grid.move(Vector2i.DOWN)
	assert_true(game.player_idle_time == 0.0, "Locomotion step resets player_idle_time to 0.0")


func test_wall_bump_sweat_drop(game: Node) -> void:
	print("--- Running Suite: Wall Bump Sweat Drop Trigger ---")
	game.load_level(0)
	assert_true("consecutive_wall_bumps" in game, "Game defines consecutive_wall_bumps")
	assert_true("sweat_drop_timer" in game, "Game defines sweat_drop_timer")

	game.consecutive_wall_bumps = 0
	game.sweat_drop_timer = 0.0
	game.is_animating = false

	# 1st bump into wall
	game._trigger_bump_recoil(Vector2i.UP)
	assert_true(game.consecutive_wall_bumps == 1, "First wall bump increments counter to 1")
	assert_true(game.sweat_drop_timer == 0.0, "No sweat drop on 1st bump")

	# 2nd bump
	game._trigger_bump_recoil(Vector2i.UP)
	assert_true(game.consecutive_wall_bumps == 2, "Second wall bump increments counter to 2")
	assert_true(game.sweat_drop_timer == 0.0, "No sweat drop on 2nd bump")

	# 3rd bump -> triggers sweat drop!
	game._trigger_bump_recoil(Vector2i.UP)
	assert_true(game.consecutive_wall_bumps == 3, "Third wall bump reaches threshold 3")
	assert_true(game.sweat_drop_timer > 1.0, "Sweat drop triggered on 3rd bump (timer = %f)" % game.sweat_drop_timer)

	# Process decay
	game._process(0.5)
	assert_true(game.sweat_drop_timer < 1.0, "Sweat drop timer decays over time (got %f)" % game.sweat_drop_timer)

	# Locomotion clears bumps counter
	game.grid.move(Vector2i.DOWN)
	assert_true(game.consecutive_wall_bumps == 0, "Moving clears consecutive_wall_bumps counter to 0")
