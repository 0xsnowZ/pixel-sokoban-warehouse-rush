extends SceneTree

## Headless test script for Main Menu & Level Select flow (Pixel Porter PRD v1.md Section 6).
## Run via: godot --headless --path . -s tests/test_main_menu.gd

const MainMenuScene = preload("res://scenes/main_menu.tscn")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const TEST_SAVE_PATH: String = "user://test_main_menu_save.json"

var _passed_suites: int = 0
var _failed_suites: int = 0
var _total_assertions: int = 0
var _failed_assertions: int = 0


func _init() -> void:
	print("==================================================")
	print("    Pixel Porter - Main Menu Headless Tests      ")
	print("==================================================")

	_cleanup_test_file()

	run_suite("Main Menu Initialization & Views", test_menu_initialization)
	run_suite("Progression Reactive State (Continue/Play)", test_continue_and_play_state)
	run_suite("50-Level Select Grid & Status Badges", test_level_select_grid)
	run_suite("Sound Toggle & Credits Modal", test_sound_and_credits)
	run_suite("Settings Modal & Audio Sliders", test_settings_modal_and_sliders)
	run_suite("Porter Locker Modal & Cosmetic Equipping", test_porter_locker_modal)
	run_suite("Warehouse Achievements Modal", test_achievements_modal)

	_cleanup_test_file()

	print("\n==================================================")
	print("Test Suites: %d passed, %d failed" % [_passed_suites, _failed_suites])
	print("Assertions : %d total, %d failed" % [_total_assertions, _failed_assertions])
	print("==================================================")

	if _failed_assertions > 0 or _failed_suites > 0:
		printerr("FAILED: Test suite had failures.")
		quit(1)
	else:
		print("SUCCESS: All Main Menu tests passed successfully!")
		quit(0)


func _cleanup_test_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func run_suite(suite_name: String, test_callable: Callable) -> void:
	print("\n--- Running Suite: %s ---" % suite_name)
	var prev_failures: int = _failed_assertions
	test_callable.call()
	if _failed_assertions == prev_failures:
		_passed_suites += 1
	else:
		_failed_suites += 1


func assert_true(condition: bool, message: String) -> void:
	_total_assertions += 1
	if condition:
		print("  [PASS] %s" % message)
	else:
		_failed_assertions += 1
		printerr("  [FAIL] Assertion failed: %s" % message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_total_assertions += 1
	if actual == expected:
		print("  [PASS] %s (got %s)" % [message, str(actual)])
	else:
		_failed_assertions += 1
		printerr("  [FAIL] %s - Expected: %s, Got: %s" % [message, str(expected), str(actual)])


func create_test_menu() -> Control:
	var menu: Control = MainMenuScene.instantiate()
	root.add_child(menu)
	menu._ready()
	return menu


func test_menu_initialization() -> void:
	var menu: Control = create_test_menu()

	assert_true(menu.main_view.visible, "Main view is visible by default")
	assert_false(menu.level_select_view.visible, "Level select view is hidden by default")
	assert_false(menu.credits_modal.visible, "Credits modal is hidden by default")

	# View switching
	menu._show_level_select()
	assert_false(menu.main_view.visible, "Main view hidden when level select is shown")
	assert_true(menu.level_select_view.visible, "Level select visible when activated")

	menu._show_main_view()
	assert_true(menu.main_view.visible, "Main view restored on back")
	assert_false(menu.level_select_view.visible, "Level select hidden on back")

	menu.queue_free()


func test_continue_and_play_state() -> void:
	var menu: Control = create_test_menu()

	# 1. Fresh state: no completed levels
	menu.save_mgr.reset_all_progress(TEST_SAVE_PATH)
	menu._update_menu_state()
	assert_false(menu.continue_btn.visible, "Continue button hidden on fresh game")
	assert_equal(menu.play_btn.text, "PLAY", "Play button text is 'PLAY'")

	# 2. Player has completed level 0 and unlocked level 1
	menu.save_mgr.record_level_completion(0, 10, 5, TEST_SAVE_PATH)
	menu.save_mgr.last_played_level = 0
	menu._update_menu_state()

	assert_true(menu.continue_btn.visible, "Continue button visible after completing a level")
	assert_true("LEVEL 1" in menu.continue_btn.text, "Continue button indicates Level 1")
	assert_equal(menu.play_btn.text, "NEW GAME", "Play button text switches to 'NEW GAME'")

	menu.queue_free()


func test_level_select_grid() -> void:
	var menu: Control = create_test_menu()

	var grid_buttons = menu.level_grid.get_children()
	assert_equal(grid_buttons.size(), 50, "Level grid contains 50 level buttons as required by PRD")

	# Set level 0 as completed, level 1 as unlocked, level 2 as available
	menu.save_mgr.reset_all_progress(TEST_SAVE_PATH)
	menu.save_mgr.record_level_completion(0, 7, 3, TEST_SAVE_PATH)
	menu._refresh_level_grid_buttons()

	var btn0: Button = grid_buttons[0] as Button
	assert_false(btn0.disabled, "Level 1 button is enabled (completed)")
	assert_true("★" in btn0.text, "Level 1 button shows completed star badge")
	assert_equal(btn0.text, "1\n★★★", "Level 1 button shows clean level number and stars")

	var btn1: Button = grid_buttons[1] as Button
	assert_false(btn1.disabled, "Level 2 button is enabled (current unlocked)")
	assert_true(btn1.icon != null, "Level 2 button shows playable arrow icon")

	var btn2: Button = grid_buttons[2] as Button
	assert_true(btn2.disabled, "Level 3 button is locked until level 2 completed")
	assert_true(btn2.icon != null, "Level 3 button shows lock icon")

	var btn10: Button = grid_buttons[10] as Button
	assert_true(btn10.disabled, "Level 11 button is locked until unlocked")
	assert_true(btn10.icon != null, "Level 11 button shows lock icon")

	menu.queue_free()


func test_sound_and_credits() -> void:
	var menu: Control = create_test_menu()

	# Sound toggle
	menu.save_mgr.sound_enabled = true
	menu._update_menu_state()
	assert_equal(menu.sound_btn.text, "SOUND: ON", "Sound button displays 'SOUND: ON'")

	menu._on_sound_toggle_pressed()
	assert_false(menu.save_mgr.sound_enabled, "Sound setting toggled to false")
	assert_equal(menu.sound_btn.text, "SOUND: OFF", "Sound button displays 'SOUND: OFF'")

	menu._on_sound_toggle_pressed()
	assert_true(menu.save_mgr.sound_enabled, "Sound setting toggled back to true")
	assert_equal(menu.sound_btn.text, "SOUND: ON", "Sound button displays 'SOUND: ON'")

	# Haptics toggle
	menu.save_mgr.haptics_enabled = true
	menu._update_menu_state()
	assert_true(menu.haptics_btn != null, "Haptics button exists in MainMenu")
	assert_equal(menu.haptics_btn.text, "HAPTICS: ON", "Haptics button displays 'HAPTICS: ON'")

	menu._on_haptics_toggle_pressed()
	assert_false(menu.save_mgr.haptics_enabled, "Haptics setting toggled to false")
	assert_equal(menu.haptics_btn.text, "HAPTICS: OFF", "Haptics button displays 'HAPTICS: OFF'")

	menu._on_haptics_toggle_pressed()
	assert_true(menu.save_mgr.haptics_enabled, "Haptics setting toggled back to true")
	assert_equal(menu.haptics_btn.text, "HAPTICS: ON", "Haptics button displays 'HAPTICS: ON'")

	# Credits modal
	menu._show_credits()
	assert_true(menu.credits_modal.visible, "Credits modal is visible after _show_credits")

	menu._hide_credits()
	assert_false(menu.credits_modal.visible, "Credits modal is hidden after _hide_credits")

	menu.queue_free()


func test_settings_modal_and_sliders() -> void:
	var menu: Control = create_test_menu()

	# 1. Elements exist
	assert_true(menu.settings_btn != null, "Settings button exists on MainMenu")
	assert_true(menu.settings_modal != null, "Settings modal exists")
	assert_false(menu.settings_modal.visible, "Settings modal is hidden initially")
	assert_true(menu.music_slider != null, "Music slider exists")
	assert_true(menu.sfx_slider != null, "SFX slider exists")
	assert_true(menu.track_cycle_btn != null, "Track cycle button exists")

	# 2. Open / Close modal
	menu._show_settings()
	assert_true(menu.settings_modal.visible, "Settings modal opens via _show_settings")

	# 3. Sliders update save_mgr
	menu._on_music_slider_changed(0.45)
	assert_equal(menu.save_mgr.music_volume, 0.45, "Music volume updated via slider to 0.45")
	assert_true("45%" in menu.music_vol_label.text, "Music label reflects 45%")

	menu._on_sfx_slider_changed(0.85)
	assert_equal(menu.save_mgr.sfx_volume, 0.85, "SFX volume updated via slider to 0.85")
	assert_true("85%" in menu.sfx_vol_label.text, "SFX label reflects 85%")

	# 4. Track cycle button
	menu.save_mgr.selected_bgm_track = 0
	menu._update_settings_ui()
	assert_true("Warehouse Chill" in menu.track_cycle_btn.text, "Track button shows Warehouse Chill")

	menu._on_track_cycle_pressed()
	assert_equal(menu.save_mgr.selected_bgm_track, 1, "Track cycled to 1 (Industrial Pulse)")
	assert_true("Industrial Pulse" in menu.track_cycle_btn.text, "Track button shows Industrial Pulse")

	# 5. Music toggle
	menu.save_mgr.music_enabled = true
	menu._on_music_toggle_pressed()
	assert_false(menu.save_mgr.music_enabled, "Music toggled to false")
	assert_equal(menu.music_toggle_btn.text, "MUSIC: OFF", "Music toggle button text is OFF")

	menu._on_music_toggle_pressed()
	assert_true(menu.save_mgr.music_enabled, "Music toggled back to true")
	assert_equal(menu.music_toggle_btn.text, "MUSIC: ON", "Music toggle button text is ON")

	# 6. Control scheme cycling
	assert_true(menu.control_mode_btn != null, "Control mode button exists in Settings modal")
	assert_true("SWIPE" in menu.control_mode_btn.text, "Initial control mode displays SWIPE")
	menu._on_control_mode_pressed()
	assert_equal(menu.save_mgr.control_scheme, 1, "Control scheme cycled to 1 (D-PAD)")
	assert_true("D-PAD" in menu.control_mode_btn.text, "Control button updates to D-PAD")
	menu._on_control_mode_pressed()
	assert_equal(menu.save_mgr.control_scheme, 2, "Control scheme cycled to 2 (DUAL)")
	assert_true("DUAL" in menu.control_mode_btn.text, "Control button updates to DUAL")
	menu._on_control_mode_pressed()
	assert_equal(menu.save_mgr.control_scheme, 0, "Control scheme cycled back to 0 (SWIPE)")
	assert_true("SWIPE" in menu.control_mode_btn.text, "Control button cycles back to SWIPE")

	# Close modal
	menu._hide_settings()
	assert_false(menu.settings_modal.visible, "Settings modal hidden via _hide_settings")

	menu.queue_free()


func test_porter_locker_modal() -> void:
	var menu: Control = create_test_menu()

	# 1. Elements exist
	assert_true(menu.locker_btn != null, "Locker button exists on ConsoleCard")
	assert_true(menu.locker_modal != null, "Locker modal exists")
	assert_false(menu.locker_modal.visible, "Locker modal is hidden initially")
	assert_true(menu.locker_stars_badge != null, "Locker stars badge exists")
	assert_true(menu.outfits_tab_btn != null, "Outfits tab button exists")
	assert_true(menu.crates_tab_btn != null, "Crates tab button exists")
	assert_true(menu.locker_items_vbox != null, "Locker items VBox exists")

	# 2. Open locker modal
	menu._show_locker()
	assert_true(menu.locker_modal.visible, "Locker modal opens via _show_locker")
	assert_equal(menu.current_locker_tab, "outfits", "Default locker tab is outfits")
	assert_true("Stars" in menu.locker_stars_badge.text, "Locker stars badge reflects total stars")

	# 3. Items populated for Outfits (6 worker skins)
	var outfit_cards = menu.locker_items_vbox.get_children()
	assert_equal(outfit_cards.size(), 6, "Locker displays 6 worker skin cards in outfits tab")

	# 4. Switch tab to Crates (5 crate skins)
	menu._switch_locker_tab("crates")
	assert_equal(menu.current_locker_tab, "crates", "Switched current tab to crates")
	var crate_cards = menu.locker_items_vbox.get_children()
	assert_equal(crate_cards.size(), 5, "Locker displays 5 crate skin cards in crates tab")

	# 5. Unlock and Equip cosmetics with stars
	menu.save_mgr.reset_all_progress(TEST_SAVE_PATH)
	for i in range(17):
		menu.save_mgr.record_level_completion(i, 5, 2, TEST_SAVE_PATH)
	assert_true(menu.save_mgr.get_total_stars() >= 50, "Player has >= 50 stars")

	# Refresh locker UI with new stars
	menu._refresh_locker_ui()

	# Equip unlocked steel container (requires 40 stars)
	menu._on_equip_crate_skin("steel_container")
	assert_equal(menu.save_mgr.selected_crate_skin, "steel_container", "Equipped steel_container crate skin via locker")

	# Switch back to outfits and equip safety vest (requires 25 stars)
	menu._switch_locker_tab("outfits")
	menu._on_equip_worker_skin("safety_vest")
	assert_equal(menu.save_mgr.selected_worker_skin, "safety_vest", "Equipped safety_vest worker skin via locker")

	# Close modal
	menu._hide_locker()
	assert_false(menu.locker_modal.visible, "Locker modal hidden via _hide_locker")

	menu.queue_free()


func test_achievements_modal() -> void:
	var menu: Control = create_test_menu()

	# 1. Elements exist
	assert_true(menu.achievements_btn != null, "Achievements button exists on ConsoleCard")
	assert_true(menu.achievements_modal != null, "Achievements modal exists")
	assert_false(menu.achievements_modal.visible, "Achievements modal is hidden initially")
	assert_true(menu.achievements_title_label != null, "Achievements title label exists")
	assert_true(menu.achievements_counter_badge != null, "Achievements counter badge exists")
	assert_true(menu.achievements_items_vbox != null, "Achievements items VBox exists")

	# 2. Open achievements modal
	menu._show_achievements()
	assert_true(menu.achievements_modal.visible, "Achievements modal opens via _show_achievements")
	assert_true("0 / 9" in menu.achievements_counter_badge.text or "0" in menu.achievements_counter_badge.text, "Achievements counter badge starts at 0")

	# 3. 9 achievement cards populated
	var cards = menu.achievements_items_vbox.get_children()
	assert_equal(cards.size(), 9, "Achievements modal displays all 9 achievement cards")

	# 4. Unlock an achievement and refresh
	if menu.achievement_mgr:
		menu.achievement_mgr.unlock("first_shift")
		menu._refresh_achievements_ui()
		assert_true("1 / 9" in menu.achievements_counter_badge.text, "Counter badge updates to 1 / 9 unlocked")

	# 5. Close modal
	menu._hide_achievements()
	assert_false(menu.achievements_modal.visible, "Achievements modal hidden via _hide_achievements")

	menu.queue_free()
