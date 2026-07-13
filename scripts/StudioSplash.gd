extends Control

# First thing the game shows on boot, before IntroCutscene.tscn - the
# Sapphire Signal Studio mark (a crystal falls from above, shatters,
# and reveals the signal light inside it - see SapphireLogoMark.gd),
# then the standard photosensitivity warning every commercial game
# ships with. Same "hold until genuinely on screen, then wait for
# input" shape as IntroCutscene.gd's title card, so a fast key-mash
# can't skip past content that's supposed to actually be read.

const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const STUDIO_NAME := "SAPPHIRE SIGNAL STUDIO"
const DIM_ALPHA := 0.05

var _waiting_for_skip: bool = false
var _skip_requested: bool = false
var _advanced: bool = false
var _letter_labels: Array = []
var _ambient_particles: Control = null

@onready var logo_layer: Control = $LogoLayer
@onready var logo_mark: Control = $LogoLayer/LogoMark
@onready var name_row: HBoxContainer = $LogoLayer/NameRow
@onready var warning_layer: Control = $WarningLayer
@onready var warning_title: Label = $WarningLayer/WarningVBox/WarningTitle
@onready var warning_body: Label = $WarningLayer/WarningVBox/WarningBody
@onready var continue_label: Label = $WarningLayer/ContinueLabel

func _ready() -> void:
	GameManager.set_default_cursor()
	logo_layer.modulate.a = 1.0
	warning_layer.visible = false
	warning_layer.modulate.a = 0.0
	continue_label.visible = false
	logo_mark.set_script(preload("res://scripts/SapphireLogoMark.gd"))
	# Known Godot behavior: attaching a script to a node that's already
	# in the tree (LogoMark comes from the .tscn, already entered the
	# tree before this _ready() runs) silently drops its process
	# callbacks even though the new script's own _ready() calls
	# set_process(true) - that call doesn't take effect from inside the
	# newly-attached script itself. Has to be called again from out here.
	logo_mark.set_process(true)
	logo_mark.shattered.connect(_on_shattered)
	_build_name_letters()
	_play_sequence()

func _build_name_letters() -> void:
	# Built per-character (not a single Label) so each one can fade in
	# on its own staggered tween once the signal lights up, instead of
	# the whole name appearing/typing in at once.
	var font := load("res://assets/fonts/ChakraPetch-SemiBold.ttf")
	for c in STUDIO_NAME:
		var lbl := Label.new()
		lbl.text = c
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 27)
		lbl.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.25, 0.8))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.modulate.a = DIM_ALPHA
		name_row.add_child(lbl)
		_letter_labels.append(lbl)

func _input(event: InputEvent) -> void:
	if _waiting_for_skip and not _skip_requested and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_skip_requested = true
		Sfx.play_menu_confirm()
		get_viewport().set_input_as_handled()

func _on_shattered() -> void:
	# Letters fade in one by one, timed to feel like the signal light
	# is the thing revealing them - a short stagger per letter rather
	# than all at once.
	for i in range(_letter_labels.size()):
		var lbl: Label = _letter_labels[i]
		var tw := create_tween()
		tw.tween_interval(float(i) * 0.045)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_ambient_particles = Control.new()
	_ambient_particles.anchor_right = 1.0
	_ambient_particles.anchor_bottom = 1.0
	_ambient_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_particles.set_script(TooltipParticlesScript)
	_ambient_particles.particle_color = Color(0.65, 0.88, 1.0, 0.7)
	_ambient_particles.intensity = 30
	logo_layer.add_child(_ambient_particles)
	logo_layer.move_child(_ambient_particles, name_row.get_index())

func _play_sequence() -> void:
	# --- Logo card: dark screen, crystal falls, HOLDS intact for a beat
	# so it's actually seen (not just glimpsed mid-fall), then shatters
	# and the signal lights the name up. Long enough for the whole beat
	# to land - fall + hold + shatter + full letter stagger + a real
	# hold on the result.
	const CRYSTAL_HOLD_DURATION := 1.7
	await get_tree().create_timer(logo_mark.FALL_DURATION).timeout
	await get_tree().create_timer(CRYSTAL_HOLD_DURATION).timeout
	logo_mark.trigger_impact()
	Sfx.play_crystal_chime()

	# Letters finish staggering in at roughly FALL_DURATION + (26 letters
	# * 0.045s stagger) + the 0.5s fade each one runs - hold well past
	# that so the finished logo is genuinely seen, not skipped mid-fade.
	var letter_stagger_total: float = float(_letter_labels.size()) * 0.045 + 0.5
	_waiting_for_skip = false
	await get_tree().create_timer(letter_stagger_total + 1.6).timeout
	_waiting_for_skip = true
	var elapsed := 0.0
	while elapsed < 2.2 and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_waiting_for_skip = false
	_skip_requested = false

	var out_tw := create_tween()
	out_tw.tween_property(logo_layer, "modulate:a", 0.0, 0.5)
	await out_tw.finished

	# --- Photosensitivity warning ---
	warning_layer.visible = true
	var warn_in := create_tween()
	warn_in.tween_property(warning_layer, "modulate:a", 1.0, 0.6)
	await warn_in.finished

	await get_tree().create_timer(1.0).timeout
	continue_label.visible = true
	var blink_tw := continue_label.create_tween()
	blink_tw.bind_node(continue_label)
	blink_tw.set_loops()
	blink_tw.tween_property(continue_label, "modulate:a", 1.0, 0.5)
	blink_tw.tween_property(continue_label, "modulate:a", 0.35, 0.5).set_delay(0.4)

	_waiting_for_skip = true
	elapsed = 0.0
	# Auto-advances after a generous read window even with no input, same
	# as the warning screens in most commercial games - it's not meant to
	# block forever, just guarantee it was actually up long enough to read.
	while elapsed < 8.0 and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_waiting_for_skip = false
	blink_tw.kill()

	_advance()

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	Transition.change_scene("res://scenes/ClarityPartnerSplash.tscn", 0.5, 0.4)
