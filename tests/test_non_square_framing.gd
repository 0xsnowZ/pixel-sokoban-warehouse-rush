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

	# 1. Test non-square framing logic with a non-square level layout
	game.grid.load_from_text("  ###   \n  #.#   \n  # ####\n###$ $ .#\n#. $ @##\n####$#  \n   #.#  \n   ###  ")
	print("Loaded non-square test grid (width=%d, height=%d)..." % [game.grid.width, game.grid.height])

	var is_non_sq_l2: bool = game.is_level_non_square()
	print("  is_level_non_square: %s" % str(is_non_sq_l2))
	assert(is_non_sq_l2 == true, "Must be recognized as non-square shape")

	# Verify exterior tile detection on corners of non-square shape
	assert(game.is_exterior_tile(Vector2i(0, 0)) == true, "Corner (0, 0) is exterior void")
	assert(game.is_exterior_tile(Vector2i(1, 0)) == true, "(1, 0) is exterior void")
	assert(game.is_exterior_tile(Vector2i(0, 7)) == true, "Corner (0, 7) is exterior void")
	assert(game.grid.is_wall(Vector2i(0, 0)) == false, "Corner (0, 0) must NOT be a wall")
	assert(game.grid.is_wall(Vector2i(2, 0)) == true, "Wall at (2, 0) must be a single wall")

	# 2. Test non-square Pinwheel Cross layout
	game.grid.load_from_text("  ####  \n###  ###\n#  ..  #\n# $$@$$#\n#  ..  #\n###  ###\n  ####  ")
	print("Loaded non-square pinwheel test grid (width=%d, height=%d)..." % [game.grid.width, game.grid.height])

	var is_non_sq_l6: bool = game.is_level_non_square()
	print("  is_level_non_square: %s" % str(is_non_sq_l6))
	assert(is_non_sq_l6 == true, "Must be recognized as non-square shape")

	# Verify exterior tile detection on corners
	assert(game.is_exterior_tile(Vector2i(0, 0)) == true, "Corner (0, 0) is exterior")
	assert(game.is_exterior_tile(Vector2i(7, 0)) == true, "Corner (7, 0) is exterior")
	assert(game.is_exterior_tile(Vector2i(0, 6)) == true, "Corner (0, 6) is exterior")
	assert(game.is_exterior_tile(Vector2i(7, 6)) == true, "Corner (7, 6) is exterior")

	# Interior floor should NOT be exterior
	assert(game.is_exterior_tile(game.grid.player_pos) == false, "Player position is interior")

	# 3. Test Level 4 (Solid 8x7 rectangle)
	game.load_level(3)
	print("Loaded Level 4 (width=%d, height=%d)..." % [game.grid.width, game.grid.height])
	var is_non_sq_l4: bool = game.is_level_non_square()
	print("  is_level_non_square(Level 4): %s" % str(is_non_sq_l4))
	assert(is_non_sq_l4 == false, "Level 4 must be recognized as solid rectangle")

	# 4. Test queue_redraw pass on non-square layout
	game.grid.load_from_text("  ####  \n###  ###\n#  ..  #\n# $$@$$#\n#  ..  #\n###  ###\n  ####  ")
	game.queue_redraw()

	print("\nSUCCESS: Non-square slim border and empty space removal verified!\n")
	game.free()
	loc.free()
	save.free()
	quit(0)
