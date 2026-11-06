extends SceneTree

## Headless Unit Test Suite for SafeAreaManager & Android Export Presets (PRD Sections 5, 8, 9 & 11).
## Tests:
## - Safe Area hardware API capability detection and safe insets retrieval
## - Cutout / notch simulation for headless and device verification
## - MarginContainer theme override calculations (TopBar, BottomBar)
## - Responsive in-game board repositioning in safe zones
## - Verification of export_presets.cfg Android settings (package name, portrait lock, permissions)

const SafeAreaManagerScript = preload("res://scripts/safe_area_manager.gd")
const GameScene = preload("res://scenes/game.tscn")

var passes: int = 0
var fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(56))
	print("   Pixel Porter - Safe Area & Export Presets Test Suite   ")
	print("=".repeat(56) + "\n")

	test_safe_area_initialization()
	test_simulated_cutouts_and_signals()
	test_margin_container_application()
	test_game_scene_notch_repositioning()
	test_export_presets_configuration()

	print("\n" + "=".repeat(56))
	print("Safe Area Results: %d passed, %d failed" % [passes, fails])
	print("=".repeat(56))

	if fails > 0:
		print("FAILURE: %d Safe Area tests failed." % fails)
		quit(1)
	else:
		print("SUCCESS: All Safe Area tests passed!\n")
		quit(0)


func assert_true(cond: bool, msg: String) -> void:
	if cond:
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


func test_safe_area_initialization() -> void:
	print("--- Running Suite: Safe Area Initialization & Defaults ---")
	var mgr: Node = SafeAreaManagerScript.new()
	root.add_child(mgr)

	var insets: Dictionary = mgr.get_safe_insets()
	assert_true(insets.has("top"), "Insets dictionary contains 'top'")
	assert_true(insets.has("bottom"), "Insets dictionary contains 'bottom'")
	assert_true(insets.has("left"), "Insets dictionary contains 'left'")
	assert_true(insets.has("right"), "Insets dictionary contains 'right'")

	# In desktop/headless environment without physical notch
	assert_eq(insets["top"], 0.0, "Default top inset in headless mode is 0.0")
	assert_eq(insets["bottom"], 0.0, "Default bottom inset in headless mode is 0.0")

	mgr.queue_free()


func test_simulated_cutouts_and_signals() -> void:
	print("--- Running Suite: Simulated Cutouts & Change Signals ---")
	var mgr: Node = SafeAreaManagerScript.new()
	root.add_child(mgr)

	var signal_captured: Array[Dictionary] = []
	mgr.safe_area_changed.connect(func(data: Dictionary): signal_captured.append(data))

	# Simulate a modern punch-hole cutout (e.g. 52px top notch, 34px gesture bar)
	mgr.simulate_insets(52.0, 34.0, 0.0, 0.0)
	var insets: Dictionary = mgr.get_safe_insets()

	assert_eq(insets["top"], 52.0, "Simulated top notch is 52.0")
	assert_eq(insets["bottom"], 34.0, "Simulated bottom gesture bar is 34.0")
	assert_eq(signal_captured.size(), 1, "safe_area_changed signal emitted on simulation")
	assert_eq(signal_captured[0]["top"], 52.0, "Signal delivered 52.0 top inset")

	# Clear simulation
	mgr.clear_simulation()
	var cleared_insets: Dictionary = mgr.get_safe_insets()
	assert_eq(cleared_insets["top"], 0.0, "Cleared top inset reset to 0.0")
	assert_eq(signal_captured.size(), 2, "safe_area_changed signal emitted on clear")

	mgr.queue_free()


func test_margin_container_application() -> void:
	print("--- Running Suite: MarginContainer Inset Adjustments ---")
	var mgr: Node = SafeAreaManagerScript.new()
	root.add_child(mgr)

	# Simulate 48px notch and 36px bottom bar
	mgr.simulate_insets(48.0, 36.0, 8.0, 8.0)

	var container: MarginContainer = MarginContainer.new()
	root.add_child(container)

	# Apply to TopBar: pads top and sides, leaves bottom untouched
	mgr.apply_safe_area_margins(container, 16, 10, 16, 10, true, false)
	assert_eq(container.get_theme_constant("margin_top"), 10 + 48, "TopBar margin_top padded by 48px notch")
	assert_eq(container.get_theme_constant("margin_bottom"), 10, "TopBar margin_bottom unchanged")
	assert_eq(container.get_theme_constant("margin_left"), 16 + 8, "TopBar margin_left padded by 8px")

	# Apply to BottomBar: pads bottom and sides, leaves top untouched
	mgr.apply_safe_area_margins(container, 16, 10, 16, 10, false, true)
	assert_eq(container.get_theme_constant("margin_top"), 10, "BottomBar margin_top unchanged")
	assert_eq(container.get_theme_constant("margin_bottom"), 10 + 36, "BottomBar margin_bottom padded by 36px bar")

	container.queue_free()
	mgr.queue_free()


func test_game_scene_notch_repositioning() -> void:
	print("--- Running Suite: Game Scene Playable Area Repositioning ---")
	var game: Node = GameScene.instantiate()
	root.add_child(game)
	game._ready()

	var mgr: Node = SafeAreaManagerScript.new()
	root.add_child(mgr)
	game.safe_area_mgr = mgr

	# Base layout with 0 notch
	mgr.simulate_insets(0.0, 0.0, 0.0, 0.0)
	game.load_level(0)
	game.calculate_layout(Vector2(540, 960))
	var base_origin_y: float = game.grid_origin.y

	# Layout with 60px notch
	mgr.simulate_insets(60.0, 0.0, 0.0, 0.0)
	game.calculate_layout(Vector2(540, 960))
	var notch_origin_y: float = game.grid_origin.y

	assert_true(notch_origin_y > base_origin_y, "Board origin shifts down when top notch is present")
	assert_eq(notch_origin_y - base_origin_y, 30.0, "Board origin centered proportionally in reduced safe space")

	game.queue_free()
	mgr.queue_free()


func test_export_presets_configuration() -> void:
	print("--- Running Suite: Android Export Presets Validation ---")
	var file_path: String = "res://export_presets.cfg"
	assert_true(FileAccess.file_exists(file_path), "export_presets.cfg exists on disk")

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	assert_true(file != null, "Successfully opened export_presets.cfg")

	var content: String = file.get_as_text()
	file.close()

	assert_true(content.contains("platform=\"Android\""), "Target platform is Android")
	assert_true(content.contains("package/unique_name=\"com.snowz.pixelsokoban\"") or content.contains("package/unique_name=\"com.pixelporter.game\""), "Package name is configured")
	assert_true(content.contains("package/name=\"Pixel Sokoban: Warehouse Rush\""), "Application name is Pixel Sokoban: Warehouse Rush")
	assert_true(content.contains("screen/orientation=1"), "Screen orientation locked to Portrait (1)")
	assert_true(content.contains("screen/immersive_mode=true"), "Immersive mode enabled")
	assert_true(content.contains("permissions/vibrate=true"), "Haptics permission enabled (permissions/vibrate)")
	assert_true(content.contains("permissions/internet=true"), "AdMob network permission enabled (permissions/internet)")
	assert_true(content.contains("include_filter=\"*.sok"), "Include filter bundles .sok level files")
