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
var sfx_push: AudioStreamWAV
var sfx_win: AudioStreamWAV
var sfx_restart: AudioStreamWAV
var sfx_click: AudioStreamWAV
var sfx_goal_lock: AudioStreamWAV
var sfx_star1: AudioStreamWAV
var sfx_star2: AudioStreamWAV
var sfx_star3: AudioStreamWAV
var sfx_hint: AudioStreamWAV
var sfx_deadlock: AudioStreamWAV

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


func play_stream(stream: AudioStreamWAV, volume_db: float = 0.0) -> void:
	if not is_inside_tree() or not is_sound_enabled() or stream == null:
		return

	var sfx_vol_db: float = get_sfx_volume_db()
	if sfx_vol_db <= -75.0:
		return # Muted
	var final_db: float = volume_db + sfx_vol_db

	# Find an available player or steal the one playing longest
	for p in _players:
		if p.is_inside_tree() and not p.playing:
			p.stream = stream
			p.volume_db = final_db
			p.play()
			return

	# Fallback: reuse first player if in tree
	if not _players.is_empty() and _players[0].is_inside_tree():
		var fallback_player: AudioStreamPlayer = _players[0]
		fallback_player.stream = stream
		fallback_player.volume_db = final_db
		fallback_player.play()


## Player movement step sound
func play_move() -> void:
	play_stream(sfx_move, -6.0)


## Crate pushed sound
func play_push() -> void:
	play_stream(sfx_push, -1.0)


## Level won fanfare
func play_win() -> void:
	duck_music(-8.0, 0.15)
	play_stream(sfx_win, 0.0)
	var tw: Tween = create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func(): unduck_music(0.40))


## Level restart sound
func play_restart() -> void:
	play_stream(sfx_restart, -3.0)


## UI button click sound
func play_click() -> void:
	play_stream(sfx_click, -4.0)


## Goal pad lock chime
func play_goal_lock() -> void:
	play_stream(sfx_goal_lock, -1.0)


## Star awarded chime (1, 2, or 3)
func play_star(star_num: int = 1) -> void:
	match star_num:
		1: play_stream(sfx_star1, 0.0)
		2: play_stream(sfx_star2, 0.5)
		3: play_stream(sfx_star3, 1.0)
		_: play_stream(sfx_star1, 0.0)


## Solver hint sparkle sound
func play_hint() -> void:
	play_stream(sfx_hint, -2.0)


## Deadlock warning buzzer
func play_deadlock() -> void:
	play_stream(sfx_deadlock, -1.0)


# ==============================================================================
# Procedural Retro 8-Bit Audio Synthesis
# ==============================================================================

func _generate_all_sfx() -> void:
	sfx_move = _synth_move()
	sfx_push = _synth_push()
	sfx_win = _synth_win()
	sfx_restart = _synth_restart()
	sfx_click = _synth_click()
	sfx_goal_lock = _synth_goal_lock()
	sfx_star1 = _synth_star_chime(587.33, false)
	sfx_star2 = _synth_star_chime(739.99, false)
	sfx_star3 = _synth_star_chime(880.00, true)
	sfx_hint = _synth_hint()
	sfx_deadlock = _synth_deadlock()


func _create_wav(data_bytes: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data_bytes
	return wav


## Generates a short 35ms retro step blip
func _synth_move() -> AudioStreamWAV:
	var duration: float = 0.035
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var freq_start: float = 160.0
	var freq_end: float = 90.0
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += (freq * TAU) / float(MIX_RATE)

		# Soft square wave
		var wave: float = 1.0 if sin(phase) > 0.0 else -1.0
		# Decay envelope
		var envelope: float = (1.0 - t) * (1.0 - t)
		var sample_val: int = int(clampi(int(wave * envelope * 12000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 90ms punchy crate push thud
func _synth_push() -> AudioStreamWAV:
	var duration: float = 0.09
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var freq_start: float = 120.0
	var freq_end: float = 55.0
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += (freq * TAU) / float(MIX_RATE)

		# Combined square and triangle for a heavy crate impact
		var sq: float = 1.0 if sin(phase) > 0.0 else -1.0
		var tri: float = 2.0 * abs(fmod(phase / PI, 2.0) - 1.0) - 1.0
		var wave: float = 0.7 * sq + 0.3 * tri

		# Punchy attack and decay envelope
		var envelope: float = (1.0 - t)
		var sample_val: int = int(clampi(int(wave * envelope * 24000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a sweet, warm 0.52s marimba/bell victory chime
## Features an ascending 4-note acoustic arpeggio (C5-E5-G5-C6) with pure harmonic resonance
func _synth_win() -> AudioStreamWAV:
	var duration: float = 0.52
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	# 4-note cheerful acoustic chime/marimba arpeggio:
	# C5 (523Hz), E5 (659Hz), G5 (784Hz), C6 (1046Hz, warm bell ring)
	var notes: Array[Dictionary] = [
		{"start": 0.00, "end": 0.13, "freq": 523.25, "gain": 0.65}, # C5
		{"start": 0.10, "end": 0.24, "freq": 659.25, "gain": 0.70}, # E5
		{"start": 0.21, "end": 0.36, "freq": 783.99, "gain": 0.75}, # G5
		{"start": 0.32, "end": 0.52, "freq": 1046.50, "gain": 0.85}, # C6 (resolving bell ring)
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
				# Soft 5ms attack eliminates digital clicks/pops
				var att: float = minf(1.0, dt / 0.005)
				var rel_t: float = dt / note_len
				var decay_exp: float = 1.6 if n["freq"] >= 1000.0 else 2.0
				var env: float = att * pow(maxf(0.0, 1.0 - rel_t), decay_exp)

				# Warm acoustic bell / marimba timbre:
				# Pure sine fundamental + gentle octave harmonic + subtle presence overtone
				var p1: float = TAU * n["freq"] * dt
				var p2: float = TAU * (n["freq"] * 2.0) * dt
				var p3: float = TAU * (n["freq"] * 3.0) * dt
				var bell_wave: float = 0.72 * sin(p1) + 0.22 * sin(p2) + 0.06 * sin(p3)

				val += bell_wave * env * n["gain"]

		var sample_val: int = int(clampi(int(val * 24000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates an 80ms descending restart whistle
func _synth_restart() -> AudioStreamWAV:
	var duration: float = 0.08
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var freq_start: float = 380.0
	var freq_end: float = 160.0
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += (freq * TAU) / float(MIX_RATE)

		var wave: float = sin(phase)
		var envelope: float = (1.0 - t)
		var sample_val: int = int(clampi(int(wave * envelope * 18000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a 20ms UI click blip
func _synth_click() -> AudioStreamWAV:
	var duration: float = 0.02
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var freq: float = 780.0
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		phase += (freq * TAU) / float(MIX_RATE)
		var wave: float = 1.0 if sin(phase) > 0.0 else -1.0
		var envelope: float = (1.0 - t) * (1.0 - t)
		var sample_val: int = int(clampi(int(wave * envelope * 14000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates a punchy hydraulic goal lock sound (pneumatic hiss + mechanical clamp + ascending chime, 240ms)
func _synth_goal_lock() -> AudioStreamWAV:
	var duration: float = 0.24
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

		# 3. 3-Tone Ascending Golden Lock Chime (C5 -> E5 -> G5)
		var chime_freq: float = 523.25
		if t_sec >= 0.14:
			chime_freq = 783.99
		elif t_sec >= 0.07:
			chime_freq = 659.25

		phase1 += (chime_freq * TAU) / float(MIX_RATE)
		phase2 += (chime_freq * 2.0 * TAU) / float(MIX_RATE)

		var chime_wave: float = sin(phase1) * 0.70 + sin(phase2) * 0.30
		var chime_env: float = pow(1.0 - t, 1.6)
		var chime: float = chime_wave * chime_env * 0.65

		var final_wave: float = air + thud + chime
		var sample_val: int = int(clampi(int(final_wave * 24000.0), -32767, 32767))
		bytes.encode_s16(i * 2, sample_val)

	return _create_wav(bytes)


## Generates an arcade star award chime (180ms bell with harmonic shimmer)
func _synth_star_chime(pitch_hz: float, is_major_chord: bool) -> AudioStreamWAV:
	var duration: float = 0.22 if is_major_chord else 0.16
	var total_samples: int = int(duration * MIX_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var phase1: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(total_samples)
		var f1: float = pitch_hz
		var f2: float = pitch_hz * 1.5 if is_major_chord else pitch_hz * 2.0
		var f3: float = pitch_hz * 2.0 if is_major_chord else pitch_hz * 3.0

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

