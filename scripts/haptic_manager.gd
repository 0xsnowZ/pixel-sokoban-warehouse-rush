extends Node

## Manages tactile haptic feedback for Pixel Porter (PRD Section 6).
## Provides subtle, distinct vibration pulses for crate pushes, goal snapping,
## level completion, UI clicks, and obstacle bumps.
## Seamlessly integrates with SaveManager for persistence and toggle settings.
## Works both as an Autoload singleton and as an instantiable node for tests.

signal haptics_toggled(enabled: bool)

# Vibration durations in milliseconds
const DURATION_PUSH: int = 30
const DURATION_TARGET: int = 45
const DURATION_WIN: int = 140
const DURATION_BUMP: int = 20
const DURATION_CLICK: int = 15
const DURATION_IMPACT: int = 55

# Vibration amplitudes (normalized 0.0 to 1.0, or -1.0 for system default)
const AMP_PUSH: float = 0.4
const AMP_TARGET: float = 0.6
const AMP_WIN: float = 0.8
const AMP_BUMP: float = 0.3
const AMP_CLICK: float = 0.2
const AMP_IMPACT: float = 0.70

var save_mgr: Node = null
var _local_enabled: bool = true

# Telemetry and unit testing inspection trackers
var total_vibrations_triggered: int = 0
var last_vibration_type: String = ""
var last_vibration_duration: int = 0
var last_vibration_amplitude: float = -1.0


func _ready() -> void:
	if is_inside_tree() and get_tree().root.has_node("SaveManager"):
		save_mgr = get_tree().root.get_node("SaveManager")


## Checks if the current platform and engine build support handheld vibration.
func is_haptic_supported() -> bool:
	return Input.has_method("vibrate_handheld")


## Returns true if haptics is enabled in user settings.
func is_haptic_enabled() -> bool:
	if save_mgr != null and "haptics_enabled" in save_mgr:
		return save_mgr.haptics_enabled
	return _local_enabled


## Explicitly sets whether haptic feedback is enabled.
func set_haptic_enabled(enabled: bool) -> void:
	_local_enabled = enabled
	if save_mgr != null and "haptics_enabled" in save_mgr:
		save_mgr.haptics_enabled = enabled
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()
	haptics_toggled.emit(enabled)


## Toggles haptic feedback on/off. If toggled on, plays a subtle confirmation pulse.
func toggle_haptics() -> bool:
	var new_state: bool = not is_haptic_enabled()
	set_haptic_enabled(new_state)
	if new_state:
		vibrate_click()
	return new_state


## Core invocation wrapper. Checks settings and hardware support before triggering.
func _vibrate(duration_ms: int, amplitude: float = -1.0, type_label: String = "custom") -> bool:
	if not is_haptic_enabled():
		return false

	total_vibrations_triggered += 1
	last_vibration_type = type_label
	last_vibration_duration = duration_ms
	last_vibration_amplitude = amplitude

	if is_haptic_supported():
		Input.vibrate_handheld(duration_ms, amplitude)
		return true

	return false


## Subtle vibration when pushing a crate (PRD Section 6).
func vibrate_push() -> bool:
	return _vibrate(DURATION_PUSH, AMP_PUSH, "push")


## Crisp, satisfying vibration when a crate snaps onto a target goal.
func vibrate_target() -> bool:
	return _vibrate(DURATION_TARGET, AMP_TARGET, "target")


## Celebratory, prolonged vibration when clearing a level (PRD Section 6).
func vibrate_win() -> bool:
	return _vibrate(DURATION_WIN, AMP_WIN, "win")


## Subtle tactile bump when colliding with a wall or unmovable object.
func vibrate_bump() -> bool:
	return _vibrate(DURATION_BUMP, AMP_BUMP, "bump")


## Pronounced tactile vibration for deadlocks or heavy obstacle impacts.
func vibrate_impact() -> bool:
	return _vibrate(DURATION_IMPACT, AMP_IMPACT, "impact")


## Micro-tap vibration for UI interactions and button presses.
func vibrate_click() -> bool:
	return _vibrate(DURATION_CLICK, AMP_CLICK, "click")


## Custom configurable vibration.
func vibrate_custom(duration_ms: int, amplitude: float = -1.0) -> bool:
	return _vibrate(duration_ms, amplitude, "custom")
