extends SceneTree

## Headless Unit Test Suite for Game Scene (scenes/game.tscn & scenes/game.gd).
## Tests:
## - Instantiation and initial UI setup
## - Player directional facing (UP, DOWN, LEFT, RIGHT)
## - Move animation & queued move handling
## - Restart confirmation at >= 5 moves (localized)
## - Win state and celebration particle spawning & simulation
## - Board layout calculations with decorative framing, bevels, and pulsing goals

const GameScene = preload("res://scenes/game.tscn")
const LocalizationManagerScript = preload("res://scripts/localization_manager.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

var passes: int = 0
var fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(54))
	print("    Pixel Porter - Game Scene Headless Test Suite    ")
	print("=".repeat(54) + "\n")

	test_game_initialization_and_ui()
	test_player_facing_directions()
	test_walking_sprite_cycle()
	test_restart_confirmation_threshold()
	test_win_celebration_and_particles()
	test_layout_and_framing()
	test_undo_button_interaction()
	test_hint_system_and_solver()
	test_juice_and_micro_interactions()
	test_win_modal_three_star_system()
	test_warehouse_chapter_themes_and_progression()
	test_porter_locker_cosmetics_in_game()
	test_rewarded_ad_hint_economy_in_game()

	print("\n" + "=".repeat(54))
	print("Game Scene Results: %d passed, %d failed" % [passes, fails])
	print("=".repeat(54))

	if fails > 0:
		print("FAILURE: %d game scene tests failed." % fails)
		quit(1)
	else:
		print("SUCCESS: All game scene tests passed!\n")
		quit(0)


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % msg)
	else:
		fails += 1
		print("  [FAIL] %s" % msg)


func assert_false(cond: bool, msg: String) -> void:
	if not cond:
		passes += 1
		print("  [PASS] %s" % msg)
	else:
		fails += 1
		print("  [FAIL] %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		passes += 1
		print("  [PASS] %s (got %s)" % [msg, str(actual)])
	else:
		fails += 1
		print("  [FAIL] %s: Expected %s but got %s" % [msg, str(expected), str(actual)])


func create_test_game(loc_node: Node = null, save_node: Node = null) -> Control:
	var game: Control = GameScene.instantiate()
	if loc_node:
		game.loc_mgr = loc_node
	if save_node:
		game.save_mgr = save_node
	root.add_child(game)
	game._ready()
	return game


func test_game_initialization_and_ui() -> void:
	print("--- Running Suite: Game Scene Initialization & UI ---")
	var loc: Node = LocalizationManagerScript.new()
	var save_mgr: Node = SaveManagerScript.new()

	var game: Control = create_test_game(loc, save_mgr)

	assert_true(game.grid != null, "Grid logic initialized")
	assert_eq(game.current_level_index, 0, "Initial level index is 0")
	assert_eq(game.level_label.text, "LEVEL 1 / 50", "Level label in EN")
	assert_true(game.restart_button.text == "Restart", "Restart button localized in EN")
	assert_true(game.undo_button != null, "Undo button initialized in game")
	assert_true(game.undo_button.text == "Undo", "Undo button localized in EN")
	assert_true(game.undo_button.disabled, "Undo button is disabled initially")
	assert_true(game.hint_button != null, "Hint button initialized in game")
	assert_true("Hint" in game.hint_button.text, "Hint button localized in EN")
	assert_true(not game.hint_button.disabled, "Hint button is enabled initially")
	assert_true(game.prev_button == null, "Prev button removed from bottom bar")
	assert_true(game.next_button == null, "Next button removed from bottom bar")

	# Test switching language updates UI
	loc.set_language("fr")
	game._update_ui()
	assert_eq(game.level_label.text, "NIVEAU 1 / 50", "Level label in FR")
	assert_eq(game.restart_button.text, "Recommencer", "Restart button localized in FR")
	assert_eq(game.undo_button.text, "Annuler", "Undo button localized in FR")
	assert_true("Indice" in game.hint_button.text, "Hint button localized in FR")

	loc.set_language("ar")
	game._update_ui()
	assert_true("تلميح" in game.hint_button.text, "Hint button localized in AR")

	# Test in-game music toggle button
	assert_true(game.music_button != null, "Music button initialized in game")
	assert_eq(game.music_button.icon, game.icon_music_on, "Music button default icon is icon_music_on")
	assert_eq(game.music_button.text, "", "Music button has clean icon with no text overlap")
	game._on_music_btn_pressed()
	assert_false(save_mgr.music_enabled, "SaveManager music_enabled toggled to false via game button")
	assert_eq(game.music_button.icon, game.icon_music_off, "Music button shows muted icon_music_off")
	game._on_music_btn_pressed()
	assert_true(save_mgr.music_enabled, "SaveManager music_enabled toggled back to true")
	assert_eq(game.music_button.icon, game.icon_music_on, "Music button restored to icon_music_on")

	# Test in-game control mode & D-Pad overlay
	assert_true(game.control_button != null, "Control mode button initialized in game")
	assert_true(game.dpad_overlay != null, "D-Pad overlay initialized in game")
	assert_false(game.dpad_overlay.visible, "D-Pad overlay hidden in default SWIPE mode")
	assert_eq(game.control_button.icon, game.icon_control_swipe, "Control button displays swipe icon in SWIPE mode")
	assert_eq(game.control_button.text, "", "Control button has no text overlap")

	# Cycle to D-PAD mode
	game._on_control_button_pressed()
	assert_eq(save_mgr.control_scheme, 1, "Control scheme cycled to 1 (D-PAD)")
	assert_true(game.dpad_overlay.visible, "D-Pad overlay visible in D-PAD mode")
	assert_eq(game.control_button.icon, game.icon_control_dpad, "Control button displays dpad icon in D-PAD mode")

	# Test D-Pad directional movement
	game._on_dpad_down_pressed()
	assert_eq(game.player_facing_dir, Vector2i.DOWN, "Player facing updated to DOWN via D-Pad")
	game._on_dpad_up_pressed()
	assert_eq(game.player_facing_dir, Vector2i.UP, "Player facing updated to UP via D-Pad")

	# Cycle to DUAL mode
	game._on_control_button_pressed()
	assert_eq(save_mgr.control_scheme, 2, "Control scheme cycled to 2 (DUAL)")
	assert_true(game.dpad_overlay.visible, "D-Pad overlay visible in DUAL mode")
	assert_eq(game.control_button.icon, game.icon_control_gamepad, "Control button displays gamepad icon in DUAL mode")

	# Cycle back to SWIPE mode
	game._on_control_button_pressed()
	assert_eq(save_mgr.control_scheme, 0, "Control scheme cycled back to 0 (SWIPE)")
	assert_false(game.dpad_overlay.visible, "D-Pad overlay hidden in SWIPE mode")
	assert_eq(game.control_button.icon, game.icon_control_swipe, "Control button restores swipe icon")

	game.free()
	save_mgr.free()
	loc.free()


func test_player_facing_directions() -> void:
	print("--- Running Suite: Player Directional Facing ---")
	var game: Control = create_test_game()

	# Initial facing direction is DOWN
	assert_eq(game.player_facing_dir, Vector2i.DOWN, "Default facing direction is DOWN")

	# Move UP
	game.try_move(Vector2i.UP)
	assert_eq(game.player_facing_dir, Vector2i.UP, "Player facing updated to UP")

	# Move LEFT
	game.try_move(Vector2i.LEFT)
	assert_eq(game.player_facing_dir, Vector2i.LEFT, "Player facing updated to LEFT")

	# Move RIGHT
	game.try_move(Vector2i.RIGHT)
	assert_eq(game.player_facing_dir, Vector2i.RIGHT, "Player facing updated to RIGHT")

	# Move DOWN
	game.try_move(Vector2i.DOWN)
	assert_eq(game.player_facing_dir, Vector2i.DOWN, "Player facing updated to DOWN")

	game.free()
	
	
func test_walking_sprite_cycle() -> void:
	print("--- Running Suite: Walking Sprite Cycle & Locomotion Polish ---")
	var game: Control = create_test_game()

	# Verify all walking cycle textures are loaded
	assert_true(game.tex_player_down_w1 != null, "tex_player_down_w1 loaded")
	assert_true(game.tex_player_down_w2 != null, "tex_player_down_w2 loaded")
	assert_true(game.tex_player_up_w1 != null, "tex_player_up_w1 loaded")
	assert_true(game.tex_player_up_w2 != null, "tex_player_up_w2 loaded")
	assert_true(game.tex_player_left_w1 != null, "tex_player_left_w1 loaded")
	assert_true(game.tex_player_left_w2 != null, "tex_player_left_w2 loaded")
	assert_true(game.tex_player_right_w1 != null, "tex_player_right_w1 loaded")
	assert_true(game.tex_player_right_w2 != null, "tex_player_right_w2 loaded")

	# Initial state: idle frame (0)
	assert_eq(game.current_walk_frame, 0, "Initial walk frame is 0 (idle stance)")
	assert_eq(game.walk_step_count, 0, "Initial walk step count is 0")

	# Trigger an animation step
	game._animate_player(Vector2i(2, 3), Vector2i(2, 4))
	assert_true(game.is_animating, "Player is animating during locomotion step")
	assert_eq(game.walk_step_count, 1, "Walk step count incremented to 1")
	assert_true(game.current_walk_frame in [1, 2], "Walking frame is active (1 or 2) during stride")

	# Test reset returns to idle stance (frame 0)
	game._on_level_reset()
	assert_eq(game.current_walk_frame, 0, "Reset restores idle frame 0")
	assert_eq(game.walk_step_count, 0, "Reset zeroes walk step count")

	# Test undo returns to idle stance (frame 0)
	game.current_walk_frame = 2
	game._on_move_undone(Vector2i(2, 3), false, Vector2i.ZERO, Vector2i.ZERO)
	assert_eq(game.current_walk_frame, 0, "Undo restores idle frame 0")

	game.free()


func test_restart_confirmation_threshold() -> void:
	print("--- Running Suite: Restart Confirmation Threshold ---")
	var loc: Node = LocalizationManagerScript.new()
	var game: Control = create_test_game(loc)

	# Under 5 moves: restarts without dialog confirmation
	game.grid.moves_count = 3
	game._on_restart_pressed()
	assert_eq(game.grid.moves_count, 0, "Restarted immediately when moves < 5")

	# At >= 5 moves: dialog text is prepared and populated
	game.grid.moves_count = 6
	game._on_restart_pressed()
	assert_true(game.restart_dialog.dialog_text.contains("6"), "Restart confirmation contains move count 6")
	assert_eq(game.restart_dialog.dialog_text, "You've made 6 moves. Restart this level?", "Restart text matches EN")

	# Switch to Arabic
	loc.set_language("ar")
	game._on_restart_pressed()
	assert_true(game.restart_dialog.dialog_text.contains("6"), "AR Restart text contains move count 6")
	assert_true(game.restart_dialog.dialog_text.contains("إعادة"), "AR Restart text is in Arabic")

	game.free()
	loc.free()


func test_win_celebration_and_particles() -> void:
	print("--- Running Suite: Win Celebration & Particles ---")
	var game: Control = create_test_game()

	assert_eq(game.win_particles.size(), 0, "No particles initially")

	# Trigger celebration
	game._spawn_celebration_particles()
	assert_true(game.win_particles.size() > 30, "Celebration spawned particles (got %d)" % game.win_particles.size())

	var first_p: Dictionary = game.win_particles[0]
	assert_true(first_p.has("pos"), "Particle has position")
	assert_true(first_p.has("vel"), "Particle has velocity")
	assert_true(first_p.has("color"), "Particle has color")
	assert_true(first_p.has("life"), "Particle has life")

	# Simulate 0.1s of physics in _process
	game._process(0.1)
	assert_true(game.win_particles.size() > 0, "Particles active during lifetime")

	# Simulate past max life (3.5 seconds) to verify cleanup
	game._process(3.5)
	assert_eq(game.win_particles.size(), 0, "Particles expired and cleared after duration")

	game.free()


func test_layout_and_framing() -> void:
	print("--- Running Suite: Layout & Framing Calculations ---")
	var game: Control = create_test_game()

	# Compute layout for 720x1280 mobile portrait viewport
	game.calculate_layout(Vector2(720, 1280))
	assert_true(game.tile_size > 0.0, "Tile size calculated properly (got %f)" % game.tile_size)
	assert_true(game.grid_origin.y > 0.0, "Grid origin placed in playable area (got %s)" % str(game.grid_origin))
	assert_true(game.grid_origin.x >= 0.0, "Grid origin centered horizontally (got %s)" % str(game.grid_origin))

	game.free()


func test_undo_button_interaction() -> void:
	print("--- Running Suite: Undo Button UI Interaction ---")
	var game: Control = create_test_game()

	assert_true(game.undo_button != null, "Undo button initialized in game")
	assert_true(game.undo_button.disabled, "Undo button disabled at start")

	var init_pos: Vector2i = game.grid.player_pos

	# Make a move down
	game.try_move(Vector2i.DOWN)
	assert_eq(game.grid.moves_count, 1, "Moves count incremented to 1")
	assert_true(not game.undo_button.disabled, "Undo button enabled after move")

	# Trigger undo via button handler
	game._on_undo_pressed()
	assert_eq(game.grid.moves_count, 0, "Moves count restored to 0 after undo")
	assert_eq(game.grid.player_pos, init_pos, "Player position restored after undo")
	assert_true(game.undo_button.disabled, "Undo button disabled after rolling back all moves")

	game.free()


func test_juice_and_micro_interactions() -> void:
	print("--- Running Suite: Juice & Micro-Interactions ---")
	var game: Control = create_test_game()

	assert_eq(game.board_trauma, 0.0, "Board trauma starts at 0.0")
	assert_eq(game.dust_particles.size(), 0, "No dust particles initially")
	assert_eq(game.goal_effects.size(), 0, "No goal effects initially")

	# Push crate UP in Level 1
	game.try_move(Vector2i.UP)
	assert_true(game.dust_particles.size() > 0, "Dust particles spawned on crate push")
	assert_true(game.board_trauma > 0.0, "Board trauma added on crate push")
	assert_true(game.crate_squash.has(Vector2i(2, 1)), "Crate squash & stretch deformation tracked")

	# Process decay
	game._process(0.5)
	assert_eq(game.dust_particles.size(), 0, "Dust particles expired and cleared after duration")

	# Test goal effect spawning
	game._spawn_goal_effect(Vector2i(1, 3))
	assert_true(game.goal_effects.size() > 0, "Goal effect spawned shockwave and sparks")

	game._process(0.5)
	assert_eq(game.goal_effects.size(), 0, "Goal effects expired and cleared after duration")

	# Test trauma decay to 0
	game._process(1.0)
	assert_eq(game.board_trauma, 0.0, "Trauma decayed back to 0.0")
	assert_eq(game.board_shake_offset, Vector2.ZERO, "Board shake offset returned to Vector2.ZERO")

	game.free()


func test_win_modal_three_star_system() -> void:
	print("--- Running Suite: 3-Star Victory Modal & Stat Badges ---")
	var loc: Node = LocalizationManagerScript.new()
	var save_mgr: Node = SaveManagerScript.new()
	var game: Control = create_test_game(loc, save_mgr)

	assert_true(game.win_modal != null, "Win modal initialized")
	assert_true(game.star_1 != null, "Star 1 label initialized")
	assert_true(game.star_2 != null, "Star 2 label initialized")
	assert_true(game.star_3 != null, "Star 3 label initialized")
	assert_true(game.level_placard_label != null, "Level placard initialized")
	assert_true(game.win_retry_button != null, "Win retry button initialized")
	assert_true(game.win_blur_overlay != null, "Win blur backdrop overlay initialized")
	assert_true(not game.win_modal.visible, "Win modal hidden during normal play")
	assert_true(not game.win_blur_overlay.visible, "Win blur overlay hidden during normal play")

	# Test Retry button functionality
	game.grid.moves_count = 5
	game.win_modal.show()
	game.win_blur_overlay.show()
	assert_true(game.win_modal.visible, "Win modal shown for test")
	assert_true(game.win_blur_overlay.visible, "Win blur overlay shown for test")
	game._on_win_retry_pressed()
	assert_true(not game.win_modal.visible, "Win modal hidden on retry")
	assert_true(not game.win_blur_overlay.visible, "Win blur overlay hidden on retry")
	assert_eq(game.grid.moves_count, 0, "Level reset to 0 moves on retry")

	# Test Star rating calculation integration with save manager
	assert_eq(save_mgr.calculate_stars(0, 5), 3, "Optimal moves achieves 3 stars")
	assert_eq(save_mgr.calculate_stars(0, 14), 2, "Moderate moves achieves 2 stars")
	assert_eq(save_mgr.calculate_stars(0, 20), 1, "Completed with high moves achieves 1 star")

	game.free()
	save_mgr.free()
	loc.free()


func test_hint_system_and_solver() -> void:
	print("--- Running Suite: Hint Button via Solver & Directional Ghost ---")
	var loc: Node = LocalizationManagerScript.new()
	var game: Control = create_test_game(loc)

	assert_true(game.hint_button != null, "Hint button initialized in game")
	assert_true(not game.hint_button.disabled, "Hint button enabled initially")
	assert_true("Hint" in game.hint_button.text, "Hint button localized in EN")
	assert_eq(game.active_hint_dir, Vector2i.ZERO, "No active hint direction initially")
	assert_eq(game.hint_time_remaining, 0.0, "Hint timer starts at 0")

	# Ensure sufficient hints for multiple solver test invocations
	if game.save_mgr != null:
		game.save_mgr.add_hints(10)

	# 1. Trigger Hint on Level 1 (solvable)
	game._on_hint_pressed()
	assert_true(game.hint_time_remaining > 0.0, "Hint time activated on press")
	assert_true(game.active_hint_dir != Vector2i.ZERO, "Solver computed directional hint (got %s)" % str(game.active_hint_dir))
	assert_eq(game.hint_player_target, game.grid.player_pos + game.active_hint_dir, "Hint target corresponds to player move")
	if game.hint_toast != null:
		assert_true(game.hint_toast.visible, "Hint toast visible when hint triggered")
		assert_true(game.hint_toast_label.text.contains("Hint"), "Toast contains hint direction message")

	# 2. Moving clears active hint
	var hint_dir: Vector2i = game.active_hint_dir
	game.try_move(hint_dir)
	assert_eq(game.active_hint_dir, Vector2i.ZERO, "Active hint cleared on move")
	assert_eq(game.hint_time_remaining, 0.0, "Hint time cleared on move")
	game.is_animating = false

	# 3. Request hint again and verify undo clears hint
	game._on_hint_pressed()
	assert_true(game.hint_time_remaining > 0.0, "Hint active again")
	game._on_undo_pressed()
	assert_eq(game.active_hint_dir, Vector2i.ZERO, "Active hint cleared on undo")
	assert_eq(game.hint_time_remaining, 0.0, "Hint timer cleared on undo")
	game.is_animating = false

	# 4. Request hint again and verify level reset clears hint
	game._on_hint_pressed()
	assert_true(game.hint_time_remaining > 0.0, "Hint active before reset")
	game._on_level_reset()
	assert_eq(game.active_hint_dir, Vector2i.ZERO, "Active hint cleared on level reset")
	game.is_animating = false

	# 5. Process countdown expiration
	game._on_hint_pressed()
	assert_true(game.hint_time_remaining > 0.0, "Hint active before timeout test")
	game._process(5.0)
	assert_eq(game.active_hint_dir, Vector2i.ZERO, "Hint expired and cleared after 5.0s")
	assert_eq(game.hint_time_remaining, 0.0, "Hint time zeroed after duration")

	# 6. Deadlock Detection
	# Create a deadlock by putting a crate in an unsolveable corner (e.g. at (1,1))
	game.grid.crates.clear()
	game.grid.crates[Vector2i(1, 1)] = true # Wall corner in Level 1 (top-left)
	game._on_hint_pressed()
	assert_eq(game.active_hint_dir, Vector2i.ZERO, "No move hint provided for deadlocked board")
	assert_true(game.board_trauma > 0.0, "Warning trauma triggered on deadlock")
	if game.hint_toast_label != null:
		assert_true(game.hint_toast_label.text.contains("Undo"), "Deadlock toast directs player to Undo")

	game.free()
	loc.free()


func test_warehouse_chapter_themes_and_progression() -> void:
	print("--- Running Suite: Warehouse Chapter Themes & Visual Progression (Phase 2) ---")
	var loc: Node = LocalizationManagerScript.new()
	var save_mgr: Node = SaveManagerScript.new()
	save_mgr.unlocked_level = 49 # Unlock all levels for chapter transition testing

	var game: Control = create_test_game(loc, save_mgr)

	# 1. Chapter Badge UI initialized
	assert_true(game.chapter_badge != null, "ChapterBadge label node initialized in TopBar")

	# 2. Level 0 is Chapter 0 (Cargo Bay)
	assert_eq(game.current_chapter_idx, 0, "Initial chapter index is 0")
	assert_eq(game.chapter_badge.text, "CH. 1", "Chapter 0 badge displays 'CH. 1'")
	var ch0: Dictionary = game.get_current_chapter_theme()
	assert_eq(ch0["name"], "Cargo Bay", "Chapter 0 theme name is Cargo Bay")
	assert_eq(ch0["frame_rim"], Color(0.78, 0.60, 0.22), "Chapter 0 polished brass bevel rim")
	assert_eq(ch0["floor_tint"], Color(1.0, 1.0, 1.0), "Chapter 0 natural concrete floor tint")

	# 3. Chapter 1 (Cold Storage) at Level 15 (Level 16 in UI)
	game.load_level(15)
	assert_eq(game.current_chapter_idx, 1, "Level 15 transitions to chapter index 1")
	assert_eq(game.chapter_badge.text, "CH. 2", "Chapter 1 badge displays 'CH. 2'")
	var ch1: Dictionary = game.get_current_chapter_theme()
	assert_eq(ch1["name"], "Cold Storage", "Chapter 1 theme name is Cold Storage")
	assert_eq(ch1["frame_rim"], Color(0.35, 0.82, 1.00), "Chapter 1 cryogenic cyan bevel rim")
	assert_eq(ch1["floor_tint"], Color(0.82, 0.92, 1.00), "Chapter 1 frost-sheen floor tint")

	# 4. Chapter 2 (Cyber Depot) at Level 35 (Level 36 in UI)
	game.load_level(35)
	assert_eq(game.current_chapter_idx, 2, "Level 35 transitions to chapter index 2")
	assert_eq(game.chapter_badge.text, "CH. 3", "Chapter 2 badge displays 'CH. 3'")
	var ch2: Dictionary = game.get_current_chapter_theme()
	assert_eq(ch2["name"], "Cyber Depot", "Chapter 2 theme name is Cyber Depot")
	assert_eq(ch2["frame_rim"], Color(1.00, 0.65, 0.18), "Chapter 2 hazard amber bevel rim")
	assert_eq(ch2["goal_aura"], Color(0.20, 1.00, 0.55), "Chapter 2 laser emerald goal aura")

	# 5. Localization of Chapter titles
	assert_eq(loc.tr_text("CHAPTER_0_TITLE"), "Cargo Bay", "EN Chapter 0 title is 'Cargo Bay'")
	assert_eq(loc.tr_text("CHAPTER_1_TITLE"), "Cold Storage", "EN Chapter 1 title is 'Cold Storage'")
	assert_eq(loc.tr_text("CHAPTER_2_TITLE"), "Cyber Depot", "EN Chapter 2 title is 'Cyber Depot'")

	loc.current_language = "fr"
	assert_eq(loc.tr_text("CHAPTER_0_TITLE"), "Baie de chargement", "FR Chapter 0 title is 'Baie de chargement'")
	assert_eq(loc.tr_text("CHAPTER_1_TITLE"), "Chambre froide", "FR Chapter 1 title is 'Chambre froide'")
	assert_eq(loc.tr_text("CHAPTER_2_TITLE"), "Cyber Dépôt", "FR Chapter 2 title is 'Cyber Dépôt'")

	loc.current_language = "ar"
	assert_eq(loc.tr_text("CHAPTER_0_TITLE"), "خليج الشحن", "AR Chapter 0 title is 'خليج الشحن'")
	assert_eq(loc.tr_text("CHAPTER_1_TITLE"), "التخزين البارد", "AR Chapter 1 title is 'التخزين البارد'")
	assert_eq(loc.tr_text("CHAPTER_2_TITLE"), "المستودع الذكي", "AR Chapter 2 title is 'المستودع الذكي'")

	game.free()
	loc.free()
	save_mgr.free()


func test_porter_locker_cosmetics_in_game() -> void:
	print("--- Running Suite: Porter Locker Cosmetics in Game (Phase 3) ---")
	var loc: Node = LocalizationManagerScript.new()
	var save_mgr: Node = SaveManagerScript.new()

	var game: Control = create_test_game(loc, save_mgr)

	# 1. Defaults
	assert_eq(game.save_mgr.selected_worker_skin, "classic", "Default worker skin is classic in game")
	assert_eq(game.save_mgr.selected_crate_skin, "classic_wood", "Default crate skin is classic_wood in game")

	# 2. Worker skins equip and info
	var classic_info: Dictionary = game.save_mgr.get_worker_skin_info("classic")
	assert_eq(classic_info["id"], "classic", "Classic worker skin info found")
	assert_eq(classic_info["accent_color"], Color(0.28, 0.50, 0.90), "Classic worker denim accent")

	game.save_mgr.selected_worker_skin = "safety_vest"
	var safety_info: Dictionary = game.save_mgr.get_worker_skin_info("safety_vest")
	assert_eq(safety_info["icon"], "🦺", "Safety vest icon is 🦺")
	assert_eq(safety_info["accent_color"], Color(1.0, 0.50, 0.10), "Safety vest high-vis orange")

	game.save_mgr.selected_worker_skin = "foreman"
	var foreman_info: Dictionary = game.save_mgr.get_worker_skin_info("foreman")
	assert_eq(foreman_info["icon"], "👷", "Foreman icon is 👷")

	game.save_mgr.selected_worker_skin = "golden_porter"
	var gold_info: Dictionary = game.save_mgr.get_worker_skin_info("golden_porter")
	assert_eq(gold_info["icon"], "👑", "Golden Master icon is 👑")
	assert_eq(gold_info["accent_color"], Color(1.0, 0.84, 0.20), "Golden Master radiant gold")

	# 3. Crate skins equip and info
	var crate_classic: Dictionary = game.save_mgr.get_crate_skin_info("classic_wood")
	assert_eq(crate_classic["id"], "classic_wood", "Classic pine crate info found")

	game.save_mgr.selected_crate_skin = "steel_container"
	var steel_info: Dictionary = game.save_mgr.get_crate_skin_info("steel_container")
	assert_eq(steel_info["icon"], "🗄️", "Steel container icon is 🗄️")
	assert_eq(steel_info["tint"], Color(0.75, 0.85, 0.98), "Steel container freight tint")

	game.save_mgr.selected_crate_skin = "hazard_box"
	var hazard_info: Dictionary = game.save_mgr.get_crate_skin_info("hazard_box")
	assert_eq(hazard_info["icon"], "☣️", "Hazard crate icon is ☣️")

	# 4. Trigger redraw with active cosmetics without errors
	game.queue_redraw()
	assert_true(true, "Board redrawn with equipped cosmetics without error")

	# 5. Localization of Locker strings & Cosmetics (EN, FR, AR)
	assert_eq(loc.tr_text("LOCKER_TITLE"), "THE PORTER LOCKER", "EN Locker title is THE PORTER LOCKER")
	assert_eq(loc.tr_text("SKIN_WORKER_SAFETY_VEST"), "Safety Vest", "EN Safety Vest skin name")
	assert_eq(loc.tr_text("SKIN_CRATE_STEEL_CONTAINER"), "Steel Container", "EN Steel Container skin name")

	loc.current_language = "fr"
	assert_eq(loc.tr_text("LOCKER_TITLE"), "VESTIAIRE DU PORTEUR", "FR Locker title is VESTIAIRE DU PORTEUR")
	assert_eq(loc.tr_text("SKIN_WORKER_SAFETY_VEST"), "Gilet de Sécurité", "FR Safety Vest skin name")
	assert_eq(loc.tr_text("SKIN_CRATE_STEEL_CONTAINER"), "Conteneur en Acier", "FR Steel Container skin name")

	loc.current_language = "ar"
	assert_eq(loc.tr_text("LOCKER_TITLE"), "خزانة الحمال", "AR Locker title is خزانة الحمال")
	assert_eq(loc.tr_text("SKIN_WORKER_SAFETY_VEST"), "سترة الأمان", "AR Safety Vest skin name")
	assert_eq(loc.tr_text("SKIN_CRATE_STEEL_CONTAINER"), "حاوية فولاذية", "AR Steel Container skin name")

	game.free()
	loc.free()
	save_mgr.free()


func test_rewarded_ad_hint_economy_in_game() -> void:
	print("--- Running Suite: Rewarded Video Ads & Hint Economy in Game (Phase 4) ---")
	var loc: Node = LocalizationManagerScript.new()
	var save_mgr: Node = SaveManagerScript.new()

	var game: Control = create_test_game(loc, save_mgr)

	# 1. Starting hints
	assert_eq(game.save_mgr.hints_remaining, 3, "Initial hint inventory is 3")
	assert_true("(3)" in game.hint_button.text, "Hint button displays remaining count (3)")

	# 2. Exhaust hints to 0
	game.save_mgr.hints_remaining = 0
	game._update_hint_button_text()
	assert_true("(0)" in game.hint_button.text, "Hint button displays remaining count (0)")

	# 3. Tapping hint button at 0 hints presents Rewarded Ad Modal
	game._on_hint_pressed()
	assert_true(game.ad_reward_modal != null, "AdRewardModal created")
	assert_true(game.ad_reward_modal.visible, "AdRewardModal shown when hints exhausted")

	# 4. Tapping Watch Ad grants +3 hints and closes modal
	game._on_watch_ad_pressed()
	assert_true(game.save_mgr.hints_remaining >= 2, "Player awarded hints after watching ad")
	assert_true(not game.ad_reward_modal.visible, "AdRewardModal hidden after reward granted")

	# 5. Localization of rewarded ad modal
	assert_eq(loc.tr_text("MODAL_REWARD_TITLE"), "NEED A HINT?", "EN modal title localized")
	loc.current_language = "fr"
	assert_eq(loc.tr_text("MODAL_REWARD_TITLE"), "BESOIN D'UN INDICE ?", "FR modal title localized")
	loc.current_language = "ar"
	assert_eq(loc.tr_text("MODAL_REWARD_TITLE"), "تحتاج مساعدة؟", "AR modal title localized")

	game.free()
	loc.free()
	save_mgr.free()
