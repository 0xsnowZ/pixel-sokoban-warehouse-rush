extends Control

## End Screen controller shown after completing all 75 levels (PRD Section 6).
## Displays:
## - "Thank you for playing!" message
## - Total campaign statistics (levels solved, total best moves, total pushes)
## - "More levels coming soon!" teaser
## - Celebratory victory particles and fanfare
## - Multi-language localization (EN, FR, AR)
## - Replay / Level select and Main Menu navigation buttons

const SaveManagerScript = preload("res://scripts/save_manager.gd")

var save_mgr: Node = null
var audio_mgr: Node = null
var loc_mgr: Node = null
var haptic_mgr: Node = null
var safe_area_mgr: Node = null

var celebration_particles: Array[Dictionary] = []
var particle_spawn_timer: float = 0.0

@onready var margin_container: MarginContainer = $Margin
@onready var title_label: Label = $Margin/VBox/Title
@onready var thanks_label: Label = $Margin/VBox/StatsPanel/PanelMargin/PanelVBox/ThanksLabel
@onready var stats_label: Label = $Margin/VBox/StatsPanel/PanelMargin/PanelVBox/SummaryStatsLabel
@onready var more_levels_label: Label = $Margin/VBox/StatsPanel/PanelMargin/PanelVBox/MoreLevelsLabel
@onready var level_select_btn: Button = $Margin/VBox/Actions/LevelSelectBtn
@onready var menu_btn: Button = $Margin/VBox/Actions/MenuBtn


func _initialize_nodes() -> void:
	if margin_container == null and has_node("Margin"):
		margin_container = $Margin
	if title_label == null and has_node("Margin/VBox/Title"):
		title_label = $Margin/VBox/Title
		thanks_label = $Margin/VBox/StatsPanel/PanelMargin/PanelVBox/ThanksLabel
		stats_label = $Margin/VBox/StatsPanel/PanelMargin/PanelVBox/SummaryStatsLabel
		more_levels_label = $Margin/VBox/StatsPanel/PanelMargin/PanelVBox/MoreLevelsLabel
		level_select_btn = $Margin/VBox/Actions/LevelSelectBtn
		menu_btn = $Margin/VBox/Actions/MenuBtn


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

	if haptic_mgr == null and is_inside_tree() and get_tree().root.has_node("HapticManager"):
		haptic_mgr = get_tree().root.get_node("HapticManager")

	if safe_area_mgr == null and is_inside_tree() and get_tree().root.has_node("SafeAreaManager"):
		safe_area_mgr = get_tree().root.get_node("SafeAreaManager")
	if safe_area_mgr:
		safe_area_mgr.safe_area_changed.connect(_on_safe_area_changed)
		_apply_safe_area()

	if not level_select_btn.pressed.is_connected(_on_level_select_pressed):
		level_select_btn.pressed.connect(_on_level_select_pressed)
	if not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.pressed.connect(_on_menu_pressed)

	_update_ui()
	_spawn_initial_confetti()

	if audio_mgr:
		audio_mgr.play_win()
	if haptic_mgr:
		haptic_mgr.vibrate_win()

	_attach_spring_physics(level_select_btn)
	_attach_spring_physics(menu_btn)

	if has_node("Margin/VBox/TrophyIcon"):
		var trophy = $Margin/VBox/TrophyIcon
		trophy.pivot_offset = trophy.custom_minimum_size / 2.0 if trophy.size == Vector2.ZERO else trophy.size / 2.0
		var tw: Tween = create_tween().set_loops()
		tw.tween_property(trophy, "scale", Vector2(1.08, 1.08), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(trophy, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_safe_area() -> void:
	if safe_area_mgr != null and margin_container != null:
		safe_area_mgr.apply_safe_area_margins(margin_container, 24, 24, 24, 24, true, true)


func _on_safe_area_changed(_insets: Dictionary) -> void:
	_apply_safe_area()


func _update_ui() -> void:
	var total_solved: int = 0
	var total_moves: int = 0
	var total_pushes: int = 0
	var total_stars: int = 0

	if save_mgr and "completed_levels" in save_mgr:
		for key in save_mgr.completed_levels.keys():
			total_solved += 1
			var rec: Dictionary = save_mgr.completed_levels[key]
			total_moves += rec.get("best_moves", 0)
			total_pushes += rec.get("best_pushes", 0)
			total_stars += rec.get("stars", 0)

	if has_node("Margin/VBox/StatsPanel/PanelMargin/PanelVBox/StarsSummaryLabel"):
		var stars_lbl = $Margin/VBox/StatsPanel/PanelMargin/PanelVBox/StarsSummaryLabel as Label
		stars_lbl.text = "★ Total Stars: %d / 225 ★" % total_stars

	if loc_mgr:
		title_label.text = loc_mgr.tr_text("END_TITLE")
		thanks_label.text = loc_mgr.tr_text("END_THANKS")
		more_levels_label.text = loc_mgr.tr_text("END_MORE_LEVELS")
		stats_label.text = loc_mgr.tr_text("END_STATS_SUMMARY", [total_solved, total_moves, total_pushes])
		level_select_btn.text = loc_mgr.tr_text("BTN_REPLAY_LEVELS")
		menu_btn.text = loc_mgr.tr_text("BTN_MAIN_MENU")
	else:
		title_label.text = "CAMPAIGN COMPLETED!"
		thanks_label.text = "Thank you for playing Pixel Sokoban: Warehouse Rush!\nYou have mastered all 75 warehouse puzzles."
		more_levels_label.text = "★ More levels coming soon! ★"
		stats_label.text = "Levels Solved: %d / 75\nTotal Best Moves: %d\nTotal Best Pushes: %d" % [total_solved, total_moves, total_pushes]
		level_select_btn.text = "Level Select"
		menu_btn.text = "Main Menu"


func _spawn_initial_confetti() -> void:
	var viewport_sz: Vector2 = size if size != Vector2.ZERO else Vector2(540, 960)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var palette: Array[Color] = [
		Color(1.0, 0.84, 0.20), # Gold
		Color(0.25, 0.88, 0.45), # Emerald
		Color(0.95, 0.28, 0.35), # Ruby
		Color(0.35, 0.78, 1.0), # Sky
		Color(1.0, 0.96, 0.88) # Pearl
	]

	for i in range(60):
		var p_pos: Vector2 = Vector2(rng.randf_range(40, viewport_sz.x - 40), rng.randf_range(80, viewport_sz.y * 0.75))
		var angle: float = rng.randf_range(-PI, PI)
		var speed: float = rng.randf_range(80.0, 260.0)
		var life: float = rng.randf_range(1.8, 3.5)
		var p_type: String = "star" if (i % 4 == 0) else "ribbon"

		celebration_particles.append({
			"type": p_type,
			"pos": p_pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": palette[rng.randi() % palette.size()],
			"size": rng.randf_range(7.0, 12.0),
			"life": life,
			"max_life": life,
			"rot": rng.randf_range(0.0, TAU),
			"vrot": rng.randf_range(-6.0, 6.0)
		})


func _process(delta: float) -> void:
	particle_spawn_timer += delta
	# Continuous slow celebratory confetti shower
	if particle_spawn_timer >= 0.18:
		particle_spawn_timer = 0.0
		var viewport_sz: Vector2 = size if size != Vector2.ZERO else Vector2(540, 960)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		var palette: Array[Color] = [
			Color(1.0, 0.84, 0.20),
			Color(0.25, 0.88, 0.45),
			Color(0.95, 0.28, 0.35),
			Color(0.35, 0.78, 1.0)
		]
		var p_type: String = "star" if (rng.randf() < 0.25) else "ribbon"
		celebration_particles.append({
			"type": p_type,
			"pos": Vector2(rng.randf_range(20, viewport_sz.x - 20), -10),
			"vel": Vector2(rng.randf_range(-40, 40), rng.randf_range(80, 160)),
			"color": palette[rng.randi() % palette.size()],
			"size": rng.randf_range(7.0, 11.0),
			"life": 3.2,
			"max_life": 3.2,
			"rot": rng.randf_range(0.0, TAU),
			"vrot": rng.randf_range(-4.0, 4.0)
		})

	var i: int = celebration_particles.size() - 1
	while i >= 0:
		var p: Dictionary = celebration_particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			celebration_particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			p["vel"].y += 120.0 * delta # Gravity
			p["rot"] += p["vrot"] * delta
		i -= 1

	queue_redraw()


func _draw_star_shape(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(10):
		var r: float = radius if (i % 2 == 0) else (radius * 0.45)
		var a: float = i * (TAU / 10.0) - (PI / 2.0)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _draw() -> void:
	for p in celebration_particles:
		var alpha: float = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var p_col: Color = p["color"]
		p_col.a = alpha
		var half_sz: float = p["size"] * 0.5
		var p_type: String = p.get("type", "ribbon")

		if p_type == "star":
			_draw_star_shape(p["pos"], p["size"] * 0.85, p_col)
		else:
			# 3D perspective tumbling ribbon based on rotation
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


func _on_level_select_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_menu_pressed() -> void:
	if audio_mgr:
		audio_mgr.play_click()
	if haptic_mgr:
		haptic_mgr.vibrate_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _attach_spring_physics(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size / 2.0
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.07)
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
