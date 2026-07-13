extends AudioStreamPlayer

# Procedurally synthesizes a dark, evolving industrial ambient track for the
# Main Menu - a low detuned drone, a slow sub-bass "heartbeat" pulse,
# irregular distant metallic clanks, and sparse high radar-like pings.
# No external audio files - everything is generated live.

const SAMPLE_RATE := 44100.0

var playback: AudioStreamGeneratorPlayback
var rng := RandomNumberGenerator.new()

# Low detuned drone (two tones a fifth apart, each pair slightly detuned).
var osc_phase := [0.0, 0.0, 0.0, 0.0]
var osc_freq := [41.2, 41.35, 61.8, 61.5]
var lfo_phase := 0.0

# Sub-bass pulse, like a distant heartbeat.
var pulse_timer := 0.0
var pulse_interval := 3.0
var pulse_env := 0.0
var pulse_phase := 0.0

# Distant metallic clank (filtered noise burst).
var clank_timer := 0.0
var clank_next := 5.0
var clank_env := 0.0
var clank_rising := false
var clank_filter_state := 0.0

# Sparse high "ping", like a radar/sonar blip.
var ping_timer := 0.0
var ping_next := 7.0
var ping_env := 0.0
var ping_phase := 0.0
var ping_freq := 1200.0

# Slow melodic arpeggio pad (Destiny-esque heroic/melancholic touch),
# cycling one soft note at a time over a minor-key sequence.
var arp_notes := [220.00, 246.94, 261.63, 196.00, 220.00, 293.66]
var arp_index := 0
var arp_timer := 0.0
var arp_note_dur := 2.6
var arp_phase := 0.0

func _ready() -> void:
	# Runs even while the tree is paused (raids pause briefly on
	# extraction/death) so the buffer never stalls mid-transition.
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	# Was 0.6s, then 1.5s - still not enough headroom for a heavy scene
	# load (Main Menu is a genuinely huge scene, 40+ panels) to fully
	# drain the buffer before _fill_buffer() got to run again. Scene
	# changes block the main thread while the new scene loads, which
	# means _process() (and therefore _fill_buffer()) doesn't run at
	# all for that whole stretch - the only real fix is enough buffered
	# audio queued up beforehand to outlast it, hence the much bigger
	# number here.
	gen.buffer_length = 4.0
	stream = gen
	bus = "Music"
	volume_db = -9.0
	play()
	playback = get_stream_playback()
	clank_next = rng.randf_range(4.0, 7.0)
	ping_next = rng.randf_range(5.0, 10.0)
	_fill_buffer()

# Called when a raid starts/ends - pausing (rather than stop()) keeps the
# generator's internal phase/envelope state intact, so it picks back up
# smoothly instead of the drone restarting from a cold buffer.
func stop_menu_music() -> void:
	stream_paused = true

func resume_menu_music() -> void:
	stream_paused = false

func _process(_delta: float) -> void:
	_fill_buffer()

func _fill_buffer() -> void:
	if playback == null:
		return
	var to_fill := playback.get_frames_available()
	var dt := 1.0 / SAMPLE_RATE
	for i in range(to_fill):
		# --- low detuned drone with a slow swell ---
		lfo_phase += dt * TAU * 0.04
		var swell := 0.45 + 0.55 * (0.5 + 0.5 * sin(lfo_phase))
		var drone := 0.0
		for j in range(osc_freq.size()):
			osc_phase[j] += osc_freq[j] * dt
			if osc_phase[j] > 1.0:
				osc_phase[j] -= 1.0
			drone += sin(osc_phase[j] * TAU)
		drone /= osc_freq.size()
		drone *= 0.20 * swell

		# --- sub-bass heartbeat pulse ---
		pulse_timer += dt
		if pulse_timer >= pulse_interval:
			pulse_timer = 0.0
			pulse_env = 1.0
			pulse_phase = 0.0
		pulse_env *= 0.9993
		pulse_phase += dt
		var pulse := sin(TAU * 48.0 * pulse_phase) * pulse_env * 0.32

		# --- distant metallic clank (filtered noise) ---
		# Unlike the pulse/ping below, this is raw noise rather than a sine
		# wave, so it has no natural zero-crossing to fade in from - jumping
		# clank_env straight to 1.0 caused an audible click/static-pop at
		# the start of every single clank. Rising smoothly instead, and
		# decaying about 100x slower than before (was tuned as if this ran
		# once per video frame, not once per audio sample), so it actually
		# reads as a soft distant clank instead of a millisecond of static.
		clank_timer += dt
		if clank_timer >= clank_next:
			clank_timer = 0.0
			clank_next = rng.randf_range(4.0, 8.0)
			clank_rising = true
		if clank_rising:
			clank_env += (1.0 - clank_env) * 0.02
			if clank_env > 0.995:
				clank_env = 1.0
				clank_rising = false
		else:
			clank_env *= 0.99988
		var noise := rng.randf_range(-1.0, 1.0)
		clank_filter_state += (noise - clank_filter_state) * 0.5
		var clank := clank_filter_state * clank_env * 0.15

		# --- sparse high radar ping ---
		ping_timer += dt
		if ping_timer >= ping_next:
			ping_timer = 0.0
			ping_next = rng.randf_range(6.0, 12.0)
			ping_env = 1.0
			ping_phase = 0.0
			ping_freq = rng.randf_range(900.0, 1600.0)
		ping_env *= 0.997
		ping_phase += dt
		var ping := sin(TAU * ping_freq * ping_phase) * ping_env * 0.08

		# --- slow melodic arpeggio pad ---
		arp_timer += dt
		if arp_timer >= arp_note_dur:
			arp_timer = 0.0
			arp_index = (arp_index + 1) % arp_notes.size()
			arp_phase = 0.0
		var arp_env: float = sin(PI * clamp(arp_timer / arp_note_dur, 0.0, 1.0))
		arp_phase += arp_notes[arp_index] * dt
		var arp_tone := sin(arp_phase * TAU) + 0.4 * sin(arp_phase * TAU * 2.0)
		var arp := arp_tone * arp_env * 0.09

		var mixed := tanh((drone + pulse + clank + ping + arp) * 1.3)
		playback.push_frame(Vector2(mixed, mixed))
