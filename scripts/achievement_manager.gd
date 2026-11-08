extends Node

## Achievement Manager for Pixel Porter (Phase 4: Google Play Games & In-Game Achievements).
## Manages achievement definitions, unlock triggers, in-game notification toasts,
## and integration with SaveManager and Google Play Games.

signal achievement_unlocked(id: String, info: Dictionary)

const ACHIEVEMENTS: Array[Dictionary] = [
	{
		"id": "first_shift",
		"icon": "📦",
		"name": "First Shift",
		"name_key": "ACH_FIRST_SHIFT",
		"desc": "Complete your very first warehouse shift.",
		"desc_key": "ACH_FIRST_SHIFT_DESC"
	},
	{
		"id": "cargo_master",
		"icon": "🚚",
		"name": "Logistics Specialist",
		"name_key": "ACH_CARGO_MASTER",
		"desc": "Conquer all 15 levels of Chapter 1 Cargo Bay.",
		"desc_key": "ACH_CARGO_MASTER_DESC"
	},
	{
		"id": "cold_storage",
		"icon": "❄️",
		"name": "Sub-Zero Handler",
		"name_key": "ACH_COLD_STORAGE",
		"desc": "Conquer all 20 levels of Chapter 2 Cold Storage.",
		"desc_key": "ACH_COLD_STORAGE_DESC"
	},
	{
		"id": "quantum_master",
		"icon": "⚛️",
		"name": "Quantum Master",
		"name_key": "ACH_QUANTUM_MASTER",
		"desc": "Conquer all 25 levels of Chapter 4 Quantum Vault.",
		"desc_key": "ACH_QUANTUM_MASTER_DESC"
	},
	{
		"id": "depot_cleared",
		"icon": "🏆",
		"name": "Unstoppable Porter",
		"name_key": "ACH_DEPOT_CLEARED",
		"desc": "Complete all 75 handcrafted warehouse levels.",
		"desc_key": "ACH_DEPOT_CLEARED_DESC"
	},
	{
		"id": "precision_starter",
		"icon": "⭐",
		"name": "Precision Starter",
		"name_key": "ACH_PRECISION_STARTER",
		"desc": "Earn 3 stars on at least 5 levels.",
		"desc_key": "ACH_PRECISION_STARTER_DESC"
	},
	{
		"id": "precision_master",
		"icon": "🌟",
		"name": "Precision Master",
		"name_key": "ACH_PRECISION_MASTER",
		"desc": "Earn 3 stars on at least 25 levels.",
		"desc_key": "ACH_PRECISION_MASTER_DESC"
	},
	{
		"id": "puzzle_perfectionist",
		"icon": "👑",
		"name": "Puzzle Perfectionist",
		"name_key": "ACH_PERFECTIONIST",
		"desc": "Achieve 3 stars on all 75 levels (225 Stars).",
		"desc_key": "ACH_PERFECTIONIST_DESC"
	},
	{
		"id": "stylin_porter",
		"icon": "🦺",
		"name": "Stylin' Porter",
		"name_key": "ACH_STYLIN_PORTER",
		"desc": "Equip any unlockable cosmetic from the Supply Depot.",
		"desc_key": "ACH_STYLIN_PORTER_DESC"
	},
	{
		"id": "heavy_lifter",
		"icon": "💪",
		"name": "Heavy Lifter",
		"name_key": "ACH_HEAVY_LIFTER",
		"desc": "Push 100 crates across all your warehouse shifts.",
		"desc_key": "ACH_HEAVY_LIFTER_DESC"
	}
]

var save_mgr: Node = null
var _play_games_singleton: Object = null


func _ready() -> void:
	if is_inside_tree() and get_tree().root.has_node("SaveManager"):
		save_mgr = get_tree().root.get_node("SaveManager")

	if Engine.has_singleton("GodotPlayGames"):
		_play_games_singleton = Engine.get_singleton("GodotPlayGames")


## Returns metadata dictionary for a given achievement id.
func get_achievement_info(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}


## Returns all 10 achievement definitions.
func get_all_achievements() -> Array[Dictionary]:
	return ACHIEVEMENTS


## Returns true if the achievement is already unlocked in save data.
func is_unlocked(id: String, custom_save_mgr: Node = null) -> bool:
	var mgr = custom_save_mgr if custom_save_mgr != null else save_mgr
	if mgr != null:
		return mgr.is_achievement_unlocked(id)
	return false


## Attempts to unlock an achievement. Returns true if newly unlocked.
func unlock(id: String, custom_save_mgr: Node = null) -> bool:
	var mgr = custom_save_mgr if custom_save_mgr != null else save_mgr
	var info = get_achievement_info(id)
	if info.is_empty():
		return false

	if mgr != null:
		var newly_unlocked: bool = mgr.unlock_achievement(id)
		if newly_unlocked:
			_notify_google_play_games(id)
			achievement_unlocked.emit(id, info)
			return true
	return false


## Evaluates game progress against achievement milestones.
func evaluate_progress(custom_save_mgr: Node = null) -> Array[String]:
	var mgr = custom_save_mgr if custom_save_mgr != null else save_mgr
	var newly_unlocked: Array[String] = []
	if mgr == null:
		return newly_unlocked

	# 1. First Shift (Completed level 0)
	if mgr.is_level_completed(0):
		if unlock("first_shift", mgr):
			newly_unlocked.append("first_shift")

	# 2. Logistics Specialist (Completed all 15 levels of Chapter 0)
	if mgr.is_chapter_completed(0):
		if unlock("cargo_master", mgr):
			newly_unlocked.append("cargo_master")

	# 3. Sub-Zero Handler (Completed all 20 levels of Chapter 1)
	if mgr.is_chapter_completed(1):
		if unlock("cold_storage", mgr):
			newly_unlocked.append("cold_storage")

	# 4. Quantum Master (Completed all 25 levels of Chapter 3)
	if mgr.is_chapter_completed(3):
		if unlock("quantum_master", mgr):
			newly_unlocked.append("quantum_master")

	# 5. Unstoppable Porter (Completed all 75 levels)
	var all_levels_done: bool = true
	for lvl in range(75):
		if not mgr.is_level_completed(lvl):
			all_levels_done = false
			break
	if all_levels_done and mgr.completed_levels.size() >= 75:
		if unlock("depot_cleared", mgr):
			newly_unlocked.append("depot_cleared")

	# 6. Star milestones
	var three_star_count: int = 0
	for lvl in range(75):
		if mgr.get_level_stars(lvl) == 3:
			three_star_count += 1

	if three_star_count >= 5:
		if unlock("precision_starter", mgr):
			newly_unlocked.append("precision_starter")

	if three_star_count >= 25:
		if unlock("precision_master", mgr):
			newly_unlocked.append("precision_master")

	if mgr.get_total_stars() >= 225:
		if unlock("puzzle_perfectionist", mgr):
			newly_unlocked.append("puzzle_perfectionist")

	# 7. Cosmetics check
	if mgr.selected_worker_skin != "classic" or mgr.selected_crate_skin != "classic_wood":
		if unlock("stylin_porter", mgr):
			newly_unlocked.append("stylin_porter")

	# 7. Heavy lifter check (100 crates pushed)
	if mgr.total_crates_pushed >= 100:
		if unlock("heavy_lifter", mgr):
			newly_unlocked.append("heavy_lifter")

	return newly_unlocked


## Returns number of unlocked achievements out of 9.
func get_unlocked_count(custom_save_mgr: Node = null) -> int:
	var mgr = custom_save_mgr if custom_save_mgr != null else save_mgr
	if mgr == null:
		return 0
	return mgr.unlocked_achievements.size()


func _notify_google_play_games(id: String) -> void:
	if _play_games_singleton != null and _play_games_singleton.has_method("unlock_achievement"):
		_play_games_singleton.unlock_achievement(id)
