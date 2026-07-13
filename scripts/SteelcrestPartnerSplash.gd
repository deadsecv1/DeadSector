extends Control

# Steelcrest Games' partner credit screen - a bold, heavy "slam" reveal
# (scales down fast from oversized, a flash and a hard shake on
# impact) rather than Clarity's tumbling drop, so the two partner
# screens don't feel like reskins of each other.

const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")

var _waiting_for_skip: bool = false
var _skip_requested: bool = false
var _advanced: bool = false

@onready var content: Control = $Content
@onready var name_label: Label = $Content/NameLabel
@onready var subtitle: Label = $Content/Subtitle
@onready var flash: ColorRect = $Flash
@onready var continue_label: Label = $Content/ContinueLabel
@onready var particles: Control = $Particles

func _ready() -> void:
	GameManager.set_default_cursor()
	content.modulate.a = 0.0
	name_label.modulate.a = 0.0
	name_label.scale = Vector2(2.4, 2.4)
	name_label.pivot_offset = name_label.size / 2.0
	subtitle.modulate.a = 0.0
	flash.color.a = 0.0
	continue_label.visible = false
	particles.set_script(TooltipParticlesScript)
	# Same already-in-tree set_process() fix as ClarityPartnerSplash.gd.
	particles.set_process(true)
	particles.particle_color = Color(0.9, 0.55, 0.2, 0.5)
	particles.intensity = 20
	particles.modulate.a = 0.0
	_play_sequence()

func _input(event: InputEvent) -> void:
	if _waiting_for_skip and not _skip_requested and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_skip_requested = true
		Sfx.play_menu_confirm()
		get_viewport().set_input_as_handled()

func _play_sequence() -> void:
	var bg_tw := create_tween()
	bg_tw.tween_property(content, "modulate:a", 1.0, 0.3)
	await bg_tw.finished

	await get_tree().create_timer(0.3).timeout

	# The slam: name scales down hard and fast, landing right as the
	# flash and particle burst hit.
	name_label.modulate.a = 1.0
	var slam_tw := create_tween()
	slam_tw.tween_property(name_label, "scale", Vector2(0.92, 0.92), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam_tw.tween_property(name_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.22).timeout

	flash.color.a = 0.55
	var flash_tw := create_tween()
	flash_tw.tween_property(flash, "color:a", 0.0, 0.35)
	_shake_content()

	var particle_tw := create_tween()
	particle_tw.tween_property(particles, "modulate:a", 1.0, 0.2)

	await get_tree().create_timer(0.5).timeout
	var sub_tw := create_tween()
	sub_tw.tween_property(subtitle, "modulate:a", 1.0, 0.4)
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

func _shake_content() -> void:
	var base_pos: Vector2 = content.position
	var tw := create_tween()
	for i in range(5):
		var offset := Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0))
		tw.tween_property(content, "position", base_pos + offset, 0.03)
	tw.tween_property(content, "position", base_pos, 0.03)

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	Transition.change_scene("res://scenes/EngineSplash.tscn", 0.4, 0.4, false)
