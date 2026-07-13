extends Control

# Input is completely ignored until "PRESS ANY BUTTON TO PLAY" is
# genuinely on screen - the buildup animation always plays in full.
# Once past that title card, the World View cutscene also always plays
# in full - there is no skip mechanism anywhere in this scene anymore.
var start_requested: bool = false
var waiting_for_start: bool = false
var finished: bool = false

const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")
const TwinkleStarBorderScript := preload("res://scripts/TwinkleStarBorder.gd")
const MeteorShowerScript := preload("res://scripts/MeteorShower.gd")
const CursorLilDirtyScript := preload("res://scripts/CursorLilDirty.gd")

@onready var background: ColorRect = $Background
@onready var skyline: Control = $Skyline
@onready var embers: Control = $Embers
@onready var title_logo: Control = $TitleLogo
@onready var tagline_label: Label = $TaglineLabel
@onready var press_start_label: Label = $PressStartLabel
@onready var world_view: Control = $WorldView

const TAGLINE_TEXT := "T H E   S E C T O R   D O E S   N O T   F O R G I V E"

# Rotating quotes shown (one at a time, crossfading) once the title
# card is up and waiting for input - the same letter-spaced caps style
# as the original tagline, generated automatically so these can just be
# written normally below.
const IDLE_QUOTES := [
	"THE SECTOR DOES NOT FORGIVE",
	"EXTRACT OR BE FORGOTTEN",
	"EVERY RAID IS A GAMBLE",
	"TRUST NOTHING. LOOT EVERYTHING.",
	"THE SECTOR REMEMBERS EVERY NAME",
	"SURVIVAL IS NEVER GUARANTEED",
]
const QUOTE_INTERVAL := 2.0

# Background/text color cycle - a slow sine wave between near-black and
# grey, looping forever until the player presses start. Text color is
# derived from the SAME wave (inverted) each frame, so it always stays
# in sync and readable, with no separate tween that could drift.
const BG_DARK := Color(0.015, 0.015, 0.02, 1)
const BG_LIGHT := Color(0.55, 0.55, 0.58, 1)
const BG_CYCLE_SECONDS := 7.0

var _effects_active: bool = false
var _quote_rotation_active: bool = false
var _color_cycle_time: float = 0.0
var _quote_timer: float = 0.0
var _quote_index: int = 0
var _cursor_lil_dirty: Control = null
var _title_trace: Control = null
var _title_stars: Control = null
var _meteor_shower: Control = null
var _extra_particles: Control = null

func _ready() -> void:
	GameManager.set_default_cursor()
	skyline.position.y = 260.0
	title_logo.visible = false
	title_logo.scale = Vector2(0.2, 0.2)
	title_logo.modulate.a = 0.0
	title_logo.pivot_offset = title_logo.size / 2.0
	tagline_label.visible = false
	tagline_label.text = ""
	press_start_label.visible = false
	press_start_label.modulate.a = 0.0
	world_view.visible = false
	world_view.modulate.a = 0.0

	# The background color cycle, particles, title tracing, twinkling
	# stars, meteor shower, and cursor Lil Dirty all start immediately -
	# no reason to wait for the buildup animation (skyline rising, title
	# bouncing in) to finish first. Only the quote rotation waits, since
	# it would otherwise fight with the tagline's typed-out reveal.
	_effects_active = true
	_color_cycle_time = 0.0
	_spawn_extra_flourish()

	_play_sequence()

func _input(event: InputEvent) -> void:
	if waiting_for_start and not start_requested and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		start_requested = true
		Sfx.play_menu_confirm()
		get_viewport().set_input_as_handled()

func _play_sequence() -> void:
	await get_tree().create_timer(1.2).timeout

	# Skyline rises into view.
	var rise_tw := create_tween()
	rise_tw.tween_property(skyline, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.3).timeout

	# Title bounces in with a scale overshoot, plus a quick jitter for impact.
	title_logo.visible = true
	Sfx.play_crystal_chime()
	var title_tw := create_tween()
	title_tw.tween_property(title_logo, "scale", Vector2(1.08, 1.08), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_tw.parallel().tween_property(title_logo, "modulate:a", 1.0, 0.3)
	title_tw.tween_property(title_logo, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
	await title_tw.finished
	_do_jitter()
	await get_tree().create_timer(1.4).timeout

	# Tagline types itself out letter by letter.
	tagline_label.visible = true
	for i in range(TAGLINE_TEXT.length() + 1):
		tagline_label.text = TAGLINE_TEXT.substr(0, i)
		await get_tree().create_timer(0.045).timeout

	await _show_press_start()
	await _play_world_view()
	_finish()

# Holds on the title screen with a blinking prompt until the player
# presses anything, like a real game's main menu title card. This is
# the ONLY moment any input is listened to in this whole scene.
func _show_press_start() -> void:
	press_start_label.visible = true
	waiting_for_start = true
	var blink_tw := press_start_label.create_tween()
	blink_tw.bind_node(press_start_label)
	blink_tw.set_loops()
	blink_tw.tween_property(press_start_label, "modulate:a", 1.0, 0.5)
	blink_tw.tween_property(press_start_label, "modulate:a", 0.35, 0.5).set_delay(0.4)

	_quote_rotation_active = true
	_quote_timer = 0.0
	_quote_index = 0

	while not start_requested:
		await get_tree().process_frame
	blink_tw.kill()
	waiting_for_start = false
	start_requested = false
	press_start_label.visible = false
	_effects_active = false
	_quote_rotation_active = false

	# Settle the background/text back to the normal dark state and clean
	# up everything spawned just for this hold-for-input phase.
	background.color = BG_DARK
	tagline_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.7, 1))
	press_start_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1))
	if _cursor_lil_dirty != null and is_instance_valid(_cursor_lil_dirty):
		_cursor_lil_dirty.dismiss()
		_cursor_lil_dirty = null
	if _title_trace != null and is_instance_valid(_title_trace):
		_title_trace.queue_free()
		_title_trace = null
	if _title_stars != null and is_instance_valid(_title_stars):
		_title_stars.queue_free()
		_title_stars = null
	if _meteor_shower != null and is_instance_valid(_meteor_shower):
		_meteor_shower.queue_free()
		_meteor_shower = null
	if _extra_particles != null and is_instance_valid(_extra_particles):
		_extra_particles.queue_free()
		_extra_particles = null

# The denser drifting particle field, the shiny tracing line around the
# title, the twinkling stars, the meteor shower, and the cursor-following
# Lil Dirty cameo - all spawned once from _ready() and alive for the
# entire screen (not just once "press any button" appears), and cleaned
# up together the moment the player actually presses start.
func _spawn_extra_flourish() -> void:
	_extra_particles = Control.new()
	_extra_particles.anchor_right = 1.0
	_extra_particles.anchor_bottom = 1.0
	_extra_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra_particles.set_script(TooltipParticlesScript)
	_extra_particles.particle_color = Color(0.75, 0.8, 0.85, 0.6)
	_extra_particles.intensity = 60
	add_child(_extra_particles)
	move_child(_extra_particles, title_logo.get_index())

	_title_trace = Control.new()
	_title_trace.anchor_left = 0.5
	_title_trace.anchor_top = 0.5
	_title_trace.anchor_right = 0.5
	_title_trace.anchor_bottom = 0.5
	# TitleLogo.gd draws "D E A D   S E C T O R" at font_size 56, centered
	# inside its own much-larger 800x130 layout box - tracing THAT box
	# produced a huge rectangle around mostly empty padding. Compute the
	# actual rendered text size the same way TitleLogo.gd does instead,
	# and hug that.
	var title_font: Font = load("res://assets/fonts/GaliverSans-Bold.ttf")
	var title_text_size: Vector2 = title_font.get_string_size("D E A D   S E C T O R", HORIZONTAL_ALIGNMENT_LEFT, -1, 56)
	var pad := Vector2(24.0, 16.0)
	var box_size: Vector2 = title_text_size + pad * 2.0
	var title_center_y: float = (title_logo.offset_top + title_logo.offset_bottom) / 2.0 - 10.0
	_title_trace.offset_left = -box_size.x / 2.0
	_title_trace.offset_right = box_size.x / 2.0
	_title_trace.offset_top = title_center_y - box_size.y / 2.0
	_title_trace.offset_bottom = title_center_y + box_size.y / 2.0
	_title_trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_trace.set_script(GlowTraceBorderScript)
	_title_trace.trace_color = Color(1, 1, 1, 0.9)
	_title_trace.trace_speed = 90.0
	_title_trace.trace_segments = 20
	_title_trace.trace_width = 2.2
	_title_trace.glow_boost = 1.8
	add_child(_title_trace)

	_title_stars = Control.new()
	_title_stars.anchor_left = 0.5
	_title_stars.anchor_top = 0.5
	_title_stars.anchor_right = 0.5
	_title_stars.anchor_bottom = 0.5
	_title_stars.offset_left = _title_trace.offset_left
	_title_stars.offset_right = _title_trace.offset_right
	_title_stars.offset_top = _title_trace.offset_top
	_title_stars.offset_bottom = _title_trace.offset_bottom
	_title_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_stars.set_script(TwinkleStarBorderScript)
	_title_stars.star_color = Color(1, 1, 1, 1)
	_title_stars.star_count = 10
	_title_stars.min_size = 3.0
	_title_stars.max_size = 6.0
	add_child(_title_stars)

	_meteor_shower = Control.new()
	_meteor_shower.anchor_right = 1.0
	_meteor_shower.anchor_bottom = 1.0
	_meteor_shower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meteor_shower.set_script(MeteorShowerScript)
	add_child(_meteor_shower)
	move_child(_meteor_shower, title_logo.get_index())
	_meteor_shower.title_rect = _title_trace.get_global_rect()
	_meteor_shower.skyline = skyline
	_meteor_shower.meteor_color = Color(1, 1, 1, 0.16)

	_cursor_lil_dirty = Control.new()
	_cursor_lil_dirty.set_script(CursorLilDirtyScript)
	add_child(_cursor_lil_dirty)

func _process(delta: float) -> void:
	if not _effects_active:
		return

	# Smooth, continuous, never-ending sine oscillation between dark and
	# light - no tween to restart or drift out of sync with the text.
	_color_cycle_time += delta
	var t: float = (sin(_color_cycle_time * TAU / (BG_CYCLE_SECONDS * 2.0)) + 1.0) / 2.0
	background.color = BG_DARK.lerp(BG_LIGHT, t)
	var text_color: Color = Color.WHITE.lerp(Color.BLACK, t)
	tagline_label.add_theme_color_override("font_color", text_color)
	press_start_label.add_theme_color_override("font_color", text_color)
	skyline.contrast_color = text_color
	if _title_trace != null and is_instance_valid(_title_trace):
		_title_trace.trace_color = Color(text_color.r, text_color.g, text_color.b, 0.9)
	if _title_stars != null and is_instance_valid(_title_stars):
		_title_stars.star_color = Color(text_color.r, text_color.g, text_color.b, 1.0)
	if _meteor_shower != null and is_instance_valid(_meteor_shower):
		_meteor_shower.meteor_color = Color(text_color.r, text_color.g, text_color.b, 0.16)
		_meteor_shower.title_rect = _title_trace.get_global_rect()

	if not _quote_rotation_active:
		return

	# Rotating quotes, crossfading every QUOTE_INTERVAL seconds.
	_quote_timer += delta
	if _quote_timer >= QUOTE_INTERVAL:
		_quote_timer = 0.0
		_quote_index = (_quote_index + 1) % IDLE_QUOTES.size()
		var tw := create_tween()
		tw.tween_property(tagline_label, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func(): tagline_label.text = _spaced(IDLE_QUOTES[_quote_index]))
		tw.tween_property(tagline_label, "modulate:a", 1.0, 0.35)

func _spaced(text: String) -> String:
	var words: PackedStringArray = text.split(" ")
	var spaced_words: Array = []
	for word in words:
		var letters: Array = []
		for i in range(word.length()):
			letters.append(word[i])
		spaced_words.append(" ".join(letters))
	return "   ".join(spaced_words)

func _play_world_view() -> void:
	# Fade out the title beat.
	var out_tw := create_tween()
	out_tw.tween_property(title_logo, "modulate:a", 0.0, 0.7)
	out_tw.parallel().tween_property(tagline_label, "modulate:a", 0.0, 0.7)
	out_tw.parallel().tween_property(skyline, "modulate:a", 0.0, 0.7)
	out_tw.parallel().tween_property(embers, "modulate:a", 0.0, 0.7)
	await out_tw.finished

	# Fade in the wide vista shot with the character overlooking the world.
	world_view.visible = true
	world_view.scale = Vector2(1.0, 1.0)
	world_view.pivot_offset = world_view.size / 2.0
	var world_subtitle: Label = world_view.get_node("WorldViewSubtitle")
	world_subtitle.modulate.a = 0.0

	var in_tw := create_tween()
	in_tw.tween_property(world_view, "modulate:a", 1.0, 1.2)
	await in_tw.finished

	var subtitle_tw := create_tween()
	subtitle_tw.tween_property(world_subtitle, "modulate:a", 1.0, 1.0)

	# Slow cinematic push-in for the remainder of the shot. Always plays
	# in full now - there's no skip during this beat.
	var zoom_tw := create_tween()
	zoom_tw.tween_property(world_view, "scale", Vector2(1.08, 1.08), 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(3.5).timeout

func _do_jitter() -> void:
	var base_pos: Vector2 = title_logo.position
	var tw := create_tween()
	for i in range(4):
		var offset := Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
		tw.tween_property(title_logo, "position", base_pos + offset, 0.03)
	tw.tween_property(title_logo, "position", base_pos, 0.03)

func _finish() -> void:
	if finished:
		return
	finished = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	if GameManager.character_created:
		Transition.change_scene("res://scenes/MainMenu.tscn", 0.0, 0.5)
	else:
		Transition.change_scene("res://scenes/LoreIntro.tscn", 0.0, 0.5)
