extends Control

# Standard legal/copyright screen - plays after the engine credit,
# before the title sequence. Same "fade in, hold, wait for skippable
# input" shape as the other splash screens.

var _waiting_for_skip: bool = false
var _skip_requested: bool = false
var _advanced: bool = false

@onready var content: Control = $Content
@onready var continue_label: Label = $Content/ContinueLabel

func _ready() -> void:
	GameManager.set_default_cursor()
	content.modulate.a = 0.0
	continue_label.visible = false
	_play_sequence()

func _input(event: InputEvent) -> void:
	if _waiting_for_skip and not _skip_requested and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_skip_requested = true
		Sfx.play_menu_confirm()
		get_viewport().set_input_as_handled()

func _play_sequence() -> void:
	Sfx.play_soft_whoosh()
	var in_tw := create_tween()
	in_tw.tween_property(content, "modulate:a", 1.0, 0.6)
	await in_tw.finished

	await get_tree().create_timer(0.8).timeout
	continue_label.visible = true
	var blink_tw := continue_label.create_tween()
	blink_tw.bind_node(continue_label)
	blink_tw.set_loops()
	blink_tw.tween_property(continue_label, "modulate:a", 1.0, 0.5)
	blink_tw.tween_property(continue_label, "modulate:a", 0.35, 0.5).set_delay(0.4)

	_waiting_for_skip = true
	var elapsed := 0.0
	while elapsed < 4.5 and not _skip_requested:
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
	Transition.change_scene("res://scenes/IntroCutscene.tscn", 0.4, 0.5)
