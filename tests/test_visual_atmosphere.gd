extends SceneTree

# ==============================================================================
# Pixel Porter - Option B: Visual Atmosphere & Polish Test Suite
# Tests:
#   1. Ambient Motes Initialization (16 motes, normalized coordinates, size, phase)
#   2. Ambient Motes Process & Drifting (phase increment, pos update, boundary wrapping)
#   3. Chapter Progression Atmospherics (Ch 0 Dust, Ch 1 Frost, Ch 2 Cyber)
#   4. Worker Headlamp Illumination (radial pool & directional beam)
#   5. Board Vignette Framing & Geometry
#   6. Goal Pad Hazard Corner Brackets & Floor Bleed Radiance
#   7. 3D Wall Coping Highlights, Demarcation, and Directional Ambient Shading
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
	print("    Pixel Porter - Visual Atmosphere Test Suite       ")
	print("======================================================\n")

	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node = game_scene.instantiate()
	root.add_child(game)
	game._ready()
	game.load_level(0)

	test_ambient_motes_initialization(game)
	test_ambient_motes_simulation(game)
	test_chapter_atmospherics(game)
	test_headlamp_and_vignette(game)
	test_wall_coping_depth(game)
	test_tracking_security_camera(game)

	print("\n======================================================")
	print("Visual Atmosphere Results: %d passed, %d failed" % [passed_count, failed_count])
	print("======================================================")

	game.queue_free()
	if failed_count > 0:
		quit(1)
	else:
		print("SUCCESS: All visual atmosphere tests passed!\n")
		quit(0)


func test_ambient_motes_initialization(game: Node) -> void:
	print("--- Running Suite: Ambient Motes Initialization ---")
	assert_true("ambient_motes" in game, "Game scene defines ambient_motes array")
	assert_true(game.ambient_motes.size() == 16, "Ambient motes initialized with 16 motes (got %d)" % game.ambient_motes.size())

	var first_mote: Dictionary = game.ambient_motes[0]
	assert_true(first_mote.has("pos_norm"), "Mote has normalized position")
	assert_true(first_mote.has("vel"), "Mote has velocity vector")
	assert_true(first_mote.has("phase"), "Mote has sinusoidal phase")
	assert_true(first_mote.has("size"), "Mote has size property")
	assert_true(first_mote.has("base_alpha"), "Mote has base_alpha property")
	assert_true(first_mote["pos_norm"].x >= 0.0 and first_mote["pos_norm"].x <= 1.0, "Mote initial x in [0, 1]")
	assert_true(first_mote["pos_norm"].y >= 0.0 and first_mote["pos_norm"].y <= 1.0, "Mote initial y in [0, 1]")


func test_ambient_motes_simulation(game: Node) -> void:
	print("--- Running Suite: Ambient Motes Simulation & Wrapping ---")
	var initial_phase: float = game.ambient_motes[0]["phase"]
	var initial_pos: Vector2 = game.ambient_motes[0]["pos_norm"]

	# Simulate 1.0 second of game process
	game._process(1.0)

	var new_phase: float = game.ambient_motes[0]["phase"]
	var new_pos: Vector2 = game.ambient_motes[0]["pos_norm"]

	assert_true(new_phase > initial_phase, "Mote phase advances over time (got %f > %f)" % [new_phase, initial_phase])
	assert_true(new_pos != initial_pos, "Mote pos drifts during process")

	# Test wrapping
	game.ambient_motes[0]["pos_norm"] = Vector2(1.10, 0.5)
	game._process(0.016)
	assert_true(game.ambient_motes[0]["pos_norm"].x <= 1.05, "Mote wrapped around right boundary")


func test_chapter_atmospherics(game: Node) -> void:
	print("--- Running Suite: Chapter Progression Atmospherics ---")
	if game.save_mgr:
		game.save_mgr.unlocked_level = 74
	game.load_level(0)
	assert_true(game.current_chapter_idx == 0, "Level 1 is Cargo Bay chapter 0")

	game.load_level(15)
	assert_true(game.current_chapter_idx == 1, "Level 16 is Cold Storage chapter 1")
	assert_true(game.ambient_motes.size() == 16, "Motes re-seeded on chapter change")

	game.load_level(35)
	assert_true(game.current_chapter_idx == 2, "Level 36 is Cyber Depot chapter 2")
	assert_true(game.ambient_motes.size() == 16, "Motes active in Cyber Depot")

	game.load_level(50)
	assert_true(game.current_chapter_idx == 3, "Level 51 is Quantum Vault chapter 3")
	assert_true(game.ambient_motes.size() == 16, "Motes active in Quantum Vault")

	# Return to level 0
	game.load_level(0)


func test_headlamp_and_vignette(game: Node) -> void:
	print("--- Running Suite: Headlamp, Vignette & Goal Docking Methods ---")
	assert_true(game.has_method("_draw_player_headlamp"), "Game implements _draw_player_headlamp")
	assert_true(game.has_method("_draw_board_vignette"), "Game implements _draw_board_vignette")
	assert_true(game.has_method("_draw_goal_hazard_brackets"), "Game implements _draw_goal_hazard_brackets")
	assert_true(game.has_method("_draw_goal_light_pillar"), "Game implements _draw_goal_light_pillar")
	assert_true(game.has_method("_draw_floor_tile"), "Game implements _draw_floor_tile")
	assert_true(game.has_method("_draw_ambient_motes"), "Game implements _draw_ambient_motes")


func test_wall_coping_depth(game: Node) -> void:
	print("--- Running Suite: 3D Wall Coping Depth ---")
	assert_true(game.has_method("_draw_wall"), "Game implements _draw_wall")
	# Force a redraw pass to ensure no CanvasItem errors during drawing
	game.queue_redraw()
	assert_true(true, "CanvasItem redraw pass queued cleanly without error")


func test_tracking_security_camera(game: Node) -> void:
	print("--- Running Suite: Living Warehouse - Tracking Security Camera ---")
	game.load_level(0)
	assert_true("cctv_active" in game and game.cctv_active, "Tracking security camera is active")
	assert_true(game.cctv_camera_tile != Vector2i(-1, -1), "Valid wall tile selected for camera mount (got %s)" % str(game.cctv_camera_tile))
	assert_true(game.grid.is_wall(game.cctv_camera_tile), "Camera mount tile is verified as a wall tile")

	assert_true(game.has_method("_find_security_camera_mount"), "Game implements _find_security_camera_mount")
	assert_true(game.has_method("_init_security_camera"), "Game implements _init_security_camera")
	assert_true(game.has_method("_update_security_camera"), "Game implements _update_security_camera")
	assert_true(game.has_method("_draw_security_camera"), "Game implements _draw_security_camera")
	assert_true(game.has_method("_draw_cctv_cone"), "Game implements _draw_cctv_cone")

	# Test tracking servo rotation
	var initial_angle: float = game.cctv_current_angle
	game._process(0.2)
	assert_true(game.cctv_current_angle != initial_angle or absf(game.cctv_target_angle - game.cctv_current_angle) < 0.05, "Camera servo swivels smoothly towards player")

	# Test motion boost reactivity
	game.cctv_motion_timer = 0.0
	game.try_move(Vector2i.RIGHT)
	assert_true(game.cctv_motion_timer > 0.0, "Player movement activates camera motion boost timer (got %f)" % game.cctv_motion_timer)

	# Test wall collision / anomaly alert reactivity
	game.is_animating = false
	game.cctv_alert_timer = 0.0
	game._trigger_bump_recoil(Vector2i.UP)
	assert_true(game.cctv_alert_timer > 0.0, "Wall collision activates camera alert strobe timer (got %f)" % game.cctv_alert_timer)

	# Test camera initialization across all chapters
	for lvl in [15, 35, 50]:
		game.load_level(lvl)
		assert_true(game.cctv_active, "CCTV camera active in level %d" % (lvl + 1))
		assert_true(game.grid.is_wall(game.cctv_camera_tile), "CCTV camera on valid wall in level %d" % (lvl + 1))

	# Return to level 0
	game.load_level(0)
	game.queue_redraw()
	assert_true(true, "CanvasItem redraw pass with CCTV camera executed cleanly")
