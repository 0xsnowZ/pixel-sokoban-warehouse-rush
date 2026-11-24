extends Control

## Main menu and Level Select controller for Pixel Porter.
## Implements PRD Section 6 flow:
## - Continue / Play navigation
## - Level select 75-level grid with locked/completed visual states
## - Sound on/off toggle persisted via SaveManager
## - Credits popup

const SaveManagerScript: GDScript = preload("res://scripts/save_manager.gd")
const AchievementManagerScript: GDScript = preload("res://scripts/achievement_manager.gd")
const TOTAL_LEVELS_COUNT: int = 75
const AVAILABLE_LEVELS_COUNT: int = 75 # All 75 verified solvable levels active
const GAME_SCENE_PATH: String = "res://scenes/game.tscn"

# Enhanced High-Resolution UI Icon Textures
var icon_trophy: Texture2D = preload("res://assets/icons/icon_trophy.png")
var icon_settings: Texture2D = preload("res://assets/icons/icon_settings.png")
var icon_locker: Texture2D = preload("res://assets/icons/icon_locker.png")
var icon_star_full: Texture2D = preload("res://assets/icons/icon_star_full.png")
var icon_lock: Texture2D = preload("res://assets/icons/icon_lock.png")
var icon_play: Texture2D = preload("res://assets/icons/icon_play.png")
var icon_check: Texture2D = preload("res://assets/icons/icon_check.png")
var icon_hint: Texture2D = preload("res://assets/icons/icon_hint.png")
var icon_calendar: Texture2D = preload("res://assets/icons/icon_calendar.png")
var icon_flame: Texture2D = preload("res://assets/icons/icon_flame.png")
var icon_sector_1: Texture2D = preload("res://assets/icons/icon_sector_1.png")
var icon_sector_2: Texture2D = preload("res://assets/icons/icon_sector_2.png")
var icon_sector_3: Texture2D = preload("res://assets/icons/icon_sector_3.png")
var icon_sector_4: Texture2D = preload("res://assets/icons/icon_sector_4.png")
var icon_undo: Texture2D = preload("res://assets/icons/icon_undo.png")

# Thematic Sector Dispatch Styling & Cached StyleBoxes
var _sector_styles_completed: Array[StyleBoxFlat] = []
var _sector_styles_hover: Array[StyleBoxFlat] = []
var _sector_styles_pressed: Array[StyleBoxFlat] = []
var _frontier_style: StyleBoxFlat = null
var _locked_style: StyleBoxFlat = null
var _sector_font_colors: Array[Color] = [
	Color(1.0, 0.94, 0.78),
	Color(0.85, 0.95, 1.0),
	Color(1.0, 0.92, 0.75),
	Color(0.95, 0.85, 1.0)
]

var tex_player_down: Texture2D = preload("res://assets/player_down.png")
var tex_player_down_w1: Texture2D = preload("res://assets/player_down_walk1.png")
var tex_player_down_w2: Texture2D = preload("res://assets/player_down_walk2.png")
var tex_crate: Texture2D = preload("res://assets/crate_normal.png")
var tex_goal_pad: Texture2D = preload("res://assets/goal_pad.png")

var _preview_anim_time: float = 0.0

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
@onready var sound_btn: Button = _find_button("SoundToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/SfxBox/SfxRow/SoundToggleBtn")
@onready var haptics_btn: Button = _find_button("HapticsToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/HapticsToggleBtn")
@onready var tap_walk_btn: Button = _find_button("TapWalkToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/ControlBox/TapWalkToggleBtn")
@onready var language_btn: Button = _find_button("LanguageBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/LanguageBtn")
@onready var credits_btn: Button = _find_button("CreditsBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/CreditsBtn")
@onready var locker_btn: Button = _find_button("LockerBtn", "MainView/BottomMargin/ActionDeck/DualDeck/LockerBtn")
@onready var locker_btn_label: Label = find_child("LockerBtn", true, false).find_child("Label", true, false) as Label if find_child("LockerBtn", true, false) else null
@onready var locker_btn_icon: TextureRect = find_child("LockerBtn", true, false).find_child("Icon", true, false) as TextureRect if find_child("LockerBtn", true, false) else null
@onready var locker_modal: PanelContainer = find_child("LockerModal", true, false) as PanelContainer
@onready var outfits_tab_btn: Button = _find_button("OutfitsTabBtn", "LockerModal/Margin/VBox/TabsHBox/OutfitsTabBtn")
@onready var crates_tab_btn: Button = _find_button("CratesTabBtn", "LockerModal/Margin/VBox/TabsHBox/CratesTabBtn")
@onready var close_locker_btn: Button = _find_button("CloseLockerBtn", "LockerModal/Margin/VBox/CloseLockerBtn")
@onready var locker_title_label: Label = find_child("LockerModal", true, false).find_child("Title", true, false) as Label if find_child("LockerModal", true, false) else null
@onready var locker_stars_badge: Label = find_child("LockerModal", true, false).find_child("StarsBadge", true, false) as Label if find_child("LockerModal", true, false) else null
@onready var locker_items_vbox: VBoxContainer = find_child("LockerModal", true, false).find_child("ItemsVBox", true, false) as VBoxContainer if find_child("LockerModal", true, false) else null
@onready var locker_preview_content: Control = find_child("LockerModal", true, false).find_child("PreviewContent", true, false) as Control if find_child("LockerModal", true, false) else null
@onready var star_progress_btn: Button = _find_button("StarProgressBtn", "MainView/TopBarMargin/HBox/StarProgressBtn")
@onready var quick_lang_btn: Button = _find_button("QuickLangBtn", "MainView/TopBarMargin/HBox/QuickBar/QuickLangBtn")

var current_locker_tab: String = "outfits"
var current_level_pulse_tw: Tween = null
var daily_shift_btn: Button = null
var star_vault_modal: PanelContainer = null
var _touch_scroll_controllers: Array = []
var _active_spring_button: Button = null

# Achievements elements (Phase 4)
@onready var achievements_btn: Button = _find_button("AchievementsBtn", "MainView/TopBarMargin/HBox/QuickBar/AchievementsBtn")
@onready var achievements_modal: PanelContainer = find_child("AchievementsModal", true, false) as PanelContainer
@onready var close_achievements_btn: Button = _find_button("CloseAchievementsBtn", "AchievementsModal/Margin/VBox/CloseAchievementsBtn")
@onready var achievements_title_label: Label = find_child("AchievementsModal", true, false).find_child("Title", true, false) as Label if find_child("AchievementsModal", true, false) else null
@onready var achievements_counter_badge: Label = find_child("AchievementsModal", true, false).find_child("CounterBadge", true, false) as Label if find_child("AchievementsModal", true, false) else null
@onready var achievements_items_vbox: VBoxContainer = find_child("AchievementsModal", true, false).find_child("ItemsVBox", true, false) as VBoxContainer if find_child("AchievementsModal", true, false) else null
@onready var modal_blur_overlay: ColorRect = $ModalBlurOverlay if has_node("ModalBlurOverlay") else null

# Settings elements
@onready var settings_title_label: Label = find_child("SettingsModal", true, false).find_child("Title", true, false) as Label if find_child("SettingsModal", true, false) else null
@onready var music_vol_label: Label = find_child("MusicVolLabel", true, false) as Label
@onready var music_slider: HSlider = find_child("MusicSlider", true, false) as HSlider
@onready var music_toggle_btn: Button = _find_button("MusicToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/MusicBox/MusicRow/MusicToggleBtn")
@onready var track_label: Label = find_child("TrackLabel", true, false) as Label
@onready var track_cycle_btn: Button = _find_button("TrackCycleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/TrackBox/TrackCycleBtn")
@onready var sfx_vol_label: Label = find_child("SfxVolLabel", true, false) as Label
@onready var sfx_slider: HSlider = find_child("SfxSlider", true, false) as HSlider
@onready var close_settings_btn: Button = _find_button("CloseSettingsBtn", "SettingsModal/Margin/VBox/CloseSettingsBtn")
@onready var control_mode_btn: Button = _find_button("ControlModeBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/ControlBox/ControlModeBtn")

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
		sound_btn = _find_button("SoundToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/SfxBox/SfxRow/SoundToggleBtn")
		haptics_btn = _find_button("HapticsToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/HapticsToggleBtn")
		tap_walk_btn = _find_button("TapWalkToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/ControlBox/TapWalkToggleBtn")
		language_btn = _find_button("LanguageBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/LanguageBtn")
		credits_btn = _find_button("CreditsBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/CreditsBtn")
		if settings_modal != null:
			settings_title_label = settings_modal.find_child("Title", true, false) as Label
		music_vol_label = find_child("MusicVolLabel", true, false) as Label
		music_slider = find_child("MusicSlider", true, false) as HSlider
		music_toggle_btn = _find_button("MusicToggleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/MusicBox/MusicRow/MusicToggleBtn")
		track_label = find_child("TrackLabel", true, false) as Label
		track_cycle_btn = _find_button("TrackCycleBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/TrackBox/TrackCycleBtn")
		sfx_vol_label = find_child("SfxVolLabel", true, false) as Label
		sfx_slider = find_child("SfxSlider", true, false) as HSlider
		close_settings_btn = _find_button("CloseSettingsBtn", "SettingsModal/Margin/VBox/CloseSettingsBtn")
		control_mode_btn = _find_button("ControlModeBtn", "SettingsModal/Margin/VBox/Scroll/ItemsVBox/ControlBox/ControlModeBtn")
		level_grid = find_child("LevelGrid", true, false) as GridContainer
		back_btn = _find_button("BackBtn", "LevelSelectView/TopBar/Margin/HBox/BackBtn")
		close_credits_btn = _find_button("CloseCreditsBtn", "CreditsModal/VBox/CloseCreditsBtn")
		locker_modal = find_child("LockerModal", true, false) as PanelContainer
		locker_btn = _find_button("LockerBtn", "MainView/BottomMargin/ActionDeck/DualDeck/LockerBtn")
		if locker_btn != null:
			locker_btn_label = locker_btn.find_child("Label", true, false) as Label
			locker_btn_icon = locker_btn.find_child("Icon", true, false) as TextureRect
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
			locker_preview_content = locker_modal.find_child("PreviewContent", true, false) as Control
		if achievements_modal != null:
			achievements_title_label = achievements_modal.find_child("Title", true, false) as Label
			achievements_counter_badge = achievements_modal.find_child("CounterBadge", true, false) as Label
			achievements_items_vbox = achievements_modal.find_child("ItemsVBox", true, false) as VBoxContainer
		modal_blur_overlay = find_child("ModalBlurOverlay", true, false) as ColorRect


func _ready() -> void:
	_initialize_nodes()
	if save_mgr == null:
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
		if AchievementManagerScript:
			achievement_mgr = AchievementManagerScript.new()
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
	if tap_walk_btn and not tap_walk_btn.pressed.is_connected(_on_tap_walk_toggle_pressed):
		tap_walk_btn.pressed.connect(_on_tap_walk_toggle_pressed)
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
	if locker_preview_content != null and not locker_preview_content.draw.is_connected(_on_preview_content_draw):
		locker_preview_content.draw.connect(_on_preview_content_draw)
	if modal_blur_overlay != null:
		modal_blur_overlay.hide()
		if not modal_blur_overlay.gui_input.is_connected(_on_modal_backdrop_gui_input):
			modal_blur_overlay.gui_input.connect(_on_modal_backdrop_gui_input)

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
		locker_btn.icon = null
		locker_btn.text = ""
		locker_btn.tooltip_text = ""
		if locker_btn_icon != null:
			locker_btn_icon.texture = icon_locker
		if locker_btn_label != null:
			locker_btn.mouse_entered.connect(func(): locker_btn_label.add_theme_color_override("font_color", Color(1, 1, 1, 1)))
			locker_btn.mouse_exited.connect(func(): locker_btn_label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98, 1)))
			locker_btn.button_down.connect(func(): locker_btn_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25, 1)))
			locker_btn.button_up.connect(func(): locker_btn_label.add_theme_color_override("font_color", Color(1, 1, 1, 1) if locker_btn.is_hovered() else Color(0.94, 0.96, 0.98, 1)))
	if star_progress_btn:
		star_progress_btn.icon = icon_star_full
		star_progress_btn.expand_icon = true
		star_progress_btn.add_theme_constant_override("icon_max_width", 20)
		star_progress_btn.add_theme_constant_override("h_separation", 8)
	if continue_btn:
		continue_btn.icon = null
	if play_btn:
		play_btn.icon = null

	_init_sector_styles()
	_setup_sector_tabs()
	if back_btn:
		back_btn.icon = icon_undo
		back_btn.expand_icon = true
		back_btn.add_theme_constant_override("icon_max_width", 18)
		back_btn.add_theme_constant_override("h_separation", 6)
		back_btn.text = "RETURN"

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
	for b in [continue_btn, play_btn, level_select_btn, locker_btn, achievements_btn, settings_btn, sound_btn, haptics_btn, tap_walk_btn, language_btn, credits_btn, back_btn, close_credits_btn, close_settings_btn, close_locker_btn, close_achievements_btn, outfits_tab_btn, crates_tab_btn, music_toggle_btn, track_cycle_btn, control_mode_btn, star_progress_btn, quick_lang_btn]:
		if b != null:
			_attach_spring_physics(b)

	_setup_touch_scrolling()

	var open_lvl_select: bool = false
	if save_mgr != null and save_mgr.has_meta("open_level_select") and bool(save_mgr.get_meta("open_level_select")):
		open_lvl_select = true
		save_mgr.set_meta("open_level_select", false)
	if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_meta("open_level_select") and bool(get_tree().root.get_meta("open_level_select")):
		open_lvl_select = true
		get_tree().root.set_meta("open_level_select", false)
	if open_lvl_select:
		_show_level_select()

	ResourceLoader.load_threaded_request(GAME_SCENE_PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if credits_modal != null and credits_modal.visible:
			_hide_credits()
			if get_viewport(): get_viewport().set_input_as_handled()
		elif settings_modal != null and settings_modal.visible:
			_hide_settings()
			if get_viewport(): get_viewport().set_input_as_handled()
		elif locker_modal != null and locker_modal.visible:
			_hide_locker()
			if get_viewport(): get_viewport().set_input_as_handled()
		elif achievements_modal != null and achievements_modal.visible:
			_hide_achievements()
			if get_viewport(): get_viewport().set_input_as_handled()
		elif level_select_view != null and level_select_view.visible:
			_show_main_view()
			if get_viewport(): get_viewport().set_input_as_handled()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if save_mgr != null and save_mgr.has_method("save_data"):
			save_mgr.save_data()


func _transition_to_game() -> void:
	if ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene = ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
		if scene != null:
			get_tree().change_scene_to_packed(scene)
			return
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


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
	for m in [settings_modal, locker_modal, achievements_modal, credits_modal]:
		if m != null and m.visible:
			_clamp_modal_to_safe_area(m)


func _sanitize_main_view_top_bar() -> void:
	if locker_btn != null:
		locker_btn.tooltip_text = ""
		for child in locker_btn.get_children():
			if child is Popup or child is PopupPanel or child.name.begins_with("@Popup"):
				child.queue_free()
	if settings_btn != null:
		settings_btn.tooltip_text = ""
	if achievements_btn != null:
		achievements_btn.tooltip_text = ""
	if main_view == null:
		return
	for child in main_view.get_children():
		if child.name != "TopBarMargin" and child.name != "CenterStage" and child.name != "BottomMargin":
			child.queue_free()
	var top_bar_margin: MarginContainer = main_view.get_node_or_null("TopBarMargin") as MarginContainer
	if top_bar_margin != null:
		var hbox: HBoxContainer = top_bar_margin.get_node_or_null("HBox") as HBoxContainer
		if hbox != null:
			for child in hbox.get_children():
				if child != star_progress_btn and child != quick_lang_btn.get_parent() and child.name != "Spacer":
					child.queue_free()
	for child in get_children():
		if child is Popup or child is PopupPanel or child.name.begins_with("@Popup"):
			child.queue_free()
	if level_select_view != null:
		level_select_view.hide()
	if credits_modal != null:
		credits_modal.hide()
	if settings_modal != null:
		settings_modal.hide()
	if locker_modal != null:
		locker_modal.hide()
	if achievements_modal != null:
		achievements_modal.hide()
	if star_vault_modal != null:
		star_vault_modal.hide()
	if modal_blur_overlay != null:
		modal_blur_overlay.hide()


func _show_main_view() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if current_level_pulse_tw != null and current_level_pulse_tw.is_valid():
		current_level_pulse_tw.kill()
		current_level_pulse_tw = null
	main_view.show()
	_sanitize_main_view_top_bar()
	_update_menu_state()
	_check_star_vault_milestones()


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
	if modal_blur_overlay:
		modal_blur_overlay.hide()
	_refresh_level_grid_buttons()
	_check_star_vault_milestones()


var _backdrop_tw: Tween = null

func _show_modal_backdrop() -> void:
	if modal_blur_overlay == null:
		return
	if _backdrop_tw != null and _backdrop_tw.is_valid():
		_backdrop_tw.kill()
	modal_blur_overlay.show()
	modal_blur_overlay.modulate.a = 0.0
	_backdrop_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_backdrop_tw.tween_property(modal_blur_overlay, "modulate:a", 1.0, 0.20)


func _hide_modal_backdrop() -> void:
	if modal_blur_overlay == null or not modal_blur_overlay.visible:
		return
	if _backdrop_tw != null and _backdrop_tw.is_valid():
		_backdrop_tw.kill()
	_backdrop_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_backdrop_tw.tween_property(modal_blur_overlay, "modulate:a", 0.0, 0.15)
	_backdrop_tw.tween_callback(func():
		if modal_blur_overlay and not (
			(locker_modal and locker_modal.visible) or
			(settings_modal and settings_modal.visible) or
			(achievements_modal and achievements_modal.visible) or
			(credits_modal and credits_modal.visible)
		):
			modal_blur_overlay.hide()
	)


func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if locker_modal and locker_modal.visible:
			_hide_locker()
		elif settings_modal and settings_modal.visible:
			_hide_settings()
		elif achievements_modal and achievements_modal.visible:
			_hide_achievements()
		elif credits_modal and credits_modal.visible:
			_hide_credits()


func _clamp_modal_to_safe_area(modal: Control) -> void:
	if modal == null:
		return
	var vp_sz: Vector2 = get_viewport_rect().size if (is_inside_tree() and get_viewport() != null) else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
	if vp_sz.x <= 10.0 or vp_sz.y <= 10.0:
		return
	var insets: Dictionary = safe_area_mgr.get_safe_insets(self) if safe_area_mgr else {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	var avail_w: float = maxf(280.0, vp_sz.x - insets.get("left", 0.0) - insets.get("right", 0.0) - 32.0)
	var avail_h: float = maxf(300.0, vp_sz.y - insets.get("top", 0.0) - insets.get("bottom", 0.0) - 48.0)
	var target_w: float = minf(absf(modal.offset_right - modal.offset_left), avail_w)
	var target_h: float = minf(absf(modal.offset_bottom - modal.offset_top), avail_h)
	if target_w > 0.0:
		modal.offset_left = -target_w * 0.5
		modal.offset_right = target_w * 0.5
	if target_h > 0.0:
		var y_bias: float = (insets.get("top", 0.0) - insets.get("bottom", 0.0)) * 0.5
		modal.offset_top = -target_h * 0.5 + y_bias
		modal.offset_bottom = target_h * 0.5 + y_bias


func _animate_modal_open(modal: Control) -> void:
	if modal == null:
		return
	if audio_mgr and audio_mgr.has_method("play_modal_open"):
		audio_mgr.play_modal_open()
	_show_modal_backdrop()
	_clamp_modal_to_safe_area(modal)
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
		if audio_mgr.has_method("play_ui_back"):
			audio_mgr.play_ui_back()
		else:
			audio_mgr.play_click()
	credits_modal.hide()
	_hide_modal_backdrop()


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
		if audio_mgr.has_method("play_ui_back"):
			audio_mgr.play_ui_back()
		else:
			audio_mgr.play_click()
	if settings_modal:
		settings_modal.hide()
	_hide_modal_backdrop()
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
		if audio_mgr.has_method("play_ui_back"):
			audio_mgr.play_ui_back()
		else:
			audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if locker_modal:
		locker_modal.hide()
	_hide_modal_backdrop()
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
		if audio_mgr.has_method("play_ui_back"):
			audio_mgr.play_ui_back()
		else:
			audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if achievements_modal:
		achievements_modal.hide()
	_hide_modal_backdrop()
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
				if audio_mgr.has_method("play_ui_equip"):
					audio_mgr.play_ui_equip()
				else:
					audio_mgr.play_star(3)
			if haptic_mgr:
				haptic_mgr.vibrate_target()
	_refresh_locker_ui()


func _on_equip_crate_skin(skin_id: String) -> void:
	if save_mgr and save_mgr.has_method("equip_crate_skin"):
		var ok: bool = save_mgr.equip_crate_skin(skin_id)
		if ok:
			if audio_mgr:
				if audio_mgr.has_method("play_ui_equip"):
					audio_mgr.play_ui_equip()
				else:
					audio_mgr.play_star(3)
			if haptic_mgr:
				haptic_mgr.vibrate_target()
	_refresh_locker_ui()


func _process(delta: float) -> void:
	if locker_modal != null and locker_modal.visible:
		_preview_anim_time += delta
		if locker_preview_content != null:
			locker_preview_content.queue_redraw()


func _on_preview_content_draw() -> void:
	if locker_preview_content == null:
		return

	var size: Vector2 = locker_preview_content.size
	if size.x <= 10.0 or size.y <= 10.0:
		return

	var center_x: float = size.x * 0.5
	var base_y: float = size.y * 0.64

	# 1. Industrial Platform Pedestal
	var plat_w: float = minf(size.x - 32.0, 320.0)
	var plat_h: float = 24.0
	var plat_rect: Rect2 = Rect2(center_x - plat_w * 0.5, base_y - 2.0, plat_w, plat_h)

	# Platform soft drop shadow
	locker_preview_content.draw_rect(plat_rect.grow(2.0), Color(0.04, 0.06, 0.09, 0.55), false, 2.0)
	locker_preview_content.draw_rect(plat_rect, Color(0.12, 0.16, 0.22, 0.95))
	# Polished metallic rim line on platform
	locker_preview_content.draw_line(
		plat_rect.position + Vector2(2.0, 1.0),
		plat_rect.position + Vector2(plat_rect.size.x - 2.0, 1.0),
		Color(0.95, 0.82, 0.35, 0.70), 1.5
	)

	# 2. Freight Crate on Goal Pad (Right side)
	var crate_pos: Vector2 = Vector2(center_x + 50.0, base_y + 1.0)
	var goal_rect: Rect2 = Rect2(crate_pos - Vector2(17, 16), Vector2(34, 32))
	if tex_goal_pad:
		locker_preview_content.draw_texture_rect(tex_goal_pad, goal_rect, false, Color(1.0, 1.0, 1.0, 0.85))

	var crate_info: Dictionary = save_mgr.get_crate_skin_info() if (save_mgr and save_mgr.has_method("get_crate_skin_info")) else {}
	var crate_id: String = crate_info.get("id", "classic_wood")
	var crate_tint: Color = crate_info.get("tint", Color.WHITE)
	var crate_draw_r: Rect2 = Rect2(crate_pos - Vector2(15, 23), Vector2(30, 30))

	# Soft crate shadow
	locker_preview_content.draw_circle(crate_pos + Vector2(0, 4), 10.0, Color(0.0, 0.0, 0.0, 0.35))
	if tex_crate:
		locker_preview_content.draw_texture_rect(tex_crate, crate_draw_r, false, crate_tint)

	# Crate custom skin accessories in preview
	var c_center: Vector2 = crate_draw_r.get_center()
	match crate_id:
		"steel_container":
			var b_col: Color = Color(0.85, 0.92, 1.0, 0.80)
			locker_preview_content.draw_rect(crate_draw_r.grow(-1), b_col, false, 1.4)
		"hazard_box":
			locker_preview_content.draw_rect(crate_draw_r.grow(-2), Color(1.0, 0.75, 0.15, 0.80), false, 1.5)
			locker_preview_content.draw_line(c_center - Vector2(5, 5), c_center + Vector2(5, 5), Color(0.12, 0.12, 0.15, 0.85), 2.5)
			locker_preview_content.draw_line(c_center - Vector2(5, -5), c_center + Vector2(5, -5), Color(0.12, 0.12, 0.15, 0.85), 2.5)
		"cryo_vault":
			locker_preview_content.draw_rect(crate_draw_r.grow(-2), Color(0.40, 0.88, 1.0, 0.80), false, 1.5)
			locker_preview_content.draw_circle(c_center, 3.0, Color(0.85, 0.98, 1.0, 0.90))
		"luxury_safe":
			locker_preview_content.draw_rect(crate_draw_r.grow(-2), Color(1.0, 0.84, 0.20, 0.90), false, 1.8)
			locker_preview_content.draw_circle(c_center, 4.0, Color(1.0, 0.86, 0.28, 0.95))

	# 3. Worker with animated walk/breathing cycle (Left side)
	var worker_pos: Vector2 = Vector2(center_x - 50.0, base_y + 1.0)
	var walk_phase: int = int(_preview_anim_time * 3.5) % 4
	var p_tex: Texture2D = tex_player_down
	var bob_y: float = 0.0
	if walk_phase == 0:
		p_tex = tex_player_down_w1 if tex_player_down_w1 else tex_player_down
		bob_y = -1.2
	elif walk_phase == 2:
		p_tex = tex_player_down_w2 if tex_player_down_w2 else tex_player_down
		bob_y = -1.2

	var worker_info: Dictionary = save_mgr.get_worker_skin_info() if (save_mgr and save_mgr.has_method("get_worker_skin_info")) else {}
	var worker_id: String = worker_info.get("id", "classic")
	var worker_mod: Color = worker_info.get("sprite_tint", Color.WHITE)
	var worker_rect: Rect2 = Rect2(worker_pos - Vector2(14, 25) + Vector2(0, bob_y), Vector2(28, 28))

	# Worker foot shadow
	locker_preview_content.draw_circle(worker_pos + Vector2(0, 3), 9.0, Color(0.0, 0.0, 0.0, 0.35))
	if p_tex:
		locker_preview_content.draw_texture_rect(p_tex, worker_rect, false, worker_mod)

	# Worker accessories in preview
	var w_center: Vector2 = worker_rect.get_center()
	match worker_id:
		"safety_vest":
			var stripe_y: float = worker_rect.position.y + worker_rect.size.y * 0.54
			locker_preview_content.draw_line(Vector2(w_center.x - 6, stripe_y), Vector2(w_center.x + 6, stripe_y), Color(0.95, 0.98, 1.0, 0.90), 2.0)
		"mechanic":
			var belt_y: float = worker_rect.position.y + worker_rect.size.y * 0.58
			locker_preview_content.draw_line(Vector2(w_center.x - 6, belt_y), Vector2(w_center.x + 6, belt_y), Color(0.18, 0.20, 0.25, 0.90), 2.0)
			locker_preview_content.draw_line(Vector2(w_center.x + 3, belt_y - 2), Vector2(w_center.x + 3, belt_y + 3), Color(0.85, 0.90, 0.98, 0.95), 1.5)
		"foreman":
			var brim_y: float = worker_rect.position.y + worker_rect.size.y * 0.28
			locker_preview_content.draw_line(Vector2(w_center.x - 7, brim_y), Vector2(w_center.x + 7, brim_y), Color(1.0, 0.90, 0.25, 0.90), 1.8)
		"hazmat":
			var visor_y: float = worker_rect.position.y + worker_rect.size.y * 0.32
			locker_preview_content.draw_line(Vector2(w_center.x - 5, visor_y), Vector2(w_center.x + 5, visor_y), Color(0.20, 0.95, 1.0, 0.95), 2.0)
		"golden_porter":
			var shim: float = sin(_preview_anim_time * 5.0) * 0.25 + 0.75
			locker_preview_content.draw_circle(w_center + Vector2(0, -worker_rect.size.y * 0.45), 2.2 * shim, Color(1.0, 0.95, 0.60, 0.85))

	# 4. Loadout Display Text Banner
	var w_name: String = loc_mgr.tr_text(worker_info.get("name_key", "")) if (loc_mgr and worker_info.has("name_key")) else worker_info.get("name", "Classic")
	var c_name: String = loc_mgr.tr_text(crate_info.get("name_key", "")) if (loc_mgr and crate_info.has("name_key")) else crate_info.get("name", "Pine")
	var banner_text: String = "%s  •  %s" % [w_name.to_upper(), c_name.to_upper()]
	var font: Font = get_theme_default_font()
	if font:
		var font_sz: int = 11
		var txt_w: float = font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz).x
		locker_preview_content.draw_string(
			font,
			Vector2(center_x - txt_w * 0.5, 14.0),
			banner_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_sz,
			Color(0.98, 0.85, 0.30, 0.95)
		)


func _refresh_locker_ui() -> void:
	if locker_modal == null or save_mgr == null:
		return

	if locker_preview_content:
		locker_preview_content.queue_redraw()

	var total_stars: int = save_mgr.get_total_stars()
	if locker_title_label:
		locker_title_label.text = loc_mgr.tr_text("LOCKER_TITLE") if loc_mgr else "SUPPLY DEPOT"
	if locker_stars_badge:
		locker_stars_badge.text = loc_mgr.tr_text("LOCKER_STARS_BADGE", [total_stars]) if loc_mgr else ("%d / 225 Stars Collected" % total_stars)

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
		var skins: Array[Dictionary] = save_mgr.get_all_worker_skins()
		var player_tex: Texture2D = preload("res://assets/player_down.png")
		for skin in skins:
			var card: Control = _create_locker_item_card(
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
		var crates: Array[Dictionary] = save_mgr.get_all_crate_skins()
		var crate_tex: Texture2D = preload("res://assets/crate_normal.png")
		for crate in crates:
			var card: Control = _create_locker_item_card(
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
	panel.theme_type_variation = &"CardPanel"
	panel.custom_minimum_size = Vector2(0, 68)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	if preview_texture != null:
		var preview_frame: PanelContainer = PanelContainer.new()
		preview_frame.custom_minimum_size = Vector2(44, 44)
		preview_frame.theme_type_variation = &"TopBarPanel"
		preview_frame.mouse_filter = Control.MOUSE_FILTER_PASS
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.texture = preview_texture
		tex_rect.modulate = preview_tint
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		preview_frame.add_child(tex_rect)
		hbox.add_child(preview_frame)
	else:
		var icon_lbl: Label = Label.new()
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", 26)
		hbox.add_child(icon_lbl)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl: Label = Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.30) if is_equipped else Color(0.90, 0.95, 1.0))
	info_vbox.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
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
	act_btn.custom_minimum_size = Vector2(108, 36)
	act_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act_btn.clip_contents = true

	var btn_center: HBoxContainer = HBoxContainer.new()
	btn_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_center.add_theme_constant_override("separation", 6)
	btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_btn.add_child(btn_center)

	var btn_icon: TextureRect = TextureRect.new()
	btn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	btn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	btn_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var btn_lbl: Label = Label.new()
	btn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if is_equipped:
		var sb_eq: StyleBoxFlat = StyleBoxFlat.new()
		sb_eq.bg_color = Color(0.12, 0.40, 0.24, 0.95)
		sb_eq.border_color = Color(0.35, 0.85, 0.52, 0.95)
		sb_eq.set_border_width_all(2)
		sb_eq.border_width_bottom = 3
		sb_eq.set_corner_radius_all(8)
		sb_eq.shadow_color = Color(0, 0, 0, 0.35)
		sb_eq.shadow_size = 2
		act_btn.add_theme_stylebox_override("normal", sb_eq)
		act_btn.add_theme_stylebox_override("hover", sb_eq)
		act_btn.add_theme_stylebox_override("pressed", sb_eq)
		act_btn.add_theme_stylebox_override("disabled", sb_eq)

		btn_icon.custom_minimum_size = Vector2(16, 16)
		btn_icon.texture = icon_check
		btn_icon.modulate = Color(0.95, 1.0, 0.95, 1.0)
		btn_center.add_child(btn_icon)

		var eq_text: String = loc_mgr.tr_text("LOCKER_EQUIPPED") if loc_mgr else "EQUIPPED"
		btn_lbl.text = eq_text
		btn_lbl.add_theme_font_size_override("font_size", 12)
		btn_lbl.add_theme_color_override("font_color", Color(0.95, 1.0, 0.96, 1.0))
		btn_center.add_child(btn_lbl)

		act_btn.tooltip_text = ""
		act_btn.mouse_filter = Control.MOUSE_FILTER_PASS

	elif is_unlocked:
		act_btn.theme_type_variation = &"PrimaryButton"
		var equip_text: String = loc_mgr.tr_text("LOCKER_EQUIP") if loc_mgr else "EQUIP"
		btn_lbl.text = equip_text
		btn_lbl.add_theme_font_size_override("font_size", 13)
		btn_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		btn_center.add_child(btn_lbl)

		act_btn.mouse_entered.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0)))
		act_btn.mouse_exited.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0)))
		act_btn.button_down.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25, 1.0)))
		act_btn.button_up.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0)))

		act_btn.tooltip_text = ""
		act_btn.pressed.connect(func():
			if _is_any_scroll_dragging():
				return
			equip_callable.call()
		)
		_attach_spring_physics(act_btn)

	else:
		var sb_lock: StyleBoxFlat = StyleBoxFlat.new()
		sb_lock.bg_color = Color(0.11, 0.14, 0.20, 0.90)
		sb_lock.border_color = Color(0.28, 0.36, 0.48, 0.75)
		sb_lock.set_border_width_all(2)
		sb_lock.set_corner_radius_all(8)
		sb_lock.shadow_color = Color(0, 0, 0, 0.35)
		sb_lock.shadow_size = 2
		act_btn.add_theme_stylebox_override("normal", sb_lock)
		act_btn.add_theme_stylebox_override("hover", sb_lock)
		act_btn.add_theme_stylebox_override("pressed", sb_lock)
		act_btn.add_theme_stylebox_override("disabled", sb_lock)

		btn_icon.custom_minimum_size = Vector2(16, 16)
		btn_icon.texture = icon_lock
		btn_icon.modulate = Color(0.95, 0.95, 1.0, 0.95)
		btn_center.add_child(btn_icon)

		var lock_text: String = loc_mgr.tr_text("LOCKER_LOCKED") if loc_mgr else "LOCKED"
		btn_lbl.text = lock_text
		btn_lbl.add_theme_font_size_override("font_size", 12)
		btn_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 1.0))
		btn_center.add_child(btn_lbl)

		act_btn.tooltip_text = ""

		# Tactile feedback when tapping locked item
		act_btn.pressed.connect(func():
			if _is_any_scroll_dragging():
				return
			var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(desc_lbl, "modulate", Color(1.4, 0.9, 0.3, 1.0), 0.08)
			tw.tween_property(desc_lbl, "modulate", Color.WHITE, 0.24)
			if audio_mgr and audio_mgr.has_method("play_ui_click"):
				audio_mgr.play_ui_click()
			if haptic_mgr and haptic_mgr.has_method("vibrate_click"):
				haptic_mgr.vibrate_click()
		)
		_attach_spring_physics(act_btn)

	hbox.add_child(act_btn)
	return panel


func _refresh_achievements_ui() -> void:
	if achievements_modal == null:
		return

	var ach_list: Array = []
	if achievement_mgr and achievement_mgr.has_method("get_all_achievements"):
		ach_list = achievement_mgr.get_all_achievements()
	elif AchievementManagerScript != null:
		ach_list = AchievementManagerScript.ACHIEVEMENTS

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

		var card: Control = _create_achievement_item_card(
			ach.get("id", ""),
			ach.get("icon", "🏆"),
			loc_mgr.tr_text(ach.get("name_key", "")) if loc_mgr else ach.get("name", ""),
			loc_mgr.tr_text(ach.get("desc_key", "")) if loc_mgr else ach.get("desc", ""),
			is_unlocked
		)
		achievements_items_vbox.add_child(card)


func _create_achievement_item_card(_ach_id: String, _icon: String, title: String, desc: String, is_unlocked: bool) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = icon_trophy if is_unlocked else icon_lock
	hbox.add_child(icon_rect)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var title_lbl: Label = Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.30) if is_unlocked else Color(0.65, 0.70, 0.80))
	info_vbox.add_child(title_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98) if is_unlocked else Color(0.45, 0.50, 0.60))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var status_rect: TextureRect = TextureRect.new()
	status_rect.mouse_filter = Control.MOUSE_FILTER_PASS
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
	var tap_walk_on: bool = save_mgr.tap_to_walk_enabled if "tap_to_walk_enabled" in save_mgr else true

	if settings_title_label and loc_mgr:
		settings_title_label.text = loc_mgr.tr_text("SETTINGS_TITLE")
	if track_label and loc_mgr:
		track_label.text = loc_mgr.tr_text("SETTINGS_TRACK_TITLE")

	if music_slider:
		music_slider.set_value_no_signal(m_vol)
	if music_vol_label:
		if loc_mgr:
			music_vol_label.text = loc_mgr.tr_text("SETTINGS_MUSIC_VOL", [int(m_vol * 100)])
		else:
			music_vol_label.text = "MUSIC: %d%%" % int(m_vol * 100)

	if music_toggle_btn:
		if loc_mgr:
			var m_status: String = loc_mgr.tr_text("MENU_SOUND_ON" if m_on else "MENU_SOUND_OFF")
			music_toggle_btn.text = loc_mgr.tr_text("SETTINGS_MUSIC_TOGGLE", [m_status])
		else:
			var status_text: String = "ON" if m_on else "OFF"
			music_toggle_btn.text = "MUSIC: " + status_text

	if tap_walk_btn:
		if loc_mgr:
			var tw_status: String = loc_mgr.tr_text("MENU_SOUND_ON" if tap_walk_on else "MENU_SOUND_OFF")
			tap_walk_btn.text = loc_mgr.tr_text("SETTINGS_TAP_WALK", [tw_status])
		else:
			tap_walk_btn.text = "TAP TO WALK: %s" % ("ON" if tap_walk_on else "OFF")

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
	if loc_mgr and loc_mgr.has_method("apply_rtl"):
		for rtl_ctrl in [main_view, level_select_view, settings_modal, locker_modal, achievements_modal, credits_modal, star_vault_modal]:
			loc_mgr.apply_rtl(rtl_ctrl)
		if level_grid != null:
			level_grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
		if locker_preview_content != null:
			locker_preview_content.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var unlocked_lvl: int = save_mgr.unlocked_level if save_mgr else 0
	var last_lvl: int = save_mgr.last_played_level if save_mgr else 0
	var has_progress: bool = (unlocked_lvl > 0 or (save_mgr and save_mgr.is_level_completed(0)))
	var is_sound_on: bool = save_mgr.sound_enabled if save_mgr else true
	var is_haptics_on: bool = save_mgr.haptics_enabled if save_mgr else true

	if loc_mgr:
		if has_progress:
			if continue_btn != null:
				continue_btn.visible = true
				continue_btn.text = loc_mgr.tr_text("MENU_CONTINUE", [last_lvl + 1])
				continue_btn.theme_type_variation = &"PrimaryButton"
			if play_btn != null:
				play_btn.text = loc_mgr.tr_text("MENU_NEW_GAME")
				play_btn.theme_type_variation = &""
		else:
			if continue_btn != null:
				continue_btn.visible = false
			if play_btn != null:
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
			settings_btn.tooltip_text = ""
		if locker_btn:
			locker_btn.text = ""
			locker_btn.tooltip_text = ""
			if locker_btn_label != null:
				locker_btn_label.text = loc_mgr.tr_text("MENU_LOCKER")
			else:
				locker_btn.text = loc_mgr.tr_text("MENU_LOCKER")
		if achievements_btn:
			achievements_btn.text = ""
			achievements_btn.tooltip_text = ""
		if language_btn != null:
			language_btn.text = loc_mgr.tr_text("MENU_LANGUAGE", [loc_mgr.get_language_display_name()])
		if level_select_btn != null:
			level_select_btn.text = loc_mgr.tr_text("MENU_LEVEL_SELECT")
		if credits_btn != null:
			credits_btn.text = loc_mgr.tr_text("MENU_CREDITS")
		if back_btn != null:
			back_btn.text = loc_mgr.tr_text("BTN_BACK")
		var game_subtitle: Label = find_child("GameSubtitle", true, false) as Label
		if game_subtitle != null:
			game_subtitle.text = loc_mgr.tr_text("MAIN_SUBTITLE")
		var footer_lbl: Label = find_child("Footer", true, false) as Label
		if footer_lbl != null:
			footer_lbl.text = loc_mgr.tr_text("MAIN_FOOTER")
		for sec_i in range(4):
			var tab_node: Button = find_child("SectorTab%d" % sec_i, true, false) as Button
			if tab_node != null:
				var name_lbl: Label = tab_node.find_child("Name", true, false) as Label
				if name_lbl != null:
					name_lbl.text = loc_mgr.tr_text("SECTOR_TAB_%d" % sec_i)
		if has_node("LevelSelectView/TopBar/Margin/HBox/Title"):
			$LevelSelectView/TopBar/Margin/HBox/Title.text = loc_mgr.tr_text("LEVEL_SELECT_TITLE")
		if has_node("CreditsModal/VBox/Title"):
			$CreditsModal/VBox/Title.text = loc_mgr.tr_text("CREDITS_TITLE")
		if has_node("CreditsModal/VBox/Description"):
			$CreditsModal/VBox/Description.text = loc_mgr.tr_text("CREDITS_BODY")
		if close_credits_btn != null:
			close_credits_btn.text = loc_mgr.tr_text("BTN_CLOSE")
		if settings_modal != null and settings_modal.visible:
			_update_settings_ui()
		var tap_walk_val: bool = save_mgr.tap_to_walk_enabled if (save_mgr and "tap_to_walk_enabled" in save_mgr) else true
		if tap_walk_btn != null:
			var tw_s: String = loc_mgr.tr_text("MENU_SOUND_ON" if tap_walk_val else "MENU_SOUND_OFF")
			tap_walk_btn.text = loc_mgr.tr_text("SETTINGS_TAP_WALK", [tw_s])
	else:
		if has_progress:
			if continue_btn != null:
				continue_btn.visible = true
				continue_btn.text = "CONTINUE (LEVEL %d)" % (last_lvl + 1)
				continue_btn.theme_type_variation = &"PrimaryButton"
			if play_btn != null:
				play_btn.text = "NEW GAME"
				play_btn.theme_type_variation = &""
		else:
			if continue_btn != null:
				continue_btn.visible = false
			if play_btn != null:
				play_btn.text = "PLAY"
				play_btn.theme_type_variation = &"PrimaryButton"
		if settings_btn:
			settings_btn.text = ""
			settings_btn.tooltip_text = ""
		if locker_btn:
			locker_btn.text = ""
			locker_btn.tooltip_text = ""
			if locker_btn_label != null:
				locker_btn_label.text = "SUPPLY DEPOT"
			else:
				locker_btn.text = "SUPPLY DEPOT"
		if achievements_btn:
			achievements_btn.text = ""
			achievements_btn.tooltip_text = ""
		if sound_btn:
			sound_btn.text = "SOUND: %s" % ("ON" if is_sound_on else "OFF")
		if haptics_btn:
			haptics_btn.text = "HAPTICS: %s" % ("ON" if is_haptics_on else "OFF")
		if tap_walk_btn:
			var tw_en: bool = save_mgr.tap_to_walk_enabled if (save_mgr and "tap_to_walk_enabled" in save_mgr) else true
			tap_walk_btn.text = "TAP TO WALK: %s" % ("ON" if tw_en else "OFF")
		language_btn.text = "LANGUAGE: English"

	var total_stars: int = save_mgr.get_total_stars() if (save_mgr and save_mgr.has_method("get_total_stars")) else 0
	var total_crowns: int = save_mgr.get_total_crowns() if (save_mgr and save_mgr.has_method("get_total_crowns")) else 0
	var sector_idx: int = save_mgr.get_chapter_index(last_lvl) if (save_mgr and save_mgr.has_method("get_chapter_index")) else (0 if last_lvl < 15 else (1 if last_lvl < 35 else (2 if last_lvl < 50 else 3)))
	if star_progress_btn:
		var ch_title: String = "Cargo Bay"
		if loc_mgr and loc_mgr.has_method("tr_text"):
			ch_title = loc_mgr.tr_text("CHAPTER_%d_TITLE" % sector_idx)
		elif save_mgr and save_mgr.has_method("get_chapter_info"):
			ch_title = save_mgr.get_chapter_info(sector_idx).get("name", "Cargo Bay")
		if loc_mgr:
			if total_crowns > 0:
				star_progress_btn.text = loc_mgr.tr_text("STAR_PROGRESS_PILL_CROWN", [total_stars, total_crowns, sector_idx + 1, ch_title])
			else:
				star_progress_btn.text = loc_mgr.tr_text("STAR_PROGRESS_PILL", [total_stars, sector_idx + 1, ch_title])
		else:
			var crown_str: String = " • %d 👑" % total_crowns if total_crowns > 0 else ""
			star_progress_btn.text = "%d / 225 Stars%s • Sector %d: %s" % [total_stars, crown_str, sector_idx + 1, ch_title]
	if quick_lang_btn:
		var lang_code: String = loc_mgr.current_language.to_upper() if loc_mgr else "EN"
		quick_lang_btn.text = lang_code

	# Breakout Retention Engine: Daily Shift Hero Card
	if daily_shift_btn == null:
		var deck: VBoxContainer = find_child("ActionDeck", true, false) as VBoxContainer
		if deck != null:
			daily_shift_btn = Button.new()
			daily_shift_btn.name = "DailyShiftBtn"
			daily_shift_btn.custom_minimum_size = Vector2(0, 48)
			daily_shift_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			daily_shift_btn.theme_type_variation = &"SecondaryButton"
			daily_shift_btn.add_theme_font_size_override("font_size", 14)
			daily_shift_btn.icon = icon_calendar
			daily_shift_btn.expand_icon = true
			daily_shift_btn.add_theme_constant_override("icon_max_width", 22)
			daily_shift_btn.add_theme_constant_override("h_separation", 8)
			daily_shift_btn.pressed.connect(_on_daily_shift_pressed)
			_attach_spring_physics(daily_shift_btn)
			var dual_deck: Control = deck.find_child("DualDeck", false, false) as Control
			if dual_deck != null:
				deck.add_child(daily_shift_btn)
				deck.move_child(daily_shift_btn, dual_deck.get_index())
			else:
				deck.add_child(daily_shift_btn)

	if daily_shift_btn != null and save_mgr != null and save_mgr.has_method("get_daily_challenge_info"):
		daily_shift_btn.icon = icon_calendar
		daily_shift_btn.expand_icon = true
		daily_shift_btn.add_theme_constant_override("icon_max_width", 22)
		daily_shift_btn.add_theme_constant_override("h_separation", 8)
		var d_info: Dictionary = save_mgr.get_daily_challenge_info()
		var streak_count: int = d_info.get("streak", 0)
		var is_done: bool = d_info.get("is_completed", false)
		if is_done:
			daily_shift_btn.text = loc_mgr.tr_text("DAILY_SHIFT_CLEARED", [streak_count]) if loc_mgr else ("DAILY SHIFT: CLEARED ✓ (STREAK: %d)" % streak_count)
			daily_shift_btn.modulate = Color(0.80, 1.0, 0.85)
		else:
			if streak_count > 0:
				daily_shift_btn.text = loc_mgr.tr_text("DAILY_SHIFT_STREAK", [streak_count]) if loc_mgr else ("DAILY SHIFT • %d STREAK (+3 HINTS)" % streak_count)
			else:
				daily_shift_btn.text = loc_mgr.tr_text("DAILY_SHIFT_PLAY") if loc_mgr else "DAILY SHIFT • PLAY (+3 HINTS)"
			daily_shift_btn.modulate = Color(1.0, 0.92, 0.55)


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


func _on_tap_walk_toggle_pressed() -> void:
	if save_mgr:
		save_mgr.tap_to_walk_enabled = not save_mgr.tap_to_walk_enabled
		save_mgr.save_data()
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_update_settings_ui()
	_update_menu_state()


func _start_game_at_level(level_index: int) -> void:
	if save_mgr:
		save_mgr.last_played_level = level_index
	_transition_to_game()


func _build_level_grid() -> void:
	# Clear existing children
	for child in level_grid.get_children():
		child.queue_free()

	for i in range(TOTAL_LEVELS_COUNT):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 14)
		btn.set_meta("level_index", i)
		btn.pressed.connect(_on_level_button_pressed.bind(i))
		_attach_spring_physics(btn)
		level_grid.add_child(btn)

	_refresh_level_grid_buttons()


func _init_sector_styles() -> void:
	if _sector_styles_completed.size() > 0:
		return

	var sector_bg_colors: Array[Color] = [
		Color(0.11, 0.14, 0.19, 1.0), # S1: Cargo Bay
		Color(0.08, 0.14, 0.22, 1.0), # S2: Cold Storage
		Color(0.14, 0.13, 0.18, 1.0), # S3: Cyber Depot
		Color(0.13, 0.09, 0.22, 1.0)  # S4: Quantum Vault
	]
	var sector_border_colors: Array[Color] = [
		Color(0.88, 0.68, 0.22, 1.0), # Brass / Amber
		Color(0.28, 0.78, 0.96, 1.0), # Cryo Cyan
		Color(0.98, 0.75, 0.18, 1.0), # Laser Gold
		Color(0.78, 0.45, 0.96, 1.0)  # Quantum Violet
	]

	for i in range(4):
		var base_bg: Color = sector_bg_colors[i]
		var border_col: Color = sector_border_colors[i]

		var norm: StyleBoxFlat = StyleBoxFlat.new()
		norm.bg_color = base_bg
		norm.border_color = border_col
		norm.border_width_left = 2
		norm.border_width_top = 2
		norm.border_width_right = 2
		norm.border_width_bottom = 4
		norm.corner_radius_top_left = 8
		norm.corner_radius_top_right = 8
		norm.corner_radius_bottom_right = 8
		norm.corner_radius_bottom_left = 8
		norm.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.22)
		norm.shadow_size = 3
		norm.shadow_offset = Vector2(0, 2)
		norm.content_margin_left = 4.0
		norm.content_margin_top = 5.0
		norm.content_margin_right = 4.0
		norm.content_margin_bottom = 5.0
		_sector_styles_completed.append(norm)

		var hov: StyleBoxFlat = norm.duplicate()
		hov.bg_color = base_bg.lightened(0.12)
		hov.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.35)
		hov.shadow_size = 5
		_sector_styles_hover.append(hov)

		var prs: StyleBoxFlat = norm.duplicate()
		prs.bg_color = base_bg.darkened(0.15)
		prs.border_width_top = 4
		prs.border_width_bottom = 2
		prs.shadow_size = 1
		_sector_styles_pressed.append(prs)

	# Frontier unlocked style
	_frontier_style = StyleBoxFlat.new()
	_frontier_style.bg_color = Color(0.24, 0.18, 0.08, 1.0)
	_frontier_style.border_color = Color(1.0, 0.85, 0.22, 1.0)
	_frontier_style.border_width_left = 2
	_frontier_style.border_width_top = 2
	_frontier_style.border_width_right = 2
	_frontier_style.border_width_bottom = 4
	_frontier_style.corner_radius_top_left = 8
	_frontier_style.corner_radius_top_right = 8
	_frontier_style.corner_radius_bottom_right = 8
	_frontier_style.corner_radius_bottom_left = 8
	_frontier_style.shadow_color = Color(1.0, 0.85, 0.22, 0.40)
	_frontier_style.shadow_size = 6
	_frontier_style.shadow_offset = Vector2(0, 2)
	_frontier_style.content_margin_left = 4.0
	_frontier_style.content_margin_top = 5.0
	_frontier_style.content_margin_right = 4.0
	_frontier_style.content_margin_bottom = 5.0

	# Locked style
	_locked_style = StyleBoxFlat.new()
	_locked_style.bg_color = Color(0.08, 0.10, 0.14, 1.0)
	_locked_style.border_color = Color(0.18, 0.22, 0.28, 0.85)
	_locked_style.border_width_left = 1
	_locked_style.border_width_top = 1
	_locked_style.border_width_right = 1
	_locked_style.border_width_bottom = 3
	_locked_style.corner_radius_top_left = 8
	_locked_style.corner_radius_top_right = 8
	_locked_style.corner_radius_bottom_right = 8
	_locked_style.corner_radius_bottom_left = 8
	_locked_style.content_margin_left = 4.0
	_locked_style.content_margin_top = 5.0
	_locked_style.content_margin_right = 4.0
	_locked_style.content_margin_bottom = 5.0


func _setup_sector_tabs() -> void:
	var tab_icons: Array[Texture2D] = [icon_sector_1, icon_sector_2, icon_sector_3, icon_sector_4]
	var tab_colors: Array[Color] = [
		Color(0.88, 0.68, 0.22),
		Color(0.28, 0.78, 0.96),
		Color(0.98, 0.75, 0.18),
		Color(0.78, 0.45, 0.96)
	]

	var vault_card: PanelContainer = find_child("VaultMilestoneCard", true, false) as PanelContainer
	if vault_card != null:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.08, 0.12, 0.90)
		sb.border_color = Color(0.85, 0.65, 0.20, 0.65)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_right = 6
		sb.corner_radius_bottom_left = 6
		vault_card.add_theme_stylebox_override("panel", sb)

	for i in range(4):
		var tab_btn: Button = find_child("SectorTab%d" % i, true, false) as Button
		if tab_btn == null:
			continue

		var icon_rect: TextureRect = tab_btn.find_child("Icon", true, false) as TextureRect
		if icon_rect != null and i < tab_icons.size():
			icon_rect.texture = tab_icons[i]

		var col: Color = tab_colors[i]
		var tab_norm: StyleBoxFlat = StyleBoxFlat.new()
		tab_norm.bg_color = Color(0.08, 0.10, 0.15, 0.95)
		tab_norm.border_color = Color(col.r, col.g, col.b, 0.55)
		tab_norm.border_width_left = 1
		tab_norm.border_width_top = 1
		tab_norm.border_width_right = 1
		tab_norm.border_width_bottom = 2
		tab_norm.corner_radius_top_left = 8
		tab_norm.corner_radius_top_right = 8
		tab_norm.corner_radius_bottom_right = 8
		tab_norm.corner_radius_bottom_left = 8
		tab_btn.add_theme_stylebox_override("normal", tab_norm)

		var tab_hov: StyleBoxFlat = tab_norm.duplicate()
		tab_hov.bg_color = Color(0.12, 0.15, 0.22, 1.0)
		tab_hov.border_color = col
		tab_hov.shadow_color = Color(col.r, col.g, col.b, 0.3)
		tab_hov.shadow_size = 4
		tab_btn.add_theme_stylebox_override("hover", tab_hov)

		var tab_prs: StyleBoxFlat = tab_norm.duplicate()
		tab_prs.bg_color = Color(0.06, 0.08, 0.12, 1.0)
		tab_prs.border_color = col
		tab_btn.add_theme_stylebox_override("pressed", tab_prs)

		if not tab_btn.pressed.is_connected(_on_sector_tab_pressed.bind(i)):
			tab_btn.pressed.connect(_on_sector_tab_pressed.bind(i))
		_attach_spring_physics(tab_btn)


func _on_sector_tab_pressed(ch_idx: int) -> void:
	if _is_any_scroll_dragging():
		return
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()

	var tab_btn: Button = find_child("SectorTab%d" % ch_idx, true, false) as Button
	if tab_btn != null:
		var pulse_tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tab_btn.pivot_offset = tab_btn.size / 2.0
		pulse_tw.tween_property(tab_btn, "scale", Vector2(1.08, 1.08), 0.12)
		pulse_tw.tween_property(tab_btn, "scale", Vector2.ONE, 0.15)

	var scroll_cnt: ScrollContainer = find_child("Scroll", true, false) as ScrollContainer
	if scroll_cnt == null or level_grid == null:
		return

	if ch_idx == 0:
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(scroll_cnt, "scroll_vertical", 0, 0.35)
	else:
		var start_lvl: int = 0
		match ch_idx:
			1: start_lvl = 15
			2: start_lvl = 35
			3: start_lvl = 50
		if start_lvl < level_grid.get_child_count():
			var btn: Button = level_grid.get_child(start_lvl) as Button
			if btn != null:
				var v_scroll: VScrollBar = scroll_cnt.get_v_scroll_bar()
				var max_scroll: float = maxf(0.0, v_scroll.max_value - scroll_cnt.size.y) if v_scroll else 5000.0
				var target_scroll: float = clampf(level_grid.position.y + btn.position.y - 8.0, 0.0, max_scroll)
				var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(scroll_cnt, "scroll_vertical", int(target_scroll), 0.35)


func _refresh_level_grid_buttons() -> void:
	if current_level_pulse_tw != null and current_level_pulse_tw.is_valid():
		current_level_pulse_tw.kill()
		current_level_pulse_tw = null

	_init_sector_styles()

	var active_frontier_btn: Button = null
	var unlocked_lvl: int = save_mgr.unlocked_level if save_mgr else 0
	var total_stars: int = save_mgr.get_total_stars() if save_mgr != null else 0

	var total_crowns: int = save_mgr.get_total_crowns() if (save_mgr != null and save_mgr.has_method("get_total_crowns")) else 0

	if has_node("LevelSelectView/TopBar/Margin/HBox/TotalStarsLabel") and save_mgr != null:
		var stars_lbl: Label = get_node("LevelSelectView/TopBar/Margin/HBox/TotalStarsLabel") as Label
		if total_crowns > 0:
			stars_lbl.text = "%d / 225 ★  •  %d 👑" % [total_stars, total_crowns]
		else:
			stars_lbl.text = "%d / 225 ★" % total_stars

	# Update Campaign Banner card if present
	var pb: ProgressBar = find_child("ProgressBar", true, false) as ProgressBar
	if pb != null:
		pb.max_value = 225.0
		pb.value = float(total_stars)

	var next_vault_info: String = ""
	var next_vault_name: String = ""
	var next_vault_stars: int = 0
	if save_mgr != null and save_mgr.has_method("get_all_star_vaults"):
		var vaults: Array[Dictionary] = save_mgr.get_all_star_vaults()
		for v in vaults:
			if total_stars < v["stars"]:
				next_vault_name = v.get("name", "Supply Cache")
				next_vault_stars = v["stars"]
				next_vault_info = " • Next Vault: %s (%d★)" % [next_vault_name, next_vault_stars]
				break

	var campaign_title: Label = find_child("CampaignTitle", true, false) as Label
	if campaign_title != null and loc_mgr:
		campaign_title.text = loc_mgr.tr_text("CAMPAIGN_TITLE")
	var campaign_badge: Label = find_child("CampaignBadge", true, false) as Label
	if campaign_badge != null and loc_mgr:
		campaign_badge.text = loc_mgr.tr_text("CAMPAIGN_BADGE")

	var stars_count_lbl: Label = find_child("StarsCountLabel", true, false) as Label
	var vault_card: PanelContainer = find_child("VaultMilestoneCard", true, false) as PanelContainer
	var vault_lbl: Label = find_child("VaultMilestoneLabel", true, false) as Label
	var vault_icon_rect: TextureRect = find_child("VaultIcon", true, false) as TextureRect

	if stars_count_lbl != null:
		if vault_card != null and vault_lbl != null:
			stars_count_lbl.text = loc_mgr.tr_text("LOCKER_STARS_BADGE", [total_stars]) if loc_mgr else ("%d / 225 Stars Collected" % total_stars)
		else:
			var stars_base: String = loc_mgr.tr_text("LOCKER_STARS_BADGE", [total_stars]) if loc_mgr else ("%d / 225 Stars Collected" % total_stars)
			stars_count_lbl.text = "%s%s" % [stars_base, next_vault_info]

	if vault_card != null and vault_lbl != null:
		if next_vault_name != "":
			vault_lbl.text = loc_mgr.tr_text("NEXT_VAULT_LABEL", [next_vault_name.to_upper(), next_vault_stars]) if loc_mgr else ("NEXT VAULT: %s (%d★)" % [next_vault_name.to_upper(), next_vault_stars])
			if vault_icon_rect != null:
				vault_icon_rect.texture = icon_trophy
		else:
			vault_lbl.text = loc_mgr.tr_text("ALL_VAULTS_SECURED") if loc_mgr else "ALL VAULT REWARDS SECURED ✓"
			if vault_icon_rect != null:
				vault_icon_rect.texture = icon_check

	var completion_lbl: Label = find_child("CompletionLabel", true, false) as Label
	if completion_lbl != null and save_mgr != null:
		var completed_count: int = 0
		for i in range(TOTAL_LEVELS_COUNT):
			if save_mgr.is_level_completed(i):
				completed_count += 1
		var pct: int = int((float(completed_count) / float(TOTAL_LEVELS_COUNT)) * 100.0)
		completion_lbl.text = loc_mgr.tr_text("CAMPAIGN_COMPLETION", [completed_count, pct]) if loc_mgr else ("%d/75 Cleared • %d%%" % [completed_count, pct])

	var s1_stars: int = save_mgr.get_chapter_stars(0) if save_mgr else 0
	var s2_stars: int = save_mgr.get_chapter_stars(1) if save_mgr else 0
	var s3_stars: int = save_mgr.get_chapter_stars(2) if save_mgr else 0
	var s4_stars: int = save_mgr.get_chapter_stars(3) if save_mgr else 0
	var s1_crowns: int = save_mgr.get_chapter_crowns(0) if (save_mgr and save_mgr.has_method("get_chapter_crowns")) else 0
	var s2_crowns: int = save_mgr.get_chapter_crowns(1) if (save_mgr and save_mgr.has_method("get_chapter_crowns")) else 0
	var s3_crowns: int = save_mgr.get_chapter_crowns(2) if (save_mgr and save_mgr.has_method("get_chapter_crowns")) else 0
	var s4_crowns: int = save_mgr.get_chapter_crowns(3) if (save_mgr and save_mgr.has_method("get_chapter_crowns")) else 0

	var s1_badge: Label = find_child("Sector1Badge", true, false) as Label
	if s1_badge != null:
		s1_badge.text = ("%d/45 ★ • %d 👑" % [s1_stars, s1_crowns]) if s1_crowns > 0 else ("%d/45 ★" % s1_stars)

	var s2_badge: Label = find_child("Sector2Badge", true, false) as Label
	if s2_badge != null:
		s2_badge.text = ("%d/60 ★ • %d 👑" % [s2_stars, s2_crowns]) if s2_crowns > 0 else ("%d/60 ★" % s2_stars)

	var s3_badge: Label = find_child("Sector3Badge", true, false) as Label
	if s3_badge != null:
		s3_badge.text = ("%d/45 ★ • %d 👑" % [s3_stars, s3_crowns]) if s3_crowns > 0 else ("%d/45 ★" % s3_stars)

	var s4_badge: Label = find_child("Sector4Badge", true, false) as Label
	if s4_badge != null:
		s4_badge.text = ("%d/75 ★ • %d 👑" % [s4_stars, s4_crowns]) if s4_crowns > 0 else ("%d/75 ★" % s4_stars)

	for child in level_grid.get_children():
		if not child is Button:
			continue
		var lvl_idx: int = child.get_meta("level_index", 0)
		var is_available: bool = (lvl_idx < AVAILABLE_LEVELS_COUNT)
		var is_unlocked: bool = is_available and (lvl_idx <= unlocked_lvl)
		var is_completed: bool = save_mgr != null and save_mgr.is_level_completed(lvl_idx)

		var ch_idx: int = save_mgr.get_chapter_index(lvl_idx) if (save_mgr != null and save_mgr.has_method("get_chapter_index")) else (0 if lvl_idx < 15 else (1 if lvl_idx < 35 else (2 if lvl_idx < 50 else 3)))
		var ch_info: Dictionary = save_mgr.get_chapter_info(ch_idx) if (save_mgr != null and save_mgr.has_method("get_chapter_info")) else {"color": Color(1.0, 1.0, 1.0)}
		var opt_moves: int = save_mgr.get_optimal_moves(lvl_idx) if save_mgr else 15
		var ch_title_str: String = ch_info.get("name", "Cargo Bay")
		if loc_mgr and loc_mgr.has_method("tr_text"):
			ch_title_str = loc_mgr.tr_text("CHAPTER_%d_TITLE" % ch_idx)
		var is_mobile_or_touch: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
		if not is_mobile_or_touch:
			child.tooltip_text = "Level %d • %s\nOptimal Par: ≤ %d moves" % [lvl_idx + 1, ch_title_str, opt_moves]
		else:
			child.tooltip_text = ""

		if is_completed:
			var record: Dictionary = save_mgr.get_level_record(lvl_idx)
			var stars: int = record.get("stars", 1)
			var best_moves: int = record.get("best_moves", record.get("moves", 0))
			var is_crowned: bool = save_mgr.is_level_crowned(lvl_idx) if save_mgr.has_method("is_level_crowned") else false
			if not is_mobile_or_touch:
				var crown_tag: String = " 👑" if is_crowned else ""
				child.tooltip_text = "Level %d • %s%s\nBest: %d moves (Par: ≤ %d)" % [lvl_idx + 1, ch_title_str, crown_tag, best_moves, opt_moves]
			else:
				child.tooltip_text = ""
			var star_str: String = ""
			if is_crowned:
				star_str = "👑 ★★★"
			else:
				match stars:
					3: star_str = "★★★"
					2: star_str = "★★☆"
					1: star_str = "★☆☆"
					_: star_str = "★"
			child.text = "%d\n%s" % [lvl_idx + 1, star_str]
			child.icon = null
			child.disabled = false
			child.theme_type_variation = &"LevelBtnCompleted"
			child.modulate = Color.WHITE
			if ch_idx < _sector_styles_completed.size():
				child.add_theme_stylebox_override("normal", _sector_styles_completed[ch_idx])
				child.add_theme_stylebox_override("hover", _sector_styles_hover[ch_idx])
				child.add_theme_stylebox_override("pressed", _sector_styles_pressed[ch_idx])
				child.add_theme_color_override("font_color", _sector_font_colors[ch_idx])
		elif is_unlocked:
			child.text = "%d" % [lvl_idx + 1]
			child.icon = null
			child.disabled = false
			child.theme_type_variation = &"LevelBtnCurrent"
			child.modulate = Color.WHITE
			if _frontier_style != null:
				child.add_theme_stylebox_override("normal", _frontier_style)
				child.add_theme_stylebox_override("hover", _frontier_style)
				child.add_theme_stylebox_override("pressed", _frontier_style)
			if active_frontier_btn == null:
				active_frontier_btn = child
		else:
			if is_available:
				child.text = "%d" % [lvl_idx + 1]
				child.add_theme_font_size_override("font_size", 13)
				child.icon = icon_lock
				child.expand_icon = true
				child.add_theme_constant_override("icon_max_width", 14)
				child.add_theme_constant_override("h_separation", 4)
				child.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				child.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
				child.add_theme_color_override("icon_disabled_color", Color(1.0, 1.0, 1.0, 0.72))
				if not is_mobile_or_touch:
					child.tooltip_text = "Level %d • %s (Locked)" % [lvl_idx + 1, ch_title_str]
				else:
					child.tooltip_text = ""
			else:
				child.text = ""
				child.icon = null
			child.disabled = true
			child.theme_type_variation = &"LevelBtnLocked"
			child.modulate = Color.WHITE
			if _locked_style != null:
				child.add_theme_stylebox_override("disabled", _locked_style)
				child.add_theme_stylebox_override("normal", _locked_style)

	if active_frontier_btn != null and active_frontier_btn.is_inside_tree():
		var p_sz: Vector2 = active_frontier_btn.custom_minimum_size if active_frontier_btn.size == Vector2.ZERO else active_frontier_btn.size
		active_frontier_btn.pivot_offset = p_sz / 2.0
		if current_level_pulse_tw and current_level_pulse_tw.is_valid():
			current_level_pulse_tw.kill()
		current_level_pulse_tw = create_tween().set_loops()
		current_level_pulse_tw.tween_property(active_frontier_btn, "scale", Vector2(1.05, 1.05), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		current_level_pulse_tw.tween_property(active_frontier_btn, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_scroll_to_button(active_frontier_btn)


func _scroll_to_button(btn: Button) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree() or get_tree() == null:
		return
	var scroll_cnt: ScrollContainer = find_child("Scroll", true, false) as ScrollContainer
	if scroll_cnt == null or not is_instance_valid(scroll_cnt) or not scroll_cnt.is_inside_tree():
		return
	call_deferred("_do_scroll_to_button", scroll_cnt, btn)


func _do_scroll_to_button(scroll_cnt: ScrollContainer, btn: Button) -> void:
	if not is_instance_valid(scroll_cnt) or not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	var v_scroll: VScrollBar = scroll_cnt.get_v_scroll_bar()
	if v_scroll != null and v_scroll.max_value > scroll_cnt.size.y:
		var btn_y: float = btn.global_position.y - scroll_cnt.global_position.y + scroll_cnt.scroll_vertical
		var target_scroll: float = btn_y - (scroll_cnt.size.y * 0.4)
		var max_scroll: float = maxf(0.0, v_scroll.max_value - scroll_cnt.size.y)
		target_scroll = clampf(target_scroll, 0.0, max_scroll)
		var tw: Tween = create_tween()
		if tw != null:
			tw.tween_property(scroll_cnt, "scroll_vertical", int(target_scroll), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _is_any_scroll_dragging() -> bool:
	for ctrl in _touch_scroll_controllers:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.has_method("is_drag_scrolling"):
			if ctrl.is_drag_scrolling():
				return true
	return false


func _reset_active_spring_button() -> void:
	if _active_spring_button != null and is_instance_valid(_active_spring_button):
		var btn: Button = _active_spring_button
		_active_spring_button = null
		var sz: Vector2 = btn.custom_minimum_size if btn.size == Vector2.ZERO else btn.size
		btn.pivot_offset = sz / 2.0
		var tw: Tween = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)


func _setup_touch_scrolling() -> void:
	_touch_scroll_controllers.clear()
	var scroll_candidates: Array[ScrollContainer] = []
	if level_select_view != null:
		var ls_scroll: ScrollContainer = level_select_view.find_child("Scroll", true, false) as ScrollContainer
		if ls_scroll != null:
			scroll_candidates.append(ls_scroll)
	if locker_modal != null:
		var lk_scroll: ScrollContainer = locker_modal.find_child("Scroll", true, false) as ScrollContainer
		if lk_scroll != null:
			scroll_candidates.append(lk_scroll)
	if achievements_modal != null:
		var ach_scroll: ScrollContainer = achievements_modal.find_child("Scroll", true, false) as ScrollContainer
		if ach_scroll != null:
			scroll_candidates.append(ach_scroll)
	if settings_modal != null:
		var set_scroll: ScrollContainer = settings_modal.find_child("Scroll", true, false) as ScrollContainer
		if set_scroll != null:
			scroll_candidates.append(set_scroll)

	for s in scroll_candidates:
		if s != null:
			var ctrl: TouchScrollController = TouchScrollController.new(self, s)
			s.add_child(ctrl)
			_touch_scroll_controllers.append(ctrl)


func _on_level_button_pressed(level_index: int) -> void:
	if _is_any_scroll_dragging():
		return
	if level_index < AVAILABLE_LEVELS_COUNT:
		if save_mgr and not save_mgr.is_level_unlocked(level_index):
			return
		_start_game_at_level(level_index)


func _attach_spring_physics(btn: Button) -> void:
	if btn == null or btn.has_meta("has_spring_physics"):
		return
	btn.set_meta("has_spring_physics", true)
	var calc_pivot: Callable = func() -> void:
		var sz: Vector2 = btn.custom_minimum_size if btn.size == Vector2.ZERO else btn.size
		btn.pivot_offset = sz / 2.0
	calc_pivot.call()
	btn.button_down.connect(func():
		_active_spring_button = btn
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.07)
	)
	btn.button_up.connect(func():
		if _active_spring_button == btn:
			_active_spring_button = null
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)
	btn.mouse_exited.connect(func():
		if _active_spring_button == btn:
			_active_spring_button = null
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)


# ==============================================================================
# Breakout Retention Engine: Daily Shift & Star Vault Milestones
# ==============================================================================

func _on_daily_shift_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if save_mgr != null and save_mgr.has_method("get_daily_challenge_info"):
		var d_info: Dictionary = save_mgr.get_daily_challenge_info()
		save_mgr.set_meta("is_daily_challenge", true)
		save_mgr.last_played_level = d_info["level_index"]
	_transition_to_game()


func _check_star_vault_milestones() -> void:
	if save_mgr == null or not save_mgr.has_method("get_unclaimed_star_vaults"):
		return
	var unclaimed: Array[Dictionary] = save_mgr.get_unclaimed_star_vaults()
	if unclaimed.is_empty():
		return
	var target: Dictionary = unclaimed[0]
	_show_star_vault_modal(target["index"], target["vault"])


func _show_star_vault_modal(vault_idx: int, vault: Dictionary) -> void:
	if star_vault_modal == null:
		star_vault_modal = _create_star_vault_modal()

	_show_modal_backdrop()

	var title_lbl: Label = star_vault_modal.find_child("VaultTitleLabel", true, false) as Label
	var icon_lbl: Label = star_vault_modal.find_child("VaultIconLabel", true, false) as Label
	var name_lbl: Label = star_vault_modal.find_child("VaultNameLabel", true, false) as Label
	var desc_lbl: Label = star_vault_modal.find_child("VaultDescLabel", true, false) as Label
	var claim_btn: Button = star_vault_modal.find_child("ClaimVaultBtn", true, false) as Button

	if title_lbl:
		title_lbl.text = loc_mgr.tr_text("VAULT_UNLOCKED_TITLE") if loc_mgr else "★ STAR VAULT UNLOCKED! ★"
	var icon_rect: TextureRect = star_vault_modal.find_child("VaultIconRect", true, false) as TextureRect
	if icon_rect:
		if vault.get("reward_type") == "hints":
			icon_rect.texture = icon_hint
		else:
			icon_rect.texture = icon_locker
	if icon_lbl:
		icon_lbl.text = ""
		icon_lbl.visible = false
	if name_lbl:
		var v_name: String = vault.get("name", loc_mgr.tr_text("STAR_VAULT_STASH") if loc_mgr else "Supply Cache")
		var v_stars: int = vault.get("stars", 15)
		name_lbl.text = loc_mgr.tr_text("VAULT_NAME_FORMAT", [v_name, v_stars]) if loc_mgr else ("%s (%d Stars)" % [v_name, v_stars])
	if desc_lbl:
		if vault.get("reward_type") == "hints":
			desc_lbl.text = loc_mgr.tr_text("VAULT_DESC_HINTS", [vault.get("amount", 5)]) if loc_mgr else ("Congratulations! You earned +%d Free Solver Hints for your dedication!" % vault.get("amount", 5))
		else:
			var s_id: String = vault.get("skin_id", "")
			var is_crate: bool = false
			if save_mgr and save_mgr.has_method("get_all_crate_skins"):
				for cs in save_mgr.get_all_crate_skins():
					if cs.get("id", "") == s_id:
						is_crate = true
						break
			if is_crate:
				desc_lbl.text = loc_mgr.tr_text("VAULT_DESC_CRATE") if loc_mgr else "Exclusive Crate Skin Unlocked! Visit the Supply Depot to equip your new gear!"
			else:
				desc_lbl.text = loc_mgr.tr_text("VAULT_DESC_OUTFIT") if loc_mgr else "Exclusive Outfit Unlocked! Visit the Supply Depot to equip your new gear!"

	if claim_btn:
		claim_btn.text = loc_mgr.tr_text("BTN_CLAIM_REWARD") if loc_mgr else "CLAIM REWARD"
	var close_v_btn: Button = star_vault_modal.find_child("CloseVaultBtn", true, false) as Button
	if close_v_btn:
		close_v_btn.text = loc_mgr.tr_text("BTN_LATER") if loc_mgr else "LATER"
	if loc_mgr and loc_mgr.has_method("apply_rtl"):
		loc_mgr.apply_rtl(star_vault_modal)

	if claim_btn:
		for conn in claim_btn.pressed.get_connections():
			claim_btn.pressed.disconnect(conn.callable)
		claim_btn.pressed.connect(func():
			if save_mgr and save_mgr.has_method("claim_star_vault"):
				save_mgr.claim_star_vault(vault_idx)
			if audio_mgr:
				audio_mgr.play_win()
			if haptic_mgr:
				haptic_mgr.vibrate_target()
			_hide_star_vault_modal()
			_update_menu_state()
			_refresh_level_grid_buttons()
		)

	star_vault_modal.show()
	star_vault_modal.modulate.a = 0.0
	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(star_vault_modal, "modulate:a", 1.0, 0.20)
	if audio_mgr:
		audio_mgr.play_star(3)


func _hide_star_vault_modal() -> void:
	if star_vault_modal:
		star_vault_modal.hide()
	_hide_modal_backdrop()


func _create_star_vault_modal() -> PanelContainer:
	var modal: PanelContainer = PanelContainer.new()
	modal.name = "StarVaultModal"
	modal.anchors_preset = Control.PRESET_FULL_RECT
	modal.anchor_right = 1.0
	modal.anchor_bottom = 1.0
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center: CenterContainer = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	modal.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 260)
	card.theme_type_variation = &"ConsoleCard"
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.name = "VaultTitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	vbox.add_child(title_lbl)

	var icon_lbl: Label = Label.new()
	icon_lbl.name = "VaultIconLabel"
	icon_lbl.visible = false
	vbox.add_child(icon_lbl)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = "VaultIconRect"
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	var name_lbl: Label = Label.new()
	name_lbl.name = "VaultNameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	vbox.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.name = "VaultDescLabel"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	vbox.add_child(desc_lbl)

	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_vbox)

	var claim_btn: Button = Button.new()
	claim_btn.name = "ClaimVaultBtn"
	claim_btn.text = "CLAIM REWARD"
	claim_btn.custom_minimum_size = Vector2(0, 44)
	claim_btn.theme_type_variation = &"PrimaryButton"
	_attach_spring_physics(claim_btn)
	btn_vbox.add_child(claim_btn)

	var close_btn: Button = Button.new()
	close_btn.name = "CloseVaultBtn"
	close_btn.text = "LATER"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.pressed.connect(_hide_star_vault_modal)
	_attach_spring_physics(close_btn)
	btn_vbox.add_child(close_btn)

	add_child(modal)
	return modal


# ==============================================================================
# Touch & Drag Scroll Controller for Mobile Viewports
# Allows smooth drag-scrolling even when holding down on interactive buttons
# ==============================================================================

class TouchScrollController extends Node:
	var menu: Control = null
	var scroll_cnt: ScrollContainer = null
	var touch_active: bool = false
	var touch_id: int = -1
	var start_pos: Vector2 = Vector2.ZERO
	var last_pos: Vector2 = Vector2.ZERO
	var start_scroll: float = 0.0
	var is_scrolling: bool = false
	var last_scroll_msec: int = 0
	var velocity_y: float = 0.0
	var last_time: float = 0.0
	var inertia_tw: Tween = null
	const THRESHOLD: float = 8.0

	func _init(p_menu: Control, p_scroll: ScrollContainer) -> void:
		menu = p_menu
		scroll_cnt = p_scroll

	func _input(event: InputEvent) -> void:
		if scroll_cnt == null or not is_instance_valid(scroll_cnt) or not scroll_cnt.is_visible():
			return

		var s_rect: Rect2 = scroll_cnt.get_global_rect()
		var in_bounds: bool = (s_rect.size == Vector2.ZERO or s_rect.has_point(event.position))

		if event is InputEventScreenTouch:
			if event.pressed:
				if not touch_active and in_bounds:
					if inertia_tw and inertia_tw.is_valid():
						inertia_tw.kill()
					touch_active = true
					touch_id = event.index
					start_pos = event.position
					last_pos = event.position
					start_scroll = float(scroll_cnt.scroll_vertical)
					is_scrolling = false
					velocity_y = 0.0
					last_time = Time.get_ticks_msec() / 1000.0
			elif event.index == touch_id:
				_finish_touch()

		elif event is InputEventScreenDrag:
			if touch_active and event.index == touch_id:
				_handle_drag(event.position)

		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					if not touch_active and in_bounds:
						if inertia_tw and inertia_tw.is_valid():
							inertia_tw.kill()
						touch_active = true
						touch_id = -1
						start_pos = event.position
						last_pos = event.position
						start_scroll = float(scroll_cnt.scroll_vertical)
						is_scrolling = false
						velocity_y = 0.0
						last_time = Time.get_ticks_msec() / 1000.0
				elif touch_active and touch_id == -1:
					_finish_touch()

		elif event is InputEventMouseMotion:
			if touch_active and touch_id == -1 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				_handle_drag(event.position)

	func _handle_drag(curr_pos: Vector2) -> void:
		var delta_y: float = curr_pos.y - start_pos.y
		if not is_scrolling and abs(delta_y) > THRESHOLD:
			is_scrolling = true
			if menu != null and is_instance_valid(menu) and menu.has_method("_reset_active_spring_button"):
				menu._reset_active_spring_button()

		if is_scrolling:
			var now: float = Time.get_ticks_msec() / 1000.0
			var dt: float = maxf(0.001, now - last_time)
			velocity_y = (curr_pos.y - last_pos.y) / dt
			last_pos = curr_pos
			last_time = now
			last_scroll_msec = Time.get_ticks_msec()

			var v_scroll: VScrollBar = scroll_cnt.get_v_scroll_bar()
			var max_v: float = maxf(0.0, (v_scroll.max_value - v_scroll.page) if v_scroll else 5000.0)
			var target: float = clampf(start_scroll - delta_y, 0.0, max_v)
			scroll_cnt.scroll_vertical = int(target)

	func _finish_touch() -> void:
		if not touch_active:
			return
		touch_active = false
		if is_scrolling:
			last_scroll_msec = Time.get_ticks_msec()
			if abs(velocity_y) > 120.0 and scroll_cnt.is_inside_tree():
				var v_scroll: VScrollBar = scroll_cnt.get_v_scroll_bar()
				var max_v: float = maxf(0.0, (v_scroll.max_value - v_scroll.page) if v_scroll else 5000.0)
				var fling_dist: float = velocity_y * 0.22
				var final_target: float = clampf(float(scroll_cnt.scroll_vertical) - fling_dist, 0.0, max_v)
				if inertia_tw and inertia_tw.is_valid():
					inertia_tw.kill()
				inertia_tw = scroll_cnt.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				inertia_tw.tween_property(scroll_cnt, "scroll_vertical", int(final_target), 0.35)

		if scroll_cnt.is_inside_tree():
			var tr: SceneTree = scroll_cnt.get_tree()
			if tr != null:
				tr.create_timer(0.12).timeout.connect(func():
					is_scrolling = false
				)
			else:
				is_scrolling = false
		else:
			is_scrolling = false

	func is_drag_scrolling() -> bool:
		return is_scrolling or (Time.get_ticks_msec() - last_scroll_msec < 120)
