extends Control

## Main menu and Level Select controller for Pixel Porter.
## Implements PRD Section 6 flow:
## - Continue / Play navigation
## - Level select 75-level grid with locked/completed visual states
## - Sound on/off toggle persisted via SaveManager
## - Credits popup

const SaveManagerScript: GDScript = preload("res://scripts/save_manager.gd")
const AchievementManagerScript: GDScript = preload("res://scripts/achievement_manager.gd")
const CosmeticRendererScript: GDScript = preload("res://scripts/cosmetic_renderer.gd")
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
var icon_back: Texture2D = preload("res://assets/icons/icon_back.png")
var icon_levels: Texture2D = preload("res://assets/icons/icon_levels.png")
var icon_crown: Texture2D = preload("res://assets/icons/icon_crown.png")
var icon_music_on: Texture2D = preload("res://assets/icons/icon_music_on.png")
var icon_music_off: Texture2D = preload("res://assets/icons/icon_music_off.png")
var icon_sfx: Texture2D = preload("res://assets/icons/icon_sfx.png")
var icon_haptics: Texture2D = preload("res://assets/icons/icon_haptics.png")
var icon_globe: Texture2D = preload("res://assets/icons/icon_globe.png")
var icon_info: Texture2D = preload("res://assets/icons/icon_info.png")
var icon_control_swipe: Texture2D = preload("res://assets/icons/icon_control_swipe.png")
var icon_control_dpad: Texture2D = preload("res://assets/icons/icon_control_dpad.png")
var icon_control_gamepad: Texture2D = preload("res://assets/icons/icon_control_gamepad.png")

# Thematic Sector Dispatch Styling & Cached StyleBoxes
var _sector_styles_completed: Array[StyleBoxFlat] = []
var _sector_styles_hover: Array[StyleBoxFlat] = []
var _sector_styles_pressed: Array[StyleBoxFlat] = []
var _sector_styles_locked: Array[StyleBoxFlat] = []
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
var tex_player_up: Texture2D = preload("res://assets/player_up.png")
var tex_player_up_w1: Texture2D = preload("res://assets/player_up_walk1.png")
var tex_player_up_w2: Texture2D = preload("res://assets/player_up_walk2.png")
var tex_player_left: Texture2D = preload("res://assets/player_left.png")
var tex_player_left_w1: Texture2D = preload("res://assets/player_left_walk1.png")
var tex_player_left_w2: Texture2D = preload("res://assets/player_left_walk2.png")
var tex_player_right: Texture2D = preload("res://assets/player_right.png")
var tex_player_right_w1: Texture2D = preload("res://assets/player_right_walk1.png")
var tex_player_right_w2: Texture2D = preload("res://assets/player_right_walk2.png")
var tex_crate: Texture2D = preload("res://assets/crate_normal.png")
var tex_crate_goal: Texture2D = preload("res://assets/crate_goal.png")
var tex_goal_pad: Texture2D = preload("res://assets/goal_pad.png")
var _font_rubik_base: FontFile = preload("res://assets/fonts/Rubik-Variable.ttf")
var _font_arabic_fallback: FontFile = preload("res://assets/fonts/NotoSansArabic-Bold.ttf")
var _ui_fonts: Dictionary = {}
var _vault_emblem_kind: String = "cube"
var _vault_emblem_accent: Color = Color(0.92, 0.72, 0.34)
var _vault_emblem_skin_id: String = ""
var _vault_emblem_is_skin: bool = false
var _vault_emblem_canvas: Control = null
var _star_vault_anim_time: float = 0.0

var _preview_anim_time: float = 0.0
var _preview_worker_skin_id: String = ""
var _preview_crate_skin_id: String = ""
var _preview_dir_timer: float = 0.0

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
@onready var level_select_btn_label: Label = find_child("LevelSelectBtn", true, false).find_child("Label", true, false) as Label if find_child("LevelSelectBtn", true, false) else null
@onready var level_select_btn_icon: TextureRect = find_child("LevelSelectBtn", true, false).find_child("Icon", true, false) as TextureRect if find_child("LevelSelectBtn", true, false) else null
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
var _logo_tw: Tween = null
var _subtitle_tw: Tween = null
var _star_vault_tw: Tween = null
var _vault_toast_tw: Tween = null
var daily_shift_btn: Button = null
var vault_ready_btn: Button = null
var star_vault_modal: PanelContainer = null
var _vault_claim_toast: PanelContainer = null
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
		if level_select_btn != null:
			level_select_btn_label = level_select_btn.find_child("Label", true, false) as Label
			level_select_btn_icon = level_select_btn.find_child("Icon", true, false) as TextureRect
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
		if not safe_area_mgr.safe_area_changed.is_connected(_on_safe_area_changed):
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
		_setup_center_box_button(locker_btn, locker_btn_icon, icon_locker, locker_btn_label)
	if star_progress_btn:
		_style_star_progress_pill()
	if level_select_btn:
		if level_select_btn_icon != null and level_select_btn_label != null:
			_setup_center_box_button(level_select_btn, level_select_btn_icon, icon_levels, level_select_btn_label)
		else:
			_apply_button_icon(level_select_btn, icon_levels, 20, 8)

	_init_sector_styles()
	_setup_sector_tabs()
	if back_btn:
		_style_back_pill_button()

	_show_main_view()
	_update_menu_state()
	_build_level_grid()

	# Ambient breathing animation on logo and subtitle
	_start_ambient_logo_tweens()

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


func _exit_tree() -> void:
	_stop_ambient_logo_tweens()
	if current_level_pulse_tw != null and current_level_pulse_tw.is_valid():
		current_level_pulse_tw.kill()
		current_level_pulse_tw = null
	if _star_vault_tw != null and _star_vault_tw.is_valid():
		_star_vault_tw.kill()
		_star_vault_tw = null
	if _vault_toast_tw != null and _vault_toast_tw.is_valid():
		_vault_toast_tw.kill()
		_vault_toast_tw = null


func _start_ambient_logo_tweens() -> void:
	_stop_ambient_logo_tweens()
	if DisplayServer.get_name() == "headless":
		return
	var logo: TextureRect = find_child("LogoRect", true, false) as TextureRect
	if logo != null and logo.is_inside_tree():
		logo.pivot_offset = Vector2(150, 84)
		_logo_tw = logo.create_tween().set_loops()
		_logo_tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_logo_tw.tween_property(logo, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var subtitle: Label = find_child("GameSubtitle", true, false) as Label
	if subtitle != null and subtitle.is_inside_tree():
		_subtitle_tw = subtitle.create_tween().set_loops()
		_subtitle_tw.tween_property(subtitle, "modulate:a", 0.72, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_subtitle_tw.tween_property(subtitle, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_ambient_logo_tweens() -> void:
	if _logo_tw != null and _logo_tw.is_valid():
		_logo_tw.kill()
	_logo_tw = null
	if _subtitle_tw != null and _subtitle_tw.is_valid():
		_subtitle_tw.kill()
	_subtitle_tw = null


func _handle_menu_back_request() -> bool:
	if star_vault_modal != null and star_vault_modal.visible:
		_hide_star_vault_modal()
		return true
	elif credits_modal != null and credits_modal.visible:
		_hide_credits()
		return true
	elif settings_modal != null and settings_modal.visible:
		_hide_settings()
		return true
	elif locker_modal != null and locker_modal.visible:
		_hide_locker()
		return true
	elif achievements_modal != null and achievements_modal.visible:
		_hide_achievements()
		return true
	elif level_select_view != null and level_select_view.visible:
		_show_main_view()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo():
		if _handle_menu_back_request() and get_viewport():
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _handle_menu_back_request() and get_viewport():
			get_viewport().set_input_as_handled()
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
				safe_area_mgr.apply_safe_area_margins(main_top_bar, 16, 18, 16, 8, true, false)
		if has_node("MainView/BottomMargin"):
			var main_bottom: MarginContainer = get_node("MainView/BottomMargin") as MarginContainer
			if main_bottom != null:
				safe_area_mgr.apply_safe_area_margins(main_bottom, 32, 0, 32, 24, false, true)


func _on_safe_area_changed(_insets: Dictionary) -> void:
	_apply_safe_area()
	for m in [settings_modal, locker_modal, achievements_modal, credits_modal]:
		if m != null and m.visible:
			_clamp_modal_to_safe_area(m)
	if star_vault_modal != null and star_vault_modal.visible:
		var card_ctrl: Control = star_vault_modal.find_child("VaultCard", true, false) as Control
		if card_ctrl != null:
			var vp_sz: Vector2 = get_viewport_rect().size if (is_inside_tree() and get_viewport() != null) else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
			var insets: Dictionary = safe_area_mgr.get_safe_insets(self) if safe_area_mgr else {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
			var avail_w: float = maxf(260.0, vp_sz.x - insets.get("left", 0.0) - insets.get("right", 0.0) - 32.0)
			card_ctrl.custom_minimum_size.x = minf(360.0, avail_w)


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
	_start_ambient_logo_tweens()
	_check_star_vault_milestones()


func _show_level_select() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	_stop_ambient_logo_tweens()
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
			(credits_modal and credits_modal.visible) or
			(star_vault_modal and star_vault_modal.visible)
		):
			modal_blur_overlay.hide()
	)


func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	var pressed_tap: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or
		(event is InputEventScreenTouch and event.pressed)
	)
	if pressed_tap:
		if star_vault_modal and star_vault_modal.visible:
			_hide_star_vault_modal()
		elif locker_modal and locker_modal.visible:
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
		modal.offset_left = - target_w * 0.5
		modal.offset_right = target_w * 0.5
	if target_h > 0.0:
		var y_bias: float = (insets.get("top", 0.0) - insets.get("bottom", 0.0)) * 0.5
		modal.offset_top = - target_h * 0.5 + y_bias
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
	if save_mgr:
		_preview_worker_skin_id = save_mgr.selected_worker_skin
		_preview_crate_skin_id = save_mgr.selected_crate_skin
	_preview_dir_timer = 0.0
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


func _apply_locker_tab_styles() -> void:
	var tab_buttons: Array = [
		[outfits_tab_btn, current_locker_tab == "outfits"],
		[crates_tab_btn, current_locker_tab == "crates"]
	]
	for pair in tab_buttons:
		var btn: Button = pair[0] as Button
		var is_active: bool = bool(pair[1])
		if btn == null:
			continue
		btn.clip_contents = true
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		if is_active:
			btn.theme_type_variation = &"PrimaryButton"
			for s_name in ["normal", "hover", "pressed"]:
				btn.remove_theme_stylebox_override(s_name)
			btn.add_theme_font_override("font", _get_modern_font(600))
			for c_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				btn.add_theme_color_override(c_name, Color(0.067, 0.078, 0.110, 1.0))
		else:
			btn.theme_type_variation = &""
			var sb_idle: StyleBoxFlat = StyleBoxFlat.new()
			sb_idle.bg_color = Color(0.065, 0.082, 0.118, 0.94)
			sb_idle.border_color = Color(1.0, 1.0, 1.0, 0.09)
			sb_idle.set_border_width_all(1)
			sb_idle.set_corner_radius_all(12)
			var sb_hover: StyleBoxFlat = sb_idle.duplicate()
			sb_hover.bg_color = Color(0.098, 0.122, 0.172, 0.96)
			sb_hover.border_color = Color(1.0, 1.0, 1.0, 0.16)
			btn.add_theme_stylebox_override("normal", sb_idle)
			btn.add_theme_stylebox_override("hover", sb_hover)
			btn.add_theme_stylebox_override("pressed", sb_idle)
			btn.add_theme_font_override("font", _get_modern_font(500))
			for c_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				btn.add_theme_color_override(c_name, Color(0.78, 0.84, 0.94, 1.0))


func _switch_locker_tab(tab: String) -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	current_locker_tab = tab
	_apply_locker_tab_styles()
	_refresh_locker_ui()


func _preview_locker_item(tab_kind: String, item_id: String) -> void:
	if tab_kind == "outfits":
		_preview_worker_skin_id = item_id
	else:
		_preview_crate_skin_id = item_id
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_refresh_locker_ui()


func _on_equip_worker_skin(skin_id: String) -> void:
	if save_mgr and save_mgr.has_method("equip_worker_skin"):
		var ok: bool = save_mgr.equip_worker_skin(skin_id)
		_preview_worker_skin_id = save_mgr.selected_worker_skin
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
		_preview_crate_skin_id = save_mgr.selected_crate_skin
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
		_preview_dir_timer += delta
		if locker_preview_content != null:
			locker_preview_content.queue_redraw()
	if star_vault_modal != null and star_vault_modal.visible:
		_star_vault_anim_time += delta
		if _vault_emblem_is_skin and _vault_emblem_canvas != null:
			_vault_emblem_canvas.queue_redraw()


func _get_preview_worker_frame(facing_dir: Vector2i, walk_phase: int) -> Texture2D:
	if facing_dir == Vector2i.RIGHT:
		if walk_phase == 0 and tex_player_right_w1:
			return tex_player_right_w1
		if walk_phase == 2 and tex_player_right_w2:
			return tex_player_right_w2
		return tex_player_right if tex_player_right else tex_player_down
	if facing_dir == Vector2i.UP:
		if walk_phase == 0 and tex_player_up_w1:
			return tex_player_up_w1
		if walk_phase == 2 and tex_player_up_w2:
			return tex_player_up_w2
		return tex_player_up if tex_player_up else tex_player_down
	if facing_dir == Vector2i.LEFT:
		if walk_phase == 0 and tex_player_left_w1:
			return tex_player_left_w1
		if walk_phase == 2 and tex_player_left_w2:
			return tex_player_left_w2
		return tex_player_left if tex_player_left else tex_player_down
	if walk_phase == 0 and tex_player_down_w1:
		return tex_player_down_w1
	if walk_phase == 2 and tex_player_down_w2:
		return tex_player_down_w2
	return tex_player_down


func _draw_locker_stage_status_chip(canvas: Control, center_x: float, y_top: float, label_text: String, text_col: Color, bg_col: Color, border_col: Color) -> void:
	var font: Font = _get_modern_font(500)
	if font == null or label_text.is_empty():
		return
	var font_sz: int = 10
	var txt_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz)
	var pill_w: float = txt_size.x + 18.0
	var pill_h: float = 18.0
	var pill_r: Rect2 = Rect2(center_x - pill_w * 0.5, y_top, pill_w, pill_h)
	var sb_pill: StyleBoxFlat = StyleBoxFlat.new()
	sb_pill.bg_color = bg_col
	sb_pill.border_color = border_col
	sb_pill.set_border_width_all(1)
	sb_pill.set_corner_radius_all(9)
	canvas.draw_style_box(sb_pill, pill_r)
	canvas.draw_string(
		font,
		Vector2(pill_r.position.x, y_top + 12.5),
		label_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		pill_w,
		font_sz,
		text_col
	)


func _on_preview_content_draw() -> void:
	if locker_preview_content == null:
		return

	var size: Vector2 = locker_preview_content.size
	if size.x <= 10.0 or size.y <= 10.0:
		return

	var center_x: float = size.x * 0.5
	var base_y: float = 82.0

	var eq_worker_id: String = save_mgr.selected_worker_skin if save_mgr else "classic"
	var eq_crate_id: String = save_mgr.selected_crate_skin if save_mgr else "classic_wood"
	var worker_id: String = _preview_worker_skin_id if not _preview_worker_skin_id.is_empty() else eq_worker_id
	var crate_id: String = _preview_crate_skin_id if not _preview_crate_skin_id.is_empty() else eq_crate_id

	var worker_info: Dictionary = save_mgr.get_worker_skin_info(worker_id) if (save_mgr and save_mgr.has_method("get_worker_skin_info")) else {}
	var crate_info: Dictionary = save_mgr.get_crate_skin_info(crate_id) if (save_mgr and save_mgr.has_method("get_crate_skin_info")) else {}

	# 1. Soft Ambient Spotlight Washes & Industrial Platform Bay
	var w_accent: Color = worker_info.get("accent_color", Color(0.95, 0.78, 0.35))
	var c_accent: Color = crate_info.get("tint", Color(0.38, 0.72, 0.96))
	var worker_pos: Vector2 = Vector2(center_x - 46.0, base_y)
	var crate_pos: Vector2 = Vector2(center_x + 46.0, base_y)

	locker_preview_content.draw_circle(worker_pos + Vector2(0, -20), 34.0, Color(w_accent.r, w_accent.g, w_accent.b, 0.055))
	locker_preview_content.draw_circle(worker_pos + Vector2(0, -20), 22.0, Color(w_accent.r, w_accent.g, w_accent.b, 0.075))
	locker_preview_content.draw_circle(crate_pos + Vector2(0, -20), 34.0, Color(c_accent.r, c_accent.g, c_accent.b, 0.055))
	locker_preview_content.draw_circle(crate_pos + Vector2(0, -20), 22.0, Color(c_accent.r, c_accent.g, c_accent.b, 0.075))

	var plat_w: float = minf(size.x - 32.0, 304.0)
	var plat_h: float = 22.0
	var plat_rect: Rect2 = Rect2(center_x - plat_w * 0.5, base_y - 7.0, plat_w, plat_h)
	var sb_plat: StyleBoxFlat = StyleBoxFlat.new()
	sb_plat.bg_color = Color(0.085, 0.110, 0.160, 0.96)
	sb_plat.border_color = Color(1.0, 1.0, 1.0, 0.10)
	sb_plat.set_border_width_all(1)
	sb_plat.set_corner_radius_all(6)
	locker_preview_content.draw_style_box(sb_plat, plat_rect)
	locker_preview_content.draw_line(
		plat_rect.position + Vector2(6.0, 1.0),
		plat_rect.position + Vector2(plat_rect.size.x - 6.0, 1.0),
		Color(0.95, 0.78, 0.35, 0.45),
		1.0
	)
	locker_preview_content.draw_line(
		Vector2(center_x, plat_rect.position.y + 3.0),
		Vector2(center_x, plat_rect.end.y - 3.0),
		Color(1.0, 1.0, 1.0, 0.07),
		1.0
	)

	# 2. Freight Crate on Illuminated Bay Dock Plate (Right Bay, flush inside pedestal)
	var bay_col: Color = crate_info.get("tint", Color(0.95, 0.78, 0.35))
	var bay_plate: Rect2 = Rect2(crate_pos.x - 22.0, base_y + 1.0, 44.0, 7.0)
	var sb_bay: StyleBoxFlat = StyleBoxFlat.new()
	sb_bay.bg_color = Color(bay_col.r * 0.28, bay_col.g * 0.28, bay_col.b * 0.32, 0.92)
	sb_bay.border_color = Color(bay_col.r, bay_col.g, bay_col.b, 0.48)
	sb_bay.set_border_width_all(1)
	sb_bay.set_corner_radius_all(3)
	locker_preview_content.draw_style_box(sb_bay, bay_plate)
	locker_preview_content.draw_circle(crate_pos + Vector2(0, 3), 12.0, Color(0.0, 0.0, 0.0, 0.36))

	var crate_draw_r: Rect2 = Rect2(crate_pos - Vector2(21.0, 38.0), Vector2(42.0, 42.0))
	if tex_crate:
		var crate_skinned: Texture2D = CosmeticRendererScript.get_crate_texture(crate_id, tex_crate)
		locker_preview_content.draw_texture_rect(crate_skinned, crate_draw_r, false, Color.WHITE)
	CosmeticRendererScript.draw_crate_accessories(locker_preview_content, crate_draw_r, crate_id, false)

	# 3. 4-Direction Animated Worker Showcase (Left Bay)
	var dir_cycle: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
	var dir_idx: int = int(_preview_dir_timer / 1.35) % 4
	var facing_dir: Vector2i = dir_cycle[dir_idx]
	var walk_phase: int = int(_preview_anim_time * 4.2) % 4
	var bob_y: float = -1.4 if (walk_phase == 0 or walk_phase == 2) else 0.0
	var base_p_tex: Texture2D = _get_preview_worker_frame(facing_dir, walk_phase)
	var worker_rect: Rect2 = Rect2(worker_pos - Vector2(22.0, 40.0) + Vector2(0.0, bob_y), Vector2(44.0, 44.0))

	locker_preview_content.draw_circle(worker_pos + Vector2(0, 4), 12.0, Color(0.0, 0.0, 0.0, 0.38))
	if base_p_tex:
		var skinned_p_tex: Texture2D = CosmeticRendererScript.get_worker_texture(worker_id, base_p_tex)
		locker_preview_content.draw_texture_rect(skinned_p_tex, worker_rect, false, Color.WHITE)
	CosmeticRendererScript.draw_worker_accessories(locker_preview_content, worker_rect, facing_dir, worker_id, _preview_anim_time)

	# 4. Top Loadout Title Banner
	var w_name: String = loc_mgr.tr_text(worker_info.get("name_key", "")) if (loc_mgr and worker_info.has("name_key")) else worker_info.get("name", "Classic")
	var c_name: String = loc_mgr.tr_text(crate_info.get("name_key", "")) if (loc_mgr and crate_info.has("name_key")) else crate_info.get("name", "Pine")
	var banner_text: String = "%s  ·  %s" % [w_name.to_upper(), c_name.to_upper()]
	var title_font: Font = _get_modern_font(600)
	if title_font:
		locker_preview_content.draw_string(
			title_font,
			Vector2(0.0, 18.0),
			banner_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			11,
			Color(0.96, 0.80, 0.38, 0.96)
		)

	# 5. Bottom Try-On Status Chip
	var total_stars: int = save_mgr.get_total_stars() if save_mgr else 0
	var focused_info: Dictionary = worker_info if current_locker_tab == "outfits" else crate_info
	var focused_req: int = int(focused_info.get("required_stars", 0))
	var w_req: int = int(worker_info.get("required_stars", 0))
	var c_req: int = int(crate_info.get("required_stars", 0))
	var chip_text: String = ""
	var chip_txt_col: Color = Color(0.72, 0.90, 0.78, 0.95)
	var chip_bg_col: Color = Color(0.075, 0.145, 0.115, 0.92)
	var chip_bd_col: Color = Color(0.35, 0.82, 0.52, 0.35)

	if total_stars < focused_req or total_stars < w_req or total_stars < c_req:
		var locked_req: int = focused_req if total_stars < focused_req else (w_req if total_stars < w_req else c_req)
		chip_text = loc_mgr.tr_text("LOCKER_TRYON_LOCKED", [locked_req]) if loc_mgr else ("Preview · Unlocks at %d ★" % locked_req)
		chip_txt_col = Color(0.98, 0.80, 0.38, 0.98)
		chip_bg_col = Color(0.145, 0.105, 0.055, 0.92)
		chip_bd_col = Color(0.95, 0.74, 0.30, 0.40)
	elif worker_id != eq_worker_id or crate_id != eq_crate_id:
		chip_text = loc_mgr.tr_text("LOCKER_TRYON_UNLOCKED") if loc_mgr else "Preview · Unlocked"
		chip_txt_col = Color(0.72, 0.88, 1.0, 0.96)
		chip_bg_col = Color(0.075, 0.115, 0.180, 0.92)
		chip_bd_col = Color(0.42, 0.72, 0.98, 0.38)
	else:
		chip_text = loc_mgr.tr_text("LOCKER_ACTIVE_LOADOUT") if loc_mgr else "Active Loadout"

	_draw_locker_stage_status_chip(locker_preview_content, center_x, 104.0, chip_text, chip_txt_col, chip_bg_col, chip_bd_col)


func _refresh_locker_ui() -> void:
	if locker_modal == null or save_mgr == null:
		return

	if _preview_worker_skin_id.is_empty():
		_preview_worker_skin_id = save_mgr.selected_worker_skin
	if _preview_crate_skin_id.is_empty():
		_preview_crate_skin_id = save_mgr.selected_crate_skin

	var preview_frame: PanelContainer = locker_modal.find_child("PreviewFrame", true, false) as PanelContainer
	if preview_frame:
		preview_frame.clip_contents = true
		var sb_stage: StyleBoxFlat = StyleBoxFlat.new()
		sb_stage.bg_color = Color(0.048, 0.060, 0.088, 0.98)
		sb_stage.border_color = Color(1.0, 1.0, 1.0, 0.09)
		sb_stage.set_border_width_all(1)
		sb_stage.set_corner_radius_all(16)
		preview_frame.add_theme_stylebox_override("panel", sb_stage)

	if locker_preview_content:
		locker_preview_content.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		locker_preview_content.queue_redraw()

	var total_stars: int = save_mgr.get_total_stars()
	if locker_title_label:
		locker_title_label.text = loc_mgr.tr_text("LOCKER_TITLE") if loc_mgr else "SUPPLY DEPOT"
		locker_title_label.add_theme_font_override("font", _get_modern_font(600))
		locker_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if locker_stars_badge:
		locker_stars_badge.text = loc_mgr.tr_text("LOCKER_STARS_BADGE", [total_stars]) if loc_mgr else ("%d / 225 Stars Collected" % total_stars)
		locker_stars_badge.add_theme_font_override("font", _get_modern_font(500))
		locker_stars_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

	if outfits_tab_btn:
		outfits_tab_btn.text = loc_mgr.tr_text("LOCKER_TAB_OUTFITS") if loc_mgr else "OUTFITS"
	if crates_tab_btn:
		crates_tab_btn.text = loc_mgr.tr_text("LOCKER_TAB_CRATES") if loc_mgr else "CRATES"
	_apply_locker_tab_styles()
	if close_locker_btn:
		close_locker_btn.add_theme_font_override("font", _get_modern_font(600))
		close_locker_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		if loc_mgr:
			close_locker_btn.text = loc_mgr.tr_text("BTN_CLOSE")

	if locker_items_vbox == null:
		return

	for child in locker_items_vbox.get_children():
		locker_items_vbox.remove_child(child)
		child.queue_free()

	if current_locker_tab == "outfits":
		var skins: Array[Dictionary] = save_mgr.get_all_worker_skins()
		for skin in skins:
			var s_id: String = skin["id"]
			var card: Control = _create_locker_item_card(
				s_id,
				skin.get("icon", "🧢"),
				loc_mgr.tr_text(skin["name_key"]) if loc_mgr else skin.get("name", ""),
				loc_mgr.tr_text(skin["desc_key"]) if loc_mgr else skin.get("desc", ""),
				skin.get("required_stars", 0),
				total_stars,
				save_mgr.selected_worker_skin == s_id,
				Callable(self, "_on_equip_worker_skin").bind(s_id),
				tex_player_down,
				skin.get("sprite_tint", Color.WHITE),
				"outfits",
				_preview_worker_skin_id == s_id,
				Callable(self, "_preview_locker_item").bind("outfits", s_id)
			)
			locker_items_vbox.add_child(card)
	else:
		var crates: Array[Dictionary] = save_mgr.get_all_crate_skins()
		for crate in crates:
			var c_id: String = crate["id"]
			var card: Control = _create_locker_item_card(
				c_id,
				crate.get("icon", "📦"),
				loc_mgr.tr_text(crate["name_key"]) if loc_mgr else crate.get("name", ""),
				loc_mgr.tr_text(crate["desc_key"]) if loc_mgr else crate.get("desc", ""),
				crate.get("required_stars", 0),
				total_stars,
				save_mgr.selected_crate_skin == c_id,
				Callable(self, "_on_equip_crate_skin").bind(c_id),
				tex_crate,
				crate.get("tint", Color.WHITE),
				"crates",
				_preview_crate_skin_id == c_id,
				Callable(self, "_preview_locker_item").bind("crates", c_id)
			)
			locker_items_vbox.add_child(card)


func _create_locker_item_card(item_id: String, icon: String, item_name: String, desc: String, req_stars: int, total_stars: int, is_equipped: bool, equip_callable: Callable, preview_texture: Texture2D = null, _preview_tint: Color = Color.WHITE, item_kind: String = "outfits", is_previewed: bool = false, preview_callable: Callable = Callable()) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 62)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb_row: StyleBoxFlat = StyleBoxFlat.new()
	sb_row.bg_color = Color(0.070, 0.088, 0.125, 0.96) if (is_equipped or is_previewed) else Color(0.055, 0.068, 0.095, 0.94)
	if is_equipped:
		sb_row.border_color = Color(0.95, 0.78, 0.35, 0.55)
	elif is_previewed:
		sb_row.border_color = Color(1.0, 1.0, 1.0, 0.30)
	else:
		sb_row.border_color = Color(1.0, 1.0, 1.0, 0.08)
	sb_row.set_border_width_all(1)
	sb_row.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", sb_row)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	if preview_texture != null:
		var preview_frame: PanelContainer = PanelContainer.new()
		preview_frame.custom_minimum_size = Vector2(48, 48)
		preview_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		preview_frame.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb_pv: StyleBoxFlat = StyleBoxFlat.new()
		sb_pv.bg_color = Color(0.065, 0.082, 0.120, 0.98)
		sb_pv.border_color = Color(0.95, 0.78, 0.35, 0.45) if is_equipped else (Color(1.0, 1.0, 1.0, 0.24) if is_previewed else Color(1.0, 1.0, 1.0, 0.09))
		sb_pv.set_border_width_all(1)
		sb_pv.set_corner_radius_all(11)
		preview_frame.add_theme_stylebox_override("panel", sb_pv)

		var thumb: Control = Control.new()
		thumb.custom_minimum_size = Vector2(42, 42)
		thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.draw.connect(func():
			var sz: Vector2 = thumb.size
			var pad: float = 4.0
			var draw_r: Rect2 = Rect2(Vector2(pad, pad), sz - Vector2(pad * 2.0, pad * 2.0))
			if item_kind == "outfits":
				var skinned_tex: Texture2D = CosmeticRendererScript.get_worker_texture(item_id, preview_texture)
				if skinned_tex:
					thumb.draw_texture_rect(skinned_tex, draw_r, false, Color.WHITE)
				CosmeticRendererScript.draw_worker_accessories(thumb, draw_r, Vector2i.DOWN, item_id, 0.0)
			else:
				var skinned_tex: Texture2D = CosmeticRendererScript.get_crate_texture(item_id, preview_texture)
				if skinned_tex:
					thumb.draw_texture_rect(skinned_tex, draw_r, false, Color.WHITE)
				CosmeticRendererScript.draw_crate_accessories(thumb, draw_r, item_id, false)
		)
		preview_frame.add_child(thumb)
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
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var is_unlocked: bool = (total_stars >= req_stars)
	var name_lbl: Label = Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	name_lbl.text = item_name
	name_lbl.add_theme_font_override("font", _get_modern_font(600))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.80, 0.36) if is_equipped else (Color(0.95, 0.97, 1.0) if is_unlocked else Color(0.84, 0.88, 0.94)))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	info_vbox.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	desc_lbl.text = desc
	desc_lbl.add_theme_font_override("font", _get_modern_font(400))
	desc_lbl.add_theme_color_override("font_color", Color(0.64, 0.70, 0.80) if is_unlocked else Color(0.56, 0.62, 0.72))
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_constant_override("line_spacing", -4)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var act_btn: Button = Button.new()
	act_btn.custom_minimum_size = Vector2(104, 36)
	act_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act_btn.clip_contents = true

	var btn_center: HBoxContainer = HBoxContainer.new()
	btn_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_center.add_theme_constant_override("separation", 5)
	btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_btn.add_child(btn_center)

	var btn_lbl: Label = Label.new()
	btn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_lbl.add_theme_font_override("font", _get_modern_font(600))
	btn_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

	if is_equipped:
		var sb_eq: StyleBoxFlat = StyleBoxFlat.new()
		sb_eq.bg_color = Color(0.11, 0.46, 0.25, 1.0)
		sb_eq.border_color = Color(0.42, 0.88, 0.58, 0.45)
		sb_eq.set_border_width_all(1)
		sb_eq.set_corner_radius_all(10)
		act_btn.add_theme_stylebox_override("normal", sb_eq)
		act_btn.add_theme_stylebox_override("hover", sb_eq)
		act_btn.add_theme_stylebox_override("pressed", sb_eq)
		act_btn.add_theme_stylebox_override("disabled", sb_eq)

		var btn_icon: TextureRect = TextureRect.new()
		btn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		btn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_icon.custom_minimum_size = Vector2(14, 14)
		btn_icon.texture = icon_check
		btn_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		btn_center.add_child(btn_icon)

		btn_lbl.text = loc_mgr.tr_text("LOCKER_EQUIPPED") if loc_mgr else "EQUIPPED"
		btn_lbl.add_theme_font_size_override("font_size", 11)
		btn_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		btn_center.add_child(btn_lbl)
		act_btn.tooltip_text = ""
		act_btn.mouse_filter = Control.MOUSE_FILTER_PASS

	elif is_unlocked:
		act_btn.theme_type_variation = &"PrimaryButton"
		btn_lbl.text = loc_mgr.tr_text("LOCKER_EQUIP") if loc_mgr else "EQUIP"
		btn_lbl.add_theme_font_size_override("font_size", 13)
		btn_lbl.add_theme_color_override("font_color", Color(0.067, 0.078, 0.110, 1.0))
		btn_center.add_child(btn_lbl)

		act_btn.mouse_entered.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(0.04, 0.05, 0.08, 1.0)))
		act_btn.mouse_exited.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(0.067, 0.078, 0.110, 1.0)))
		act_btn.button_down.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(0.067, 0.078, 0.110, 1.0)))
		act_btn.button_up.connect(func(): btn_lbl.add_theme_color_override("font_color", Color(0.067, 0.078, 0.110, 1.0)))

		act_btn.tooltip_text = ""
		act_btn.pressed.connect(func():
			if _is_any_scroll_dragging():
				return
			equip_callable.call()
		)
		_attach_spring_physics(act_btn)

	else:
		var sb_lock: StyleBoxFlat = StyleBoxFlat.new()
		sb_lock.bg_color = Color(0.085, 0.105, 0.145, 0.94)
		sb_lock.border_color = Color(0.95, 0.78, 0.35, 0.36) if is_previewed else Color(1.0, 1.0, 1.0, 0.11)
		sb_lock.set_border_width_all(1)
		sb_lock.set_corner_radius_all(10)
		act_btn.add_theme_stylebox_override("normal", sb_lock)
		act_btn.add_theme_stylebox_override("hover", sb_lock)
		act_btn.add_theme_stylebox_override("pressed", sb_lock)
		act_btn.add_theme_stylebox_override("disabled", sb_lock)

		var btn_icon: TextureRect = TextureRect.new()
		btn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		btn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_icon.custom_minimum_size = Vector2(14, 14)
		btn_icon.texture = icon_lock
		btn_icon.modulate = Color(0.96, 0.78, 0.36, 0.96)
		btn_center.add_child(btn_icon)

		btn_lbl.text = "%d ★" % req_stars if req_stars > 0 else (loc_mgr.tr_text("LOCKER_LOCKED") if loc_mgr else "LOCKED")
		btn_lbl.add_theme_font_size_override("font_size", 12)
		btn_lbl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72, 1.0))
		btn_center.add_child(btn_lbl)
		act_btn.tooltip_text = ""

		act_btn.pressed.connect(func():
			if _is_any_scroll_dragging():
				return
			if preview_callable.is_valid():
				preview_callable.call()
			else:
				if audio_mgr:
					audio_mgr.play_click()
				if haptic_mgr:
					haptic_mgr.vibrate_click()
		)
		_attach_spring_physics(act_btn)

	if preview_callable.is_valid():
		panel.gui_input.connect(func(event: InputEvent):
			if _is_any_scroll_dragging():
				return
			var tapped: bool = (
				(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or
				(event is InputEventScreenTouch and not event.pressed)
			)
			if tapped:
				preview_callable.call()
		)

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


func _make_fixed_icon(tex: Texture2D, target_px: int) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var copy_img: Image = img.duplicate()
	copy_img.resize(target_px, target_px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(copy_img)


func _style_star_progress_pill() -> void:
	if star_progress_btn == null:
		return
	star_progress_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	star_progress_btn.clip_text = false
	star_progress_btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	star_progress_btn.custom_minimum_size = Vector2(0, 42)
	star_progress_btn.icon = _make_fixed_icon(icon_star_full, 18)
	star_progress_btn.expand_icon = false
	star_progress_btn.add_theme_constant_override("h_separation", 8)

	var pill_norm: StyleBoxFlat = StyleBoxFlat.new()
	pill_norm.bg_color = Color(0.065, 0.095, 0.155, 0.90)
	pill_norm.border_color = Color(0.96, 0.78, 0.30, 0.45)
	pill_norm.border_width_left = 1
	pill_norm.border_width_top = 1
	pill_norm.border_width_right = 1
	pill_norm.border_width_bottom = 2
	pill_norm.set_corner_radius_all(21)
	pill_norm.content_margin_left = 12.0
	pill_norm.content_margin_right = 16.0
	pill_norm.content_margin_top = 6.0
	pill_norm.content_margin_bottom = 7.0
	pill_norm.shadow_color = Color(0, 0, 0, 0.40)
	pill_norm.shadow_size = 8
	pill_norm.shadow_offset = Vector2(0, 3)

	var pill_hov: StyleBoxFlat = pill_norm.duplicate()
	pill_hov.bg_color = Color(0.11, 0.15, 0.24, 0.96)
	pill_hov.border_color = Color(0.95, 0.78, 0.36, 0.78)
	pill_hov.shadow_color = Color(0, 0, 0, 0.38)
	pill_hov.shadow_size = 5

	var pill_prs: StyleBoxFlat = pill_norm.duplicate()
	pill_prs.bg_color = Color(0.05, 0.07, 0.12, 0.98)
	pill_prs.border_width_bottom = 1

	star_progress_btn.add_theme_stylebox_override("normal", pill_norm)
	star_progress_btn.add_theme_stylebox_override("hover", pill_hov)
	star_progress_btn.add_theme_stylebox_override("pressed", pill_prs)


func _style_back_pill_button() -> void:
	if back_btn == null:
		return
	back_btn.icon = _make_fixed_icon(icon_back, 15)
	back_btn.expand_icon = false
	back_btn.add_theme_constant_override("h_separation", 6)
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(84, 38)

	var b_norm: StyleBoxFlat = StyleBoxFlat.new()
	b_norm.bg_color = Color(0.08, 0.11, 0.175, 0.90)
	b_norm.border_color = Color(0.32, 0.44, 0.62, 0.48)
	b_norm.border_width_left = 1
	b_norm.border_width_top = 1
	b_norm.border_width_right = 1
	b_norm.border_width_bottom = 2
	b_norm.set_corner_radius_all(19)
	b_norm.content_margin_left = 12.0
	b_norm.content_margin_right = 14.0
	b_norm.content_margin_top = 5.0
	b_norm.content_margin_bottom = 6.0

	var b_hov: StyleBoxFlat = b_norm.duplicate()
	b_hov.bg_color = Color(0.14, 0.19, 0.29, 0.96)
	b_hov.border_color = Color(0.96, 0.80, 0.32, 0.88)

	var b_prs: StyleBoxFlat = b_norm.duplicate()
	b_prs.bg_color = Color(0.06, 0.085, 0.14, 0.96)
	b_prs.border_width_bottom = 1

	back_btn.add_theme_stylebox_override("normal", b_norm)
	back_btn.add_theme_stylebox_override("hover", b_hov)
	back_btn.add_theme_stylebox_override("pressed", b_prs)


func _setup_center_box_button(btn: Button, icon_rect: TextureRect, tex: Texture2D, lbl: Label) -> void:
	if btn == null:
		return
	btn.icon = null
	btn.text = ""
	btn.tooltip_text = ""
	if icon_rect != null:
		icon_rect.texture = tex
	if lbl != null and not btn.has_meta("_center_box_feedback"):
		btn.set_meta("_center_box_feedback", true)
		btn.mouse_entered.connect(func(): lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1)))
		btn.mouse_exited.connect(func(): lbl.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98, 1)))
		btn.button_down.connect(func(): lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25, 1)))
		btn.button_up.connect(func(): lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1) if btn.is_hovered() else Color(0.94, 0.96, 0.98, 1)))


func _apply_button_icon(btn: Button, tex: Texture2D, max_w: int = 20, h_sep: int = 8) -> void:
	if btn == null:
		return
	btn.icon = tex
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", max_w)
	btn.add_theme_constant_override("h_separation", h_sep)


func _apply_compact_button_padding(btn: Button, horiz_pad: int = 10) -> void:
	if btn == null or btn.has_meta("_compact_pad_applied"):
		return
	btn.set_meta("_compact_pad_applied", true)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBox = btn.get_theme_stylebox(state_name, "Button")
		if sb != null:
			var dup_sb: StyleBox = sb.duplicate()
			dup_sb.content_margin_left = float(horiz_pad)
			dup_sb.content_margin_right = float(horiz_pad)
			btn.add_theme_stylebox_override(state_name, dup_sb)


func _get_achievement_icon(ach_id: String) -> Texture2D:
	match ach_id:
		"first_shift": return icon_play
		"cargo_master": return icon_sector_1
		"cold_storage": return icon_sector_2
		"cyber_master": return icon_sector_3
		"quantum_master": return icon_sector_4
		"depot_cleared": return icon_trophy
		"precision_starter": return icon_star_full
		"precision_master": return icon_star_full
		"puzzle_perfectionist": return icon_crown
		"stylin_porter": return icon_locker
		"heavy_lifter": return icon_flame
		_: return icon_trophy


func _create_achievement_item_card(ach_id: String, _icon: String, title: String, desc: String, is_unlocked: bool) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb_ach := StyleBoxFlat.new()
	sb_ach.bg_color = Color(0.055, 0.068, 0.095, 0.94)
	sb_ach.border_color = Color(0.94, 0.76, 0.36, 0.45) if is_unlocked else Color(1.0, 1.0, 1.0, 0.075)
	sb_ach.set_border_width_all(1)
	sb_ach.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", sb_ach)

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
	icon_rect.custom_minimum_size = Vector2(30, 30)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _get_achievement_icon(ach_id)
	icon_rect.modulate = Color.WHITE if is_unlocked else Color(0.55, 0.62, 0.72, 0.72)
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
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36) if is_unlocked else Color(0.76, 0.81, 0.89))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	info_vbox.add_child(title_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.84, 0.88, 0.95) if is_unlocked else Color(0.54, 0.60, 0.70))
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
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
		_apply_button_icon(music_toggle_btn, icon_music_on if m_on else icon_music_off, 18, 8)
		if loc_mgr:
			var m_status: String = loc_mgr.tr_text("MENU_SOUND_ON" if m_on else "MENU_SOUND_OFF")
			music_toggle_btn.text = loc_mgr.tr_text("SETTINGS_MUSIC_TOGGLE", [m_status])
		else:
			var status_text: String = "ON" if m_on else "OFF"
			music_toggle_btn.text = "MUSIC: " + status_text

	if tap_walk_btn:
		_apply_button_icon(tap_walk_btn, icon_control_swipe, 18, 8)
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
		_apply_button_icon(track_cycle_btn, icon_music_on, 18, 8)
		var track_name: String = "Warehouse Chill" if track_idx == 0 else "Industrial Pulse"
		if loc_mgr:
			var key: String = "TRACK_LOFI" if track_idx == 0 else "TRACK_INDUSTRIAL"
			track_name = loc_mgr.tr_text(key)
		track_cycle_btn.text = track_name

	if control_mode_btn:
		var scheme_id: int = save_mgr.control_scheme if (save_mgr and "control_scheme" in save_mgr) else 0
		var ctrl_tex: Texture2D = icon_control_swipe
		if scheme_id == 1:
			ctrl_tex = icon_control_dpad
		elif scheme_id == 2:
			ctrl_tex = icon_control_gamepad
		_apply_button_icon(control_mode_btn, ctrl_tex, 20, 8)
		var mode_name: String = save_mgr.get_control_scheme_name() if save_mgr and save_mgr.has_method("get_control_scheme_name") else "SWIPE"
		var mode_key: String = "CONTROL_" + mode_name.replace("-", "")
		var mode_text: String = loc_mgr.tr_text(mode_key) if loc_mgr else mode_name
		control_mode_btn.text = loc_mgr.tr_text("SETTINGS_CONTROLS", [mode_text]) if loc_mgr else "CONTROLS: %s" % mode_name

	_apply_settings_icons()

	if close_settings_btn and loc_mgr:
		close_settings_btn.text = loc_mgr.tr_text("SETTINGS_CLOSE")


func _apply_settings_icons() -> void:
	var m_on: bool = save_mgr.music_enabled if (save_mgr and "music_enabled" in save_mgr) else true
	var scheme_id: int = save_mgr.control_scheme if (save_mgr and "control_scheme" in save_mgr) else 0
	var ctrl_tex: Texture2D = icon_control_swipe
	if scheme_id == 1:
		ctrl_tex = icon_control_dpad
	elif scheme_id == 2:
		ctrl_tex = icon_control_gamepad
	if music_toggle_btn:
		music_toggle_btn.custom_minimum_size.x = maxf(music_toggle_btn.custom_minimum_size.x, 148.0)
		_apply_compact_button_padding(music_toggle_btn, 10)
	_apply_button_icon(music_toggle_btn, icon_music_on if m_on else icon_music_off, 18, 6)
	_apply_button_icon(track_cycle_btn, icon_music_on, 18, 8)
	_apply_button_icon(control_mode_btn, ctrl_tex, 20, 8)
	_apply_button_icon(tap_walk_btn, icon_control_swipe, 18, 8)
	if sound_btn:
		sound_btn.custom_minimum_size.x = maxf(sound_btn.custom_minimum_size.x, 148.0)
		_apply_compact_button_padding(sound_btn, 10)
	_apply_button_icon(sound_btn, icon_sfx, 18, 6)
	_apply_button_icon(haptics_btn, icon_haptics, 18, 8)
	_apply_button_icon(language_btn, icon_globe, 18, 8)
	_apply_button_icon(credits_btn, icon_info, 18, 8)


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
			if level_select_btn_label != null:
				level_select_btn.text = ""
				level_select_btn_label.text = loc_mgr.tr_text("MENU_LEVEL_SELECT")
			else:
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
		if level_select_btn:
			if level_select_btn_label != null:
				level_select_btn.text = ""
				level_select_btn_label.text = "LEVEL SELECT"
			else:
				level_select_btn.text = "LEVEL SELECT"
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
				star_progress_btn.text = loc_mgr.tr_text("STAR_PROGRESS_PILL_CROWN", [total_stars, total_crowns, ch_title])
			else:
				star_progress_btn.text = loc_mgr.tr_text("STAR_PROGRESS_PILL", [total_stars, ch_title])
		else:
			var crown_str: String = " • %d 👑" % total_crowns if total_crowns > 0 else ""
			star_progress_btn.text = "%d/225%s  •  %s" % [total_stars, crown_str, ch_title]
	if quick_lang_btn:
		var lang_code: String = loc_mgr.current_language.to_upper() if loc_mgr else "EN"
		quick_lang_btn.text = lang_code

	_apply_settings_icons()

	# Breakout Retention Engine: Daily Shift Hero Card
	if daily_shift_btn == null:
		var deck: VBoxContainer = find_child("ActionDeck", true, false) as VBoxContainer
		if deck != null:
			daily_shift_btn = Button.new()
			daily_shift_btn.name = "DailyShiftBtn"
			daily_shift_btn.custom_minimum_size = Vector2(0, 48)
			daily_shift_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			daily_shift_btn.add_theme_font_override("font", _get_modern_font(500))
			daily_shift_btn.add_theme_font_size_override("font_size", 14)
			var sb_ds := StyleBoxFlat.new()
			sb_ds.bg_color = Color(0.085, 0.112, 0.132, 0.96)
			sb_ds.border_color = Color(0.34, 0.78, 0.56, 0.38)
			sb_ds.set_border_width_all(1)
			sb_ds.set_corner_radius_all(14)
			sb_ds.content_margin_left = 16.0
			sb_ds.content_margin_right = 16.0
			sb_ds.content_margin_top = 8.0
			sb_ds.content_margin_bottom = 8.0
			daily_shift_btn.add_theme_stylebox_override("normal", sb_ds)
			var sb_ds_hov := sb_ds.duplicate() as StyleBoxFlat
			sb_ds_hov.bg_color = Color(0.115, 0.150, 0.175, 0.98)
			sb_ds_hov.border_color = Color(0.42, 0.86, 0.64, 0.65)
			daily_shift_btn.add_theme_stylebox_override("hover", sb_ds_hov)
			daily_shift_btn.add_theme_stylebox_override("pressed", sb_ds)
			daily_shift_btn.add_theme_color_override("font_color", Color(0.88, 0.96, 0.91))
			daily_shift_btn.add_theme_color_override("font_hover_color", Color(0.95, 0.99, 0.96))
			daily_shift_btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
			_apply_button_icon(daily_shift_btn, icon_calendar, 22, 8)
			daily_shift_btn.pressed.connect(_on_daily_shift_pressed)
			_attach_spring_physics(daily_shift_btn)
			var dual_deck: Control = deck.find_child("DualDeck", false, false) as Control
			if dual_deck != null:
				deck.add_child(daily_shift_btn)
				deck.move_child(daily_shift_btn, dual_deck.get_index())
			else:
				deck.add_child(daily_shift_btn)

	if daily_shift_btn != null and save_mgr != null and save_mgr.has_method("get_daily_challenge_info"):
		var d_info: Dictionary = save_mgr.get_daily_challenge_info()
		var streak_count: int = d_info.get("streak", 0)
		var is_done: bool = d_info.get("is_completed", false)
		var ds_icon: Texture2D = icon_calendar
		daily_shift_btn.modulate = Color.WHITE
		if is_done:
			ds_icon = icon_check
			daily_shift_btn.text = loc_mgr.tr_text("DAILY_SHIFT_CLEARED", [streak_count]) if loc_mgr else ("DAILY SHIFT: CLEARED ✓ (STREAK: %d)" % streak_count)
			daily_shift_btn.add_theme_color_override("font_color", Color(0.62, 0.92, 0.72))
		else:
			if streak_count > 0:
				ds_icon = icon_flame
				daily_shift_btn.text = loc_mgr.tr_text("DAILY_SHIFT_STREAK", [streak_count]) if loc_mgr else ("DAILY SHIFT • %d STREAK (+3 HINTS)" % streak_count)
			else:
				daily_shift_btn.text = loc_mgr.tr_text("DAILY_SHIFT_PLAY") if loc_mgr else "DAILY SHIFT • PLAY (+3 HINTS)"
			daily_shift_btn.add_theme_color_override("font_color", Color(0.88, 0.96, 0.91))
		_apply_button_icon(daily_shift_btn, ds_icon, 22, 8)

	# Persistent Clickable Pill when an unlocked Star Vault is waiting to be claimed (e.g. after tapping Later)
	var unclaimed_main: Array[Dictionary] = save_mgr.get_unclaimed_star_vaults() if (save_mgr != null and save_mgr.has_method("get_unclaimed_star_vaults")) else []
	if not unclaimed_main.is_empty():
		if vault_ready_btn == null:
			var deck_v: VBoxContainer = find_child("ActionDeck", true, false) as VBoxContainer
			if deck_v != null:
				vault_ready_btn = Button.new()
				vault_ready_btn.name = "VaultReadyBtn"
				vault_ready_btn.custom_minimum_size = Vector2(0, 42)
				vault_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vault_ready_btn.add_theme_font_override("font", _get_modern_font(500))
				vault_ready_btn.add_theme_font_size_override("font_size", 13)
				var sb_v := StyleBoxFlat.new()
				sb_v.bg_color = Color(0.095, 0.112, 0.155, 0.96)
				sb_v.border_color = Color(0.92, 0.74, 0.36, 0.38)
				sb_v.set_border_width_all(1)
				sb_v.set_corner_radius_all(14)
				sb_v.content_margin_left = 16.0
				sb_v.content_margin_right = 16.0
				sb_v.content_margin_top = 8.0
				sb_v.content_margin_bottom = 8.0
				vault_ready_btn.add_theme_stylebox_override("normal", sb_v)
				var sb_v_hov := sb_v.duplicate() as StyleBoxFlat
				sb_v_hov.bg_color = Color(0.125, 0.145, 0.198, 0.98)
				sb_v_hov.border_color = Color(0.95, 0.80, 0.44, 0.65)
				vault_ready_btn.add_theme_stylebox_override("hover", sb_v_hov)
				vault_ready_btn.add_theme_stylebox_override("pressed", sb_v)
				vault_ready_btn.add_theme_color_override("font_color", Color(0.94, 0.83, 0.56))
				vault_ready_btn.add_theme_color_override("font_hover_color", Color(0.98, 0.90, 0.68))
				vault_ready_btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
				vault_ready_btn.pressed.connect(_check_star_vault_milestones)
				_attach_spring_physics(vault_ready_btn)
				deck_v.add_child(vault_ready_btn)
				if daily_shift_btn != null and daily_shift_btn.get_parent() == deck_v:
					deck_v.move_child(vault_ready_btn, daily_shift_btn.get_index())
		if vault_ready_btn != null:
			var first_v: Dictionary = unclaimed_main[0].get("vault", {})
			var v_name_m: String = str(first_v.get("name", "Supply Cache"))
			vault_ready_btn.text = loc_mgr.tr_text("VAULT_READY_BANNER", [v_name_m]) if loc_mgr else ("Vault Ready · %s" % v_name_m)
			_apply_button_icon(vault_ready_btn, icon_star_full, 16, 10)
			vault_ready_btn.show()
	elif vault_ready_btn != null:
		vault_ready_btn.hide()


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
		btn.custom_minimum_size = Vector2(58, 66)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 15)
		btn.set_meta("level_index", i)
		btn.pressed.connect(_on_level_button_pressed.bind(i))
		_attach_spring_physics(btn)
		level_grid.add_child(btn)

	_refresh_level_grid_buttons()


func _init_sector_styles() -> void:
	if _sector_styles_completed.size() > 0:
		return

	var sector_bg_colors: Array[Color] = [
		Color(0.11, 0.14, 0.19, 0.94), # S1: Cargo Bay
		Color(0.08, 0.14, 0.22, 0.94), # S2: Cold Storage
		Color(0.14, 0.13, 0.19, 0.94), # S3: Cyber Depot
		Color(0.13, 0.09, 0.22, 0.94)  # S4: Quantum Vault
	]
	var sector_border_colors: Array[Color] = [
		Color(0.90, 0.70, 0.24, 0.95), # Brass / Amber
		Color(0.30, 0.80, 0.96, 0.95), # Cryo Cyan
		Color(0.98, 0.76, 0.20, 0.95), # Laser Gold
		Color(0.78, 0.48, 0.98, 0.95)  # Quantum Violet
	]

	for i in range(4):
		var base_bg: Color = sector_bg_colors[i]
		var border_col: Color = sector_border_colors[i]

		var norm: StyleBoxFlat = StyleBoxFlat.new()
		norm.bg_color = base_bg
		norm.border_color = Color(border_col.r, border_col.g, border_col.b, 0.55)
		norm.border_width_left = 1
		norm.border_width_top = 1
		norm.border_width_right = 1
		norm.border_width_bottom = 2
		norm.set_corner_radius_all(12)
		norm.shadow_color = Color(0, 0, 0, 0.30)
		norm.shadow_size = 3
		norm.shadow_offset = Vector2(0, 2)
		norm.content_margin_left = 4.0
		norm.content_margin_top = 6.0
		norm.content_margin_right = 4.0
		norm.content_margin_bottom = 6.0
		_sector_styles_completed.append(norm)

		var hov: StyleBoxFlat = norm.duplicate()
		hov.bg_color = base_bg.lightened(0.10)
		hov.border_color = border_col
		hov.shadow_color = Color(0, 0, 0, 0.36)
		hov.shadow_size = 4
		_sector_styles_hover.append(hov)

		var prs: StyleBoxFlat = norm.duplicate()
		prs.bg_color = base_bg.darkened(0.14)
		prs.border_width_top = 2
		prs.border_width_bottom = 1
		prs.shadow_size = 1
		_sector_styles_pressed.append(prs)

		var lck: StyleBoxFlat = StyleBoxFlat.new()
		lck.bg_color = Color(0.085, 0.11, 0.165, 0.88).lerp(base_bg, 0.25)
		lck.border_color = Color(border_col.r, border_col.g, border_col.b, 0.26)
		lck.border_width_left = 1
		lck.border_width_top = 1
		lck.border_width_right = 1
		lck.border_width_bottom = 2
		lck.set_corner_radius_all(12)
		lck.content_margin_left = 4.0
		lck.content_margin_top = 8.0
		lck.content_margin_right = 4.0
		lck.content_margin_bottom = 8.0
		_sector_styles_locked.append(lck)

	# Frontier unlocked style
	_frontier_style = StyleBoxFlat.new()
	_frontier_style.bg_color = Color(0.24, 0.17, 0.06, 0.98)
	_frontier_style.border_color = Color(1.0, 0.84, 0.28, 0.90)
	_frontier_style.border_width_left = 1
	_frontier_style.border_width_top = 1
	_frontier_style.border_width_right = 1
	_frontier_style.border_width_bottom = 3
	_frontier_style.set_corner_radius_all(12)
	_frontier_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	_frontier_style.shadow_size = 4
	_frontier_style.shadow_offset = Vector2(0, 2)
	_frontier_style.content_margin_left = 4.0
	_frontier_style.content_margin_top = 6.0
	_frontier_style.content_margin_right = 4.0
	_frontier_style.content_margin_bottom = 6.0

	# Locked fallback style
	_locked_style = _sector_styles_locked[0]


func _setup_sector_tabs() -> void:
	var tab_icons: Array[Texture2D] = [icon_sector_1, icon_sector_2, icon_sector_3, icon_sector_4]
	var tab_colors: Array[Color] = [
		Color(0.90, 0.70, 0.24),
		Color(0.30, 0.80, 0.96),
		Color(0.98, 0.76, 0.20),
		Color(0.78, 0.48, 0.98)
	]

	var vault_card: PanelContainer = find_child("VaultMilestoneCard", true, false) as PanelContainer
	if vault_card != null:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.78, 0.28, 0.08)
		sb.border_color = Color(0.96, 0.78, 0.28, 0.22)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.set_corner_radius_all(10)
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
		tab_norm.bg_color = Color(0.075, 0.10, 0.155, 0.90)
		tab_norm.border_color = Color(col.r, col.g, col.b, 0.45)
		tab_norm.border_width_left = 1
		tab_norm.border_width_top = 1
		tab_norm.border_width_right = 1
		tab_norm.border_width_bottom = 3
		tab_norm.set_corner_radius_all(12)
		tab_norm.shadow_color = Color(0, 0, 0, 0.28)
		tab_norm.shadow_size = 4
		tab_norm.shadow_offset = Vector2(0, 2)
		tab_btn.add_theme_stylebox_override("normal", tab_norm)

		var tab_hov: StyleBoxFlat = tab_norm.duplicate()
		tab_hov.bg_color = Color(0.115, 0.15, 0.23, 0.98)
		tab_hov.border_color = col
		tab_hov.shadow_color = Color(0, 0, 0, 0.36)
		tab_hov.shadow_size = 4
		tab_btn.add_theme_stylebox_override("hover", tab_hov)

		var tab_prs: StyleBoxFlat = tab_norm.duplicate()
		tab_prs.bg_color = Color(0.06, 0.08, 0.125, 1.0)
		tab_prs.border_color = col
		tab_prs.border_width_bottom = 2
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

	var unclaimed_vaults: Array[Dictionary] = save_mgr.get_unclaimed_star_vaults() if (save_mgr != null and save_mgr.has_method("get_unclaimed_star_vaults")) else []
	if vault_card != null and vault_lbl != null:
		if not vault_card.gui_input.is_connected(_on_vault_milestone_card_gui_input):
			vault_card.mouse_filter = Control.MOUSE_FILTER_STOP
			vault_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			vault_card.gui_input.connect(_on_vault_milestone_card_gui_input)
		if not unclaimed_vaults.is_empty():
			var waiting_v: Dictionary = unclaimed_vaults[0].get("vault", {})
			var w_name: String = str(waiting_v.get("name", "Supply Cache"))
			vault_lbl.text = loc_mgr.tr_text("VAULT_READY_BANNER", [w_name]) if loc_mgr else ("VAULT READY: %s  •  TAP TO CLAIM" % w_name)
			vault_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
			if vault_icon_rect != null:
				vault_icon_rect.texture = tex_crate_goal
		elif next_vault_name != "":
			vault_lbl.text = loc_mgr.tr_text("NEXT_VAULT_LABEL", [next_vault_name, next_vault_stars]) if loc_mgr else ("Next Vault: %s · %d★" % [next_vault_name, next_vault_stars])
			vault_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 0.95))
			if vault_icon_rect != null:
				vault_icon_rect.texture = icon_trophy
		else:
			vault_lbl.text = loc_mgr.tr_text("ALL_VAULTS_SECURED") if loc_mgr else "ALL VAULT REWARDS SECURED ✓"
			vault_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.62))
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
			child.add_theme_font_size_override("font_size", 14)
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
			child.add_theme_font_size_override("font_size", 18)
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
				child.add_theme_font_size_override("font_size", 15)
				child.icon = icon_lock
				child.expand_icon = true
				child.add_theme_constant_override("icon_max_width", 14)
				child.add_theme_constant_override("h_separation", 2)
				child.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				child.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
				child.add_theme_color_override("icon_disabled_color", Color(0.84, 0.90, 0.98, 0.45))
				child.add_theme_color_override("font_disabled_color", Color(0.74, 0.80, 0.90, 0.72))
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
			var sec_locked_sb: StyleBoxFlat = _sector_styles_locked[ch_idx] if ch_idx < _sector_styles_locked.size() else _locked_style
			if sec_locked_sb != null:
				child.add_theme_stylebox_override("disabled", sec_locked_sb)
				child.add_theme_stylebox_override("normal", sec_locked_sb)

	if active_frontier_btn != null and active_frontier_btn.is_inside_tree():
		var p_sz: Vector2 = active_frontier_btn.custom_minimum_size if active_frontier_btn.size == Vector2.ZERO else active_frontier_btn.size
		active_frontier_btn.pivot_offset = p_sz / 2.0
		if current_level_pulse_tw and current_level_pulse_tw.is_valid():
			current_level_pulse_tw.kill()
		current_level_pulse_tw = null
		if level_select_view != null and level_select_view.visible and DisplayServer.get_name() != "headless":
			current_level_pulse_tw = active_frontier_btn.create_tween().set_loops()
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
		save_mgr.set_meta("daily_challenge_level", int(d_info["level_index"]))
	_transition_to_game()


func _check_star_vault_milestones() -> void:
	if save_mgr == null or not save_mgr.has_method("get_unclaimed_star_vaults"):
		return
	var unclaimed: Array[Dictionary] = save_mgr.get_unclaimed_star_vaults()
	if unclaimed.is_empty():
		return
	var target: Dictionary = unclaimed[0]
	_show_star_vault_modal(target["index"], target["vault"])


func _on_vault_milestone_card_gui_input(event: InputEvent) -> void:
	var tapped: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or
		(event is InputEventScreenTouch and event.pressed)
	)
	if tapped and save_mgr != null and save_mgr.has_method("get_unclaimed_star_vaults"):
		if not save_mgr.get_unclaimed_star_vaults().is_empty():
			_check_star_vault_milestones()


func _get_vault_accent_color(vault: Dictionary) -> Color:
	var req_stars: int = int(vault.get("stars", 15))
	var s_id: String = str(vault.get("skin_id", ""))
	if s_id == "golden_porter" or req_stars >= 180:
		return Color(0.96, 0.80, 0.36) # Champagne Gold
	if s_id == "hazard_box":
		return Color(0.96, 0.72, 0.22) # Hazard Freight Amber
	if s_id == "safety_vest":
		return Color(0.98, 0.56, 0.18) # Safety High-Vis Orange
	if s_id == "foreman":
		return Color(0.95, 0.76, 0.30) # Foreman Warm Gold
	if req_stars == 40 or s_id == "steel_container":
		return Color(0.60, 0.80, 0.98) # Cold-Rolled Steel Ice
	if req_stars >= 140:
		return Color(0.72, 0.56, 0.96) # Quantum Lavender
	return Color(0.92, 0.72, 0.34) # Satin Amber Bronze


func _get_modern_font(weight: int) -> Font:
	if _ui_fonts.has(weight):
		return _ui_fonts[weight] as Font
	var fv := FontVariation.new()
	fv.base_font = _font_rubik_base
	fv.variation_opentype = { 2003265652: weight } # OpenType 'wght'
	if _font_arabic_fallback:
		fv.fallbacks = [_font_arabic_fallback]
	_ui_fonts[weight] = fv
	return fv


func _draw_vault_skin_pedestal(canvas: Control, c: Vector2, acc: Color, is_crate: bool) -> void:
	var plat_r: Rect2 = Rect2(c.x - 56.0, c.y + 18.0, 112.0, 17.0)
	var sb_plat: StyleBoxFlat = StyleBoxFlat.new()
	sb_plat.bg_color = Color(0.085, 0.110, 0.160, 0.96)
	sb_plat.border_color = Color(1.0, 1.0, 1.0, 0.10)
	sb_plat.set_border_width_all(1)
	sb_plat.set_corner_radius_all(6)
	canvas.draw_style_box(sb_plat, plat_r)
	canvas.draw_line(
		plat_r.position + Vector2(6.0, 1.0),
		plat_r.position + Vector2(plat_r.size.x - 6.0, 1.0),
		Color(acc.r, acc.g, acc.b, 0.62),
		1.0
	)
	if is_crate:
		var bay_r: Rect2 = Rect2(c.x - 24.0, c.y + 20.0, 48.0, 7.0)
		var sb_bay: StyleBoxFlat = StyleBoxFlat.new()
		sb_bay.bg_color = Color(acc.r * 0.28, acc.g * 0.28, acc.b * 0.32, 0.92)
		sb_bay.border_color = Color(acc.r, acc.g, acc.b, 0.50)
		sb_bay.set_border_width_all(1)
		sb_bay.set_corner_radius_all(3)
		canvas.draw_style_box(sb_bay, bay_r)
	canvas.draw_circle(c + Vector2(0.0, 21.0), 15.0 if is_crate else 14.0, Color(0.0, 0.0, 0.0, 0.38))


func _draw_vault_hero_emblem(canvas: Control) -> void:
	if canvas == null:
		return
	var sz: Vector2 = canvas.size
	if sz.x <= 4.0 or sz.y <= 4.0:
		return
	var c: Vector2 = Vector2(sz.x * 0.5, sz.y * 0.52)
	var acc: Color = _vault_emblem_accent
	var kind: String = _vault_emblem_kind

	# Delicate overhead halo arc (subtle architectural accent without any boxed border)
	var arc_r: float = 44.0 if (kind == "worker_skin" or kind == "crate_skin") else 38.0
	canvas.draw_arc(c + Vector2(0.0, -2.0), arc_r, -PI * 0.82, -PI * 0.18, 36, Color(1.0, 1.0, 1.0, 0.11), 1.0, true)

	match kind:
		"worker_skin":
			_draw_vault_skin_pedestal(canvas, c, acc, false)
			var dir_cycle: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
			var dir_idx: int = int(_star_vault_anim_time / 1.55) % 4
			var facing_dir: Vector2i = dir_cycle[dir_idx]
			var walk_phase: int = int(_star_vault_anim_time * 4.0) % 4
			var bob_y: float = -1.4 if (walk_phase == 0 or walk_phase == 2) else 0.0
			var base_p: Texture2D = _get_preview_worker_frame(facing_dir, walk_phase)
			var w_rect: Rect2 = Rect2(c.x - 28.0, c.y - 34.0 + bob_y, 56.0, 56.0)
			if base_p:
				var skinned_w: Texture2D = CosmeticRendererScript.get_worker_texture(_vault_emblem_skin_id, base_p)
				canvas.draw_texture_rect(skinned_w, w_rect, false, Color.WHITE)
			CosmeticRendererScript.draw_worker_accessories(canvas, w_rect, facing_dir, _vault_emblem_skin_id, _star_vault_anim_time)
		"crate_skin":
			_draw_vault_skin_pedestal(canvas, c, acc, true)
			var c_rect: Rect2 = Rect2(c.x - 26.0, c.y - 31.0, 52.0, 52.0)
			if tex_crate:
				var skinned_c: Texture2D = CosmeticRendererScript.get_crate_texture(_vault_emblem_skin_id, tex_crate)
				canvas.draw_texture_rect(skinned_c, c_rect, false, Color.WHITE)
			CosmeticRendererScript.draw_crate_accessories(canvas, c_rect, _vault_emblem_skin_id, false)
		"prism":
			# Floating faceted octahedron artifact for high-tier solver caches
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, 22), c + Vector2(20, 27), c + Vector2(0, 32), c + Vector2(-20, 27)
			]), Color(0.0, 0.0, 0.0, 0.28))
			var p_top := c + Vector2(0, -28)
			var p_bot := c + Vector2(0, 20)
			var p_left := c + Vector2(-21, -4)
			var p_mid := c + Vector2(0, 3)
			var p_right := c + Vector2(21, -4)
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_mid, p_left]), Color(0.96, 0.96, 1.0).lerp(acc, 0.45))
			canvas.draw_colored_polygon(PackedVector2Array([p_top, p_right, p_mid]), acc.lerp(Color(0.24, 0.20, 0.36), 0.30))
			canvas.draw_colored_polygon(PackedVector2Array([p_left, p_mid, p_bot]), acc.darkened(0.18))
			canvas.draw_colored_polygon(PackedVector2Array([p_mid, p_right, p_bot]), Color(0.08, 0.09, 0.14).lerp(acc, 0.25))
			canvas.draw_line(p_top, p_mid, Color(1.0, 1.0, 1.0, 0.60), 1.4, true)
			canvas.draw_line(p_left, p_mid, Color(1.0, 1.0, 1.0, 0.35), 1.2, true)
			canvas.draw_line(p_mid, p_bot, Color(1.0, 1.0, 1.0, 0.32), 1.2, true)
		"trophy":
			# Minimalist faceted architectural apex chalice
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-18, 25), c + Vector2(18, 25), c + Vector2(13, 29), c + Vector2(-13, 29)
			]), Color(0.0, 0.0, 0.0, 0.30))
			var cup_tl := c + Vector2(-18, -16)
			var cup_tr := c + Vector2(18, -16)
			var cup_tm := c + Vector2(0, -16)
			var cup_bl := c + Vector2(-9, 8)
			var cup_br := c + Vector2(9, 8)
			var cup_bm := c + Vector2(0, 11)
			canvas.draw_colored_polygon(PackedVector2Array([cup_tl, cup_tm, cup_bm, cup_bl]), Color(0.99, 0.92, 0.62).lerp(acc, 0.40))
			canvas.draw_colored_polygon(PackedVector2Array([cup_tm, cup_tr, cup_br, cup_bm]), acc.darkened(0.24))
			# Stem + pedestal
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 9), c + Vector2(3, 9), c + Vector2(4, 19), c + Vector2(-4, 19)]), acc.darkened(0.32))
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 19), c + Vector2(13, 19), c + Vector2(15, 25), c + Vector2(-15, 25)]), Color(0.18, 0.21, 0.28))
			canvas.draw_line(cup_tl, cup_tr, Color(1.0, 1.0, 1.0, 0.55), 1.3, true)
			canvas.draw_line(cup_tm, cup_bm, Color(1.0, 1.0, 1.0, 0.35), 1.2, true)
		_:
			# Precision isometric sculptural vault cube (default for supply caches & crate skins)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, 19), c + Vector2(30, 31), c + Vector2(0, 38), c + Vector2(-30, 31)
			]), Color(0.0, 0.0, 0.0, 0.34))
			var pt_top := c + Vector2(0, -26)
			var pt_left := c + Vector2(-26, -12)
			var pt_right := c + Vector2(26, -12)
			var pt_mid := c + Vector2(0, 2)
			var pt_left_bot := c + Vector2(-26, 15)
			var pt_right_bot := c + Vector2(26, 15)
			var pt_bot := c + Vector2(0, 29)
			# Top sunlit matte surface
			canvas.draw_colored_polygon(PackedVector2Array([pt_top, pt_right, pt_mid, pt_left]), Color(0.97, 0.97, 0.99).lerp(acc, 0.44))
			# Left satin face
			canvas.draw_colored_polygon(PackedVector2Array([pt_left, pt_mid, pt_bot, pt_left_bot]), acc.lerp(Color(0.16, 0.19, 0.26), 0.36))
			# Right shadow architectural face
			canvas.draw_colored_polygon(PackedVector2Array([pt_mid, pt_right, pt_right_bot, pt_bot]), Color(0.08, 0.095, 0.14).lerp(acc, 0.22))
			# Top inlaid recessed diamond + luminous core (strictly inset inside top facet)
			var top_c := c + Vector2(0, -12)
			canvas.draw_colored_polygon(PackedVector2Array([
				top_c + Vector2(0, -6.5), top_c + Vector2(12.5, 0), top_c + Vector2(0, 6.5), top_c + Vector2(-12.5, 0)
			]), Color(0.08, 0.10, 0.14, 0.78))
			canvas.draw_colored_polygon(PackedVector2Array([
				top_c + Vector2(0, -3.2), top_c + Vector2(6.0, 0), top_c + Vector2(0, 3.2), top_c + Vector2(-6.0, 0)
			]), acc.lightened(0.45))
			# Minimal vertical front architectural seam + subtle clasp cleanly below top ridge
			canvas.draw_colored_polygon(PackedVector2Array([
				pt_mid + Vector2(-3.0, 4.5), pt_mid + Vector2(0.0, 6.0), pt_mid + Vector2(0.0, 12.5), pt_mid + Vector2(-3.0, 11.0)
			]), Color(0.95, 0.96, 0.98, 0.65))
			canvas.draw_colored_polygon(PackedVector2Array([
				pt_mid + Vector2(0.0, 6.0), pt_mid + Vector2(3.0, 4.5), pt_mid + Vector2(3.0, 11.0), pt_mid + Vector2(0.0, 12.5)
			]), Color(0.55, 0.60, 0.70, 0.60))
			# Subtle anti-aliased specular ridge highlights
			canvas.draw_line(pt_top, pt_left, Color(1.0, 1.0, 1.0, 0.28), 1.0, true)
			canvas.draw_line(pt_left, pt_mid, Color(1.0, 1.0, 1.0, 0.42), 1.0, true)
			canvas.draw_line(pt_mid, pt_right, Color(1.0, 1.0, 1.0, 0.28), 1.0, true)
			canvas.draw_line(pt_mid, pt_bot, Color(1.0, 1.0, 1.0, 0.20), 1.0, true)


func _draw_reward_pill_glyph(canvas: Control) -> void:
	if canvas == null:
		return
	var c: Vector2 = canvas.size * 0.5
	var col: Color = _vault_emblem_accent.lightened(0.32)
	if _vault_emblem_is_skin:
		var t: Vector2 = c + Vector2(0, -5.5)
		var l: Vector2 = c + Vector2(-5.0, -2.4)
		var r: Vector2 = c + Vector2(5.0, -2.4)
		var m: Vector2 = c + Vector2(0, 0.5)
		var lb: Vector2 = c + Vector2(-5.0, 3.1)
		var rb: Vector2 = c + Vector2(5.0, 3.1)
		var b: Vector2 = c + Vector2(0, 5.8)
		canvas.draw_colored_polygon(PackedVector2Array([t, r, m, l]), col.lightened(0.22))
		canvas.draw_colored_polygon(PackedVector2Array([l, m, b, lb]), col)
		canvas.draw_colored_polygon(PackedVector2Array([m, r, rb, b]), col.darkened(0.32))
	else:
		canvas.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -5.5), c + Vector2(5.0, 0), c + Vector2(0, 5.5), c + Vector2(-5.0, 0)
		]), col)


func _show_vault_claimed_toast(v_name: String, accent: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _vault_claim_toast == null:
		_vault_claim_toast = PanelContainer.new()
		_vault_claim_toast.name = "VaultClaimToast"
		_vault_claim_toast.anchors_preset = Control.PRESET_TOP_WIDE
		_vault_claim_toast.anchor_left = 0.5
		_vault_claim_toast.anchor_right = 0.5
		_vault_claim_toast.anchor_top = 0.0
		_vault_claim_toast.anchor_bottom = 0.0
		_vault_claim_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_vault_claim_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vault_claim_toast.z_index = 20

		var mg := MarginContainer.new()
		mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mg.add_theme_constant_override("margin_left", 14)
		mg.add_theme_constant_override("margin_top", 8)
		mg.add_theme_constant_override("margin_right", 14)
		mg.add_theme_constant_override("margin_bottom", 8)
		_vault_claim_toast.add_child(mg)

		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 8)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		mg.add_child(hb)

		var ic := TextureRect.new()
		ic.name = "ToastIcon"
		ic.custom_minimum_size = Vector2(20, 20)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.texture = icon_check
		hb.add_child(ic)

		var lbl := Label.new()
		lbl.name = "ToastLbl"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
		hb.add_child(lbl)
		add_child(_vault_claim_toast)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.11, 0.18, 0.96)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 8
	_vault_claim_toast.add_theme_stylebox_override("panel", sb)

	var toast_lbl: Label = _vault_claim_toast.find_child("ToastLbl", true, false) as Label
	if toast_lbl:
		toast_lbl.text = loc_mgr.tr_text("VAULT_CLAIMED_TOAST", [v_name]) if loc_mgr else ("Claimed: %s!" % v_name)

	var safe_top: float = safe_area_mgr.get_safe_insets(self).get("top", 0.0) if safe_area_mgr else 0.0
	_vault_claim_toast.offset_left = -165.0
	_vault_claim_toast.offset_right = 165.0
	_vault_claim_toast.offset_top = safe_top + 64.0
	_vault_claim_toast.offset_bottom = safe_top + 104.0

	if _vault_toast_tw != null and _vault_toast_tw.is_valid():
		_vault_toast_tw.kill()
	_vault_claim_toast.show()
	_vault_claim_toast.modulate.a = 0.0
	_vault_toast_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_vault_toast_tw.tween_property(_vault_claim_toast, "modulate:a", 1.0, 0.18)
	_vault_toast_tw.tween_interval(2.0)
	_vault_toast_tw.tween_property(_vault_claim_toast, "modulate:a", 0.0, 0.30)
	_vault_toast_tw.tween_callback(func():
		if _vault_claim_toast:
			_vault_claim_toast.hide()
	)


func _show_star_vault_modal(vault_idx: int, vault: Dictionary) -> void:
	if star_vault_modal == null:
		star_vault_modal = _create_star_vault_modal()

	_show_modal_backdrop()

	var accent: Color = _get_vault_accent_color(vault)
	var v_name: String = str(vault.get("name", loc_mgr.tr_text("STAR_VAULT_STASH") if loc_mgr else "Supply Cache"))
	var v_stars: int = int(vault.get("stars", 15))
	var r_type: String = str(vault.get("reward_type", "hints"))
	var r_amount: int = int(vault.get("amount", 5))
	var skin_id_v: String = str(vault.get("skin_id", ""))
	var is_crate_skin: bool = false
	var skin_info: Dictionary = {}
	if r_type != "hints" and not skin_id_v.is_empty() and save_mgr:
		if save_mgr.has_method("get_all_crate_skins"):
			for cs in save_mgr.get_all_crate_skins():
				if cs.get("id", "") == skin_id_v:
					is_crate_skin = true
					skin_info = cs
					break
		if not is_crate_skin and save_mgr.has_method("get_worker_skin_info"):
			var ws: Dictionary = save_mgr.get_worker_skin_info(skin_id_v)
			if ws.get("id", "") == skin_id_v:
				skin_info = ws
	var has_skin_item: bool = (r_type != "hints" and not skin_id_v.is_empty())

	var vault_card: PanelContainer = star_vault_modal.find_child("VaultCard", true, false) as PanelContainer
	var header_banner: PanelContainer = star_vault_modal.find_child("HeaderBanner", true, false) as PanelContainer
	var title_lbl: Label = star_vault_modal.find_child("VaultTitleLabel", true, false) as Label
	var milestone_lbl: Label = star_vault_modal.find_child("MilestoneTagLabel", true, false) as Label
	var medallion: PanelContainer = star_vault_modal.find_child("MedallionFrame", true, false) as PanelContainer
	var spot_rect: TextureRect = star_vault_modal.find_child("HeroSpotlight", true, false) as TextureRect
	var emblem_canvas: Control = star_vault_modal.find_child("VaultEmblemCanvas", true, false) as Control
	var icon_lbl: Label = star_vault_modal.find_child("VaultIconLabel", true, false) as Label
	var icon_rect: TextureRect = star_vault_modal.find_child("VaultIconRect", true, false) as TextureRect
	var name_lbl: Label = star_vault_modal.find_child("VaultNameLabel", true, false) as Label
	var reward_pill: PanelContainer = star_vault_modal.find_child("RewardPill", true, false) as PanelContainer
	var reward_icon: TextureRect = star_vault_modal.find_child("RewardPillIcon", true, false) as TextureRect
	var reward_glyph: Control = star_vault_modal.find_child("RewardGlyphCanvas", true, false) as Control
	var reward_lbl: Label = star_vault_modal.find_child("RewardPillLabel", true, false) as Label
	var desc_lbl: Label = star_vault_modal.find_child("VaultDescLabel", true, false) as Label
	var prog_curr_lbl: Label = star_vault_modal.find_child("ProgressCurrentLbl", true, false) as Label
	var prog_next_lbl: Label = star_vault_modal.find_child("ProgressNextLbl", true, false) as Label
	var prog_bar: ProgressBar = star_vault_modal.find_child("VaultProgressBar", true, false) as ProgressBar
	var claim_btn: Button = star_vault_modal.find_child("ClaimVaultBtn", true, false) as Button
	var close_v_btn: Button = star_vault_modal.find_child("CloseVaultBtn", true, false) as Button

	# Architectural Warm-Obsidian Sheet with neutral frosted specular rim (zero neon wireframe borders)
	if vault_card:
		var vp_sz: Vector2 = get_viewport_rect().size if (is_inside_tree() and get_viewport() != null) else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
		var insets: Dictionary = safe_area_mgr.get_safe_insets(self) if safe_area_mgr else {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
		var avail_w: float = maxf(260.0, vp_sz.x - insets.get("left", 0.0) - insets.get("right", 0.0) - 44.0)
		vault_card.custom_minimum_size = Vector2(clampf(avail_w, 284.0, 330.0), 0.0)

		var sb_card := StyleBoxFlat.new()
		sb_card.bg_color = Color(0.075, 0.088, 0.116, 0.985)
		sb_card.border_color = Color(1.0, 1.0, 1.0, 0.095)
		sb_card.set_border_width_all(1)
		sb_card.set_corner_radius_all(28)
		sb_card.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
		sb_card.shadow_size = 42
		sb_card.shadow_offset = Vector2(0, 18)
		vault_card.add_theme_stylebox_override("panel", sb_card)

	if header_banner:
		header_banner.visible = false

	if title_lbl:
		title_lbl.text = loc_mgr.tr_text("VAULT_UNLOCKED_TITLE") if loc_mgr else "MILESTONE VAULT UNLOCKED"

	if milestone_lbl:
		if has_skin_item:
			milestone_lbl.text = loc_mgr.tr_text("VAULT_MILESTONE_ITEM", [v_name.to_upper(), v_stars]) if loc_mgr else ("%s  ·  %d ★" % [v_name.to_upper(), v_stars])
		else:
			milestone_lbl.text = loc_mgr.tr_text("VAULT_MILESTONE_REACHED", [v_stars]) if loc_mgr else ("MILESTONE  ·  %d ★" % v_stars)
		milestone_lbl.add_theme_font_override("font", _get_modern_font(500))
		milestone_lbl.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.88))
		milestone_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))

	if medallion:
		medallion.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_vault_emblem_accent = accent
	_vault_emblem_skin_id = skin_id_v
	_vault_emblem_is_skin = has_skin_item
	_star_vault_anim_time = 0.0
	_vault_emblem_canvas = emblem_canvas
	if has_skin_item:
		_vault_emblem_kind = "crate_skin" if is_crate_skin else "worker_skin"
	elif v_stars >= 210:
		_vault_emblem_kind = "trophy"
	elif v_stars >= 140 and r_type == "hints":
		_vault_emblem_kind = "prism"
	else:
		_vault_emblem_kind = "cube"

	if spot_rect:
		var g_tex := GradientTexture2D.new()
		g_tex.width = 188
		g_tex.height = 128
		g_tex.fill = GradientTexture2D.FILL_RADIAL
		g_tex.fill_from = Vector2(0.5, 0.50)
		g_tex.fill_to = Vector2(0.5, 0.02)
		var grad := Gradient.new()
		grad.colors = PackedColorArray([
			Color(accent.r, accent.g, accent.b, 0.24),
			Color(accent.r, accent.g, accent.b, 0.08),
			Color(accent.r, accent.g, accent.b, 0.0)
		])
		grad.offsets = PackedFloat32Array([0.0, 0.50, 1.0])
		g_tex.gradient = grad
		spot_rect.texture = g_tex

	if emblem_canvas:
		emblem_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		emblem_canvas.queue_redraw()
	if icon_rect:
		icon_rect.visible = false
	if icon_lbl:
		icon_lbl.text = ""
		icon_lbl.visible = false

	if name_lbl:
		var display_item_name: String = v_name
		if has_skin_item and not skin_info.is_empty():
			var s_name_key: String = str(skin_info.get("name_key", ""))
			if loc_mgr and not s_name_key.is_empty():
				display_item_name = loc_mgr.tr_text(s_name_key)
			elif skin_info.has("name"):
				display_item_name = str(skin_info.get("name", v_name))
		name_lbl.text = display_item_name if has_skin_item else (loc_mgr.tr_text("VAULT_NAME_FORMAT", [v_name]) if loc_mgr else v_name)
		name_lbl.add_theme_font_override("font", _get_modern_font(600))
		name_lbl.add_theme_color_override("font_color", Color(0.955, 0.965, 0.985))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))

	if reward_pill:
		var sb_rp := StyleBoxFlat.new()
		sb_rp.bg_color = Color(1.0, 1.0, 1.0, 0.048)
		sb_rp.border_color = Color(accent.r, accent.g, accent.b, 0.26) if has_skin_item else Color(1.0, 1.0, 1.0, 0.085)
		sb_rp.set_border_width_all(1)
		sb_rp.set_corner_radius_all(999)
		reward_pill.add_theme_stylebox_override("panel", sb_rp)

	if reward_icon:
		reward_icon.visible = false
	if reward_glyph:
		reward_glyph.queue_redraw()

	if reward_lbl:
		if r_type == "hints":
			reward_lbl.text = loc_mgr.tr_text("VAULT_REWARD_HINTS", [r_amount]) if loc_mgr else ("+%d Solver Hints" % r_amount)
		elif is_crate_skin:
			reward_lbl.text = loc_mgr.tr_text("VAULT_REWARD_DEPOT_CRATE") if loc_mgr else "Supply Depot  ·  Crate Skin"
		else:
			reward_lbl.text = loc_mgr.tr_text("VAULT_REWARD_DEPOT_OUTFIT") if loc_mgr else "Supply Depot  ·  Worker Outfit"
		reward_lbl.add_theme_font_override("font", _get_modern_font(500))
		reward_lbl.add_theme_color_override("font_color", accent.lightened(0.32))
		reward_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))

	if desc_lbl:
		var desc_str: String = ""
		if has_skin_item:
			var s_desc_key: String = str(skin_info.get("desc_key", ""))
			if loc_mgr and not s_desc_key.is_empty():
				desc_str = loc_mgr.tr_text(s_desc_key)
			elif skin_info.has("desc"):
				desc_str = str(skin_info.get("desc", ""))
			if desc_str.is_empty():
				desc_str = (loc_mgr.tr_text("VAULT_DESC_CRATE") if is_crate_skin else loc_mgr.tr_text("VAULT_DESC_OUTFIT")) if loc_mgr else "Equippable in Supply Depot"
		desc_lbl.text = desc_str
		desc_lbl.visible = not desc_str.is_empty()
		desc_lbl.add_theme_font_override("font", _get_modern_font(400))
		desc_lbl.add_theme_constant_override("line_spacing", -4)
		desc_lbl.add_theme_color_override("font_color", Color(0.58, 0.65, 0.76))
		desc_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))

	# Quiet minimalist milestone ladder
	var total_stars_now: int = save_mgr.get_total_stars() if (save_mgr and save_mgr.has_method("get_total_stars")) else v_stars
	var next_target: int = v_stars
	if save_mgr and save_mgr.has_method("get_all_star_vaults"):
		for item in save_mgr.get_all_star_vaults():
			var item_stars: int = int(item.get("stars", 0))
			if item_stars > v_stars:
				next_target = item_stars
				break
	if prog_curr_lbl:
		prog_curr_lbl.text = "%d ★" % total_stars_now
		prog_curr_lbl.add_theme_font_override("font", _get_modern_font(500))
		prog_curr_lbl.add_theme_color_override("font_color", Color(0.76, 0.81, 0.89))
		prog_curr_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	if prog_next_lbl:
		if next_target > v_stars:
			prog_next_lbl.text = loc_mgr.tr_text("VAULT_NEXT_TARGET", [next_target]) if loc_mgr else ("Next %d ★" % next_target)
		else:
			prog_next_lbl.text = loc_mgr.tr_text("VAULT_FINAL_TIER") if loc_mgr else "Max Milestone"
		prog_next_lbl.add_theme_font_override("font", _get_modern_font(500))
		prog_next_lbl.add_theme_color_override("font_color", Color(0.45, 0.51, 0.62))
		prog_next_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	if prog_bar:
		prog_bar.max_value = float(maxi(next_target, v_stars))
		prog_bar.value = float(mini(total_stars_now, maxi(next_target, v_stars)))
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = accent.lightened(0.08)
		sb_fill.set_corner_radius_all(2)
		prog_bar.add_theme_stylebox_override("fill", sb_fill)

	if claim_btn:
		claim_btn.icon = null
		if r_type == "hints":
			claim_btn.text = loc_mgr.tr_text("BTN_CLAIM_HINTS", [r_amount]) if loc_mgr else ("Claim +%d Hints" % r_amount)
		else:
			claim_btn.text = loc_mgr.tr_text("BTN_CLAIM_EQUIP") if loc_mgr else "Claim & Equip"
		claim_btn.add_theme_font_override("font", _get_modern_font(600))
		claim_btn.add_theme_font_size_override("font_size", 14)
		var sb_cta := StyleBoxFlat.new()
		sb_cta.bg_color = Color(0.93, 0.57, 0.12)
		sb_cta.border_color = Color(1.0, 1.0, 1.0, 0.25)
		sb_cta.border_width_top = 1
		sb_cta.set_corner_radius_all(14)
		sb_cta.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
		sb_cta.shadow_size = 4
		sb_cta.shadow_offset = Vector2(0, 2)
		sb_cta.content_margin_top = 13.0
		sb_cta.content_margin_bottom = 13.0
		claim_btn.add_theme_stylebox_override("normal", sb_cta)
		var sb_cta_hov := sb_cta.duplicate() as StyleBoxFlat
		sb_cta_hov.bg_color = Color(0.97, 0.63, 0.17)
		claim_btn.add_theme_stylebox_override("hover", sb_cta_hov)
		var sb_cta_prs := sb_cta.duplicate() as StyleBoxFlat
		sb_cta_prs.bg_color = Color(0.79, 0.46, 0.08)
		claim_btn.add_theme_stylebox_override("pressed", sb_cta_prs)
		claim_btn.add_theme_color_override("font_color", Color(0.067, 0.078, 0.110))
		claim_btn.add_theme_color_override("font_hover_color", Color(0.04, 0.05, 0.08))
		claim_btn.add_theme_color_override("font_pressed_color", Color(0.067, 0.078, 0.110))
		claim_btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	if close_v_btn:
		close_v_btn.text = loc_mgr.tr_text("BTN_LATER") if loc_mgr else "Later"
		close_v_btn.add_theme_font_override("font", _get_modern_font(500))
		close_v_btn.add_theme_font_size_override("font_size", 13)
		close_v_btn.add_theme_color_override("font_color", Color(0.46, 0.52, 0.63))
		close_v_btn.add_theme_color_override("font_hover_color", Color(0.78, 0.83, 0.92))
		close_v_btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
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
			_update_menu_state()
			_refresh_level_grid_buttons()
			# Chain seamlessly if player unlocked multiple Star Vaults before returning!
			var remaining_vaults: Array[Dictionary] = save_mgr.get_unclaimed_star_vaults() if (save_mgr and save_mgr.has_method("get_unclaimed_star_vaults")) else []
			if not remaining_vaults.is_empty():
				var nxt: Dictionary = remaining_vaults[0]
				_show_star_vault_modal(int(nxt["index"]), nxt["vault"])
			else:
				_hide_star_vault_modal()
				_show_vault_claimed_toast(v_name, accent)
		)

	star_vault_modal.show()
	if _star_vault_tw != null and _star_vault_tw.is_valid():
		_star_vault_tw.kill()
		_star_vault_tw = null

	if DisplayServer.get_name() == "headless":
		star_vault_modal.modulate.a = 1.0
		if vault_card:
			vault_card.scale = Vector2.ONE
	else:
		star_vault_modal.modulate.a = 0.0
		if vault_card:
			vault_card.pivot_offset = vault_card.size * 0.5
			vault_card.scale = Vector2(0.88, 0.88)
		_star_vault_tw = create_tween().set_parallel(true)
		_star_vault_tw.tween_property(star_vault_modal, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if vault_card:
			_star_vault_tw.tween_property(vault_card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if audio_mgr:
		audio_mgr.play_star(3)


func _hide_star_vault_modal() -> void:
	if _star_vault_tw != null and _star_vault_tw.is_valid():
		_star_vault_tw.kill()
		_star_vault_tw = null
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
	modal.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var center: CenterContainer = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.name = "VaultCard"
	var vp_sz: Vector2 = get_viewport_rect().size if (is_inside_tree() and get_viewport() != null) else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
	var insets: Dictionary = safe_area_mgr.get_safe_insets(self) if safe_area_mgr else {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	var avail_w: float = maxf(260.0, vp_sz.x - insets.get("left", 0.0) - insets.get("right", 0.0) - 44.0)
	card.custom_minimum_size = Vector2(clampf(avail_w, 284.0, 330.0), 0.0)
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# 1. Top Header Banner Plaque
	var header_banner: PanelContainer = PanelContainer.new()
	header_banner.name = "HeaderBanner"
	vbox.add_child(header_banner)

	var hdr_margin := MarginContainer.new()
	hdr_margin.add_theme_constant_override("margin_left", 10)
	hdr_margin.add_theme_constant_override("margin_top", 6)
	hdr_margin.add_theme_constant_override("margin_right", 10)
	hdr_margin.add_theme_constant_override("margin_bottom", 6)
	header_banner.add_child(hdr_margin)

	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.add_theme_constant_override("separation", 8)
	hdr_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr_margin.add_child(hdr_hbox)

	var s_left := TextureRect.new()
	s_left.custom_minimum_size = Vector2(16, 16)
	s_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s_left.texture = icon_star_full
	hdr_hbox.add_child(s_left)

	var title_lbl: Label = Label.new()
	title_lbl.name = "VaultTitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	hdr_hbox.add_child(title_lbl)

	var s_right := TextureRect.new()
	s_right.custom_minimum_size = Vector2(16, 16)
	s_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s_right.texture = icon_star_full
	hdr_hbox.add_child(s_right)

	# 2. Clean Borderless Reward Showcase
	var showcase := PanelContainer.new()
	showcase.name = "ShowcasePanel"
	showcase.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	vbox.add_child(showcase)

	var show_margin := MarginContainer.new()
	show_margin.add_theme_constant_override("margin_left", 0)
	show_margin.add_theme_constant_override("margin_top", 0)
	show_margin.add_theme_constant_override("margin_right", 0)
	show_margin.add_theme_constant_override("margin_bottom", 2)
	showcase.add_child(show_margin)

	var show_vbox := VBoxContainer.new()
	show_vbox.add_theme_constant_override("separation", 8)
	show_margin.add_child(show_vbox)

	var milestone_lbl := Label.new()
	milestone_lbl.name = "MilestoneTagLabel"
	milestone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milestone_lbl.add_theme_font_size_override("font_size", 11)
	show_vbox.add_child(milestone_lbl)

	var medallion := PanelContainer.new()
	medallion.name = "MedallionFrame"
	medallion.custom_minimum_size = Vector2(176, 102)
	medallion.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	show_vbox.add_child(medallion)

	var med_center := CenterContainer.new()
	medallion.add_child(med_center)

	var spot_rect := TextureRect.new()
	spot_rect.name = "HeroSpotlight"
	spot_rect.custom_minimum_size = Vector2(188, 114)
	spot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot_rect.stretch_mode = TextureRect.STRETCH_SCALE
	spot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	med_center.add_child(spot_rect)

	var emblem_canvas := Control.new()
	emblem_canvas.name = "VaultEmblemCanvas"
	emblem_canvas.custom_minimum_size = Vector2(148, 98)
	emblem_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	emblem_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem_canvas.draw.connect(_draw_vault_hero_emblem.bind(emblem_canvas))
	med_center.add_child(emblem_canvas)

	var icon_lbl: Label = Label.new()
	icon_lbl.name = "VaultIconLabel"
	icon_lbl.visible = false
	med_center.add_child(icon_lbl)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = "VaultIconRect"
	icon_rect.visible = false
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	med_center.add_child(icon_rect)

	var name_lbl: Label = Label.new()
	name_lbl.name = "VaultNameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 21)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	show_vbox.add_child(name_lbl)

	var reward_pill := PanelContainer.new()
	reward_pill.name = "RewardPill"
	reward_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	show_vbox.add_child(reward_pill)

	var rp_mg := MarginContainer.new()
	rp_mg.add_theme_constant_override("margin_left", 13)
	rp_mg.add_theme_constant_override("margin_top", 5)
	rp_mg.add_theme_constant_override("margin_right", 15)
	rp_mg.add_theme_constant_override("margin_bottom", 5)
	reward_pill.add_child(rp_mg)

	var rp_hb := HBoxContainer.new()
	rp_hb.add_theme_constant_override("separation", 7)
	rp_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	rp_mg.add_child(rp_hb)

	var rp_icon := TextureRect.new()
	rp_icon.name = "RewardPillIcon"
	rp_icon.visible = false
	rp_icon.custom_minimum_size = Vector2(14, 14)
	rp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rp_hb.add_child(rp_icon)

	var rp_glyph := Control.new()
	rp_glyph.name = "RewardGlyphCanvas"
	rp_glyph.custom_minimum_size = Vector2(12, 12)
	rp_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rp_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp_glyph.draw.connect(_draw_reward_pill_glyph.bind(rp_glyph))
	rp_hb.add_child(rp_glyph)

	var rp_lbl := Label.new()
	rp_lbl.name = "RewardPillLabel"
	rp_lbl.add_theme_font_size_override("font_size", 13)
	rp_hb.add_child(rp_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.name = "VaultDescLabel"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.54, 0.60, 0.70))
	show_vbox.add_child(desc_lbl)

	# 3. Quiet Minimal Milestone Progression Track
	var prog_vbox := VBoxContainer.new()
	prog_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(prog_vbox)

	var prog_hdr := HBoxContainer.new()
	prog_vbox.add_child(prog_hdr)

	var prog_curr := Label.new()
	prog_curr.name = "ProgressCurrentLbl"
	prog_curr.add_theme_font_size_override("font_size", 11)
	prog_curr.add_theme_color_override("font_color", Color(0.76, 0.81, 0.89))
	prog_hdr.add_child(prog_curr)

	var prog_spacer := Control.new()
	prog_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_hdr.add_child(prog_spacer)

	var prog_next := Label.new()
	prog_next.name = "ProgressNextLbl"
	prog_next.add_theme_font_size_override("font_size", 11)
	prog_next.add_theme_color_override("font_color", Color(0.45, 0.51, 0.62))
	prog_hdr.add_child(prog_next)

	var prog_bar := ProgressBar.new()
	prog_bar.name = "VaultProgressBar"
	prog_bar.custom_minimum_size = Vector2(0, 3)
	prog_bar.show_percentage = false
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(1.0, 1.0, 1.0, 0.085)
	sb_track.set_corner_radius_all(2)
	prog_bar.add_theme_stylebox_override("background", sb_track)
	prog_vbox.add_child(prog_bar)

	# 4. Crisp Editorial Action Footer
	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_vbox)

	var claim_btn: Button = Button.new()
	claim_btn.name = "ClaimVaultBtn"
	claim_btn.text = "Claim Reward"
	claim_btn.custom_minimum_size = Vector2(0, 46)
	claim_btn.add_theme_font_size_override("font_size", 14)
	claim_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_attach_spring_physics(claim_btn)
	btn_vbox.add_child(claim_btn)

	var close_btn: Button = Button.new()
	close_btn.name = "CloseVaultBtn"
	close_btn.text = "Later"
	close_btn.custom_minimum_size = Vector2(0, 34)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_color_override("font_color", Color(0.46, 0.52, 0.63))
	close_btn.add_theme_color_override("font_hover_color", Color(0.78, 0.83, 0.92))
	close_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	close_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.pressed.connect(_hide_star_vault_modal)
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
					if is_instance_valid(self):
						is_scrolling = false
				, CONNECT_ONE_SHOT)
			else:
				is_scrolling = false
		else:
			is_scrolling = false

	func is_drag_scrolling() -> bool:
		return is_scrolling or (Time.get_ticks_msec() - last_scroll_msec < 120)
