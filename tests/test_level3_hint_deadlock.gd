extends SceneTree

const GameScene = preload("res://scenes/game.tscn")
const HapticManagerScript = preload("res://scripts/haptic_manager.gd")
const AudioManagerScript = preload("res://scripts/audio_manager.gd")
const LocalizationManagerScript = preload("res://scripts/localization_manager.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

func _init() -> void:
	print("\n=== Testing Level 3 Deadlock Hint Scenario ===")
	var game: Control = GameScene.instantiate()
	var haptics: Node = HapticManagerScript.new()
	var audio: Node = AudioManagerScript.new()
	var loc: Node = LocalizationManagerScript.new()
	var save: Node = SaveManagerScript.new()

	root.add_child(save)
	root.add_child(loc)
	root.add_child(haptics)
	root.add_child(audio)
	root.add_child(game)

	game.haptic_mgr = haptics
	game.audio_mgr = audio
	game.loc_mgr = loc
	game.save_mgr = save
	game._ready()

	# Load Level 3 (index 2)
	game.load_level(2)

	# Set French language to mirror user screenshot
	loc.set_language("fr")

	# Reconstruct exact state from user's screenshot:
	# Row 1: goals at (6, 1)
	# Row 3: crates on goals at (2, 3), (3, 3), (4, 3)
	# Row 3: crate at (6, 3) (deadlocked against wall at (7, 3) and (6, 4))
	# Player at (6, 2)
	game.grid.crates.clear()
	game.grid.crates[Vector2i(2, 3)] = true
	game.grid.crates[Vector2i(3, 3)] = true
	game.grid.crates[Vector2i(4, 3)] = true
	game.grid.crates[Vector2i(6, 3)] = true
	game.grid.player_pos = Vector2i(6, 2)
	game.visual_player_pos = Vector2(6, 2)

	print("Board state configured to screenshot scenario.")
	print("Calling game._on_hint_pressed()...")

	var start_ms: int = Time.get_ticks_msec()
	game._on_hint_pressed()
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	print("Hint pressed finished in %d ms." % elapsed_ms)
	print("Haptic last type: %s, duration: %d" % [haptics.last_vibration_type, haptics.last_vibration_duration])
	print("Toast visible: %s, text: '%s'" % [str(game.hint_toast.visible), game.hint_toast_label.text])

	assert(haptics.last_vibration_type == "impact", "Haptics should be impact")
	assert(haptics.last_vibration_duration == 55, "Haptic duration should be 55ms")
	assert(game.hint_toast.visible == true, "Toast must be visible")
	assert("Annuler" in game.hint_toast_label.text or "Bloqué" in game.hint_toast_label.text, "Toast must direct player to undo in French")
	assert(game.active_hint_dir == Vector2i.ZERO, "No directional ghost should be shown for deadlock")

	# Request redraw via standard Godot queue_redraw()
	game.queue_redraw()

	print("\nSUCCESS: Level 3 Deadlock Hint handled smoothly without freezing!\n")
	game.free()
	audio.free()
	haptics.free()
	loc.free()
	save.free()
	quit(0)
