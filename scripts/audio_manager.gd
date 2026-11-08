extends Node

## Central Audio Manager for Pixel Porter (PRD Section 9 & 6).
## Synthesizes and plays authentic retro 8-bit sound effects:
## - Move / Step: Short subtle blip
## - Push Crate: Punchy low square wave thud
## - Level Complete: Cheerful ascending 8-bit arpeggio
## - Restart: Descending rewind sweep
## - UI Click: Crisp feedback click
## Respects SaveManager.sound_enabled toggle.

const MIX_RATE: int = 22050

var save_mgr: Node = null

# Cached procedural streams
var sfx_move: AudioStreamWAV
var sfx_move_alt: AudioStreamWAV
var sfx_push: AudioStreamWAV
var sfx_push_cold: AudioStreamWAV
var sfx_push_cyber: AudioStreamWAV
var sfx_bump: AudioStreamWAV
var sfx_undo: AudioStreamWAV
var sfx_win: AudioStreamWAV
var sfx_restart: AudioStreamWAV
var sfx_click: AudioStreamWAV
var sfx_ui_click: AudioStreamWAV
var sfx_ui_back: AudioStreamWAV
var sfx_ui_equip: AudioStreamWAV
var sfx_modal_open: AudioStreamWAV
var sfx_modal_close: AudioStreamWAV
var sfx_goal_lock: AudioStreamWAV
var sfx_goal_unlock: AudioStreamWAV
var sfx_star1: AudioStreamWAV
var sfx_star2: AudioStreamWAV
var sfx_star3: AudioStreamWAV
var sfx_hint: AudioStreamWAV
var sfx_deadlock: AudioStreamWAV

# Dynamic Anti-Fatigue Footstep & Voice Management
var _footstep_toggle: bool = false
var _next_player_idx: int = 0

# BGM Track Constants
const TRACK_LOFI: int = 0
const TRACK_INDUSTRIAL: int = 1
const BGM_TRACKS: Array[Dictionary] = [
	{
		"id": 0,
		"key": "TRACK_LOFI",
		"name": "Warehouse Chill",
		"path": "res://assets/audio/bgm_lofi_shift.ogg"
	},
	{
		"id": 1,
		"key": "TRACK_INDUSTRIAL",
		"name": "Industrial Pulse",
		"path": "res://assets/audio/bgm_industrial_pulse.ogg"
	}
]

# Music player & cached BGM streams
var music_player: AudioStreamPlayer = null
var current_bgm_track: int = -1
var _bgm_streams: Dictionary = {}
var _duck_offset_db: float = 0.0
var _music_fade_tween: Tween = null

# AudioStreamPlayer voice pool for overlapping SFX
var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 6


func _ready() -> void:
	# Retrieve SaveManager if present
	if is_inside_tree() and get_tree().root.has_node("SaveManager"):
		save_mgr = get_tree().root.get_node("SaveManager")

	_create_player_pool()
	_create_music_player()
	_generate_all_sfx()
	_load_bgm_streams()

	if is_music_enabled():
		var initial_track: int = save_mgr.selected_bgm_track if save_mgr != null and "selected_bgm_track" in save_mgr else TRACK_LOFI
		play_music(initial_track)


func _create_player_pool() -> void:
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _create_music_player() -> void:
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		music_player.bus = "Master"
		add_child(music_player)


func _load_bgm_streams() -> void:
	for track in BGM_TRACKS:
		var path: String = track["path"]
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream != null:
				if stream is AudioStreamOggVorbis:
					stream.loop = true
				_bgm_streams[track["id"]] = stream
		elif FileAccess.file_exists(path):
			var stream = AudioStreamOggVorbis.load_from_file(path)
			if stream != null:
				stream.loop = true
				_bgm_streams[track["id"]] = stream


func is_sound_enabled() -> bool:
	if save_mgr != null and "sound_enabled" in save_mgr:
		return save_mgr.sound_enabled
	return true


func is_music_enabled() -> bool:
	if save_mgr != null and "music_enabled" in save_mgr:
		return save_mgr.music_enabled
	return true


func get_music_volume_db() -> float:
	var linear: float = 0.7
	if save_mgr != null and "music_volume" in save_mgr:
		linear = save_mgr.music_volume
	if linear <= 0.01:
		return -80.0
	return linear_to_db(clampf(linear, 0.001, 1.0))


func get_effective_music_volume_db() -> float:
	var base_db: float = get_music_volume_db()
	if base_db <= -75.0:
		return -80.0
	return clampf(base_db + _duck_offset_db, -80.0, 6.0)


func get_sfx_volume_db() -> float:
	var linear: float = 0.8
	if save_mgr != null and "sfx_volume" in save_mgr:
		linear = save_mgr.sfx_volume
	if linear <= 0.01:
		return -80.0
	return linear_to_db(clampf(linear, 0.001, 1.0))


func play_music(track_index: int = -1) -> void:
	if track_index < 0:
		track_index = save_mgr.selected_bgm_track if save_mgr != null and "selected_bgm_track" in save_mgr else TRACK_LOFI

	if not is_music_enabled():
		stop_music()
		return

	current_bgm_track = track_index
	if save_mgr != null and "selected_bgm_track" in save_mgr:
		save_mgr.selected_bgm_track = track_index
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()

	var stream = _bgm_streams.get(track_index, null)
	if stream == null:
		_load_bgm_streams()
		stream = _bgm_streams.get(track_index, null)

	if stream != null and music_player != null:
		music_player.stream = stream
		music_player.volume_db = get_effective_music_volume_db()
		if music_player.is_inside_tree() and DisplayServer.get_name() != "headless":
			music_player.play()


func _exit_tree() -> void:
	cleanup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()


func cleanup() -> void:
	stop_music()
	if music_player != null and is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_bgm_streams.clear()


func stop_music() -> void:
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	if music_player != null and music_player.playing:
		music_player.stop()


func fade_out_music(duration: float = 0.8) -> void:
	if music_player == null or not music_player.playing or not is_inside_tree():
		stop_music()
		return
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_music_fade_tween.tween_property(music_player, "volume_db", -80.0, maxf(duration, 0.05))
	_music_fade_tween.tween_callback(func():
		if music_player != null:
			music_player.stop()
	)


func fade_in_music(track_index: int = -1, duration: float = 0.8) -> void:
	play_music(track_index)
	if music_player != null and music_player.playing and is_inside_tree():
		var target_db: float = get_effective_music_volume_db()
		music_player.volume_db = -80.0
		_smooth_volume_to(target_db, duration)


func duck_music(amount_db: float = -16.0, duration: float = 0.35) -> void:
	_duck_offset_db = amount_db
	_smooth_volume_to(get_effective_music_volume_db(), duration)


func unduck_music(duration: float = 0.7) -> void:
	_duck_offset_db = 0.0
	_smooth_volume_to(get_effective_music_volume_db(), duration)


func _smooth_volume_to(target_db: float, duration: float) -> void:
	if music_player == null or not is_inside_tree() or not is_music_enabled():
		return
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_music_fade_tween.tween_property(music_player, "volume_db", target_db, maxf(duration, 0.05))


func switch_music_track(track_index: int) -> void:
	var next_track: int = track_index % BGM_TRACKS.size()
	play_music(next_track)


func set_music_volume(linear_vol: float) -> void:
	if save_mgr != null and "music_volume" in save_mgr:
		save_mgr.music_volume = clampf(linear_vol, 0.0, 1.0)
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()
	if music_player != null:
		music_player.volume_db = get_effective_music_volume_db()


func set_sfx_volume(linear_vol: float) -> void:
	if save_mgr != null and "sfx_volume" in save_mgr:
		save_mgr.sfx_volume = clampf(linear_vol, 0.0, 1.0)
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()


func set_music_enabled(enabled: bool) -> void:
	if save_mgr != null and "music_enabled" in save_mgr:
		save_mgr.music_enabled = enabled
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()
	if enabled:
		play_music(current_bgm_track if current_bgm_track >= 0 else TRACK_LOFI)
	else:
		stop_music()


func set_sound_enabled(enabled: bool) -> void:
	if save_mgr != null and "sound_enabled" in save_mgr:
		save_mgr.sound_enabled = enabled
		if save_mgr.has_method("save_data"):
			save_mgr.save_data()


func get_track_name(track_index: int) -> String:
	if track_index >= 0 and track_index < BGM_TRACKS.size():
		return BGM_TRACKS[track_index]["name"]
	return "Warehouse Chill"


func play_stream(stream: AudioStreamWAV, volume_db: float = 0.0, pitch_scale: float = 1.0, pitch_randomness: float = 0.0) -> void:
	if not is_inside_tree() or not is_sound_enabled() or stream == null:
		return

	var sfx_vol_db: float = get_sfx_volume_db()
	if sfx_vol_db <= -75.0:
		return # Muted
	var final_db: float = volume_db + sfx_vol_db

	var final_pitch: float = pitch_scale
	if pitch_randomness > 0.0:
		final_pitch *= randf_range(1.0 - pitch_randomness, 1.0 + pitch_randomness)

	# Find an available idle player
	for p in _players:
		if p.is_inside_tree() and not p.playing:
			p.stream = stream
			p.volume_db = final_db
			p.pitch_scale = final_pitch
			p.play()
			return

	# Round-robin voice stealing fallback when all channels are occupied
	if not _players.is_empty():
		var fallback_player: AudioStreamPlayer = _players[_next_player_idx]
		_next_player_idx = (_next_player_idx + 1) % _players.size()
		if fallback_player.is_inside_tree():
			fallback_player.stream = stream
			fallback_player.volume_db = final_db
			fallback_player.pitch_scale = final_pitch
			fallback_player.play()


## Player movement step sound with left/right footstep alternating rhythm and organic pitch jitter
func play_move() -> void:
	_footstep_toggle = not _footstep_toggle
	var stream: AudioStreamWAV = sfx_move if _footstep_toggle else (sfx_move_alt if sfx_move_alt != null else sfx_move)
	play_stream(stream, -7.0, 1.0, 0.04)


## Heavy warehouse crate push with physical weight, friction texture, and chapter-specific acoustics
func play_push(chapter_idx: int = 0) -> void:
	var stream: AudioStreamWAV = sfx_push
	match chapter_idx:
		1:
			stream = sfx_push_cold if sfx_push_cold != null else sfx_push
		2:
			stream = sfx_push_cyber if sfx_push_cyber != null else sfx_push
		_:
			stream = sfx_push
	play_stream(stream, -1.0, 1.0, 0.05)


## Wall collision / obstacle recoil knock
func play_bump() -> void:
	play_stream(sfx_bump if sfx_bump != null else sfx_click, -2.5, 1.0, 0.04)


## Time rewind / move undo sound
func play_undo() -> void:
	play_stream(sfx_undo if sfx_undo != null else sfx_click, -2.0, 1.0, 0.03)


## Level won grand acoustic celebration fanfare with music ducking
func play_win() -> void:
	duck_music(-10.0, 0.12)
	play_stream(sfx_win, 1.0)
	var tw: Tween = create_tween()
	tw.tween_interval(0.68)
	tw.tween_callback(func(): unduck_music(0.45))


## Level restart sound
func play_restart() -> void:
	play_stream(sfx_restart, -2.5, 1.0, 0.02)


## Tactile UI button click
func play_click() -> void:
	play_stream(sfx_click, -4.0, 1.0, 0.03)


## Clean tactile switch click for navigation
func play_ui_click() -> void:
	play_stream(sfx_ui_click if sfx_ui_click != null else sfx_click, -4.0, 1.0, 0.02)


## Mellow back/cancel button click
func play_ui_back() -> void:
	play_stream(sfx_ui_back if sfx_ui_back != null else sfx_click, -4.5, 1.0, 0.02)


## Rewarding chime for equipping cosmetics in Supply Depot
func play_ui_equip() -> void:
	play_stream(sfx_ui_equip if sfx_ui_equip != null else sfx_star3, 0.5)


## Modal slide-in whoosh
func play_modal_open() -> void:
	play_stream(sfx_modal_open if sfx_modal_open != null else sfx_click, -5.0)


## Modal dismiss pop
func play_modal_close() -> void:
	play_stream(sfx_modal_close if sfx_modal_close != null else sfx_click, -5.5)


## Hydraulic docking pad lock chime with dynamic ascending harmonic arpeggios
## (C4 -> E4 -> G4 -> C5 -> E5 -> G5) providing musical dopamine on successive crate dockings.
const DOCKING_CHORD_PITCHES: Array[float] = [1.00, 1.26, 1.50, 2.00, 2.52, 3.00]

func play_goal_lock(dock_index: int = 1, total_goals: int = 1) -> void:
	var idx: int = clampi(dock_index - 1, 0, DOCKING_CHORD_PITCHES.size() - 1)
	var pitch: float = DOCKING_CHORD_PITCHES[idx]
	var vol_boost: float = 1.5 if (dock_index >= total_goals and total_goals > 0) else 0.0
	play_stream(sfx_goal_lock, vol_boost, pitch, 0.01)


## Crate disengage / goal unlock sound when pulling crate off a goal
func play_goal_unlock(remaining_docks: int = 0) -> void:
	var idx: int = clampi(remaining_docks, 0, DOCKING_CHORD_PITCHES.size() - 1)
	var pitch: float = DOCKING_CHORD_PITCHES[idx] * 0.90
	play_stream(sfx_goal_unlock if sfx_goal_unlock != null else sfx_push, -1.5, pitch, 0.02)


## Progressive star award chime (1, 2, or 3)
func play_star(star_num: int = 1) -> void:
	match star_num:
		1: play_stream(sfx_star1, 0.5, 1.0, 0.01)
		2: play_stream(sfx_star2, 1.0, 1.0, 0.01)
		3: play_stream(sfx_star3, 1.5, 1.0, 0.01)
		_: play_stream(sfx_star1, 0.5)


## Solver hint sparkle sound
func play_hint() -> void:
	play_stream(sfx_hint, -2.0)


## Deadlock warning buzzer
func play_deadlock() -> void:
	play_stream(sfx_deadlock, -1.0)


# ==============================================================================
# Procedural Retro Audio Synthesis (Warm, High-Fidelity Waveforms)
# ==============================================================================

func _generate_all_sfx() -> void:
	sfx_move = _synth_move(false)
	sfx_move_alt = _synth_move(true)
	sfx_push = _synth_push(0)
	sfx_push_cold = _synth_push(1)
	sfx_push_cyber = _synth_push(2)
	sfx_bump = _synth_bump()
	sfx_undo = _synth_undo()
	sfx_win = _synth_win()
	sfx_restart = _synth_restart()
	sfx_click = _synth_click()
	sfx_ui_click = _synth_ui_click()
	sfx_ui_back = _synth_ui_back()
	sfx_ui_equip = _synth_ui_equip()
	sfx_modal_open = _synth_modal_open()
	sfx_modal_close = _synth_modal_close()
	sfx_goal_lock = _synth_goal_lock()
	sfx_goal_unlock = _synth_goal_unlock()
	sfx_star1 = _synth_star_chime(587.33, 1)
	sfx_star2 = _synth_star_chime(739.99, 2)
	sfx_star3 = _synth_star_chime(880.00, 3)
	sfx_hint = _synth_hint()
	sfx_deadlock = _synth_deadlock()


func _create_wav(data_bytes: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data_bytes
	return wav


## Generates a warm, organic warehouse footstep on concrete (32ms, left/right foot alternating timbre)
func _synth_move(alt: bool = false) -> AudioStreamWAV:
	var duration: float = 0.032
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var freq_start: float = 158.0 if alt else 142.0
	var freq_end: float = 100.0 if alt else 90.0
	var phase: float = 0.0
	var seed_val: int = 42 if alt else 17

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += (freq * TAU) / float(MIX_RATE)

		# Soft, warm fundamental plus gentle 2nd harmonic (eliminates buzzing square edge)
		var s1: float = sin(phase)
		var s2: float = sin(phase * 2.0) * 0.22
		var body: float = s1 + s2

		# Subtle rubber-sole friction micro-tap on polished concrete (first 12ms)
		var tap: float = 0.0
		if t_sec < 0.012:
			seed_val = int((seed_val * 1103515245 + 12345) & 0x7FFFFFFF)
			var noise: float = (float(seed_val & 0xFFFF) / 32768.0) - 1.0
			tap = noise * pow(1.0 - t_sec / 0.012, 2.0) * 0.28

		var att: float = minf(1.0, t_sec / 0.002)
		var env: float = att * exp(-t * 26.0)
		var sample_val: int = int(clampi(int((body * 0.72 + tap) * env * 14000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a tactile, punchy crate push sound (woody contact knock, smooth sliding friction, and solid grid settle)
func _synth_push(style: int = 0) -> AudioStreamWAV:
	match style:
		1:
			# === Chapter 2: Cold Storage (Cryo Metal Skid & Resonant Crystalline Latch) ===
			var duration: float = 0.108
			var total_samples: int = int(duration * MIX_RATE)
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(total_samples * 2)
			var p_tap: float = 0.0
			var p_skid: float = 0.0
			var p_ring: float = 0.0
			var lp_noise: float = 0.0
			var seed_val: int = 555

			for i in range(total_samples):
				var t: float = float(i) / float(total_samples)
				var t_sec: float = float(i) / float(MIX_RATE)

				# 1. Metallic Contact Tap (0 to 28ms)
				var tap: float = 0.0
				if t_sec < 0.028:
					var f_tap: float = 420.0 - (t_sec / 0.028) * 180.0
					p_tap += (f_tap * TAU) / float(MIX_RATE)
					tap = (sin(p_tap) + 0.35 * sin(p_tap * 2.1)) * exp(-t_sec * 110.0) * 0.70

				# 2. Smooth Icy Gliding Skid (10 to 80ms)
				var skid: float = 0.0
				if t_sec >= 0.010 and t_sec <= 0.080:
					var s_t: float = (t_sec - 0.010) / 0.070
					var s_env: float = sin(s_t * PI)
					seed_val = int((seed_val * 1103515245 + 12345) & 0x7FFFFFFF)
					var raw_noise: float = (float(seed_val & 0xFFFF) / 32768.0) - 1.0
					lp_noise += 0.20 * (raw_noise - lp_noise)

					p_skid += (310.0 * TAU) / float(MIX_RATE)
					p_ring += (880.0 * TAU) / float(MIX_RATE)
					var cryo_tone: float = sin(p_skid) * 0.45 + sin(p_ring) * 0.20
					skid = (cryo_tone + lp_noise * 0.50) * s_env * 0.65

				# 3. Chilled Metal Latch (70 to 108ms)
				var latch: float = 0.0
				if t_sec >= 0.070:
					var dt: float = t_sec - 0.070
					p_tap += (320.0 * TAU) / float(MIX_RATE)
					latch = sin(p_tap) * exp(-dt * 120.0) * 0.60

				var val: float = tap + skid + latch
				var sample_val: int = int(clampi(int(val * 23000.0), -32767, 32767))
				bytes.encode_s16(i * 2, sample_val)
			return _create_wav(bytes)

		2:
			# === Chapter 3: Cyber Depot (Pneumatic Solenoid Kick & Magnetic Servo Glide) ===
			var duration: float = 0.112
			var total_samples: int = int(duration * MIX_RATE)
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(total_samples * 2)
			var p_servo: float = 0.0
			var p_snap: float = 0.0
			var lp_noise: float = 0.0
			var seed_val: int = 777

			for i in range(total_samples):
				var t: float = float(i) / float(total_samples)
				var t_sec: float = float(i) / float(MIX_RATE)

				# 1. Solenoid Kick (0 to 30ms)
				var kick: float = 0.0
				if t_sec < 0.030:
					p_snap += (360.0 * TAU) / float(MIX_RATE)
					kick = (sin(p_snap) + 0.25 * sin(p_snap * 2.0)) * exp(-t_sec * 105.0) * 0.70

				# 2. Magnetic Servo Glide & Pneumatic Vent (10 to 82ms)
				var glide: float = 0.0
				if t_sec >= 0.010 and t_sec <= 0.082:
					var s_t: float = (t_sec - 0.010) / 0.072
					var s_env: float = sin(s_t * PI)
					var f_servo: float = 210.0 + sin(s_t * PI) * 70.0
					p_servo += (f_servo * TAU) / float(MIX_RATE)

					seed_val = int((seed_val * 1103515245 + 12345) & 0x7FFFFFFF)
					var raw_noise: float = (float(seed_val & 0xFFFF) / 32768.0) - 1.0
					lp_noise += 0.18 * (raw_noise - lp_noise)

					var servo_tone: float = (sin(p_servo) + 0.30 * sin(p_servo * 2.0)) * 0.50
					glide = (servo_tone + lp_noise * 0.45) * s_env * 0.65

				# 3. Electromagnetic Lock Snap (72 to 112ms)
				var em_lock: float = 0.0
				if t_sec >= 0.072:
					var dt: float = t_sec - 0.072
					p_snap += (290.0 * TAU) / float(MIX_RATE)
					em_lock = sin(p_snap) * exp(-dt * 115.0) * 0.60

				var val: float = kick + glide + em_lock
				var sample_val: int = int(clampi(int(val * 23000.0), -32767, 32767))
				bytes.encode_s16(i * 2, sample_val)
			return _create_wav(bytes)

		_:
			# === Chapter 1: Cargo Bay (Oak Crate on Concrete: Snappy Wood Knock, Filtered Friction, Solid Settle Tock) ===
			var duration: float = 0.108
			var total_samples: int = int(duration * MIX_RATE)
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(total_samples * 2)
			var p_knock: float = 0.0
			var p_slide: float = 0.0
			var p_settle: float = 0.0
			var lp_noise: float = 0.0
			var seed_val: int = 12345

			for i in range(total_samples):
				var t_sec: float = float(i) / float(MIX_RATE)

				# 1. Initial Woody Contact Knock (0 to 32ms) - Crisp impact transient
				var knock: float = 0.0
				if t_sec < 0.032:
					var k_env: float = exp(-t_sec * 105.0)
					var f_k: float = 340.0 - (t_sec / 0.032) * 180.0
					p_knock += (f_k * TAU) / float(MIX_RATE)
					knock = (sin(p_knock) + 0.35 * sin(p_knock * 2.1) + 0.15 * sin(p_knock * 3.0)) * k_env * 0.75

				# 2. Resonant Wood Slide Friction (10ms to 82ms) - Low-pass filtered wood scraping (no static hiss!)
				var slide: float = 0.0
				if t_sec >= 0.010 and t_sec <= 0.082:
					var s_t: float = (t_sec - 0.010) / 0.072
					var s_env: float = sin(s_t * PI)
					seed_val = int((seed_val * 1103515245 + 12345) & 0x7FFFFFFF)
					var raw_noise: float = (float(seed_val & 0xFFFF) / 32768.0) - 1.0
					# Low-pass filter noise at ~450 Hz to produce smooth physical sliding friction
					lp_noise += 0.15 * (raw_noise - lp_noise)

					var f_slide: float = 220.0 + sin(s_t * PI) * 45.0
					p_slide += (f_slide * TAU) / float(MIX_RATE)
					var wood_body: float = (sin(p_slide) + 0.30 * sin(p_slide * 1.8)) * 0.50
					slide = (wood_body + lp_noise * 0.55) * s_env * 0.70

				# 3. Solid Tile Settle 'Tock' (72ms to 108ms)
				var settle: float = 0.0
				if t_sec >= 0.072:
					var dt: float = t_sec - 0.072
					var st_env: float = exp(-dt * 125.0)
					var f_st: float = 260.0 - dt * 500.0
					p_settle += (f_st * TAU) / float(MIX_RATE)
					settle = (sin(p_settle) + 0.25 * sin(p_settle * 2.0)) * st_env * 0.65

				var val: float = knock + slide + settle
				var sample_val: int = int(clampi(int(val * 24000.0), -32767, 32767))
				bytes.encode_s16(i * 2, sample_val)
			return _create_wav(bytes)


## Generates a solid, muffled barrier thump for wall collisions / blocked moves (52ms)
func _synth_bump() -> AudioStreamWAV:
	var duration: float = 0.052
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 110.0 - t * 50.0
		phase += (f * TAU) / float(MIX_RATE)
		var s: float = sin(phase) + 0.25 * sin(phase * 2.0)
		var att: float = minf(1.0, t_sec / 0.0015)
		var env: float = att * exp(-t * 32.0)
		var sample_val: int = int(clampi(int(s * env * 23000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a pleasant rising tape-rewind sweep for move undo (75ms)
func _synth_undo() -> AudioStreamWAV:
	var duration: float = 0.075
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 190.0 + t * 290.0
		phase += (f * TAU) / float(MIX_RATE)
		var flutter: float = 1.0 + 0.12 * sin(TAU * 32.0 * t_sec)
		var s: float = (sin(phase) + 0.20 * sin(phase * 2.0)) * flutter
		var att: float = minf(1.0, t_sec / 0.004)
		var rel: float = minf(1.0, (duration - t_sec) / 0.015)
		var env: float = att * rel * (0.4 + 0.6 * sin(t * PI))
		var sample_val: int = int(clampi(int(s * env * 19000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a grand, warm acoustic celebration fanfare (0.70s, 5-note shimmering arpeggio + C4 pedal bass)
func _synth_win() -> AudioStreamWAV:
	var duration: float = 0.70
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	# 5-note radiant acoustic arpeggio (C5-E5-G5-B5-C6) with C4 pedal bass support
	var notes: Array[Dictionary] = [
		{"start": 0.00, "end": 0.15, "freq": 523.25, "gain": 0.55}, # C5
		{"start": 0.10, "end": 0.28, "freq": 659.25, "gain": 0.60}, # E5
		{"start": 0.21, "end": 0.42, "freq": 783.99, "gain": 0.65}, # G5
		{"start": 0.32, "end": 0.54, "freq": 987.77, "gain": 0.70}, # B5 (Major 7th shimmer)
		{"start": 0.42, "end": 0.70, "freq": 1046.50, "gain": 0.85}, # C6 (Resolving high bell)
		{"start": 0.20, "end": 0.70, "freq": 261.63, "gain": 0.40}, # C4 Bass foundation
	]

	for i in range(total_samples):
		var t: float = float(i) / float(MIX_RATE)
		var val: float = 0.0

		for n in notes:
			var start: float = n["start"]
			var end: float = n["end"]
			if t >= start and t < end:
				var dt: float = t - start
				var note_len: float = end - start
				var att: float = minf(1.0, dt / 0.006)
				var rel_t: float = dt / note_len
				var decay_exp: float = 1.5 if n["freq"] >= 1000.0 else 1.8
				var env: float = att * pow(maxf(0.0, 1.0 - rel_t), decay_exp)

				var p1: float = TAU * n["freq"] * dt
				var p2: float = TAU * (n["freq"] * 2.0) * dt
				var p3: float = TAU * (n["freq"] * 3.0) * dt
				var bell_wave: float = 0.72 * sin(p1) + 0.20 * sin(p2) + 0.08 * sin(p3)

				val += bell_wave * env * n["gain"]

		var sample_val: int = int(clampi(int(val * 22000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates an 85ms descending rewind whistle
func _synth_restart() -> AudioStreamWAV:
	var duration: float = 0.085
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var freq_start: float = 400.0
	var freq_end: float = 150.0
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += (freq * TAU) / float(MIX_RATE)

		var wave: float = sin(phase) + 0.15 * sin(phase * 2.0)
		var envelope: float = (1.0 - t)
		var sample_val: int = int(clampi(int(wave * envelope * 18000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates an 18ms soft mechanical switch click (no harsh square buzzing)
func _synth_click() -> AudioStreamWAV:
	var duration: float = 0.018
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 750.0 - t * 380.0
		phase += (f * TAU) / float(MIX_RATE)
		var s: float = sin(phase) + 0.20 * sin(phase * 2.0)
		var att: float = minf(1.0, t_sec / 0.001)
		var env: float = att * pow(1.0 - t, 2.2)
		var sample_val: int = int(clampi(int(s * env * 14000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 16ms high-clarity subtle UI navigation click
func _synth_ui_click() -> AudioStreamWAV:
	var duration: float = 0.016
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 900.0 - t * 450.0
		phase += (f * TAU) / float(MIX_RATE)
		var s: float = sin(phase)
		var att: float = minf(1.0, t_sec / 0.0008)
		var env: float = att * pow(1.0 - t, 2.5)
		var sample_val: int = int(clampi(int(s * env * 13000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 24ms soft descending cancel/back click
func _synth_ui_back() -> AudioStreamWAV:
	var duration: float = 0.024
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 520.0 - t * 240.0
		phase += (f * TAU) / float(MIX_RATE)
		var s: float = sin(phase)
		var att: float = minf(1.0, t_sec / 0.001)
		var env: float = att * pow(1.0 - t, 2.0)
		var sample_val: int = int(clampi(int(s * env * 14000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 140ms bright double-tap chime (E5 -> A5) for equipping cosmetics
func _synth_ui_equip() -> AudioStreamWAV:
	var duration: float = 0.140
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var p1: float = 0.0
	var p2: float = 0.0

	for i in range(total_samples):
		var t_sec: float = float(i) / float(MIX_RATE)
		var val: float = 0.0

		# Note 1: E5 (659Hz, 0-60ms)
		if t_sec < 0.065:
			var dt: float = t_sec
			p1 += (659.25 * TAU) / float(MIX_RATE)
			var env1: float = minf(1.0, dt / 0.003) * pow(maxf(0.0, 1.0 - dt / 0.065), 1.8)
			val += sin(p1) * env1 * 0.55

		# Note 2: A5 (880Hz, 45-140ms)
		if t_sec >= 0.045:
			var dt: float = t_sec - 0.045
			p2 += (880.00 * TAU) / float(MIX_RATE)
			var env2: float = minf(1.0, dt / 0.003) * pow(maxf(0.0, 1.0 - dt / 0.095), 1.6)
			val += (sin(p2) + 0.25 * sin(p2 * 2.0)) * env2 * 0.65

		var sample_val: int = int(clampi(int(val * 18000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 55ms gentle rising pop for modal entry
func _synth_modal_open() -> AudioStreamWAV:
	var duration: float = 0.055
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 280.0 + t * 280.0
		phase += (f * TAU) / float(MIX_RATE)
		var s: float = sin(phase)
		var att: float = minf(1.0, t_sec / 0.003)
		var env: float = att * pow(1.0 - t, 1.6)
		var sample_val: int = int(clampi(int(s * env * 15000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 45ms soft falling pop for modal dismissal
func _synth_modal_close() -> AudioStreamWAV:
	var duration: float = 0.045
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 480.0 - t * 260.0
		phase += (f * TAU) / float(MIX_RATE)
		var s: float = sin(phase)
		var att: float = minf(1.0, t_sec / 0.002)
		var env: float = att * pow(1.0 - t, 1.8)
		var sample_val: int = int(clampi(int(s * env * 14000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a punchy hydraulic goal lock sound (pneumatic hiss + mechanical clamp + ascending chime, 260ms)
func _synth_goal_lock() -> AudioStreamWAV:
	var duration: float = 0.26
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var phase1: float = 0.0
	var phase2: float = 0.0
	var phase_sub: float = 0.0
	var noise_seed: int = 1337

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)

		# 1. Pneumatic Air Release (Noise burst, 0 - 65ms)
		var air: float = 0.0
		if t_sec < 0.065:
			noise_seed = int((noise_seed * 1103515245 + 12345) & 0x7FFFFFFF)
			var noise: float = (float(noise_seed & 0xFFFF) / 32768.0) - 1.0
			var air_env: float = pow(1.0 - t_sec / 0.065, 1.5)
			air = noise * air_env * 0.35

		# 2. Mechanical Clamp Thud (Sub click, 0 - 50ms)
		var thud: float = 0.0
		if t_sec < 0.050:
			var sub_freq: float = 150.0 - (t_sec / 0.050) * 85.0
			phase_sub += (sub_freq * TAU) / float(MIX_RATE)
			var thud_env: float = pow(1.0 - t_sec / 0.050, 2.0)
			thud = sin(phase_sub) * thud_env * 0.45

		# 3. 4-Tone Ascending Golden Lock Chime (C5 -> E5 -> G5 -> C6)
		var chime_freq: float = 523.25
		if t_sec >= 0.18:
			chime_freq = 1046.50
		elif t_sec >= 0.12:
			chime_freq = 783.99
		elif t_sec >= 0.06:
			chime_freq = 659.25

		phase1 += (chime_freq * TAU) / float(MIX_RATE)
		phase2 += (chime_freq * 2.0 * TAU) / float(MIX_RATE)

		var chime_wave: float = sin(phase1) * 0.70 + sin(phase2) * 0.30
		var chime_env: float = pow(1.0 - t, 1.6)
		var chime: float = chime_wave * chime_env * 0.65

		var final_wave: float = air + thud + chime
		var sample_val: int = int(clampi(int(final_wave * 23000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 150ms crate disengage / goal unlock sound (descending minor chord release)
func _synth_goal_unlock() -> AudioStreamWAV:
	var duration: float = 0.150
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase1: float = 0.0
	var phase2: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var t_sec: float = float(i) / float(MIX_RATE)
		var f: float = 783.99 if t_sec < 0.045 else (622.25 if t_sec < 0.095 else 523.25)
		phase1 += (f * TAU) / float(MIX_RATE)
		phase2 += (f * 2.0 * TAU) / float(MIX_RATE)
		var tone: float = sin(phase1) * 0.70 + sin(phase2) * 0.20
		var att: float = minf(1.0, fmod(t_sec, 0.045) / 0.003)
		var env: float = att * pow(1.0 - t, 1.8)
		var sample_val: int = int(clampi(int(tone * env * 17000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates an arcade star award chime (1, 2, or 3) with progressive harmonic brilliance
func _synth_star_chime(pitch_hz: float, star_num: int = 1) -> AudioStreamWAV:
	var duration: float = 0.26 if star_num == 3 else (0.21 if star_num == 2 else 0.18)
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var phase1: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var f1: float = pitch_hz
		var f2: float = pitch_hz * 1.5 if star_num >= 2 else pitch_hz * 2.0
		var f3: float = pitch_hz * 2.0 if star_num == 3 else pitch_hz * 3.0

		phase1 += (f1 * TAU) / float(MIX_RATE)
		phase2 += (f2 * TAU) / float(MIX_RATE)
		phase3 += (f3 * TAU) / float(MIX_RATE)

		var wave: float = sin(phase1) * 0.60 + sin(phase2) * 0.25 + sin(phase3) * 0.15
		var env: float = pow(1.0 - t, 2.0)
		var sample_val: int = int(clampi(int(wave * env * 24000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a pleasant two-tone sparkle chime for hint guidance
func _synth_hint() -> AudioStreamWAV:
	var duration: float = 0.22
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var freq: float = 659.25 if t < 0.35 else 987.77
		phase += (freq * TAU) / float(MIX_RATE)
		var s: float = sin(phase)
		var tri: float = 2.0 * absf(2.0 * (fposmod(phase / TAU, 1.0) - 0.5)) - 1.0
		var wave: float = 0.7 * s + 0.3 * tri
		var env: float = (1.0 - t) * (1.0 - t * 0.5)
		var sample_val: int = int(clampi(int(wave * env * 14000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a low warning buzzer for deadlock detection
func _synth_deadlock() -> AudioStreamWAV:
	var duration: float = 0.18
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var freq: float = lerpf(140.0, 95.0, t)
		phase += (freq * TAU) / float(MIX_RATE)
		var wave: float = 1.0 if sin(phase) > 0.2 else -1.0
		var env: float = 1.0 - t
		var sample_val: int = int(clampi(int(wave * env * 11000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)

