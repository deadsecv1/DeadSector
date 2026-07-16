extends Control

const TraderPortraitScene := preload("res://scenes/TraderPortrait.tscn")

# A short line of in-character dialogue shown as a speech bubble above
# each trader's portrait on the hub screen.
const TRADER_QUOTES := {
	"medic": "\"Bleeding's temporary. Dying's forever.\"",
	"quartermaster": "\"Guns don't kill people. Running out of ammo does.\"",
	"scavenger": "\"One man's trash is still trash. I'll take it anyway.\"",
	"scrapper": "\"Bring me junk, I'll bring you nightmares. In gun form.\"",
	"alloy_dealer": "\"Alloys aren't cheap. Neither is staying alive.\"",
}

@onready var card_row: HBoxContainer = $VBox/CardScroll/CardRow
@onready var back_button: Button = $VBox/BackButton

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
	elif (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _ready() -> void:
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MainMenu.tscn"))
	_build_cards()

func _build_cards() -> void:
	for c in card_row.get_children():
		c.queue_free()
	for trader_id in GameManager.TRADER_CATALOG.keys():
		card_row.add_child(_make_card(trader_id))
	card_row.add_child(_make_barterer_card())

func _make_barterer_card() -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(210, 340)
	btn.pressed.connect(func():
		Transition.change_scene_instant("res://scenes/BarterPanel.tscn")
	)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12
	vbox.offset_top = 16
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	btn.add_child(vbox)

	var bubble := PanelContainer.new()
	var bubble_sb := StyleBoxFlat.new()
	bubble_sb.bg_color = Color(0.12, 0.16, 0.14, 0.95)
	bubble_sb.border_color = Color(0.4, 0.55, 0.45, 0.8)
	bubble_sb.set_border_width_all(1)
	bubble_sb.set_corner_radius_all(8)
	bubble_sb.content_margin_left = 8
	bubble_sb.content_margin_right = 8
	bubble_sb.content_margin_top = 6
	bubble_sb.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", bubble_sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_lbl := Label.new()
	bubble_lbl.text = "\"Coin's for the weak. Bring me goods.\""
	bubble_lbl.add_theme_font_size_override("font_size", 11)
	bubble_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	bubble_lbl.custom_minimum_size = Vector2(180, 0)
	bubble.add_child(bubble_lbl)
	vbox.add_child(bubble)

	var portrait = TraderPortraitScene.instantiate()
	portrait.trader_id = "barterer"
	portrait.custom_minimum_size = Vector2(140, 140)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.text = "The Barterer"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_lbl)

	var tagline_lbl := Label.new()
	tagline_lbl.text = "Trades goods for better goods"
	tagline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tagline_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(tagline_lbl)

	return btn

func _make_card(trader_id: String) -> Control:
	var trader: Dictionary = GameManager.TRADER_CATALOG[trader_id]

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(210, 340)
	btn.pressed.connect(func():
		GameManager.current_trader_id = trader_id
		Transition.change_scene_instant("res://scenes/TraderShop.tscn")
	)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12
	vbox.offset_top = 16
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	btn.add_child(vbox)

	var bubble := PanelContainer.new()
	var bubble_sb := StyleBoxFlat.new()
	bubble_sb.bg_color = Color(0.12, 0.16, 0.14, 0.95)
	bubble_sb.border_color = Color(0.4, 0.55, 0.45, 0.8)
	bubble_sb.set_border_width_all(1)
	bubble_sb.set_corner_radius_all(8)
	bubble_sb.content_margin_left = 8
	bubble_sb.content_margin_right = 8
	bubble_sb.content_margin_top = 6
	bubble_sb.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", bubble_sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_lbl := Label.new()
	bubble_lbl.text = TRADER_QUOTES.get(trader_id, "\"...\"")
	bubble_lbl.add_theme_font_size_override("font_size", 11)
	bubble_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	bubble_lbl.custom_minimum_size = Vector2(180, 0)
	bubble.add_child(bubble_lbl)
	vbox.add_child(bubble)

	var portrait = TraderPortraitScene.instantiate()
	portrait.trader_id = trader_id
	portrait.custom_minimum_size = Vector2(140, 140)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.text = str(trader.get("name", trader_id))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_lbl)

	var tagline_lbl := Label.new()
	tagline_lbl.text = str(trader.get("tagline", ""))
	tagline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tagline_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(tagline_lbl)

	return btn
