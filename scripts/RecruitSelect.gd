extends Control

const RECRUIT_ORDER := ["clarity", "sorrow", "glenn", "big_crax"]
const PortraitScene := preload("res://scenes/TraderPortrait.tscn")

@onready var card_row: HBoxContainer = $VBox/CardRow
@onready var solo_button: Button = $VBox/SoloButton
@onready var back_button: Button = $VBox/BackButton

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MapSelect.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()
	solo_button.pressed.connect(func(): _deploy(""))
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MapSelect.tscn"))
	_build_cards()

func _build_cards() -> void:
	for c in card_row.get_children():
		c.queue_free()
	for rid in RECRUIT_ORDER:
		card_row.add_child(_make_card(rid))

func _make_card(rid: String) -> Control:
	var data: Dictionary = GameManager.RECRUITS.get(rid, {})
	var affordable: bool = GameManager.can_afford_recruit(rid)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 260)
	btn.disabled = not affordable
	btn.pressed.connect(func(): _deploy(rid))

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12
	vbox.offset_top = 14
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	btn.add_child(vbox)

	var portrait_box := PanelContainer.new()
	portrait_box.custom_minimum_size = Vector2(0, 110)
	var portrait = PortraitScene.instantiate()
	portrait.trader_id = rid
	portrait_box.add_child(portrait)
	vbox.add_child(portrait_box)

	var name_lbl := Label.new()
	name_lbl.text = str(data.get("label", rid))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_lbl)

	var quote_lbl := Label.new()
	quote_lbl.text = str(data.get("quote", ""))
	quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	quote_lbl.add_theme_font_size_override("font_size", 12)
	quote_lbl.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(quote_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%d Rubles" % int(data.get("cost", 0))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1) if affordable else Color(1, 0.4, 0.35, 1))
	vbox.add_child(cost_lbl)

	return btn

func _deploy(rid: String) -> void:
	if not GameManager.hire_recruit(rid):
		GameManager.toast_requested.emit("Not enough Rubles to bring them along")
		return
	if rid != "":
		GameManager.notify_event("bring_recruit_raid")
	var scene_path: String = GameManager.MAP_SCENES.get(GameManager.selected_map, "res://scenes/Main.tscn")
	Transition.change_scene(scene_path)
