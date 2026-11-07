extends SceneTree

## Unit test suite for Pixel Porter Splash Screen & Boot Splash Branding.
## Verifies PRD Section 6 screen #1 and Godot project boot splash configuration.
## Run via: godot --headless --path . -s tests/test_splash_screen.gd

const SplashScreenScene = preload("res://scenes/splash_screen.tscn")

var _passed_suites: int = 0
var _failed_suites: int = 0
var _total_assertions: int = 0
var _failed_assertions: int = 0


func _init() -> void:
	print("==================================================")
	print("    Pixel Porter - Splash Screen Headless Tests   ")
	print("==================================================")

	run_suite("Project Boot Splash Configuration", test_boot_splash_settings)
	run_suite("Splash Screen Scene Node Hierarchy & Assets", test_splash_scene_structure)
	run_suite("Splash Loading Progress & Localization", test_splash_loading_logic)
	run_suite("Splash Skip & Transition Logic", test_splash_skip_logic)
	run_suite("Splash Mobile Safe Area & Aspect Ratio Adaptation", test_splash_mobile_adaptation)

	print("\n==================================================")
	print("Test Suites: %d passed, %d failed" % [_passed_suites, _failed_suites])
	print("Assertions : %d total, %d failed" % [_total_assertions, _failed_assertions])
	print("==================================================")

	if _failed_assertions > 0 or _failed_suites > 0:
		printerr("FAILED: Splash Screen test suite had failures.")
		quit(1)
	else:
		print("SUCCESS: All Splash Screen tests passed!")
		quit(0)


func run_suite(suite_name: String, callable: Callable) -> void:
	print("\n--- Running Suite: %s ---" % suite_name)
	var prev_fails: int = _failed_assertions
	callable.call()
	if _failed_assertions == prev_fails:
		_passed_suites += 1
		print("    Suite PASSED")
	else:
		_failed_suites += 1
		print("    Suite FAILED")


func assert_true(condition: bool, message: String) -> void:
	_total_assertions += 1
	if not condition:
		_failed_assertions += 1
		printerr("  [FAIL] %s" % message)
	else:
		print("  [PASS] %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_total_assertions += 1
	if actual != expected:
		_failed_assertions += 1
		printerr("  [FAIL] %s (Expected: %s, Got: %s)" % [message, str(expected), str(actual)])
	else:
		print("  [PASS] %s" % message)


func test_boot_splash_settings() -> void:
	var boot_img: String = ProjectSettings.get_setting("application/boot_splash/image", "")
	assert_eq(boot_img, "res://assets/splash.png", "Boot splash image is set to res://assets/splash.png")

	var boot_bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	assert_true(boot_bg.r < 0.1 and boot_bg.b < 0.1, "Boot splash bg_color is deep navy/black palette")

	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(main_scene, "res://scenes/splash_screen.tscn", "Main scene starts on splash screen")

	var stretch_mode: int = ProjectSettings.get_setting("application/boot_splash/stretch_mode", 0)
	assert_eq(stretch_mode, 1, "Boot splash stretch mode is set to Keep (1)")


func test_splash_scene_structure() -> void:
	var splash = SplashScreenScene.instantiate()
	assert_true(splash != null, "SplashScreen instantiated successfully")

	var base_col = splash.get_node_or_null("BaseColor")
	assert_true(base_col != null, "BaseColor ColorRect exists for seamless startup")

	var bg = splash.get_node_or_null("Background")
	assert_true(bg != null, "Background TextureRect exists")
	assert_true(bg.texture != null, "Background has valid texture assigned")
	assert_eq(bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Background uses STRETCH_KEEP_ASPECT_COVERED (5) for fullscreen mobile display")

	var bar = splash.get_node_or_null("Margin/BottomVBox/LoadingBar")
	assert_true(bar != null, "Loading ProgressBar exists")

	var status = splash.get_node_or_null("Margin/BottomVBox/StatusLabel")
	assert_true(status != null, "StatusLabel exists")

	var prompt = splash.get_node_or_null("Margin/BottomVBox/PromptLabel")
	assert_true(prompt != null, "PromptLabel exists")

	var overlay = splash.get_node_or_null("FadeOverlay")
	assert_true(overlay != null, "FadeOverlay exists")

	splash.free()


func test_splash_loading_logic() -> void:
	var splash = SplashScreenScene.instantiate()
	root.add_child(splash)
	splash._ready()

	# Initial progress
	assert_eq(splash.progress_bar.value, 0.0, "Progress bar starts at 0.0")

	# Simulate progress callbacks
	splash._on_progress_update(25.0)
	assert_eq(splash.progress_bar.value, 25.0, "Progress bar updated to 25.0")
	assert_true(splash.status_label.text.length() > 0, "Status label populated at 25%")

	splash._on_progress_update(75.0)
	assert_eq(splash.progress_bar.value, 75.0, "Progress bar updated to 75.0")

	splash._on_progress_update(100.0)
	assert_eq(splash.progress_bar.value, 100.0, "Progress bar reaches 100.0")

	splash.free()


func test_splash_skip_logic() -> void:
	var splash = SplashScreenScene.instantiate()
	root.add_child(splash)
	splash._ready()

	assert_true(not splash._is_transitioning, "Not transitioning initially")

	# Test skip
	splash.skip_to_main_menu()
	assert_true(splash._is_transitioning, "skip_to_main_menu() initiates transition")

	splash.free()


func test_splash_mobile_adaptation() -> void:
	var splash = SplashScreenScene.instantiate()
	root.add_child(splash)
	splash._ready()

	assert_true(splash.dust_motes.size() >= 24, "Dust motes spawned across screen")

	# Simulate safe area cutout (e.g. 36px bottom navigation gesture bar)
	var simulated_insets: Dictionary = { "bottom": 36.0, "left": 12.0, "right": 12.0, "top": 48.0 }
	splash._on_safe_area_changed(simulated_insets)

	var margin_bottom: int = splash.margin.get_theme_constant("margin_bottom")
	assert_true(margin_bottom >= 52, "Margin bottom elevates above 36px gesture bar (got %d)" % margin_bottom)

	var margin_left: int = splash.margin.get_theme_constant("margin_left")
	assert_true(margin_left >= 48, "Margin left provides safe inset padding (got %d)" % margin_left)

	splash.free()
