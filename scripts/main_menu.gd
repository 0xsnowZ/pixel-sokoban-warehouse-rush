extends Control

## Main menu and Level Select controller for Pixel Porter.
## Implements PRD Section 6 flow:
## - Continue / Play navigation
## - Level select 50-level grid with locked/completed visual states
## - Sound on/off toggle persisted via SaveManager
## - Credits popup

const SaveManagerScript = preload("res://scripts/save_manager.gd")
const AchievementManagerScript = preload("res://scripts/achievement_manager.gd")
const TOTAL_LEVELS_COUNT: int = 50
const AVAILABLE_LEVELS_COUNT: int = 50 # All 50 verified solvable levels active

# Enhanced High-Resolution UI Icon Textures
var icon_trophy: Texture2D = preload("res://assets/icons/icon_trophy.png")
var icon_settings: Texture2D = preload("res://assets/icons/icon_settings.png")
var icon_locker: Texture2D = preload("res://assets/icons/icon_locker.png")
var icon_star_full: Texture2D = preload("res://assets/icons/icon_star_full.png")
var icon_lock: Texture2D = preload("res://assets/icons/icon_lock.png")
var icon_play: Texture2D = preload("res://assets/icons/icon_play.png")
var icon_check: Texture2D = preload("res://assets/icons/icon_check.png")

var save_mgr: Node = null
var audio_mgr: Node = null
var loc_mgr: Node = null
var haptic_mgr: Node = null
var safe_area_mgr: Node = null
var achievement_mgr: Node = null

# Node references
@onready var main_view: VBoxContainer = $MainView
@onready var level_select_view: VBoxContainer = $LevelSelectView
@onready var credits_modal: PanelContainer = $CreditsModal
@onready var settings_modal: PanelContainer = find_child("SettingsModal", true, false) as PanelContainer

# Main View buttons
@onready var continue_btn: Button = _find_button("ContinueBtn", "MainView/BottomMargin/ActionDeck/ContinueBtn")
@onready var play_btn: Button = _find_button("PlayBtn", "MainView/BottomMargin/ActionDeck/PlayBtn")
@onready var level_select_btn: Button = _find_button("LevelSelectBtn", "MainView/BottomMargin/ActionDeck/DualDeck/LevelSelectBtn")
@onready var settings_btn: Button = _find_button("SettingsBtn", "MainView/TopBarMargin/HBox/QuickBar/SettingsBtn")
@onready var sound_btn: Button = _find_button("SoundToggleBtn", "SettingsModal/Margin/VBox/SfxBox/SoundToggleBtn")
@onready var haptics_btn: Button = _find_button("HapticsToggleBtn", "SettingsModal/Margin/VBox/HapticsToggleBtn")
@onready var language_btn: Button = _find_button("LanguageBtn", "SettingsModal/Margin/VBox/LanguageBtn")
@onready var credits_btn: Button = _find_button("CreditsBtn", "SettingsModal/Margin/VBox/CreditsBtn")
@onready var locker_btn: Button = _find_button("LockerBtn", "MainView/BottomMargin/ActionDeck/DualDeck/LockerBtn")
@onready var locker_modal: PanelContainer = find_child("LockerModal", true, false) as PanelContainer
@onready var outfits_tab_btn: Button = _find_button("OutfitsTabBtn", "LockerModal/Margin/VBox/TabsHBox/OutfitsTabBtn")
@onready var crates_tab_btn: Button = _find_button("CratesTabBtn", "LockerModal/Margin/VBox/TabsHBox/CratesTabBtn")
@onready var close_locker_btn: Button = _find_button("CloseLockerBtn", "LockerModal/Margin/VBox/CloseLockerBtn")
@onready var locker_title_label: Label = find_child("LockerModal", true, false).find_child("Title", true, false) as Label if find_child("LockerModal", true, false) else null
@onready var locker_stars_badge: Label = find_child("LockerModal", true, false).find_child("StarsBadge", true, false) as Label if find_child("LockerModal", true, false) else null
@onready var locker_items_vbox: VBoxContainer = find_child("LockerModal", true, false).find_child("ItemsVBox", true, false) as VBoxContainer if find_child("LockerModal", true, false) else null
@onready var star_progress_btn: Button = _find_button("StarProgressBtn", "MainView/TopBarMargin/HBox/StarProgressBtn")
@onready var quick_lang_btn: Button = _find_button("QuickLangBtn", "MainView/TopBarMargin/HBox/QuickBar/QuickLangBtn")

var current_locker_tab: String = "outfits"
var current_level_pulse_tw: Tween = null

# Achievements elements (Phase 4)
@onready var achievements_btn: Button = _find_button("AchievementsBtn", "MainView/TopBarMargin/HBox/QuickBar/AchievementsBtn")
@onready var achievements_modal: PanelContainer = find_child("AchievementsModal", true, false) as PanelContainer
@onready var close_achievements_btn: Button = _find_button("CloseAchievementsBtn", "AchievementsModal/Margin/VBox/CloseAchievementsBtn")
@onready var achievements_title_label: Label = find_child("AchievementsModal", true, false).find_child("Title", true, false) as Label if find_child("AchievementsModal", true, false) else null
@onready var achievements_counter_badge: Label = find_child("AchievementsModal", true, false).find_child("CounterBadge", true, false) as Label if find_child("AchievementsModal", true, false) else null
@onready var achievements_items_vbox: VBoxContainer = find_child("AchievementsModal", true, false).find_child("ItemsVBox", true, false) as VBoxContainer if find_child("AchievementsModal", true, false) else null

# Settings elements
@onready var music_vol_label: Label = find_child("MusicVolLabel", true, false) as Label
@onready var music_slider: HSlider = find_child("MusicSlider", true, false) as HSlider
@onready var music_toggle_btn: Button = _find_button("MusicToggleBtn", "SettingsModal/Margin/VBox/MusicBox/MusicToggleBtn")
@onready var track_label: Label = find_child("TrackLabel", true, false) as Label
@onready var track_cycle_btn: Button = _find_button("TrackCycleBtn", "SettingsModal/Margin/VBox/TrackBox/TrackCycleBtn")
@onready var sfx_vol_label: Label = find_child("SfxVolLabel", true, false) as Label
@onready var sfx_slider: HSlider = find_child("SfxSlider", true, false) as HSlider
@onready var close_settings_btn: Button = _find_button("CloseSettingsBtn", "SettingsModal/Margin/VBox/CloseSettingsBtn")
@onready var control_mode_btn: Button = _find_button("ControlModeBtn", "SettingsModal/Margin/VBox/ControlBox/ControlModeBtn")

# Level Select elements
@onready var level_grid: GridContainer = find_child("LevelGrid", true, false) as GridContainer
@onready var back_btn: Button = _find_button("BackBtn", "LevelSelectView/TopBar/Margin/HBox/BackBtn")
@onready var close_credits_btn: Button = _find_button("CloseCreditsBtn", "CreditsModal/VBox/CloseCreditsBtn")


func _find_button(btn_name: String, fallback_path: String) -> Button:
	var b: Button = find_child(btn_name, true, false) as Button
	if b != null:
		return b
	if has_node(fallback_path):
		return get_node(fallback_path) as Button
	return null


func _initialize_nodes() -> void:
	if main_view == null and has_node("MainView"):
		main_view = $MainView
		level_select_view = $LevelSelectView
		credits_modal = $CreditsModal
		settings_modal = find_child("SettingsModal", true, false) as PanelContainer
		continue_btn = _find_button("ContinueBtn", "MainView/BottomMargin/ActionDeck/ContinueBtn")
		play_btn = _find_button("PlayBtn", "MainView/BottomMargin/ActionDeck/PlayBtn")
		level_select_btn = _find_button("LevelSelectBtn", "MainView/BottomMargin/ActionDeck/DualDeck/LevelSelectBtn")
		settings_btn = _find_button("SettingsBtn", "MainView/TopBarMargin/HBox/QuickBar/SettingsBtn")
		sound_btn = _find_button("SoundToggleBtn", "SettingsModal/Margin/VBox/SfxBox/SoundToggleBtn")
		haptics_btn = _find_button("HapticsToggleBtn", "SettingsModal/Margin/VBox/HapticsToggleBtn")
		language_btn = _find_button("LanguageBtn", "SettingsModal/Margin/VBox/LanguageBtn")
		credits_btn = _find_button("CreditsBtn", "SettingsModal/Margin/VBox/CreditsBtn")
		music_vol_label = find_child("MusicVolLabel", true, false) as Label
		music_slider = find_child("MusicSlider", true, false) as HSlider
		music_toggle_btn = _find_button("MusicToggleBtn", "SettingsModal/Margin/VBox/MusicBox/MusicToggleBtn")
		track_label = find_child("TrackLabel", true, false) as Label
		track_cycle_btn = _find_button("TrackCycleBtn", "SettingsModal/Margin/VBox/TrackBox/TrackCycleBtn")
		sfx_vol_label = find_child("SfxVolLabel", true, false) as Label
		sfx_slider = find_child("SfxSlider", true, false) as HSlider
		close_settings_btn = _find_button("CloseSettingsBtn", "SettingsModal/Margin/VBox/CloseSettingsBtn")
		control_mode_btn = _find_button("ControlModeBtn", "SettingsModal/Margin/VBox/ControlBox/ControlModeBtn")
		level_grid = find_child("LevelGrid", true, false) as GridContainer
		back_btn = _find_button("BackBtn", "LevelSelectView/TopBar/Margin/HBox/BackBtn")
		close_credits_btn = _find_button("CloseCreditsBtn", "CreditsModal/VBox/CloseCreditsBtn")
		locker_modal = find_child("LockerModal", true, false) as PanelContainer
		locker_btn = _find_button("LockerBtn", "MainView/BottomMargin/ActionDeck/DualDeck/LockerBtn")
		outfits_tab_btn = _find_button("OutfitsTabBtn", "LockerModal/Margin/VBox/TabsHBox/OutfitsTabBtn")
		crates_tab_btn = _find_button("CratesTabBtn", "LockerModal/Margin/VBox/TabsHBox/CratesTabBtn")
		close_locker_btn = _find_button("CloseLockerBtn", "LockerModal/Margin/VBox/CloseLockerBtn")
		achievements_modal = find_child("AchievementsModal", true, false) as PanelContainer
		achievements_btn = _find_button("AchievementsBtn", "MainView/TopBarMargin/HBox/QuickBar/AchievementsBtn")
		close_achievements_btn = _find_button("CloseAchievementsBtn", "AchievementsModal/Margin/VBox/CloseAchievementsBtn")
		star_progress_btn = _find_button("StarProgressBtn", "MainView/TopBarMargin/HBox/StarProgressBtn")
		quick_lang_btn = _find_button("QuickLangBtn", "MainView/TopBarMargin/HBox/QuickBar/QuickLangBtn")
		if locker_modal != null:
			locker_title_label = locker_modal.find_child("Title", true, false) as Label
			locker_stars_badge = locker_modal.find_child("StarsBadge", true, false) as Label
			locker_items_vbox = locker_modal.find_child("ItemsVBox", true, false) as VBoxContainer
		if achievements_modal != null:
			achievements_title_label = achievements_modal.find_child("Title", true, false) as Label
			achievements_counter_badge = achievements_modal.find_child("CounterBadge", true, false) as Label
			achievements_items_vbox = achievements_modal.find_child("ItemsVBox", true, false) as VBoxContainer


func _ready() -> void:
	_initialize_nodes()
	if is_inside_tree() and get_tree().root.has_node("SaveManager"):
		save_mgr = get_tree().root.get_node("SaveManager")
	else:
		save_mgr = SaveManagerScript.new()
		add_child(save_mgr)

	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		audio_mgr = get_tree().root.get_node("AudioManager")

	if is_inside_tree() and get_tree().root.has_node("LocalizationManager"):
		loc_mgr = get_tree().root.get_node("LocalizationManager")

	if is_inside_tree() and get_tree().root.has_node("HapticManager"):
		haptic_mgr = get_tree().root.get_node("HapticManager")

	if is_inside_tree() and get_tree().root.has_node("AchievementManager"):
		achievement_mgr = get_tree().root.get_node("AchievementManager")
	else:
		var ach_script = load("res://scripts/achievement_manager.gd")
		if ach_script:
			achievement_mgr = ach_script.new()
			achievement_mgr.save_mgr = save_mgr
			add_child(achievement_mgr)

	if is_inside_tree() and get_tree().root.has_node("SafeAreaManager"):
		safe_area_mgr = get_tree().root.get_node("SafeAreaManager")
		safe_area_mgr.safe_area_changed.connect(_on_safe_area_changed)
		_apply_safe_area()

	if not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)
	if not play_btn.pressed.is_connected(_on_play_pressed):
		play_btn.pressed.connect(_on_play_pressed)
	if not level_select_btn.pressed.is_connected(_show_level_select):
		level_select_btn.pressed.connect(_show_level_select)
	if sound_btn and not sound_btn.pressed.is_connected(_on_sound_toggle_pressed):
		sound_btn.pressed.connect(_on_sound_toggle_pressed)
	if haptics_btn and not haptics_btn.pressed.is_connected(_on_haptics_toggle_pressed):
		haptics_btn.pressed.connect(_on_haptics_toggle_pressed)
	if not language_btn.pressed.is_connected(_on_language_pressed):
		language_btn.pressed.connect(_on_language_pressed)
	if not credits_btn.pressed.is_connected(_show_credits):
		credits_btn.pressed.connect(_show_credits)
	if settings_btn and not settings_btn.pressed.is_connected(_show_settings):
		settings_btn.pressed.connect(_show_settings)
	if close_settings_btn and not close_settings_btn.pressed.is_connected(_hide_settings):
		close_settings_btn.pressed.connect(_hide_settings)
	if control_mode_btn and not control_mode_btn.pressed.is_connected(_on_control_mode_pressed):
		control_mode_btn.pressed.connect(_on_control_mode_pressed)
	if music_slider and not music_slider.value_changed.is_connected(_on_music_slider_changed):
		music_slider.value_changed.connect(_on_music_slider_changed)
	if music_toggle_btn and not music_toggle_btn.pressed.is_connected(_on_music_toggle_pressed):
		music_toggle_btn.pressed.connect(_on_music_toggle_pressed)
	if track_cycle_btn and not track_cycle_btn.pressed.is_connected(_on_track_cycle_pressed):
		track_cycle_btn.pressed.connect(_on_track_cycle_pressed)
	if sfx_slider and not sfx_slider.value_changed.is_connected(_on_sfx_slider_changed):
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if not back_btn.pressed.is_connected(_show_main_view):
		back_btn.pressed.connect(_show_main_view)
	if not close_credits_btn.pressed.is_connected(_hide_credits):
		close_credits_btn.pressed.connect(_hide_credits)
	if locker_btn and not locker_btn.pressed.is_connected(_show_locker):
		locker_btn.pressed.connect(_show_locker)
	if close_locker_btn and not close_locker_btn.pressed.is_connected(_hide_locker):
		close_locker_btn.pressed.connect(_hide_locker)
	if outfits_tab_btn and not outfits_tab_btn.pressed.is_connected(_switch_locker_tab.bind("outfits")):
		outfits_tab_btn.pressed.connect(_switch_locker_tab.bind("outfits"))
	if crates_tab_btn and not crates_tab_btn.pressed.is_connected(_switch_locker_tab.bind("crates")):
		crates_tab_btn.pressed.connect(_switch_locker_tab.bind("crates"))
	if achievements_btn and not achievements_btn.pressed.is_connected(_show_achievements):
		achievements_btn.pressed.connect(_show_achievements)
	if close_achievements_btn and not close_achievements_btn.pressed.is_connected(_hide_achievements):
		close_achievements_btn.pressed.connect(_hide_achievements)
	if star_progress_btn and not star_progress_btn.pressed.is_connected(_show_level_select):
		star_progress_btn.pressed.connect(_show_level_select)
	if quick_lang_btn and not quick_lang_btn.pressed.is_connected(_on_language_pressed):
		quick_lang_btn.pressed.connect(_on_language_pressed)

	# Enhanced UI Icons on Main Menu
	if achievements_btn:
		achievements_btn.icon = icon_trophy
		achievements_btn.expand_icon = true
		achievements_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		achievements_btn.text = ""
		achievements_btn.add_theme_constant_override("icon_max_width", 24)
	if settings_btn:
		settings_btn.icon = icon_settings
		settings_btn.expand_icon = true
		settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		settings_btn.text = ""
		settings_btn.add_theme_constant_override("icon_max_width", 24)
	if locker_btn:
		locker_btn.icon = icon_locker
		locker_btn.expand_icon = true
		locker_btn.add_theme_constant_override("icon_max_width", 22)
		locker_btn.add_theme_constant_override("h_separation", 8)
	if star_progress_btn:
		star_progress_btn.icon = icon_star_full
		star_progress_btn.expand_icon = true
		star_progress_btn.add_theme_constant_override("icon_max_width", 20)
		star_progress_btn.add_theme_constant_override("h_separation", 8)
	if continue_btn:
		continue_btn.icon = null
	if play_btn:
		play_btn.icon = null

	_show_main_view()
	_update_menu_state()
	_build_level_grid()

	# Ambient breathing animation on logo and subtitle
	var logo: TextureRect = find_child("LogoRect", true, false) as TextureRect
	if logo != null:
		logo.pivot_offset = Vector2(150, 84)
		var tw: Tween = create_tween().set_loops()
		tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(logo, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var subtitle: Label = find_child("GameSubtitle", true, false) as Label
	if subtitle != null:
		var sub_tw: Tween = create_tween().set_loops()
		sub_tw.tween_property(subtitle, "modulate:a", 0.72, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sub_tw.tween_property(subtitle, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Tactile arcade button physics
	for b in [continue_btn, play_btn, level_select_btn, locker_btn, achievements_btn, settings_btn, sound_btn, haptics_btn, language_btn, credits_btn, back_btn, close_credits_btn, close_settings_btn, close_locker_btn, close_achievements_btn, outfits_tab_btn, crates_tab_btn, music_toggle_btn, track_cycle_btn, control_mode_btn, star_progress_btn, quick_lang_btn]:
		if b != null:
			_attach_spring_physics(b)


func _apply_safe_area() -> void:
	if safe_area_mgr != null:
		if has_node("LevelSelectView/TopBar/Margin"):
			var level_top_bar: MarginContainer = get_node("LevelSelectView/TopBar/Margin") as MarginContainer
			if level_top_bar != null:
				safe_area_mgr.apply_safe_area_margins(level_top_bar, 16, 12, 16, 12, true, false)
		if has_node("MainView/TopBarMargin"):
			var main_top_bar: MarginContainer = get_node("MainView/TopBarMargin") as MarginContainer
			if main_top_bar != null:
				safe_area_mgr.apply_safe_area_margins(main_top_bar, 20, 20, 20, 0, true, false)
		if has_node("MainView/BottomMargin"):
			var main_bottom: MarginContainer = get_node("MainView/BottomMargin") as MarginContainer
			if main_bottom != null:
				safe_area_mgr.apply_safe_area_margins(main_bottom, 32, 0, 32, 24, false, true)


func _on_safe_area_changed(_insets: Dictionary) -> void:
	_apply_safe_area()


func _show_main_view() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if current_level_pulse_tw != null and current_level_pulse_tw.is_valid():
		current_level_pulse_tw.kill()
		current_level_pulse_tw = null
	main_view.show()
	level_select_view.hide()
	credits_modal.hide()
	if settings_modal:
		settings_modal.hide()
	if locker_modal:
		locker_modal.hide()
	if achievements_modal:
		achievements_modal.hide()
	_update_menu_state()


func _show_level_select() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	main_view.hide()
	level_select_view.show()
	credits_modal.hide()
	if settings_modal:
		settings_modal.hide()
	if locker_modal:
		locker_modal.hide()
	if achievements_modal:
		achievements_modal.hide()
	_refresh_level_grid_buttons()


func _animate_modal_open(modal: Control) -> void:
	if modal == null:
		return
	modal.show()
	modal.pivot_offset = modal.size / 2.0
	modal.scale = Vector2(0.90, 0.90)
	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal, "scale", Vector2.ONE, 0.20)


func _show_credits() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if settings_modal:
		settings_modal.hide()
	if locker_modal:
		locker_modal.hide()
	if achievements_modal:
		achievements_modal.hide()
	_animate_modal_open(credits_modal)


func _hide_credits() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	credits_modal.hide()


func _show_settings() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	credits_modal.hide()
	if locker_modal:
		locker_modal.hide()
	if achievements_modal:
		achievements_modal.hide()
	if settings_modal:
		_update_settings_ui()
		_animate_modal_open(settings_modal)


func _hide_settings() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if settings_modal:
		settings_modal.hide()
	if save_mgr and save_mgr.has_method("save_data"):
		save_mgr.save_data()
	_update_menu_state()


func _show_locker() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	credits_modal.hide()
	if settings_modal:
		settings_modal.hide()
	if achievements_modal:
		achievements_modal.hide()
	if locker_modal:
		_refresh_locker_ui()
		_animate_modal_open(locker_modal)


func _hide_locker() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if locker_modal:
		locker_modal.hide()
	_update_menu_state()


func _show_achievements() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	credits_modal.hide()
	if settings_modal:
		settings_modal.hide()
	if locker_modal:
		locker_modal.hide()
	if achievements_modal:
		_refresh_achievements_ui()
		_animate_modal_open(achievements_modal)


func _hide_achievements() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if achievements_modal:
		achievements_modal.hide()
	_update_menu_state()


func _switch_locker_tab(tab: String) -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	current_locker_tab = tab
	if outfits_tab_btn:
		outfits_tab_btn.theme_type_variation = &"PrimaryButton" if tab == "outfits" else &""
	if crates_tab_btn:
		crates_tab_btn.theme_type_variation = &"PrimaryButton" if tab == "crates" else &""
	_refresh_locker_ui()


func _on_equip_worker_skin(skin_id: String) -> void:
	if save_mgr and save_mgr.has_method("equip_worker_skin"):
		var ok: bool = save_mgr.equip_worker_skin(skin_id)
		if ok:
			if audio_mgr:
				audio_mgr.play_star(3)
			if haptic_mgr:
				haptic_mgr.vibrate_target()
	_refresh_locker_ui()


func _on_equip_crate_skin(skin_id: String) -> void:
	if save_mgr and save_mgr.has_method("equip_crate_skin"):
		var ok: bool = save_mgr.equip_crate_skin(skin_id)
		if ok:
			if audio_mgr:
				audio_mgr.play_star(3)
			if haptic_mgr:
				haptic_mgr.vibrate_target()
	_refresh_locker_ui()


func _refresh_locker_ui() -> void:
	if locker_modal == null or save_mgr == null:
		return

	var total_stars: int = save_mgr.get_total_stars()
	if locker_title_label:
		locker_title_label.text = loc_mgr.tr_text("LOCKER_TITLE") if loc_mgr else "SUPPLY DEPOT"
	if locker_stars_badge:
		locker_stars_badge.text = loc_mgr.tr_text("LOCKER_STARS_BADGE", [total_stars]) if loc_mgr else ("%d / 150 Stars Collected" % total_stars)

	if outfits_tab_btn:
		outfits_tab_btn.text = loc_mgr.tr_text("LOCKER_TAB_OUTFITS") if loc_mgr else "OUTFITS"
	if crates_tab_btn:
		crates_tab_btn.text = loc_mgr.tr_text("LOCKER_TAB_CRATES") if loc_mgr else "CRATES"
	if close_locker_btn and loc_mgr:
		close_locker_btn.text = loc_mgr.tr_text("BTN_CLOSE")

	if locker_items_vbox == null:
		return

	for child in locker_items_vbox.get_children():
		locker_items_vbox.remove_child(child)
		child.queue_free()

	if current_locker_tab == "outfits":
		var skins = save_mgr.get_all_worker_skins()
		var player_tex: Texture2D = preload("res://assets/player_down.png")
		for skin in skins:
			var card = _create_locker_item_card(
				skin["id"],
				skin.get("icon", "🧢"),
				loc_mgr.tr_text(skin["name_key"]) if loc_mgr else skin.get("name", ""),
				loc_mgr.tr_text(skin["desc_key"]) if loc_mgr else skin.get("desc", ""),
				skin.get("required_stars", 0),
				total_stars,
				save_mgr.selected_worker_skin == skin["id"],
				Callable(self, "_on_equip_worker_skin").bind(skin["id"]),
				player_tex,
				skin.get("sprite_tint", Color.WHITE)
			)
			locker_items_vbox.add_child(card)
	else:
		var crates = save_mgr.get_all_crate_skins()
		var crate_tex: Texture2D = preload("res://assets/crate_normal.png")
		for crate in crates:
			var card = _create_locker_item_card(
				crate["id"],
				crate.get("icon", "📦"),
				loc_mgr.tr_text(crate["name_key"]) if loc_mgr else crate.get("name", ""),
				loc_mgr.tr_text(crate["desc_key"]) if loc_mgr else crate.get("desc", ""),
				crate.get("required_stars", 0),
				total_stars,
				save_mgr.selected_crate_skin == crate["id"],
				Callable(self, "_on_equip_crate_skin").bind(crate["id"]),
				crate_tex,
				crate.get("tint", Color.WHITE)
			)
			locker_items_vbox.add_child(card)


func _create_locker_item_card(_item_id: String, icon: String, item_name: String, desc: String, req_stars: int, total_stars: int, is_equipped: bool, equip_callable: Callable, preview_texture: Texture2D = null, preview_tint: Color = Color.WHITE) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 68)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	if preview_texture != null:
		var preview_frame: PanelContainer = PanelContainer.new()
		preview_frame.custom_minimum_size = Vector2(44, 44)
		preview_frame.theme_type_variation = &"TopBarPanel"
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.texture = preview_texture
		tex_rect.modulate = preview_tint
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_frame.add_child(tex_rect)
		hbox.add_child(preview_frame)
	else:
		var icon_lbl: Label = Label.new()
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", 26)
		hbox.add_child(icon_lbl)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.30) if is_equipped else Color(0.90, 0.95, 1.0))
	info_vbox.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	var is_unlocked: bool = (total_stars >= req_stars)
	if is_unlocked:
		desc_lbl.text = desc
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	else:
		var req_text: String = loc_mgr.tr_text("LOCKER_LOCKED_STARS", [req_stars]) if loc_mgr else ("%d Stars required" % req_stars)
		desc_lbl.text = req_text
		desc_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.40))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var act_btn: Button = Button.new()
	act_btn.custom_minimum_size = Vector2(96, 38)
	act_btn.add_theme_font_size_override("font_size", 13)

	if is_equipped:
		act_btn.text = loc_mgr.tr_text("LOCKER_EQUIPPED") if loc_mgr else "EQUIPPED"
		act_btn.icon = icon_check
		act_btn.expand_icon = true
		act_btn.add_theme_constant_override("icon_max_width", 16)
		act_btn.add_theme_constant_override("h_separation", 6)
		act_btn.disabled = true
		act_btn.theme_type_variation = &"PrimaryButton"
	elif is_unlocked:
		act_btn.text = loc_mgr.tr_text("LOCKER_EQUIP") if loc_mgr else "EQUIP"
		act_btn.disabled = false
		act_btn.pressed.connect(equip_callable)
		_attach_spring_physics(act_btn)
	else:
		act_btn.text = "LOCKED"
		act_btn.icon = icon_lock
		act_btn.expand_icon = true
		act_btn.add_theme_constant_override("icon_max_width", 16)
		act_btn.add_theme_constant_override("h_separation", 6)
		act_btn.disabled = true

	hbox.add_child(act_btn)
	return panel


func _refresh_achievements_ui() -> void:
	if achievements_modal == null:
		return

	var ach_list: Array = []
	if achievement_mgr and achievement_mgr.has_method("get_all_achievements"):
		ach_list = achievement_mgr.get_all_achievements()
	elif save_mgr and save_mgr.has_method("get_unlocked_achievements"):
		# In case achievement_mgr is absent, build from save_mgr
		var unlocked = save_mgr.get_unlocked_achievements()
		ach_list = []

	var unlocked_count: int = 0
	for ach in ach_list:
		var is_unlocked: bool = false
		if achievement_mgr and achievement_mgr.has_method("is_unlocked"):
			is_unlocked = achievement_mgr.is_unlocked(ach.get("id", ""), save_mgr)
		elif save_mgr and save_mgr.has_method("is_achievement_unlocked"):
			is_unlocked = save_mgr.is_achievement_unlocked(ach.get("id", ""))
		if is_unlocked:
			unlocked_count += 1

	if achievements_title_label:
		achievements_title_label.text = loc_mgr.tr_text("ACHIEVEMENTS_TITLE") if loc_mgr else "WAREHOUSE ACHIEVEMENTS"

	if achievements_counter_badge:
		achievements_counter_badge.text = loc_mgr.tr_text("ACHIEVEMENTS_COUNTER", [unlocked_count, ach_list.size()]) if loc_mgr else ("%d / %d Unlocked" % [unlocked_count, ach_list.size()])

	if close_achievements_btn and loc_mgr:
		close_achievements_btn.text = loc_mgr.tr_text("BTN_CLOSE")

	if achievements_items_vbox == null:
		return

	for child in achievements_items_vbox.get_children():
		achievements_items_vbox.remove_child(child)
		child.queue_free()

	for ach in ach_list:
		var is_unlocked: bool = false
		if achievement_mgr and achievement_mgr.has_method("is_unlocked"):
			is_unlocked = achievement_mgr.is_unlocked(ach.get("id", ""), save_mgr)
		elif save_mgr and save_mgr.has_method("is_achievement_unlocked"):
			is_unlocked = save_mgr.is_achievement_unlocked(ach.get("id", ""))

		var card = _create_achievement_item_card(
			ach.get("id", ""),
			ach.get("icon", "🏆"),
			loc_mgr.tr_text(ach.get("title_key", "")) if loc_mgr else ach.get("title", ""),
			loc_mgr.tr_text(ach.get("desc_key", "")) if loc_mgr else ach.get("desc", ""),
			is_unlocked
		)
		achievements_items_vbox.add_child(card)


func _create_achievement_item_card(_ach_id: String, _icon: String, title: String, desc: String, is_unlocked: bool) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = icon_trophy if is_unlocked else icon_lock
	hbox.add_child(icon_rect)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.30) if is_unlocked else Color(0.65, 0.70, 0.80))
	info_vbox.add_child(title_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98) if is_unlocked else Color(0.45, 0.50, 0.60))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var status_rect: TextureRect = TextureRect.new()
	status_rect.custom_minimum_size = Vector2(18, 18)
	status_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_rect.texture = icon_check if is_unlocked else icon_lock
	hbox.add_child(status_rect)

	return panel


func _update_settings_ui() -> void:
	if save_mgr == null:
		return

	var m_vol: float = save_mgr.music_volume if "music_volume" in save_mgr else 0.7
	var s_vol: float = save_mgr.sfx_volume if "sfx_volume" in save_mgr else 0.8
	var m_on: bool = save_mgr.music_enabled if "music_enabled" in save_mgr else true
	var track_idx: int = save_mgr.selected_bgm_track if "selected_bgm_track" in save_mgr else 0

	if music_slider:
		music_slider.set_value_no_signal(m_vol)
	if music_vol_label:
		if loc_mgr:
			music_vol_label.text = loc_mgr.tr_text("SETTINGS_MUSIC_VOL", [int(m_vol * 100)])
		else:
			music_vol_label.text = "MUSIC: %d%%" % int(m_vol * 100)

	if music_toggle_btn:
		var status_text: String = "ON" if m_on else "OFF"
		music_toggle_btn.text = "MUSIC: " + status_text

	if sfx_slider:
		sfx_slider.set_value_no_signal(s_vol)
	if sfx_vol_label:
		if loc_mgr:
			sfx_vol_label.text = loc_mgr.tr_text("SETTINGS_SFX_VOL", [int(s_vol * 100)])
		else:
			sfx_vol_label.text = "SOUND FX: %d%%" % int(s_vol * 100)

	if track_cycle_btn:
		var track_name: String = "Warehouse Chill" if track_idx == 0 else "Industrial Pulse"
		if loc_mgr:
			var key: String = "TRACK_LOFI" if track_idx == 0 else "TRACK_INDUSTRIAL"
			track_name = loc_mgr.tr_text(key)
		track_cycle_btn.text = track_name

	if control_mode_btn:
		var mode_name: String = save_mgr.get_control_scheme_name() if save_mgr and save_mgr.has_method("get_control_scheme_name") else "SWIPE"
		var mode_key: String = "CONTROL_" + mode_name.replace("-", "")
		var mode_text: String = loc_mgr.tr_text(mode_key) if loc_mgr else mode_name
		control_mode_btn.text = loc_mgr.tr_text("SETTINGS_CONTROLS", [mode_text]) if loc_mgr else "CONTROLS: %s" % mode_name

	if close_settings_btn and loc_mgr:
		close_settings_btn.text = loc_mgr.tr_text("SETTINGS_CLOSE")


func _on_music_slider_changed(value: float) -> void:
	if audio_mgr and audio_mgr.has_method("set_music_volume"):
		audio_mgr.set_music_volume(value)
	elif save_mgr:
		save_mgr.music_volume = value
	if music_vol_label:
		if loc_mgr:
			music_vol_label.text = loc_mgr.tr_text("SETTINGS_MUSIC_VOL", [int(value * 100)])
		else:
			music_vol_label.text = "MUSIC: %d%%" % int(value * 100)


func _on_sfx_slider_changed(value: float) -> void:
	if audio_mgr and audio_mgr.has_method("set_sfx_volume"):
		audio_mgr.set_sfx_volume(value)
	elif save_mgr:
		save_mgr.sfx_volume = value
	if sfx_vol_label:
		if loc_mgr:
			sfx_vol_label.text = loc_mgr.tr_text("SETTINGS_SFX_VOL", [int(value * 100)])
		else:
			sfx_vol_label.text = "SOUND FX: %d%%" % int(value * 100)


func _on_music_toggle_pressed() -> void:
	var current: bool = save_mgr.music_enabled if save_mgr and "music_enabled" in save_mgr else true
	var new_val: bool = not current
	if audio_mgr and audio_mgr.has_method("set_music_enabled"):
		audio_mgr.set_music_enabled(new_val)
	elif save_mgr:
		save_mgr.music_enabled = new_val
	_update_settings_ui()


func _on_control_mode_pressed() -> void:
	if save_mgr and save_mgr.has_method("cycle_control_scheme"):
		save_mgr.cycle_control_scheme()
	elif save_mgr and "control_scheme" in save_mgr:
		save_mgr.control_scheme = (save_mgr.control_scheme + 1) % 3
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_update_settings_ui()


func _on_track_cycle_pressed() -> void:
	var current: int = save_mgr.selected_bgm_track if save_mgr and "selected_bgm_track" in save_mgr else 0
	var next_track: int = (current + 1) % 2
	if audio_mgr and audio_mgr.has_method("switch_music_track"):
		audio_mgr.switch_music_track(next_track)
	elif save_mgr:
		save_mgr.selected_bgm_track = next_track
	_update_settings_ui()


func _update_menu_state() -> void:
	var unlocked_lvl: int = save_mgr.unlocked_level if save_mgr else 0
	var last_lvl: int = save_mgr.last_played_level if save_mgr else 0
	var has_progress: bool = (unlocked_lvl > 0 or (save_mgr and save_mgr.is_level_completed(0)))
	var is_sound_on: bool = save_mgr.sound_enabled if save_mgr else true
	var is_haptics_on: bool = save_mgr.haptics_enabled if save_mgr else true

	if loc_mgr:
		if has_progress:
			continue_btn.visible = true
			continue_btn.text = loc_mgr.tr_text("MENU_CONTINUE", [last_lvl + 1])
			continue_btn.theme_type_variation = &"PrimaryButton"
			play_btn.text = loc_mgr.tr_text("MENU_NEW_GAME")
			play_btn.theme_type_variation = &""
		else:
			continue_btn.visible = false
			play_btn.text = loc_mgr.tr_text("MENU_PLAY")
			play_btn.theme_type_variation = &"PrimaryButton"

		if sound_btn:
			var sound_status: String = loc_mgr.tr_text("MENU_SOUND_ON" if is_sound_on else "MENU_SOUND_OFF")
			sound_btn.text = loc_mgr.tr_text("MENU_SOUND", [sound_status])

		if haptics_btn:
			var haptic_status: String = loc_mgr.tr_text("MENU_HAPTICS_ON" if is_haptics_on else "MENU_HAPTICS_OFF")
			haptics_btn.text = loc_mgr.tr_text("MENU_HAPTICS", [haptic_status])

		if settings_btn:
			settings_btn.text = ""
			settings_btn.tooltip_text = loc_mgr.tr_text("MENU_SETTINGS")
		if locker_btn:
			locker_btn.text = loc_mgr.tr_text("MENU_LOCKER")
		if achievements_btn:
			achievements_btn.text = ""
			achievements_btn.tooltip_text = loc_mgr.tr_text("MENU_ACHIEVEMENTS")
		language_btn.text = loc_mgr.tr_text("MENU_LANGUAGE", [loc_mgr.get_language_display_name()])
		level_select_btn.text = loc_mgr.tr_text("MENU_LEVEL_SELECT")
		credits_btn.text = loc_mgr.tr_text("MENU_CREDITS")
		back_btn.text = loc_mgr.tr_text("BTN_BACK")
		$LevelSelectView/TopBar/Margin/HBox/Title.text = loc_mgr.tr_text("LEVEL_SELECT_TITLE")
		$CreditsModal/VBox/Title.text = loc_mgr.tr_text("CREDITS_TITLE")
		$CreditsModal/VBox/Description.text = loc_mgr.tr_text("CREDITS_BODY")
		close_credits_btn.text = loc_mgr.tr_text("BTN_CLOSE")
	else:
		if has_progress:
			continue_btn.visible = true
			continue_btn.text = "CONTINUE (LEVEL %d)" % (last_lvl + 1)
			continue_btn.theme_type_variation = &"PrimaryButton"
			play_btn.text = "NEW GAME"
			play_btn.theme_type_variation = &""
		else:
			continue_btn.visible = false
			play_btn.text = "PLAY"
			play_btn.theme_type_variation = &"PrimaryButton"
		if settings_btn:
			settings_btn.text = ""
			settings_btn.tooltip_text = "Settings"
		if locker_btn:
			locker_btn.text = "SUPPLY DEPOT"
		if achievements_btn:
			achievements_btn.text = ""
			achievements_btn.tooltip_text = "Achievements"
		if sound_btn:
			sound_btn.text = "SOUND: %s" % ("ON" if is_sound_on else "OFF")
		if haptics_btn:
			haptics_btn.text = "HAPTICS: %s" % ("ON" if is_haptics_on else "OFF")
		language_btn.text = "LANGUAGE: English"

	var total_stars: int = save_mgr.get_total_stars() if (save_mgr and save_mgr.has_method("get_total_stars")) else 0
	var sector_num: int = (last_lvl + 1)
	if star_progress_btn:
		star_progress_btn.text = "%d / 150 Stars • Sector %d" % [total_stars, sector_num]
	if quick_lang_btn:
		var lang_code: String = loc_mgr.current_language.to_upper() if loc_mgr else "EN"
		quick_lang_btn.text = lang_code


func _on_language_pressed() -> void:
	if loc_mgr:
		loc_mgr.cycle_language()
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_update_menu_state()
	_refresh_level_grid_buttons()


func _on_continue_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	var target_lvl: int = save_mgr.last_played_level if save_mgr else 0
	_start_game_at_level(target_lvl)


func _on_play_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_start_game_at_level(0)


func _on_sound_toggle_pressed() -> void:
	if save_mgr:
		save_mgr.sound_enabled = not save_mgr.sound_enabled
		save_mgr.save_data()
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_update_menu_state()


func _on_haptics_toggle_pressed() -> void:
	if save_mgr:
		save_mgr.haptics_enabled = not save_mgr.haptics_enabled
		save_mgr.save_data()
		if haptic_mgr:
			haptic_mgr.set_haptic_enabled(save_mgr.haptics_enabled)
	elif haptic_mgr:
		haptic_mgr.toggle_haptics()

	if save_mgr and save_mgr.haptics_enabled and haptic_mgr:
		haptic_mgr.vibrate_click()

	if audio_mgr:
		audio_mgr.play_click()
	_update_menu_state()


func _start_game_at_level(level_index: int) -> void:
	if save_mgr:
		save_mgr.last_played_level = level_index
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _build_level_grid() -> void:
	# Clear existing children
	for child in level_grid.get_children():
		child.queue_free()

	for i in range(TOTAL_LEVELS_COUNT):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(86, 86)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 14)
		btn.set_meta("level_index", i)
		btn.pressed.connect(_on_level_button_pressed.bind(i))
		_attach_spring_physics(btn)
		level_grid.add_child(btn)

	_refresh_level_grid_buttons()


func _refresh_level_grid_buttons() -> void:
	if current_level_pulse_tw != null and current_level_pulse_tw.is_valid():
		current_level_pulse_tw.kill()
		current_level_pulse_tw = null

	var active_frontier_btn: Button = null
	var unlocked_lvl: int = save_mgr.unlocked_level if save_mgr else 0
	var total_stars: int = save_mgr.get_total_stars() if save_mgr != null else 0

	if has_node("LevelSelectView/TopBar/Margin/HBox/TotalStarsLabel") and save_mgr != null:
		var stars_lbl = get_node("LevelSelectView/TopBar/Margin/HBox/TotalStarsLabel") as Label
		stars_lbl.text = "%d / 150 Stars" % total_stars

	# Update Campaign Banner card if present
	var pb: ProgressBar = find_child("ProgressBar", true, false) as ProgressBar
	if pb != null:
		pb.max_value = 150.0
		pb.value = float(total_stars)

	var stars_count_lbl: Label = find_child("StarsCountLabel", true, false) as Label
	if stars_count_lbl != null:
		stars_count_lbl.text = "%d / 150 Stars Collected" % total_stars

	var completion_lbl: Label = find_child("CompletionLabel", true, false) as Label
	if completion_lbl != null and save_mgr != null:
		var completed_count: int = 0
		for i in range(TOTAL_LEVELS_COUNT):
			if save_mgr.is_level_completed(i):
				completed_count += 1
		var pct: int = int((float(completed_count) / float(TOTAL_LEVELS_COUNT)) * 100.0)
		completion_lbl.text = "%d/50 Cleared • %d%%" % [completed_count, pct]

	for child in level_grid.get_children():
		if not child is Button:
			continue
		var lvl_idx: int = child.get_meta("level_index", 0)
		var is_available: bool = (lvl_idx < AVAILABLE_LEVELS_COUNT)
		var is_unlocked: bool = is_available and (lvl_idx <= unlocked_lvl)
		var is_completed: bool = save_mgr != null and save_mgr.is_level_completed(lvl_idx)

		var ch_idx: int = save_mgr.get_chapter_index(lvl_idx) if (save_mgr != null and save_mgr.has_method("get_chapter_index")) else (0 if lvl_idx < 15 else (1 if lvl_idx < 35 else 2))
		var ch_info: Dictionary = save_mgr.get_chapter_info(ch_idx) if (save_mgr != null and save_mgr.has_method("get_chapter_info")) else { "color": Color(1.0, 1.0, 1.0) }
		var ch_col: Color = ch_info.get("color", Color(1.0, 1.0, 1.0))

		if is_completed:
			var record: Dictionary = save_mgr.get_level_record(lvl_idx)
			var stars: int = record.get("stars", 1)
			var star_str: String = ""
			match stars:
				3: star_str = "★★★"
				2: star_str = "★★☆"
				1: star_str = "★☆☆"
				_: star_str = "★"
			child.text = "%d\n%s" % [lvl_idx + 1, star_str]
			child.icon = null
			child.disabled = false
			child.theme_type_variation = &"LevelBtnCompleted"
			child.modulate = Color(1.0, 1.0, 1.0).lerp(ch_col, 0.28)
		elif is_unlocked:
			child.text = "%d" % [lvl_idx + 1]
			child.icon = icon_play
			child.expand_icon = true
			child.add_theme_constant_override("icon_max_width", 14)
			child.add_theme_constant_override("h_separation", 4)
			child.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.disabled = false
			child.theme_type_variation = &"LevelBtnCurrent"
			child.modulate = ch_col
			if active_frontier_btn == null:
				active_frontier_btn = child
		else:
			child.text = "%d" % [lvl_idx + 1]
			if is_available:
				child.icon = icon_lock
				child.expand_icon = true
				child.add_theme_constant_override("icon_max_width", 14)
				child.add_theme_constant_override("h_separation", 4)
				child.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				child.icon = null
			child.disabled = true
			child.theme_type_variation = &"LevelBtnLocked"
			child.modulate = Color(0.68, 0.72, 0.82, 0.75).lerp(ch_col, 0.15)

	if active_frontier_btn != null and active_frontier_btn.is_inside_tree():
		var p_sz: Vector2 = active_frontier_btn.custom_minimum_size if active_frontier_btn.size == Vector2.ZERO else active_frontier_btn.size
		active_frontier_btn.pivot_offset = p_sz / 2.0
		current_level_pulse_tw = create_tween().set_loops()
		current_level_pulse_tw.tween_property(active_frontier_btn, "scale", Vector2(1.05, 1.05), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		current_level_pulse_tw.tween_property(active_frontier_btn, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_level_button_pressed(level_index: int) -> void:
	if level_index < AVAILABLE_LEVELS_COUNT:
		if save_mgr and not save_mgr.is_level_unlocked(level_index):
			return
		_start_game_at_level(level_index)


func _attach_spring_physics(btn: Button) -> void:
	if btn == null:
		return
	var calc_pivot = func():
		var sz: Vector2 = btn.custom_minimum_size if btn.size == Vector2.ZERO else btn.size
		btn.pivot_offset = sz / 2.0
	calc_pivot.call()
	btn.button_down.connect(func():
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.07)
	)
	btn.button_up.connect(func():
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)
	btn.mouse_exited.connect(func():
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)
