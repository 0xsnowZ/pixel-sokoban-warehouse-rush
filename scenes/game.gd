extends Control

## Main playable game scene for Pixel Porter.
## Renders the grid, handles swipes and keyboard input, animates moves,
## and implements PRD Section 4 & 5 gameplay and UI requirements.

const SaveManagerScript = preload("res://scripts/save_manager.gd")
const SokobanSolverScript = preload("res://scripts/sokoban_solver.gd")

# Levels available (50 verified solvable levels)
var level_paths: Array[String] = _get_default_level_paths()
var current_level_index: int = 0

static func _get_default_level_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in range(1, 51):
		paths.append("res://levels/level_%02d.sok" % i)
	return paths

var grid: GridLogic
var save_mgr: Node = null
var audio_mgr: Node = null
var loc_mgr: Node = null
var ad_mgr: Node = null
var haptic_mgr: Node = null
var safe_area_mgr: Node = null

# Visual settings
var tile_size: float = 64.0
var grid_origin: Vector2 = Vector2.ZERO
var _layout_dirty: bool = true
var player_facing_dir: Vector2i = Vector2i.DOWN
var win_particles: Array[Dictionary] = []
var is_level_won: bool = false
var player_celebration_hop: float = 0.0
var victory_radiance_rings: Array[Dictionary] = []
var star_burst_particles: Array[Dictionary] = []

# Game Feel & Tactility (Option A)
var is_undo_held: bool = false
var undo_hold_time: float = 0.0
var undo_step_timer: float = 0.0
var bump_offset: Vector2 = Vector2.ZERO

# Visual Atmosphere & Polish (Option B)
var ambient_motes: Array[Dictionary] = []

# Live HUD 3-Star Tracker & Worker Micro-Interactions (Option C)
var player_idle_time: float = 0.0
var consecutive_wall_bumps: int = 0
var sweat_drop_timer: float = 0.0
var _prev_live_stars: int = 3

# 3 Logistics Chapters & Visual Progression (PRD Phase 2)
# Ch 0: Cargo Bay (Levels 1–15, idx 0–14)
# Ch 1: Cold Storage (Levels 16–35, idx 15–34)
# Ch 2: Cyber Depot (Levels 36–50, idx 35–49)
const CHAPTER_THEMES: Array[Dictionary] = [
	{
		"id": 0,
		"name": "Cargo Bay",
		"icon": "📦",
		"frame_base": Color(0.12, 0.15, 0.20),
		"frame_rim": Color(0.78, 0.60, 0.22),
		"frame_groove": Color(0.06, 0.08, 0.12),
		"bolt_dark": Color(0.12, 0.09, 0.05),
		"bolt_core": Color(0.92, 0.74, 0.28),
		"bolt_specular": Color(1.0, 0.95, 0.70),
		"floor_tint": Color(1.0, 1.0, 1.0),
		"wall_tint": Color(1.0, 1.0, 1.0),
		"goal_aura": Color(0.98, 0.82, 0.20),
		"goal_core": Color(1.0, 1.0, 0.85, 0.90),
		"crate_tint": Color(1.0, 1.0, 1.0),
		"dim_color": Color(0.02, 0.03, 0.06, 0.40),
		"badge_color": Color(0.98, 0.82, 0.25)
	},
	{
		"id": 1,
		"name": "Cold Storage",
		"icon": "❄",
		"frame_base": Color(0.08, 0.14, 0.22),
		"frame_rim": Color(0.35, 0.82, 1.00),
		"frame_groove": Color(0.04, 0.07, 0.14),
		"bolt_dark": Color(0.04, 0.08, 0.15),
		"bolt_core": Color(0.55, 0.90, 1.00),
		"bolt_specular": Color(0.88, 0.96, 1.00),
		"floor_tint": Color(0.82, 0.92, 1.00),
		"wall_tint": Color(0.80, 0.90, 1.00),
		"goal_aura": Color(0.25, 0.85, 1.00),
		"goal_core": Color(0.85, 0.98, 1.00, 0.95),
		"crate_tint": Color(0.92, 0.96, 1.00),
		"dim_color": Color(0.02, 0.06, 0.12, 0.45),
		"badge_color": Color(0.35, 0.85, 1.00)
	},
	{
		"id": 2,
		"name": "Cyber Depot",
		"icon": "⚡",
		"frame_base": Color(0.06, 0.07, 0.10),
		"frame_rim": Color(1.00, 0.65, 0.18),
		"frame_groove": Color(0.03, 0.04, 0.06),
		"bolt_dark": Color(0.05, 0.04, 0.02),
		"bolt_core": Color(1.00, 0.72, 0.24),
		"bolt_specular": Color(1.00, 0.92, 0.65),
		"floor_tint": Color(0.88, 0.88, 0.94),
		"wall_tint": Color(0.78, 0.76, 0.86),
		"goal_aura": Color(0.20, 1.00, 0.55),
		"goal_core": Color(0.75, 1.00, 0.85, 0.95),
		"crate_tint": Color(1.00, 0.94, 0.90),
		"dim_color": Color(0.05, 0.04, 0.08, 0.45),
		"badge_color": Color(1.00, 0.65, 0.20)
	}
]

var current_chapter_idx: int = 0
var _last_loaded_chapter: int = -1

# Juice & Micro-interaction state
var board_trauma: float = 0.0
var board_shake_offset: Vector2 = Vector2.ZERO
var crate_squash: Dictionary = {} # Vector2i -> Vector2 scale
var dust_particles: Array[Dictionary] = []
var goal_effects: Array[Dictionary] = []
var _last_hud_moves: int = 0

# Animation state
var is_animating: bool = false
var queued_move_dir: Vector2i = Vector2i.ZERO # PRD Section 5: "A swipe made during a move animation is queued (one move only)"
var visual_player_pos: Vector2 = Vector2.ZERO
var visual_crates: Dictionary = {} # Vector2i (current logical) -> Vector2 (interpolated visual)
var walk_step_count: int = 0
var current_walk_frame: int = 0 # 0: idle stance, 1: walk frame 1, 2: walk frame 2

# Hint state (P3: Hint via Solver)
var active_hint_dir: Vector2i = Vector2i.ZERO
var hint_player_target: Vector2i = Vector2i.ZERO
var hint_crate_target: Vector2i = Vector2i.ZERO
var hint_has_crate: bool = false
var hint_time_remaining: float = 0.0
var hint_pulse_timer: float = 0.0

# Touch / Swipe handling (PRD Section 5)
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touching: bool = false
const SWIPE_THRESHOLD_PIXELS: float = 30.0

var achievement_mgr: Node = null
var ad_reward_modal: PanelContainer = null

# UI references
@onready var top_bar_margin: MarginContainer = $TopBar/Margin
@onready var bottom_bar_margin: MarginContainer = $BottomBar/Margin
@onready var menu_button: Button = find_child("MenuBtn", true, false) as Button
@onready var music_button: Button = find_child("MusicBtn", true, false) as Button
@onready var control_button: Button = find_child("ControlBtn", true, false) as Button
@onready var chapter_badge: Label = find_child("ChapterBadge", true, false) as Label
@onready var dpad_overlay: Control = find_child("DPadOverlay", true, false) as Control
@onready var dpad_up: Button = find_child("DPadUp", true, false) as Button
@onready var dpad_down: Button = find_child("DPadDown", true, false) as Button
@onready var dpad_left: Button = find_child("DPadLeft", true, false) as Button
@onready var dpad_right: Button = find_child("DPadRight", true, false) as Button
@onready var level_label: Label = find_child("LevelLabel", true, false) as Label
@onready var star_gauge: Label = find_child("StarGauge", true, false) as Label
@onready var stats_label: Label = find_child("StatsLabel", true, false) as Label
@onready var prev_button: Button = $BottomBar/Margin/HBox/PrevButton if has_node("BottomBar/Margin/HBox/PrevButton") else null
@onready var undo_button: Button = $BottomBar/Margin/HBox/UndoButton if has_node("BottomBar/Margin/HBox/UndoButton") else null
@onready var hint_button: Button = $BottomBar/Margin/HBox/HintButton if has_node("BottomBar/Margin/HBox/HintButton") else null
@onready var hint_toast: PanelContainer = $HintToast if has_node("HintToast") else null
@onready var hint_toast_label: Label = $HintToast/Margin/Label if has_node("HintToast/Margin/Label") else ($HintToast/Label if has_node("HintToast/Label") else null)
@onready var restart_button: Button = $BottomBar/Margin/HBox/RestartButton if has_node("BottomBar/Margin/HBox/RestartButton") else null
@onready var next_button: Button = $BottomBar/Margin/HBox/NextButton if has_node("BottomBar/Margin/HBox/NextButton") else null
@onready var win_modal: PanelContainer = $WinModal
@onready var win_blur_overlay: ColorRect = $WinBlurOverlay if has_node("WinBlurOverlay") else null
@onready var win_title: Label = $WinModal.find_child("WinTitle", true, false) if has_node("WinModal") else null
@onready var win_stats: Label = $WinModal.find_child("WinStats", true, false) if has_node("WinModal") else null
@onready var win_menu_button: Button = $WinModal.find_child("WinMenuBtn", true, false) if has_node("WinModal") else null
@onready var next_level_button: Button = $WinModal.find_child("NextLevelBtn", true, false) if has_node("WinModal") else null
@onready var win_retry_button: Button = $WinModal.find_child("WinRetryBtn", true, false) if has_node("WinModal") else null
@onready var level_placard_label: Label = $WinModal.find_child("LevelPlacardLabel", true, false) if has_node("WinModal") else null
@onready var star_1: Label = $WinModal.find_child("Star1", true, false) if has_node("WinModal") else null
@onready var star_2: Label = $WinModal.find_child("Star2", true, false) if has_node("WinModal") else null
@onready var star_3: Label = $WinModal.find_child("Star3", true, false) if has_node("WinModal") else null
@onready var restart_dialog: ConfirmationDialog = $RestartConfirmDialog

var level_start_time: int = 0

# Board sprite textures
var tex_wall: Texture2D = preload("res://assets/wall_brick.png")
var tex_floor_1: Texture2D = preload("res://assets/floor_tile_1.png")
var tex_floor_2: Texture2D = preload("res://assets/floor_tile_2.png")
var tex_goal: Texture2D = preload("res://assets/goal_pad.png")
var tex_crate: Texture2D = preload("res://assets/crate_normal.png")
var tex_crate_goal: Texture2D = preload("res://assets/crate_goal.png")
var tex_void_high_value_crate: Texture2D = preload("res://assets/void_high_value_crate.png")
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

# Enhanced High-Resolution UI Icon Textures
var icon_home: Texture2D = preload("res://assets/icons/icon_home.png")
var icon_music_on: Texture2D = preload("res://assets/icons/icon_music_on.png")
var icon_music_off: Texture2D = preload("res://assets/icons/icon_music_off.png")
var icon_control_swipe: Texture2D = preload("res://assets/icons/icon_control_swipe.png")
var icon_control_dpad: Texture2D = preload("res://assets/icons/icon_control_dpad.png")
var icon_control_gamepad: Texture2D = preload("res://assets/icons/icon_control_gamepad.png")
var icon_dpad_up: Texture2D = preload("res://assets/icons/icon_dpad_up.png")
var icon_dpad_down: Texture2D = preload("res://assets/icons/icon_dpad_down.png")
var icon_dpad_left: Texture2D = preload("res://assets/icons/icon_dpad_left.png")
var icon_dpad_right: Texture2D = preload("res://assets/icons/icon_dpad_right.png")
var icon_undo: Texture2D = preload("res://assets/icons/icon_undo.png")
var icon_restart: Texture2D = preload("res://assets/icons/icon_restart.png")
var icon_hint: Texture2D = preload("res://assets/icons/icon_hint.png")


func _initialize_nodes() -> void:
	if has_node("Background"):
		$Background.show_behind_parent = true
	if has_node("DimOverlay"):
		$DimOverlay.show_behind_parent = true
	if top_bar_margin == null and has_node("TopBar/Margin"):
		top_bar_margin = $TopBar/Margin
		bottom_bar_margin = $BottomBar/Margin
	if menu_button == null:
		menu_button = find_child("MenuBtn", true, false) as Button
	if music_button == null:
		music_button = find_child("MusicBtn", true, false) as Button
	if control_button == null:
		control_button = find_child("ControlBtn", true, false) as Button
	if chapter_badge == null:
		chapter_badge = find_child("ChapterBadge", true, false) as Label
	if level_label == null:
		level_label = find_child("LevelLabel", true, false) as Label
	if star_gauge == null:
		star_gauge = find_child("StarGauge", true, false) as Label
	if stats_label == null:
		stats_label = find_child("StatsLabel", true, false) as Label
	if dpad_overlay == null:
		dpad_overlay = find_child("DPadOverlay", true, false) as Control
		dpad_up = find_child("DPadUp", true, false) as Button
		dpad_down = find_child("DPadDown", true, false) as Button
		dpad_left = find_child("DPadLeft", true, false) as Button
		dpad_right = find_child("DPadRight", true, false) as Button
	if undo_button == null and has_node("BottomBar/Margin/HBox/UndoButton"):
		undo_button = $BottomBar/Margin/HBox/UndoButton
	if hint_button == null and has_node("BottomBar/Margin/HBox/HintButton"):
		hint_button = $BottomBar/Margin/HBox/HintButton
	if restart_button == null and has_node("BottomBar/Margin/HBox/RestartButton"):
		restart_button = $BottomBar/Margin/HBox/RestartButton
	if prev_button == null and has_node("BottomBar/Margin/HBox/PrevButton"):
		prev_button = $BottomBar/Margin/HBox/PrevButton
	if next_button == null and has_node("BottomBar/Margin/HBox/NextButton"):
		next_button = $BottomBar/Margin/HBox/NextButton
	if hint_toast == null and has_node("HintToast"):
		hint_toast = $HintToast
		if has_node("HintToast/Margin/Label"):
			hint_toast_label = $HintToast/Margin/Label
		elif has_node("HintToast/Label"):
			hint_toast_label = $HintToast/Label
	if restart_dialog == null and has_node("RestartConfirmDialog"):
		restart_dialog = $RestartConfirmDialog

	if win_modal == null and has_node("WinModal"):
		win_modal = $WinModal
	if win_blur_overlay == null and has_node("WinBlurOverlay"):
		win_blur_overlay = $WinBlurOverlay
	if win_modal != null:
		win_title = win_modal.find_child("WinTitle", true, false)
		win_stats = win_modal.find_child("WinStats", true, false)
		win_menu_button = win_modal.find_child("WinMenuBtn", true, false)
		next_level_button = win_modal.find_child("NextLevelBtn", true, false)
		win_retry_button = win_modal.find_child("WinRetryBtn", true, false)
		level_placard_label = win_modal.find_child("LevelPlacardLabel", true, false)
		star_1 = win_modal.find_child("Star1", true, false)
		star_2 = win_modal.find_child("Star2", true, false)
		star_3 = win_modal.find_child("Star3", true, false)

	# Enhanced UI icons on buttons
	if menu_button != null:
		menu_button.icon = icon_home
		menu_button.text = ""
		menu_button.expand_icon = true
		menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if dpad_up != null:
		dpad_up.icon = icon_dpad_up
		dpad_up.text = ""
		dpad_up.expand_icon = true
		dpad_up.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if dpad_down != null:
		dpad_down.icon = icon_dpad_down
		dpad_down.text = ""
		dpad_down.expand_icon = true
		dpad_down.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if dpad_left != null:
		dpad_left.icon = icon_dpad_left
		dpad_left.text = ""
		dpad_left.expand_icon = true
		dpad_left.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if dpad_right != null:
		dpad_right.icon = icon_dpad_right
		dpad_right.text = ""
		dpad_right.expand_icon = true
		dpad_right.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if undo_button != null:
		undo_button.icon = icon_undo
		undo_button.expand_icon = true
		undo_button.add_theme_constant_override("icon_max_width", 22)
		undo_button.add_theme_constant_override("h_separation", 8)
		undo_button.add_theme_color_override("icon_disabled_color", Color(0.55, 0.65, 0.78, 0.50))
	if restart_button != null:
		restart_button.icon = icon_restart
		restart_button.expand_icon = true
		restart_button.add_theme_constant_override("icon_max_width", 22)
		restart_button.add_theme_constant_override("h_separation", 8)
	if hint_button != null:
		hint_button.icon = icon_hint
		hint_button.expand_icon = true
		hint_button.add_theme_constant_override("icon_max_width", 22)
		hint_button.add_theme_constant_override("h_separation", 8)

	if win_menu_button != null:
		win_menu_button.icon = null
	if win_retry_button != null:
		win_retry_button.icon = null
	if next_level_button != null:
		next_level_button.icon = null


func _ready() -> void:
	_initialize_nodes()
	if save_mgr == null:
		if is_inside_tree() and get_tree().root.has_node("SaveManager"):
			save_mgr = get_tree().root.get_node("SaveManager")
		else:
			save_mgr = SaveManagerScript.new()
			add_child(save_mgr)

	if audio_mgr == null and is_inside_tree() and get_tree().root.has_node("AudioManager"):
		audio_mgr = get_tree().root.get_node("AudioManager")

	if loc_mgr == null and is_inside_tree() and get_tree().root.has_node("LocalizationManager"):
		loc_mgr = get_tree().root.get_node("LocalizationManager")

	if ad_mgr == null and is_inside_tree() and get_tree().root.has_node("AdManager"):
		ad_mgr = get_tree().root.get_node("AdManager")

	if haptic_mgr == null and is_inside_tree() and get_tree().root.has_node("HapticManager"):
		haptic_mgr = get_tree().root.get_node("HapticManager")

	if safe_area_mgr == null and is_inside_tree() and get_tree().root.has_node("SafeAreaManager"):
		safe_area_mgr = get_tree().root.get_node("SafeAreaManager")
	if safe_area_mgr:
		safe_area_mgr.safe_area_changed.connect(_on_safe_area_changed)
		_apply_safe_area()

	if achievement_mgr == null and is_inside_tree() and get_tree().root.has_node("AchievementManager"):
		achievement_mgr = get_tree().root.get_node("AchievementManager")

	if ad_mgr != null and not ad_mgr.rewarded_earned.is_connected(_on_rewarded_hints_earned):
		ad_mgr.rewarded_earned.connect(_on_rewarded_hints_earned)

	if save_mgr != null and not save_mgr.hints_changed.is_connected(_on_hints_changed):
		save_mgr.hints_changed.connect(_on_hints_changed)

	grid = GridLogic.new()
	grid.crate_pushed.connect(_on_crate_pushed)
	grid.player_moved.connect(_on_player_moved)
	grid.move_undone.connect(_on_move_undone)
	grid.level_won.connect(_on_level_won)
	grid.level_reset.connect(_on_level_reset)

	if not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)
	if not win_menu_button.pressed.is_connected(_on_menu_pressed):
		win_menu_button.pressed.connect(_on_menu_pressed)
	if undo_button != null:
		if not undo_button.pressed.is_connected(_on_undo_pressed):
			undo_button.pressed.connect(_on_undo_pressed)
		if not undo_button.button_down.is_connected(_on_undo_button_down):
			undo_button.button_down.connect(_on_undo_button_down)
		if not undo_button.button_up.is_connected(_on_undo_button_up):
			undo_button.button_up.connect(_on_undo_button_up)
	if hint_button != null and not hint_button.pressed.is_connected(_on_hint_pressed):
		hint_button.pressed.connect(_on_hint_pressed)
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	if prev_button != null and not prev_button.pressed.is_connected(_on_prev_level_pressed):
		prev_button.pressed.connect(_on_prev_level_pressed)
	if next_button != null and not next_button.pressed.is_connected(_on_next_level_pressed):
		next_button.pressed.connect(_on_next_level_pressed)
	if next_level_button != null and not next_level_button.pressed.is_connected(_on_next_level_pressed):
		next_level_button.pressed.connect(_on_next_level_pressed)
	if win_retry_button != null and not win_retry_button.pressed.is_connected(_on_win_retry_pressed):
		win_retry_button.pressed.connect(_on_win_retry_pressed)
	if not restart_dialog.confirmed.is_connected(_do_restart):
		restart_dialog.confirmed.connect(_do_restart)
	if not restart_dialog.canceled.is_connected(_on_restart_dialog_canceled):
		restart_dialog.canceled.connect(_on_restart_dialog_canceled)
	if music_button != null and not music_button.pressed.is_connected(_on_music_btn_pressed):
		music_button.pressed.connect(_on_music_btn_pressed)
	if control_button != null and not control_button.pressed.is_connected(_on_control_button_pressed):
		control_button.pressed.connect(_on_control_button_pressed)
	if dpad_up != null and not dpad_up.pressed.is_connected(_on_dpad_up_pressed):
		dpad_up.pressed.connect(_on_dpad_up_pressed)
	if dpad_down != null and not dpad_down.pressed.is_connected(_on_dpad_down_pressed):
		dpad_down.pressed.connect(_on_dpad_down_pressed)
	if dpad_left != null and not dpad_left.pressed.is_connected(_on_dpad_left_pressed):
		dpad_left.pressed.connect(_on_dpad_left_pressed)
	if dpad_right != null and not dpad_right.pressed.is_connected(_on_dpad_right_pressed):
		dpad_right.pressed.connect(_on_dpad_right_pressed)
	_update_music_button_ui()
	_update_control_scheme_ui()

	if star_1:
		star_1.pivot_offset = Vector2(28, 28)
		star_1.rotation_degrees = -10.0
	if star_2:
		star_2.pivot_offset = Vector2(34, 34)
		star_2.rotation_degrees = 0.0
	if star_3:
		star_3.pivot_offset = Vector2(28, 28)
		star_3.rotation_degrees = 10.0

	if loc_mgr:
		restart_dialog.ok_button_text = loc_mgr.tr_text("BTN_RESTART")
		restart_dialog.cancel_button_text = loc_mgr.tr_text("BTN_CLOSE")

	var initial_level: int = 0
	if save_mgr and save_mgr.last_played_level >= 0 and save_mgr.last_played_level < level_paths.size():
		initial_level = save_mgr.last_played_level
	load_level(initial_level)
	if get_viewport():
		get_viewport().size_changed.connect(queue_redraw)

	# Tactile arcade button physics
	if menu_button:
		_attach_spring_physics(menu_button)
	if prev_button:
		_attach_spring_physics(prev_button)
	if undo_button:
		_attach_spring_physics(undo_button)
	if hint_button:
		_attach_spring_physics(hint_button)
	if restart_button:
		_attach_spring_physics(restart_button)
	if next_button:
		_attach_spring_physics(next_button)
	if hint_toast != null:
		hint_toast.hide()
	if win_menu_button:
		_attach_spring_physics(win_menu_button)
	if next_level_button:
		_attach_spring_physics(next_level_button)
	if win_retry_button:
		_attach_spring_physics(win_retry_button)
	for b in [control_button, dpad_up, dpad_down, dpad_left, dpad_right]:
		if b != null:
			_attach_spring_physics(b)


func _apply_safe_area() -> void:
	if safe_area_mgr != null:
		if top_bar_margin != null:
			safe_area_mgr.apply_safe_area_margins(top_bar_margin, 16, 10, 16, 10, true, false)
		if bottom_bar_margin != null:
			safe_area_mgr.apply_safe_area_margins(bottom_bar_margin, 16, 10, 16, 10, false, true)
	calculate_layout()
	queue_redraw()


func _on_safe_area_changed(_insets: Dictionary) -> void:
	_apply_safe_area()


func get_chapter_index(level_idx: int = -1) -> int:
	var l_idx: int = current_level_index if level_idx < 0 else level_idx
	if save_mgr and save_mgr.has_method("get_chapter_index"):
		return save_mgr.get_chapter_index(l_idx)
	if l_idx < 15:
		return 0
	elif l_idx < 35:
		return 1
	return 2


func get_current_chapter_theme() -> Dictionary:
	var idx: int = clampi(current_chapter_idx, 0, CHAPTER_THEMES.size() - 1)
	return CHAPTER_THEMES[idx]


func announce_chapter(ch_idx: int) -> void:
	var ch: Dictionary = CHAPTER_THEMES[clampi(ch_idx, 0, CHAPTER_THEMES.size() - 1)]
	var ch_key: String = "CHAPTER_%d_TITLE" % ch_idx
	var ch_title: String = loc_mgr.tr_text(ch_key) if loc_mgr else ch["name"]
	var toast_msg: String = loc_mgr.tr_text("CHAPTER_TOAST", [ch_idx + 1, ch_title]) if loc_mgr else ("CHAPTER %d: %s" % [ch_idx + 1, ch_title])
	_show_hint_toast(toast_msg, ch["badge_color"])


func load_level(index: int) -> void:
	var target_index: int = clampi(index, 0, level_paths.size() - 1)
	if save_mgr and not save_mgr.is_level_unlocked(target_index):
		return

	var prev_ch: int = current_chapter_idx
	current_level_index = target_index
	current_chapter_idx = get_chapter_index(current_level_index)
	var ch: Dictionary = get_current_chapter_theme()

	if has_node("DimOverlay"):
		var dim: ColorRect = get_node("DimOverlay") as ColorRect
		if dim:
			dim.color = ch["dim_color"]

	if _last_loaded_chapter != -1 and prev_ch != current_chapter_idx:
		announce_chapter(current_chapter_idx)
	_last_loaded_chapter = current_chapter_idx

	if save_mgr:
		save_mgr.last_played_level = current_level_index

	var path: String = level_paths[current_level_index]
	var ok: bool = grid.load_from_file(path)
	if not ok:
		push_error("Failed to load level: %s" % path)
		return

	_layout_dirty = true
	is_animating = false
	queued_move_dir = Vector2i.ZERO
	current_walk_frame = 0
	walk_step_count = 0
	clear_hint()
	is_level_won = false
	player_celebration_hop = 0.0
	victory_radiance_rings.clear()
	star_burst_particles.clear()
	win_particles.clear()
	level_start_time = Time.get_ticks_msec()
	if win_modal:
		win_modal.hide()
	if win_blur_overlay:
		win_blur_overlay.hide()
	if ad_mgr:
		ad_mgr.preload_interstitial()
	if audio_mgr and audio_mgr.has_method("unduck_music"):
		audio_mgr.unduck_music(0.8)

	# Sync visual positions
	visual_player_pos = Vector2(grid.get_player_pos())
	visual_crates.clear()
	for crate_pos in grid.crates.keys():
		visual_crates[crate_pos] = Vector2(crate_pos)

	_last_hud_moves = 0
	board_trauma = 0.0
	board_shake_offset = Vector2.ZERO
	dust_particles.clear()
	goal_effects.clear()
	crate_squash.clear()
	_init_ambient_motes()
	player_idle_time = 0.0
	consecutive_wall_bumps = 0
	sweat_drop_timer = 0.0
	_prev_live_stars = 3

	_update_ui()
	queue_redraw()


func _update_ui() -> void:
	var best_str: String = ""
	if save_mgr and save_mgr.is_level_completed(current_level_index):
		var rec: Dictionary = save_mgr.get_level_record(current_level_index)
		var best_m: int = rec.get("best_moves", 0)
		best_str = "   •   %s" % (loc_mgr.tr_text("GAME_BEST", [best_m]) if loc_mgr else "BEST: %d" % best_m)

	if chapter_badge != null:
		var ch_info: Dictionary = get_current_chapter_theme()
		chapter_badge.text = "CH. %d" % [current_chapter_idx + 1]
		chapter_badge.modulate = ch_info["badge_color"]

	# Option C: Real-Time Live 3-Star Rating & Target Tracking
	var live_stars: int = 3
	var star_target_sub: String = ""
	if save_mgr and save_mgr.has_method("get_star_targets"):
		var targets: Dictionary = save_mgr.get_star_targets(current_level_index)
		var cur_moves: int = grid.moves_count if grid != null else 0
		var s3: int = targets.get("three_star", targets.get("star_3", 999))
		var s2: int = targets.get("two_star", targets.get("star_2", 999))
		if cur_moves <= s3:
			live_stars = 3
			star_target_sub = " (≤%d)" % s3
		elif cur_moves <= s2:
			live_stars = 2
			star_target_sub = " (≤%d)" % s2
		else:
			live_stars = 1
			star_target_sub = ""

	if star_gauge != null:
		match live_stars:
			3:
				star_gauge.text = "★★★"
				star_gauge.modulate = Color(1.0, 0.85, 0.25)
			2:
				star_gauge.text = "★★☆"
				star_gauge.modulate = Color(0.95, 0.72, 0.20)
			_:
				star_gauge.text = "★☆☆"
				star_gauge.modulate = Color(0.85, 0.65, 0.35)

		# Star change juicing animation
		if live_stars < _prev_live_stars and star_gauge.is_inside_tree():
			star_gauge.pivot_offset = star_gauge.size / 2.0
			var tw_sg: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			star_gauge.scale = Vector2(1.35, 1.35)
			tw_sg.tween_property(star_gauge, "scale", Vector2.ONE, 0.30)
			add_trauma(0.12)
			if audio_mgr and audio_mgr.has_method("play_bump"):
				audio_mgr.play_bump()
		elif live_stars > _prev_live_stars and star_gauge.is_inside_tree():
			star_gauge.pivot_offset = star_gauge.size / 2.0
			var tw_sg: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			star_gauge.scale = Vector2(1.25, 1.25)
			tw_sg.tween_property(star_gauge, "scale", Vector2.ONE, 0.20)

	_prev_live_stars = live_stars

	if loc_mgr:
		level_label.text = loc_mgr.tr_text("GAME_LEVEL_LABEL", [current_level_index + 1, level_paths.size()])
		stats_label.text = "%s%s   •   %s%s" % [
			loc_mgr.tr_text("GAME_MOVES", [grid.moves_count]),
			star_target_sub,
			loc_mgr.tr_text("GAME_PUSHES", [grid.pushes_count]),
			best_str
		]
		if restart_button != null:
			restart_button.text = loc_mgr.tr_text("BTN_RESTART")
		if undo_button != null:
			undo_button.text = loc_mgr.tr_text("BTN_UNDO")
		_update_hint_button_text()
		if prev_button != null:
			prev_button.text = loc_mgr.tr_text("BTN_PREV")
		if next_button != null:
			next_button.text = loc_mgr.tr_text("BTN_NEXT")
		if win_menu_button != null:
			win_menu_button.text = loc_mgr.tr_text("WIN_MENU_BTN")
		if next_level_button != null:
			next_level_button.text = loc_mgr.tr_text("WIN_NEXT_BTN")
		if win_retry_button != null:
			win_retry_button.text = loc_mgr.tr_text("WIN_RETRY_BTN")
	else:
		level_label.text = "LEVEL %d / %d" % [current_level_index + 1, level_paths.size()]
		stats_label.text = "MOVES: %d%s   •   PUSHES: %d%s" % [grid.moves_count, star_target_sub, grid.pushes_count, best_str]
		if undo_button != null:
			undo_button.text = "Undo"
		if restart_button != null:
			restart_button.text = "Restart"
		if prev_button != null:
			prev_button.text = "Prev"
		if next_button != null:
			next_button.text = "Next"
		_update_hint_button_text()
		if win_menu_button != null:
			win_menu_button.text = "MENU"
		if next_level_button != null:
			next_level_button.text = "NEXT"
		if win_retry_button != null:
			win_retry_button.text = "RETRY"

	if undo_button != null:
		undo_button.disabled = (grid == null or not grid.can_undo())
	if hint_button != null:
		hint_button.disabled = (grid == null or grid.is_won())
	if prev_button != null:
		prev_button.disabled = (current_level_index == 0)
	var can_advance: bool = (current_level_index < level_paths.size() - 1)
	if save_mgr:
		can_advance = can_advance and save_mgr.is_level_unlocked(current_level_index + 1)
	if next_button != null:
		next_button.disabled = not can_advance

	# Numeric pop animation on moves counter
	if grid != null and grid.moves_count > _last_hud_moves:
		_last_hud_moves = grid.moves_count
		if stats_label != null and stats_label.is_inside_tree():
			stats_label.pivot_offset = stats_label.size / 2.0
			var pop_tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stats_label.scale = Vector2(1.14, 1.14)
			pop_tw.tween_property(stats_label, "scale", Vector2.ONE, 0.16)
	elif grid != null and grid.moves_count < _last_hud_moves:
		_last_hud_moves = grid.moves_count


func _on_player_moved(from_pos: Vector2i, to_pos: Vector2i) -> void:
	consecutive_wall_bumps = 0
	player_idle_time = 0.0
	_update_ui()
	_animate_player(from_pos, to_pos)
	if not grid.last_move_pushed_crate and audio_mgr:
		audio_mgr.play_move()


func _on_crate_pushed(from_pos: Vector2i, to_pos: Vector2i) -> void:
	_animate_crate(from_pos, to_pos)
	_spawn_push_dust(from_pos, to_pos)
	add_trauma(0.24)
	if grid != null and grid.goals.has(to_pos):
		_spawn_goal_effect(to_pos)
		add_trauma(0.38)
		if audio_mgr:
			if audio_mgr.has_method("play_goal_lock"):
				audio_mgr.play_goal_lock()
			else:
				audio_mgr.play_push()
	else:
		if audio_mgr:
			audio_mgr.play_push()

	if haptic_mgr:
		if grid != null and grid.goals.has(to_pos):
			haptic_mgr.vibrate_target()
		else:
			haptic_mgr.vibrate_push()

	if save_mgr:
		save_mgr.record_crate_push()
	_check_achievements()


func _on_level_won() -> void:
	is_level_won = true

	# 1. Authentic Hit-Stop Freeze-Frame (Micro-pause right as final crate snaps into goal)
	if is_inside_tree():
		await get_tree().create_timer(0.075).timeout

	# 2. Explosive screen shake and radiance rings
	add_trauma(0.60)

	# Trigger joyous worker celebration hops
	player_celebration_hop = 0.0
	var tw_hop: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_hop.tween_property(self, "player_celebration_hop", -24.0, 0.16)
	tw_hop.set_ease(Tween.EASE_IN)
	tw_hop.tween_property(self, "player_celebration_hop", 0.0, 0.14)
	tw_hop.set_ease(Tween.EASE_OUT)
	tw_hop.tween_property(self, "player_celebration_hop", -15.0, 0.14)
	tw_hop.set_ease(Tween.EASE_IN)
	tw_hop.tween_property(self, "player_celebration_hop", 0.0, 0.12)

	# Spawn radiant victory shockwave rings on every goal
	victory_radiance_rings.clear()
	if grid and not grid.goals.is_empty():
		for goal_pos in grid.goals.keys():
			var center_pt: Vector2 = grid_origin + Vector2(goal_pos) * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
			victory_radiance_rings.append({
				"pos": center_pt,
				"radius": tile_size * 0.25,
				"max_radius": tile_size * 2.5,
				"life": 0.85,
				"max_life": 0.85,
				"color": Color(1.0, 0.88, 0.30)
			})

	if audio_mgr:
		audio_mgr.play_win()
	if haptic_mgr:
		haptic_mgr.vibrate_win()
	if save_mgr:
		save_mgr.record_level_completion(current_level_index, grid.moves_count, grid.pushes_count)
	_check_achievements()
	if ad_mgr:
		ad_mgr.record_level_completed(current_level_index)

	_spawn_celebration_particles()
	_update_ui()

	# Delay win popup slightly so player sees the celebration burst and crate snap to goal
	await get_tree().create_timer(0.35).timeout
	var elapsed_ms: int = Time.get_ticks_msec() - level_start_time
	var elapsed_sec: int = maxi(int(elapsed_ms / 1000.0), 1)
	var time_formatted: String = "%02d:%02d" % [int(elapsed_sec / 60.0), elapsed_sec % 60]

	var earned_stars: int = save_mgr.calculate_stars(current_level_index, grid.moves_count) if save_mgr else 1
	var star_targets: Dictionary = save_mgr.get_star_targets(current_level_index) if (save_mgr and save_mgr.has_method("get_star_targets")) else { "optimal": 10, "three_star": 12, "two_star": 15 }
	var optimal_moves: int = star_targets.get("optimal", 10)
	var three_star_target: int = star_targets.get("three_star", optimal_moves + 2)

	# Populate card stats
	var moves_card = win_modal.find_child("MovesCard", true, false) if win_modal else null
	var time_card = win_modal.find_child("TimeCard", true, false) if win_modal else null
	var pushes_card = win_modal.find_child("PushesCard", true, false) if win_modal else null

	var moves_val_lbl = moves_card.find_child("Val", true, false) if moves_card else null
	var time_val_lbl = time_card.find_child("Val", true, false) if time_card else null
	var pushes_val_lbl = pushes_card.find_child("Val", true, false) if pushes_card else null

	var moves_title_lbl = moves_card.find_child("Title", true, false) if moves_card else null
	var time_title_lbl = time_card.find_child("Title", true, false) if time_card else null
	var pushes_title_lbl = pushes_card.find_child("Title", true, false) if pushes_card else null

	if moves_val_lbl: moves_val_lbl.text = str(grid.moves_count)
	if time_val_lbl: time_val_lbl.text = time_formatted
	if pushes_val_lbl: pushes_val_lbl.text = str(grid.pushes_count)

	if level_placard_label:
		level_placard_label.text = "LEVEL %d" % [current_level_index + 1]

	if loc_mgr:
		if moves_title_lbl: moves_title_lbl.text = loc_mgr.tr_text("STAT_MOVES_TITLE")
		if time_title_lbl: time_title_lbl.text = loc_mgr.tr_text("STAT_TIME_TITLE")
		if pushes_title_lbl: pushes_title_lbl.text = loc_mgr.tr_text("STAT_PUSHES_TITLE")
		if win_title: win_title.text = loc_mgr.tr_text("WIN_BANNER")
		if win_menu_button: win_menu_button.text = loc_mgr.tr_text("WIN_MENU_BTN")
		if win_retry_button: win_retry_button.text = loc_mgr.tr_text("WIN_RETRY_BTN")
		if next_level_button:
			if current_level_index >= level_paths.size() - 1:
				next_level_button.text = loc_mgr.tr_text("BTN_CAMPAIGN_COMPLETE")
			else:
				next_level_button.text = loc_mgr.tr_text("WIN_NEXT_BTN")
		if win_stats: win_stats.text = loc_mgr.tr_text("WIN_TARGET_HINT", [three_star_target])
	else:
		if win_title: win_title.text = "LEVEL COMPLETED!"
		if win_menu_button: win_menu_button.text = "MENU"
		if win_retry_button: win_retry_button.text = "RETRY"
		if next_level_button:
			if current_level_index >= level_paths.size() - 1:
				next_level_button.text = "Finish Campaign"
			else:
				next_level_button.text = "NEXT"
		if win_stats: win_stats.text = "Target: ≤ %d moves" % three_star_target

	# Prepare stars in unlit state
	var stars: Array = [star_1, star_2, star_3]
	var dim_color: Color = Color(0.38, 0.40, 0.48, 0.55)
	var gold_color: Color = Color(1.0, 0.88, 0.22, 1.0)
	for s in stars:
		if s:
			s.modulate = dim_color
			s.scale = Vector2.ONE
			var s_sz: Vector2 = s.custom_minimum_size if s.custom_minimum_size != Vector2.ZERO else s.size
			s.pivot_offset = s_sz / 2.0

	if win_blur_overlay:
		win_blur_overlay.modulate.a = 0.0
		win_blur_overlay.show()
		var tw_blur: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_blur.tween_property(win_blur_overlay, "modulate:a", 1.0, 0.25)

	win_modal.pivot_offset = win_modal.size / 2.0
	win_modal.scale = Vector2(0.88, 0.88)
	win_modal.show()
	var tw_modal: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_modal.tween_property(win_modal, "scale", Vector2.ONE, 0.24)
	_animate_stars_sequence(stars, earned_stars, gold_color)


func _animate_stars_sequence(stars: Array, earned: int, gold_color: Color) -> void:
	for i in range(mini(earned, stars.size())):
		var s = stars[i]
		if s == null:
			continue
		var star_num: int = i + 1
		var delay: float = 0.22 + float(i) * 0.28
		var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(delay)
		tw.tween_callback(func():
			s.modulate = gold_color
			var s_sz: Vector2 = s.size if s.size != Vector2.ZERO else s.custom_minimum_size
			s.pivot_offset = s_sz / 2.0
			s.scale = Vector2(1.50, 1.50)
			if audio_mgr:
				audio_mgr.play_star(star_num)
			if haptic_mgr:
				haptic_mgr.vibrate_target()
			_spawn_star_burst(s.get_global_rect().get_center())
		)
		tw.tween_property(s, "scale", Vector2.ONE, 0.24)


func _on_level_reset() -> void:
	current_walk_frame = 0
	walk_step_count = 0
	clear_hint()
	is_level_won = false
	player_celebration_hop = 0.0
	victory_radiance_rings.clear()
	star_burst_particles.clear()
	win_particles.clear()
	visual_player_pos = Vector2(grid.get_player_pos())
	visual_crates.clear()
	for crate_pos in grid.crates.keys():
		visual_crates[crate_pos] = Vector2(crate_pos)
	_update_ui()
	queue_redraw()


func _animate_player(from_pos: Vector2i, to_pos: Vector2i) -> void:
	is_animating = true
	walk_step_count += 1
	var step_base: int = 1 if (walk_step_count % 2 == 1) else 2
	current_walk_frame = step_base
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	visual_player_pos = Vector2(from_pos)
	tween.tween_method(func(pos: Vector2):
		visual_player_pos = pos
		var dist: float = pos.distance_to(Vector2(from_pos))
		if dist > 0.5:
			current_walk_frame = 2 if step_base == 1 else 1
		else:
			current_walk_frame = step_base
		queue_redraw()
	, Vector2(from_pos), Vector2(to_pos), 0.12)
	tween.tween_callback(func():
		is_animating = false
		current_walk_frame = 0
		visual_player_pos = Vector2(to_pos)
		queue_redraw()
		# Process queued move if one was buffered during animation (PRD Section 5)
		if queued_move_dir != Vector2i.ZERO:
			var dir_to_run: Vector2i = queued_move_dir
			queued_move_dir = Vector2i.ZERO
			try_move(dir_to_run)
	)


func _animate_crate(from_pos: Vector2i, to_pos: Vector2i) -> void:
	visual_crates.erase(from_pos)
	visual_crates[to_pos] = Vector2(from_pos)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(val: Vector2):
		visual_crates[to_pos] = val
		queue_redraw()
	, Vector2(from_pos), Vector2(to_pos), 0.12)

	# Squash & stretch deformation along push axis (Option A: Juicy Magnetic Goal Snap)
	var push_dir: Vector2i = to_pos - from_pos
	var is_entering_goal: bool = (grid != null and grid.goals.has(to_pos))

	var squash_start: Vector2
	if is_entering_goal:
		squash_start = Vector2(1.24, 0.78) if push_dir.x != 0 else Vector2(0.78, 1.24)
	else:
		squash_start = Vector2(0.86, 1.14) if push_dir.x != 0 else Vector2(1.14, 0.86)

	crate_squash[to_pos] = squash_start
	var sq_tw: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	sq_tw.tween_method(func(s: Vector2):
		crate_squash[to_pos] = s
		queue_redraw()
	, squash_start, Vector2.ONE, 0.28 if is_entering_goal else 0.22)


func try_move(dir: Vector2i) -> void:
	player_facing_dir = dir
	clear_hint()
	if win_modal != null and win_modal.visible:
		return

	if is_animating:
		# PRD Section 5: "A swipe made during a move animation is queued (one move only)."
		queued_move_dir = dir
		return

	if grid != null:
		var moved: bool = grid.move(dir)
		if not moved:
			_trigger_bump_recoil(dir)


func _trigger_bump_recoil(dir: Vector2i) -> void:
	if is_animating:
		return
	add_trauma(0.14)
	consecutive_wall_bumps += 1
	if consecutive_wall_bumps >= 3:
		trigger_sweat_drop()

	if haptic_mgr and haptic_mgr.has_method("vibrate_bump"):
		haptic_mgr.vibrate_bump()
	elif haptic_mgr and haptic_mgr.has_method("vibrate_click"):
		haptic_mgr.vibrate_click()

	if audio_mgr and audio_mgr.has_method("play_bump"):
		audio_mgr.play_bump()
	elif audio_mgr and audio_mgr.has_method("play_click"):
		audio_mgr.play_click()

	var recoil_vec: Vector2 = Vector2(dir) * 4.5
	bump_offset = recoil_vec
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "bump_offset", Vector2.ZERO, 0.11)
	tw.tween_callback(queue_redraw)


func trigger_sweat_drop() -> void:
	sweat_drop_timer = 1.4
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if win_modal != null and win_modal.visible:
		return

	# Keyboard navigation (Desktop / Testing) with Rapid Rewind on Hold
	if event is InputEventKey:
		if event.keycode in [KEY_Z, KEY_U, KEY_BACKSPACE]:
			if event.is_pressed() and not event.is_echo():
				is_undo_held = true
				undo_hold_time = 0.0
				undo_step_timer = 0.0
				_on_undo_pressed()
			elif not event.is_pressed():
				is_undo_held = false
				undo_hold_time = 0.0
				undo_step_timer = 0.0
		elif event.is_pressed() and not event.is_echo():
			match event.keycode:
				KEY_UP, KEY_W:
					try_move(Vector2i.UP)
				KEY_DOWN, KEY_S:
					try_move(Vector2i.DOWN)
				KEY_LEFT, KEY_A:
					try_move(Vector2i.LEFT)
				KEY_RIGHT, KEY_D:
					try_move(Vector2i.RIGHT)
				KEY_R:
					_on_restart_pressed()

	# Touch & Mouse swipe detection (PRD Section 5)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_touching = true
				touch_start_pos = event.position
			else:
				if is_touching:
					var release_delta: Vector2 = event.position - touch_start_pos
					if release_delta.length() >= SWIPE_THRESHOLD_PIXELS:
						_handle_swipe(release_delta)
					is_touching = false

	elif event is InputEventScreenTouch:
		if event.pressed:
			is_touching = true
			touch_start_pos = event.position
		else:
			if is_touching:
				var release_delta: Vector2 = event.position - touch_start_pos
				if release_delta.length() >= SWIPE_THRESHOLD_PIXELS:
					_handle_swipe(release_delta)
				is_touching = false

	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and is_touching):
		if is_touching:
			var drag_delta: Vector2 = event.position - touch_start_pos
			if drag_delta.length() >= SWIPE_THRESHOLD_PIXELS:
				_handle_swipe(drag_delta)
				touch_start_pos = event.position


func _handle_swipe(delta: Vector2) -> void:
	if save_mgr and "control_scheme" in save_mgr and save_mgr.control_scheme == 1:
		return # Swipe disabled when D-PAD only mode is active
	if delta.length() < SWIPE_THRESHOLD_PIXELS:
		return # Ignore taps and tiny movements (PRD Section 5)

	# Dominant axis decides direction (PRD Section 5)
	if abs(delta.x) > abs(delta.y):
		if delta.x > 0:
			try_move(Vector2i.RIGHT)
		else:
			try_move(Vector2i.LEFT)
	else:
		if delta.y > 0:
			try_move(Vector2i.DOWN)
		else:
			try_move(Vector2i.UP)


func _on_restart_pressed() -> void:
	if win_modal != null and win_modal.visible:
		return
	# PRD Section 5: "After 5 or more moves, Restart asks for one confirmation tap."
	var current_moves: int = grid.moves_count if grid != null else 0
	if current_moves >= 5:
		if loc_mgr:
			restart_dialog.dialog_text = loc_mgr.tr_text("RESTART_CONFIRM", [current_moves])
		else:
			restart_dialog.dialog_text = "You've made %d moves. Restart this level?" % current_moves
		if audio_mgr and audio_mgr.has_method("duck_music"):
			audio_mgr.duck_music(-10.0, 0.2)
		if restart_dialog.is_inside_tree():
			restart_dialog.popup_centered()
	else:
		_do_restart()


func _do_restart() -> void:
	if audio_mgr:
		audio_mgr.play_restart()
		if audio_mgr.has_method("unduck_music"):
			audio_mgr.unduck_music(0.5)
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if grid:
		grid.restart()


func _on_restart_dialog_canceled() -> void:
	if audio_mgr and audio_mgr.has_method("unduck_music"):
		audio_mgr.unduck_music(0.5)


func _on_music_btn_pressed() -> void:
	if audio_mgr != null and audio_mgr.has_method("is_music_enabled"):
		var cur_on: bool = audio_mgr.is_music_enabled()
		audio_mgr.set_music_enabled(not cur_on)
		if audio_mgr.has_method("play_click"):
			audio_mgr.play_click()
	elif save_mgr != null and "music_enabled" in save_mgr:
		save_mgr.music_enabled = not save_mgr.music_enabled
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()
	if haptic_mgr != null and haptic_mgr.has_method("vibrate_click"):
		haptic_mgr.vibrate_click()
	_update_music_button_ui()


func _update_music_button_ui() -> void:
	if music_button == null:
		return
	var is_on: bool = true
	if audio_mgr != null and audio_mgr.has_method("is_music_enabled"):
		is_on = audio_mgr.is_music_enabled()
	elif save_mgr != null and "music_enabled" in save_mgr:
		is_on = save_mgr.music_enabled
	music_button.text = ""
	music_button.icon = icon_music_on if is_on else icon_music_off
	music_button.expand_icon = true
	music_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_button.modulate = Color.WHITE


func _on_control_button_pressed() -> void:
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
	_update_control_scheme_ui()
	calculate_layout()
	queue_redraw()


func _update_control_scheme_ui() -> void:
	var scheme: int = save_mgr.control_scheme if save_mgr and "control_scheme" in save_mgr else 0
	# 0 = Swipe, 1 = D-Pad, 2 = Dual
	var show_dpad: bool = (scheme == 1 or scheme == 2)
	if dpad_overlay:
		dpad_overlay.visible = show_dpad
	if control_button:
		control_button.modulate = Color.WHITE
		control_button.expand_icon = true
		control_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		control_button.text = ""
		match scheme:
			0:
				control_button.icon = icon_control_swipe
			1:
				control_button.icon = icon_control_dpad
			2:
				control_button.icon = icon_control_gamepad


func _on_dpad_up_pressed() -> void:
	try_move(Vector2i.UP)


func _on_dpad_down_pressed() -> void:
	try_move(Vector2i.DOWN)


func _on_dpad_left_pressed() -> void:
	try_move(Vector2i.LEFT)


func _on_dpad_right_pressed() -> void:
	try_move(Vector2i.RIGHT)


func _on_undo_button_down() -> void:
	is_undo_held = true
	undo_hold_time = 0.0
	undo_step_timer = 0.0


func _on_undo_button_up() -> void:
	is_undo_held = false
	undo_hold_time = 0.0
	undo_step_timer = 0.0


func _on_undo_pressed() -> void:
	if win_modal != null and win_modal.visible:
		return
	is_animating = false
	queued_move_dir = Vector2i.ZERO
	clear_hint()
	if grid != null and grid.can_undo():
		if audio_mgr:
			audio_mgr.play_click()
		if haptic_mgr:
			haptic_mgr.vibrate_click()
		grid.undo()


func _on_move_undone(p_pos: Vector2i, _had_crate: bool, _crate_from: Vector2i, _crate_to: Vector2i) -> void:
	is_animating = false
	queued_move_dir = Vector2i.ZERO
	current_walk_frame = 0
	clear_hint()
	visual_player_pos = Vector2(p_pos)
	visual_crates.clear()
	for crate_pos in grid.crates.keys():
		visual_crates[crate_pos] = Vector2(crate_pos)
	_update_ui()
	queue_redraw()


func _on_hint_pressed() -> void:
	if is_animating:
		return
	if win_modal != null and win_modal.visible:
		return
	if grid == null or grid.is_won():
		return

	# Check hint inventory (Phase 4: Rewarded Ad Hint Economy)
	if save_mgr != null and save_mgr.get_hints_remaining() <= 0:
		if audio_mgr:
			audio_mgr.play_click()
		_show_ad_reward_modal()
		return

	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()

	var move_char: String = ""
	var is_confirmed_deadlock: bool = false

	# 1. Fast check if current state matches the level's verified optimal path (instant 0ms lookup)
	var lvl_path: String = level_paths[current_level_index] if current_level_index < level_paths.size() else ""
	var path_hint: String = SokobanSolverScript.get_next_hint(grid, current_level_index, lvl_path)
	if not path_hint.is_empty():
		move_char = path_hint
	else:
		# 2. Check if player has placed a crate into an immediate unresolvable deadlock
		if grid.has_deadlock():
			is_confirmed_deadlock = true
		else:
			# 3. High-speed solver search for custom player paths
			var result: SokobanSolver.SolverResult = SokobanSolverScript.solve(grid, 15000)
			if result.is_solvable and not result.solution_str.is_empty():
				move_char = result.solution_str.substr(0, 1)
			elif result.is_deadlock:
				is_confirmed_deadlock = true

	if move_char.is_empty():
		# Deadlock or search limit reached
		if audio_mgr:
			if audio_mgr.has_method("play_deadlock"):
				audio_mgr.play_deadlock()
			elif audio_mgr.has_method("play_bump"):
				audio_mgr.play_bump()
		if haptic_mgr:
			if haptic_mgr.has_method("vibrate_impact"):
				haptic_mgr.vibrate_impact()
			elif haptic_mgr.has_method("vibrate_bump"):
				haptic_mgr.vibrate_bump()
		add_trauma(0.25)
		if is_confirmed_deadlock:
			_show_hint_toast(loc_mgr.tr_text("HINT_DEADLOCK") if loc_mgr else "No solution from here! Tap Undo", Color(1.0, 0.4, 0.4))
		else:
			_show_hint_toast(loc_mgr.tr_text("HINT_NO_PATH") if loc_mgr else "No clear path found. Try another move or Undo", Color(1.0, 0.7, 0.4))
		# Clear ghost trajectory without hiding the toast message
		active_hint_dir = Vector2i.ZERO
		hint_time_remaining = 0.0
		hint_has_crate = false
		queue_redraw()
		return

	# Deduct 1 hint from inventory only when solution step was found
	if save_mgr != null:
		save_mgr.use_hint()
		_update_hint_button_text()

	# Solvable next step
	if audio_mgr:
		audio_mgr.play_hint()
	match move_char:
		"u": active_hint_dir = Vector2i.UP
		"d": active_hint_dir = Vector2i.DOWN
		"l": active_hint_dir = Vector2i.LEFT
		"r": active_hint_dir = Vector2i.RIGHT
		_: active_hint_dir = Vector2i.ZERO

	if active_hint_dir == Vector2i.ZERO:
		return

	hint_player_target = grid.player_pos + active_hint_dir
	hint_has_crate = grid.has_crate(hint_player_target)
	hint_crate_target = (hint_player_target + active_hint_dir) if hint_has_crate else Vector2i.ZERO
	hint_time_remaining = 4.0 # Active for 4 seconds
	hint_pulse_timer = 0.0

	var dir_key: String = "UP"
	if active_hint_dir == Vector2i.DOWN: dir_key = "DOWN"
	elif active_hint_dir == Vector2i.LEFT: dir_key = "LEFT"
	elif active_hint_dir == Vector2i.RIGHT: dir_key = "RIGHT"

	var toast_msg: String = loc_mgr.tr_text("HINT_STEP_" + dir_key) if loc_mgr else ("Hint: Move " + dir_key)
	_show_hint_toast(toast_msg, Color(1.0, 0.95, 0.6))
	queue_redraw()


func _show_hint_toast(msg: String, color: Color = Color(1.0, 0.95, 0.6)) -> void:
	if hint_toast == null or hint_toast_label == null:
		return
	hint_toast_label.text = msg
	hint_toast_label.modulate = color
	hint_toast.modulate.a = 0.0
	hint_toast.show()
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hint_toast, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.2)
	tw.tween_property(hint_toast, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if hint_toast:
			hint_toast.hide()
	)


func clear_hint() -> void:
	active_hint_dir = Vector2i.ZERO
	hint_time_remaining = 0.0
	if hint_toast != null:
		hint_toast.hide()
	queue_redraw()


func _on_prev_level_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if current_level_index > 0:
		load_level(current_level_index - 1)


func _on_next_level_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()

	# If completing the final level (Level 50), navigate to the Campaign End Screen (PRD Section 6)
	if current_level_index >= level_paths.size() - 1:
		get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
		return

	var next_idx: int = current_level_index + 1
	if not save_mgr or save_mgr.is_level_unlocked(next_idx):
		if ad_mgr and ad_mgr.should_show_interstitial(current_level_index):
			ad_mgr.show_interstitial(current_level_index)
			if ad_mgr.is_showing_ad:
				# Await ad close with safety timeout guard so level advance is never hung
				var safety_timer: SceneTreeTimer = get_tree().create_timer(10.0)
				var ad_done: Array[bool] = [false]
				var on_closed: Callable = func() -> void:
					ad_done[0] = true
				ad_mgr.interstitial_closed.connect(on_closed, CONNECT_ONE_SHOT)
				safety_timer.timeout.connect(on_closed, CONNECT_ONE_SHOT)
				while not ad_done[0] and is_inside_tree():
					await get_tree().process_frame
		load_level(next_idx)


func _on_win_retry_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if win_modal != null:
		win_modal.hide()
	if win_blur_overlay != null:
		win_blur_overlay.hide()
	load_level(current_level_index)


func _on_menu_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
		if audio_mgr.has_method("unduck_music"):
			audio_mgr.unduck_music(0.5)
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _spawn_celebration_particles() -> void:
	win_particles.clear()
	var palette: Array[Color] = [
		Color(1.0, 0.84, 0.20), # Gold
		Color(0.20, 0.88, 0.40), # Emerald
		Color(0.95, 0.25, 0.30), # Ruby
		Color(0.30, 0.75, 1.00), # Sky / Diamond
		Color(1.0, 0.95, 0.85), # Warm Pearl
		Color(1.0, 0.58, 0.18), # Amber
		Color(0.88, 0.40, 1.00)  # Violet
	]

	var spawn_points: Array[Vector2] = []
	if grid and not grid.goals.is_empty():
		for goal_pos in grid.goals.keys():
			var pt: Vector2 = grid_origin + Vector2(goal_pos) * tile_size + Vector2(tile_size / 2.0, tile_size / 2.0)
			spawn_points.append(pt)

	if spawn_points.is_empty():
		spawn_points.append(size / 2.0 if size != Vector2.ZERO else Vector2(360, 640))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	# 1. Fountain bursts from goal pads
	for origin_pt in spawn_points:
		for i in range(12):
			var angle: float = rng.randf_range(-PI * 0.92, -PI * 0.08)
			var speed: float = rng.randf_range(180.0, 480.0)
			var p_color: Color = palette[rng.randi() % palette.size()]
			var p_size: float = rng.randf_range(6.0, 11.0)
			var life: float = rng.randf_range(1.4, 2.4)
			var p_type: String = "star" if (i % 3 == 0) else "ribbon"

			win_particles.append({
				"type": p_type,
				"pos": origin_pt + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)),
				"vel": Vector2(cos(angle), sin(angle)) * speed,
				"color": p_color,
				"size": p_size,
				"life": life,
				"max_life": life,
				"rot": rng.randf_range(0.0, TAU),
				"vrot": rng.randf_range(-6.0, 6.0),
				"sway_phase": rng.randf_range(0.0, TAU),
				"sway_speed": rng.randf_range(4.0, 9.0),
				"sway_amount": rng.randf_range(25.0, 60.0)
			})

	# 2. Dual bottom-corner confetti cannons
	var vp_w: float = size.x if size.x > 0 else 720.0
	var vp_h: float = size.y if size.y > 0 else 1280.0
	var left_cannon: Vector2 = Vector2(0.0, vp_h)
	var right_cannon: Vector2 = Vector2(vp_w, vp_h)

	for i in range(20):
		# Left cannon fires up-right
		var angle_l: float = rng.randf_range(-PI * 0.45, -PI * 0.15)
		var speed_l: float = rng.randf_range(500.0, 840.0)
		var p_color_l: Color = palette[rng.randi() % palette.size()]
		var life_l: float = rng.randf_range(1.8, 2.8)
		win_particles.append({
			"type": "ribbon" if (i % 2 == 0) else "star",
			"pos": left_cannon + Vector2(rng.randf_range(0, 30), rng.randf_range(-10, 10)),
			"vel": Vector2(cos(angle_l), sin(angle_l)) * speed_l,
			"color": p_color_l,
			"size": rng.randf_range(7.0, 13.0),
			"life": life_l,
			"max_life": life_l,
			"rot": rng.randf_range(0.0, TAU),
			"vrot": rng.randf_range(-7.0, 7.0),
			"sway_phase": rng.randf_range(0.0, TAU),
			"sway_speed": rng.randf_range(5.0, 10.0),
			"sway_amount": rng.randf_range(30.0, 75.0)
		})

		# Right cannon fires up-left
		var angle_r: float = rng.randf_range(-PI * 0.85, -PI * 0.55)
		var speed_r: float = rng.randf_range(500.0, 840.0)
		var p_color_r: Color = palette[rng.randi() % palette.size()]
		var life_r: float = rng.randf_range(1.8, 2.8)
		win_particles.append({
			"type": "ribbon" if (i % 2 == 0) else "star",
			"pos": right_cannon + Vector2(rng.randf_range(-30, 0), rng.randf_range(-10, 10)),
			"vel": Vector2(cos(angle_r), sin(angle_r)) * speed_r,
			"color": p_color_r,
			"size": rng.randf_range(7.0, 13.0),
			"life": life_r,
			"max_life": life_r,
			"rot": rng.randf_range(0.0, TAU),
			"vrot": rng.randf_range(-7.0, 7.0),
			"sway_phase": rng.randf_range(0.0, TAU),
			"sway_speed": rng.randf_range(5.0, 10.0),
			"sway_amount": rng.randf_range(30.0, 75.0)
		})


func _spawn_star_burst(center_pt: Vector2) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(14):
		var angle: float = rng.randf_range(0.0, TAU)
		var speed: float = rng.randf_range(70.0, 220.0)
		var life: float = rng.randf_range(0.35, 0.65)
		var col: Color = Color(1.0, rng.randf_range(0.82, 0.98), rng.randf_range(0.20, 0.40))
		star_burst_particles.append({
			"pos": center_pt,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": life,
			"max_life": life,
			"size": rng.randf_range(3.5, 6.5),
			"color": col
		})


func _process(delta: float) -> void:
	var needs_redraw: bool = is_animating

	# Option A: Continuous Rapid Rewind when Undo is held down
	if is_undo_held and (win_modal == null or not win_modal.visible):
		undo_hold_time += delta
		if undo_hold_time >= 0.30: # 300ms hold threshold
			undo_step_timer += delta
			if undo_step_timer >= 0.085: # Rewind 1 step every 85ms (~12 moves/sec)
				undo_step_timer = 0.0
				if grid != null and grid.can_undo():
					if audio_mgr and audio_mgr.has_method("play_click"):
						audio_mgr.play_click()
					if haptic_mgr and haptic_mgr.has_method("vibrate_click"):
						haptic_mgr.vibrate_click()
					grid.undo()
				else:
					is_undo_held = false

	# Update hint ghost timer
	if hint_time_remaining > 0.0:
		needs_redraw = true
		hint_time_remaining -= delta
		hint_pulse_timer += delta
		if hint_time_remaining <= 0.0:
			clear_hint()

	# Subtle continuous breathing pulse for goals
	if grid and not grid.goals.is_empty():
		needs_redraw = true

	# Update board trauma & shake
	if board_trauma > 0.0:
		board_trauma = max(0.0, board_trauma - delta * 4.2)
		var shake_mag: float = board_trauma * board_trauma * 7.5
		var a: float = randf() * TAU
		board_shake_offset = Vector2(cos(a), sin(a)) * shake_mag
		needs_redraw = true
	else:
		board_shake_offset = Vector2.ZERO

	# Update dust particles
	if not dust_particles.is_empty():
		needs_redraw = true
		var di: int = dust_particles.size() - 1
		while di >= 0:
			var dp: Dictionary = dust_particles[di]
			dp["life"] -= delta
			if dp["life"] <= 0.0:
				dust_particles.remove_at(di)
			else:
				dp["pos"] += dp["vel"] * delta
				dp["vel"] *= (1.0 - 5.0 * delta)
				dp["size"] += 2.0 * delta
			di -= 1

	# Option B: Update floating ambient warehouse motes
	if not ambient_motes.is_empty() and (win_modal == null or not win_modal.visible):
		needs_redraw = true
		for mote in ambient_motes:
			mote["phase"] += delta * 1.35 * mote.get("speed_mult", 1.0)
			var drift: Vector2 = mote["vel"] + Vector2(cos(mote["phase"]) * 0.006, sin(mote["phase"] * 0.8) * 0.005)
			mote["pos_norm"] += drift * delta
			if mote["pos_norm"].x < -0.05:
				mote["pos_norm"].x = 1.05
			elif mote["pos_norm"].x > 1.05:
				mote["pos_norm"].x = -0.05
			if mote["pos_norm"].y < -0.05:
				mote["pos_norm"].y = 1.05
			elif mote["pos_norm"].y > 1.05:
				mote["pos_norm"].y = -0.05

	# Option C: Worker Idle Nuance & Thinking Sweat Drop
	if not is_animating and not is_level_won and (win_modal == null or not win_modal.visible):
		player_idle_time += delta
		if player_idle_time >= 10.0 and sweat_drop_timer <= 0.0:
			trigger_sweat_drop()
		if player_idle_time > 2.0:
			needs_redraw = true
	else:
		player_idle_time = 0.0

	if sweat_drop_timer > 0.0:
		sweat_drop_timer -= delta
		needs_redraw = true

	# Update goal shockwaves & sparks
	if not goal_effects.is_empty():
		needs_redraw = true
		var gi: int = goal_effects.size() - 1
		while gi >= 0:
			var ge: Dictionary = goal_effects[gi]
			ge["life"] -= delta
			if ge["life"] <= 0.0:
				goal_effects.remove_at(gi)
			else:
				if ge["type"] == "ring":
					var progress: float = 1.0 - (ge["life"] / ge["max_life"])
					ge["radius"] = lerpf(4.0, ge["max_radius"], progress)
				elif ge["type"] == "spark":
					ge["pos"] += ge["vel"] * delta
					ge["vel"] *= (1.0 - 3.0 * delta)
			gi -= 1

	# Update victory radiant shockwaves
	if not victory_radiance_rings.is_empty():
		needs_redraw = true
		var vi: int = victory_radiance_rings.size() - 1
		while vi >= 0:
			var ring: Dictionary = victory_radiance_rings[vi]
			ring["life"] -= delta
			if ring["life"] <= 0.0:
				victory_radiance_rings.remove_at(vi)
			else:
				var t_prog: float = 1.0 - (ring["life"] / ring["max_life"])
				ring["radius"] = lerpf(tile_size * 0.25, ring["max_radius"], t_prog)
			vi -= 1

	# Update star award burst sparks
	if not star_burst_particles.is_empty():
		needs_redraw = true
		var si: int = star_burst_particles.size() - 1
		while si >= 0:
			var sp: Dictionary = star_burst_particles[si]
			sp["life"] -= delta
			if sp["life"] <= 0.0:
				star_burst_particles.remove_at(si)
			else:
				sp["pos"] += sp["vel"] * delta
				sp["vel"] *= (1.0 - 2.8 * delta)
			si -= 1

	# Update celebration particles with fluttering ribbon sway
	if not win_particles.is_empty():
		needs_redraw = true
		var i: int = win_particles.size() - 1
		while i >= 0:
			var p: Dictionary = win_particles[i]
			p["life"] -= delta
			if p["life"] <= 0.0:
				win_particles.remove_at(i)
			else:
				p["sway_phase"] = p.get("sway_phase", 0.0) + p.get("sway_speed", 5.0) * delta
				p["pos"].x += sin(p["sway_phase"]) * p.get("sway_amount", 40.0) * delta
				p["pos"] += p["vel"] * delta
				p["vel"].y += 320.0 * delta # Gravity
				p["vel"].x *= (1.0 - 0.45 * delta) # Air resistance
				p["rot"] += p["vrot"] * delta
			i -= 1

	if needs_redraw:
		queue_redraw()


func calculate_layout(custom_viewport_size: Vector2 = Vector2.ZERO) -> void:
	if not grid or grid.width == 0 or grid.height == 0:
		return

	var viewport_size: Vector2 = custom_viewport_size if custom_viewport_size != Vector2.ZERO else size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(720.0, 1280.0)

	var insets: Dictionary = safe_area_mgr.get_safe_insets(self) if safe_area_mgr else { "top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0 }
	var safe_top: float = insets.get("top", 0.0)
	var safe_bottom: float = insets.get("bottom", 0.0)
	var safe_horiz: float = insets.get("left", 0.0) + insets.get("right", 0.0)

	var top_offset: float = 96.0 + safe_top
	var dpad_allowance: float = 160.0 if (dpad_overlay and dpad_overlay.visible) else 0.0
	var bottom_offset: float = 70.0 + safe_bottom + dpad_allowance
	var playable_height: float = viewport_size.y - (top_offset + bottom_offset)
	var playable_width: float = viewport_size.x - (36.0 + safe_horiz)

	var max_tile_w: float = playable_width / float(grid.width)
	var max_tile_h: float = playable_height / float(grid.height)
	tile_size = floor(min(max_tile_w, max_tile_h))

	var board_pixel_size: Vector2 = Vector2(grid.width * tile_size, grid.height * tile_size)
	grid_origin = Vector2(
		floor((viewport_size.x - board_pixel_size.x) / 2.0),
		floor(top_offset + (playable_height - board_pixel_size.y) / 2.0)
	)
	_layout_dirty = false


func _draw() -> void:
	if not grid or grid.width == 0 or grid.height == 0:
		return

	if _layout_dirty:
		calculate_layout()
	var effective_origin: Vector2 = grid_origin + board_shake_offset
	var board_pixel_size: Vector2 = Vector2(grid.width * tile_size, grid.height * tile_size)
	var ch: Dictionary = get_current_chapter_theme()

	var is_non_square: bool = is_level_non_square()

	# 1. Industrial Warehouse Loading Bay Board Framing (PRD Section 4 & Phase 2 Themes)
	if is_non_square:
		# Multi-stage cinematic silhouette 2.5D drop shadow under the non-square shape
		for y in range(grid.height):
			for x in range(grid.width):
				var pos: Vector2i = Vector2i(x, y)
				if not grid.is_exterior_void(pos):
					var s_rect: Rect2 = Rect2(effective_origin + Vector2(x, y) * tile_size, Vector2(tile_size, tile_size))
					# Layer 4: Distant soft ambient penumbra
					draw_rect(Rect2(s_rect.position + Vector2(10, 14), s_rect.size + Vector2(8, 8)), Color(0.0, 0.0, 0.0, 0.08))
					# Layer 3: Mid ambient spread
					draw_rect(Rect2(s_rect.position + Vector2(6, 9), s_rect.size + Vector2(4, 4)), Color(0.0, 0.0, 0.0, 0.18))
					# Layer 2: Directional elevation shadow
					draw_rect(Rect2(s_rect.position + Vector2(4, 5), s_rect.size + Vector2(2, 2)), Color(0.0, 0.0, 0.0, 0.32))
					# Layer 1: Tight perimeter contact depth
					draw_rect(Rect2(s_rect.position + Vector2(1, 2), s_rect.size), Color(0.0, 0.0, 0.0, 0.48))
	else:
		var frame_margin: float = 12.0
		var frame_rect: Rect2 = Rect2(
			effective_origin - Vector2(frame_margin, frame_margin),
			board_pixel_size + Vector2(frame_margin * 2.0, frame_margin * 2.0)
		)

		# Multi-stage drop shadow
		draw_rect(Rect2(frame_rect.position + Vector2(10, 14), frame_rect.size + Vector2(6, 6)), Color(0.0, 0.0, 0.0, 0.22))
		draw_rect(Rect2(frame_rect.position + Vector2(6, 9), frame_rect.size + Vector2(3, 3)), Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(Rect2(frame_rect.position + Vector2(2, 3), frame_rect.size), Color(0.0, 0.0, 0.0, 0.60))

		# Heavy chapter frame base
		draw_rect(frame_rect, ch["frame_base"])
		# Polished chapter bevel rim
		draw_rect(frame_rect, ch["frame_rim"], false, 2.5)
		# Inner dark groove
		draw_rect(Rect2(effective_origin - Vector2(2, 2), board_pixel_size + Vector2(4, 4)), ch["frame_groove"], false, 2.0)

		# 4 Corner industrial chapter bolts
		var corner_offsets: Array[Vector2] = [
			Vector2(frame_margin * 0.5, frame_margin * 0.5),
			Vector2(frame_rect.size.x - frame_margin * 0.5, frame_margin * 0.5),
			Vector2(frame_margin * 0.5, frame_rect.size.y - frame_margin * 0.5),
			Vector2(frame_rect.size.x - frame_margin * 0.5, frame_rect.size.y - frame_margin * 0.5)
		]
		for c_offset in corner_offsets:
			var bolt_center: Vector2 = frame_rect.position + c_offset
			draw_circle(bolt_center, 4.5, ch["bolt_dark"])
			draw_circle(bolt_center, 3.5, ch["bolt_core"])
			draw_circle(bolt_center - Vector2(1.0, 1.0), 1.2, ch["bolt_specular"])

	# 2. Draw Floor & Walls with 3D Depth & Chapter Tinting
	for y in range(grid.height):
		for x in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var rect: Rect2 = Rect2(effective_origin + Vector2(x, y) * tile_size, Vector2(tile_size, tile_size))

			if grid.is_wall(pos):
				_draw_wall(rect, pos)
			elif grid.is_interior_floor(pos) or grid.interior_floor.is_empty():
				var is_alt: bool = ((x + y) % 2 == 0)
				var floor_tex: Texture2D = tex_floor_1 if is_alt else tex_floor_2
				draw_texture_rect(floor_tex, rect, false, ch["floor_tint"])

				# Graduated 3D Ambient Depth Shadow: if cell above is a wall, cast soft drop shadow down
				var has_top_wall: bool = (y > 0 and grid.is_wall(Vector2i(x, y - 1)))
				var has_left_wall: bool = (x > 0 and grid.is_wall(Vector2i(x - 1, y)))

				if has_top_wall:
					# Multi-tier shadow gradient from wall base down onto floor
					draw_rect(Rect2(rect.position, Vector2(rect.size.x, tile_size * 0.06)), Color(0.0, 0.0, 0.0, 0.45))
					draw_rect(Rect2(rect.position, Vector2(rect.size.x, tile_size * 0.14)), Color(0.0, 0.0, 0.0, 0.26))
					draw_rect(Rect2(rect.position, Vector2(rect.size.x, tile_size * 0.24)), Color(0.0, 0.0, 0.0, 0.12))

				# Left-wall drop shadow for isometric ambient depth
				if has_left_wall:
					draw_rect(Rect2(rect.position, Vector2(tile_size * 0.05, rect.size.y)), Color(0.0, 0.0, 0.0, 0.36))
					draw_rect(Rect2(rect.position, Vector2(tile_size * 0.12, rect.size.y)), Color(0.0, 0.0, 0.0, 0.20))
					draw_rect(Rect2(rect.position, Vector2(tile_size * 0.20, rect.size.y)), Color(0.0, 0.0, 0.0, 0.08))

				# Deep corner ambient occlusion when flanked by both top and left walls
				if has_top_wall and has_left_wall:
					draw_circle(rect.position, tile_size * 0.22, Color(0.0, 0.0, 0.0, 0.20))
			else:
				# Exterior void tile: only draw for solid rectangular boards (no empty spaces on irregular levels)
				if not is_non_square:
					_draw_exterior_void_tile(rect, pos, ch)

	# 2.2. Slim Level Border along outer perimeter walls (Non-Square Levels)
	if is_non_square:
		_draw_slim_level_border(effective_origin, ch)

	# 2.5. Board Peripheral Vignette (Option B: Soft atmospheric edge darkening for solid rectangular boards)
	if not is_non_square:
		_draw_board_vignette(effective_origin, board_pixel_size)

	# 3. Draw Goals with Chapter Pressure Plate, Hazard Markings & Pulsing Aura (Option B)
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = sin(time_sec * 3.5) * 0.12
	var aura_col_base: Color = ch["goal_aura"]
	var core_col: Color = ch["goal_core"]
	for goal_pos in grid.goals.keys():
		var rect: Rect2 = Rect2(effective_origin + Vector2(goal_pos) * tile_size, Vector2(tile_size, tile_size))
		var center: Vector2 = rect.get_center()
		var has_crate: bool = grid.crates.has(goal_pos)

		if not has_crate:
			# --- Empty Goal: Recessed Industrial Docking Station ---
			var pad_inset: float = tile_size * 0.04
			var pad_rect: Rect2 = rect.grow(-pad_inset)

			# 1. Dark recessed floor plate
			draw_rect(pad_rect, Color(0.09, 0.11, 0.15, 0.72))
			# Inset shadow along top & left interior edges
			draw_line(pad_rect.position, pad_rect.position + Vector2(pad_rect.size.x, 0.0), Color(0.0, 0.0, 0.0, 0.65), 1.8)
			draw_line(pad_rect.position, pad_rect.position + Vector2(0.0, pad_rect.size.y), Color(0.0, 0.0, 0.0, 0.55), 1.8)
			# Subtle specular lip along bottom & right edges
			draw_line(pad_rect.position + Vector2(0.0, pad_rect.size.y), pad_rect.end, Color(0.40, 0.46, 0.54, 0.35), 1.2)
			draw_line(pad_rect.position + Vector2(pad_rect.size.x, 0.0), pad_rect.end, Color(0.40, 0.46, 0.54, 0.35), 1.2)

			# 2. Industrial hazard caution corner brackets on the goal pad
			_draw_goal_hazard_brackets(rect, ch)

			# 3. Integrated goal station graphic (harmonious modulate)
			draw_texture_rect(tex_goal, rect, false, Color(1.0, 0.90, 0.60, 0.74))

			# 4. Pulsing laser reticle & concentric target ring
			var ring_r: float = (tile_size * 0.28) * (1.0 + pulse * 0.35)
			var ring_col: Color = Color(aura_col_base.r, aura_col_base.g, aura_col_base.b, 0.24 + pulse * 0.08)
			draw_arc(center, ring_r, 0.0, TAU, 32, ring_col, 1.5, true)

			# 4-direction alignment crosshair tick marks
			var tick_in: float = tile_size * 0.16
			var tick_out: float = tile_size * 0.32
			var tick_c: Color = Color(aura_col_base.r, aura_col_base.g, aura_col_base.b, 0.30 + pulse * 0.10)
			draw_line(center - Vector2(tick_out, 0.0), center - Vector2(tick_in, 0.0), tick_c, 1.4)
			draw_line(center + Vector2(tick_in, 0.0), center + Vector2(tick_out, 0.0), tick_c, 1.4)
			draw_line(center - Vector2(0.0, tick_out), center - Vector2(0.0, tick_in), tick_c, 1.4)
			draw_line(center + Vector2(0.0, tick_in), center + Vector2(0.0, tick_out), tick_c, 1.4)

			draw_circle(center, 3.2, core_col)
		else:
			# --- Filled Goal: Radiant Docking Under-Glow beneath crate ---
			_draw_goal_hazard_brackets(rect, ch)
			draw_texture_rect(tex_goal, rect, false, Color(1.0, 1.0, 1.0, 0.50))
			var aura_glow: Color = aura_col_base
			aura_glow.a = 0.36 + pulse * 0.12
			draw_circle(center, tile_size * 0.46, aura_glow)
			draw_arc(center, tile_size * 0.42, 0.0, TAU, 36, Color(1.0, 0.92, 0.45, 0.70), 2.0, true)

	# 3.5. Draw Floating Ambient Warehouse Motes (Option B)
	_draw_ambient_motes(effective_origin, board_pixel_size, ch)

	# 4. Draw Push Friction Dust Puffs
	for dp in dust_particles:
		var alpha: float = clampf(dp["life"] / dp["max_life"], 0.0, 1.0)
		var col: Color = dp["color"]
		col.a = alpha * 0.70
		draw_circle(dp["pos"], dp["size"], col)

	# 5. Draw Goal Shockwaves & Sparks
	for ge in goal_effects:
		var alpha: float = clampf(ge["life"] / ge["max_life"], 0.0, 1.0)
		if ge["type"] == "ring":
			var ring_col: Color = ge["color"]
			ring_col.a = alpha * 0.85
			draw_arc(ge["pos"], ge["radius"], 0, TAU, 32, ring_col, 3.0, true)
		elif ge["type"] == "spark":
			var spark_col: Color = ge["color"]
			spark_col.a = alpha
			draw_circle(ge["pos"], ge["size"] * alpha, spark_col)

	# 5.5. Draw Victory Goal Radiance Shockwaves
	for ring in victory_radiance_rings:
		var alpha: float = clampf(ring["life"] / ring["max_life"], 0.0, 1.0)
		var r_col: Color = ring["color"]
		r_col.a = alpha * 0.85
		draw_arc(ring["pos"], ring["radius"], 0.0, TAU, 36, r_col, 4.0, true)
		var inner_col: Color = Color(1.0, 1.0, 0.90, alpha * 0.50)
		draw_arc(ring["pos"], ring["radius"] * 0.72, 0.0, TAU, 28, inner_col, 2.0, true)

	# 5.8. Draw Worker Ambient Headlamp Glow & Forward Beam (Option B)
	_draw_player_headlamp(effective_origin)

	# 6. Draw Crates with Drop Shadow, 3D Shading & Squash
	for logical_pos in grid.crates.keys():
		var draw_tile_pos: Vector2 = visual_crates.get(logical_pos, Vector2(logical_pos))
		var is_on_goal: bool = grid.is_goal(logical_pos)
		var crate_padding: float = tile_size * 0.04
		var rect: Rect2 = Rect2(
			effective_origin + draw_tile_pos * tile_size + Vector2(crate_padding, crate_padding),
			Vector2(tile_size - crate_padding * 2.0, tile_size - crate_padding * 2.0)
		)
		_draw_crate(rect, is_on_goal, logical_pos)

	# 7. Draw Directional Porter Worker
	var player_padding: float = tile_size * 0.04
	var player_rect: Rect2 = Rect2(
		effective_origin + visual_player_pos * tile_size + Vector2(player_padding, player_padding),
		Vector2(tile_size - player_padding * 2.0, tile_size - player_padding * 2.0)
	)
	_draw_player(player_rect)

	# 7.5. Draw 1-Step Hint Directional Ghost & Indicator
	_draw_hint_ghost(effective_origin)

	# 8. Draw Victory Celebration Particles
	for p in win_particles:
		var alpha: float = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var p_col: Color = p["color"]
		p_col.a = alpha
		var half_sz: float = p["size"] * 0.5
		var p_type: String = p.get("type", "ribbon")

		if p_type == "star":
			_draw_star_shape(p["pos"], p["size"] * 0.85, p_col)
		else:
			# Ribbon with 3D aspect ratio perspective tumbling based on rotation
			var cos_r: float = cos(p["rot"])
			var rib_w: float = half_sz * 1.5
			var rib_h: float = half_sz * 0.65 * abs(cos_r) + 1.5
			var pts: PackedVector2Array = [
				p["pos"] + Vector2(-rib_w, -rib_h).rotated(p["rot"]),
				p["pos"] + Vector2(rib_w, -rib_h).rotated(p["rot"]),
				p["pos"] + Vector2(rib_w, rib_h).rotated(p["rot"]),
				p["pos"] + Vector2(-rib_w, rib_h).rotated(p["rot"])
			]
			draw_colored_polygon(pts, p_col)

	# 9. Draw Star Award Burst Sparks
	for sp in star_burst_particles:
		var alpha: float = clampf(sp["life"] / sp["max_life"], 0.0, 1.0)
		var col: Color = sp["color"]
		col.a = alpha
		_draw_star_shape(sp["pos"], sp["size"] * alpha, col)


func _draw_star_shape(center: Vector2, radius: float, color: Color) -> void:
	if radius < 1.0:
		return
	var pts: PackedVector2Array = []
	for i in range(8):
		var a: float = i * (TAU / 8.0) - PI * 0.5
		var r: float = radius if (i % 2 == 0) else (radius * 0.38)
		pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(pts, color)


func _draw_exterior_void_tile(rect: Rect2, pos: Vector2i, ch: Dictionary) -> void:
	# 1. Dark warehouse yard/perimeter floor base with clean subtle industrial tint
	var void_bg: Color = ch.get("dim_color", Color(0.02, 0.03, 0.06, 0.45))
	draw_rect(rect, void_bg)

	# 2. Outer wall drop shadow cast onto exterior void for 2.5D ambient depth
	if pos.y > 0 and grid.is_wall(Vector2i(pos.x, pos.y - 1)):
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, tile_size * 0.26)), Color(0.0, 0.0, 0.0, 0.38))
	if pos.x > 0 and grid.is_wall(Vector2i(pos.x - 1, pos.y)):
		draw_rect(Rect2(rect.position, Vector2(tile_size * 0.22, rect.size.y)), Color(0.0, 0.0, 0.0, 0.34))

	# 3. Subtle architectural grid lines (faint warehouse blueprint grid)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.022), false, 1.0)


func _draw_warehouse_prop(rect: Rect2, _pos: Vector2i, _ch: Dictionary) -> void:
	var pad: float = tile_size * 0.05
	var prop_rect: Rect2 = Rect2(rect.position + Vector2(pad, pad), Vector2(tile_size - pad * 2.0, tile_size - pad * 2.0))

	# Chapter-specific atmospheric tint
	var prop_tint: Color = Color(1.0, 1.0, 1.0, 0.96)
	if current_chapter_idx == 1:
		# Cold Storage: Frosted / Icy cool tint
		prop_tint = Color(0.85, 0.94, 1.0, 0.92)
	elif current_chapter_idx == 2:
		# Cyber Depot: Neon high-tech depot tint
		prop_tint = Color(0.92, 0.88, 1.0, 0.95)

	draw_texture_rect(tex_void_high_value_crate, prop_rect, false, prop_tint)


func _draw_cyber_pylon(rect: Rect2, center: Vector2) -> void:
	var pylon_sz: float = tile_size * 0.42
	var pylon_r: Rect2 = Rect2(center - Vector2(pylon_sz, pylon_sz) * 0.5, Vector2(pylon_sz, pylon_sz))
	draw_rect(pylon_r, Color(0.06, 0.08, 0.14))
	draw_rect(pylon_r, Color(0.18, 0.38, 0.65), false, 1.5)
	var pulse: float = sin(float(Time.get_ticks_msec()) * 0.004 + (rect.position.x + rect.position.y)) * 0.25 + 0.75
	draw_circle(center, pylon_sz * 0.22, Color(0.10, 0.85, 1.0, pulse * 0.9))


func _draw_wall(rect: Rect2, pos: Vector2i = Vector2i.ZERO) -> void:
	var ch: Dictionary = get_current_chapter_theme()
	draw_texture_rect(tex_wall, rect, false, ch["wall_tint"])

	if grid == null:
		return

	var is_top_edge: bool = (pos.y == 0 or not grid.is_wall(pos + Vector2i.UP))
	var is_bottom_edge: bool = (pos.y >= grid.height - 1 or not grid.is_wall(pos + Vector2i.DOWN))
	var is_left_edge: bool = (pos.x == 0 or not grid.is_wall(pos + Vector2i.LEFT))
	var is_right_edge: bool = (pos.x >= grid.width - 1 or not grid.is_wall(pos + Vector2i.RIGHT))

	# 1. Top coping stone / specular highlight (Option B)
	if is_top_edge:
		# Crisp specular edge on top of wall cap
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), Color(1.0, 1.0, 1.0, 0.38), 2.5)
		draw_line(rect.position + Vector2(0.0, 2.5), rect.position + Vector2(rect.size.x, 2.5), Color(1.0, 1.0, 1.0, 0.14), 1.0)
		# Demarcation shadow crease right below the coping edge
		draw_line(rect.position + Vector2(0.0, 3.5), rect.position + Vector2(rect.size.x, 3.5), Color(0.0, 0.0, 0.0, 0.28), 1.0)
	else:
		# Subtle interior masonry course line
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), Color(0.0, 0.0, 0.0, 0.18), 1.0)

	# 2. Left side specular highlight (top-left key lighting)
	if is_left_edge:
		draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), Color(1.0, 1.0, 1.0, 0.22), 1.5)

	# 3. Right side ambient shadow edge
	if is_right_edge:
		draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + rect.size, Color(0.0, 0.0, 0.0, 0.35), 2.0)

	# 4. Bottom base shadow / footing depth
	if is_bottom_edge:
		draw_line(rect.position + Vector2(0.0, rect.size.y - 1.0), rect.end - Vector2(0.0, 1.0), Color(0.0, 0.0, 0.0, 0.48), 2.5)


## Returns true if the level has exterior void tiles outside its walls (irregular / non-square shape).
func is_level_non_square() -> bool:
	if grid == null or grid.width == 0 or grid.height == 0:
		return false
	if grid.interior_floor.is_empty():
		return false
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.is_exterior_void(Vector2i(x, y)):
				return true
	return false


## Returns true if the position is an exterior tile (out of bounds or marked as exterior void).
func is_exterior_tile(pos: Vector2i) -> bool:
	if grid == null:
		return true
	if not grid.is_in_bounds(pos):
		return true
	return grid.is_exterior_void(pos)


## Draws a slim, snug chapter border directly along the outer perimeter walls for non-square levels,
## eliminating empty corner voids while preserving polished industrial styling.
func _draw_slim_level_border(effective_origin: Vector2, ch: Dictionary) -> void:
	if grid == null:
		return

	var rim_col: Color = ch["frame_rim"]
	var groove_col: Color = ch["frame_groove"]
	var bolt_dark: Color = ch["bolt_dark"]
	var bolt_core: Color = ch["bolt_core"]
	var bolt_spec: Color = ch["bolt_specular"]

	for wall_pos in grid.walls.keys():
		var rect: Rect2 = Rect2(effective_origin + Vector2(wall_pos) * tile_size, Vector2(tile_size, tile_size))

		var ext_u: bool = is_exterior_tile(wall_pos + Vector2i.UP)
		var ext_d: bool = is_exterior_tile(wall_pos + Vector2i.DOWN)
		var ext_l: bool = is_exterior_tile(wall_pos + Vector2i.LEFT)
		var ext_r: bool = is_exterior_tile(wall_pos + Vector2i.RIGHT)

		# Top outer edge
		if ext_u:
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), rim_col, 2.5)
			draw_line(rect.position + Vector2(0.0, 1.0), rect.position + Vector2(rect.size.x, 1.0), Color(1.0, 1.0, 1.0, 0.38), 1.0)
			draw_line(rect.position + Vector2(0.0, 2.5), rect.position + Vector2(rect.size.x, 2.5), groove_col, 1.5)

		# Left outer edge
		if ext_l:
			draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), rim_col, 2.5)
			draw_line(rect.position + Vector2(1.0, 0.0), rect.position + Vector2(1.0, rect.size.y), Color(1.0, 1.0, 1.0, 0.30), 1.0)
			draw_line(rect.position + Vector2(2.5, 0.0), rect.position + Vector2(2.5, rect.size.y), groove_col, 1.5)

		# Bottom outer edge
		if ext_d:
			draw_line(rect.position + Vector2(0.0, rect.size.y + 1.2), rect.end + Vector2(0.0, 1.2), Color(0.0, 0.0, 0.0, 0.45), 2.0)
			draw_line(rect.position + Vector2(0.0, rect.size.y), rect.end, rim_col, 2.5)
			draw_line(rect.position + Vector2(0.0, rect.size.y - 1.5), rect.end - Vector2(0.0, 1.5), groove_col, 1.5)

		# Right outer edge
		if ext_r:
			draw_line(rect.position + Vector2(rect.size.x + 1.2, 0.0), rect.end + Vector2(1.2, 0.0), Color(0.0, 0.0, 0.0, 0.42), 2.0)
			draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.end, rim_col, 2.5)
			draw_line(rect.position + Vector2(rect.size.x - 1.5, 0.0), rect.end - Vector2(1.5, 0.0), groove_col, 1.5)

		# Outer convex corners: decorative industrial chapter bolts
		if ext_u and ext_l:
			draw_circle(rect.position, 3.2, bolt_dark)
			draw_circle(rect.position, 2.2, bolt_core)
			draw_circle(rect.position - Vector2(0.6, 0.6), 0.8, bolt_spec)

		if ext_u and ext_r:
			var c_tr: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
			draw_circle(c_tr, 3.2, bolt_dark)
			draw_circle(c_tr, 2.2, bolt_core)
			draw_circle(c_tr + Vector2(-0.6, 0.6), 0.8, bolt_spec)

		if ext_d and ext_l:
			var c_bl: Vector2 = rect.position + Vector2(0.0, rect.size.y)
			draw_circle(c_bl, 3.2, bolt_dark)
			draw_circle(c_bl, 2.2, bolt_core)
			draw_circle(c_bl + Vector2(0.6, -0.6), 0.8, bolt_spec)

		if ext_d and ext_r:
			var c_br: Vector2 = rect.end
			draw_circle(c_br, 3.2, bolt_dark)
			draw_circle(c_br, 2.2, bolt_core)
			draw_circle(c_br - Vector2(0.6, 0.6), 0.8, bolt_spec)


func _draw_board_vignette(effective_origin: Vector2, board_pixel_size: Vector2) -> void:
	var v_thick: float = minf(tile_size * 0.45, 36.0)
	var board_rect: Rect2 = Rect2(effective_origin, board_pixel_size)

	# Soft edge inward darkening strips
	# Top edge
	draw_rect(Rect2(board_rect.position, Vector2(board_rect.size.x, v_thick)), Color(0.0, 0.0, 0.0, 0.14))
	draw_rect(Rect2(board_rect.position, Vector2(board_rect.size.x, v_thick * 0.45)), Color(0.0, 0.0, 0.0, 0.10))

	# Bottom edge
	draw_rect(Rect2(Vector2(board_rect.position.x, board_rect.end.y - v_thick), Vector2(board_rect.size.x, v_thick)), Color(0.0, 0.0, 0.0, 0.14))
	draw_rect(Rect2(Vector2(board_rect.position.x, board_rect.end.y - v_thick * 0.45), Vector2(board_rect.size.x, v_thick * 0.45)), Color(0.0, 0.0, 0.0, 0.10))

	# Left edge
	draw_rect(Rect2(board_rect.position, Vector2(v_thick, board_rect.size.y)), Color(0.0, 0.0, 0.0, 0.14))
	draw_rect(Rect2(board_rect.position, Vector2(v_thick * 0.45, board_rect.size.y)), Color(0.0, 0.0, 0.0, 0.10))

	# Right edge
	draw_rect(Rect2(Vector2(board_rect.end.x - v_thick, board_rect.position.y), Vector2(v_thick, board_rect.size.y)), Color(0.0, 0.0, 0.0, 0.14))
	draw_rect(Rect2(Vector2(board_rect.end.x - v_thick * 0.45, board_rect.position.y), Vector2(v_thick * 0.45, board_rect.size.y)), Color(0.0, 0.0, 0.0, 0.10))

	# Corner ambient shadow rounds
	var corner_r: float = v_thick * 1.15
	var corners: Array[Vector2] = [
		board_rect.position,
		Vector2(board_rect.end.x, board_rect.position.y),
		Vector2(board_rect.position.x, board_rect.end.y),
		board_rect.end
	]
	for c_pos in corners:
		draw_circle(c_pos, corner_r, Color(0.0, 0.0, 0.0, 0.12))


func _draw_goal_hazard_brackets(rect: Rect2, _ch: Dictionary) -> void:
	var arm: float = rect.size.x * 0.22
	var m: float = 1.0
	var steel_col: Color = Color(0.12, 0.14, 0.18, 0.88)
	var yellow_col: Color = Color(0.96, 0.80, 0.15, 0.85)
	var rivet_col: Color = Color(0.90, 0.92, 0.95, 0.95)

	# Top-Left Bracket
	draw_line(rect.position + Vector2(m, m), rect.position + Vector2(m + arm, m), steel_col, 2.5)
	draw_line(rect.position + Vector2(m, m), rect.position + Vector2(m, m + arm), steel_col, 2.5)
	draw_line(rect.position + Vector2(m + 1.2, m + 1.2), rect.position + Vector2(m + arm * 0.75, m + 1.2), yellow_col, 1.4)
	draw_line(rect.position + Vector2(m + 1.2, m + 1.2), rect.position + Vector2(m + 1.2, m + arm * 0.75), yellow_col, 1.4)
	draw_circle(rect.position + Vector2(m + 2.0, m + 2.0), 1.2, rivet_col)

	# Top-Right Bracket
	var tr: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	draw_line(tr + Vector2(-m, m), tr + Vector2(-m - arm, m), steel_col, 2.5)
	draw_line(tr + Vector2(-m, m), tr + Vector2(-m, m + arm), steel_col, 2.5)
	draw_line(tr + Vector2(-m - 1.2, m + 1.2), tr + Vector2(-m - arm * 0.75, m + 1.2), yellow_col, 1.4)
	draw_line(tr + Vector2(-m - 1.2, m + 1.2), tr + Vector2(-m - 1.2, m + arm * 0.75), yellow_col, 1.4)
	draw_circle(tr + Vector2(-m - 2.0, m + 2.0), 1.2, rivet_col)

	# Bottom-Left Bracket
	var bl: Vector2 = rect.position + Vector2(0.0, rect.size.y)
	draw_line(bl + Vector2(m, -m), bl + Vector2(m + arm, -m), steel_col, 2.5)
	draw_line(bl + Vector2(m, -m), bl + Vector2(m, -m - arm), steel_col, 2.5)
	draw_line(bl + Vector2(m + 1.2, -m - 1.2), bl + Vector2(m + arm * 0.75, -m - 1.2), yellow_col, 1.4)
	draw_line(bl + Vector2(m + 1.2, -m - 1.2), bl + Vector2(m + 1.2, -m - arm * 0.75), yellow_col, 1.4)
	draw_circle(bl + Vector2(m + 2.0, -m - 2.0), 1.2, rivet_col)

	# Bottom-Right Bracket
	var br: Vector2 = rect.end
	draw_line(br + Vector2(-m, -m), br + Vector2(-m - arm, -m), steel_col, 2.5)
	draw_line(br + Vector2(-m, -m), br + Vector2(-m, -m - arm), steel_col, 2.5)
	draw_line(br + Vector2(-m - 1.2, -m - 1.2), br + Vector2(-m - arm * 0.75, -m - 1.2), yellow_col, 1.4)
	draw_line(br + Vector2(-m - 1.2, -m - 1.2), br + Vector2(-m - 1.2, -m - arm * 0.75), yellow_col, 1.4)
	draw_circle(br + Vector2(-m - 2.0, -m - 2.0), 1.2, rivet_col)


func _draw_player_headlamp(effective_origin: Vector2) -> void:
	# Subtle, soft ambient contact warmth under player (no harsh discs or projecting beams)
	var p_center: Vector2 = effective_origin + visual_player_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5) + bump_offset + Vector2(0.0, player_celebration_hop)
	draw_circle(p_center, tile_size * 0.35, Color(1.0, 0.96, 0.82, 0.025))


func _draw_ambient_motes(effective_origin: Vector2, board_pixel_size: Vector2, _ch: Dictionary) -> void:
	var is_non_sq: bool = is_level_non_square()
	for mote in ambient_motes:
		var norm: Vector2 = mote.get("pos_norm", Vector2.ZERO)
		if is_non_sq and grid != null and grid.width > 0 and grid.height > 0:
			var gx: int = clampi(int(floor(norm.x * float(grid.width))), 0, grid.width - 1)
			var gy: int = clampi(int(floor(norm.y * float(grid.height))), 0, grid.height - 1)
			if grid.is_exterior_void(Vector2i(gx, gy)):
				continue
		var m_pos: Vector2 = effective_origin + Vector2(norm.x * board_pixel_size.x, norm.y * board_pixel_size.y)
		var phase: float = mote.get("phase", 0.0)
		var sz: float = mote.get("size", 2.0)
		var b_alpha: float = mote.get("base_alpha", 0.4)

		match current_chapter_idx:
			1: # Cold Storage: crystalline frost sparkles
				var alpha: float = b_alpha * (0.80 + 0.20 * sin(phase * 1.6))
				var fl: float = sz * 1.3
				draw_circle(m_pos, sz * 0.75, Color(0.70, 0.90, 1.0, alpha * 0.65))
				draw_line(m_pos - Vector2(fl, 0), m_pos + Vector2(fl, 0), Color(0.88, 0.96, 1.0, alpha * 0.85), 1.0)
				draw_line(m_pos - Vector2(0, fl), m_pos + Vector2(0, fl), Color(0.88, 0.96, 1.0, alpha * 0.85), 1.0)
			2: # Cyber Depot: neon electronic embers
				var alpha: float = b_alpha * (0.75 + 0.25 * sin(phase * 2.2))
				draw_circle(m_pos, sz * 0.9, Color(0.20, 0.95, 0.85, alpha * 0.65))
				draw_circle(m_pos, sz * 0.4, Color(0.85, 1.0, 0.95, alpha * 0.95))
			_: # Cargo Bay (default): warm golden warehouse dust motes in sunbeams
				var alpha: float = b_alpha * (0.75 + 0.25 * sin(phase))
				draw_circle(m_pos, sz, Color(1.0, 0.90, 0.65, alpha * 0.60))
				draw_circle(m_pos, sz * 0.5, Color(1.0, 1.0, 0.92, alpha * 0.85))


func _init_ambient_motes() -> void:
	ambient_motes.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(16):
		ambient_motes.append({
			"pos_norm": Vector2(rng.randf(), rng.randf()),
			"vel": Vector2(rng.randf_range(-0.018, 0.018), rng.randf_range(-0.012, 0.012)),
			"phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(1.6, 3.2),
			"base_alpha": rng.randf_range(0.22, 0.55),
			"speed_mult": rng.randf_range(0.8, 1.3)
		})


func _draw_crate(rect: Rect2, on_goal: bool, logical_pos: Vector2i = Vector2i.ZERO) -> void:
	var scale_fac: Vector2 = crate_squash.get(logical_pos, Vector2.ONE)
	var c_center: Vector2 = rect.get_center()
	var scaled_sz: Vector2 = rect.size * scale_fac
	var draw_r: Rect2 = Rect2(c_center - scaled_sz * 0.5, scaled_sz)

	# 1. High-fidelity multi-stage 2.5D contact drop shadow (squashes dynamically with crate)
	var shadow_y: float = draw_r.position.y + draw_r.size.y * 0.92
	var shadow_center: Vector2 = Vector2(c_center.x + 2.0, shadow_y + 2.0)
	var rx_outer: float = draw_r.size.x * 0.48
	var ry_outer: float = draw_r.size.y * 0.22
	var rx_core: float = draw_r.size.x * 0.40
	var ry_core: float = draw_r.size.y * 0.12

	# Ambient diffused contact shadow
	var pts_c_outer: PackedVector2Array = []
	for i in range(16):
		var a: float = i * (TAU / 16.0)
		pts_c_outer.append(shadow_center + Vector2(cos(a) * rx_outer, sin(a) * ry_outer))
	draw_colored_polygon(pts_c_outer, Color(0.0, 0.0, 0.0, 0.24))

	# Core contact crease right under the base
	var pts_c_core: PackedVector2Array = []
	for i in range(16):
		var a: float = i * (TAU / 16.0)
		pts_c_core.append(shadow_center + Vector2(cos(a) * rx_core, sin(a) * ry_core))
	draw_colored_polygon(pts_c_core, Color(0.0, 0.0, 0.0, 0.48))

	var ch: Dictionary = get_current_chapter_theme()
	var c_tex: Texture2D = tex_crate_goal if on_goal else tex_crate

	# Crate Skin from Porter Locker
	var crate_skin_info: Dictionary = save_mgr.get_crate_skin_info() if (save_mgr and save_mgr.has_method("get_crate_skin_info")) else {}
	var crate_skin_id: String = crate_skin_info.get("id", "classic_wood")
	var crate_tint: Color = crate_skin_info.get("tint", Color.WHITE)

	var c_mod: Color = Color(1.0, 1.0, 1.0) if on_goal else (ch["crate_tint"] * crate_tint)
	draw_texture_rect(c_tex, draw_r, false, c_mod)

	# 2. 3D Volume Bevel Highlights matching warehouse overhead light
	draw_line(draw_r.position + Vector2(2.0, 1.0), draw_r.position + Vector2(draw_r.size.x - 2.0, 1.0), Color(1.0, 1.0, 1.0, 0.24), 1.2)
	draw_line(draw_r.position + Vector2(2.0, draw_r.size.y - 1.0), draw_r.end - Vector2(2.0, 1.0), Color(0.0, 0.0, 0.0, 0.32), 1.5)

	# Crate custom skin accessories (only when not on goal so goal star is unobstructed)
	if not on_goal:
		match crate_skin_id:
			"steel_container":
				# Cold-rolled metallic corner angle braces
				var brace_len: float = draw_r.size.x * 0.22
				var b_col: Color = Color(0.85, 0.92, 1.0, 0.75)
				# Top-left corner
				draw_line(draw_r.position, draw_r.position + Vector2(brace_len, 0), b_col, 2.0)
				draw_line(draw_r.position, draw_r.position + Vector2(0, brace_len), b_col, 2.0)
				# Top-right corner
				draw_line(draw_r.position + Vector2(draw_r.size.x, 0), draw_r.position + Vector2(draw_r.size.x - brace_len, 0), b_col, 2.0)
				draw_line(draw_r.position + Vector2(draw_r.size.x, 0), draw_r.position + Vector2(draw_r.size.x, brace_len), b_col, 2.0)
				# Bottom-left corner
				draw_line(draw_r.position + Vector2(0, draw_r.size.y), draw_r.position + Vector2(brace_len, draw_r.size.y), b_col, 2.0)
				draw_line(draw_r.position + Vector2(0, draw_r.size.y), draw_r.position + Vector2(0, draw_r.size.y - brace_len), b_col, 2.0)
				# Bottom-right corner
				draw_line(draw_r.end, draw_r.end - Vector2(brace_len, 0), b_col, 2.0)
				draw_line(draw_r.end, draw_r.end - Vector2(0, brace_len), b_col, 2.0)
			"hazard_box":
				# Caution diagonal hazard accent in center
				var h_col: Color = Color(0.12, 0.12, 0.15, 0.70)
				var c_len: float = draw_r.size.x * 0.35
				draw_line(c_center - Vector2(c_len * 0.5, c_len * 0.5), c_center + Vector2(c_len * 0.5, c_len * 0.5), h_col, 3.5)
				draw_line(c_center - Vector2(c_len * 0.5, -c_len * 0.5), c_center + Vector2(c_len * 0.5, -c_len * 0.5), h_col, 3.5)
				# Glowing hazard border rim
				draw_rect(draw_r.grow(-2), Color(1.0, 0.75, 0.15, 0.55), false, 1.5)

	if on_goal:
		var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
		var star_pulse: float = sin(time_sec * 4.0) * 0.15
		var aura_spark: Color = ch["goal_aura"]
		aura_spark.a = 0.50
		draw_circle(c_center, 9.5 * (1.0 + star_pulse), aura_spark)
		draw_circle(c_center, 4.0, Color(1.0, 1.0, 0.92, 0.95))

		# 4 Radiant metallic lock-in corner rivets
		var r_pad: float = draw_r.size.x * 0.14
		var corners: Array[Vector2] = [
			draw_r.position + Vector2(r_pad, r_pad),
			draw_r.position + Vector2(draw_r.size.x - r_pad, r_pad),
			draw_r.position + Vector2(r_pad, draw_r.size.y - r_pad),
			draw_r.position + Vector2(draw_r.size.x - r_pad, draw_r.size.y - r_pad)
		]
		for corn in corners:
			draw_circle(corn, 2.8, Color(0.08, 0.10, 0.14, 0.90))
			draw_circle(corn, 2.0, aura_spark)
			draw_circle(corn - Vector2(0.5, 0.5), 0.9, Color(1.0, 1.0, 0.95, 0.98))


func _draw_player(rect: Rect2) -> void:
	var idle_breath_y: float = 0.0
	if not is_animating and not is_level_won and player_idle_time > 2.0:
		idle_breath_y = sin((player_idle_time - 2.0) * 3.5) * 1.2

	var hopped_rect: Rect2 = Rect2(
		rect.position + bump_offset + Vector2(0.0, player_celebration_hop + idle_breath_y),
		rect.size
	)
	var center: Vector2 = hopped_rect.get_center()
	var radius: float = hopped_rect.size.x / 2.0

	# Ground contact drop shadow (positioned directly under soles of boots on floor)
	var x_offset: float = 0.0
	if player_facing_dir == Vector2i.LEFT:
		x_offset = -radius * 0.04
	elif player_facing_dir == Vector2i.RIGHT:
		x_offset = radius * 0.04
	var shadow_center: Vector2 = Vector2(rect.get_center().x + x_offset, rect.position.y + rect.size.y * 0.94)

	# As player hops up, ground shadow shrinks slightly for 2.5D jump depth
	var hop_factor: float = clampf(1.0 + player_celebration_hop / 35.0, 0.45, 1.0)

	# 1. Outer soft ambient shadow
	var pts_outer: PackedVector2Array = []
	var rx_outer: float = radius * 0.68 * hop_factor
	var ry_outer: float = radius * 0.24 * hop_factor
	for i in range(16):
		var a: float = i * (TAU / 16.0)
		pts_outer.append(shadow_center + Vector2(cos(a) * rx_outer, sin(a) * ry_outer))
	draw_colored_polygon(pts_outer, Color(0.0, 0.0, 0.0, 0.30 * hop_factor))

	# 2. Inner core contact shadow (tight under soles)
	var pts_inner: PackedVector2Array = []
	var rx_inner: float = radius * 0.48 * hop_factor
	var ry_inner: float = radius * 0.14 * hop_factor
	for i in range(16):
		var a: float = i * (TAU / 16.0)
		pts_inner.append(shadow_center + Vector2(cos(a) * rx_inner, sin(a) * ry_inner))
	draw_colored_polygon(pts_inner, Color(0.0, 0.0, 0.0, 0.55 * hop_factor))

	# 3. Grounded micro contact points under left and right boots
	var boot_spacing: float = radius * 0.20
	draw_circle(shadow_center + Vector2(-boot_spacing, 0.0), radius * 0.10 * hop_factor, Color(0.0, 0.0, 0.0, 0.40 * hop_factor))
	draw_circle(shadow_center + Vector2(boot_spacing, 0.0), radius * 0.10 * hop_factor, Color(0.0, 0.0, 0.0, 0.40 * hop_factor))

	# Pick directional sprite (idle vs walk cycle frame 1/2)
	var p_tex: Texture2D = tex_player_down
	if player_facing_dir == Vector2i.UP:
		p_tex = tex_player_up_w1 if current_walk_frame == 1 else (tex_player_up_w2 if current_walk_frame == 2 else tex_player_up)
	elif player_facing_dir == Vector2i.LEFT:
		p_tex = tex_player_left_w1 if current_walk_frame == 1 else (tex_player_left_w2 if current_walk_frame == 2 else tex_player_left)
	elif player_facing_dir == Vector2i.RIGHT:
		p_tex = tex_player_right_w1 if current_walk_frame == 1 else (tex_player_right_w2 if current_walk_frame == 2 else tex_player_right)
	else:
		p_tex = tex_player_down_w1 if current_walk_frame == 1 else (tex_player_down_w2 if current_walk_frame == 2 else tex_player_down)

	# Equipped Worker Skin from Porter Locker
	var skin_info: Dictionary = save_mgr.get_worker_skin_info() if (save_mgr and save_mgr.has_method("get_worker_skin_info")) else {}
	var skin_id: String = skin_info.get("id", "classic")
	var p_modulate: Color = skin_info.get("sprite_tint", Color.WHITE)

	draw_texture_rect(p_tex, hopped_rect, false, p_modulate)

	# Skin Accessory & Visual Accent Overlays
	match skin_id:
		"safety_vest":
			# High-vis reflective horizontal safety chest stripes
			var stripe_y: float = rect.position.y + rect.size.y * 0.54
			var stripe_w: float = rect.size.x * 0.42
			var stripe_x: float = center.x - stripe_w * 0.5
			draw_line(Vector2(stripe_x, stripe_y), Vector2(stripe_x + stripe_w, stripe_y), Color(0.95, 0.98, 1.0, 0.85), 2.2)
			draw_line(Vector2(stripe_x, stripe_y - 2), Vector2(stripe_x + stripe_w, stripe_y - 2), Color(1.0, 0.55, 0.10, 0.70), 1.2)
		"foreman":
			# Foreman hardhat brim highlight
			var brim_y: float = rect.position.y + rect.size.y * 0.28
			var brim_w: float = rect.size.x * 0.50
			var brim_x: float = center.x - brim_w * 0.5
			draw_line(Vector2(brim_x, brim_y), Vector2(brim_x + brim_w, brim_y), Color(1.0, 0.90, 0.25, 0.90), 2.0)
		"golden_porter":
			# Radiant golden sparkles & prestige shimmer
			var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
			var shimmer: float = sin(time_sec * 5.0) * 0.25 + 0.75
			draw_circle(center + Vector2(0, -rect.size.y * 0.40), 2.5 * shimmer, Color(1.0, 0.95, 0.60, 0.85))
			draw_circle(center + Vector2(-rect.size.x * 0.32, -rect.size.y * 0.10), 1.8 * (1.2 - shimmer), Color(1.0, 0.85, 0.30, 0.75))
			draw_circle(center + Vector2(rect.size.x * 0.32, -rect.size.y * 0.15), 1.8 * shimmer, Color(1.0, 0.88, 0.40, 0.75))

	# Joyful victory sparkles above worker when level is won
	if is_level_won:
		var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
		var hop_bounce: float = sin(time_sec * 12.0) * 3.5
		var star_col: Color = Color(1.0, 0.95, 0.35, 0.92)
		_draw_star_shape(hopped_rect.position + Vector2(hopped_rect.size.x * 0.20, -8.0 + hop_bounce), 5.0, star_col)
		_draw_star_shape(hopped_rect.position + Vector2(hopped_rect.size.x * 0.80, -11.0 - hop_bounce), 5.5, star_col)

	# Option C: Anime-style thinking / perplexed sweat drop
	if sweat_drop_timer > 0.0:
		var s_alpha: float = clampf(sweat_drop_timer / 0.4, 0.0, 1.0)
		var drip_progress: float = 1.0 - (sweat_drop_timer / 1.4)
		var drip_y: float = drip_progress * 4.5
		var drop_center: Vector2 = hopped_rect.position + Vector2(hopped_rect.size.x * 0.82, hopped_rect.size.y * 0.22 + drip_y)
		var drop_r: float = 3.2
		draw_circle(drop_center, drop_r, Color(0.22, 0.78, 1.0, s_alpha * 0.90))
		var drop_tip: Vector2 = drop_center - Vector2(0.0, drop_r * 1.5)
		var drop_pts: PackedVector2Array = [
			drop_tip,
			drop_center + Vector2(drop_r * 0.95, 0.0),
			drop_center + Vector2(-drop_r * 0.95, 0.0)
		]
		draw_colored_polygon(drop_pts, Color(0.22, 0.78, 1.0, s_alpha * 0.90))
		# Specular glint
		draw_circle(drop_center - Vector2(0.9, 0.9), 1.1, Color(1.0, 1.0, 1.0, s_alpha * 0.95))



func _draw_hint_ghost(effective_origin: Vector2) -> void:
	if hint_time_remaining <= 0.0 or active_hint_dir == Vector2i.ZERO:
		return

	var pulse: float = 0.55 + 0.35 * sin(hint_pulse_timer * 7.0)
	var fade: float = clampf(hint_time_remaining / 0.4, 0.0, 1.0)
	var base_alpha: float = pulse * fade

	# 1. Player Target Ghost Tile
	var p_target_rect: Rect2 = Rect2(
		effective_origin + Vector2(hint_player_target) * tile_size,
		Vector2(tile_size, tile_size)
	)
	var p_center: Vector2 = p_target_rect.get_center()

	# Glowing beacon tile highlight
	draw_rect(p_target_rect.grow(-3), Color(0.15, 0.65, 1.0, 0.22 * base_alpha), true)
	draw_rect(p_target_rect.grow(-3), Color(0.35, 0.85, 1.0, 0.75 * base_alpha), false, 2.5)

	# Pick directional ghost player texture
	var p_ghost_tex: Texture2D = tex_player_down
	if active_hint_dir == Vector2i.UP:
		p_ghost_tex = tex_player_up
	elif active_hint_dir == Vector2i.LEFT:
		p_ghost_tex = tex_player_left
	elif active_hint_dir == Vector2i.RIGHT:
		p_ghost_tex = tex_player_right

	var p_draw_padding: float = tile_size * 0.04
	var p_ghost_draw_rect: Rect2 = Rect2(
		p_target_rect.position + Vector2(p_draw_padding, p_draw_padding),
		Vector2(tile_size - p_draw_padding * 2.0, tile_size - p_draw_padding * 2.0)
	)
	draw_texture_rect(p_ghost_tex, p_ghost_draw_rect, false, Color(1.0, 1.0, 1.0, 0.72 * base_alpha))

	# 2. Crate Target Ghost Tile (if move is a push)
	if hint_has_crate:
		var c_target_rect: Rect2 = Rect2(
			effective_origin + Vector2(hint_crate_target) * tile_size,
			Vector2(tile_size, tile_size)
		)
		# Glowing amber beacon for crate push destination
		draw_rect(c_target_rect.grow(-3), Color(1.0, 0.75, 0.15, 0.22 * base_alpha), true)
		draw_rect(c_target_rect.grow(-3), Color(1.0, 0.88, 0.30, 0.75 * base_alpha), false, 2.5)

		var is_target_goal: bool = grid.is_goal(hint_crate_target)
		var c_ghost_tex: Texture2D = tex_crate_goal if is_target_goal else tex_crate
		var c_draw_padding: float = tile_size * 0.04
		var c_ghost_draw_rect: Rect2 = Rect2(
			c_target_rect.position + Vector2(c_draw_padding, c_draw_padding),
			Vector2(tile_size - c_draw_padding * 2.0, tile_size - c_draw_padding * 2.0)
		)
		draw_texture_rect(c_ghost_tex, c_ghost_draw_rect, false, Color(1.0, 1.0, 1.0, 0.72 * base_alpha))

	# 3. Dynamic Directional Trajectory Arrow
	var current_player_center: Vector2 = effective_origin + visual_player_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
	var arrow_start: Vector2 = current_player_center + Vector2(active_hint_dir) * (tile_size * 0.32)
	var arrow_end: Vector2 = p_center - Vector2(active_hint_dir) * (tile_size * 0.22)
	var arrow_col: Color = Color(1.0, 0.92, 0.35, 0.85 * base_alpha)
	draw_line(arrow_start, arrow_end, arrow_col, 3.5)

	# Arrow head
	var arrow_norm: Vector2 = Vector2(active_hint_dir).normalized()
	var arrow_perp: Vector2 = Vector2(-arrow_norm.y, arrow_norm.x)
	var head_len: float = tile_size * 0.18
	var head_width: float = tile_size * 0.14
	var p1: Vector2 = arrow_end
	var p2: Vector2 = arrow_end - arrow_norm * head_len + arrow_perp * head_width
	var p3: Vector2 = arrow_end - arrow_norm * head_len - arrow_perp * head_width
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), arrow_col)

	# 4. Secondary Crate Push Trajectory (shows crate sliding to target beacon)
	if hint_has_crate:
		var c_dest_center: Vector2 = effective_origin + Vector2(hint_crate_target) * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
		var c_arrow_start: Vector2 = p_center + Vector2(active_hint_dir) * (tile_size * 0.28)
		var c_arrow_end: Vector2 = c_dest_center - Vector2(active_hint_dir) * (tile_size * 0.20)
		var c_arrow_col: Color = Color(1.0, 0.80, 0.25, 0.85 * base_alpha)
		draw_line(c_arrow_start, c_arrow_end, c_arrow_col, 3.0)

		var c_p1: Vector2 = c_arrow_end
		var c_p2: Vector2 = c_arrow_end - arrow_norm * head_len + arrow_perp * head_width
		var c_p3: Vector2 = c_arrow_end - arrow_norm * head_len - arrow_perp * head_width
		draw_colored_polygon(PackedVector2Array([c_p1, c_p2, c_p3]), c_arrow_col)


func add_trauma(amount: float) -> void:
	board_trauma = clampf(board_trauma + amount, 0.0, 1.0)


func _spawn_push_dust(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var dir: Vector2i = to_pos - from_pos
	var base_origin: Vector2 = grid_origin + Vector2(from_pos) * tile_size
	var spawn_edge_center: Vector2 = base_origin + Vector2(tile_size * 0.5, tile_size * 0.5) - Vector2(dir) * (tile_size * 0.42)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var dust_palette: Array[Color] = [
		Color(0.85, 0.80, 0.72, 0.85),
		Color(0.72, 0.67, 0.60, 0.80),
		Color(0.55, 0.50, 0.45, 0.70)
	]

	for i in range(6):
		var offset: Vector2 = Vector2.ZERO
		if dir.x != 0:
			offset = Vector2(0, rng.randf_range(-tile_size * 0.35, tile_size * 0.35))
		else:
			offset = Vector2(rng.randf_range(-tile_size * 0.35, tile_size * 0.35), 0)

		var back_vel: Vector2 = -Vector2(dir) * rng.randf_range(40.0, 85.0) + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		dust_particles.append({
			"pos": spawn_edge_center + offset,
			"vel": back_vel,
			"size": rng.randf_range(3.0, 5.5),
			"color": dust_palette[rng.randi() % dust_palette.size()],
			"life": rng.randf_range(0.22, 0.32),
			"max_life": 0.32
		})


func _spawn_goal_effect(goal_pos: Vector2i) -> void:
	var center: Vector2 = grid_origin + Vector2(goal_pos) * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)

	# Expanding shockwave ring
	goal_effects.append({
		"type": "ring",
		"pos": center,
		"radius": 4.0,
		"max_radius": tile_size * 0.85,
		"color": Color(1.0, 0.88, 0.25, 0.95),
		"life": 0.35,
		"max_life": 0.35
	})

	# 8 radiating golden sparks
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(8):
		var angle: float = (float(i) / 8.0) * TAU + rng.randf_range(-0.15, 0.15)
		var spd: float = rng.randf_range(110.0, 190.0)
		goal_effects.append({
			"type": "spark",
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"size": rng.randf_range(3.5, 6.5),
			"color": Color(1.0, 0.92, 0.40, 1.0) if i % 2 == 0 else Color(1.0, 0.65, 0.20, 1.0),
			"life": rng.randf_range(0.28, 0.42),
			"max_life": 0.42
		})


func _attach_spring_physics(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size / 2.0
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.07)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)


func _update_hint_button_text() -> void:
	if hint_button != null:
		var hint_str: String = loc_mgr.tr_text("BTN_HINT") if loc_mgr else "Hint"
		var count: int = save_mgr.get_hints_remaining() if save_mgr else 3
		hint_button.text = "%s (%d)" % [hint_str, count]


func _on_hints_changed(_new_count: int) -> void:
	_update_hint_button_text()


func _create_ad_reward_modal() -> PanelContainer:
	var modal: PanelContainer = PanelContainer.new()
	modal.name = "AdRewardModal"
	modal.anchors_preset = Control.PRESET_FULL_RECT
	modal.anchor_right = 1.0
	modal.anchor_bottom = 1.0
	modal.mouse_filter = Control.MOUSE_FILTER_STOP

	# Full dark backdrop scrim
	var bg_rect: ColorRect = ColorRect.new()
	bg_rect.anchors_preset = Control.PRESET_FULL_RECT
	bg_rect.anchor_right = 1.0
	bg_rect.anchor_bottom = 1.0
	bg_rect.color = Color(0.04, 0.06, 0.10, 0.88)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(bg_rect)

	# Center container
	var center: CenterContainer = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	modal.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 240)
	card.theme_type_variation = &"ConsoleCard"
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = loc_mgr.tr_text("MODAL_REWARD_TITLE") if loc_mgr else "NEED A HINT?"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	vbox.add_child(title_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = loc_mgr.tr_text("MODAL_REWARD_DESC") if loc_mgr else "You're out of hints. Watch a sponsor video to receive +3 Free Hints!"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
	vbox.add_child(desc_lbl)

	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_vbox)

	var watch_btn: Button = Button.new()
	watch_btn.name = "WatchAdBtn"
	watch_btn.text = loc_mgr.tr_text("BTN_WATCH_AD") if loc_mgr else "WATCH AD (+3 HINTS)"
	watch_btn.custom_minimum_size = Vector2(0, 46)
	watch_btn.theme_type_variation = &"PrimaryButton"
	watch_btn.pressed.connect(_on_watch_ad_pressed)
	_attach_spring_physics(watch_btn)
	btn_vbox.add_child(watch_btn)

	var close_btn: Button = Button.new()
	close_btn.name = "CloseRewardModalBtn"
	close_btn.text = loc_mgr.tr_text("BTN_CLOSE") if loc_mgr else "CLOSE"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(_hide_ad_reward_modal)
	_attach_spring_physics(close_btn)
	btn_vbox.add_child(close_btn)

	add_child(modal)
	return modal


func _show_ad_reward_modal() -> void:
	if ad_reward_modal == null:
		ad_reward_modal = _create_ad_reward_modal()
	ad_reward_modal.show()
	ad_reward_modal.modulate.a = 0.0
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ad_reward_modal, "modulate:a", 1.0, 0.18)


func _hide_ad_reward_modal() -> void:
	if ad_reward_modal != null:
		ad_reward_modal.hide()


func _on_watch_ad_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if ad_mgr != null:
		var ok: bool = ad_mgr.show_rewarded_for_hints()
		if not ok:
			_on_rewarded_hints_earned("hints", 3)
	else:
		_on_rewarded_hints_earned("hints", 3)


func _on_rewarded_hints_earned(reward_type: String, amount: int) -> void:
	if reward_type == "hints":
		if save_mgr != null:
			save_mgr.add_hints(amount)
		_hide_ad_reward_modal()
		_update_hint_button_text()
		var msg = loc_mgr.tr_text("TOAST_HINTS_ADDED") if loc_mgr else "+3 Hints Added!"
		_show_hint_toast(msg, Color(0.4, 1.0, 0.6))
		if audio_mgr:
			audio_mgr.play_win()
		if haptic_mgr:
			haptic_mgr.vibrate_target()
		_on_hint_pressed()


func _check_achievements() -> void:
	if achievement_mgr != null and save_mgr != null:
		var newly_unlocked: Array[String] = achievement_mgr.evaluate_progress(save_mgr)
		for id in newly_unlocked:
			var info = achievement_mgr.get_achievement_info(id)
			_show_achievement_toast(info)


func _show_achievement_toast(info: Dictionary) -> void:
	var ach_name: String = loc_mgr.tr_text(info.get("name_key", "")) if loc_mgr else info.get("name", "Achievement")
	var toast_text: String = "UNLOCKED: %s" % [ach_name]
	_show_hint_toast(toast_text, Color(1.0, 0.85, 0.25))
	if audio_mgr:
		audio_mgr.play_win()
	if haptic_mgr:
		haptic_mgr.vibrate_target()
