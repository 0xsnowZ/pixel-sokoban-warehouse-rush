extends Node

## Handles display cutouts, camera notches, and gesture navigation bar insets
## for mobile devices (PRD Section 9: "Use safe-area margins for notches and system bars").
## Supports runtime detection via DisplayServer, dynamic resizing, and simulation for tests.
## Works both as an Autoload singleton and as an instantiable node.

signal safe_area_changed(insets: Dictionary)

var simulated_insets: Dictionary = {}
var has_simulation: bool = false


func _ready() -> void:
	if is_inside_tree() and get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		safe_area_changed.emit(get_safe_insets())


func _on_viewport_size_changed() -> void:
	safe_area_changed.emit(get_safe_insets())


## Returns safe insets in logical viewport pixels { "top": float, "bottom": float, "left": float, "right": float }.
func get_safe_insets(control_node: Control = null) -> Dictionary:
	if has_simulation:
		return simulated_insets.duplicate()

	if not DisplayServer.has_method("get_display_safe_area"):
		return { "top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0 }

	# On desktop platforms (Linux, Windows, macOS), display cutouts/notches do not exist
	var os_name: String = OS.get_name()
	if os_name != "Android" and os_name != "iOS":
		return { "top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0 }

	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()

	# If no cutout or in desktop/headless environment
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return { "top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0 }

	# If safe rect is equal to window size, no insets needed
	if safe_rect.position == Vector2i.ZERO and safe_rect.size == window_size:
		return { "top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0 }

	# Scale factor from physical screen pixels to logical canvas/viewport units
	var vp_size: Vector2 = Vector2(540, 960)
	if control_node != null and control_node.is_inside_tree() and control_node.get_viewport() != null:
		vp_size = control_node.get_viewport_rect().size
	elif is_inside_tree() and get_viewport() != null:
		vp_size = get_viewport().get_visible_rect().size

	var scale_x: float = vp_size.x / float(window_size.x)
	var scale_y: float = vp_size.y / float(window_size.y)

	var top_inset: float = float(safe_rect.position.y) * scale_y
	var left_inset: float = float(safe_rect.position.x) * scale_x
	var right_inset: float = float(window_size.x - (safe_rect.position.x + safe_rect.size.x)) * scale_x
	var bottom_inset: float = float(window_size.y - (safe_rect.position.y + safe_rect.size.y)) * scale_y

	return {
		"top": maxf(top_inset, 0.0),
		"bottom": maxf(bottom_inset, 0.0),
		"left": maxf(left_inset, 0.0),
		"right": maxf(right_inset, 0.0)
	}


## Applies safe insets to a MarginContainer, adding to base margin values.
func apply_safe_area_margins(
	container: MarginContainer,
	base_left: int = 16,
	base_top: int = 10,
	base_right: int = 16,
	base_bottom: int = 10,
	pad_top: bool = true,
	pad_bottom: bool = true
) -> void:
	if container == null:
		return

	var insets: Dictionary = get_safe_insets(container)
	var new_top: int = base_top + (int(round(insets.get("top", 0.0))) if pad_top else 0)
	var new_bottom: int = base_bottom + (int(round(insets.get("bottom", 0.0))) if pad_bottom else 0)
	var new_left: int = base_left + int(round(insets.get("left", 0.0)))
	var new_right: int = base_right + int(round(insets.get("right", 0.0)))

	container.add_theme_constant_override("margin_top", new_top)
	container.add_theme_constant_override("margin_bottom", new_bottom)
	container.add_theme_constant_override("margin_left", new_left)
	container.add_theme_constant_override("margin_right", new_right)


## Simulates device cutouts (notch, navigation pill) for automated testing or in-editor preview.
func simulate_insets(top: float, bottom: float, left: float = 0.0, right: float = 0.0) -> void:
	simulated_insets = {
		"top": top,
		"bottom": bottom,
		"left": left,
		"right": right
	}
	has_simulation = true
	safe_area_changed.emit(simulated_insets.duplicate())


## Clears simulated insets to resume native hardware detection.
func clear_simulation() -> void:
	simulated_insets.clear()
	has_simulation = false
	safe_area_changed.emit(get_safe_insets())
