extends SceneTree

## Headless Unit Test Suite for Campaign End Screen (scenes/end_screen.tscn & scenes/end_screen.gd).
## Tests PRD Section 6 requirement:
## - "End screen after level 50: a thank-you message and 'more levels coming soon'."
## - Overall campaign statistics calculation
## - Multi-language dynamic localization (EN, FR, AR)
## - Replay / Level select and Menu navigation buttons
## - Continuous celebratory particles simulation and rendering

const EndScreenScene = preload("res://scenes/end_screen.tscn")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const LocalizationManagerScript = preload("res://scripts/localization_manager.gd")

var passes: int = 0
var fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(56))
	print("   Pixel Porter - End Screen Headless Test Suite   ")
	print("=".repeat(56) + "\n")

	test_end_screen_initialization()
	test_campaign_statistics_aggregation()
	test_localization_support()
	test_particle_simulation()

	print("\n" + "=".repeat(56))
	print("End Screen Results: %d passed, %d failed" % [passes, fails])
	print("=".repeat(56))

	if fails > 0:
		print("FAILURE: %d End Screen tests failed." % fails)
		quit(1)
	else:
		print("SUCCESS: All End Screen tests passed!\n")
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


func create_test_end_screen(loc_node: Node = null, save_node: Node = null) -> Control:
	var end_screen: Control = EndScreenScene.instantiate()
	if loc_node:
		end_screen.loc_mgr = loc_node
	if save_node:
		end_screen.save_mgr = save_node
	root.add_child(end_screen)
	end_screen._ready()
	return end_screen


func test_end_screen_initialization() -> void:
	print("--- Running Suite: End Screen Initialization & Views ---")
	var end_screen: Control = create_test_end_screen()

	assert_true(end_screen.title_label != null, "Title label initialized")
	assert_true(end_screen.thanks_label != null, "Thanks label initialized")
	assert_true(end_screen.stats_label != null, "Stats label initialized")
	assert_true(end_screen.more_levels_label != null, "More levels label initialized")
	assert_true(end_screen.level_select_btn != null, "Level select button initialized")
	assert_true(end_screen.menu_btn != null, "Menu button initialized")

	assert_true(end_screen.more_levels_label.text.contains("More levels coming soon"), "Displays PRD 'more levels coming soon' message")
	assert_true(end_screen.thanks_label.text.contains("Thank you for playing"), "Displays PRD thank-you message")

	end_screen.free()


func test_campaign_statistics_aggregation() -> void:
	print("--- Running Suite: Campaign Statistics Aggregation ---")
	var save_mgr: Node = SaveManagerScript.new()

	# Simulate completing all 75 levels with 10 moves and 5 pushes each
	for i in range(75):
		save_mgr.completed_levels[str(i)] = {
			"best_moves": 10,
			"best_pushes": 5
		}

	var end_screen: Control = create_test_end_screen(null, save_mgr)

	assert_true(end_screen.stats_label.text.contains("75 / 75"), "Stats displays 75 / 75 levels solved")
	assert_true(end_screen.stats_label.text.contains("750"), "Stats displays total 750 moves (75 * 10)")
	assert_true(end_screen.stats_label.text.contains("375"), "Stats displays total 375 pushes (75 * 5)")

	end_screen.free()
	save_mgr.free()


func test_localization_support() -> void:
	print("--- Running Suite: Multi-Language Localization ---")
	var loc: Node = LocalizationManagerScript.new()
	var end_screen: Control = create_test_end_screen(loc)

	# English
	loc.set_language("en")
	end_screen._update_ui()
	assert_eq(end_screen.title_label.text, "CAMPAIGN COMPLETED!", "EN Title label")
	assert_true(end_screen.thanks_label.text.contains("Thank you for playing"), "EN Thanks label")

	# French
	loc.set_language("fr")
	end_screen._update_ui()
	assert_eq(end_screen.title_label.text, "CAMPAGNE TERMINÉE !", "FR Title label")
	assert_true(end_screen.thanks_label.text.contains("Merci d'avoir joué"), "FR Thanks label")
	assert_true(end_screen.more_levels_label.text.contains("Plus de niveaux"), "FR More levels label")

	# Arabic
	loc.set_language("ar")
	end_screen._update_ui()
	assert_eq(end_screen.title_label.text, "اكتملت الحملة بنجاح!", "AR Title label")
	assert_true(end_screen.thanks_label.text.contains("شكراً لك"), "AR Thanks label")
	assert_true(end_screen.more_levels_label.text.contains("المزيد من المستويات"), "AR More levels label")

	end_screen.free()
	loc.free()


func test_particle_simulation() -> void:
	print("--- Running Suite: Particle Simulation & Draw ---")
	var end_screen: Control = create_test_end_screen()

	assert_true(end_screen.celebration_particles.size() > 0, "Initial confetti burst spawned")

	var initial_count: int = end_screen.celebration_particles.size()
	end_screen._process(0.1)
	assert_true(end_screen.celebration_particles.size() > 0, "Particles active during process")

	end_screen.free()
