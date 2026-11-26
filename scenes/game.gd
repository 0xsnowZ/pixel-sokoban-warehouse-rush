extends Control

## Main playable game scene for Pixel Porter.
## Renders the grid, handles swipes and keyboard input, animates moves,
## and implements PRD Section 4 & 5 gameplay and UI requirements.

const SaveManagerScript: GDScript = preload("res://scripts/save_manager.gd")
const SokobanSolverScript: GDScript = preload("res://scripts/sokoban_solver.gd")
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"
const END_SCENE_PATH: String = "res://scenes/end_screen.tscn"

const MAX_DUST_PARTICLES: int = 36
const MAX_GOAL_EFFECTS: int = 32
const MAX_WIN_PARTICLES: int = 48
const MAX_VICTORY_RINGS: int = 16
const MAX_STAR_BURST_PARTICLES: int = 32

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Levels available (75 verified solvable levels)
var level_paths: Array[String] = _get_default_level_paths()
var current_level_index: int = 0

static func _get_default_level_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in range(1, 76):
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
var is_daily_challenge: bool = false
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

# Diegetic Living Warehouse: Tracking Security Camera (CCTV)
var cctv_camera_tile: Vector2i = Vector2i(-1, -1)
var cctv_current_angle: float = PI * 0.5
var cctv_target_angle: float = PI * 0.5
var cctv_active: bool = false
var cctv_tally_timer: float = 0.0
var cctv_motion_timer: float = 0.0
var cctv_alert_timer: float = 0.0
var cctv_sweep_phase: float = 0.0
var cctv_idle_pan_timer: float = 0.0

# Proactive Deadlock Radar (Ghost Warning Glyph)
var active_deadlocked_crates: Array[Vector2i] = []
var deadlock_pulse_timer: float = 0.0

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
	},
	{
		"id": 3,
		"name": "Quantum Vault",
		"icon": "⚛️",
		"frame_base": Color(0.08, 0.04, 0.14),
		"frame_rim": Color(0.85, 0.40, 1.00),
		"frame_groove": Color(0.04, 0.02, 0.08),
		"bolt_dark": Color(0.06, 0.02, 0.10),
		"bolt_core": Color(0.90, 0.50, 1.00),
		"bolt_specular": Color(1.00, 0.85, 1.00),
		"floor_tint": Color(0.90, 0.84, 0.98),
		"wall_tint": Color(1.0, 1.0, 1.0),
		"goal_aura": Color(0.85, 0.35, 1.00),
		"goal_core": Color(0.95, 0.80, 1.00, 0.95),
		"crate_tint": Color(0.95, 0.90, 1.00),
		"dim_color": Color(0.06, 0.02, 0.10, 0.45),
		"badge_color": Color(0.85, 0.40, 1.00)
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
var is_star_tension: bool = false

# Animation state
var is_animating: bool = false
var queued_move_dir: Vector2i = Vector2i.ZERO # PRD Section 5: "A swipe made during a move animation is queued (one move only)"
var visual_player_pos: Vector2 = Vector2.ZERO
var visual_crates: Dictionary = {} # Vector2i (current logical) -> Vector2 (interpolated visual)
var walk_step_count: int = 0
var current_walk_frame: int = 0 # 0: idle stance, 1: walk frame 1, 2: walk frame 2

# Locomotion Juice & Character State (Option A)
var stride_arc_y: float = 0.0
var player_scale: Vector2 = Vector2.ONE
var landing_squash_tween: Tween = null
var held_move_dir: Vector2i = Vector2i.ZERO
var held_move_time: float = 0.0
var held_move_step_timer: float = 0.0
var _dpad_moved_on_down: bool = false

# Hint state (P3: Hint via Solver — multi-step walk + next push plan)
var active_hint_dir: Vector2i = Vector2i.ZERO
var hint_player_target: Vector2i = Vector2i.ZERO
var hint_crate_target: Vector2i = Vector2i.ZERO
var hint_has_crate: bool = false
var hint_walk_waypoints: Array[Vector2i] = []
var hint_push_from: Vector2i = Vector2i.ZERO
var hint_push_to: Vector2i = Vector2i.ZERO
var hint_push_dir: Vector2i = Vector2i.ZERO
var hint_has_push: bool = false
var hint_time_remaining: float = 0.0
var hint_pulse_timer: float = 0.0

# Touch / Swipe handling (PRD Section 5)
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touching: bool = false
var active_touch_index: int = -1
var swipe_triggered_in_gesture: bool = false
var preview_swipe_dir: Vector2i = Vector2i.ZERO
var tutorial_pulse_timer: float = 0.0
var board_intro_scale: float = 1.0
var board_intro_tween: Tween = null
const SWIPE_PREVIEW_PIXELS: float = 18.0
const SWIPE_THRESHOLD_PIXELS: float = 42.0
const CONTINUOUS_DRAG_THRESHOLD_PIXELS: float = 80.0

# Tap-to-Walk pathfinding state (Phase 1 QoL)
var auto_walk_path: Array[Vector2i] = []
var auto_walk_target: Vector2i = Vector2i(-1, -1)
var is_auto_walking: bool = false

var achievement_mgr: Node = null
var ad_reward_modal: PanelContainer = null
var achievement_banner: PanelContainer = null
var _achievement_banner_tw: Tween = null
var stage_picker_modal: PanelContainer = null
var deadlock_pill: PanelContainer = null

# UI references
@onready var top_bar: PanelContainer = $TopBar if has_node("TopBar") else null
@onready var bottom_bar: PanelContainer = $BottomBar if has_node("BottomBar") else null
@onready var top_bar_margin: MarginContainer = $TopBar/Margin
@onready var bottom_bar_margin: MarginContainer = $BottomBar/Margin
@onready var menu_button: Button = find_child("MenuBtn", true, false) as Button
@onready var music_button: Button = find_child("MusicBtn", true, false) as Button
@onready var control_button: Button = find_child("ControlBtn", true, false) as Button
@onready var stage_badge: PanelContainer = find_child("StageBadge", true, false) as PanelContainer
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
@onready var restart_dialog: Node = $RestartConfirmDialog
@onready var dim_overlay: ColorRect = $DimOverlay if has_node("DimOverlay") else null
@onready var moves_card: PanelContainer = $WinModal.find_child("MovesCard", true, false) as PanelContainer if has_node("WinModal") else null
@onready var time_card: PanelContainer = $WinModal.find_child("TimeCard", true, false) as PanelContainer if has_node("WinModal") else null
@onready var pushes_card: PanelContainer = $WinModal.find_child("PushesCard", true, false) as PanelContainer if has_node("WinModal") else null
@onready var moves_val_lbl: Label = moves_card.find_child("Val", true, false) as Label if moves_card else null
@onready var time_val_lbl: Label = time_card.find_child("Val", true, false) as Label if time_card else null
@onready var pushes_val_lbl: Label = pushes_card.find_child("Val", true, false) as Label if pushes_card else null
@onready var moves_title_lbl: Label = moves_card.find_child("Title", true, false) as Label if moves_card else null
@onready var time_title_lbl: Label = time_card.find_child("Title", true, false) as Label if time_card else null
@onready var pushes_title_lbl: Label = pushes_card.find_child("Title", true, false) as Label if pushes_card else null

var _idle_pulse_timer: float = 0.0
var level_start_time: int = 0

# Board sprite textures
var tex_wall_cargo: Texture2D = preload("res://assets/wall_brick.png")
var tex_wall_cold_storage: Texture2D = preload("res://assets/wall_cold_storage.png")
var tex_wall_cyber_depot: Texture2D = preload("res://assets/wall_cyber_depot.png")
var tex_wall_quantum_vault: Texture2D = preload("res://assets/wall_quantum_vault.png")
var tex_wall: Texture2D = tex_wall_cargo
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
var icon_trophy: Texture2D = preload("res://assets/icons/icon_trophy.png")
var icon_lock: Texture2D = preload("res://assets/icons/icon_lock.png")
var icon_check: Texture2D = preload("res://assets/icons/icon_check.png")


func _initialize_nodes() -> void:
	if has_node("Background"):
		$Background.show_behind_parent = true
	if has_node("BackdropBlur"):
		$BackdropBlur.show_behind_parent = true
	if has_node("DimOverlay"):
		$DimOverlay.show_behind_parent = true
	if top_bar == null and has_node("TopBar"):
		top_bar = $TopBar
	if bottom_bar == null and has_node("BottomBar"):
		bottom_bar = $BottomBar
	if top_bar_margin == null and has_node("TopBar/Margin"):
		top_bar_margin = $TopBar/Margin
		bottom_bar_margin = $BottomBar/Margin
	if menu_button == null:
		menu_button = find_child("MenuBtn", true, false) as Button
	if music_button == null:
		music_button = find_child("MusicBtn", true, false) as Button
	if control_button == null:
		control_button = find_child("ControlBtn", true, false) as Button
	if stage_badge == null:
		stage_badge = find_child("StageBadge", true, false) as PanelContainer
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
	_rng.randomize()
	ResourceLoader.load_threaded_request(MAIN_MENU_SCENE_PATH)
	ResourceLoader.load_threaded_request(END_SCENE_PATH)
	if save_mgr == null:
		if is_inside_tree() and get_tree().root.has_node("SaveManager"):
			save_mgr = get_tree().root.get_node("SaveManager")
		else:
			save_mgr = SaveManagerScript.new()
			add_child(save_mgr)

	if save_mgr != null and save_mgr.has_meta("is_daily_challenge") and bool(save_mgr.get_meta("is_daily_challenge")):
		is_daily_challenge = true
		save_mgr.set_meta("is_daily_challenge", false)

	if audio_mgr == null and is_inside_tree() and get_tree().root.has_node("AudioManager"):
		audio_mgr = get_tree().root.get_node("AudioManager")

	if loc_mgr == null and is_inside_tree() and get_tree().root.has_node("LocalizationManager"):
		loc_mgr = get_tree().root.get_node("LocalizationManager")
	if loc_mgr and not loc_mgr.language_changed.is_connected(_update_ui):
		loc_mgr.language_changed.connect(_update_ui)

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
	if stage_badge != null and not stage_badge.gui_input.is_connected(_on_stage_badge_gui_input):
		stage_badge.gui_input.connect(_on_stage_badge_gui_input)
	if dpad_up != null:
		if not dpad_up.pressed.is_connected(_on_dpad_up_pressed):
			dpad_up.pressed.connect(_on_dpad_up_pressed)
		if not dpad_up.button_down.is_connected(_on_dpad_up_down):
			dpad_up.button_down.connect(_on_dpad_up_down)
		if not dpad_up.button_up.is_connected(_on_dpad_up_up):
			dpad_up.button_up.connect(_on_dpad_up_up)
	if dpad_down != null:
		if not dpad_down.pressed.is_connected(_on_dpad_down_pressed):
			dpad_down.pressed.connect(_on_dpad_down_pressed)
		if not dpad_down.button_down.is_connected(_on_dpad_down_down):
			dpad_down.button_down.connect(_on_dpad_down_down)
		if not dpad_down.button_up.is_connected(_on_dpad_down_up):
			dpad_down.button_up.connect(_on_dpad_down_up)
	if dpad_left != null:
		if not dpad_left.pressed.is_connected(_on_dpad_left_pressed):
			dpad_left.pressed.connect(_on_dpad_left_pressed)
		if not dpad_left.button_down.is_connected(_on_dpad_left_down):
			dpad_left.button_down.connect(_on_dpad_left_down)
		if not dpad_left.button_up.is_connected(_on_dpad_left_up):
			dpad_left.button_up.connect(_on_dpad_left_up)
	if dpad_right != null:
		if not dpad_right.pressed.is_connected(_on_dpad_right_pressed):
			dpad_right.pressed.connect(_on_dpad_right_pressed)
		if not dpad_right.button_down.is_connected(_on_dpad_right_down):
			dpad_right.button_down.connect(_on_dpad_right_down)
		if not dpad_right.button_up.is_connected(_on_dpad_right_up):
			dpad_right.button_up.connect(_on_dpad_right_up)
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
		if "ok_button_text" in restart_dialog:
			restart_dialog.ok_button_text = loc_mgr.tr_text("BTN_RESTART")
		if "cancel_button_text" in restart_dialog:
			restart_dialog.cancel_button_text = loc_mgr.tr_text("BTN_CLOSE")
		var title_tr: String = loc_mgr.tr_text("RESTART_TITLE")
		if title_tr != "RESTART_TITLE" and "title_text" in restart_dialog:
			restart_dialog.title_text = title_tr

	var initial_level: int = 0
	if save_mgr and save_mgr.last_played_level >= 0 and save_mgr.last_played_level < level_paths.size():
		initial_level = save_mgr.last_played_level
	load_level(initial_level)
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)

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

	# Industrial Operator Console Hardware Overlays
	if top_bar != null and not top_bar.draw.is_connected(_on_top_bar_draw):
		top_bar.draw.connect(_on_top_bar_draw)
	if bottom_bar != null and not bottom_bar.draw.is_connected(_on_bottom_bar_draw):
		bottom_bar.draw.connect(_on_bottom_bar_draw)
	if bottom_bar != null and not bottom_bar.resized.is_connected(_update_dpad_position):
		bottom_bar.resized.connect(_update_dpad_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_mobile_back_request()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_application_paused()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_application_resumed()


func _handle_mobile_back_request() -> void:
	if stage_picker_modal != null and stage_picker_modal.visible:
		_hide_stage_picker()
		if get_viewport(): get_viewport().set_input_as_handled()
	elif ad_reward_modal != null and ad_reward_modal.visible:
		ad_reward_modal.hide()
		if get_viewport(): get_viewport().set_input_as_handled()
	elif win_modal != null and win_modal.visible:
		_on_menu_pressed()
		if get_viewport(): get_viewport().set_input_as_handled()
	elif restart_dialog != null and restart_dialog.visible:
		restart_dialog.hide()
		_on_restart_dialog_canceled()
		if get_viewport(): get_viewport().set_input_as_handled()
	else:
		_on_restart_pressed()
		if get_viewport(): get_viewport().set_input_as_handled()


func _on_application_paused() -> void:
	is_undo_held = false
	undo_hold_time = 0.0
	undo_step_timer = 0.0
	_stop_held_move()
	_stop_auto_walk()
	_dpad_moved_on_down = false
	is_touching = false
	active_touch_index = -1
	swipe_triggered_in_gesture = false
	if save_mgr != null and save_mgr.has_method("save_data"):
		save_mgr.save_data()


func _on_application_resumed() -> void:
	_apply_safe_area()
	calculate_layout()
	queue_redraw()


func _transition_to_scene(path: String) -> void:
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
		if scene != null:
			get_tree().change_scene_to_packed(scene)
			return
	get_tree().change_scene_to_file(path)


func _apply_safe_area() -> void:
	if safe_area_mgr != null:
		if top_bar_margin != null:
			safe_area_mgr.apply_safe_area_margins(top_bar_margin, 16, 10, 16, 10, true, false)
		if bottom_bar_margin != null:
			safe_area_mgr.apply_safe_area_margins(bottom_bar_margin, 16, 10, 16, 10, false, true)
	_update_dpad_position()
	_update_hint_toast_position()
	_update_achievement_banner_position()
	_update_deadlock_pill()
	calculate_layout()
	queue_redraw()


func _on_safe_area_changed(_insets: Dictionary) -> void:
	_apply_safe_area()


func _on_viewport_size_changed() -> void:
	_layout_dirty = true
	_apply_safe_area()
	calculate_layout()
	_update_hint_toast_position()
	_update_achievement_banner_position()
	_update_deadlock_pill()
	queue_redraw()


func get_chapter_index(level_idx: int = -1) -> int:
	var l_idx: int = current_level_index if level_idx < 0 else level_idx
	if save_mgr and save_mgr.has_method("get_chapter_index"):
		return save_mgr.get_chapter_index(l_idx)
	if l_idx < 15:
		return 0
	elif l_idx < 35:
		return 1
	elif l_idx < 50:
		return 2
	return 3


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

	if dim_overlay:
		dim_overlay.color = ch["dim_color"]
	if has_node("BackdropBlur") and $BackdropBlur.material is ShaderMaterial:
		var blur_tint: Color = ch["dim_color"]
		blur_tint.a = clampf(blur_tint.a, 0.34, 0.54)
		($BackdropBlur.material as ShaderMaterial).set_shader_parameter("tint_color", blur_tint)

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
	_stop_held_move()
	_stop_auto_walk()
	_dpad_moved_on_down = false
	stride_arc_y = 0.0
	player_scale = Vector2.ONE
	if landing_squash_tween and landing_squash_tween.is_valid():
		landing_squash_tween.kill()
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
	_init_security_camera()
	player_idle_time = 0.0
	consecutive_wall_bumps = 0
	sweat_drop_timer = 0.0
	_prev_live_stars = 3

	# Initialize harmonic goal docking progress
	if audio_mgr and audio_mgr.has_method("set_dock_progress") and grid != null:
		var init_docked: int = 0
		for c_pos in grid.crates.keys():
			if grid.goals.has(c_pos):
				init_docked += 1
		audio_mgr.set_dock_progress(init_docked, grid.goals.size(), true)

	_refresh_deadlock_radar(false)
	_set_swipe_preview_dir(Vector2i.ZERO)
	is_touching = false
	swipe_triggered_in_gesture = false
	tutorial_pulse_timer = 0.0
	if board_intro_tween and board_intro_tween.is_valid():
		board_intro_tween.kill()
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		board_intro_scale = 0.965
		board_intro_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		board_intro_tween.tween_property(self, "board_intro_scale", 1.0, 0.20)
	else:
		board_intro_scale = 1.0
	_update_ui()
	queue_redraw()


func _update_ui(_new_lang: String = "") -> void:
	var best_str: String = ""
	if save_mgr and save_mgr.is_level_completed(current_level_index):
		var rec: Dictionary = save_mgr.get_level_record(current_level_index)
		var best_m: int = rec.get("best_moves", 0)
		best_str = "   •   %s" % (loc_mgr.tr_text("GAME_BEST", [best_m]) if loc_mgr else "BEST: %d" % best_m)

	if chapter_badge != null:
		var ch_info: Dictionary = get_current_chapter_theme()
		chapter_badge.text = loc_mgr.tr_text("CHAPTER_BADGE", [current_chapter_idx + 1]) if loc_mgr else ("CH. %d" % [current_chapter_idx + 1])
		var badge_col: Color = ch_info.get("badge_color", Color(0.98, 0.82, 0.25))
		chapter_badge.modulate = Color.WHITE
		chapter_badge.add_theme_color_override("font_color", badge_col)

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
			is_star_tension = (cur_moves >= s3 - 1)
		elif cur_moves <= s2:
			live_stars = 2
			star_target_sub = " (≤%d)" % s2
			is_star_tension = (cur_moves >= s2 - 1)
		else:
			live_stars = 1
			star_target_sub = ""
			is_star_tension = false

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

		# Star change juicing animation & tactile spark feedback
		if live_stars < _prev_live_stars and star_gauge.is_inside_tree():
			star_gauge.pivot_offset = star_gauge.size / 2.0
			var tw_sg: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			star_gauge.scale = Vector2(1.35, 1.35)
			tw_sg.tween_property(star_gauge, "scale", Vector2.ONE, 0.30)
			add_trauma(0.12)
			if audio_mgr and audio_mgr.has_method("play_bump"):
				audio_mgr.play_bump()

			# Micro electrical sparks popping from lost star
			var rng: RandomNumberGenerator = _rng
			var sg_pos: Vector2 = star_gauge.global_position + star_gauge.size * 0.5
			for i in range(6):
				dust_particles.append({
					"pos": sg_pos + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-4.0, 4.0)),
					"vel": Vector2(rng.randf_range(-45.0, 45.0), rng.randf_range(20.0, 95.0)),
					"size": rng.randf_range(2.0, 3.8),
					"color": Color(1.0, 0.78, 0.22, 0.95),
					"life": rng.randf_range(0.20, 0.35),
					"max_life": 0.35
				})
		elif live_stars > _prev_live_stars and star_gauge.is_inside_tree():
			star_gauge.pivot_offset = star_gauge.size / 2.0
			var tw_sg: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			star_gauge.scale = Vector2(1.25, 1.25)
			tw_sg.tween_property(star_gauge, "scale", Vector2.ONE, 0.20)

	_prev_live_stars = live_stars

	if loc_mgr:
		if loc_mgr.has_method("apply_rtl"):
			for rtl_ctrl in [win_modal, restart_dialog, ad_reward_modal, hint_toast, achievement_banner, deadlock_pill]:
				if rtl_ctrl is Control:
					loc_mgr.apply_rtl(rtl_ctrl)
		if is_daily_challenge:
			var daily_info: Dictionary = save_mgr.get_daily_challenge_info() if save_mgr else {}
			var streak_val: int = daily_info.get("streak", 0)
			level_label.text = loc_mgr.tr_text("GAME_DAILY_SHIFT", [streak_val])
		else:
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
		if restart_dialog != null:
			if "ok_button_text" in restart_dialog:
				restart_dialog.ok_button_text = loc_mgr.tr_text("BTN_RESTART")
			if "cancel_button_text" in restart_dialog:
				restart_dialog.cancel_button_text = loc_mgr.tr_text("BTN_CLOSE")
			var title_tr: String = loc_mgr.tr_text("RESTART_TITLE")
			if title_tr != "RESTART_TITLE" and "title_text" in restart_dialog:
				restart_dialog.title_text = title_tr
	else:
		if is_daily_challenge:
			var daily_info: Dictionary = save_mgr.get_daily_challenge_info() if save_mgr else {}
			var streak_val: int = daily_info.get("streak", 0)
			level_label.text = "DAILY SHIFT • STREAK: %d" % streak_val
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
	if save_mgr and current_level_index == 0 and grid != null and grid.pushes_count > 0 and "has_completed_tutorial" in save_mgr and not save_mgr.has_completed_tutorial:
		save_mgr.has_completed_tutorial = true
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
		var docked_count: int = 0
		for c_pos in grid.crates.keys():
			if grid.goals.has(c_pos):
				docked_count += 1
		var total_goals: int = grid.goals.size()
		if audio_mgr:
			if audio_mgr.has_method("play_goal_lock"):
				audio_mgr.play_goal_lock(docked_count, total_goals)
			else:
				audio_mgr.play_push()
	else:
		if audio_mgr:
			if grid != null and grid.goals.has(from_pos) and audio_mgr.has_method("play_goal_unlock"):
				var remaining_docks: int = 0
				for c_pos in grid.crates.keys():
					if grid.goals.has(c_pos):
						remaining_docks += 1
				audio_mgr.play_goal_unlock(remaining_docks)
			elif audio_mgr.has_method("play_push"):
				audio_mgr.play_push(current_chapter_idx)

	if haptic_mgr:
		if grid != null and grid.goals.has(to_pos):
			haptic_mgr.vibrate_target()
		else:
			haptic_mgr.vibrate_push()

	if save_mgr:
		save_mgr.record_crate_push()
	_check_achievements()
	_refresh_deadlock_radar(true)


func _refresh_deadlock_radar(is_push: bool = false) -> void:
	var prev_empty: bool = active_deadlocked_crates.is_empty()
	active_deadlocked_crates = grid.get_deadlocked_crates() if grid != null else []
	if not active_deadlocked_crates.is_empty():
		if is_push and prev_empty:
			if audio_mgr and audio_mgr.has_method("play_deadlock"):
				audio_mgr.play_deadlock()
			if haptic_mgr and haptic_mgr.has_method("vibrate_bump"):
				haptic_mgr.vibrate_bump()
			cctv_alert_timer = 0.85
			add_trauma(0.08)
			if save_mgr and "has_seen_deadlock_tip" in save_mgr and not save_mgr.has_seen_deadlock_tip:
				save_mgr.has_seen_deadlock_tip = true
				if save_mgr.has_method("save_data"):
					save_mgr.save_data()
				var tip_msg: String = loc_mgr.tr_text("TOAST_FIRST_DEADLOCK") if loc_mgr else "Corner trap! Rewind Push anytime — no penalty"
				_show_hint_toast(tip_msg, Color(1.0, 0.55, 0.35))
	else:
		deadlock_pulse_timer = 0.0
		if is_instance_valid(undo_button) and undo_button.modulate != Color.WHITE:
			undo_button.modulate = Color.WHITE
	_update_deadlock_pill()


func _on_level_won() -> void:
	is_level_won = true
	if audio_mgr and audio_mgr.has_method("set_dock_progress") and grid != null:
		audio_mgr.set_dock_progress(grid.goals.size(), grid.goals.size(), false)
	_stop_held_move()
	_dpad_moved_on_down = false
	stride_arc_y = 0.0
	player_scale = Vector2.ONE
	if landing_squash_tween and landing_squash_tween.is_valid():
		landing_squash_tween.kill()

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
		if "has_completed_tutorial" in save_mgr and not save_mgr.has_completed_tutorial:
			save_mgr.has_completed_tutorial = true
		save_mgr.record_level_completion(current_level_index, grid.moves_count, grid.pushes_count)
		if is_daily_challenge:
			var d_res: Dictionary = save_mgr.record_daily_challenge_completed()
			var cur_streak: int = d_res.get("streak", 1)
			var daily_msg: String = loc_mgr.tr_text("TOAST_DAILY_CLEARED", [cur_streak]) if loc_mgr else ("DAILY SHIFT CLEARED! +3 HINTS • %d DAY STREAK" % cur_streak)
			_show_hint_toast(daily_msg, Color(1.0, 0.85, 0.25))
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
	if moves_val_lbl == null and win_modal != null:
		moves_card = win_modal.find_child("MovesCard", true, false) as PanelContainer
		time_card = win_modal.find_child("TimeCard", true, false) as PanelContainer
		pushes_card = win_modal.find_child("PushesCard", true, false) as PanelContainer
		moves_val_lbl = moves_card.find_child("Val", true, false) as Label if moves_card else null
		time_val_lbl = time_card.find_child("Val", true, false) as Label if time_card else null
		pushes_val_lbl = pushes_card.find_child("Val", true, false) as Label if pushes_card else null
		moves_title_lbl = moves_card.find_child("Title", true, false) as Label if moves_card else null
		time_title_lbl = time_card.find_child("Title", true, false) as Label if time_card else null
		pushes_title_lbl = pushes_card.find_child("Title", true, false) as Label if pushes_card else null

	if moves_val_lbl: moves_val_lbl.text = str(grid.moves_count)
	if time_val_lbl: time_val_lbl.text = time_formatted
	if pushes_val_lbl: pushes_val_lbl.text = str(grid.pushes_count)

	if level_placard_label:
		var ch_info: Dictionary = get_current_chapter_theme()
		var ch_title_text: String = loc_mgr.tr_text("CHAPTER_%d_TITLE" % current_chapter_idx) if loc_mgr else ch_info.get("name", "Cargo Bay")
		level_placard_label.text = loc_mgr.tr_text("WIN_LEVEL_PLACARD", [current_level_index + 1, ch_title_text.to_upper()]) if loc_mgr else ("LEVEL %d  •  %s" % [current_level_index + 1, ch_title_text.to_upper()])

	var is_master: bool = (grid.moves_count <= optimal_moves)
	if loc_mgr:
		if moves_title_lbl: moves_title_lbl.text = loc_mgr.tr_text("STAT_MOVES_TITLE")
		if time_title_lbl: time_title_lbl.text = loc_mgr.tr_text("STAT_TIME_TITLE")
		if pushes_title_lbl: pushes_title_lbl.text = loc_mgr.tr_text("STAT_PUSHES_TITLE")
		if win_title:
			win_title.text = loc_mgr.tr_text("WIN_BANNER_MASTER") if is_master else loc_mgr.tr_text("WIN_BANNER")
		if win_menu_button: win_menu_button.text = loc_mgr.tr_text("WIN_MENU_BTN")
		if win_retry_button: win_retry_button.text = loc_mgr.tr_text("WIN_RETRY_BTN")
		if next_level_button:
			if current_level_index >= level_paths.size() - 1:
				next_level_button.text = loc_mgr.tr_text("BTN_CAMPAIGN_COMPLETE")
			else:
				next_level_button.text = loc_mgr.tr_text("WIN_NEXT_BTN")
		if win_stats:
			if is_master:
				win_stats.text = loc_mgr.tr_text("WIN_TARGET_MASTER", [grid.moves_count])
			else:
				win_stats.text = loc_mgr.tr_text("WIN_TARGET_HINT", [three_star_target])
	else:
		if win_title:
			win_title.text = "👑 MASTER PAR ACHIEVED!" if is_master else "LEVEL COMPLETED!"
		if win_menu_button: win_menu_button.text = "MENU"
		if win_retry_button: win_retry_button.text = "RETRY"
		if next_level_button:
			if current_level_index >= level_paths.size() - 1:
				next_level_button.text = "Finish Campaign"
			else:
				next_level_button.text = "NEXT"
		if win_stats:
			if is_master:
				win_stats.text = "👑 PERFECT PAR: %d MOVES" % grid.moves_count
			else:
				win_stats.text = "Target: ≤ %d moves" % three_star_target

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
	var optimal_par: int = save_mgr.get_optimal_moves(current_level_index) if save_mgr else 10
	var is_master: bool = (grid != null and grid.moves_count <= optimal_par)

	for i in range(mini(earned, stars.size())):
		var s: Label = stars[i] as Label
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

	# Extra triumphant fanfare burst for Master Crown
	if is_master and earned >= 3:
		var crown_delay: float = 0.22 + 3.0 * 0.28 + 0.15
		var tw_crown: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_crown.tween_interval(crown_delay)
		tw_crown.tween_callback(func():
			if audio_mgr and audio_mgr.has_method("play_win"):
				audio_mgr.play_win()
			if haptic_mgr and haptic_mgr.has_method("vibrate_target"):
				haptic_mgr.vibrate_target()
			if win_modal != null:
				_spawn_star_burst(win_modal.get_global_rect().get_center())
				if win_title != null:
					var tw_t: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					tw_t.tween_property(win_title, "scale", Vector2(1.15, 1.15), 0.18)
					tw_t.tween_property(win_title, "scale", Vector2.ONE, 0.20)
		)


func _on_level_reset() -> void:
	is_animating = false
	queued_move_dir = Vector2i.ZERO
	current_walk_frame = 0
	walk_step_count = 0
	_stop_held_move()
	_stop_auto_walk()
	_dpad_moved_on_down = false
	stride_arc_y = 0.0
	player_scale = Vector2.ONE
	if landing_squash_tween and landing_squash_tween.is_valid():
		landing_squash_tween.kill()
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
	if audio_mgr and audio_mgr.has_method("set_dock_progress") and grid != null:
		var reset_docked: int = 0
		for c_pos in grid.crates.keys():
			if grid.goals.has(c_pos):
				reset_docked += 1
		audio_mgr.set_dock_progress(reset_docked, grid.goals.size(), false)
	_refresh_deadlock_radar(false)
	_set_swipe_preview_dir(Vector2i.ZERO)
	_update_ui()
	queue_redraw()


func _animate_player(from_pos: Vector2i, to_pos: Vector2i) -> void:
	is_animating = true
	walk_step_count += 1
	var step_base: int = 1 if (walk_step_count % 2 == 1) else 2
	current_walk_frame = step_base

	var was_push: bool = (grid != null and grid.last_move_pushed_crate)
	var move_dir: Vector2i = to_pos - from_pos

	cctv_motion_timer = 0.55
	cctv_idle_pan_timer = 0.0

	# Heavy pushing uses deliberate cubic ease-out curve; walking uses swift quad ease-out (brisker during auto-walk)
	var trans_mode: Tween.TransitionType = Tween.TRANS_CUBIC if was_push else Tween.TRANS_QUAD
	var anim_duration: float = 0.135 if was_push else (0.072 if is_auto_walking else 0.11)

	# Footstep floor dust puff when walking on empty floor (every 2 steps)
	if not was_push and (walk_step_count % 2 == 0):
		_spawn_footstep_dust(from_pos, to_pos)
	elif was_push:
		_spawn_push_friction_dust(from_pos, to_pos)

	if landing_squash_tween and landing_squash_tween.is_valid():
		landing_squash_tween.kill()

	var arc_h: float = -1.8 if was_push else -2.8
	var stretch_peak: float = 0.04 if was_push else 0.06

	var tween: Tween = create_tween().set_trans(trans_mode).set_ease(Tween.EASE_OUT)
	visual_player_pos = Vector2(from_pos)
	tween.tween_method(func(pos: Vector2):
		visual_player_pos = pos
		var dist: float = pos.distance_to(Vector2(from_pos))
		var progress: float = clampf(dist, 0.0, 1.0)
		stride_arc_y = sin(progress * PI) * arc_h

		# Mid-stride directional stretch along movement axis
		var stretch: float = sin(progress * PI) * stretch_peak
		if move_dir.x != 0:
			player_scale = Vector2(1.0 + stretch, 1.0 - stretch * 0.7)
		else:
			player_scale = Vector2(1.0 - stretch * 0.7, 1.0 + stretch)

		if dist > 0.5:
			current_walk_frame = 2 if step_base == 1 else 1
		else:
			current_walk_frame = step_base
		queue_redraw()
	, Vector2(from_pos), Vector2(to_pos), anim_duration)
	tween.tween_callback(func():
		is_animating = false
		current_walk_frame = 0
		visual_player_pos = Vector2(to_pos)
		stride_arc_y = 0.0

		# Snappy landing squash anchored at boots on floor
		var squash_x: float = 1.08 if not was_push else 1.05
		var squash_y: float = 0.92 if not was_push else 0.95
		player_scale = Vector2(squash_x, squash_y)
		landing_squash_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		landing_squash_tween.tween_property(self, "player_scale", Vector2.ONE, 0.09)
		landing_squash_tween.tween_callback(queue_redraw)

		queue_redraw()
		# Process queued move if one was buffered during animation (PRD Section 5)
		if queued_move_dir != Vector2i.ZERO:
			_stop_auto_walk()
			var dir_to_run: Vector2i = queued_move_dir
			queued_move_dir = Vector2i.ZERO
			try_move(dir_to_run)
		elif is_auto_walking:
			if not auto_walk_path.is_empty():
				_step_auto_walk()
			else:
				_stop_auto_walk()
	)


func _spawn_push_friction_dust(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var dir: Vector2i = to_pos - from_pos
	var crate_origin: Vector2 = grid_origin + Vector2(to_pos) * tile_size
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var contact_pt: Vector2 = crate_origin + Vector2(tile_size * 0.5, tile_size * 0.5) - Vector2(dir) * (tile_size * 0.46)
	if dir.y == 0:
		contact_pt.y = crate_origin.y + tile_size * 0.84
	elif dir.y > 0:
		contact_pt.y = crate_origin.y + tile_size * 0.10
	else:
		contact_pt.y = crate_origin.y + tile_size * 0.90

	var rng: RandomNumberGenerator = _rng
	for i in range(4):
		var lateral: Vector2 = perp * rng.randf_range(-16.0, 16.0) - Vector2(dir) * rng.randf_range(6.0, 18.0)
		dust_particles.append({
			"pos": contact_pt + perp * rng.randf_range(-5.0, 5.0) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
			"vel": lateral + Vector2(0.0, rng.randf_range(-6.0, 2.0)),
			"size": rng.randf_range(2.0, 3.4),
			"color": Color(0.78, 0.72, 0.62, 0.55),
			"life": rng.randf_range(0.18, 0.28),
			"max_life": 0.28
		})


func _spawn_footstep_dust(from_pos: Vector2i, _to_pos: Vector2i) -> void:
	var base_origin: Vector2 = grid_origin + Vector2(from_pos) * tile_size
	var foot_pos: Vector2 = base_origin + Vector2(tile_size * 0.5, tile_size * 0.80)
	var rng: RandomNumberGenerator = _rng
	for i in range(2):
		dust_particles.append({
			"pos": foot_pos + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-2.0, 2.0)),
			"vel": Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-8.0, 4.0)),
			"size": rng.randf_range(1.6, 2.6),
			"color": Color(0.70, 0.65, 0.58, 0.40),
			"life": rng.randf_range(0.18, 0.25),
			"max_life": 0.25
		})


func _animate_crate(from_pos: Vector2i, to_pos: Vector2i) -> void:
	visual_crates.erase(from_pos)
	visual_crates[to_pos] = Vector2(from_pos)
	# Crate uses weighty cubic ease-out curve for heavy industrial mass
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(val: Vector2):
		visual_crates[to_pos] = val
		queue_redraw()
	, Vector2(from_pos), Vector2(to_pos), 0.135)

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


func try_move(dir: Vector2i, from_auto_walk: bool = false) -> void:
	if not from_auto_walk:
		_stop_auto_walk()
	player_facing_dir = dir
	clear_hint()
	if win_modal != null and win_modal.visible:
		return
	if stage_picker_modal != null and stage_picker_modal.visible:
		return

	if is_animating:
		# PRD Section 5: "A swipe made during a move animation is queued (one move only)."
		queued_move_dir = dir
		return

	if grid != null:
		var moved: bool = grid.move(dir)
		if not moved:
			if from_auto_walk:
				_stop_auto_walk()
			_trigger_bump_recoil(dir)


func _trigger_bump_recoil(dir: Vector2i) -> void:
	if is_animating:
		return
	add_trauma(0.14)
	consecutive_wall_bumps += 1
	cctv_alert_timer = 0.65
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

	# Micro contact dust specks kicking back from wall impact
	var p_center: Vector2 = grid_origin + visual_player_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
	var contact_pt: Vector2 = p_center + Vector2(dir) * (tile_size * 0.44)
	var rng: RandomNumberGenerator = _rng
	for i in range(3):
		var lateral: Vector2 = Vector2(-dir.y, dir.x) * rng.randf_range(-20.0, 20.0) - Vector2(dir) * rng.randf_range(15.0, 35.0)
		dust_particles.append({
			"pos": contact_pt + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0)),
			"vel": lateral,
			"size": rng.randf_range(1.8, 3.2),
			"color": Color(0.80, 0.75, 0.68, 0.60),
			"life": rng.randf_range(0.18, 0.28),
			"max_life": 0.28
		})

	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "bump_offset", Vector2.ZERO, 0.12)
	tw.tween_callback(queue_redraw)


func trigger_sweat_drop() -> void:
	sweat_drop_timer = 1.4
	queue_redraw()


func _is_touch_on_ui(pos: Vector2) -> bool:
	if win_modal != null and win_modal.visible:
		return true
	if restart_dialog != null and restart_dialog.visible:
		return true
	if ad_reward_modal != null and ad_reward_modal.visible:
		return true
	if stage_picker_modal != null and stage_picker_modal.visible:
		return true
	if deadlock_pill != null and deadlock_pill.is_visible_in_tree() and deadlock_pill.get_global_rect().has_point(pos):
		return true

	# Top bar region (TopBar header and status bar / cutout)
	var top_h: float = 96.0
	if safe_area_mgr != null:
		var insets: Dictionary = safe_area_mgr.get_safe_insets(self)
		top_h += insets.get("top", 0.0)
	if top_bar != null and top_bar.size.y > 0.0:
		top_h = maxf(top_h, top_bar.position.y + top_bar.size.y)
	if pos.y <= top_h:
		return true

	# Bottom bar region (BottomBar actions and bottom inset)
	var bot_h: float = 72.0
	if safe_area_mgr != null:
		var insets: Dictionary = safe_area_mgr.get_safe_insets(self)
		bot_h += insets.get("bottom", 0.0)
	var current_h: float = size.y if size.y > 0.0 else 960.0
	if pos.y >= (current_h - bot_h):
		return true

	# D-Pad overlay (when visible in D-Pad or Dual mode)
	if dpad_overlay != null and dpad_overlay.is_visible_in_tree() and dpad_overlay.get_global_rect().has_point(pos):
		return true

	return false


func _unhandled_input(event: InputEvent) -> void:
	# Primary reactive handler for Android touch, drag, and mobile gameplay inputs
	_process_game_input(event)


func _input(event: InputEvent) -> void:
	# Supports direct calls from automated test suites in headless mode
	# while allowing normal GUI Control nodes to consume touch events first at runtime
	if not is_inside_tree() or get_tree().root == null or DisplayServer.get_name() == "headless":
		_process_game_input(event)


func _gui_input(event: InputEvent) -> void:
	# Receives touch and drag events if captured by the root Game Control
	_process_game_input(event)


func _start_held_move(dir: Vector2i) -> void:
	held_move_dir = dir
	held_move_time = 0.0
	held_move_step_timer = 0.0


func _stop_held_move(dir: Vector2i = Vector2i.ZERO) -> void:
	if dir == Vector2i.ZERO or held_move_dir == dir:
		held_move_dir = Vector2i.ZERO
		held_move_time = 0.0
		held_move_step_timer = 0.0


func _process_game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo():
		_handle_mobile_back_request()
		return

	if win_modal != null and win_modal.visible:
		return
	if restart_dialog != null and restart_dialog.visible:
		return
	if ad_reward_modal != null and ad_reward_modal.visible:
		return
	if stage_picker_modal != null and stage_picker_modal.visible:
		return

	# Keyboard navigation (Desktop / Testing) with Rapid Rewind on Hold & Corridor Auto-Repeat
	if event is InputEventKey:
		if event.keycode in [KEY_Z, KEY_U, KEY_BACKSPACE]:
			if event.is_pressed() and not event.is_echo():
				if event.keycode == KEY_Z and (event.shift_pressed or event.ctrl_pressed):
					_on_undo_push_pressed()
				else:
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
					_start_held_move(Vector2i.UP)
					try_move(Vector2i.UP)
				KEY_DOWN, KEY_S:
					_start_held_move(Vector2i.DOWN)
					try_move(Vector2i.DOWN)
				KEY_LEFT, KEY_A:
					_start_held_move(Vector2i.LEFT)
					try_move(Vector2i.LEFT)
				KEY_RIGHT, KEY_D:
					_start_held_move(Vector2i.RIGHT)
					try_move(Vector2i.RIGHT)
				KEY_R:
					_on_restart_pressed()
				KEY_H:
					_on_hint_pressed()
		elif not event.is_pressed():
			match event.keycode:
				KEY_UP, KEY_W:
					_stop_held_move(Vector2i.UP)
				KEY_DOWN, KEY_S:
					_stop_held_move(Vector2i.DOWN)
				KEY_LEFT, KEY_A:
					_stop_held_move(Vector2i.LEFT)
				KEY_RIGHT, KEY_D:
					_stop_held_move(Vector2i.RIGHT)

	# Gamepad navigation (D-Pad & Face Buttons)
	elif event is InputEventJoypadButton:
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					_start_held_move(Vector2i.UP)
					try_move(Vector2i.UP)
				JOY_BUTTON_DPAD_DOWN:
					_start_held_move(Vector2i.DOWN)
					try_move(Vector2i.DOWN)
				JOY_BUTTON_DPAD_LEFT:
					_start_held_move(Vector2i.LEFT)
					try_move(Vector2i.LEFT)
				JOY_BUTTON_DPAD_RIGHT:
					_start_held_move(Vector2i.RIGHT)
					try_move(Vector2i.RIGHT)
				JOY_BUTTON_B:
					_on_undo_pressed()
				JOY_BUTTON_Y:
					_on_restart_pressed()
				JOY_BUTTON_X:
					_on_hint_pressed()
				JOY_BUTTON_START:
					_handle_mobile_back_request()
		else:
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					_stop_held_move(Vector2i.UP)
				JOY_BUTTON_DPAD_DOWN:
					_stop_held_move(Vector2i.DOWN)
				JOY_BUTTON_DPAD_LEFT:
					_stop_held_move(Vector2i.LEFT)
				JOY_BUTTON_DPAD_RIGHT:
					_stop_held_move(Vector2i.RIGHT)

	# 1. Native Mobile Screen Touch (Primary on Android & iOS devices)
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _is_touch_on_ui(event.position):
				if active_touch_index == -1:
					active_touch_index = event.index
					touch_start_pos = event.position
					is_touching = true
					swipe_triggered_in_gesture = false
		else:
			if is_touching and event.index == active_touch_index:
				if not swipe_triggered_in_gesture:
					var release_delta: Vector2 = event.position - touch_start_pos
					if release_delta.length() >= SWIPE_THRESHOLD_PIXELS:
						_handle_swipe(release_delta)
					elif release_delta.length() <= 18.0 and not _is_touch_on_ui(event.position):
						_try_tap_to_walk(event.position)
				is_touching = false
				active_touch_index = -1
				swipe_triggered_in_gesture = false

	# 2. Native Mobile Screen Drag (Deliberate swipe gesture; limits runaway repeated inputs)
	elif event is InputEventScreenDrag:
		if is_touching and (active_touch_index == -1 or event.index == active_touch_index):
			var drag_delta: Vector2 = event.position - touch_start_pos
			if not swipe_triggered_in_gesture:
				if drag_delta.length() >= SWIPE_THRESHOLD_PIXELS:
					_set_swipe_preview_dir(Vector2i.ZERO)
					_handle_swipe(drag_delta)
					swipe_triggered_in_gesture = true
					touch_start_pos = event.position
				elif drag_delta.length() >= SWIPE_PREVIEW_PIXELS:
					_set_swipe_preview_dir(_delta_to_cardinal_dir(drag_delta))
				else:
					_set_swipe_preview_dir(Vector2i.ZERO)
			else:
				_set_swipe_preview_dir(Vector2i.ZERO)
				# Continuous drag requires a large deliberate movement and finished animation
				if drag_delta.length() >= CONTINUOUS_DRAG_THRESHOLD_PIXELS and not is_animating:
					_handle_swipe(drag_delta)
					touch_start_pos = event.position

	# 3. Mouse Button (Desktop / Testing - ignored if physical screen touch is active)
	elif event is InputEventMouseButton and active_touch_index == -1:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not _is_touch_on_ui(event.position):
					is_touching = true
					touch_start_pos = event.position
					swipe_triggered_in_gesture = false
					_set_swipe_preview_dir(Vector2i.ZERO)
			else:
				if is_touching:
					_set_swipe_preview_dir(Vector2i.ZERO)
					if not swipe_triggered_in_gesture:
						var release_delta: Vector2 = event.position - touch_start_pos
						if release_delta.length() >= SWIPE_THRESHOLD_PIXELS:
							_handle_swipe(release_delta)
						elif release_delta.length() <= 18.0 and not _is_touch_on_ui(event.position):
							_try_tap_to_walk(event.position)
					is_touching = false
					swipe_triggered_in_gesture = false

	# 4. Mouse Motion (Desktop Drag - deliberate swipe gesture)
	elif event is InputEventMouseMotion and is_touching and active_touch_index == -1:
		var drag_delta: Vector2 = event.position - touch_start_pos
		if not swipe_triggered_in_gesture:
			if drag_delta.length() >= SWIPE_THRESHOLD_PIXELS:
				_set_swipe_preview_dir(Vector2i.ZERO)
				_handle_swipe(drag_delta)
				swipe_triggered_in_gesture = true
				touch_start_pos = event.position
			elif drag_delta.length() >= SWIPE_PREVIEW_PIXELS:
				_set_swipe_preview_dir(_delta_to_cardinal_dir(drag_delta))
			else:
				_set_swipe_preview_dir(Vector2i.ZERO)
		else:
			_set_swipe_preview_dir(Vector2i.ZERO)
			if drag_delta.length() >= CONTINUOUS_DRAG_THRESHOLD_PIXELS and not is_animating:
				_handle_swipe(drag_delta)
				touch_start_pos = event.position


func _delta_to_cardinal_dir(delta: Vector2) -> Vector2i:
	if abs(delta.x) > abs(delta.y):
		return Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP


func _set_swipe_preview_dir(dir: Vector2i) -> void:
	if save_mgr and "control_scheme" in save_mgr and save_mgr.control_scheme == 1:
		dir = Vector2i.ZERO
	if preview_swipe_dir != dir:
		preview_swipe_dir = dir
		queue_redraw()


func _handle_swipe(delta: Vector2) -> void:
	_set_swipe_preview_dir(Vector2i.ZERO)
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
			var title_tr: String = loc_mgr.tr_text("RESTART_TITLE")
			if title_tr != "RESTART_TITLE" and "title_text" in restart_dialog:
				restart_dialog.title_text = title_tr
		else:
			restart_dialog.dialog_text = "You've made %d moves. Restart this level?" % current_moves
		if audio_mgr and audio_mgr.has_method("duck_music"):
			audio_mgr.duck_music(-10.0, 0.2)
		if win_blur_overlay:
			win_blur_overlay.modulate.a = 0.0
			win_blur_overlay.show()
			var tw_blur: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_blur.tween_property(win_blur_overlay, "modulate:a", 0.85, 0.2)
		if restart_dialog.is_inside_tree():
			restart_dialog.popup_centered()
	else:
		_do_restart()


func _do_restart() -> void:
	if win_blur_overlay and not (win_modal and win_modal.visible):
		win_blur_overlay.hide()
	if audio_mgr:
		audio_mgr.play_restart()
		if audio_mgr.has_method("unduck_music"):
			audio_mgr.unduck_music(0.5)
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	if grid:
		grid.restart()


func _on_restart_dialog_canceled() -> void:
	if win_blur_overlay and not (win_modal and win_modal.visible):
		win_blur_overlay.hide()
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


func _get_actual_bottom_bar_height() -> float:
	var h: float = 72.0
	if bottom_bar_margin != null:
		var top_m: float = float(bottom_bar_margin.get_theme_constant("margin_top"))
		var bot_m: float = float(bottom_bar_margin.get_theme_constant("margin_bottom"))
		# 3.0 (top border) + margins + 48.0 (button height)
		var inner_h: float = 3.0 + top_m + 48.0 + bot_m
		h = maxf(h, inner_h)
	if bottom_bar != null:
		if bottom_bar.size.y > 0.0:
			h = maxf(h, bottom_bar.size.y)
		if is_inside_tree() and bottom_bar.position.y > 0.0:
			var vp_h: float = get_viewport_rect().size.y
			if vp_h > bottom_bar.position.y:
				h = maxf(h, vp_h - bottom_bar.position.y)
	if safe_area_mgr != null:
		var insets: Dictionary = safe_area_mgr.get_safe_insets(self)
		var safe_bottom: float = insets.get("bottom", 0.0)
		h = maxf(h, 72.0 + safe_bottom)
	return h


func _update_dpad_position() -> void:
	if dpad_overlay == null:
		return

	var bot_bar_h: float = _get_actual_bottom_bar_height()
	var clearance: float = 16.0
	var dpad_h: float = 164.0
	if dpad_overlay.size.y > 0.0:
		dpad_h = maxf(dpad_h, dpad_overlay.size.y)

	var half_w: float = 95.0
	if dpad_overlay.size.x > 0.0:
		half_w = dpad_overlay.size.x / 2.0

	dpad_overlay.offset_left = -half_w
	dpad_overlay.offset_right = half_w
	dpad_overlay.offset_bottom = -(bot_bar_h + clearance)
	dpad_overlay.offset_top = -(bot_bar_h + clearance + dpad_h)
	_update_deadlock_pill()


func _update_control_scheme_ui() -> void:
	var scheme: int = save_mgr.control_scheme if save_mgr and "control_scheme" in save_mgr else 0
	# 0 = Swipe, 1 = D-Pad, 2 = Dual
	var show_dpad: bool = (scheme == 1 or scheme == 2)
	if dpad_overlay:
		dpad_overlay.visible = show_dpad
	_update_dpad_position()
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


func _on_dpad_up_down() -> void:
	_dpad_moved_on_down = true
	_start_held_move(Vector2i.UP)
	try_move(Vector2i.UP)


func _on_dpad_up_up() -> void:
	_stop_held_move(Vector2i.UP)


func _on_dpad_up_pressed() -> void:
	if not _dpad_moved_on_down:
		try_move(Vector2i.UP)
	_dpad_moved_on_down = false


func _on_dpad_down_down() -> void:
	_dpad_moved_on_down = true
	_start_held_move(Vector2i.DOWN)
	try_move(Vector2i.DOWN)


func _on_dpad_down_up() -> void:
	_stop_held_move(Vector2i.DOWN)


func _on_dpad_down_pressed() -> void:
	if not _dpad_moved_on_down:
		try_move(Vector2i.DOWN)
	_dpad_moved_on_down = false


func _on_dpad_left_down() -> void:
	_dpad_moved_on_down = true
	_start_held_move(Vector2i.LEFT)
	try_move(Vector2i.LEFT)


func _on_dpad_left_up() -> void:
	_stop_held_move(Vector2i.LEFT)


func _on_dpad_left_pressed() -> void:
	if not _dpad_moved_on_down:
		try_move(Vector2i.LEFT)
	_dpad_moved_on_down = false


func _on_dpad_right_down() -> void:
	_dpad_moved_on_down = true
	_start_held_move(Vector2i.RIGHT)
	try_move(Vector2i.RIGHT)


func _on_dpad_right_up() -> void:
	_stop_held_move(Vector2i.RIGHT)


func _on_dpad_right_pressed() -> void:
	if not _dpad_moved_on_down:
		try_move(Vector2i.RIGHT)
	_dpad_moved_on_down = false


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
	_stop_auto_walk()
	is_animating = false
	queued_move_dir = Vector2i.ZERO
	clear_hint()
	if grid != null and grid.can_undo():
		if audio_mgr:
			if audio_mgr.has_method("play_undo"):
				audio_mgr.play_undo()
			else:
				audio_mgr.play_click()
		if haptic_mgr:
			haptic_mgr.vibrate_click()
		grid.undo()


func _on_undo_push_pressed() -> void:
	if win_modal != null and win_modal.visible:
		return
	_stop_auto_walk()
	is_animating = false
	queued_move_dir = Vector2i.ZERO
	clear_hint()
	if grid != null and grid.can_undo_push():
		if audio_mgr:
			if audio_mgr.has_method("play_undo"):
				audio_mgr.play_undo()
			else:
				audio_mgr.play_click()
		if haptic_mgr:
			haptic_mgr.vibrate_click()
		grid.undo_last_push()


func _on_move_undone(p_pos: Vector2i, _had_crate: bool, _crate_from: Vector2i, _crate_to: Vector2i) -> void:
	is_animating = false
	queued_move_dir = Vector2i.ZERO
	_stop_held_move()
	_dpad_moved_on_down = false
	stride_arc_y = 0.0
	player_scale = Vector2.ONE
	if landing_squash_tween and landing_squash_tween.is_valid():
		landing_squash_tween.kill()
	current_walk_frame = 0
	clear_hint()
	visual_player_pos = Vector2(p_pos)
	visual_crates.clear()
	for crate_pos in grid.crates.keys():
		visual_crates[crate_pos] = Vector2(crate_pos)
	if audio_mgr and audio_mgr.has_method("set_dock_progress") and grid != null:
		var reset_docked: int = 0
		for c_pos in grid.crates.keys():
			if grid.goals.has(c_pos):
				reset_docked += 1
		audio_mgr.set_dock_progress(reset_docked, grid.goals.size(), false)
	_refresh_deadlock_radar(false)
	_set_swipe_preview_dir(Vector2i.ZERO)
	_update_ui()
	queue_redraw()


func _on_hint_pressed() -> void:
	_stop_auto_walk()
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
	var walk_plan_waypoints: Array[Vector2i] = []
	var plan_has_push: bool = false
	var plan_push_from: Vector2i = Vector2i.ZERO
	var plan_push_to: Vector2i = Vector2i.ZERO
	var plan_push_dir: Vector2i = Vector2i.ZERO

	# 1. Fast check for walk-to-next-meaningful-push plan (instant 0ms lookup on verified path)
	var lvl_path: String = level_paths[current_level_index] if current_level_index < level_paths.size() else ""
	var plan: Dictionary = SokobanSolverScript.get_next_push_plan(grid, current_level_index, lvl_path, 12)
	var plan_first: String = plan.get("first_char", "")
	if not plan_first.is_empty():
		move_char = plan_first
		var raw_wp: Array = plan.get("walk_waypoints", [])
		for wp in raw_wp:
			if wp is Vector2i:
				walk_plan_waypoints.append(wp)
		plan_has_push = bool(plan.get("has_push", false))
		plan_push_from = plan.get("push_from", Vector2i.ZERO)
		plan_push_to = plan.get("push_to", Vector2i.ZERO)
		plan_push_dir = plan.get("push_dir", Vector2i.ZERO)
	elif bool(plan.get("deadlock", false)):
		is_confirmed_deadlock = true
	else:
		# 2. Check if player has placed a crate into an immediate unresolvable deadlock
		if grid.has_deadlock():
			is_confirmed_deadlock = true
		else:
			# 3. High-speed solver search for custom player paths
			var result: SokobanSolver.SolverResult = SokobanSolverScript.solve(grid, 15000)
			if result.is_solvable and not result.solution_str.is_empty():
				move_char = result.solution_str.substr(0, 1)
				var trace_grid: GridLogic = grid.clone()
				var step_cap: int = mini(result.solution_str.length(), 12)
				for si in range(step_cap):
					var sc: String = result.solution_str.substr(si, 1)
					var sd: Vector2i = Vector2i.ZERO
					match sc:
						"u": sd = Vector2i.UP
						"d": sd = Vector2i.DOWN
						"l": sd = Vector2i.LEFT
						"r": sd = Vector2i.RIGHT
					if sd == Vector2i.ZERO:
						break
					var pre_p: Vector2i = trace_grid.player_pos
					var target_tile: Vector2i = pre_p + sd
					var will_push: bool = trace_grid.has_crate(target_tile)
					if not trace_grid.move(sd):
						break
					walk_plan_waypoints.append(trace_grid.player_pos)
					if will_push:
						plan_has_push = true
						plan_push_from = target_tile
						plan_push_to = target_tile + sd
						plan_push_dir = sd
						break
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
		hint_walk_waypoints.clear()
		hint_has_push = false
		hint_push_from = Vector2i.ZERO
		hint_push_to = Vector2i.ZERO
		hint_push_dir = Vector2i.ZERO
		queue_redraw()
		return

	# Deduct 1 hint from inventory only when solution step was found
	if save_mgr != null:
		save_mgr.use_hint()
		_update_hint_button_text()

	# Solvable next step / push plan
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
	hint_walk_waypoints = walk_plan_waypoints
	hint_has_push = plan_has_push
	hint_push_from = plan_push_from
	hint_push_to = plan_push_to
	hint_push_dir = plan_push_dir
	hint_time_remaining = 5.0 if hint_walk_waypoints.size() > 1 else 4.0
	hint_pulse_timer = 0.0

	var dir_key: String = "UP"
	var hint_loc_key: String = "HINT_STEP_UP"
	if active_hint_dir == Vector2i.DOWN:
		dir_key = "DOWN"
		hint_loc_key = "HINT_STEP_DOWN"
	elif active_hint_dir == Vector2i.LEFT:
		dir_key = "LEFT"
		hint_loc_key = "HINT_STEP_LEFT"
	elif active_hint_dir == Vector2i.RIGHT:
		dir_key = "RIGHT"
		hint_loc_key = "HINT_STEP_RIGHT"

	var toast_msg: String
	if hint_walk_waypoints.size() > 1 and hint_has_push:
		toast_msg = loc_mgr.tr_text("HINT_PUSH_PLAN") if loc_mgr else "Hint: Follow path & push crate"
	else:
		toast_msg = loc_mgr.tr_text(hint_loc_key) if loc_mgr else ("Hint: Move " + dir_key)
	_show_hint_toast(toast_msg, Color(1.0, 0.95, 0.6))
	queue_redraw()


func _show_hint_toast(msg: String, color: Color = Color(1.0, 0.95, 0.6)) -> void:
	if hint_toast == null or hint_toast_label == null:
		return
	_update_hint_toast_position()
	hint_toast_label.text = msg
	hint_toast_label.modulate = color
	hint_toast.modulate.a = 0.0
	hint_toast.show()
	_update_achievement_banner_position()
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
	hint_has_crate = false
	hint_walk_waypoints.clear()
	hint_has_push = false
	hint_push_from = Vector2i.ZERO
	hint_push_to = Vector2i.ZERO
	hint_push_dir = Vector2i.ZERO
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

	# If completing the final level (Level 75), navigate to the Campaign End Screen (PRD Section 6)
	if current_level_index >= level_paths.size() - 1:
		_transition_to_scene(END_SCENE_PATH)
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
		if audio_mgr.has_method("reset_to_menu_music"):
			audio_mgr.reset_to_menu_music()
		elif audio_mgr.has_method("set_dock_progress"):
			audio_mgr.set_dock_progress(0, 0, false)
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_transition_to_scene(MAIN_MENU_SCENE_PATH)


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

	var rng: RandomNumberGenerator = _rng

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
	var rng: RandomNumberGenerator = _rng
	victory_radiance_rings.append({
		"pos": center_pt,
		"radius": 14.0,
		"max_radius": 52.0,
		"life": 0.36,
		"max_life": 0.36,
		"color": Color(1.0, 0.92, 0.35, 0.95)
	})
	for i in range(18):
		var angle: float = rng.randf_range(0.0, TAU)
		var speed: float = rng.randf_range(80.0, 240.0)
		var life: float = rng.randf_range(0.38, 0.70)
		var col: Color = Color(1.0, rng.randf_range(0.85, 1.0), rng.randf_range(0.25, 0.50))
		star_burst_particles.append({
			"pos": center_pt,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": life,
			"max_life": life,
			"size": rng.randf_range(4.0, 7.5),
			"color": col
		})


func _process(delta: float) -> void:
	var needs_redraw: bool = is_animating

	# Option A: Continuous corridor walking when direction key or D-Pad is held
	if held_move_dir != Vector2i.ZERO and (win_modal == null or not win_modal.visible) and (restart_dialog == null or not restart_dialog.visible) and (ad_reward_modal == null or not ad_reward_modal.visible):
		held_move_time += delta
		if held_move_time >= 0.22: # 220ms initial hold threshold
			held_move_step_timer += delta
			if held_move_step_timer >= 0.125 and not is_animating: # 125ms repeat step
				held_move_step_timer = 0.0
				try_move(held_move_dir)

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

	# Dynamic LED Tension Pulse on Star Gauge when nearing move limit
	if star_gauge != null and star_gauge.is_inside_tree():
		if is_star_tension:
			needs_redraw = true
			var tension_t: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
			var base_col: Color = Color(1.0, 0.85, 0.25) if _prev_live_stars == 3 else Color(0.95, 0.72, 0.20)
			var warn_col: Color = Color(1.0, 0.42, 0.12)
			star_gauge.modulate = base_col.lerp(warn_col, tension_t)

	# Update hint ghost timer
	if hint_time_remaining > 0.0:
		needs_redraw = true
		hint_time_remaining -= delta
		hint_pulse_timer += delta
		if hint_time_remaining <= 0.0:
			clear_hint()

	# First-shift onboarding directional cue pulse & board intro settle
	var onboarding_active: bool = (current_level_index == 0 and grid != null and grid.moves_count == 0 and (save_mgr == null or not ("has_completed_tutorial" in save_mgr and save_mgr.has_completed_tutorial)))
	if onboarding_active:
		tutorial_pulse_timer += delta
		needs_redraw = true
	if board_intro_scale < 0.999:
		needs_redraw = true

	# Subtle continuous breathing pulse for goals: throttled to 30 FPS during idle to conserve battery
	if grid and not grid.goals.is_empty():
		_idle_pulse_timer += delta
		if _idle_pulse_timer >= 0.033:
			_idle_pulse_timer = 0.0
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
				dust_particles[di] = dust_particles.back()
				dust_particles.pop_back()
			else:
				dp["pos"] += dp["vel"] * delta
				dp["vel"] *= (1.0 - 5.0 * delta)
				dp["size"] += 2.0 * delta
			di -= 1

	# Option B: Update floating ambient warehouse motes
	if not ambient_motes.is_empty() and (win_modal == null or not win_modal.visible):
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

	# Update Living Warehouse: Tracking Security Camera (CCTV)
	if cctv_active:
		if _update_security_camera(delta):
			needs_redraw = true

	# Proactive Deadlock Radar: animate pulse and soft Undo button shimmer
	if not active_deadlocked_crates.is_empty():
		deadlock_pulse_timer += delta * 4.5
		needs_redraw = true
		if is_instance_valid(undo_button) and not undo_button.disabled:
			var u_pulse: float = 0.5 + 0.5 * sin(deadlock_pulse_timer)
			undo_button.modulate = Color.WHITE.lerp(Color(1.0, 0.45, 0.40), u_pulse)
	else:
		if is_instance_valid(undo_button) and undo_button.modulate != Color.WHITE:
			undo_button.modulate = Color.WHITE

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
				goal_effects[gi] = goal_effects.back()
				goal_effects.pop_back()
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
				victory_radiance_rings[vi] = victory_radiance_rings.back()
				victory_radiance_rings.pop_back()
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
				star_burst_particles[si] = star_burst_particles.back()
				star_burst_particles.pop_back()
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
				win_particles[i] = win_particles.back()
				win_particles.pop_back()
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

	var viewport_size: Vector2 = custom_viewport_size
	if viewport_size == Vector2.ZERO:
		if is_inside_tree() and get_viewport() != null:
			viewport_size = get_viewport_rect().size
		elif size.x > 0.0 and size.y > 0.0:
			viewport_size = size
		else:
			viewport_size = Vector2(540.0, 960.0)

	var insets: Dictionary = safe_area_mgr.get_safe_insets(self) if safe_area_mgr else { "top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0 }
	var safe_top: float = insets.get("top", 0.0)
	var safe_bottom: float = insets.get("bottom", 0.0)
	var safe_horiz: float = insets.get("left", 0.0) + insets.get("right", 0.0)

	var top_bar_h: float = 96.0 + safe_top
	if top_bar != null and top_bar.size.y > 0.0:
		top_bar_h = maxf(top_bar_h, top_bar.size.y)
	var top_offset: float = top_bar_h + 10.0

	var bot_bar_h: float = _get_actual_bottom_bar_height()

	var dpad_allowance: float = 0.0
	if dpad_overlay and dpad_overlay.visible:
		_update_dpad_position()
		dpad_allowance = 190.0
	var bottom_offset: float = bot_bar_h + 10.0 + dpad_allowance

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
	var using_intro_scale: bool = board_intro_scale < 0.999
	if using_intro_scale:
		var board_center: Vector2 = effective_origin + board_pixel_size * 0.5
		draw_set_transform(board_center * (1.0 - board_intro_scale), 0.0, Vector2(board_intro_scale, board_intro_scale))

	var is_non_square: bool = is_level_non_square()

	# 1. Industrial Warehouse 2.5D Silhouette Drop Shadow (Natural depth, no artificial border frames or screws)
	if not is_non_square:
		# Fast path: Solid rectangular warehouse room; batch entire silhouette shadow into 3 passes
		var full_rect: Rect2 = Rect2(effective_origin, board_pixel_size)
		draw_rect(Rect2(full_rect.position + Vector2(8, 12), full_rect.size + Vector2(6, 6)), Color(0.0, 0.0, 0.0, 0.12))
		draw_rect(Rect2(full_rect.position + Vector2(5, 7), full_rect.size + Vector2(3, 3)), Color(0.0, 0.0, 0.0, 0.24))
		draw_rect(Rect2(full_rect.position + Vector2(2, 3), full_rect.size), Color(0.0, 0.0, 0.0, 0.45))
	else:
		for y in range(grid.height):
			for x in range(grid.width):
				var pos: Vector2i = Vector2i(x, y)
				if not grid.is_exterior_void(pos):
					var s_rect: Rect2 = Rect2(effective_origin + Vector2(x, y) * tile_size, Vector2(tile_size, tile_size))
					# Layer 3: Distant soft ambient penumbra
					draw_rect(Rect2(s_rect.position + Vector2(8, 12), s_rect.size + Vector2(6, 6)), Color(0.0, 0.0, 0.0, 0.12))
					# Layer 2: Mid directional shadow
					draw_rect(Rect2(s_rect.position + Vector2(5, 7), s_rect.size + Vector2(3, 3)), Color(0.0, 0.0, 0.0, 0.24))
					# Layer 1: Tight perimeter contact depth
					draw_rect(Rect2(s_rect.position + Vector2(2, 3), s_rect.size), Color(0.0, 0.0, 0.0, 0.45))

	# 2A. Draw All Floor Tiles (Batched by floor texture to minimize draw calls)
	for y in range(grid.height):
		for x in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if not grid.is_wall(pos) and (grid.is_interior_floor(pos) or grid.interior_floor.is_empty()):
				var rect: Rect2 = Rect2(effective_origin + Vector2(x, y) * tile_size, Vector2(tile_size, tile_size))
				_draw_floor_tile(rect, pos, ch)

	# 2B. Draw All Wall Tiles (Batched by wall texture to minimize draw calls)
	for y in range(grid.height):
		for x in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.is_wall(pos):
				var rect: Rect2 = Rect2(effective_origin + Vector2(x, y) * tile_size, Vector2(tile_size, tile_size))
				_draw_wall(rect, pos)

	# 2.2. Architectural Edge Depth (snug drop shadows on non-square shapes, no harsh borders)
	if is_non_square:
		_draw_slim_level_border(effective_origin, ch)

	# 2.3. Living Warehouse: Tracking Security Camera Wall Mount & Hardware
	_draw_security_camera(effective_origin, ch)

	# 2.4. Living Warehouse: Volumetric Floor Surveillance Cone (projected onto floor beneath crates & player)
	_draw_cctv_cone(effective_origin, ch)

	# 3. Draw Goals with Clean, Contained Precision Docking (no vertical bleeding)
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = sin(time_sec * 3.5) * 0.12
	var aura_col_base: Color = ch["goal_aura"]
	var core_col: Color = ch["goal_core"]
	for goal_pos in grid.goals.keys():
		var rect: Rect2 = Rect2(effective_origin + Vector2(goal_pos) * tile_size, Vector2(tile_size, tile_size))
		var center: Vector2 = rect.get_center()
		var has_crate: bool = grid.crates.has(goal_pos)

		if not has_crate:
			# --- Empty Goal: Hydraulic Pallet Freight Dock ---
			draw_texture_rect(tex_goal, rect, false, Color.WHITE)
			_draw_goal_light_pillar(rect, goal_pos, ch, time_sec)
		else:
			# --- Filled Goal: Precision Docking Under-Glow beneath crate ---
			draw_texture_rect(tex_goal, rect, false, Color(1.0, 1.0, 1.0, 0.55))
			_draw_goal_hazard_brackets(rect, ch)

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

	# 6.5. Proactive Deadlock Radar (Ghost Warning Glyph & Hazard Halo)
	_draw_deadlock_radar(effective_origin, ch)

	# 6.8. Tap-to-Walk Pathfinding Breadcrumbs & Target Marker
	_draw_auto_walk_path(effective_origin, ch)

	# 7. Draw Directional Porter Worker
	var player_padding: float = tile_size * 0.04
	var player_rect: Rect2 = Rect2(
		effective_origin + visual_player_pos * tile_size + Vector2(player_padding, player_padding),
		Vector2(tile_size - player_padding * 2.0, tile_size - player_padding * 2.0)
	)
	_draw_player(player_rect)

	# 7.5. Draw Hint Trajectory & Push Ghost + Swipe Preview + Level 1 Onboarding Cue
	_draw_hint_ghost(effective_origin)
	_draw_swipe_preview(effective_origin, ch)
	_draw_onboarding_cue(effective_origin, ch)

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

	if board_intro_scale < 0.999:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_star_shape(center: Vector2, radius: float, color: Color) -> void:
	if radius < 1.0:
		return
	var pts: PackedVector2Array = []
	for i in range(8):
		var a: float = i * (TAU / 8.0) - PI * 0.5
		var r: float = radius if (i % 2 == 0) else (radius * 0.38)
		pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(pts, color)


func _draw_floor_tile(rect: Rect2, pos: Vector2i, ch: Dictionary) -> void:
	var is_alt: bool = ((pos.x + pos.y) % 2 == 0)
	var floor_tex: Texture2D = tex_floor_1 if is_alt else tex_floor_2
	draw_texture_rect(floor_tex, rect, false, ch["floor_tint"])

	# 1. Clean Recessed Concrete Seams / Expansion Joints
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), Color(0.0, 0.0, 0.0, 0.14), 1.0)
	draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), Color(0.0, 0.0, 0.0, 0.14), 1.0)

	# 2. Corner expansion anchor bolt rivets (every 2 tiles for clean industrial pacing)
	if (pos.x % 2 == 0) and (pos.y % 2 == 0):
		var rivet_p: Vector2 = rect.position + Vector2(2.5, 2.5)
		draw_circle(rivet_p, 1.2, Color(0.05, 0.06, 0.09, 0.35))

	# 3. Chapter-Specific Floor Detailing
	match current_chapter_idx:
		1:
			# Cold Storage: Crystalline steel freezer glaze
			draw_rect(rect, Color(0.35, 0.82, 1.0, 0.025), false, 1.0)
		2:
			# Cyber Depot: Neon data trace
			draw_rect(rect, Color(0.20, 1.0, 0.55, 0.020), false, 1.0)

	# 4. Clean, subtle ambient depth shadow cast by neighboring non-floor tiles (no blotches)
	if grid != null:
		var has_top_wall: bool = (pos.y > 0 and not grid.is_interior_floor(pos + Vector2i.UP))
		var has_left_wall: bool = (pos.x > 0 and not grid.is_interior_floor(pos + Vector2i.LEFT))

		if has_top_wall:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.5)), Color(0.0, 0.0, 0.0, 0.30))
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.5)), Color(0.0, 0.0, 0.0, 0.20))

		if has_left_wall:
			draw_rect(Rect2(rect.position, Vector2(3.5, rect.size.y)), Color(0.0, 0.0, 0.0, 0.24))
			draw_rect(Rect2(rect.position, Vector2(1.5, rect.size.y)), Color(0.0, 0.0, 0.0, 0.15))


func _draw_exterior_void_tile(rect: Rect2, pos: Vector2i, _ch: Dictionary = {}) -> void:
	# Solid, uniform warehouse wall enclosure seamlessly framing the level
	_draw_wall(rect, pos)


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
	var active_wall_tex: Texture2D = tex_wall_cargo
	var wall_tint: Color = Color(1.0, 1.0, 1.0)
	var top_highlight: Color = Color(1.0, 1.0, 1.0, 0.12)
	var bottom_shadow: Color = Color(0.0, 0.0, 0.0, 0.25)
	var floor_contact_shadow: Color = Color(0.0, 0.0, 0.0, 0.70)

	match current_chapter_idx:
		1:
			# === Chapter 2: Cold Storage (Cryogenic Frosted Blue-Grey Masonry) ===
			active_wall_tex = tex_wall_cold_storage
			wall_tint = Color(1.0, 1.0, 1.0)
			top_highlight = Color(0.75, 0.90, 1.0, 0.35)
			bottom_shadow = Color(0.04, 0.08, 0.14, 0.45)
			floor_contact_shadow = Color(0.02, 0.06, 0.12, 0.85)
		2:
			# === Chapter 3: Cyber Depot (Dark Charcoal Slate Basalt Masonry) ===
			active_wall_tex = tex_wall_cyber_depot
			wall_tint = Color(1.0, 1.0, 1.0)
			top_highlight = Color(1.0, 0.75, 0.22, 0.35)
			bottom_shadow = Color(0.02, 0.04, 0.08, 0.55)
			floor_contact_shadow = Color(0.0, 0.02, 0.06, 0.90)
		3:
			# === Chapter 4: Quantum Vault (Deep Royal Violet Obsidian Masonry) ===
			active_wall_tex = tex_wall_quantum_vault
			wall_tint = Color(1.0, 1.0, 1.0)
			top_highlight = Color(0.92, 0.68, 1.00, 0.40)
			bottom_shadow = Color(0.04, 0.02, 0.08, 0.60)
			floor_contact_shadow = Color(0.02, 0.01, 0.05, 0.92)
		_:
			# === Chapter 1: Cargo Bay (Traditional Terracotta Brickwork) ===
			active_wall_tex = tex_wall_cargo
			wall_tint = Color(1.0, 0.96, 0.92)
			top_highlight = Color(1.0, 1.0, 1.0, 0.12)
			bottom_shadow = Color(0.0, 0.0, 0.0, 0.25)
			floor_contact_shadow = Color(0.0, 0.0, 0.0, 0.70)

	# 1. Base Wall Texture
	draw_texture_rect(active_wall_tex, rect, false, wall_tint)

	# Adjacency checks (UP, DOWN, LEFT, RIGHT)
	var wall_u: bool = grid != null and grid.is_wall(pos + Vector2i.UP)
	var wall_d: bool = grid != null and grid.is_wall(pos + Vector2i.DOWN)
	var wall_l: bool = grid != null and grid.is_wall(pos + Vector2i.LEFT)
	var wall_r: bool = grid != null and grid.is_wall(pos + Vector2i.RIGHT)

	# 2. Continuous Wall Coping: top highlight only on exposed upper edge
	if not wall_u:
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), top_highlight, 1.2)
	if not wall_d:
		draw_line(rect.position + Vector2(0.0, rect.size.y - 1.0), rect.end - Vector2(0.0, 1.0), bottom_shadow, 1.0)

	# 3. 2.5D Directional Front-Face Floor Shadows onto interior floor below
	if grid != null and pos.y < grid.height - 1 and grid.is_interior_floor(pos + Vector2i.DOWN):
		var shadow_h: float = minf(tile_size * 0.20, 9.0)
		# 3-tier soft vertical shadow cast on floor
		draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, shadow_h), Color(0.0, 0.0, 0.0, 0.16))
		draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, shadow_h * 0.55), Color(0.0, 0.0, 0.0, 0.26))
		draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, shadow_h * 0.25), Color(0.0, 0.0, 0.0, 0.42))
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), floor_contact_shadow, 1.8)

	# 4. Lateral Contact Shadow onto interior floor to the right
	if grid != null and pos.x < grid.width - 1 and grid.is_interior_floor(pos + Vector2i.RIGHT):
		var shadow_w: float = minf(tile_size * 0.12, 5.0)
		draw_rect(Rect2(rect.end.x, rect.position.y, shadow_w, rect.size.y), Color(0.0, 0.0, 0.0, 0.16))

	# 5. Chapter-Specific Architectural Accents on Exposed Coping
	if not wall_u:
		match current_chapter_idx:
			1:
				# Cold Storage: Crystalline frost glint along exposed top edge
				draw_line(rect.position + Vector2(0.0, 1.0), rect.position + Vector2(rect.size.x, 1.0), Color(0.85, 0.95, 1.0, 0.35), 1.0)
			2:
				# Cyber Depot: Neon cyan laser-etched coping rim
				draw_line(rect.position + Vector2(0.0, 1.0), rect.position + Vector2(rect.size.x, 1.0), Color(0.0, 0.85, 1.0, 0.30), 1.0)
			3:
				# Quantum Vault: Photonic violet crystalline sheen
				draw_line(rect.position + Vector2(0.0, 1.0), rect.position + Vector2(rect.size.x, 1.0), Color(0.88, 0.50, 1.0, 0.35), 1.0)

	# 6. Exposed Outer Corner Structural Reinforcements
	if not wall_u and (not wall_l or not wall_r):
		var corner_x: float = rect.position.x + 4.0 if not wall_l else rect.end.x - 4.0
		var rivet_pos: Vector2 = Vector2(corner_x, rect.position.y + 4.0)
		var rivet_col: Color = Color(0.8, 0.85, 0.9, 0.6)
		match current_chapter_idx:
			1:
				rivet_col = Color(0.70, 0.90, 1.0, 0.70)
			2:
				rivet_col = Color(1.0, 0.75, 0.20, 0.85) # Amber locator beacon
			3:
				rivet_col = Color(0.90, 0.60, 1.0, 0.80)
		draw_circle(rivet_pos, 1.4, rivet_col)


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


## Draws a slim, snug architectural drop-shadow and soft rim lighting along outer perimeter walls
## for non-square levels, seating the board naturally without harsh neon wireframe lines.
func _draw_slim_level_border(effective_origin: Vector2, _ch: Dictionary = {}) -> void:
	if grid == null:
		return

	for wall_pos in grid.walls.keys():
		var rect: Rect2 = Rect2(effective_origin + Vector2(wall_pos) * tile_size, Vector2(tile_size, tile_size))

		var ext_u: bool = is_exterior_tile(wall_pos + Vector2i.UP)
		var ext_d: bool = is_exterior_tile(wall_pos + Vector2i.DOWN)
		var ext_l: bool = is_exterior_tile(wall_pos + Vector2i.LEFT)
		var ext_r: bool = is_exterior_tile(wall_pos + Vector2i.RIGHT)

		# Top outer edge: subtle architectural masonry top-light
		if ext_u:
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), Color(1.0, 1.0, 1.0, 0.18), 1.5)

		# Left outer edge: subtle architectural light rim
		if ext_l:
			draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), Color(1.0, 1.0, 1.0, 0.12), 1.5)

		# Bottom outer edge: natural 2.5D warehouse wall drop shadow onto background
		if ext_d:
			draw_line(rect.position + Vector2(0.0, rect.size.y + 1.0), rect.end + Vector2(0.0, 1.0), Color(0.0, 0.0, 0.0, 0.45), 2.0)
			draw_line(rect.position + Vector2(0.0, rect.size.y + 3.0), rect.end + Vector2(0.0, 3.0), Color(0.0, 0.0, 0.0, 0.25), 2.0)

		# Right outer edge: natural 2.5D warehouse wall drop shadow onto background
		if ext_r:
			draw_line(rect.position + Vector2(rect.size.x + 1.0, 0.0), rect.end + Vector2(1.0, 0.0), Color(0.0, 0.0, 0.0, 0.40), 2.0)
			draw_line(rect.position + Vector2(rect.size.x + 3.0, 0.0), rect.end + Vector2(3.0, 0.0), Color(0.0, 0.0, 0.0, 0.20), 2.0)


func _draw_board_vignette(_effective_origin: Vector2, _board_pixel_size: Vector2, _ch_override: Dictionary = {}) -> void:
	# Clean board presentation without edge darkening or artificial frames
	pass


func _draw_goal_hazard_brackets(rect: Rect2, _ch: Dictionary) -> void:
	# Industrial Hydraulic Pallet Dock - Docked & Locked State ("CARGO SECURED & LOCKED")
	var center: Vector2 = rect.get_center()

	# 1. 4 Corner Runway Guidance Diodes switch to warm golden amber
	# Position matches exact LED diode placement in assets/goal_pad.png (38 / 128)
	var led_offset: float = tile_size * (38.0 / 128.0)
	var lock_col: Color = Color(1.0, 0.86, 0.28, 0.90)
	for dx in [-1.0, 1.0]:
		for dy in [-1.0, 1.0]:
			var diode_pos: Vector2 = center + Vector2(dx * led_offset, dy * led_offset)
			draw_circle(diode_pos, 3.0, Color(1.0, 0.82, 0.20, 0.30))
			draw_circle(diode_pos, 1.4, lock_col)

	# 2. Crisp golden perimeter dock framing under crate
	var pad: float = tile_size * (14.0 / 128.0)
	var lock_rect: Rect2 = Rect2(rect.position + Vector2(pad, pad), Vector2(tile_size - pad * 2.0, tile_size - pad * 2.0))
	draw_rect(lock_rect, Color(1.0, 0.85, 0.25, 0.28), false, 1.4)


func _draw_goal_light_pillar(rect: Rect2, goal_pos: Vector2i, ch: Dictionary, time_sec: float) -> void:
	# Industrial Hydraulic Pallet Loading Dock (Theme: Warehouse Freight Logistics)
	# Smooth, glitch-free guidance lighting matching the warehouse theme
	var center: Vector2 = rect.get_center()
	var phase_offset: float = float(goal_pos.x * 7 + goal_pos.y * 13) * 0.2
	var wave: float = sin(time_sec * 3.2 + phase_offset) * 0.5 + 0.5

	var amber_col: Color = ch.get("badge_color", Color(1.0, 0.76, 0.20))

	# 1. 4 Corner Flush Guidance LEDs (Pulsing Amber Docking Beacons)
	# Position matches exact diode placement in assets/goal_pad.png (38 / 128)
	var led_offset: float = tile_size * (38.0 / 128.0)
	for dx in [-1.0, 1.0]:
		for dy in [-1.0, 1.0]:
			var diode_pos: Vector2 = center + Vector2(dx * led_offset, dy * led_offset)
			# Soft beacon halo
			draw_circle(diode_pos, 3.4, Color(amber_col.r, amber_col.g, amber_col.b, 0.22 + 0.18 * wave))
			# Sharp LED diode core
			draw_circle(diode_pos, 1.3, Color(1.0, 0.95, 0.82, 0.65 + 0.35 * wave))

	# 2. Inward Cargo Guidance Pulse (Moving along the 4 cardinal guide tracks toward center)
	var cycle: float = fmod(time_sec * 0.70 + phase_offset * 0.15, 1.0)
	var in_dist: float = lerpf(tile_size * 0.26, tile_size * 0.08, cycle)
	var pulse_alpha: float = sin(cycle * PI) * 0.40
	var pulse_col: Color = Color(amber_col.r, amber_col.g, amber_col.b, pulse_alpha)
	# 4 cardinal inward guide dots
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_circle(center + dir * in_dist, 1.5, pulse_col)

	# 3. Center Freight Diamond Specular Glint
	draw_circle(center, 1.8, Color(1.0, 0.96, 0.85, 0.70 + 0.30 * wave))


func _draw_player_headlamp(effective_origin: Vector2) -> void:
	# Subtle, soft ambient contact warmth under player (no harsh discs or projecting beams)
	var p_center: Vector2 = effective_origin + visual_player_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5) + bump_offset + Vector2(0.0, player_celebration_hop + stride_arc_y)
	draw_circle(p_center, tile_size * 0.35, Color(1.0, 0.96, 0.82, 0.025))


func _draw_ambient_motes(effective_origin: Vector2, board_pixel_size: Vector2, ch: Dictionary) -> void:
	# Render subtle chapter-tinted atmospheric motes strictly outside the puzzle board bounds
	if ambient_motes.is_empty():
		return
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var board_rect: Rect2 = Rect2(effective_origin, board_pixel_size).grow(8.0)
	var accent: Color = ch.get("goal_aura", ch.get("frame_rim", Color(0.95, 0.80, 0.28)))
	for mote in ambient_motes:
		var pos: Vector2 = Vector2(mote["pos_norm"].x * vp_size.x, mote["pos_norm"].y * vp_size.y)
		if board_rect.has_point(pos):
			continue
		var pulse: float = 0.60 + 0.40 * sin(float(mote.get("phase", 0.0)))
		var alpha: float = float(mote.get("base_alpha", 0.3)) * 0.48 * pulse
		var radius: float = float(mote.get("size", 2.0))
		draw_circle(pos, radius * 1.9, Color(accent.r, accent.g, accent.b, alpha * 0.25))
		draw_circle(pos, radius * 0.85, Color(accent.r, accent.g, accent.b, alpha))


func _init_ambient_motes() -> void:
	ambient_motes.clear()
	var rng: RandomNumberGenerator = _rng
	for i in range(16):
		ambient_motes.append({
			"pos_norm": Vector2(rng.randf(), rng.randf()),
			"vel": Vector2(rng.randf_range(-0.018, 0.018), rng.randf_range(-0.012, 0.012)),
			"phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(1.6, 3.2),
			"base_alpha": rng.randf_range(0.22, 0.55),
			"speed_mult": rng.randf_range(0.8, 1.3)
		})


# ==============================================================================
# Living Warehouse: Tracking Security Camera (CCTV)
# ==============================================================================

func _find_security_camera_mount() -> Vector2i:
	if grid == null or grid.width == 0 or grid.height == 0:
		return Vector2i(-1, -1)

	var candidates: Array[Vector2i] = []
	var min_y: int = 99999

	# Priority 1: Top-facing interior walls (wall with interior floor directly below it)
	for y in range(grid.height):
		for x in range(grid.width):
			var p: Vector2i = Vector2i(x, y)
			if grid.is_wall(p):
				var down_p: Vector2i = p + Vector2i.DOWN
				var is_floor_down: bool = grid.is_in_bounds(down_p) and not grid.is_wall(down_p) and not grid.is_exterior_void(down_p) and (grid.interior_floor.is_empty() or grid.is_interior_floor(down_p))
				if is_floor_down:
					if y < min_y:
						min_y = y
					candidates.append(p)

	if not candidates.is_empty():
		# Filter to the uppermost tier of candidate walls (closest to the top of the room)
		var top_candidates: Array[Vector2i] = []
		for p in candidates:
			if p.y == min_y:
				top_candidates.append(p)
		# Pick the one closest to horizontal center of the grid for optimal line-of-sight
		var center_x: float = float(grid.width) * 0.5
		top_candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return absf(float(a.x) - center_x) < absf(float(b.x) - center_x)
		)
		return top_candidates[0]

	# Priority 2 Fallback: Any wall adjacent to an interior floor tile
	for y in range(grid.height):
		for x in range(grid.width):
			var p: Vector2i = Vector2i(x, y)
			if grid.is_wall(p):
				for d in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]:
					var adj_p: Vector2i = p + d
					if grid.is_in_bounds(adj_p) and not grid.is_wall(adj_p) and not grid.is_exterior_void(adj_p) and (grid.interior_floor.is_empty() or grid.is_interior_floor(adj_p)):
						return p

	return Vector2i(-1, -1)


func _init_security_camera() -> void:
	cctv_camera_tile = _find_security_camera_mount()
	cctv_active = (cctv_camera_tile != Vector2i(-1, -1))
	cctv_current_angle = PI * 0.5
	cctv_target_angle = PI * 0.5
	cctv_tally_timer = 0.0
	cctv_motion_timer = 0.0
	cctv_alert_timer = 0.0
	cctv_sweep_phase = 0.0
	cctv_idle_pan_timer = 0.0


func _update_security_camera(delta: float) -> bool:
	if not cctv_active or cctv_camera_tile == Vector2i(-1, -1) or grid == null:
		return false

	var effective_origin: Vector2 = grid_origin + board_shake_offset
	var cam_anchor: Vector2 = effective_origin + Vector2(float(cctv_camera_tile.x) + 0.5, float(cctv_camera_tile.y) + 0.85) * tile_size
	var p_center: Vector2 = effective_origin + visual_player_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5) + bump_offset + Vector2(0.0, player_celebration_hop + stride_arc_y)

	var target_pt: Vector2 = p_center
	if cctv_alert_timer > 0.0 and not active_deadlocked_crates.is_empty():
		var trapped_tile: Vector2i = active_deadlocked_crates[0]
		target_pt = effective_origin + Vector2(float(trapped_tile.x) + 0.5, float(trapped_tile.y) + 0.5) * tile_size

	var dir: Vector2 = target_pt - cam_anchor
	var base_target_angle: float = dir.angle()

	# Idle servo micro-pan when player is still for a few seconds
	var pan_offset: float = 0.0
	if not is_animating and not is_level_won and player_idle_time > 2.0:
		cctv_idle_pan_timer += delta
		pan_offset = sin(cctv_idle_pan_timer * 1.5) * 0.045
	else:
		cctv_idle_pan_timer = 0.0

	cctv_target_angle = base_target_angle + pan_offset

	# Responsive, smooth robotic servo tracking
	var angle_diff: float = wrapf(cctv_target_angle - cctv_current_angle, -PI, PI)
	var servo_speed: float = 8.5
	var step: float = angle_diff * clampf(delta * servo_speed, 0.0, 1.0)
	cctv_current_angle += step

	# Advance timers
	cctv_sweep_phase += delta * 2.5
	cctv_tally_timer += delta
	if cctv_motion_timer > 0.0:
		cctv_motion_timer = maxf(0.0, cctv_motion_timer - delta)
	if cctv_alert_timer > 0.0:
		cctv_alert_timer = maxf(0.0, cctv_alert_timer - delta)

	return absf(angle_diff) > 0.003 or cctv_motion_timer > 0.0 or cctv_alert_timer > 0.0 or is_animating or not active_deadlocked_crates.is_empty()


func _draw_cctv_cone(effective_origin: Vector2, _ch: Dictionary) -> void:
	if not cctv_active or cctv_camera_tile == Vector2i(-1, -1) or grid == null:
		return

	var cam_anchor: Vector2 = effective_origin + Vector2(float(cctv_camera_tile.x) + 0.5, float(cctv_camera_tile.y) + 0.85) * tile_size
	var p_center: Vector2 = effective_origin + visual_player_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5) + bump_offset + Vector2(0.0, player_celebration_hop + stride_arc_y)

	var to_player: Vector2 = p_center - cam_anchor
	var dist: float = to_player.length()
	var cone_len: float = maxf(dist + tile_size * 0.70, tile_size * 2.5)
	var half_fov: float = deg_to_rad(13.0)
	var a_left: float = cctv_current_angle - half_fov
	var a_right: float = cctv_current_angle + half_fov

	var p_origin: Vector2 = cam_anchor + Vector2(cos(cctv_current_angle), sin(cctv_current_angle)) * (tile_size * 0.15)

	# Curved cone polygon
	var cone_pts: PackedVector2Array = [p_origin]
	var segments: int = 8
	for s in range(segments + 1):
		var t: float = float(s) / float(segments)
		var ang: float = lerpf(a_left, a_right, t)
		cone_pts.append(cam_anchor + Vector2(cos(ang), sin(ang)) * cone_len)

	# Dynamic volumetric color based on chapter and surveillance alert state
	var cone_col: Color
	if is_level_won:
		cone_col = Color(0.25, 0.95, 0.50, 0.075)
	elif cctv_alert_timer > 0.0:
		cone_col = Color(1.0, 0.35, 0.12, 0.080)
	else:
		match current_chapter_idx:
			1:
				cone_col = Color(0.45, 0.88, 1.0, 0.045)
			2:
				cone_col = Color(0.12, 1.0, 0.80, 0.050)
			3:
				cone_col = Color(0.85, 0.48, 1.0, 0.050)
			_:
				cone_col = Color(1.0, 0.85, 0.42, 0.040)
		if cctv_motion_timer > 0.0:
			cone_col.a *= 1.45

	# 1. Soft Volumetric Floor Polygon
	draw_colored_polygon(cone_pts, cone_col)

	# 2. Subtle Edge Beams
	var edge_col: Color = Color(cone_col.r, cone_col.g, cone_col.b, cone_col.a * 1.9)
	draw_line(p_origin, cone_pts[1], edge_col, 1.0)
	draw_line(p_origin, cone_pts[cone_pts.size() - 1], edge_col, 1.0)

	# 3. Dynamic Optical Wave Ripple sliding along the beam
	var wave_t: float = fmod(cctv_sweep_phase, 1.0)
	var wave_dist: float = cone_len * wave_t
	var wave_pts: PackedVector2Array = []
	for s in range(segments + 1):
		var t: float = float(s) / float(segments)
		var ang: float = lerpf(a_left, a_right, t)
		wave_pts.append(cam_anchor + Vector2(cos(ang), sin(ang)) * wave_dist)
	var wave_alpha: float = sin(wave_t * PI) * cone_col.a * 2.4
	draw_polyline(wave_pts, Color(cone_col.r, cone_col.g, cone_col.b, wave_alpha), 1.2)

	# 4. Diegetic Target Tracking Reticle around player's feet
	var reticle_r: float = tile_size * 0.36
	var bracket_len: float = tile_size * 0.12
	var ret_alpha: float = clampf(cone_col.a * 3.8, 0.08, 0.25)
	var ret_col: Color = Color(cone_col.r, cone_col.g, cone_col.b, ret_alpha)
	draw_line(p_center + Vector2(-reticle_r, -reticle_r + bracket_len), p_center + Vector2(-reticle_r, -reticle_r), ret_col, 1.5)
	draw_line(p_center + Vector2(-reticle_r, -reticle_r), p_center + Vector2(-reticle_r + bracket_len, -reticle_r), ret_col, 1.5)
	draw_line(p_center + Vector2(reticle_r - bracket_len, -reticle_r), p_center + Vector2(reticle_r, -reticle_r), ret_col, 1.5)
	draw_line(p_center + Vector2(reticle_r, -reticle_r), p_center + Vector2(reticle_r, -reticle_r + bracket_len), ret_col, 1.5)
	draw_line(p_center + Vector2(-reticle_r, reticle_r - bracket_len), p_center + Vector2(-reticle_r, reticle_r), ret_col, 1.5)
	draw_line(p_center + Vector2(-reticle_r, reticle_r), p_center + Vector2(-reticle_r + bracket_len, reticle_r), ret_col, 1.5)
	draw_line(p_center + Vector2(reticle_r - bracket_len, reticle_r), p_center + Vector2(reticle_r, reticle_r), ret_col, 1.5)
	draw_line(p_center + Vector2(reticle_r, reticle_r), p_center + Vector2(reticle_r, reticle_r - bracket_len), ret_col, 1.5)
	draw_circle(p_center, 1.2, Color(ret_col.r, ret_col.g, ret_col.b, ret_alpha * 0.75))


func _draw_security_camera(effective_origin: Vector2, _ch: Dictionary) -> void:
	if not cctv_active or cctv_camera_tile == Vector2i(-1, -1) or grid == null:
		return

	var cam_anchor: Vector2 = effective_origin + Vector2(float(cctv_camera_tile.x) + 0.5, float(cctv_camera_tile.y) + 0.85) * tile_size

	# Chapter-specific industrial hardware styling
	var casing_col: Color
	var bracket_col: Color
	var rim_col: Color
	match current_chapter_idx:
		1:
			casing_col = Color(0.68, 0.82, 0.92)
			bracket_col = Color(0.10, 0.16, 0.24)
			rim_col = Color(0.85, 0.96, 1.0, 0.50)
		2:
			casing_col = Color(0.16, 0.18, 0.24)
			bracket_col = Color(0.08, 0.10, 0.14)
			rim_col = Color(0.20, 1.0, 0.75, 0.50)
		3:
			casing_col = Color(0.24, 0.16, 0.32)
			bracket_col = Color(0.10, 0.06, 0.14)
			rim_col = Color(0.90, 0.60, 1.0, 0.55)
		_:
			casing_col = Color(0.82, 0.80, 0.76)
			bracket_col = Color(0.18, 0.20, 0.25)
			rim_col = Color(0.95, 0.95, 0.95, 0.40)

	# 1. Wall Conduit Pipe
	var wall_top_y: float = effective_origin.y + float(cctv_camera_tile.y) * tile_size
	draw_line(Vector2(cam_anchor.x, wall_top_y), Vector2(cam_anchor.x, cam_anchor.y - 7.0), Color(0.10, 0.12, 0.16), 2.2)
	draw_line(Vector2(cam_anchor.x - 0.5, wall_top_y), Vector2(cam_anchor.x - 0.5, cam_anchor.y - 7.0), Color(0.35, 0.40, 0.48, 0.50), 1.0)

	# 2. Wall Mounting Base Plate
	var plate_w: float = clampf(tile_size * 0.24, 11.0, 16.0)
	var plate_h: float = clampf(tile_size * 0.12, 6.0, 9.0)
	var plate_rect: Rect2 = Rect2(cam_anchor.x - plate_w * 0.5, cam_anchor.y - plate_h - 3.0, plate_w, plate_h)
	draw_rect(Rect2(plate_rect.position + Vector2(1, 2), plate_rect.size), Color(0.0, 0.0, 0.0, 0.50))
	draw_rect(plate_rect, bracket_col)
	draw_line(plate_rect.position, plate_rect.position + Vector2(plate_rect.size.x, 0), Color(1.0, 1.0, 1.0, 0.30), 1.0)
	draw_circle(plate_rect.position + Vector2(2.0, 2.0), 1.0, Color(0.05, 0.06, 0.08))
	draw_circle(plate_rect.position + Vector2(plate_rect.size.x - 2.0, 2.0), 1.0, Color(0.05, 0.06, 0.08))

	# 3. Swivel Hinge Joint
	draw_circle(cam_anchor + Vector2(0.0, -2.5), 3.2, bracket_col.darkened(0.15))
	draw_circle(cam_anchor + Vector2(-0.8, -3.2), 1.2, Color(1.0, 1.0, 1.0, 0.35))

	# 4. Swiveling Camera Body & Lens
	var fwd: Vector2 = Vector2(cos(cctv_current_angle), sin(cctv_current_angle))
	var perp: Vector2 = Vector2(-fwd.y, fwd.x)
	var cam_len: float = clampf(tile_size * 0.28, 12.0, 18.0)
	var cam_w: float = clampf(tile_size * 0.16, 7.0, 11.0)

	# Drop shadow under camera housing
	var s_back_l: Vector2 = cam_anchor - fwd * (cam_len * 0.25) - perp * (cam_w * 0.5) + Vector2(2.0, 3.0)
	var s_back_r: Vector2 = cam_anchor - fwd * (cam_len * 0.25) + perp * (cam_w * 0.5) + Vector2(2.0, 3.0)
	var s_front_r: Vector2 = cam_anchor + fwd * (cam_len * 0.75) + perp * (cam_w * 0.42) + Vector2(2.0, 3.0)
	var s_front_l: Vector2 = cam_anchor + fwd * (cam_len * 0.75) - perp * (cam_w * 0.42) + Vector2(2.0, 3.0)
	draw_colored_polygon(PackedVector2Array([s_back_l, s_back_r, s_front_r, s_front_l]), Color(0.0, 0.0, 0.0, 0.38))

	# Main Camera Casing
	var back_l: Vector2 = cam_anchor - fwd * (cam_len * 0.25) - perp * (cam_w * 0.5)
	var back_r: Vector2 = cam_anchor - fwd * (cam_len * 0.25) + perp * (cam_w * 0.5)
	var front_r: Vector2 = cam_anchor + fwd * (cam_len * 0.75) + perp * (cam_w * 0.42)
	var front_l: Vector2 = cam_anchor + fwd * (cam_len * 0.75) - perp * (cam_w * 0.42)
	draw_colored_polygon(PackedVector2Array([back_l, back_r, front_r, front_l]), casing_col)
	draw_polyline(PackedVector2Array([back_l, back_r, front_r, front_l, back_l]), Color(0.06, 0.07, 0.10), 1.2)

	# Metallic Specular Sheen
	var sheen_a: Vector2 = back_l.lerp(back_r, 0.22)
	var sheen_b: Vector2 = front_l.lerp(front_r, 0.22)
	draw_line(sheen_a, sheen_b, rim_col, 1.0)

	# Front Lens Face & Glint
	var lens_center: Vector2 = cam_anchor + fwd * (cam_len * 0.78)
	draw_line(front_l, front_r, Color(0.05, 0.06, 0.09), 2.2)
	draw_circle(lens_center, 1.3, Color(0.20, 0.70, 1.0, 0.85))

	# Weather Visor Hood
	draw_line(front_l + fwd * 2.2, front_r + fwd * 2.2, casing_col.lightened(0.18), 1.4)

	# 5. Dynamic Tally Recording LED
	var led_pos: Vector2 = cam_anchor - fwd * (cam_len * 0.06) + perp * (cam_w * 0.30)
	var led_col: Color
	var led_glow: Color
	if is_level_won:
		led_col = Color(0.18, 0.95, 0.45)
		led_glow = Color(0.18, 0.95, 0.45, 0.35)
	elif cctv_alert_timer > 0.0:
		var strobe: float = 1.0 if fmod(cctv_alert_timer * 9.0, 1.0) < 0.5 else 0.15
		led_col = Color(1.0, 0.22, 0.05, strobe)
		led_glow = Color(1.0, 0.22, 0.05, strobe * 0.45)
	elif cctv_motion_timer > 0.0:
		led_col = Color(1.0, 0.15, 0.25)
		led_glow = Color(1.0, 0.15, 0.25, 0.45)
	else:
		var cycle: float = fmod(cctv_tally_timer, 2.2)
		var a: float = 1.0 if cycle < 1.4 else (0.2 + 0.8 * (cycle - 1.4) / 0.8)
		led_col = Color(1.0, 0.18, 0.22, a)
		led_glow = Color(1.0, 0.18, 0.22, a * 0.35)

	draw_circle(led_pos, 3.2, led_glow)
	draw_circle(led_pos, 1.4, led_col)
	draw_circle(led_pos - Vector2(0.4, 0.4), 0.6, Color(1.0, 1.0, 1.0, 0.90))


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

	# Crate Skin from Porter Locker
	var crate_skin_info: Dictionary = save_mgr.get_crate_skin_info() if (save_mgr and save_mgr.has_method("get_crate_skin_info")) else {}
	var crate_skin_id: String = crate_skin_info.get("id", "classic_wood")
	var crate_tint: Color = crate_skin_info.get("tint", Color.WHITE)

	var c_tex: Texture2D = tex_crate_goal if on_goal else tex_crate
	var c_mod: Color = Color(1.0, 1.0, 1.0) if on_goal else (ch["crate_tint"] * crate_tint)
	draw_texture_rect(c_tex, draw_r, false, c_mod)

	# 2. 3D Volume Key-Light & Ambient Occlusion Shading
	# Top & left specular key-light rims from overhead warehouse lamps
	draw_line(draw_r.position + Vector2(2.0, 1.0), draw_r.position + Vector2(draw_r.size.x - 2.0, 1.0), Color(1.0, 1.0, 1.0, 0.38), 1.6)
	draw_line(draw_r.position + Vector2(1.0, 2.0), draw_r.position + Vector2(1.0, draw_r.size.y - 2.0), Color(1.0, 1.0, 1.0, 0.26), 1.4)
	# Top-left specular glint
	draw_circle(draw_r.position + Vector2(3.0, 3.0), 1.2, Color(1.0, 1.0, 1.0, 0.65))

	# Bottom & right ambient occlusion shadows
	draw_line(draw_r.position + Vector2(2.0, draw_r.size.y - 1.0), draw_r.end - Vector2(2.0, 1.0), Color(0.0, 0.0, 0.0, 0.45), 2.0)
	draw_line(Vector2(draw_r.end.x - 1.0, draw_r.position.y + 2.0), draw_r.end - Vector2(1.0, 2.0), Color(0.0, 0.0, 0.0, 0.35), 1.8)

	# Crate custom skin accessories (shown off-goal so docked crates always restore clean gold sprite)
	if not on_goal:
		match crate_skin_id:
			"steel_container":
				# Cold-rolled metallic corner angle braces
				var brace_len: float = draw_r.size.x * 0.22
				var b_col: Color = Color(0.85, 0.92, 1.0, 0.85)
				draw_line(draw_r.position, draw_r.position + Vector2(brace_len, 0), b_col, 2.0)
				draw_line(draw_r.position, draw_r.position + Vector2(0, brace_len), b_col, 2.0)
				draw_line(draw_r.position + Vector2(draw_r.size.x, 0), draw_r.position + Vector2(draw_r.size.x - brace_len, 0), b_col, 2.0)
				draw_line(draw_r.position + Vector2(draw_r.size.x, 0), draw_r.position + Vector2(draw_r.size.x, brace_len), b_col, 2.0)
				draw_line(draw_r.position + Vector2(0, draw_r.size.y), draw_r.position + Vector2(brace_len, draw_r.size.y), b_col, 2.0)
				draw_line(draw_r.position + Vector2(0, draw_r.size.y), draw_r.position + Vector2(0, draw_r.size.y - brace_len), b_col, 2.0)
				draw_line(draw_r.end, draw_r.end - Vector2(brace_len, 0), b_col, 2.0)
				draw_line(draw_r.end, draw_r.end - Vector2(0, brace_len), b_col, 2.0)
			"hazard_box":
				# Caution diagonal hazard accent in center
				var h_col: Color = Color(0.12, 0.12, 0.15, 0.75)
				var c_len: float = draw_r.size.x * 0.35
				draw_line(c_center - Vector2(c_len * 0.5, c_len * 0.5), c_center + Vector2(c_len * 0.5, c_len * 0.5), h_col, 3.5)
				draw_line(c_center - Vector2(c_len * 0.5, -c_len * 0.5), c_center + Vector2(c_len * 0.5, -c_len * 0.5), h_col, 3.5)
			"cryo_vault":
				# 4 Frost crystalline corner studs
				var pad: float = draw_r.size.x * 0.18
				var frost_pts: Array[Vector2] = [
					draw_r.position + Vector2(pad, pad),
					draw_r.position + Vector2(draw_r.size.x - pad, pad),
					draw_r.position + Vector2(pad, draw_r.size.y - pad),
					draw_r.position + Vector2(draw_r.size.x - pad, draw_r.size.y - pad)
				]
				for pt in frost_pts:
					draw_circle(pt, 2.2, Color(0.85, 0.98, 1.0, 0.88))
					draw_circle(pt, 1.0, Color(1.0, 1.0, 1.0, 0.98))
			"luxury_safe":
				# Central brass vault combination dial
				draw_circle(c_center, 6.2, Color(0.12, 0.10, 0.08, 0.88))
				draw_circle(c_center, 5.0, Color(1.0, 0.86, 0.28, 0.96))
				draw_circle(c_center, 2.0, Color(0.30, 0.20, 0.05, 1.0))
				# 4 Gold corner rivets
				var g_pad: float = draw_r.size.x * 0.14
				var g_corners: Array[Vector2] = [
					draw_r.position + Vector2(g_pad, g_pad),
					draw_r.position + Vector2(draw_r.size.x - g_pad, g_pad),
					draw_r.position + Vector2(g_pad, draw_r.size.y - g_pad),
					draw_r.position + Vector2(draw_r.size.x - g_pad, draw_r.size.y - g_pad)
				]
				for pt in g_corners:
					draw_circle(pt, 2.4, Color(1.0, 0.85, 0.25, 0.95))
					draw_circle(pt - Vector2(0.5, 0.5), 0.8, Color(1.0, 1.0, 0.90, 1.0))


func _draw_player(rect: Rect2) -> void:
	var idle_breath_y: float = 0.0
	if not is_animating and not is_level_won and player_idle_time > 2.0:
		idle_breath_y = sin((player_idle_time - 2.0) * 3.5) * 1.2

	# Subtle worker idle nuance (boot tap / cap adjust) around ~6s of idle
	var idle_nuance_y: float = 0.0
	var idle_nuance_x: float = 0.0
	if not is_animating and not is_level_won and player_idle_time >= 5.5 and player_idle_time <= 7.0:
		var n_t: float = (player_idle_time - 5.5) / 1.5
		idle_nuance_y = -sin(n_t * PI * 2.0) * 1.5
		idle_nuance_x = sin(n_t * PI * 4.0) * 0.8

	# Heavy crate push stance lean & strain tremor: worker visibly strains and leans into crate
	var push_lean: Vector2 = Vector2.ZERO
	var push_tremor: Vector2 = Vector2.ZERO
	if is_animating and grid != null and grid.last_move_pushed_crate:
		push_lean = Vector2(player_facing_dir) * (rect.size.x * 0.07)
		var perp: Vector2 = Vector2(-player_facing_dir.y, player_facing_dir.x)
		push_tremor = perp * (sin(float(Time.get_ticks_msec()) * 0.055) * 0.9)

	var total_hop_y: float = player_celebration_hop + stride_arc_y + idle_breath_y + idle_nuance_y
	var total_offset: Vector2 = bump_offset + push_lean + push_tremor + Vector2(idle_nuance_x, total_hop_y)
	var hopped_rect: Rect2 = Rect2(rect.position + total_offset, rect.size)

	# Foot-anchored squash & stretch deformation
	if player_scale != Vector2.ONE:
		var foot_y: float = hopped_rect.position.y + hopped_rect.size.y
		var center_x: float = hopped_rect.position.x + hopped_rect.size.x * 0.5
		var scaled_w: float = hopped_rect.size.x * player_scale.x
		var scaled_h: float = hopped_rect.size.y * player_scale.y
		hopped_rect = Rect2(
			center_x - scaled_w * 0.5,
			foot_y - scaled_h,
			scaled_w,
			scaled_h
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

	# As player hops up during stride or celebration, ground shadow shrinks slightly for 2.5D jump depth
	var hop_factor: float = clampf(1.0 + (player_celebration_hop + stride_arc_y) / 35.0, 0.45, 1.0)

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

	# Skin Accessory & Visual Accent Overlays (matches all 6 Supply Depot outfits in-game)
	var hw: float = hopped_rect.size.x
	var hh: float = hopped_rect.size.y
	match skin_id:
		"safety_vest":
			# High-visibility neon orange chest vest + reflective silver bands
			var torso_y: float = hopped_rect.position.y + hh * 0.54
			var band_w: float = hw * 0.22
			draw_rect(Rect2(center.x - band_w, torso_y - 2.0, band_w * 2.0, hh * 0.22), Color(1.0, 0.45, 0.08, 0.55))
			draw_line(Vector2(center.x - band_w, torso_y + 1.0), Vector2(center.x + band_w, torso_y + 1.0), Color(0.95, 0.98, 1.0, 0.95), maxf(2.0, hh * 0.045))
			draw_line(Vector2(center.x - band_w * 0.7, torso_y - 3.0), Vector2(center.x - band_w * 0.7, torso_y + hh * 0.16), Color(0.95, 0.98, 1.0, 0.88), maxf(1.6, hw * 0.035))
			draw_line(Vector2(center.x + band_w * 0.7, torso_y - 3.0), Vector2(center.x + band_w * 0.7, torso_y + hh * 0.16), Color(0.95, 0.98, 1.0, 0.88), maxf(1.6, hw * 0.035))
		"mechanic":
			# Reinforced dark utility belt + steel buckle + wrench hanging on hip
			var belt_y: float = hopped_rect.position.y + hh * 0.64
			var half_b: float = hw * 0.23
			draw_line(Vector2(center.x - half_b, belt_y), Vector2(center.x + half_b, belt_y), Color(0.14, 0.16, 0.22, 0.95), maxf(2.5, hh * 0.05))
			draw_rect(Rect2(center.x - hw * 0.05, belt_y - hh * 0.035, hw * 0.10, hh * 0.07), Color(0.85, 0.90, 0.98, 0.95))
			draw_line(Vector2(center.x + half_b * 0.7, belt_y), Vector2(center.x + half_b * 0.7, belt_y + hh * 0.10), Color(0.82, 0.88, 0.96, 0.95), maxf(2.0, hw * 0.035))
		"foreman":
			# Executive gold hardhat brim + front foreman emblem
			var brim_y: float = hopped_rect.position.y + hh * 0.27
			var half_h: float = hw * 0.24
			draw_line(Vector2(center.x - half_h, brim_y), Vector2(center.x + half_h, brim_y), Color(1.0, 0.86, 0.18, 0.96), maxf(2.4, hh * 0.045))
			draw_circle(Vector2(center.x, hopped_rect.position.y + hh * 0.18), maxf(2.2, hw * 0.04), Color(1.0, 0.94, 0.45, 0.95))
		"hazmat":
			# Luminous cyan bio-containment visor shield across face
			if player_facing_dir != Vector2i.UP:
				var visor_y: float = hopped_rect.position.y + hh * 0.34
				var visor_w: float = hw * 0.17 if player_facing_dir == Vector2i.DOWN else hw * 0.12
				var visor_x_off: float = 0.0 if player_facing_dir == Vector2i.DOWN else float(player_facing_dir.x) * (hw * 0.08)
				draw_rect(Rect2(center.x + visor_x_off - visor_w, visor_y - hh * 0.045, visor_w * 2.0, hh * 0.09), Color(0.18, 0.96, 1.0, 0.85))
				draw_line(Vector2(center.x + visor_x_off - visor_w * 0.7, visor_y - hh * 0.02), Vector2(center.x + visor_x_off + visor_w * 0.4, visor_y - hh * 0.02), Color(0.88, 1.0, 1.0, 0.95), 1.4)
			else:
				# Dual breather canisters visible on back pack when facing away
				var pack_y: float = hopped_rect.position.y + hh * 0.56
				draw_circle(Vector2(center.x - hw * 0.09, pack_y), maxf(2.2, hw * 0.04), Color(0.25, 0.95, 0.55, 0.90))
				draw_circle(Vector2(center.x + hw * 0.09, pack_y), maxf(2.2, hw * 0.04), Color(0.25, 0.95, 0.55, 0.90))
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





func _draw_hint_ghost(effective_origin: Vector2) -> void:
	if hint_time_remaining <= 0.0 or active_hint_dir == Vector2i.ZERO:
		return

	var pulse: float = 0.55 + 0.35 * sin(hint_pulse_timer * 7.0)
	var fade: float = clampf(hint_time_remaining / 0.4, 0.0, 1.0)
	var base_alpha: float = pulse * fade
	var half_tile: Vector2 = Vector2(tile_size * 0.5, tile_size * 0.5)
	var flow_t: float = fmod(hint_pulse_timer * 2.4, 1.0)

	# 0. Multi-step holographic walk-to-next-push breadcrumb trail
	if hint_walk_waypoints.size() > 1:
		var trail_pts: PackedVector2Array = []
		trail_pts.append(effective_origin + visual_player_pos * tile_size + half_tile)
		for wp in hint_walk_waypoints:
			trail_pts.append(effective_origin + Vector2(wp) * tile_size + half_tile)
		draw_polyline(trail_pts, Color(0.18, 0.65, 1.0, 0.30 * base_alpha), 6.5, true)
		draw_polyline(trail_pts, Color(0.50, 0.90, 1.0, 0.72 * base_alpha), 2.5, true)
		for wi in range(1, trail_pts.size()):
			var wp_alpha: float = 0.72 if wi == trail_pts.size() - 1 else 0.48
			draw_circle(trail_pts[wi], 3.5, Color(0.45, 0.90, 1.0, wp_alpha * base_alpha))

		# Animated flow bead across the full walk path
		var seg_count: int = trail_pts.size() - 1
		if seg_count > 0:
			var scaled_t: float = flow_t * float(seg_count)
			var seg_idx: int = clampi(int(floor(scaled_t)), 0, seg_count - 1)
			var local_t: float = scaled_t - float(seg_idx)
			var trail_bead: Vector2 = trail_pts[seg_idx].lerp(trail_pts[seg_idx + 1], local_t)
			draw_circle(trail_bead, 5.2, Color(0.40, 0.85, 1.0, 0.40 * base_alpha))
			draw_circle(trail_bead, 2.8, Color(1.0, 1.0, 1.0, 0.95 * base_alpha))

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

	# Holographic horizontal scanlines across player ghost
	for s in range(3):
		var s_y: float = p_ghost_draw_rect.position.y + fmod(p_ghost_draw_rect.size.y * (0.25 + s * 0.30) + hint_pulse_timer * 35.0, p_ghost_draw_rect.size.y)
		draw_line(Vector2(p_ghost_draw_rect.position.x, s_y), Vector2(p_ghost_draw_rect.end.x, s_y), Color(0.40, 0.85, 1.0, 0.45 * base_alpha), 1.2)

	# 2. Crate Push Destination Ghost (either immediate push OR terminal push in walk-to-push plan)
	var draw_crate_ghost: bool = hint_has_crate or (hint_has_push and hint_push_dir != Vector2i.ZERO)
	var dest_tile: Vector2i = hint_crate_target if hint_has_crate else hint_push_to
	var push_src_center: Vector2 = p_center if hint_has_crate else (effective_origin + Vector2(hint_push_from) * tile_size + half_tile)
	var push_dir_eff: Vector2i = active_hint_dir if hint_has_crate else hint_push_dir

	if draw_crate_ghost:
		var c_target_rect: Rect2 = Rect2(
			effective_origin + Vector2(dest_tile) * tile_size,
			Vector2(tile_size, tile_size)
		)
		# Glowing amber beacon for crate push destination
		draw_rect(c_target_rect.grow(-3), Color(1.0, 0.75, 0.15, 0.22 * base_alpha), true)
		draw_rect(c_target_rect.grow(-3), Color(1.0, 0.88, 0.30, 0.75 * base_alpha), false, 2.5)

		var is_target_goal: bool = grid != null and grid.is_goal(dest_tile)
		var c_ghost_tex: Texture2D = tex_crate_goal if is_target_goal else tex_crate
		var c_draw_padding: float = tile_size * 0.04
		var c_ghost_draw_rect: Rect2 = Rect2(
			c_target_rect.position + Vector2(c_draw_padding, c_draw_padding),
			Vector2(tile_size - c_draw_padding * 2.0, tile_size - c_draw_padding * 2.0)
		)
		draw_texture_rect(c_ghost_tex, c_ghost_draw_rect, false, Color(1.0, 1.0, 1.0, 0.72 * base_alpha))

		# Holographic horizontal scanlines across crate ghost
		for s in range(3):
			var s_y: float = c_ghost_draw_rect.position.y + fmod(c_ghost_draw_rect.size.y * (0.25 + s * 0.30) + hint_pulse_timer * 35.0, c_ghost_draw_rect.size.y)
			draw_line(Vector2(c_ghost_draw_rect.position.x, s_y), Vector2(c_ghost_draw_rect.end.x, s_y), Color(1.0, 0.85, 0.30, 0.45 * base_alpha), 1.2)

	# 3. Dynamic Directional Trajectory Laser Beam (first step)
	var current_player_center: Vector2 = effective_origin + visual_player_pos * tile_size + half_tile
	var arrow_start: Vector2 = current_player_center + Vector2(active_hint_dir) * (tile_size * 0.32)
	var arrow_end: Vector2 = p_center - Vector2(active_hint_dir) * (tile_size * 0.22)

	# Holographic laser multi-tier glow
	draw_line(arrow_start, arrow_end, Color(0.20, 0.65, 1.0, 0.35 * base_alpha), 7.0)
	draw_line(arrow_start, arrow_end, Color(0.55, 0.90, 1.0, 0.75 * base_alpha), 3.5)
	draw_line(arrow_start, arrow_end, Color(1.0, 1.0, 1.0, 0.95 * base_alpha), 1.5)

	# Flowing energy pulse bead along immediate trajectory
	var arrow_line_vec: Vector2 = arrow_end - arrow_start
	var bead_pos: Vector2 = arrow_start + arrow_line_vec * flow_t
	draw_circle(bead_pos, 3.0, Color(1.0, 1.0, 1.0, 0.95 * base_alpha))
	draw_circle(bead_pos, 5.5, Color(0.40, 0.85, 1.0, 0.40 * base_alpha))

	# Arrow head
	var arrow_norm: Vector2 = Vector2(active_hint_dir).normalized()
	var arrow_perp: Vector2 = Vector2(-arrow_norm.y, arrow_norm.x)
	var head_len: float = tile_size * 0.18
	var head_width: float = tile_size * 0.14
	var p1: Vector2 = arrow_end
	var p2: Vector2 = arrow_end - arrow_norm * head_len + arrow_perp * head_width
	var p3: Vector2 = arrow_end - arrow_norm * head_len - arrow_perp * head_width
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(0.55, 0.90, 1.0, 0.90 * base_alpha))

	# 4. Secondary Crate Push Trajectory (shows crate sliding to target beacon)
	if draw_crate_ghost:
		var push_norm: Vector2 = Vector2(push_dir_eff).normalized()
		var push_perp: Vector2 = Vector2(-push_norm.y, push_norm.x)
		var c_dest_center: Vector2 = effective_origin + Vector2(dest_tile) * tile_size + half_tile
		var c_arrow_start: Vector2 = push_src_center
		var c_arrow_end: Vector2 = c_dest_center - push_norm * (tile_size * 0.20)

		# Amber laser multi-tier glow
		draw_line(c_arrow_start, c_arrow_end, Color(1.0, 0.65, 0.15, 0.35 * base_alpha), 6.5)
		draw_line(c_arrow_start, c_arrow_end, Color(1.0, 0.85, 0.35, 0.75 * base_alpha), 3.0)
		draw_line(c_arrow_start, c_arrow_end, Color(1.0, 0.98, 0.85, 0.95 * base_alpha), 1.5)

		# Flowing energy pulse bead along crate trajectory
		var c_line_vec: Vector2 = c_arrow_end - c_arrow_start
		var c_bead_pos: Vector2 = c_arrow_start + c_line_vec * flow_t
		draw_circle(c_bead_pos, 3.0, Color(1.0, 0.95, 0.70, 0.95 * base_alpha))
		draw_circle(c_bead_pos, 5.5, Color(1.0, 0.75, 0.20, 0.40 * base_alpha))

		var c_p1: Vector2 = c_arrow_end
		var c_p2: Vector2 = c_arrow_end - push_norm * head_len + push_perp * head_width
		var c_p3: Vector2 = c_arrow_end - push_norm * head_len - push_perp * head_width
		draw_colored_polygon(PackedVector2Array([c_p1, c_p2, c_p3]), Color(1.0, 0.85, 0.35, 0.90 * base_alpha))


func _draw_swipe_preview(effective_origin: Vector2, ch: Dictionary) -> void:
	if not is_touching or preview_swipe_dir == Vector2i.ZERO or grid == null or is_level_won:
		return
	var t_pos: Vector2i = grid.player_pos + preview_swipe_dir
	var has_crate_ahead: bool = grid.is_inside(t_pos) and grid.has_crate(t_pos)
	var push_to: Vector2i = t_pos + preview_swipe_dir
	var blocked: bool = (not grid.is_inside(t_pos)) or grid.is_wall(t_pos)
	if has_crate_ahead:
		blocked = (not grid.is_inside(push_to)) or grid.is_wall(push_to) or grid.has_crate(push_to)

	var accent: Color = Color(1.0, 0.36, 0.30) if blocked else ch.get("goal_aura", Color(0.35, 0.88, 1.0))
	if grid.is_inside(t_pos):
		var t_rect: Rect2 = Rect2(effective_origin + Vector2(t_pos) * tile_size, Vector2(tile_size, tile_size)).grow(-4.0)
		draw_rect(t_rect, Color(accent.r, accent.g, accent.b, 0.16), true)
		draw_rect(t_rect, Color(accent.r, accent.g, accent.b, 0.65), false, 2.0)

	if has_crate_ahead and not blocked:
		var dest_rect: Rect2 = Rect2(effective_origin + Vector2(push_to) * tile_size, Vector2(tile_size, tile_size)).grow(-5.0)
		draw_rect(dest_rect, Color(accent.r, accent.g, accent.b, 0.12), true)
		draw_rect(dest_rect, Color(accent.r, accent.g, accent.b, 0.55), false, 1.8)

	# Directional chevron between player center and target tile
	var half: Vector2 = Vector2(tile_size * 0.5, tile_size * 0.5)
	var p_c: Vector2 = effective_origin + visual_player_pos * tile_size + half
	var d_vec: Vector2 = Vector2(preview_swipe_dir).normalized()
	var perp: Vector2 = Vector2(-d_vec.y, d_vec.x)
	var tip: Vector2 = p_c + d_vec * (tile_size * 0.62)
	var base: Vector2 = p_c + d_vec * (tile_size * 0.42)
	var chev_pts: PackedVector2Array = [tip, base + perp * (tile_size * 0.16), base - perp * (tile_size * 0.16)]
	draw_colored_polygon(chev_pts, Color(accent.r, accent.g, accent.b, 0.88))


func _draw_onboarding_cue(effective_origin: Vector2, ch: Dictionary) -> void:
	if grid == null or is_level_won or current_level_index != 0 or grid.moves_count > 0 or hint_time_remaining > 0.0:
		return
	if save_mgr != null and "has_completed_tutorial" in save_mgr and save_mgr.has_completed_tutorial:
		return

	var pulse: float = 0.55 + 0.45 * sin(tutorial_pulse_timer * 4.2)
	var accent: Color = ch.get("goal_aura", Color(0.98, 0.82, 0.25))
	var half: Vector2 = Vector2(tile_size * 0.5, tile_size * 0.5)
	var p_center: Vector2 = effective_origin + Vector2(grid.player_pos) * tile_size + half

	# Point from player toward first adjacent crate (or nearest crate)
	var cue_dir: Vector2i = Vector2i.ZERO
	for d in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var n: Vector2i = grid.player_pos + d
		if grid.has_crate(n):
			cue_dir = d
			break
	if cue_dir == Vector2i.ZERO and not grid.crates.is_empty():
		var first_crate: Vector2i = grid.crates.keys()[0]
		var diff: Vector2i = first_crate - grid.player_pos
		if absi(diff.x) >= absi(diff.y):
			cue_dir = Vector2i.RIGHT if diff.x > 0 else Vector2i.LEFT
		else:
			cue_dir = Vector2i.DOWN if diff.y > 0 else Vector2i.UP

	if cue_dir != Vector2i.ZERO:
		var dv: Vector2 = Vector2(cue_dir)
		var perp: Vector2 = Vector2(-dv.y, dv.x)
		var slide: float = (0.5 + 0.5 * sin(tutorial_pulse_timer * 4.2)) * (tile_size * 0.14)
		var tip: Vector2 = p_center + dv * (tile_size * 0.68 + slide)
		var base: Vector2 = p_center + dv * (tile_size * 0.44 + slide)
		draw_colored_polygon(
			PackedVector2Array([tip, base + perp * (tile_size * 0.16), base - perp * (tile_size * 0.16)]),
			Color(accent.r, accent.g, accent.b, 0.85 * pulse)
		)

	# Non-blocking floating instruction banner positioned clear of board tiles
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var msg: String = loc_mgr.tr_text("TUTORIAL_FIRST_PUSH") if loc_mgr else "Swipe or tap a tile to push crates onto ✦"
	var font_sz: int = 13
	var txt_sz: Vector2 = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
	var pill_w: float = minf(get_viewport_rect().size.x - 24.0, txt_sz.x + 28.0)
	var pill_h: float = 28.0
	var board_center_x: float = effective_origin.x + float(grid.width) * tile_size * 0.5
	var pill_x: float = clampf(board_center_x - pill_w * 0.5, 12.0, maxf(12.0, get_viewport_rect().size.x - pill_w - 12.0))
	var top_safe_y: float = top_bar.offset_bottom + 8.0 if top_bar != null else 102.0
	var pill_y: float = maxf(top_safe_y, effective_origin.y - pill_h - 10.0)
	if effective_origin.y - pill_h - 10.0 < top_safe_y:
		var board_bottom: float = effective_origin.y + float(grid.height) * tile_size + 10.0
		pill_y = minf(board_bottom, (bottom_bar.position.y - pill_h - 8.0) if bottom_bar != null else board_bottom)
	var pill_rect: Rect2 = Rect2(pill_x, pill_y, pill_w, pill_h)
	draw_rect(pill_rect, Color(0.05, 0.08, 0.13, 0.88), true)
	draw_rect(pill_rect, Color(accent.r, accent.g, accent.b, 0.70 * pulse), false, 1.5)
	var baseline_y: float = pill_rect.position.y + (pill_h + font.get_ascent(font_sz) - font.get_descent(font_sz)) * 0.5
	draw_string(font, Vector2(pill_rect.position.x + 14.0, baseline_y), msg, HORIZONTAL_ALIGNMENT_CENTER, pill_w - 28.0, font_sz, Color(0.95, 0.97, 1.0, 0.96))


func _draw_deadlock_radar(effective_origin: Vector2, _ch: Dictionary) -> void:
	if active_deadlocked_crates.is_empty() or grid == null:
		return

	var pulse_t: float = 0.5 + 0.5 * sin(deadlock_pulse_timer)
	var aura_alpha: float = lerp(0.40, 0.85, pulse_t)
	var halo_alpha: float = lerp(0.12, 0.35, pulse_t)
	var halo_color: Color = Color(1.0, 0.20, 0.15, halo_alpha)
	var aura_color: Color = Color(1.0, 0.25, 0.20, aura_alpha)
	var bracket_color: Color = Color(1.0, 0.82, 0.20, clampf(aura_alpha + 0.15, 0.0, 1.0))
	var bob_y: float = sin(deadlock_pulse_timer * 1.25) * 3.0

	for c_pos in active_deadlocked_crates:
		var draw_tile_pos: Vector2 = visual_crates.get(c_pos, Vector2(c_pos))
		var crate_padding: float = tile_size * 0.04
		var rect: Rect2 = Rect2(
			effective_origin + draw_tile_pos * tile_size + Vector2(crate_padding, crate_padding),
			Vector2(tile_size - crate_padding * 2.0, tile_size - crate_padding * 2.0)
		)

		# 1. Pulsing Soft Neon Hazard Halo & Perimeter
		var grow_px: float = 3.5 * pulse_t + 1.0
		draw_rect(rect.grow(grow_px), halo_color, false, 2.5)
		draw_rect(rect, aura_color, false, 1.8)

		# 2. Industrial Corner Demarcation Brackets
		var b_len: float = tile_size * 0.20
		# Top-Left Bracket
		draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x + b_len, rect.position.y), bracket_color, 2.4)
		draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.position.y + b_len), bracket_color, 2.4)
		# Top-Right Bracket
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - b_len, rect.position.y), bracket_color, 2.4)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + b_len), bracket_color, 2.4)
		# Bottom-Left Bracket
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + b_len, rect.end.y), bracket_color, 2.4)
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - b_len), bracket_color, 2.4)
		# Bottom-Right Bracket
		draw_line(Vector2(rect.end.x, rect.end.y), Vector2(rect.end.x - b_len, rect.end.y), bracket_color, 2.4)
		draw_line(Vector2(rect.end.x, rect.end.y), Vector2(rect.end.x, rect.end.y - b_len), bracket_color, 2.4)

		# 3. Floating Diegetic Ghost Warning Glyph (Diamond Backing + Exclamation Mark)
		var glyph_center: Vector2 = Vector2(rect.end.x - tile_size * 0.16, rect.position.y + tile_size * 0.14) + Vector2(0.0, bob_y)
		var d_rad: float = tile_size * 0.17
		var diamond_pts: PackedVector2Array = [
			glyph_center + Vector2(0.0, -d_rad),
			glyph_center + Vector2(d_rad, 0.0),
			glyph_center + Vector2(0.0, d_rad),
			glyph_center + Vector2(-d_rad, 0.0)
		]
		# Dark gunmetal diamond plate
		draw_colored_polygon(diamond_pts, Color(0.10, 0.08, 0.12, 0.92))
		# Neon rim on diamond
		var rim_col: Color = Color(1.0, 0.30, 0.22, 0.95)
		draw_line(diamond_pts[0], diamond_pts[1], rim_col, 1.6)
		draw_line(diamond_pts[1], diamond_pts[2], rim_col, 1.6)
		draw_line(diamond_pts[2], diamond_pts[3], rim_col, 1.6)
		draw_line(diamond_pts[3], diamond_pts[0], rim_col, 1.6)

		# Crisp Warning Exclamation Stem & Dot
		var mark_col: Color = Color(1.0, 0.92, 0.25, 0.98)
		draw_line(glyph_center + Vector2(0.0, -d_rad * 0.48), glyph_center + Vector2(0.0, d_rad * 0.12), mark_col, 2.2)
		draw_circle(glyph_center + Vector2(0.0, d_rad * 0.46), 1.35, mark_col)


func add_trauma(amount: float) -> void:
	board_trauma = clampf(board_trauma + amount, 0.0, 1.0)


func _spawn_push_dust(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var dir: Vector2i = to_pos - from_pos
	var base_origin: Vector2 = grid_origin + Vector2(from_pos) * tile_size
	var spawn_edge_center: Vector2 = base_origin + Vector2(tile_size * 0.5, tile_size * 0.5) - Vector2(dir) * (tile_size * 0.42)
	var rng: RandomNumberGenerator = _rng

	var crate_skin_id: String = save_mgr.selected_crate_skin if save_mgr else "classic_wood"
	var worker_skin_id: String = save_mgr.selected_worker_skin if save_mgr else "classic"

	# 1. Base boot traction dust puffs
	var dust_palette: Array[Color] = [
		Color(0.85, 0.80, 0.72, 0.85),
		Color(0.72, 0.67, 0.60, 0.80),
		Color(0.55, 0.50, 0.45, 0.70)
	]

	for i in range(5):
		var offset: Vector2 = Vector2.ZERO
		if dir.x != 0:
			offset = Vector2(0, rng.randf_range(-tile_size * 0.35, tile_size * 0.35))
		else:
			offset = Vector2(rng.randf_range(-tile_size * 0.35, tile_size * 0.35), 0)

		var back_vel: Vector2 = -Vector2(dir) * rng.randf_range(40.0, 85.0) + Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-15.0, 15.0))
		dust_particles.append({
			"pos": spawn_edge_center + offset,
			"vel": back_vel,
			"size": rng.randf_range(3.0, 5.5),
			"color": dust_palette[rng.randi() % dust_palette.size()],
			"life": rng.randf_range(0.22, 0.32),
			"max_life": 0.32
		})

	# 2. Material-specific friction particles along crate contact line
	var crate_edge_center: Vector2 = base_origin + Vector2(tile_size * 0.5, tile_size * 0.5) + Vector2(dir) * (tile_size * 0.46)
	match crate_skin_id:
		"steel_container":
			# High-speed metallic friction sparks shooting sideways
			for i in range(5):
				var lateral: Vector2 = Vector2(-dir.y, dir.x) * rng.randf_range(-65.0, 65.0)
				dust_particles.append({
					"pos": crate_edge_center + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0)),
					"vel": lateral + Vector2(dir) * rng.randf_range(15.0, 40.0),
					"size": rng.randf_range(2.0, 4.0),
					"color": Color(1.0, 0.95, 0.70, 0.95) if i % 2 == 0 else Color(0.80, 0.90, 1.0, 0.90),
					"life": rng.randf_range(0.18, 0.28),
					"max_life": 0.28
				})
		"hazard_box":
			# Electric caution sparks
			for i in range(4):
				var h_vel: Vector2 = Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-50.0, 50.0))
				dust_particles.append({
					"pos": crate_edge_center,
					"vel": h_vel,
					"size": rng.randf_range(2.5, 4.5),
					"color": Color(1.0, 0.75, 0.15, 0.95),
					"life": rng.randf_range(0.20, 0.30),
					"max_life": 0.30
				})
		"cryo_vault":
			# Drifting sub-zero frost mist
			for i in range(4):
				var c_vel: Vector2 = -Vector2(dir) * rng.randf_range(20.0, 45.0) + Vector2(0, rng.randf_range(-25.0, -5.0))
				dust_particles.append({
					"pos": crate_edge_center + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0)),
					"vel": c_vel,
					"size": rng.randf_range(3.5, 6.0),
					"color": Color(0.65, 0.92, 1.0, 0.85),
					"life": rng.randf_range(0.25, 0.38),
					"max_life": 0.38
				})
		"luxury_safe":
			# Golden stardust glints
			for i in range(4):
				dust_particles.append({
					"pos": crate_edge_center + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)),
					"vel": Vector2(rng.randf_range(-35.0, 35.0), rng.randf_range(-35.0, 35.0)),
					"size": rng.randf_range(3.0, 5.0),
					"color": Color(1.0, 0.88, 0.28, 0.95),
					"life": rng.randf_range(0.22, 0.32),
					"max_life": 0.32
				})

	# 3. Outfit-specific trailing accents
	if worker_skin_id == "golden_porter":
		for i in range(3):
			dust_particles.append({
				"pos": spawn_edge_center + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)),
				"vel": Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-25.0, 25.0)),
				"size": rng.randf_range(2.5, 4.5),
				"color": Color(1.0, 0.85, 0.20, 0.90),
				"life": 0.28,
				"max_life": 0.28
			})
	elif worker_skin_id == "hazmat":
		for i in range(2):
			dust_particles.append({
				"pos": spawn_edge_center,
				"vel": Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0)),
				"size": rng.randf_range(2.5, 4.0),
				"color": Color(0.30, 0.95, 0.40, 0.90),
				"life": 0.25,
				"max_life": 0.25
			})


func _spawn_goal_effect(goal_pos: Vector2i) -> void:
	var center: Vector2 = grid_origin + Vector2(goal_pos) * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
	var crate_skin_id: String = save_mgr.selected_crate_skin if save_mgr else "classic_wood"

	var ring_col: Color = Color(1.0, 0.88, 0.25, 0.95)
	var spark_col1: Color = Color(1.0, 0.92, 0.40, 1.0)
	var spark_col2: Color = Color(1.0, 0.65, 0.20, 1.0)

	match crate_skin_id:
		"cryo_vault":
			ring_col = Color(0.40, 0.90, 1.0, 0.95)
			spark_col1 = Color(0.85, 0.98, 1.0, 1.0)
			spark_col2 = Color(0.35, 0.85, 1.0, 1.0)
		"luxury_safe":
			ring_col = Color(1.0, 0.86, 0.20, 0.98)
			spark_col1 = Color(1.0, 0.95, 0.65, 1.0)
			spark_col2 = Color(1.0, 0.80, 0.20, 1.0)
		"hazard_box":
			ring_col = Color(1.0, 0.68, 0.12, 0.95)
			spark_col1 = Color(1.0, 0.85, 0.20, 1.0)
			spark_col2 = Color(1.0, 0.40, 0.10, 1.0)
		"steel_container":
			ring_col = Color(0.75, 0.88, 1.0, 0.95)
			spark_col1 = Color(0.95, 0.98, 1.0, 1.0)
			spark_col2 = Color(0.60, 0.75, 0.95, 1.0)

	# Primary expanding shockwave ring
	goal_effects.append({
		"type": "ring",
		"pos": center,
		"radius": 4.0,
		"max_radius": tile_size * 0.95,
		"color": ring_col,
		"life": 0.38,
		"max_life": 0.38
	})

	# Secondary inner radiant shockwave halo
	goal_effects.append({
		"type": "ring",
		"pos": center,
		"radius": 2.0,
		"max_radius": tile_size * 0.65,
		"color": Color(1.0, 1.0, 0.92, 0.90),
		"life": 0.25,
		"max_life": 0.25
	})

	# 12 radiating thematic sparks
	var rng: RandomNumberGenerator = _rng
	for i in range(12):
		var angle: float = (float(i) / 12.0) * TAU + rng.randf_range(-0.15, 0.15)
		var spd: float = rng.randf_range(120.0, 220.0)
		goal_effects.append({
			"type": "spark",
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"size": rng.randf_range(3.5, 6.5),
			"color": spark_col1 if i % 2 == 0 else spark_col2,
			"life": rng.randf_range(0.28, 0.44),
			"max_life": 0.44
		})


func _attach_spring_physics(btn: Button) -> void:
	if btn == null or btn.has_meta("has_spring_physics"):
		return
	btn.set_meta("has_spring_physics", true)
	var calc_pivot: Callable = func() -> void:
		var sz: Vector2 = btn.custom_minimum_size if btn.size == Vector2.ZERO else btn.size
		btn.pivot_offset = sz / 2.0
	calc_pivot.call()
	btn.button_down.connect(func():
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.07)
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


func _on_top_bar_draw() -> void:
	if top_bar == null:
		return
	var sz: Vector2 = top_bar.size
	# Industrial Corner Hex Screws
	_draw_terminal_bolt(top_bar, Vector2(10.0, 10.0))
	_draw_terminal_bolt(top_bar, Vector2(sz.x - 10.0, 10.0))


func _on_bottom_bar_draw() -> void:
	if bottom_bar == null:
		return
	var sz: Vector2 = bottom_bar.size
	# Industrial Corner Hex Screws
	_draw_terminal_bolt(bottom_bar, Vector2(10.0, sz.y - 10.0))
	_draw_terminal_bolt(bottom_bar, Vector2(sz.x - 10.0, sz.y - 10.0))


func _draw_terminal_bolt(ci: CanvasItem, pos: Vector2) -> void:
	# Outer dark recessed washer ring
	ci.draw_circle(pos, 4.2, Color(0.04, 0.05, 0.08, 0.95))
	# Beveled metallic hex screw head
	ci.draw_circle(pos, 3.2, Color(0.38, 0.42, 0.50, 0.95))
	# Specular glint
	ci.draw_circle(pos + Vector2(-0.8, -0.8), 1.2, Color(0.85, 0.90, 0.98, 0.90))
	# Inset cross drive slot
	ci.draw_line(pos + Vector2(-1.5, 0.0), pos + Vector2(1.5, 0.0), Color(0.12, 0.14, 0.18, 0.95), 1.0)
	ci.draw_line(pos + Vector2(0.0, -1.5), pos + Vector2(0.0, 1.5), Color(0.12, 0.14, 0.18, 0.95), 1.0)


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

	var skip_btn: Button = Button.new()
	skip_btn.name = "SkipLevelBtn"
	skip_btn.text = loc_mgr.tr_text("BTN_SKIP_LEVEL") if loc_mgr else "SKIP THIS LEVEL (LIFELINE)"
	skip_btn.custom_minimum_size = Vector2(0, 42)
	skip_btn.theme_type_variation = &"SecondaryButton"
	skip_btn.pressed.connect(_on_skip_level_pressed)
	_attach_spring_physics(skip_btn)
	btn_vbox.add_child(skip_btn)

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
	if loc_mgr and loc_mgr.has_method("apply_rtl"):
		loc_mgr.apply_rtl(ad_reward_modal)
	var skip_btn: Button = ad_reward_modal.find_child("SkipLevelBtn", true, false) as Button
	if skip_btn != null:
		skip_btn.visible = (current_level_index < level_paths.size() - 1)
	ad_reward_modal.show()
	ad_reward_modal.modulate.a = 0.0
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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


func _on_skip_level_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	_hide_ad_reward_modal()
	var next_idx: int = current_level_index + 1
	if next_idx < level_paths.size():
		if save_mgr != null:
			save_mgr.skip_level(current_level_index)
		load_level(next_idx)
		var msg: String = loc_mgr.tr_text("TOAST_LEVEL_SKIPPED", [next_idx + 1]) if loc_mgr else "Level Skipped! Resumed at Level %d" % (next_idx + 1)
		_show_hint_toast(msg, Color(0.35, 0.85, 1.0))
		if audio_mgr:
			audio_mgr.play_win()
		if haptic_mgr:
			haptic_mgr.vibrate_target()
	else:
		var no_skip_msg: String = loc_mgr.tr_text("TOAST_FINAL_NO_SKIP") if loc_mgr else "Final level cannot be skipped!"
		_show_hint_toast(no_skip_msg, Color(1.0, 0.7, 0.4))


func _on_rewarded_hints_earned(reward_type: String, amount: int) -> void:
	if reward_type == "hints":
		if save_mgr != null:
			save_mgr.add_hints(amount)
		_hide_ad_reward_modal()
		_update_hint_button_text()
		var msg: String = loc_mgr.tr_text("TOAST_HINTS_ADDED") if loc_mgr else "+3 Hints Added!"
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
			var info: Dictionary = achievement_mgr.get_achievement_info(id)
			_show_achievement_toast(info)


func _show_achievement_toast(info: Dictionary) -> void:
	_show_achievement_banner(info)
	if audio_mgr:
		audio_mgr.play_win()
	if haptic_mgr:
		haptic_mgr.vibrate_target()


# ==============================================================================
# Phase 1 UX Helpers: Tap-to-Walk, Deadlock Rewind Pill, Achievement Banner & Stage Picker
# ==============================================================================

func _stop_auto_walk() -> void:
	var was_active: bool = is_auto_walking or not auto_walk_path.is_empty()
	is_auto_walking = false
	auto_walk_path.clear()
	auto_walk_target = Vector2i(-1, -1)
	if was_active:
		queue_redraw()


func _try_tap_to_walk(screen_pos: Vector2) -> void:
	if save_mgr != null and "tap_to_walk_enabled" in save_mgr and not save_mgr.tap_to_walk_enabled:
		return
	if save_mgr != null and "control_scheme" in save_mgr and save_mgr.control_scheme == 1:
		return
	if grid == null or tile_size <= 0.0 or is_level_won:
		return
	if (win_modal and win_modal.visible) or (restart_dialog and restart_dialog.visible) or (ad_reward_modal and ad_reward_modal.visible) or (stage_picker_modal and stage_picker_modal.visible):
		return

	var rel: Vector2 = screen_pos - grid_origin
	if rel.x < 0.0 or rel.y < 0.0:
		return
	var target_tile: Vector2i = Vector2i(int(floor(rel.x / tile_size)), int(floor(rel.y / tile_size)))
	if not grid.is_in_bounds(target_tile):
		return

	# Guard 1-step taps near the character to avoid accidental grip slips (swipes handle 1-step precision)
	var manhattan_dist: int = abs(target_tile.x - grid.player_pos.x) + abs(target_tile.y - grid.player_pos.y)
	if manhattan_dist < 2:
		return
	if not grid.is_empty_tile(target_tile):
		return

	var path: Array[Vector2i] = SokobanSolverScript.find_player_walk_path(grid.player_pos, target_tile, grid)
	if path.is_empty():
		return

	auto_walk_path = path
	auto_walk_target = target_tile
	is_auto_walking = true
	queued_move_dir = Vector2i.ZERO
	clear_hint()
	queue_redraw()
	if not is_animating:
		_step_auto_walk()


func _step_auto_walk() -> void:
	if not is_auto_walking or auto_walk_path.is_empty() or grid == null or is_level_won:
		_stop_auto_walk()
		return
	var next_tile: Vector2i = auto_walk_path.pop_front()
	var dir: Vector2i = next_tile - grid.player_pos
	if abs(dir.x) + abs(dir.y) != 1 or not grid.is_empty_tile(next_tile):
		_stop_auto_walk()
		return
	try_move(dir, true)


func _draw_auto_walk_path(effective_origin: Vector2, ch: Dictionary) -> void:
	if not is_auto_walking or grid == null:
		return
	var accent: Color = ch.get("badge_color", Color(0.45, 0.88, 1.0))
	for step_pos in auto_walk_path:
		var pt: Vector2 = effective_origin + Vector2(step_pos) * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
		draw_circle(pt, maxf(2.5, tile_size * 0.08), Color(accent.r, accent.g, accent.b, 0.55))
	if auto_walk_target.x >= 0 and auto_walk_target.y >= 0:
		var t_rect: Rect2 = Rect2(effective_origin + Vector2(auto_walk_target) * tile_size, Vector2(tile_size, tile_size)).grow(-tile_size * 0.16)
		draw_rect(t_rect, Color(accent.r, accent.g, accent.b, 0.80), false, 2.0)


func _update_hint_toast_position() -> void:
	if hint_toast == null:
		return
	var safe_top: float = 0.0
	var safe_horiz: float = 0.0
	if safe_area_mgr != null:
		var insets: Dictionary = safe_area_mgr.get_safe_insets(self)
		safe_top = insets.get("top", 0.0)
		safe_horiz = insets.get("left", 0.0) + insets.get("right", 0.0)
	var top_h: float = 96.0 + safe_top
	if top_bar != null:
		var tb_bottom: float = top_bar.position.y + top_bar.size.y
		if tb_bottom > 10.0:
			top_h = maxf(top_h, tb_bottom)
	var vp_w: float = size.x if size.x > 0.0 else 540.0
	var half_w: float = minf(170.0, (vp_w - safe_horiz - 24.0) * 0.5)
	hint_toast.offset_left = -half_w
	hint_toast.offset_right = half_w
	hint_toast.offset_top = top_h + 8.0
	hint_toast.offset_bottom = top_h + 48.0


func _update_achievement_banner_position() -> void:
	if achievement_banner == null:
		return
	var safe_top: float = 0.0
	var safe_horiz: float = 0.0
	if safe_area_mgr != null:
		var insets: Dictionary = safe_area_mgr.get_safe_insets(self)
		safe_top = insets.get("top", 0.0)
		safe_horiz = insets.get("left", 0.0) + insets.get("right", 0.0)
	var top_h: float = 96.0 + safe_top
	if top_bar != null:
		var tb_bottom: float = top_bar.position.y + top_bar.size.y
		if tb_bottom > 10.0:
			top_h = maxf(top_h, tb_bottom)
	if hint_toast != null and hint_toast.visible:
		top_h = maxf(top_h, hint_toast.offset_bottom)
	var vp_w: float = size.x if size.x > 0.0 else 540.0
	var half_w: float = minf(185.0, (vp_w - safe_horiz - 24.0) * 0.5)
	achievement_banner.offset_left = -half_w
	achievement_banner.offset_right = half_w
	achievement_banner.offset_top = top_h + 8.0
	achievement_banner.offset_bottom = top_h + 62.0


func _create_achievement_banner() -> PanelContainer:
	var banner: PanelContainer = PanelContainer.new()
	banner.name = "AchievementBanner"
	banner.anchors_preset = Control.PRESET_TOP_WIDE
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.11, 0.18, 0.96)
	sb.border_color = Color(1.0, 0.84, 0.28, 1.0)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 8
	banner.add_theme_stylebox_override("panel", sb)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	banner.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = "TrophyIcon"
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = icon_trophy
	hbox.add_child(icon_rect)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(vbox)

	var header_lbl: Label = Label.new()
	header_lbl.name = "HeaderLabel"
	header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_lbl.text = "ACHIEVEMENT UNLOCKED"
	header_lbl.add_theme_font_size_override("font_size", 10)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	vbox.add_child(header_lbl)

	var title_lbl: Label = Label.new()
	title_lbl.name = "NameLabel"
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = "First Shift"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	vbox.add_child(title_lbl)

	add_child(banner)
	return banner


func _show_achievement_banner(info: Dictionary) -> void:
	if achievement_banner == null:
		achievement_banner = _create_achievement_banner()
	if loc_mgr and loc_mgr.has_method("apply_rtl"):
		loc_mgr.apply_rtl(achievement_banner)
	var header_lbl: Label = achievement_banner.find_child("HeaderLabel", true, false) as Label
	var name_lbl: Label = achievement_banner.find_child("NameLabel", true, false) as Label
	if header_lbl:
		header_lbl.text = loc_mgr.tr_text("ACHIEVEMENT_BANNER_HEADER") if loc_mgr else "ACHIEVEMENT UNLOCKED"
	if name_lbl:
		name_lbl.text = loc_mgr.tr_text(info.get("name_key", "")) if loc_mgr else info.get("name", "Achievement")
	_update_achievement_banner_position()

	if _achievement_banner_tw and _achievement_banner_tw.is_valid():
		_achievement_banner_tw.kill()
	achievement_banner.modulate.a = 0.0
	achievement_banner.show()
	_achievement_banner_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_achievement_banner_tw.tween_property(achievement_banner, "modulate:a", 1.0, 0.20)
	_achievement_banner_tw.tween_interval(2.6)
	_achievement_banner_tw.tween_property(achievement_banner, "modulate:a", 0.0, 0.35)
	_achievement_banner_tw.tween_callback(func():
		if achievement_banner:
			achievement_banner.hide()
	)


func _create_deadlock_pill() -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.name = "DeadlockPill"
	pill.anchors_preset = Control.PRESET_CENTER_BOTTOM
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.anchor_top = 1.0
	pill.anchor_bottom = 1.0
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pill.visible = false

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.09, 0.11, 0.96)
	sb.border_color = Color(1.0, 0.35, 0.30, 0.95)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 8
	pill.add_theme_stylebox_override("panel", sb)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	pill.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	var msg_lbl: Label = Label.new()
	msg_lbl.name = "MsgLabel"
	msg_lbl.text = "Crate trapped!"
	msg_lbl.add_theme_font_size_override("font_size", 12)
	msg_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.78))
	hbox.add_child(msg_lbl)

	var rew_btn: Button = Button.new()
	rew_btn.name = "RewindPushBtn"
	rew_btn.text = "Rewind Push"
	rew_btn.icon = icon_undo
	rew_btn.expand_icon = true
	rew_btn.add_theme_constant_override("icon_max_width", 16)
	rew_btn.add_theme_constant_override("h_separation", 5)
	rew_btn.custom_minimum_size = Vector2(118, 30)
	rew_btn.add_theme_font_size_override("font_size", 12)
	rew_btn.theme_type_variation = &"GameUndoButton"
	rew_btn.pressed.connect(_on_undo_push_pressed)
	_attach_spring_physics(rew_btn)
	hbox.add_child(rew_btn)

	add_child(pill)
	return pill


func _update_deadlock_pill() -> void:
	var should_show: bool = (
		not active_deadlocked_crates.is_empty()
		and grid != null
		and grid.can_undo_push()
		and not is_level_won
		and (win_modal == null or not win_modal.visible)
	)
	if not should_show:
		if deadlock_pill != null:
			deadlock_pill.hide()
		return
	if deadlock_pill == null:
		deadlock_pill = _create_deadlock_pill()
	if loc_mgr and loc_mgr.has_method("apply_rtl"):
		loc_mgr.apply_rtl(deadlock_pill)
	var msg_lbl: Label = deadlock_pill.find_child("MsgLabel", true, false) as Label
	var rew_btn: Button = deadlock_pill.find_child("RewindPushBtn", true, false) as Button
	if msg_lbl:
		msg_lbl.text = loc_mgr.tr_text("DEADLOCK_PILL_MSG") if loc_mgr else "Crate trapped!"
	if rew_btn:
		rew_btn.text = loc_mgr.tr_text("BTN_UNDO_PUSH") if loc_mgr else "Rewind Push"
	var bot_h: float = _get_actual_bottom_bar_height()
	if dpad_overlay != null and dpad_overlay.visible:
		bot_h += 176.0
	deadlock_pill.offset_left = -155.0
	deadlock_pill.offset_right = 155.0
	deadlock_pill.offset_bottom = -(bot_h + 10.0)
	deadlock_pill.offset_top = -(bot_h + 52.0)
	deadlock_pill.show()


func _on_stage_badge_gui_input(event: InputEvent) -> void:
	if (win_modal and win_modal.visible) or (restart_dialog and restart_dialog.visible) or (ad_reward_modal and ad_reward_modal.visible):
		return
	var clicked: bool = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked = true
	elif event is InputEventScreenTouch and event.pressed:
		clicked = true
	if clicked:
		_show_stage_picker()


func _show_stage_picker() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	_stop_auto_walk()
	if stage_picker_modal == null:
		stage_picker_modal = _create_stage_picker_modal()
	_refresh_stage_picker()
	stage_picker_modal.show()


func _hide_stage_picker() -> void:
	if stage_picker_modal != null:
		stage_picker_modal.hide()


func _create_stage_picker_modal() -> PanelContainer:
	var modal: PanelContainer = PanelContainer.new()
	modal.name = "StagePickerModal"
	modal.anchors_preset = Control.PRESET_FULL_RECT
	modal.anchor_right = 1.0
	modal.anchor_bottom = 1.0
	modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim: ColorRect = ColorRect.new()
	scrim.anchors_preset = Control.PRESET_FULL_RECT
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.color = Color(0.03, 0.05, 0.09, 0.84)
	scrim.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			_hide_stage_picker()
	)
	modal.add_child(scrim)

	var center: CenterContainer = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.name = "PickerCard"
	card.custom_minimum_size = Vector2(390, 440)
	card.theme_type_variation = &"WinModalPanel"
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.name = "PickerTitle"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.28))
	vbox.add_child(title_lbl)

	var nav_hbox: HBoxContainer = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(nav_hbox)

	var prev_btn: Button = Button.new()
	prev_btn.name = "PickerPrevBtn"
	prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_btn.custom_minimum_size = Vector2(0, 38)
	prev_btn.pressed.connect(func():
		if current_level_index > 0:
			_hide_stage_picker()
			is_daily_challenge = false
			load_level(current_level_index - 1)
	)
	_attach_spring_physics(prev_btn)
	nav_hbox.add_child(prev_btn)

	var nxt_btn: Button = Button.new()
	nxt_btn.name = "PickerNextBtn"
	nxt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt_btn.custom_minimum_size = Vector2(0, 38)
	nxt_btn.pressed.connect(func():
		var next_idx: int = current_level_index + 1
		if next_idx < level_paths.size() and (save_mgr == null or save_mgr.is_level_unlocked(next_idx)):
			_hide_stage_picker()
			is_daily_challenge = false
			load_level(next_idx)
	)
	_attach_spring_physics(nxt_btn)
	nav_hbox.add_child(nxt_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PickerScroll"
	scroll.custom_minimum_size = Vector2(0, 270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid_cnt: GridContainer = GridContainer.new()
	grid_cnt.name = "PickerGrid"
	grid_cnt.columns = 5
	grid_cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_cnt.add_theme_constant_override("h_separation", 6)
	grid_cnt.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid_cnt)

	var close_btn: Button = Button.new()
	close_btn.name = "PickerCloseBtn"
	close_btn.custom_minimum_size = Vector2(150, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_hide_stage_picker)
	_attach_spring_physics(close_btn)
	vbox.add_child(close_btn)

	add_child(modal)
	return modal


func _refresh_stage_picker() -> void:
	if stage_picker_modal == null:
		return
	var picker_card: PanelContainer = stage_picker_modal.find_child("PickerCard", true, false) as PanelContainer
	if picker_card != null:
		var vp_sz: Vector2 = get_viewport_rect().size if (is_inside_tree() and get_viewport() != null) else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
		var insets: Dictionary = safe_area_mgr.get_safe_insets(self) if safe_area_mgr else {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
		var max_w: float = clampf(vp_sz.x - insets.get("left", 0.0) - insets.get("right", 0.0) - 36.0, 280.0, 420.0)
		var max_h: float = clampf(vp_sz.y - insets.get("top", 0.0) - insets.get("bottom", 0.0) - 64.0, 320.0, 480.0)
		picker_card.custom_minimum_size = Vector2(max_w, max_h)
	var title_lbl: Label = stage_picker_modal.find_child("PickerTitle", true, false) as Label
	var prev_btn: Button = stage_picker_modal.find_child("PickerPrevBtn", true, false) as Button
	var nxt_btn: Button = stage_picker_modal.find_child("PickerNextBtn", true, false) as Button
	var close_btn: Button = stage_picker_modal.find_child("PickerCloseBtn", true, false) as Button
	var grid_cnt: GridContainer = stage_picker_modal.find_child("PickerGrid", true, false) as GridContainer

	if title_lbl:
		title_lbl.text = loc_mgr.tr_text("QUICK_PICKER_TITLE") if loc_mgr else "STAGE DISPATCH"
	if prev_btn:
		prev_btn.text = loc_mgr.tr_text("BTN_PREV_LEVEL") if loc_mgr else "◀ PREV"
		prev_btn.disabled = (current_level_index <= 0)
	if nxt_btn:
		nxt_btn.text = loc_mgr.tr_text("BTN_NEXT_LEVEL") if loc_mgr else "NEXT ▶"
		var next_idx: int = current_level_index + 1
		var next_unlocked: bool = (next_idx < level_paths.size()) and (save_mgr == null or save_mgr.is_level_unlocked(next_idx))
		nxt_btn.disabled = not next_unlocked
	if close_btn:
		close_btn.text = loc_mgr.tr_text("BTN_CLOSE") if loc_mgr else "Close"
	if loc_mgr and loc_mgr.has_method("apply_rtl"):
		loc_mgr.apply_rtl(stage_picker_modal)
	if grid_cnt == null:
		return
	grid_cnt.layout_direction = Control.LAYOUT_DIRECTION_LTR
	for child in grid_cnt.get_children():
		grid_cnt.remove_child(child)
		child.queue_free()

	for i in range(level_paths.size()):
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(56, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var unlocked: bool = (save_mgr == null or save_mgr.is_level_unlocked(i))
		var completed: bool = (save_mgr != null and save_mgr.is_level_completed(i))
		if i == current_level_index:
			b.theme_type_variation = &"PrimaryButton"
		elif completed:
			b.theme_type_variation = &"LevelBtnCompleted"
		elif unlocked:
			b.theme_type_variation = &"LevelBtnCurrent"
		else:
			b.theme_type_variation = &"LevelBtnLocked"
			b.disabled = true
			b.icon = icon_lock
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 12)

		if completed and save_mgr != null:
			var stars: int = save_mgr.get_level_stars(i)
			b.text = "%d\n%s" % [i + 1, "★".repeat(stars)]
			b.add_theme_font_size_override("font_size", 11)
		else:
			b.text = "%d" % (i + 1)
			b.add_theme_font_size_override("font_size", 12)
		if unlocked:
			b.pressed.connect(func():
				_hide_stage_picker()
				is_daily_challenge = false
				load_level(i)
			)
		grid_cnt.add_child(b)
