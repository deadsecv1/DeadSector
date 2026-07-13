extends Control

# Clarity Interactive's partner credit screen - "CLARITY INTERACTIVE"
# drops in from above letter by letter, each one on its own randomized
# delay/speed so they land at staggered moments instead of falling as
# one uniform block, with a small bounce-settle on landing.

const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const PARTNER_NAME := "CLARITY INTERACTIVE"
const FONT_SIZE := 34

var _waiting_for_skip: bool = false
var _skip_requested: bool = false
var _advanced: bool = false
var _letters: Array = []  # {label, target_y}

@onready var content: Control = $Content
@onready var name_holder: Control = $Content/NameHolder
@onready var subtitle: Label = $Content/Subtitle
@onready var continue_label: Label = $Content/ContinueLabel
@onready var particles: Control = $Particles

func _ready() -> void:
	GameManager.set_default_cursor()
	content.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	continue_label.visible = false
	particles.set_script(TooltipParticlesScript)
	# Known Godot behavior: attaching a script to a node already in the
	# tree (this one's from the .tscn) silently drops its process
	# callbacks unless re-enabled from out here - see SapphireLogoMark's
	# attachment in StudioSplash.gd for the full explanation.
	particles.set_process(true)
	particles.particle_color = Color(0.6, 0.85, 1.0, 0.55)
	particles.intensity = 26
	_build_dropping_name()
	_play_sequence()

func _build_dropping_name() -> void:
	var font := load("res://assets/fonts/ChakraPetch-SemiBold.ttf")
	var widths: Array = []
	var total_width := 0.0
	for c in PARTNER_NAME:
		var w: float = font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		widths.append(w)
		total_width += w
	var start_x: float = (name_holder.size.x - total_width) / 2.0
	var target_y: float = name_holder.size.y / 2.0 - FONT_SIZE / 2.0
	var x := start_x
	for i in range(PARTNER_NAME.length()):
		var c: String = PARTNER_NAME[i]
		var lbl := Label.new()
		lbl.text = c
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.2, 0.85))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.position = Vector2(x, -500.0)
		lbl.size = Vector2(max(widths[i], 4.0), FONT_SIZE + 10.0)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_holder.add_child(lbl)
		_letters.append({"label": lbl, "target_y": target_y})
		x += widths[i]

func _animate_drop() -> void:
	for entry in _letters:
		var lbl: Label = entry["label"]
		var target_y: float = entry["target_y"]
		# Spaces have no glyph to animate - just leave them put, nothing
		# to see falling anyway.
		if lbl.text == " ":
			lbl.position.y = target_y
			continue
		var delay: float = randf_range(0.0, 0.55)
		var fall_duration: float = randf_range(0.45, 0.85)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(lbl, "position:y", target_y + 16.0, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(Sfx.play_letter_land)
		tw.tween_property(lbl, "position:y", target_y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _input(event: InputEvent) -> void:
	if _waiting_for_skip and not _skip_requested and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_skip_requested = true
		Sfx.play_menu_confirm()
		get_viewport().set_input_as_handled()

func _play_sequence() -> void:
	var in_tw := create_tween()
	in_tw.tween_property(content, "modulate:a", 1.0, 0.5)
	await in_tw.finished

	_animate_drop()
	# Longest possible drop finishes around delay(0.55) + fall(0.85) +
	# bounce(0.2) = 1.6s - hold a bit past that before the subtitle and
	# skip prompt show up, so nothing's still visibly settling.
	await get_tree().create_timer(1.9).timeout

	var sub_tw := create_tween()
	sub_tw.tween_property(subtitle, "modulate:a", 1.0, 0.5)
	await sub_tw.finished

	await get_tree().create_timer(0.6).timeout
	continue_label.visible = true
	var blink_tw := continue_label.create_tween()
	blink_tw.bind_node(continue_label)
	blink_tw.set_loops()
	blink_tw.tween_property(continue_label, "modulate:a", 1.0, 0.5)
	blink_tw.tween_property(continue_label, "modulate:a", 0.35, 0.5).set_delay(0.4)

	_waiting_for_skip = true
	var elapsed := 0.0
	while elapsed < 3.0 and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_waiting_for_skip = false
	blink_tw.kill()

	var out_tw := create_tween()
	out_tw.tween_property(content, "modulate:a", 0.0, 0.4)
	await out_tw.finished

	_advance()

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	Transition.change_scene("res://scenes/SteelcrestPartnerSplash.tscn", 0.4, 0.4)
