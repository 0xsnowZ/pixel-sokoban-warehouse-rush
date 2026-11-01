extends SceneTree

## Headless Unit Test Suite for LocalizationManager and Multi-Language Support.
## Tests PRD Section 10:
## - Supported languages: English (en), French (fr), Arabic (ar)
## - RTL detection (is_rtl)
## - Dynamic language cycling
## - Translation dictionary lookup and sprintf formatting
## - Integration with SaveManager persistence and MainMenu UI updates

const LocalizationManagerScript = preload("res://scripts/localization_manager.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const MainMenuScene = preload("res://scenes/main_menu.tscn")

var passes: int = 0
var fails: int = 0
var current_suite: String = ""


func _init() -> void:
	print("\n" + "=".repeat(54))
	print("  Pixel Porter - Localization Headless Test Suite   ")
	print("=".repeat(54) + "\n")

	test_supported_languages_and_defaults()
	test_translations_lookup()
	test_sprintf_formatting()
	test_language_cycling()
	test_rtl_detection()
	test_save_manager_integration()
	test_main_menu_localization_integration()

	print("\n" + "=".repeat(54))
	print("Localization Results: %d passed, %d failed" % [passes, fails])
	print("=".repeat(54))

	if fails > 0:
		print("FAILURE: %d localization tests failed." % fails)
		quit(1)
	else:
		print("SUCCESS: All localization tests passed!\n")
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


func test_supported_languages_and_defaults() -> void:
	print("--- Running Suite: Supported Languages & Defaults ---")
	var loc: Node = LocalizationManagerScript.new()
	root.add_child(loc)

	assert_true(loc.has_language("en"), "Supports English (en)")
	assert_true(loc.has_language("fr"), "Supports French (fr)")
	assert_true(loc.has_language("ar"), "Supports Arabic (ar)")
	assert_true(not loc.has_language("de"), "German (de) is not supported")

	assert_eq(loc.current_language, "en", "Default language is English")
	assert_eq(loc.get_language_display_name("en"), "English", "Display name for en is English")
	assert_eq(loc.get_language_display_name("fr"), "Français", "Display name for fr is Français")
	assert_eq(loc.get_language_display_name("ar"), "العربية", "Display name for ar is العربية")

	loc.queue_free()


func test_translations_lookup() -> void:
	print("--- Running Suite: Translation Dictionary Lookup ---")
	var loc: Node = LocalizationManagerScript.new()
	root.add_child(loc)

	# English
	loc.set_language("en")
	assert_eq(loc.tr_text("MENU_PLAY"), "PLAY", "EN MENU_PLAY")
	assert_eq(loc.tr_text("BTN_RESTART"), "Restart", "EN BTN_RESTART")
	assert_eq(loc.tr_text("MENU_CREDITS"), "CREDITS", "EN MENU_CREDITS")
	assert_eq(loc.tr_text("MENU_HAPTICS", ["ON"]), "HAPTICS: ON", "EN MENU_HAPTICS")

	# French
	loc.set_language("fr")
	assert_eq(loc.tr_text("MENU_PLAY"), "JOUER", "FR MENU_PLAY")
	assert_eq(loc.tr_text("BTN_RESTART"), "Recommencer", "FR BTN_RESTART")
	assert_eq(loc.tr_text("MENU_CREDITS"), "CRÉDITS", "FR MENU_CREDITS")
	assert_eq(loc.tr_text("MENU_HAPTICS", ["OUI"]), "HAPTIQUE : OUI", "FR MENU_HAPTICS")

	# Arabic
	loc.set_language("ar")
	assert_eq(loc.tr_text("MENU_PLAY"), "ابدأ", "AR MENU_PLAY")
	assert_eq(loc.tr_text("BTN_RESTART"), "إعادة", "AR BTN_RESTART")
	assert_eq(loc.tr_text("MENU_CREDITS"), "حول اللعبة", "AR MENU_CREDITS")
	assert_eq(loc.tr_text("MENU_HAPTICS", ["مفعّل"]), "الاهتزاز: مفعّل", "AR MENU_HAPTICS")

	loc.queue_free()


func test_sprintf_formatting() -> void:
	print("--- Running Suite: Translation Sprintf Interpolation ---")
	var loc: Node = LocalizationManagerScript.new()
	root.add_child(loc)

	# English
	loc.set_language("en")
	assert_eq(loc.tr_text("GAME_LEVEL_LABEL", [2, 10]), "LEVEL 2 / 10", "EN GAME_LEVEL_LABEL formatting")
	assert_eq(loc.tr_text("WIN_TITLE", [3]), "LEVEL 3 COMPLETED!", "EN WIN_TITLE formatting")
	assert_eq(loc.tr_text("RESTART_CONFIRM", [7]), "You've made 7 moves. Restart this level?", "EN RESTART_CONFIRM formatting")

	# French
	loc.set_language("fr")
	assert_eq(loc.tr_text("GAME_LEVEL_LABEL", [2, 10]), "NIVEAU 2 / 10", "FR GAME_LEVEL_LABEL formatting")
	assert_eq(loc.tr_text("WIN_TITLE", [3]), "NIVEAU 3 TERMINÉ !", "FR WIN_TITLE formatting")
	assert_eq(loc.tr_text("RESTART_CONFIRM", [7]), "Vous avez fait 7 mouvements. Recommencer ce niveau ?", "FR RESTART_CONFIRM formatting")

	# Arabic
	loc.set_language("ar")
	assert_eq(loc.tr_text("GAME_LEVEL_LABEL", [2, 10]), "المستوى 2 / 10", "AR GAME_LEVEL_LABEL formatting")
	assert_eq(loc.tr_text("WIN_TITLE", [3]), "اكتمل المستوى 3!", "AR WIN_TITLE formatting")
	assert_eq(loc.tr_text("RESTART_CONFIRM", [7]), "لقد قمت بـ 7 حركة. هل ترغب في إعادة هذا المستوى؟", "AR RESTART_CONFIRM formatting")

	loc.queue_free()


func test_language_cycling() -> void:
	print("--- Running Suite: Dynamic Language Cycling ---")
	var loc: Node = LocalizationManagerScript.new()
	root.add_child(loc)

	loc.set_language("en")
	var next_lang: String = loc.cycle_language()
	assert_eq(next_lang, "fr", "Cycling from en goes to fr")
	assert_eq(loc.current_language, "fr", "Current language is fr")

	next_lang = loc.cycle_language()
	assert_eq(next_lang, "ar", "Cycling from fr goes to ar")
	assert_eq(loc.current_language, "ar", "Current language is ar")

	next_lang = loc.cycle_language()
	assert_eq(next_lang, "en", "Cycling from ar loops back to en")
	assert_eq(loc.current_language, "en", "Current language is en")

	loc.queue_free()


func test_rtl_detection() -> void:
	print("--- Running Suite: RTL Detection ---")
	var loc: Node = LocalizationManagerScript.new()
	root.add_child(loc)

	loc.set_language("en")
	assert_true(not loc.is_rtl(), "English is not RTL")

	loc.set_language("fr")
	assert_true(not loc.is_rtl(), "French is not RTL")

	loc.set_language("ar")
	assert_true(loc.is_rtl(), "Arabic is marked RTL")

	loc.queue_free()


func test_save_manager_integration() -> void:
	print("--- Running Suite: SaveManager Integration ---")
	var save_mgr: Node = SaveManagerScript.new()
	save_mgr.name = "SaveManager"
	root.add_child(save_mgr)

	var loc: Node = LocalizationManagerScript.new()
	loc.name = "LocalizationManager"
	loc.save_mgr = save_mgr
	root.add_child(loc)

	loc.set_language("fr")
	assert_eq(save_mgr.language, "fr", "SaveManager language updated to fr")

	loc.set_language("ar")
	assert_eq(save_mgr.language, "ar", "SaveManager language updated to ar")

	var dict: Dictionary = save_mgr.to_dict()
	assert_eq(dict["settings"]["language"], "ar", "Serialized settings dictionary stores ar")

	loc.queue_free()
	save_mgr.queue_free()


func test_main_menu_localization_integration() -> void:
	print("--- Running Suite: MainMenu UI Dynamic Localization ---")
	var loc: Node = LocalizationManagerScript.new()
	loc.name = "LocalizationManager"
	root.add_child(loc)

	var menu: Control = MainMenuScene.instantiate()
	menu.loc_mgr = loc
	root.add_child(menu)
	menu._ready()

	# In default English
	loc.set_language("en")
	menu._update_menu_state()
	assert_eq(menu.play_btn.text, "PLAY", "Main menu Play button in EN")
	assert_eq(menu.language_btn.text, "LANGUAGE: English", "Language button in EN")

	# Switch to French
	loc.set_language("fr")
	menu._update_menu_state()
	assert_eq(menu.play_btn.text, "JOUER", "Main menu Play button in FR")
	assert_eq(menu.language_btn.text, "LANGUE : Français", "Language button in FR")

	# Switch to Arabic
	loc.set_language("ar")
	menu._update_menu_state()
	assert_eq(menu.play_btn.text, "ابدأ", "Main menu Play button in AR")
	assert_eq(menu.language_btn.text, "اللغة: العربية", "Language button in AR")

	menu.queue_free()
	loc.queue_free()
