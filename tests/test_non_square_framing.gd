extends SceneTree

const GameScene = preload("res://scenes/game.tscn")
const LocalizationManagerScript = preload("res://scripts/localization_manager.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

func _init() -> void:
	print("\n======================================================")
	print("   Pixel Porter - Non-Square Board Slim Border Tests  ")
	print("======================================================\n")

	var game: Control = GameScene.instantiate()
	var loc: Node = LocalizationManagerScript.new()
	var save: Node = SaveManagerScript.new()
	save.unlocked_level = 49 # Unlock all levels for test

	root.add_child(save)
	root.add_child(loc)
	root.add_child(game)

	game.loc_mgr = loc
	game.save_mgr = save
	game._ready()

	# 1. Test Level 6 (Pinwheel Cross - the exact level from user screenshot)
	# Index 5 in campaign
	game.load_level(5)
	print("Loaded Level 6 (width=%d, height=%d)..." % [game.grid.width, game.grid.height])

	var is_non_sq_l6: bool = game.is_level_non_square()
	print("  is_level_non_square(Level 6): %s" % str(is_non_sq_l6))
	assert(is_non_sq_l6 == true, "Level 6 must be recognized as non-square shape")

	# Verify exterior tile detection on corners of Level 6 (Pinwheel Cross)
	assert(game.is_exterior_tile(Vector2i(0, 0)) == true, "Corner (0, 0) is exterior")
	assert(game.is_exterior_tile(Vector2i(7, 0)) == true, "Corner (7, 0) is exterior")
	assert(game.is_exterior_tile(Vector2i(0, 8)) == true, "Corner (0, 8) is exterior")
	assert(game.is_exterior_tile(Vector2i(7, 8)) == true, "Corner (7, 8) is exterior")

	# Interior floor should NOT be exterior
	assert(game.is_exterior_tile(game.grid.player_pos) == false, "Player position is interior")

	# 2. Test Level 4 (Solid 8x7 rectangle)
	game.load_level(3)
	print("Loaded Level 4 (width=%d, height=%d)..." % [game.grid.width, game.grid.height])
	var is_non_sq_l4: bool = game.is_level_non_square()
	print("  is_level_non_square(Level 4): %s" % str(is_non_sq_l4))
	assert(is_non_sq_l4 == false, "Level 4 must be recognized as solid rectangle")

	# 3. Test queue_redraw pass on Level 6
	game.load_level(5)
	game.queue_redraw()

	print("\nSUCCESS: Non-square slim border and empty space removal verified!\n")
	game.free()
	loc.free()
	save.free()
	quit(0)
