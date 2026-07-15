extends Control

# Shown right after clicking Matchmake in the Arena panel, before
# ArenaMatchmaking.tscn's searching beat - picks a queue size (1v1 or
# 2v2) instead of always rolling the original random 4v4-7v7 squad
# match. The choice is handed off via GameManager.arena_queued_team_size
# (ArenaMatchmaking.gd reads and clears it).

const MODES := [
	{"id": "1v1", "team_size": 1, "title": "1v1", "desc": "Solo duel - just you against one opponent."},
	{"id": "2v2", "team_size": 2, "title": "2v2", "desc": "You and one ally against a pair of opponents."},
]

@onready var card_row: HBoxContainer = $VBox/CardRow

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()
	for mode in MODES:
		card_row.add_child(_make_mode_card(mode))

func _make_mode_card(mode: Dictionary) -> Control:
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var idle_style := StyleBoxFlat.new()
	idle_style.bg_color = Color(0.1, 0.08, 0.13, 0.5)
	idle_style.border_color = Color(0.75, 0.55, 0.95, 0.3)
	idle_style.set_border_width_all(2)
	idle_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("normal", idle_style)
	card.add_theme_stylebox_override("focus", idle_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.14, 0.1, 0.18, 0.7)
	hover_style.border_color = Color(0.85, 0.6, 1.0, 0.9)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)

	card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
	card.mouse_entered.connect(func():
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
	)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -16.0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var title := Label.new()
	title.text = str(mode.get("title", "?"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 1))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = str(mode.get("desc", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(1, 1, 1, 0.8)
	vbox.add_child(desc)

	card.pressed.connect(func(): _choose_mode(int(mode.get("team_size", 1))))
	return card

func _choose_mode(team_size: int) -> void:
	GameManager.arena_queued_team_size = team_size
	Transition.change_scene("res://scenes/ArenaMatchmaking.tscn")
