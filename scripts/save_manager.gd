extends Node

## Manages local persistence for Pixel Porter (PRD Sections 2, 6, & 11).
## Stores highest unlocked level, level records (best moves/pushes), and settings.
## Works both as an Autoload singleton and as an instantiable node for tests.

signal progress_saved
signal progress_loaded
signal level_unlocked(level_index: int)
signal hints_changed(new_count: int)
signal achievement_unlocked(achievement_id: String)
signal star_vault_claimed(vault_index: int, reward: Dictionary)
signal daily_challenge_completed_signal(streak: int, hints_awarded: int)

const DEFAULT_SAVE_PATH: String = "user://pixel_porter_save.json"

# Progression state (0-indexed: level 0 is Level 1)
var unlocked_level: int = 0
var last_played_level: int = 0
var completed_levels: Dictionary = {} # String(level_index) -> { "best_moves": int, "best_pushes": int }

# Settings (PRD Sections 6, 8, 9, 10)
var sound_enabled: bool = true
var music_enabled: bool = true
var music_volume: float = 0.7 # 0.0 to 1.0 linear volume
var sfx_volume: float = 0.8 # 0.0 to 1.0 linear volume
var selected_bgm_track: int = 0 # 0 = Lo-Fi Warehouse Shift, 1 = Industrial Pulse
var haptics_enabled: bool = true
var language: String = "en"
var control_scheme: int = 0 # 0 = Swipe, 1 = D-Pad, 2 = Dual (Swipe + D-Pad)

# The Porter Locker (Cosmetics & Star Economy - Phase 3)
var selected_worker_skin: String = "classic"
var selected_crate_skin: String = "classic_wood"

# Rewarded Ad Hint Economy & Achievements (Phase 4)
var hints_remaining: int = 3
var total_crates_pushed: int = 0
var unlocked_achievements: Array[String] = []
var last_hint_refill_date: String = ""

# Star Vault Milestones & Daily Warehouse Shift (Breakout Retention Engine)
var claimed_star_vaults: Array[int] = []
var daily_challenge_date: String = ""
var daily_challenge_streak: int = 0
var daily_challenge_completed: bool = false

# Progressive Star Vault Milestone Chests rewarding dedicated players
const STAR_VAULTS: Array[Dictionary] = [
	{ "stars": 15, "name": "Bronze Supply Cache", "reward_type": "hints", "amount": 5, "icon": "🥉" },
	{ "stars": 25, "name": "Safety Vest Locker", "reward_type": "skin", "skin_id": "safety_vest", "icon": "🦺" },
	{ "stars": 40, "name": "Steel Freight Vault", "reward_type": "skin", "skin_id": "steel_container", "icon": "🗄️" },
	{ "stars": 60, "name": "Foreman's Cache", "reward_type": "skin", "skin_id": "foreman", "icon": "👷" },
	{ "stars": 80, "name": "Cryo Vault Locker", "reward_type": "skin", "skin_id": "cryo_vault", "icon": "❄️" },
	{ "stars": 100, "name": "Golden Master Vault", "reward_type": "skin", "skin_id": "golden_porter", "icon": "👑" },
	{ "stars": 140, "name": "Quantum Solenoid Cache", "reward_type": "hints", "amount": 10, "icon": "⚛️" },
	{ "stars": 180, "name": "Plasma Core Vault", "reward_type": "hints", "amount": 15, "icon": "🔮" },
	{ "stars": 210, "name": "Grandmaster Apex Trophy", "reward_type": "hints", "amount": 25, "icon": "🏆" }
]


func _ready() -> void:
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()


## Returns true if the level at level_index is unlocked and playable.
func is_level_unlocked(level_index: int) -> bool:
	return level_index <= unlocked_level


## Unlocks up to target_level_index if it is higher than current unlocked_level.
func unlock_level(target_level_index: int) -> bool:
	if target_level_index > unlocked_level:
		unlocked_level = target_level_index
		level_unlocked.emit(unlocked_level)
		return true
	return false


# Mathematically verified optimal moves for all 75 levels
const OPTIMAL_MOVES: Array[int] = [
	9, 12, 18, 21, 22, 25, 26, 27, 28, 29,
	28, 28, 30, 30, 22, 35, 36, 26, 32, 38,
	34, 33, 26, 24, 36, 32, 44, 45, 46, 48,
	50, 51, 52, 52, 61, 64, 35, 76, 79, 82,
	83, 91, 24, 95, 98, 100, 100, 102, 106, 131,
	32, 34, 37, 36, 28, 25, 28, 24, 34, 25,
	30, 28, 31, 49, 22, 30, 27, 20, 33, 27,
	23, 22, 35, 21, 21
]


## Returns the optimal minimum moves target for a level.
func get_optimal_moves(level_index: int) -> int:
	if level_index >= 0 and level_index < OPTIMAL_MOVES.size():
		return OPTIMAL_MOVES[level_index]
	return 15


## Calculates earned stars (1 to 3) based on moves taken vs level optimal par.
## Uses adaptive tolerance: 3★ scales at 15% (min +2 moves) to be fair on long levels,
## while 2★ scales at 40% (min +5 moves) to maintain a rewarding middle tier.
func calculate_stars(level_index: int, moves: int) -> int:
	var optimal: int = get_optimal_moves(level_index)
	var tolerance_3: int = maxi(2, ceili(optimal * 0.15))
	var tolerance_2: int = maxi(5, ceili(optimal * 0.40))
	if moves <= optimal + tolerance_3:
		return 3
	elif moves <= optimal + tolerance_2:
		return 2
	return 1


## Returns a Dictionary with move targets for 3-star, 2-star, and optimal moves:
## { "optimal": int, "three_star": int, "two_star": int }
func get_star_targets(level_index: int) -> Dictionary:
	var optimal: int = get_optimal_moves(level_index)
	var tolerance_3: int = maxi(2, ceili(optimal * 0.15))
	var tolerance_2: int = maxi(5, ceili(optimal * 0.40))
	return {
		"optimal": optimal,
		"three_star": optimal + tolerance_3,
		"two_star": optimal + tolerance_2
	}


## Returns the best earned stars (0 to 3) for a given level.
func get_level_stars(level_index: int) -> int:
	var rec: Dictionary = get_level_record(level_index)
	return rec.get("stars", 0)


## Returns the total stars collected across all completed levels (out of 225).
func get_total_stars() -> int:
	var total: int = 0
	for rec in completed_levels.values():
		total += rec.get("stars", 0)
	return total


# 4 Warehouse Logistics Chapters across 75 levels (PRD Phase 2)
const CHAPTER_TIERS: Array[Dictionary] = [
	{ "id": 0, "name": "Cargo Bay", "start_level": 0, "end_level": 14, "icon": "📦", "color": Color(0.98, 0.82, 0.25) },
	{ "id": 1, "name": "Cold Storage", "start_level": 15, "end_level": 34, "icon": "❄", "color": Color(0.35, 0.85, 1.0) },
	{ "id": 2, "name": "Cyber Depot", "start_level": 35, "end_level": 49, "icon": "⚡", "color": Color(1.0, 0.65, 0.20) },
	{ "id": 3, "name": "Quantum Vault", "start_level": 50, "end_level": 74, "icon": "⚛️", "color": Color(0.85, 0.40, 1.00) }
]


func get_chapter_index(level_index: int) -> int:
	if level_index < 15:
		return 0
	elif level_index < 35:
		return 1
	elif level_index < 50:
		return 2
	return 3


func get_chapter_info(chapter_index: int) -> Dictionary:
	var idx: int = clampi(chapter_index, 0, CHAPTER_TIERS.size() - 1)
	return CHAPTER_TIERS[idx]


func get_level_chapter_info(level_index: int) -> Dictionary:
	return get_chapter_info(get_chapter_index(level_index))


func get_chapter_stars(chapter_index: int) -> int:
	var info: Dictionary = get_chapter_info(chapter_index)
	var s: int = 0
	for lvl in range(info["start_level"], info["end_level"] + 1):
		s += get_level_stars(lvl)
	return s


func is_chapter_completed(chapter_index: int) -> bool:
	var info: Dictionary = get_chapter_info(chapter_index)
	for lvl in range(info["start_level"], info["end_level"] + 1):
		if not is_level_completed(lvl):
			return false
	return true


# Porter Locker Unlockable Outfits & Crate Skins (Phase 3)
const WORKER_SKINS: Array[Dictionary] = [
	{
		"id": "classic",
		"name": "Classic Denim",
		"desc": "The signature red cap & blue work dungarees.",
		"name_key": "SKIN_WORKER_CLASSIC",
		"desc_key": "SKIN_WORKER_CLASSIC_DESC",
		"required_stars": 0,
		"icon": "🧢",
		"accent_color": Color(0.28, 0.50, 0.90),
		"sprite_tint": Color(1.0, 1.0, 1.0)
	},
	{
		"id": "safety_vest",
		"name": "Safety Vest",
		"desc": "High-visibility neon orange with reflective safety stripes.",
		"name_key": "SKIN_WORKER_SAFETY_VEST",
		"desc_key": "SKIN_WORKER_SAFETY_VEST_DESC",
		"required_stars": 25,
		"icon": "🦺",
		"accent_color": Color(1.0, 0.50, 0.10),
		"sprite_tint": Color(1.05, 0.90, 0.70)
	},
	{
		"id": "mechanic",
		"name": "Workshop Mechanic",
		"desc": "Heavy-duty navy workwear with a reinforced utility tool belt.",
		"name_key": "SKIN_WORKER_MECHANIC",
		"desc_key": "SKIN_WORKER_MECHANIC_DESC",
		"required_stars": 45,
		"icon": "🔧",
		"accent_color": Color(0.25, 0.45, 0.75),
		"sprite_tint": Color(0.85, 0.92, 1.05)
	},
	{
		"id": "foreman",
		"name": "Foreman",
		"desc": "Polished industrial hardhat & durable khaki workwear.",
		"name_key": "SKIN_WORKER_FOREMAN",
		"desc_key": "SKIN_WORKER_FOREMAN_DESC",
		"required_stars": 60,
		"icon": "👷",
		"accent_color": Color(0.95, 0.85, 0.20),
		"sprite_tint": Color(1.02, 0.96, 0.75)
	},
	{
		"id": "hazmat",
		"name": "Hazmat Specialist",
		"desc": "High-containment biosuit with a luminous protective visor.",
		"name_key": "SKIN_WORKER_HAZMAT",
		"desc_key": "SKIN_WORKER_HAZMAT_DESC",
		"required_stars": 95,
		"icon": "☣️",
		"accent_color": Color(0.20, 0.85, 0.40),
		"sprite_tint": Color(0.80, 1.10, 0.80)
	},
	{
		"id": "golden_porter",
		"name": "Golden Master",
		"desc": "Radiant prestige uniform reserved for master puzzle solvers.",
		"name_key": "SKIN_WORKER_GOLDEN_PORTER",
		"desc_key": "SKIN_WORKER_GOLDEN_PORTER_DESC",
		"required_stars": 120,
		"icon": "👑",
		"accent_color": Color(1.0, 0.84, 0.20),
		"sprite_tint": Color(1.20, 1.05, 0.40)
	}
]

const CRATE_SKINS: Array[Dictionary] = [
	{
		"id": "classic_wood",
		"name": "Classic Pine",
		"desc": "Traditional pine shipping crate with steel corner brackets.",
		"name_key": "SKIN_CRATE_CLASSIC_WOOD",
		"desc_key": "SKIN_CRATE_CLASSIC_WOOD_DESC",
		"required_stars": 0,
		"icon": "📦",
		"accent_color": Color(0.85, 0.65, 0.35),
		"tint": Color(1.0, 1.0, 1.0)
	},
	{
		"id": "steel_container",
		"name": "Steel Container",
		"desc": "Cold-rolled reinforced steel freight container.",
		"name_key": "SKIN_CRATE_STEEL_CONTAINER",
		"desc_key": "SKIN_CRATE_STEEL_CONTAINER_DESC",
		"required_stars": 40,
		"icon": "🗄️",
		"accent_color": Color(0.60, 0.75, 0.95),
		"tint": Color(0.75, 0.85, 0.98)
	},
	{
		"id": "cryo_vault",
		"name": "Cryo Container",
		"desc": "Sub-zero freight capsule with frost-reinforced seals.",
		"name_key": "SKIN_CRATE_CRYO_VAULT",
		"desc_key": "SKIN_CRATE_CRYO_VAULT_DESC",
		"required_stars": 65,
		"icon": "❄️",
		"accent_color": Color(0.35, 0.85, 1.0),
		"tint": Color(0.70, 0.92, 1.05)
	},
	{
		"id": "hazard_box",
		"name": "Hazard Crate",
		"desc": "High-voltage caution crate with pulsing safety markers.",
		"name_key": "SKIN_CRATE_HAZARD_BOX",
		"desc_key": "SKIN_CRATE_HAZARD_BOX_DESC",
		"required_stars": 80,
		"icon": "☣️",
		"accent_color": Color(1.0, 0.70, 0.15),
		"tint": Color(1.10, 0.88, 0.35)
	},
	{
		"id": "luxury_safe",
		"name": "Executive Safe",
		"desc": "Heavy reinforced gold-leaf vault for high-priority classified cargo.",
		"name_key": "SKIN_CRATE_LUXURY_SAFE",
		"desc_key": "SKIN_CRATE_LUXURY_SAFE_DESC",
		"required_stars": 140,
		"icon": "💎",
		"accent_color": Color(1.0, 0.84, 0.20),
		"tint": Color(1.15, 1.05, 0.75)
	}
]


func is_worker_skin_unlocked(skin_id: String) -> bool:
	var total: int = get_total_stars()
	for s in WORKER_SKINS:
		if s["id"] == skin_id:
			return total >= s["required_stars"]
	return false


func is_crate_skin_unlocked(skin_id: String) -> bool:
	var total: int = get_total_stars()
	for s in CRATE_SKINS:
		if s["id"] == skin_id:
			return total >= s["required_stars"]
	return false


func equip_worker_skin(skin_id: String) -> bool:
	if is_worker_skin_unlocked(skin_id):
		selected_worker_skin = skin_id
		save_data()
		return true
	return false


func equip_crate_skin(skin_id: String) -> bool:
	if is_crate_skin_unlocked(skin_id):
		selected_crate_skin = skin_id
		save_data()
		return true
	return false


func get_worker_skin_info(skin_id: String = "") -> Dictionary:
	var id: String = selected_worker_skin if skin_id.is_empty() else skin_id
	for s in WORKER_SKINS:
		if s["id"] == id:
			return s
	return WORKER_SKINS[0]


func get_crate_skin_info(skin_id: String = "") -> Dictionary:
	var id: String = selected_crate_skin if skin_id.is_empty() else skin_id
	for s in CRATE_SKINS:
		if s["id"] == id:
			return s
	return CRATE_SKINS[0]


func get_all_worker_skins() -> Array[Dictionary]:
	return WORKER_SKINS


func get_all_crate_skins() -> Array[Dictionary]:
	return CRATE_SKINS


## Records a level completion.
## Unlocks the next level (level_index + 1) and saves best scores and star rating.
func record_level_completion(level_index: int, moves: int, pushes: int, file_path: String = "") -> void:
	var key: String = str(level_index)
	var prev_record: Dictionary = completed_levels.get(key, {})

	var best_moves: int = moves
	var best_pushes: int = pushes
	var stars: int = calculate_stars(level_index, moves)
	var prev_stars: int = prev_record.get("stars", 0)
	var best_stars: int = maxi(prev_stars, stars)

	if not prev_record.is_empty():
		best_moves = mini(prev_record.get("best_moves", moves), moves)
		best_pushes = mini(prev_record.get("best_pushes", pushes), pushes)

	completed_levels[key] = {
		"best_moves": best_moves,
		"best_pushes": best_pushes,
		"last_moves": moves,
		"last_pushes": pushes,
		"stars": best_stars,
		"last_stars": stars
	}

	unlock_level(level_index + 1)
	last_played_level = level_index
	save_data(file_path)


## Retrieves the record for a given level, or an empty Dictionary if not yet completed.
func get_level_record(level_index: int) -> Dictionary:
	return completed_levels.get(str(level_index), {})


## Checks if a level has been completed at least once.
func is_level_completed(level_index: int) -> bool:
	return completed_levels.has(str(level_index))


## Serializes all progression and settings into a Dictionary.
func to_dict() -> Dictionary:
	return {
		"version": 1,
		"unlocked_level": unlocked_level,
		"last_played_level": last_played_level,
		"completed_levels": completed_levels,
		"settings": {
			"sound_enabled": sound_enabled,
			"music_enabled": music_enabled,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"selected_bgm_track": selected_bgm_track,
			"haptics_enabled": haptics_enabled,
			"language": language,
			"control_scheme": control_scheme
		},
		"cosmetics": {
			"worker_skin": selected_worker_skin,
			"crate_skin": selected_crate_skin
		},
		"economy": {
			"hints_remaining": hints_remaining,
			"total_crates_pushed": total_crates_pushed,
			"unlocked_achievements": unlocked_achievements,
			"last_hint_refill_date": last_hint_refill_date,
			"claimed_star_vaults": claimed_star_vaults,
			"daily_challenge_date": daily_challenge_date,
			"daily_challenge_streak": daily_challenge_streak,
			"daily_challenge_completed": daily_challenge_completed
		}
	}


## Deserializes progression and settings from a Dictionary.
func from_dict(data: Dictionary) -> void:
	unlocked_level = data.get("unlocked_level", 0)
	last_played_level = data.get("last_played_level", 0)
	completed_levels = data.get("completed_levels", {}).duplicate()

	var settings: Dictionary = data.get("settings", {})
	sound_enabled = settings.get("sound_enabled", true)
	music_enabled = settings.get("music_enabled", true)
	music_volume = float(settings.get("music_volume", 0.7))
	sfx_volume = float(settings.get("sfx_volume", 0.8))
	selected_bgm_track = int(settings.get("selected_bgm_track", 0))
	haptics_enabled = settings.get("haptics_enabled", true)
	language = settings.get("language", "en")
	control_scheme = int(settings.get("control_scheme", 0))

	var cosmetics: Dictionary = data.get("cosmetics", {})
	selected_worker_skin = cosmetics.get("worker_skin", "classic")
	selected_crate_skin = cosmetics.get("crate_skin", "classic_wood")

	var economy: Dictionary = data.get("economy", {})
	hints_remaining = int(economy.get("hints_remaining", 3))
	total_crates_pushed = int(economy.get("total_crates_pushed", 0))
	var raw_achievements: Array = economy.get("unlocked_achievements", []) as Array
	unlocked_achievements = []
	for a in raw_achievements:
		unlocked_achievements.append(str(a))
	last_hint_refill_date = str(economy.get("last_hint_refill_date", ""))

	var raw_vaults: Array = economy.get("claimed_star_vaults", []) as Array
	claimed_star_vaults = []
	for v in raw_vaults:
		claimed_star_vaults.append(int(v))
	daily_challenge_date = str(economy.get("daily_challenge_date", ""))
	daily_challenge_streak = int(economy.get("daily_challenge_streak", 0))
	daily_challenge_completed = bool(economy.get("daily_challenge_completed", false))


## Saves game state to JSON on disk atomically with backup copy protection.
func save_data(custom_path: String = "") -> bool:
	var target_path: String = custom_path if not custom_path.is_empty() else DEFAULT_SAVE_PATH
	var temp_path: String = target_path + ".tmp"
	var bak_path: String = target_path + ".bak"

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open temp save file for writing at: %s (Error: %s)" % [temp_path, FileAccess.get_open_error()])
		return false

	var json_string: String = JSON.stringify(to_dict(), "\t")
	file.store_string(json_string)
	file.flush()
	file.close()

	# Keep backup copy of last good save file
	if FileAccess.file_exists(target_path):
		DirAccess.copy_absolute(target_path, bak_path)
		DirAccess.remove_absolute(target_path)

	# Atomically rename temp file to target
	var rename_err: Error = DirAccess.rename_absolute(temp_path, target_path)
	if rename_err != OK:
		# Fallback if rename fails across partitions/devices
		DirAccess.copy_absolute(temp_path, target_path)
		DirAccess.remove_absolute(temp_path)

	progress_saved.emit()
	return true


## Loads game state from JSON on disk. Returns false if file doesn't exist or is invalid.
## Automatically recovers from .bak backup file if primary file is corrupted.
func load_data(custom_path: String = "") -> bool:
	var target_path: String = custom_path if not custom_path.is_empty() else DEFAULT_SAVE_PATH
	var bak_path: String = target_path + ".bak"

	# Try primary file first
	var success: bool = _try_load_file(target_path)
	if success:
		progress_loaded.emit()
		return true

	# If primary file failed, check if backup file exists
	if FileAccess.file_exists(bak_path):
		push_warning("SaveManager: Primary save corrupted or invalid at %s. Attempting restore from backup: %s" % [target_path, bak_path])
		var bak_success: bool = _try_load_file(bak_path)
		if bak_success:
			push_warning("SaveManager: Successfully recovered player data from backup!")
			save_data(target_path) # Restore primary save from loaded backup data
			progress_loaded.emit()
			return true

	return false


func _try_load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return false

	var json: JSON = JSON.new()
	var error: Error = json.parse(content)
	if error != OK:
		return false

	var parsed_data: Variant = json.data
	if not parsed_data is Dictionary:
		return false

	from_dict(parsed_data)
	return true


## Resets all progression back to initial new-game state.
func reset_all_progress(custom_path: String = "") -> void:
	unlocked_level = 0
	last_played_level = 0
	completed_levels.clear()
	sound_enabled = true
	music_enabled = true
	music_volume = 0.7
	sfx_volume = 0.8
	selected_bgm_track = 0
	haptics_enabled = true
	language = "en"
	control_scheme = 0
	selected_worker_skin = "classic"
	selected_crate_skin = "classic_wood"
	hints_remaining = 3
	total_crates_pushed = 0
	unlocked_achievements.clear()
	last_hint_refill_date = ""
	claimed_star_vaults.clear()
	daily_challenge_date = ""
	daily_challenge_streak = 0
	daily_challenge_completed = false
	save_data(custom_path)
	var target_path: String = custom_path if not custom_path.is_empty() else DEFAULT_SAVE_PATH
	var bak_path: String = target_path + ".bak"
	if FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(bak_path)


func get_hints_remaining() -> int:
	return hints_remaining


func use_hint() -> bool:
	if hints_remaining > 0:
		hints_remaining -= 1
		hints_changed.emit(hints_remaining)
		save_data()
		return true
	return false


func add_hints(amount: int) -> void:
	hints_remaining += amount
	hints_changed.emit(hints_remaining)
	save_data()


func record_crate_push() -> void:
	total_crates_pushed += 1


func is_achievement_unlocked(id: String) -> bool:
	return unlocked_achievements.has(id)


func unlock_achievement(id: String) -> bool:
	if not is_achievement_unlocked(id):
		unlocked_achievements.append(id)
		achievement_unlocked.emit(id)
		save_data()
		return true
	return false


func get_control_scheme_name() -> String:
	match control_scheme:
		1: return "D-PAD"
		2: return "DUAL"
		_: return "SWIPE"


func cycle_control_scheme() -> int:
	control_scheme = (control_scheme + 1) % 3
	save_data()
	return control_scheme


# ==============================================================================
# Star Vault Milestones & Daily Warehouse Shift System (Breakout Hit Engine)
# ==============================================================================

func get_all_star_vaults() -> Array[Dictionary]:
	return STAR_VAULTS


func is_star_vault_claimed(vault_index: int) -> bool:
	return claimed_star_vaults.has(vault_index)


func get_unclaimed_star_vaults() -> Array[Dictionary]:
	var unclaimed: Array[Dictionary] = []
	var current_stars: int = get_total_stars()
	for i in range(STAR_VAULTS.size()):
		var vault: Dictionary = STAR_VAULTS[i]
		if current_stars >= vault["stars"] and not is_star_vault_claimed(i):
			unclaimed.append({
				"index": i,
				"vault": vault
			})
	return unclaimed


func claim_star_vault(vault_index: int) -> Dictionary:
	if vault_index < 0 or vault_index >= STAR_VAULTS.size():
		return {}
	if is_star_vault_claimed(vault_index):
		return {}

	var vault: Dictionary = STAR_VAULTS[vault_index]
	if get_total_stars() < vault["stars"]:
		return {}

	claimed_star_vaults.append(vault_index)

	# Grant reward
	if vault.get("reward_type") == "hints":
		add_hints(vault.get("amount", 3))
	elif vault.get("reward_type") == "skin":
		var s_id: String = vault.get("skin_id", "")
		if not s_id.is_empty():
			if is_worker_skin_unlocked(s_id):
				equip_worker_skin(s_id)
			elif is_crate_skin_unlocked(s_id):
				equip_crate_skin(s_id)

	star_vault_claimed.emit(vault_index, vault)
	save_data()
	return vault


func get_today_date_str() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func get_daily_challenge_info() -> Dictionary:
	var today: String = get_today_date_str()
	if daily_challenge_date != today:
		# New calendar day detected
		if not daily_challenge_date.is_empty() and not daily_challenge_completed:
			# Missed yesterday's challenge -> reset streak
			daily_challenge_streak = 0
		daily_challenge_date = today
		daily_challenge_completed = false
		save_data()

	var parts: PackedStringArray = today.split("-")
	var y: int = parts[0].to_int() if parts.size() > 0 else 2026
	var m: int = parts[1].to_int() if parts.size() > 1 else 11
	var d: int = parts[2].to_int() if parts.size() > 2 else 7
	# Deterministic day seed selecting from quality warehouse puzzles (levels 5 to 44)
	var day_seed: int = (y * 372 + m * 31 + d)
	var level_idx: int = 5 + (day_seed % 40)

	return {
		"date": today,
		"level_index": level_idx,
		"streak": daily_challenge_streak,
		"is_completed": daily_challenge_completed,
		"reward_hints": 3
	}


func record_daily_challenge_completed() -> Dictionary:
	if daily_challenge_completed:
		return get_daily_challenge_info()

	daily_challenge_completed = true
	daily_challenge_streak += 1
	var hints_awarded: int = 3
	add_hints(hints_awarded)
	daily_challenge_completed_signal.emit(daily_challenge_streak, hints_awarded)
	save_data()
	return get_daily_challenge_info()


## Unlocks the next level and advances progress when player uses a Level Skip lifeline.
func skip_level(level_index: int) -> bool:
	var target: int = level_index + 1
	unlock_level(target)
	last_played_level = target
	save_data()
	return true
