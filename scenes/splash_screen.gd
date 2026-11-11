extends Control

## Splash Screen Controller for Pixel Porter.
## Fulfills PRD Section 6 screen #1 (Splash screen with the logo).
## Features smooth progress animation, localized status updates,
## tactile tap-to-skip, and graceful fade transition to Main Menu.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

@export var duration: float = 1.6

@onready var background: TextureRect = get_node_or_null("Background")
@onready var fade_overlay: ColorRect = get_node_or_null("FadeOverlay")
@onready var margin: MarginContainer = get_node_or_null("Margin")
@onready var progress_bar: ProgressBar = get_node_or_null("Margin/BottomVBox/LoadingBar")
@onready var status_label: Label = get_node_or_null("Margin/BottomVBox/StatusLabel")
@onready var prompt_label: Label = get_node_or_null("Margin/BottomVBox/PromptLabel")

var _is_transitioning: bool = false
var _progress_tween: Tween
var _pulse_tween: Tween
var dust_motes: Array[Dictionary] = []


func _ready() -> void:
	_ensure_node_refs()
	if fade_overlay:
		fade_overlay.modulate.a = 0.0

	_update_viewport_layout()
	_init_dust_motes()

	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	var safe_mgr: Node = null
	if is_inside_tree() and get_tree() and get_tree().root:
		safe_mgr = get_tree().root.get_node_or_null("SafeAreaManager")
	if safe_mgr and safe_mgr.has_signal("safe_area_changed"):
		if not safe_mgr.safe_area_changed.is_connected(_on_safe_area_changed):
			safe_mgr.safe_area_changed.connect(_on_safe_area_changed)

	if background:
		var vp_sz: Vector2 = get_viewport_rect().size if is_inside_tree() and get_viewport() != null else Vector2(540.0, 960.0)
		background.pivot_offset = vp_sz / 2.0
		var bg_tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bg_tw.tween_property(background, "scale", Vector2(1.035, 1.035), duration)

	if margin:
		margin.modulate.a = 0.0
		var margin_fade: Tween = create_tween()
		if margin_fade:
			margin_fade.tween_property(margin, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_update_localized_text(0.0)
	ResourceLoader.load_threaded_request(MAIN_MENU_SCENE_PATH)
	_start_loading_animation()
	_start_prompt_pulse()


func _update_viewport_layout() -> void:
	_ensure_node_refs()
	var vp_sz: Vector2 = get_viewport_rect().size if is_inside_tree() and get_viewport() != null else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
	if background:
		background.pivot_offset = vp_sz / 2.0
	_apply_safe_area()


func _apply_safe_area(custom_insets: Dictionary = {}) -> void:
	_ensure_node_refs()
	if not margin:
		return
	var insets: Dictionary = custom_insets
	if insets.is_empty():
		var safe_mgr: Node = null
		if is_inside_tree() and get_tree() and get_tree().root:
			safe_mgr = get_tree().root.get_node_or_null("SafeAreaManager")
		if safe_mgr and safe_mgr.has_method("get_safe_insets"):
			insets = safe_mgr.get_safe_insets(self)
		else:
			insets = { "bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0 }
	var bottom_pad: int = int(maxf(28.0, insets.get("bottom", 0.0) + 16.0))
	var left_pad: int = int(maxf(48.0, insets.get("left", 0.0) + 24.0))
	var right_pad: int = int(maxf(48.0, insets.get("right", 0.0) + 24.0))
	margin.add_theme_constant_override("margin_bottom", bottom_pad)
	margin.add_theme_constant_override("margin_left", left_pad)
	margin.add_theme_constant_override("margin_right", right_pad)


func _on_safe_area_changed(insets: Dictionary = {}) -> void:
	_apply_safe_area(insets)


func _on_viewport_size_changed() -> void:
	_update_viewport_layout()
	queue_redraw()


func _init_dust_motes() -> void:
	var vp_sz: Vector2 = get_viewport_rect().size if is_inside_tree() and get_viewport() != null else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	dust_motes.clear()
	for i in range(28):
		dust_motes.append({
			"pos": Vector2(rng.randf_range(20.0, vp_sz.x - 20.0), rng.randf_range(30.0, vp_sz.y - 40.0)),
			"vel": Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-14.0, -4.0)),
			"size": rng.randf_range(1.5, 3.2),
			"alpha": rng.randf_range(0.20, 0.50),
			"phase": rng.randf_range(0.0, TAU)
		})


func _process(delta: float) -> void:
	if dust_motes.is_empty():
		return
	var vp_sz: Vector2 = get_viewport_rect().size if is_inside_tree() and get_viewport() != null else (size if size != Vector2.ZERO else Vector2(540.0, 960.0))
	for m in dust_motes:
		m["phase"] += delta * 1.5
		m["pos"] += m["vel"] * delta + Vector2(sin(m["phase"]) * 4.0 * delta, 0)
		if m["pos"].y < 0:
			m["pos"].y = vp_sz.y
			m["pos"].x = randf_range(20.0, vp_sz.x - 20.0)
	queue_redraw()


func _draw() -> void:
	for m in dust_motes:
		var col: Color = Color(1.0, 0.95, 0.80, m["alpha"] * (0.8 + 0.2 * sin(m["phase"])))
		draw_circle(m["pos"], m["size"], col)


func _ensure_node_refs() -> void:
	if not background:
		background = get_node_or_null("Background")
	if not fade_overlay:
		fade_overlay = get_node_or_null("FadeOverlay")
	if not margin:
		margin = get_node_or_null("Margin")
	if not progress_bar:
		progress_bar = get_node_or_null("Margin/BottomVBox/LoadingBar")
	if not status_label:
		status_label = get_node_or_null("Margin/BottomVBox/StatusLabel")
	if not prompt_label:
		prompt_label = get_node_or_null("Margin/BottomVBox/PromptLabel")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		skip_to_main_menu()
		if get_viewport():
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	# Any tap, click, or keypress triggers instant skip to main menu
	if event is InputEventMouseButton and event.pressed:
		skip_to_main_menu()
	elif event is InputEventScreenTouch and event.pressed:
		skip_to_main_menu()
	elif event is InputEventKey and event.pressed and not event.echo:
		skip_to_main_menu()


func _start_loading_animation() -> void:
	_ensure_node_refs()
	if not progress_bar:
		return

	progress_bar.value = 0.0
	_progress_tween = create_tween()
	if _progress_tween:
		_progress_tween.set_trans(Tween.TRANS_QUAD)
		_progress_tween.set_ease(Tween.EASE_OUT)
		_progress_tween.tween_method(_on_progress_update, 0.0, 100.0, duration)
		_progress_tween.tween_callback(_on_loading_finished)


func _on_progress_update(val: float) -> void:
	_ensure_node_refs()
	if progress_bar:
		progress_bar.value = val
	_update_localized_text(val)


func _update_localized_text(val: float) -> void:
	_ensure_node_refs()
	if not status_label:
		return

	var loc_mgr: Node = null
	if is_inside_tree() and get_tree() and get_tree().root:
		loc_mgr = get_tree().root.get_node_or_null("LocalizationManager")
	var key: String = "SPLASH_INIT"

	if val < 40.0:
		key = "SPLASH_INIT"
	elif val < 90.0:
		key = "SPLASH_LEVELS"
	else:
		key = "SPLASH_READY"

	var base_text: String = ""
	if loc_mgr and loc_mgr.has_method("get_text"):
		base_text = loc_mgr.get_text(key)
	else:
		match key:
			"SPLASH_INIT":
				base_text = "INITIALIZING SYSTEM..."
			"SPLASH_LEVELS":
				base_text = "LOADING 50 SOKOBAN LEVELS..."
			"SPLASH_READY":
				base_text = "READY! TAP TO START"

	if val < 90.0:
		status_label.text = "%s %d%%" % [base_text, int(val)]
	else:
		status_label.text = base_text


func _start_prompt_pulse() -> void:
	_ensure_node_refs()
	if not prompt_label:
		return

	_pulse_tween = create_tween()
	if _pulse_tween:
		_pulse_tween.set_loops()
		_pulse_tween.tween_property(prompt_label, "modulate:a", 0.3, 0.6)
		_pulse_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.6)


func _on_loading_finished() -> void:
	if not _is_transitioning:
		_trigger_haptic()
		_transition_to_menu()


## Skips remainder of loading animation and immediately enters main menu
func skip_to_main_menu() -> void:
	if _is_transitioning:
		return

	_trigger_haptic()
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_transition_to_menu(0.15)


func _trigger_haptic() -> void:
	var haptic_mgr: Node = null
	if is_inside_tree() and get_tree() and get_tree().root:
		haptic_mgr = get_tree().root.get_node_or_null("HapticManager")
	if haptic_mgr and haptic_mgr.has_method("play_click"):
		haptic_mgr.play_click()


func _transition_to_menu(fade_time: float = 0.35) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	_ensure_node_refs()
	if fade_overlay:
		var fade: Tween = create_tween()
		if fade:
			fade.tween_property(fade_overlay, "modulate:a", 1.0, fade_time)
			fade.tween_callback(_change_scene)
		else:
			_change_scene()
	else:
		_change_scene()


func _change_scene() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	if ResourceLoader.load_threaded_get_status(MAIN_MENU_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene = ResourceLoader.load_threaded_get(MAIN_MENU_SCENE_PATH) as PackedScene
		if scene != null:
			tree.change_scene_to_packed(scene)
			return
	tree.change_scene_to_file(MAIN_MENU_SCENE_PATH)
