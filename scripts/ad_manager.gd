extends Node

## Monetization & AdMob Manager for Pixel Porter (PRD Section 8).
## Implements:
## - Interstitial ads only (Google AdMob test IDs by default).
## - Levels 1 to 3 (indices 0, 1, 2) are strictly ad-free.
## - One ad after every 3rd completed level post-tutorial.
## - Cooldown constraint: at least 60 seconds between ad displays.
## - Preloads ads so there is zero display latency on level transitions.
## - Never shows ads during a level, and never after restart.
## - EEA / UK Consent management hooks (UMP).
## - Seamless fallback simulation for desktop, testing, and headless runs.

signal interstitial_loaded
signal interstitial_failed_to_load(error_code: int)
signal interstitial_opened
signal interstitial_closed
signal rewarded_loaded
signal rewarded_failed_to_load(error_code: int)
signal rewarded_opened
signal rewarded_earned(reward_type: String, amount: int)
signal rewarded_closed
signal consent_status_changed(status: int)

enum ConsentStatus {
	UNKNOWN = 0,
	NOT_REQUIRED = 1,
	REQUIRED = 2,
	OBTAINED = 3
}

# Official Google AdMob Android test ad unit IDs
const TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"

# PRD Section 8 rules
const AD_FREE_LEVEL_THRESHOLD: int = 3 # Levels 1 to 3 are ad-free (indices 0, 1, 2)
const AD_FREQUENCY_LEVELS: int = 3     # One ad after every 3rd completed level
const MIN_COOLDOWN_MSEC: int = 60000   # At least 60 seconds between ads

var is_test_mode: bool = true
var interstitial_ad_unit_id: String = TEST_INTERSTITIAL_ID
var rewarded_ad_unit_id: String = TEST_REWARDED_ID
var is_interstitial_loaded: bool = false
var is_rewarded_loaded: bool = false
var is_showing_ad: bool = false
var is_showing_rewarded: bool = false

var completions_since_last_ad: int = 0
var last_ad_show_time_msec: int = -99999999
var total_ads_shown: int = 0
var consent_status: ConsentStatus = ConsentStatus.UNKNOWN

var _plugin_singleton: Object = null


func _ready() -> void:
	_init_plugin_or_simulator()
	request_consent()
	preload_interstitial()
	preload_rewarded()


func _init_plugin_or_simulator() -> void:
	# Detect mobile AdMob plugin if installed (e.g. PoingGodotAdMob or GodotAdMob)
	if Engine.has_singleton("PoingGodotAdMob"):
		_plugin_singleton = Engine.get_singleton("PoingGodotAdMob")
	elif Engine.has_singleton("GodotAdMob"):
		_plugin_singleton = Engine.get_singleton("GodotAdMob")

	if _plugin_singleton != null:
		_wire_plugin_signals()


func _wire_plugin_signals() -> void:
	if _plugin_singleton == null:
		return

	_connect_signal_variant([
		"interstitial_ad_loaded", "on_interstitial_ad_loaded", "interstitial_loaded", "_on_interstitial_loaded"
	], _on_plugin_interstitial_loaded)

	_connect_signal_variant([
		"interstitial_ad_opened", "on_interstitial_ad_opened", "interstitial_opened", "_on_interstitial_opened"
	], _on_plugin_interstitial_opened)

	_connect_signal_variant([
		"interstitial_ad_closed", "on_interstitial_ad_closed", "interstitial_closed", "_on_interstitial_closed", "_on_interstitial_close", "on_interstitial_dismissed"
	], _on_plugin_interstitial_closed)

	_connect_signal_variant([
		"rewarded_ad_loaded", "on_rewarded_ad_loaded", "rewarded_loaded", "_on_rewarded_video_ad_loaded"
	], _on_plugin_rewarded_loaded)

	_connect_signal_variant([
		"rewarded_ad_opened", "on_rewarded_ad_opened", "rewarded_opened", "_on_rewarded_video_ad_opened"
	], _on_plugin_rewarded_opened)

	_connect_signal_variant([
		"rewarded_ad_closed", "on_rewarded_ad_closed", "rewarded_closed", "_on_rewarded_video_ad_closed"
	], _on_plugin_rewarded_closed)

	_connect_signal_variant([
		"user_earned_rewarded", "on_user_earned_rewarded", "rewarded_earned", "_on_rewarded_video_ad_completed"
	], _on_plugin_rewarded_earned)


func _connect_signal_variant(variants: Array[String], callback: Callable) -> void:
	if _plugin_singleton == null:
		return
	for sig_name in variants:
		if _plugin_singleton.has_signal(sig_name):
			if not _plugin_singleton.is_connected(sig_name, callback):
				_plugin_singleton.connect(sig_name, callback)
			return


func _on_plugin_interstitial_loaded() -> void:
	is_interstitial_loaded = true
	interstitial_loaded.emit()


func _on_plugin_interstitial_opened() -> void:
	is_showing_ad = true
	interstitial_opened.emit()


func _on_plugin_interstitial_closed() -> void:
	is_showing_ad = false
	interstitial_closed.emit()
	preload_interstitial()


func _on_plugin_rewarded_loaded() -> void:
	is_rewarded_loaded = true
	rewarded_loaded.emit()


func _on_plugin_rewarded_opened() -> void:
	is_showing_rewarded = true
	rewarded_opened.emit()


func _on_plugin_rewarded_closed() -> void:
	is_showing_rewarded = false
	rewarded_closed.emit()
	preload_rewarded()


func _on_plugin_rewarded_earned(arg1: Variant = null, arg2: Variant = null) -> void:
	var r_type: String = "hints"
	var r_amount: int = 3
	if arg1 is String and not (arg1 as String).is_empty():
		r_type = arg1
	elif arg2 is String and not (arg2 as String).is_empty():
		r_type = arg2

	if arg1 is int and (arg1 as int) > 0:
		r_amount = arg1
	elif arg2 is int and (arg2 as int) > 0:
		r_amount = arg2
	rewarded_earned.emit(r_type, r_amount)


func _start_interstitial_watchdog() -> void:
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(12.0)
	timer.timeout.connect(func() -> void:
		if is_showing_ad:
			push_warning("AdManager: Interstitial ad watchdog triggered after 12s timeout.")
			_on_plugin_interstitial_closed()
	)


func _start_rewarded_watchdog() -> void:
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(15.0)
	timer.timeout.connect(func() -> void:
		if is_showing_rewarded:
			push_warning("AdManager: Rewarded ad watchdog triggered after 15s timeout.")
			_on_plugin_rewarded_closed()
	)


## Requests consent form status (EEA / UK UMP requirements).
func request_consent() -> void:
	if _plugin_singleton != null and _plugin_singleton.has_method("request_consent_info"):
		_plugin_singleton.request_consent_info()
	else:
		# Simulator / Development mode
		consent_status = ConsentStatus.OBTAINED
		consent_status_changed.emit(consent_status)


## Preloads an interstitial ad in the background (zero loading delay on transition).
func preload_interstitial() -> void:
	if is_interstitial_loaded:
		return

	if _plugin_singleton != null and _plugin_singleton.has_method("load_interstitial"):
		_plugin_singleton.load_interstitial(interstitial_ad_unit_id)
	else:
		# Simulator: mark loaded
		is_interstitial_loaded = true
		interstitial_loaded.emit()


## Evaluates whether an interstitial ad is eligible to be shown right now.
## PRD Rules:
## 1. Levels 1 to 3 are ad-free.
## 2. At least 60 seconds cooldown elapsed since last ad.
## 3. At least 3 completed levels since last ad (or reaching threshold).
func should_show_interstitial(level_index: int) -> bool:
	# Rule 1: Levels 1 to 3 (indices 0, 1, 2) are ad-free
	if level_index < AD_FREE_LEVEL_THRESHOLD:
		return false

	# Rule 2: Minimum 60 seconds cooldown between ads
	var now_msec: int = Time.get_ticks_msec()
	if (now_msec - last_ad_show_time_msec) < MIN_COOLDOWN_MSEC:
		return false

	# Rule 3: After level 3, one ad after every 3rd completed level
	if completions_since_last_ad < AD_FREQUENCY_LEVELS:
		return false

	return true


## Records that a level was completed and increments the cadence counter.
func record_level_completed(level_index: int) -> void:
	if level_index >= AD_FREE_LEVEL_THRESHOLD:
		completions_since_last_ad += 1


## Displays the preloaded interstitial ad if eligible and preloaded.
## Returns true if ad display was triggered, false otherwise.
func show_interstitial(level_index: int) -> bool:
	if not should_show_interstitial(level_index):
		return false

	if not is_interstitial_loaded:
		preload_interstitial()
		return false

	is_showing_ad = true
	is_interstitial_loaded = false
	last_ad_show_time_msec = Time.get_ticks_msec()
	completions_since_last_ad = 0
	total_ads_shown += 1

	interstitial_opened.emit()

	if _plugin_singleton != null and _plugin_singleton.has_method("show_interstitial"):
		_plugin_singleton.show_interstitial()
		_start_interstitial_watchdog()
	else:
		# Simulated interstitial ad: simulate quick display and auto-close
		_simulate_ad_close()

	return true


func _simulate_ad_close() -> void:
	# Signal ad close after brief simulation tick
	if is_inside_tree():
		await get_tree().create_timer(0.05).timeout
	is_showing_ad = false
	interstitial_closed.emit()
	preload_interstitial() # Preload next ad immediately


## Preloads a rewarded video ad in the background.
func preload_rewarded() -> void:
	if is_rewarded_loaded:
		return

	if _plugin_singleton != null and _plugin_singleton.has_method("load_rewarded"):
		_plugin_singleton.load_rewarded(rewarded_ad_unit_id)
	else:
		# Simulator: mark loaded
		is_rewarded_loaded = true
		rewarded_loaded.emit()


## Returns true if a rewarded video ad is loaded and ready to present.
func is_rewarded_ready() -> bool:
	return is_rewarded_loaded


## Shows a rewarded video ad for the hint economy.
## Returns true if the ad presentation was started, false otherwise.
func show_rewarded_for_hints() -> bool:
	if not is_rewarded_loaded:
		preload_rewarded()
		return false

	is_showing_rewarded = true
	is_rewarded_loaded = false
	rewarded_opened.emit()

	if _plugin_singleton != null and _plugin_singleton.has_method("show_rewarded"):
		_plugin_singleton.show_rewarded()
		_start_rewarded_watchdog()
	else:
		_simulate_rewarded_close()

	return true


func _simulate_rewarded_close() -> void:
	is_showing_rewarded = false
	rewarded_earned.emit("hints", 3)
	rewarded_closed.emit()
	preload_rewarded()


## Resets state counters (used for unit testing).
func reset_state() -> void:
	completions_since_last_ad = 0
	last_ad_show_time_msec = -99999999
	is_interstitial_loaded = false
	is_rewarded_loaded = false
	is_showing_ad = false
	is_showing_rewarded = false
	total_ads_shown = 0
