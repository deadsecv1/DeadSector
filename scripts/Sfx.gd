extends Node

# Global sound-effect player. Autoloaded as "Sfx". All clips are synthesized
# once at startup (no external audio files) and played from a small pool of
# AudioStreamPlayers so multiple sounds can overlap without cutting off.

const SAMPLE_RATE := 44100

# Gunshot and reload are now real recorded audio (Snake's Authentic Gun
# Sounds pack) instead of synthesized - everything else here is still
# generated procedurally.
const REAL_GUNSHOT := preload("res://assets/audio/sfx/gunshot.wav")
const REAL_RELOAD := preload("res://assets/audio/sfx/reload.wav")

var _gunshot: AudioStreamWAV
var _footstep: AudioStreamWAV
var _door: AudioStreamWAV
var _bush: AudioStreamWAV
var _heal: AudioStreamWAV
var _explosion: AudioStreamWAV
var _reload: AudioStreamWAV
var _alarm: AudioStreamWAV
var _soul_hover: AudioStreamWAV
var _pet_hover: AudioStreamWAV
var _nightvision_toggle: AudioStreamWAV
var _coin_hover: AudioStreamWAV
var _search: AudioStreamWAV
var _blood_hover: AudioStreamWAV
var _crate_open: AudioStreamWAV
var _loot_pickup: AudioStreamWAV
var _engram_decipher: AudioStreamWAV
var _chest_open: AudioStreamWAV
var _reveal: AudioStreamWAV
var _jump: AudioStreamWAV
var _land: AudioStreamWAV
var _sword_swing: AudioStreamWAV
var _energy_shot: AudioStreamWAV
var _item_hover: AudioStreamWAV
var _menu_confirm: AudioStreamWAV
var _letter_land: AudioStreamWAV
var _impact_thud: AudioStreamWAV
var _crystal_chime: AudioStreamWAV
var _soft_whoosh: AudioStreamWAV
var _ranked_hover: AudioStreamWAV
var _eerie_hover: AudioStreamWAV
var _signal_beam: AudioStreamWAV
var _arena_hover: AudioStreamWAV

var _pool: Array = []
const POOL_SIZE := 10

func _ready() -> void:
	_gunshot = REAL_GUNSHOT
	_footstep = _make_footstep()
	_door = _make_door()
	_bush = _make_bush()
	_heal = _make_heal()
	_explosion = _make_explosion()
	_reload = REAL_RELOAD
	_alarm = _make_alarm()
	_soul_hover = _make_soul_hover()
	_pet_hover = _make_pet_hover()
	_nightvision_toggle = _make_nightvision_toggle()
	_coin_hover = _make_coin_hover()
	_search = _make_search()
	_blood_hover = _make_blood_hover()
	_crate_open = _make_crate_open()
	_loot_pickup = _make_loot_pickup()
	_engram_decipher = _make_engram_decipher()
	_chest_open = _make_chest_open()
	_reveal = _make_reveal()
	_jump = _make_jump()
	_land = _make_land()
	_sword_swing = _make_sword_swing()
	_energy_shot = _make_energy_shot()
	_item_hover = _make_item_hover()
	_menu_confirm = _make_menu_confirm()
	_letter_land = _make_letter_land()
	_impact_thud = _make_impact_thud()
	_crystal_chime = _make_crystal_chime()
	_soft_whoosh = _make_soft_whoosh()
	_ranked_hover = _make_ranked_hover()
	_eerie_hover = _make_eerie_hover()
	_signal_beam = _make_signal_beam()
	_arena_hover = _make_arena_hover()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_wire_global_click_sfx()

# Every Button (or other BaseButton - CheckBox, OptionButton, etc.) in
# the game plays this same click the instant it's pressed, with no
# individual script needing to wire it up by hand - connects to every
# BaseButton as it's added to the tree, present or future. This is an
# autoload, so it's already ready before the very first scene's nodes
# exist, meaning nothing gets missed.
func _wire_global_click_sfx() -> void:
	get_tree().node_added.connect(_on_node_added_for_click_sfx)

func _on_node_added_for_click_sfx(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play_menu_confirm)

func _get_free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]

func play_gunshot() -> void:
	var p := _get_free_player()
	p.stream = _gunshot
	p.volume_db = -6.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func play_footstep() -> void:
	var p := _get_free_player()
	p.stream = _footstep
	p.volume_db = -26.0
	p.pitch_scale = randf_range(0.88, 1.12)
	p.play()

func play_door() -> void:
	var p := _get_free_player()
	p.stream = _door
	p.volume_db = -7.0
	p.play()

func play_bush() -> void:
	var p := _get_free_player()
	p.stream = _bush
	p.volume_db = -9.0
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()

func play_heal() -> void:
	var p := _get_free_player()
	p.stream = _heal
	p.volume_db = -8.0
	p.play()

func play_explosion() -> void:
	var p := _get_free_player()
	p.stream = _explosion
	p.volume_db = -6.0
	p.play()

func play_reload() -> void:
	var p := _get_free_player()
	p.stream = _reload
	p.volume_db = -6.0
	p.play()

func play_alarm() -> void:
	var p := _get_free_player()
	p.stream = _alarm
	p.volume_db = -22.0
	p.play()

func play_soul_hover() -> void:
	var p := _get_free_player()
	p.stream = _soul_hover
	p.volume_db = -6.0
	p.play()

func play_pet_hover() -> void:
	var p := _get_free_player()
	p.stream = _pet_hover
	p.volume_db = -12.0
	p.play()

func play_nightvision_toggle() -> void:
	var p := _get_free_player()
	p.stream = _nightvision_toggle
	p.volume_db = -4.0
	p.play()

func play_coin_hover() -> void:
	var p := _get_free_player()
	p.stream = _coin_hover
	p.volume_db = -19.0
	p.play()

func play_item_hover() -> void:
	# Fires on essentially every mouse-over in a dense inventory grid,
	# so this needs to disappear into the background rather than be
	# noticed - quieter than any other hover sound in the game, and a
	# tiny random pitch wobble so twenty of them in a row scanning down
	# a full Stash don't sound like a stuck loop.
	var p := _get_free_player()
	p.stream = _item_hover
	p.volume_db = -26.0
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()

# Plays whenever the player confirms/advances - Play on the Main Menu,
# skipping a cutscene or splash screen, or navigating between menus.
# Called from Transition.gd itself rather than each individual button,
# so it's naturally guarded by that same _is_transitioning lock - spam-
# clicking Play or mashing the skip key can't ever trigger it twice for
# the same transition.
func play_menu_confirm() -> void:
	var p := _get_free_player()
	p.stream = _menu_confirm
	p.volume_db = -15.0
	p.play()

# A tiny, soft tick - used once per letter as it lands during a splash
# screen's letter-drop animation (see ClarityPartnerSplash.gd). Several
# of these can land within the same second as different letters settle
# at their own staggered pace, so it's deliberately quiet and short -
# a whisper of a sound, not a typewriter clack.
func play_letter_land() -> void:
	var p := _get_free_player()
	p.stream = _letter_land
	p.volume_db = -26.0
	p.pitch_scale = randf_range(0.9, 1.15)
	p.play()

# A soft, muffled thump - used for the Steelcrest partner splash's
# "slam" impact beat. Quiet enough to read as a felt thud, not a bang.
func play_impact_thud() -> void:
	var p := _get_free_player()
	p.stream = _impact_thud
	p.volume_db = -14.0
	p.play()

# Same thud, much quieter - the Lil Dirty cursor cameo "hitting the wall".
func play_lildirty_ouch() -> void:
	var p := _get_free_player()
	p.stream = _impact_thud
	p.volume_db = -24.0
	p.pitch_scale = randf_range(1.3, 1.6)
	p.play()

# A quiet glassy chime - used for the Sapphire Signal Studio crystal's
# shatter moment.
func play_crystal_chime() -> void:
	var p := _get_free_player()
	p.stream = _crystal_chime
	p.volume_db = -16.0
	p.play()

# A rising radio/radar-style sweep with a fainter echoed repeat and a
# ringing tail - used once the Sapphire Signal Studio crystal's shell
# has fully fallen away and the bare signal light stands exposed, like
# the signal is actually reaching out.
func play_signal_beam() -> void:
	var p := _get_free_player()
	p.stream = _signal_beam
	p.volume_db = -15.0
	p.play()

# A very soft rising whoosh - used as a gentle "arrival" cue on the
# plainer text-only splash screens (Engine credit, Legal) as their
# content fades in, so the whole boot sequence isn't silent underneath
# the music.
func play_soft_whoosh() -> void:
	var p := _get_free_player()
	p.stream = _soft_whoosh
	p.volume_db = -20.0
	p.play()

# A quiet electronic "readying" blip - the Ranked button's hover sound.
# Distinct from the plain menu-button hover (this is the door into PvP,
# it should feel a little charged) but quiet, not the aggressive sword-
# swing sting it used to be.
func play_ranked_hover() -> void:
	var p := _get_free_player()
	p.stream = _ranked_hover
	p.volume_db = -19.0
	p.play()

# A low, dissonant, faintly unsettling tone - the Alpha Rewards button's
# hover sound. Quiet, but meant to read as a little eerie rather than
# the bright coin-chime it used to be.
func play_eerie_hover() -> void:
	var p := _get_free_player()
	p.stream = _eerie_hover
	p.volume_db = -21.0
	p.play()

# A soft two-tone "ready bell" - the Arena button's own hover cue,
# distinct from Ranked's single rising blip: a quick low-high ping
# pair, like a tournament bell tapped once, quietly.
func play_arena_hover() -> void:
	var p := _get_free_player()
	p.stream = _arena_hover
	p.volume_db = -20.0
	p.play()

func play_search() -> void:
	var p := _get_free_player()
	p.stream = _search
	p.volume_db = -27.0
	p.play()

func play_crate_open() -> void:
	var p := _get_free_player()
	p.stream = _crate_open
	p.volume_db = -6.0
	p.play()

func play_loot_pickup() -> void:
	var p := _get_free_player()
	p.stream = _loot_pickup
	p.volume_db = -8.0
	p.pitch_scale = randf_range(0.95, 1.08)
	p.play()

func play_engram_decipher() -> void:
	var p := _get_free_player()
	p.stream = _engram_decipher
	p.volume_db = -8.0
	p.play()

func play_chest_open() -> void:
	var p := _get_free_player()
	p.stream = _chest_open
	p.volume_db = -8.0
	p.play()

func play_reveal() -> void:
	var p := _get_free_player()
	p.stream = _reveal
	p.volume_db = -11.0
	p.play()

func play_blood_hover() -> void:
	var p := _get_free_player()
	p.stream = _blood_hover
	p.volume_db = -8.0
	p.play()

func play_jump() -> void:
	var p := _get_free_player()
	p.stream = _jump
	p.volume_db = -12.0
	p.pitch_scale = randf_range(0.96, 1.06)
	p.play()

func play_land() -> void:
	var p := _get_free_player()
	p.stream = _land
	p.volume_db = -10.0
	p.pitch_scale = randf_range(0.92, 1.05)
	p.play()

func play_sword_swing() -> void:
	var p := _get_free_player()
	p.stream = _sword_swing
	p.volume_db = -9.0
	p.pitch_scale = randf_range(0.95, 1.1)
	p.play()

func play_energy_shot() -> void:
	var p := _get_free_player()
	p.stream = _energy_shot
	p.volume_db = -8.0
	p.pitch_scale = randf_range(0.97, 1.05)
	p.play()

func _to_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _make_gunshot() -> AudioStreamWAV:
	var dur := 0.15
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 28.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var thump := sin(TAU * 90.0 * t) * exp(-t * 18.0)
		var s: float = (noise * 0.6 + thump * 0.7) * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_footstep() -> AudioStreamWAV:
	var dur := 0.06
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 60.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var thump := sin(TAU * 95.0 * t)
		var s: float = (noise * 0.15 + thump * 0.4) * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_door() -> AudioStreamWAV:
	var dur := 0.35
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 6.0) * (1.0 - exp(-t * 60.0))
		var creak := sin(TAU * (180.0 - t * 90.0) * t)
		var noise := rng.randf_range(-1.0, 1.0) * 0.15
		var s: float = (creak * 0.5 + noise) * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_bush() -> AudioStreamWAV:
	var dur := 0.25
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var filt := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = sin(PI * t / dur)
		var noise := rng.randf_range(-1.0, 1.0)
		filt += (noise - filt) * 0.3
		var s: float = filt * env * 0.6
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_heal() -> AudioStreamWAV:
	# A soft two-note upward chime.
	var dur := 0.3
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 7.0)
		var freq: float = 660.0 if t < 0.13 else 880.0
		var tone := sin(TAU * freq * t)
		var s: float = tone * env * 0.5
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_explosion() -> AudioStreamWAV:
	var dur := 0.55
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 5.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var thump := sin(TAU * 55.0 * t) * exp(-t * 9.0)
		var s: float = (noise * 0.7 + thump * 0.8) * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_reload() -> AudioStreamWAV:
	# Two short mechanical clacks (mag out, mag in) with a bit of noise.
	var dur := 0.28
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var click_times := [0.02, 0.16]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		for ct in click_times:
			var dt: float = t - ct
			if dt >= 0.0 and dt < 0.03:
				var env: float = exp(-dt * 140.0)
				s += (rng.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 260.0 * dt) * 0.5) * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_alarm() -> AudioStreamWAV:
	# A real car-alarm style "whoop-whoop" - rapid rising pitch sweeps
	# using a square wave for a harsher, more electronic buzzer tone,
	# instead of a flat alternating sine beep.
	var dur := 1.0
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var sweep_phase: float = fmod(t * 5.0, 1.0)
		var freq: float = lerp(550.0, 1900.0, sweep_phase * sweep_phase)
		var raw := sin(TAU * freq * t)
		var square: float = 1.0 if raw >= 0.0 else -1.0
		var env: float = 0.28
		var s: float = square * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_soul_hover() -> AudioStreamWAV:
	# An ethereal, breathy whisper - a low sine with slow vibrato, layered
	# with soft filtered noise, fading in and out like wind or a distant
	# ghost moan. No harsh edges, everything soft and airy.
	var dur := 0.9
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var noise_lp := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var frac: float = t / dur
		var envelope: float = sin(PI * frac)
		var vibrato: float = sin(TAU * 5.0 * t) * 12.0
		var base_freq: float = 340.0 + vibrato
		var tone := sin(TAU * base_freq * t) * 0.5 + sin(TAU * base_freq * 1.5 * t) * 0.2
		var raw_noise := randf_range(-1.0, 1.0)
		noise_lp = lerp(noise_lp, raw_noise, 0.06)
		var s: float = (tone * 0.55 + noise_lp * 0.5) * envelope * 0.3
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_nightvision_toggle() -> AudioStreamWAV:
	# A short electronic double-click, like a device powering on/off -
	# a sharp tick, a beat of silence, then a softer confirm tick.
	var dur := 0.22
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		if t < 0.03:
			s = sin(TAU * 2200.0 * t) * exp(-t * 90.0) * 0.5
		elif t > 0.1 and t < 0.15:
			var t2: float = t - 0.1
			s = sin(TAU * 1500.0 * t2) * exp(-t2 * 70.0) * 0.35
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_pet_hover() -> AudioStreamWAV:
	# A short, sharp double "yip" - a quick broadband noise burst with a
	# falling pitch, twice in a row. Reads unmistakably as a small
	# creature/animal sound, unlike the muddier low growl from before.
	var dur := 0.4
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var yip_starts := [0.0, 0.16]
	var noise_lp := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		for start in yip_starts:
			var local_t: float = t - start
			if local_t >= 0.0 and local_t < 0.13:
				var frac: float = local_t / 0.13
				var pitch: float = lerp(1400.0, 650.0, frac)
				var env: float = exp(-local_t * 14.0)
				var raw_noise := randf_range(-1.0, 1.0)
				noise_lp = lerp(noise_lp, raw_noise, 0.5)
				var tone: float = sin(TAU * pitch * local_t)
				s += (tone * 0.65 + noise_lp * 0.35) * env * 0.55
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_coin_hover() -> AudioStreamWAV:
	# A bright metallic chime - three quick ascending "tink" bursts, like
	# coins clinking together.
	var dur := 0.4
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var pitches := [1300.0, 1700.0, 2200.0]
	var starts := [0.0, 0.08, 0.16]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		for k in range(pitches.size()):
			var local_t: float = t - starts[k]
			if local_t >= 0.0 and local_t < 0.16:
				var decay: float = exp(-local_t * 22.0)
				s += sin(TAU * pitches[k] * local_t) * decay * 0.35
				s += sin(TAU * pitches[k] * 2.01 * local_t) * decay * 0.12
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_item_hover() -> AudioStreamWAV:
	# A single soft, rounded tick - one short sine burst with a fast
	# decay and no harsh attack, meant to be felt more than heard. Deliberately
	# plainer than coin_hover/soul_hover/etc: those play occasionally,
	# this one plays constantly while browsing a full inventory grid.
	var dur := 0.05
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var attack: float = min(t / 0.004, 1.0)
		var decay: float = exp(-t * 70.0)
		var s: float = sin(TAU * 900.0 * t) * attack * decay * 0.5
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

# A clean, understated confirm click - the kind of subtle "blip" a
# well-produced menu plays when you hit Play or confirm a choice, not
# a loud arcade beep. A quick bright tone with a soft percussive edge
# for texture, gone in well under a tenth of a second.
func _make_menu_confirm() -> AudioStreamWAV:
	var dur := 0.12
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var decay: float = exp(-t * 34.0)
		var tone: float = sin(TAU * 1600.0 * t) * decay * 0.4
		tone += sin(TAU * 2400.0 * t) * decay * 0.15
		var click_decay: float = exp(-t * 140.0)
		var click: float = randf_range(-1.0, 1.0) * click_decay * 0.08
		var s: float = tone + click
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_letter_land() -> AudioStreamWAV:
	var dur := 0.05
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 95.0)
		var s: float = sin(TAU * 950.0 * t) * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_impact_thud() -> AudioStreamWAV:
	var dur := 0.3
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 14.0)
		var pitch_sweep: float = lerp(85.0, 45.0, clamp(t / 0.2, 0.0, 1.0))
		var s: float = sin(TAU * pitch_sweep * t) * env * 0.8
		var noise_env: float = exp(-t * 60.0)
		s += randf_range(-1.0, 1.0) * noise_env * 0.15
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_crystal_chime() -> AudioStreamWAV:
	var dur := 0.6
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var pitches := [1568.0, 1976.0, 2349.0]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		for p in pitches:
			s += sin(TAU * p * t) * exp(-t * 5.5) * 0.18
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

# A rising sweep (the signal launching outward) with a fainter delayed
# echo of the same sweep (like it's reaching further out and bouncing
# back) and a ringing tail underneath, instead of just another chime -
# meant to read as an actual transmission rather than a musical note.
func _make_signal_beam() -> AudioStreamWAV:
	var dur := 1.1
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var sweep_dur := 0.32
	var echo_delay := 0.16
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		if t < sweep_dur:
			var st: float = t / sweep_dur
			var freq: float = lerp(650.0, 2100.0, st * st)
			var env: float = sin(PI * st)
			s += sin(TAU * freq * t) * env * 0.5
			s += sin(TAU * freq * 1.5 * t) * env * 0.15
		var et := t - echo_delay
		if et >= 0.0 and et < sweep_dur:
			var est: float = et / sweep_dur
			var efreq: float = lerp(650.0, 2100.0, est * est)
			s += sin(TAU * efreq * et) * sin(PI * est) * 0.22
		if t >= sweep_dur:
			var tt := t - sweep_dur
			var tail_env: float = exp(-tt * 3.2)
			s += sin(TAU * 2100.0 * t) * tail_env * 0.22
			s += sin(TAU * 1400.0 * t) * tail_env * 0.12
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_soft_whoosh() -> AudioStreamWAV:
	var dur := 0.7
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = sin(PI * clamp(t / dur, 0.0, 1.0)) * 0.5
		var noise: float = randf_range(-1.0, 1.0)
		lp = lerp(lp, noise, 0.06)
		var s: float = lp * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_ranked_hover() -> AudioStreamWAV:
	var dur := 0.14
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 18.0)
		var pitch: float = lerp(500.0, 900.0, clamp(t / 0.1, 0.0, 1.0))
		var s: float = sin(TAU * pitch * t) * env * 0.5
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_arena_hover() -> AudioStreamWAV:
	# Two quick decaying pings, low then high - a tiny "bell" rather than
	# Ranked's rising sweep, so the two PvP entry points don't sound
	# like the same cue with the volume changed.
	var dur := 0.22
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env1: float = exp(-t * 22.0)
		var env2: float = exp(-max(t - 0.09, 0.0) * 22.0) if t >= 0.09 else 0.0
		var s: float = sin(TAU * 620.0 * t) * env1 * 0.35 + sin(TAU * 780.0 * t) * env2 * 0.3
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_eerie_hover() -> AudioStreamWAV:
	var dur := 0.5
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = sin(PI * clamp(t / dur, 0.0, 1.0))
		var base: float = sin(TAU * 130.0 * t)
		var detune: float = sin(TAU * 138.0 * t)
		var s: float = (base * 0.5 + detune * 0.4) * env * 0.5
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_search() -> AudioStreamWAV:
	# Someone rummaging through a bag - a handful of irregular, filtered
	# noise rustles rather than one continuous sound, so it reads as
	# hands digging around instead of static.
	var dur := 0.7
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rustle_starts := [0.0, 0.14, 0.24, 0.4, 0.52]
	var rustle_lens := [0.09, 0.06, 0.1, 0.07, 0.1]
	var lp := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var active: bool = false
		for k in range(rustle_starts.size()):
			if t >= rustle_starts[k] and t < rustle_starts[k] + rustle_lens[k]:
				active = true
				break
		var raw: float = randf_range(-1.0, 1.0) if active else 0.0
		lp = lerp(lp, raw, 0.35)
		var s: float = lp * 0.5
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_crate_open() -> AudioStreamWAV:
	# A dramatic reveal for gamble crates - a rising anticipation sweep
	# followed by a bright, bigger payoff chime than the regular coin
	# hover, so cracking a crate actually feels like an event.
	var dur := 0.75
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var pitches := [900.0, 1250.0, 1650.0, 2100.0]
	var starts := [0.32, 0.4, 0.48, 0.56]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		if t < 0.3:
			var sweep_freq: float = lerp(180.0, 640.0, t / 0.3)
			var sweep_env: float = (t / 0.3) * 0.4
			s += sin(TAU * sweep_freq * t) * sweep_env
		for k in range(pitches.size()):
			var local_t: float = t - starts[k]
			if local_t >= 0.0 and local_t < 0.22:
				var decay: float = exp(-local_t * 12.0)
				s += sin(TAU * pitches[k] * local_t) * decay * 0.32
				s += sin(TAU * pitches[k] * 1.5 * local_t) * decay * 0.1
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_loot_pickup() -> AudioStreamWAV:
	# A quick, satisfying "item get" pop for the Gauntlet's loot drops -
	# short and punchy so it doesn't get old picking up dozens of these
	# in a single run.
	var dur := 0.18
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 18.0)
		var freq: float = lerp(500.0, 1100.0, clamp(t / 0.08, 0.0, 1.0))
		var s: float = sin(TAU * freq * t) * env * 0.55
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_engram_decipher() -> AudioStreamWAV:
	# A mystical, shimmering resolve for Justin's engram deciphering -
	# two slightly detuned tones with a slow tremolo, settling into a
	# clean high ping as the engram "unlocks".
	var dur := 0.9
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 3.0) if t < 0.6 else exp(-(t - 0.6) * 9.0) * 0.5
		var tremolo: float = 0.6 + 0.4 * sin(TAU * 6.0 * t)
		var shimmer: float = sin(TAU * 420.0 * t) * 0.3 + sin(TAU * 424.0 * t) * 0.3
		var s: float = shimmer * env * tremolo
		if t > 0.55 and t < 0.9:
			var ping_t: float = t - 0.55
			s += sin(TAU * 1400.0 * ping_t) * exp(-ping_t * 8.0) * 0.4
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_chest_open() -> AudioStreamWAV:
	# A wooden creak followed by a metal latch click - reads distinctly
	# as "opening a container" rather than the generic rummage sound.
	var dur := 0.55
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		if t < 0.35:
			var creak_freq: float = lerp(90.0, 60.0, t / 0.35)
			var creak_env: float = 0.3 * (1.0 - t / 0.35)
			var raw: float = randf_range(-1.0, 1.0) * 0.4 + sin(TAU * creak_freq * t) * 0.3
			lp = lerp(lp, raw, 0.15)
			s = lp * creak_env
		elif t < 0.42:
			var click_t: float = t - 0.35
			s = sin(TAU * 2200.0 * click_t) * exp(-click_t * 60.0) * 0.5
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_reveal() -> AudioStreamWAV:
	# A bright, triumphant "here's your reward" fanfare - a fast
	# ascending arpeggio into a held bright chord. Used for reward
	# reveal moments (crate results, engram deciphered, egg hatched)
	# instead of the explosion sound, which reads as combat, not reward.
	var dur := 0.7
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var arp_pitches := [523.0, 659.0, 784.0, 1046.0]
	var arp_starts := [0.0, 0.07, 0.14, 0.21]
	var chord_pitches := [784.0, 988.0, 1175.0]
	# Amplitudes tuned so the arpeggio + chord summing together can't
	# exceed the [-1, 1] range even in the worst-case in-phase moment -
	# they used to be loud enough on their own that a coincidental peak
	# would hit the clamp() below and hard-clip, which reads as a burst
	# of static rather than a clean tone.
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		for k in range(arp_pitches.size()):
			var local_t: float = t - arp_starts[k]
			if local_t >= 0.0 and local_t < 0.18:
				var decay: float = exp(-local_t * 10.0)
				s += sin(TAU * arp_pitches[k] * local_t) * decay * 0.2
		if t > 0.24:
			var chord_t: float = t - 0.24
			var chord_env: float = exp(-chord_t * 3.2) * 0.16
			for p in chord_pitches:
				s += sin(TAU * p * chord_t) * chord_env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_jump() -> AudioStreamWAV:
	# A quick rising "whoosh" - a short upward pitch sweep with a soft
	# noise layer, reads as a light push-off rather than anything heavy.
	var dur := 0.18
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 14.0)
		var freq: float = lerp(260.0, 620.0, clamp(t / 0.12, 0.0, 1.0))
		var tone := sin(TAU * freq * t)
		var s: float = tone * env * 0.4
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_land() -> AudioStreamWAV:
	# A short low thud with a touch of noise - a body hitting ground,
	# distinct from the lighter/higher footstep tick.
	var dur := 0.14
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 24.0)
		var thump := sin(TAU * 70.0 * t)
		var noise := rng.randf_range(-1.0, 1.0)
		var s: float = (thump * 0.55 + noise * 0.25) * env
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_sword_swing() -> AudioStreamWAV:
	# A fast filtered-noise "whoosh" with a falling pitch sweep - the
	# classic blade-cutting-air sound, no metallic ring since nothing's
	# actually being struck here (that's the enemy hit-flash instead).
	var dur := 0.22
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var lp := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = sin(PI * clamp(t / dur, 0.0, 1.0)) * exp(-t * 4.0)
		var raw := rng.randf_range(-1.0, 1.0)
		lp = lerp(lp, raw, 0.5)
		var sweep_freq: float = lerp(2400.0, 900.0, t / dur)
		var whoosh := lp * sin(TAU * sweep_freq * t * 0.02 + 1.0)
		var s: float = whoosh * env * 0.6
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_energy_shot() -> AudioStreamWAV:
	# A bright sci-fi laser "pew" for the player's blue energy bolt -
	# a fast downward pitch sweep with a clean tone, so it reads as
	# something distinct from the recorded real-gun sound elsewhere.
	var dur := 0.16
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env: float = exp(-t * 16.0)
		var freq: float = lerp(1600.0, 420.0, clamp(t / 0.1, 0.0, 1.0))
		var tone := sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.2
		var s: float = tone * env * 0.5
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)

func _make_blood_hover() -> AudioStreamWAV:
	# A low, ominous double-thump like a heartbeat - dark and heavy,
	# nothing bright or musical about it.
	var dur := 0.55
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var thumps := [0.0, 0.18]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s: float = 0.0
		for start in thumps:
			var local_t: float = t - start
			if local_t >= 0.0 and local_t < 0.15:
				var decay: float = exp(-local_t * 14.0)
				s += sin(TAU * 60.0 * local_t) * decay * 0.6
				s += sin(TAU * 45.0 * local_t) * decay * 0.3
		var s16 := int(clamp(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	return _to_wav(data)
