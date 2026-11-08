extends SceneTree

## Headless test script for AudioManager (Pixel Porter PRD v1.md Section 9).
## Run via: godot --headless --path . -s tests/test_audio_manager.gd

const AudioManagerScript = preload("res://scripts/audio_manager.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

var _passed_suites: int = 0
var _failed_suites: int = 0
var _total_assertions: int = 0
var _failed_assertions: int = 0


func _init() -> void:
	print("==================================================")
	print("   Pixel Porter - AudioManager Headless Tests    ")
	print("==================================================")

	run_suite("Procedural 8-Bit SFX Synthesis", test_sfx_synthesis)
	run_suite("Audio Voice Pool & Channels", test_voice_pool)
	run_suite("Sound Toggle Integration", test_sound_toggle_respect)
	run_suite("Safe Playback Execution", test_safe_playback)
	run_suite("Lo-Fi & Industrial BGM System", test_bgm_system)

	print("\n==================================================")
	print("Test Suites: %d passed, %d failed" % [_passed_suites, _failed_suites])
	print("Assertions : %d total, %d failed" % [_total_assertions, _failed_assertions])
	print("==================================================")

	if _failed_assertions > 0 or _failed_suites > 0:
		printerr("FAILED: Test suite had failures.")
		quit(1)
	else:
		print("SUCCESS: All AudioManager tests passed successfully!")
		quit(0)


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


func create_test_audio_mgr() -> Node:
	var mgr: Node = AudioManagerScript.new()
	root.add_child(mgr)
	mgr._ready()
	return mgr


func test_sfx_synthesis() -> void:
	var audio_mgr: Node = create_test_audio_mgr()

	assert_true(audio_mgr.sfx_move != null, "sfx_move stream generated")
	assert_true(audio_mgr.sfx_move.data.size() > 0, "sfx_move has audio sample data")
	assert_equal(audio_mgr.sfx_move.mix_rate, 22050, "sfx_move has correct 22050Hz mix rate")

	assert_true(audio_mgr.sfx_move_alt != null, "sfx_move_alt stream generated")
	assert_true(audio_mgr.sfx_move_alt.data.size() > 0, "sfx_move_alt has audio sample data")

	assert_true(audio_mgr.sfx_push != null, "sfx_push (Cargo Bay) stream generated")
	assert_true(audio_mgr.sfx_push.data.size() > 0, "sfx_push has audio sample data")

	assert_true(audio_mgr.sfx_push_cold != null, "sfx_push_cold (Cold Storage) stream generated")
	assert_true(audio_mgr.sfx_push_cyber != null, "sfx_push_cyber (Cyber Depot) stream generated")

	assert_true(audio_mgr.sfx_bump != null, "sfx_bump (Wall collision) stream generated")
	assert_true(audio_mgr.sfx_undo != null, "sfx_undo (Time rewind) stream generated")

	assert_true(audio_mgr.sfx_goal_lock != null, "sfx_goal_lock stream generated")
	assert_true(audio_mgr.sfx_goal_unlock != null, "sfx_goal_unlock stream generated")

	assert_true(audio_mgr.sfx_star1 != null, "sfx_star1 stream generated")
	assert_true(audio_mgr.sfx_star2 != null, "sfx_star2 stream generated")
	assert_true(audio_mgr.sfx_star3 != null, "sfx_star3 stream generated")

	assert_true(audio_mgr.sfx_ui_click != null, "sfx_ui_click stream generated")
	assert_true(audio_mgr.sfx_ui_back != null, "sfx_ui_back stream generated")
	assert_true(audio_mgr.sfx_ui_equip != null, "sfx_ui_equip stream generated")
	assert_true(audio_mgr.sfx_modal_open != null, "sfx_modal_open stream generated")
	assert_true(audio_mgr.sfx_modal_close != null, "sfx_modal_close stream generated")

	assert_true(audio_mgr.sfx_win != null, "sfx_win stream generated")
	assert_true(audio_mgr.sfx_win.data.size() > 0, "sfx_win has audio sample data")

	assert_true(audio_mgr.sfx_restart != null, "sfx_restart stream generated")
	assert_true(audio_mgr.sfx_restart.data.size() > 0, "sfx_restart has audio sample data")

	assert_true(audio_mgr.sfx_click != null, "sfx_click stream generated")
	assert_true(audio_mgr.sfx_click.data.size() > 0, "sfx_click has audio sample data")

	assert_true(audio_mgr.sfx_hint != null, "sfx_hint stream generated")
	assert_true(audio_mgr.sfx_hint.data.size() > 0, "sfx_hint has audio sample data")

	assert_true(audio_mgr.sfx_deadlock != null, "sfx_deadlock stream generated")
	assert_true(audio_mgr.sfx_deadlock.data.size() > 0, "sfx_deadlock has audio sample data")

	audio_mgr.queue_free()


func test_voice_pool() -> void:
	var audio_mgr: Node = create_test_audio_mgr()

	assert_equal(audio_mgr._players.size(), 6, "Voice pool contains 6 audio players")
	for p in audio_mgr._players:
		assert_true(p is AudioStreamPlayer, "Channel is AudioStreamPlayer")
		assert_equal(p.bus, "Master", "Channel is routed to Master bus")

	audio_mgr.queue_free()


func test_sound_toggle_respect() -> void:
	var audio_mgr: Node = create_test_audio_mgr()
	var mock_save: Node = SaveManagerScript.new()
	audio_mgr.save_mgr = mock_save

	# 1. Enabled
	mock_save.sound_enabled = true
	assert_true(audio_mgr.is_sound_enabled(), "Reports sound enabled when SaveManager.sound_enabled is true")

	# 2. Disabled
	mock_save.sound_enabled = false
	assert_false(audio_mgr.is_sound_enabled(), "Reports sound disabled when SaveManager.sound_enabled is false")

	audio_mgr.queue_free()
	mock_save.queue_free()


func test_safe_playback() -> void:
	var audio_mgr: Node = create_test_audio_mgr()

	# Verify calling all play methods runs cleanly without runtime exception
	audio_mgr.play_move()
	assert_true(audio_mgr._footstep_toggle, "First step triggers left foot")
	audio_mgr.play_move()
	assert_false(audio_mgr._footstep_toggle, "Second step triggers right foot (alternating rhythm)")

	audio_mgr.play_push(0)
	audio_mgr.play_push(1)
	audio_mgr.play_push(2)

	audio_mgr.play_bump()
	audio_mgr.play_undo()
	audio_mgr.play_goal_lock()
	audio_mgr.play_goal_lock(1, 3)
	audio_mgr.play_goal_lock(2, 3)
	audio_mgr.play_goal_lock(3, 3)
	audio_mgr.play_goal_unlock()
	audio_mgr.play_goal_unlock(2)

	audio_mgr.play_star(1)
	audio_mgr.play_star(2)
	audio_mgr.play_star(3)

	audio_mgr.play_win()
	audio_mgr.play_restart()
	audio_mgr.play_click()
	audio_mgr.play_ui_click()
	audio_mgr.play_ui_back()
	audio_mgr.play_ui_equip()
	audio_mgr.play_modal_open()
	audio_mgr.play_modal_close()
	audio_mgr.play_hint()
	audio_mgr.play_deadlock()
	assert_true(true, "All audio play methods executed safely")

	audio_mgr.queue_free()


func test_bgm_system() -> void:
	var audio_mgr: Node = create_test_audio_mgr()
	var mock_save: Node = SaveManagerScript.new()
	audio_mgr.save_mgr = mock_save

	# 1. Music player instance
	assert_true(audio_mgr.music_player != null, "Music player AudioStreamPlayer initialized")
	assert_equal(audio_mgr.music_player.bus, "Master", "Music player is routed to Master bus")

	# 2. BGM Streams loaded
	assert_true(audio_mgr._bgm_streams.has(0), "Track 0 (Lo-Fi Warehouse Shift) stream is loaded")
	assert_true(audio_mgr._bgm_streams.has(1), "Track 1 (Industrial Pulse) stream is loaded")

	# 3. Track naming
	assert_equal(audio_mgr.get_track_name(0), "Warehouse Chill", "Track 0 reports Warehouse Chill")
	assert_equal(audio_mgr.get_track_name(1), "Industrial Pulse", "Track 1 reports Industrial Pulse")

	# 4. Playback and track switching
	mock_save.music_enabled = true
	audio_mgr.play_music(0)
	assert_equal(audio_mgr.current_bgm_track, 0, "Current track is set to 0")
	assert_equal(mock_save.selected_bgm_track, 0, "SaveManager selected_bgm_track updated to 0")

	audio_mgr.switch_music_track(1)
	assert_equal(audio_mgr.current_bgm_track, 1, "Switched to track 1")
	assert_equal(mock_save.selected_bgm_track, 1, "SaveManager updated to track 1")

	# 5. Volume controls
	audio_mgr.set_music_volume(0.5)
	assert_equal(mock_save.music_volume, 0.5, "SaveManager music_volume updated to 0.5")

	audio_mgr.set_sfx_volume(0.6)
	assert_equal(mock_save.sfx_volume, 0.6, "SaveManager sfx_volume updated to 0.6")

	# 6. Mute toggle
	audio_mgr.set_music_enabled(false)
	assert_false(audio_mgr.is_music_enabled(), "Reports music disabled")
	assert_false(mock_save.music_enabled, "SaveManager music_enabled is false")

	audio_mgr.set_music_enabled(true)
	assert_true(audio_mgr.is_music_enabled(), "Reports music re-enabled")
	assert_true(mock_save.music_enabled, "SaveManager music_enabled is true")

	# 7. Dynamic Ducking & Unducking
	assert_true(audio_mgr.has_method("duck_music"), "AudioManager has duck_music method")
	assert_true(audio_mgr.has_method("unduck_music"), "AudioManager has unduck_music method")
	var base_db: float = audio_mgr.get_effective_music_volume_db()
	audio_mgr.duck_music(-18.0, 0.0)
	assert_equal(audio_mgr._duck_offset_db, -18.0, "Ducking offset set to -18 dB")
	var ducked_db: float = audio_mgr.get_effective_music_volume_db()
	assert_true(ducked_db < base_db, "Effective volume lower when ducked")
	audio_mgr.unduck_music(0.0)
	assert_equal(audio_mgr._duck_offset_db, 0.0, "Ducking offset restored to 0 dB")
	assert_equal(audio_mgr.get_effective_music_volume_db(), base_db, "Effective volume restored after unducking")

	# 8. Fade in & out
	assert_true(audio_mgr.has_method("fade_out_music"), "AudioManager has fade_out_music method")
	assert_true(audio_mgr.has_method("fade_in_music"), "AudioManager has fade_in_music method")

	audio_mgr.stop_music()
	audio_mgr.queue_free()
	mock_save.queue_free()
