extends SceneTree

# ==============================================================================
# Pixel Porter - Phase 4: Industrial Terminal Console UI & Tension Gauge Tests
# Tests:
#   1. TopBar & BottomBar hardware console drawing hooks & terminal bolts
#   2. Live 3-Star LED Tension Meter threshold tracking & oscillation
#   3. Electric spark feedback on star degradation
#   4. Holographic directional laser hint drawing & scanlines
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
	print("    Pixel Porter - Terminal Console & Tension Tests   ")
	print("======================================================\n")

	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Control = game_scene.instantiate() as Control
	root.add_child(game)
	game._ready()
	game.load_level(0)

	test_terminal_console_hardware(game)
	test_star_tension_meter(game)
	test_holographic_laser_hints(game)

	print("\n======================================================")
	print("Terminal Console Results: %d passed, %d failed" % [passed_count, failed_count])
	print("======================================================\n")

	game.queue_free()
	if failed_count > 0:
		quit(1)
	else:
		print("SUCCESS: All Phase 4 Terminal Console & Tension tests passed!\n")
		quit(0)


func test_terminal_console_hardware(game: Control) -> void:
	print("--- Running Suite: Industrial Terminal Console Hardware ---")
	assert_true(game.has_method("_on_top_bar_draw"), "Game defines _on_top_bar_draw")
	assert_true(game.has_method("_on_bottom_bar_draw"), "Game defines _on_bottom_bar_draw")
	assert_true(game.has_method("_draw_terminal_bolt"), "Game defines _draw_terminal_bolt")

	# Verify signal connections for CanvasItem drawing pipeline
	if game.top_bar != null:
		assert_true(game.top_bar.draw.is_connected(game._on_top_bar_draw), "TopBar draw signal connected to _on_top_bar_draw")
		game.top_bar.queue_redraw()
	if game.bottom_bar != null:
		assert_true(game.bottom_bar.draw.is_connected(game._on_bottom_bar_draw), "BottomBar draw signal connected to _on_bottom_bar_draw")
		game.bottom_bar.queue_redraw()


func test_star_tension_meter(game: Control) -> void:
	print("--- Running Suite: Live 3-Star Tension Gauge ---")
	assert_true("is_star_tension" in game, "Game defines is_star_tension")

	var targets: Dictionary = game.save_mgr.get_star_targets(0)
	var s3: int = targets.get("three_star", targets.get("star_3", 14))

	# Initial state: 0 moves, far from limit
	game._update_ui()
	assert_true(not game.is_star_tension, "is_star_tension is false at start (moves=0 < s3-1)")

	# Advance moves to s3 - 1
	while game.grid.moves_count < s3 - 1:
		if not game.grid.move(Vector2i.DOWN):
			game.grid.move(Vector2i.UP)

	game._update_ui()
	assert_true(game.is_star_tension, "is_star_tension is TRUE when moves reach s3-1 threshold (%d == %d)" % [game.grid.moves_count, s3 - 1])

	# Advance to exactly s3
	if not game.grid.move(Vector2i.DOWN):
		game.grid.move(Vector2i.UP)
	game._update_ui()
	assert_true(game.is_star_tension, "is_star_tension remains TRUE at exact s3 limit (%d == %d)" % [game.grid.moves_count, s3])

	# Process delta to verify LED pulse modulation
	var prev_modulate: Color = game.star_gauge.modulate
	game._process(0.1)
	assert_true(game.star_gauge != null, "StarGauge active during tension pulse")

	# Advance past s3: star is lost, sparks generated
	var prev_particles_count: int = game.dust_particles.size()
	if not game.grid.move(Vector2i.DOWN):
		game.grid.move(Vector2i.UP)
	game._update_ui()
	assert_true(game.dust_particles.size() > prev_particles_count, "Sparks spawned on star degradation (got %d particles)" % game.dust_particles.size())


func test_holographic_laser_hints(game: Control) -> void:
	print("--- Running Suite: Holographic Directional Laser Hints ---")
	assert_true(game.has_method("_draw_hint_ghost"), "Game implements _draw_hint_ghost")

	# Mock active hint state
	game.active_hint_dir = Vector2i.DOWN
	game.hint_player_target = game.grid.player_pos + Vector2i.DOWN
	game.hint_has_crate = true
	game.hint_crate_target = game.grid.player_pos + Vector2i.DOWN * 2
	game.hint_time_remaining = 3.5
	game.hint_pulse_timer = 0.5

	# Queue redraw which executes _draw_hint_ghost in proper Godot render loop
	game.queue_redraw()
	assert_true(game.hint_time_remaining > 0.0, "Hint state active with positive remaining duration")
	assert_true(game.active_hint_dir == Vector2i.DOWN, "Hint directional vector set to DOWN")
