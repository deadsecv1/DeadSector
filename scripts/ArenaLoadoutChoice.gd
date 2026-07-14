extends Control

# Shown after Arena matchmaking succeeds (or a Find a Team match fills),
# right before The Grid loads - pick a named preset (weapon/gear/pet/ammo
# all matched to a theme) instead of just carrying in whatever's normally
# equipped. Cards are built dynamically from GameManager.
# ARENA_LOADOUT_PRESETS, same "_make_gear_icon per slot" pattern
# PmcScavChoice.gd uses for its two static cards.

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var card_row: HBoxContainer = $VBox/CardRow

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()
	for preset in GameManager.ARENA_LOADOUT_PRESETS:
		card_row.add_child(_make_preset_card(preset))

func _make_preset_card(preset: Dictionary) -> Control:
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
	title.text = str(preset.get("name", "?")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 1))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = str(preset.get("desc", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(1, 1, 1, 0.8)
	vbox.add_child(desc)

	var gear_label := Label.new()
	gear_label.text = "Loadout"
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_label.add_theme_font_size_override("font_size", 12)
	gear_label.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(gear_label)

	var gear_row := HBoxContainer.new()
	gear_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gear_row.add_theme_constant_override("separation", 8)
	var gear: Dictionary = preset.get("gear", {})
	for slot in ["weapon", "body", "head", "boots"]:
		if gear.has(slot):
			gear_row.add_child(_make_gear_icon(gear[slot]))
	vbox.add_child(gear_row)

	var pet_id: String = str(preset.get("pet_id", ""))
	if pet_id != "":
		var pet_data: Dictionary = GameManager.PET_CATALOG.get(pet_id, {})
		var pet_label := Label.new()
		pet_label.text = "Pet: %s" % str(pet_data.get("name", pet_id.capitalize()))
		pet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pet_label.add_theme_font_size_override("font_size", 12)
		pet_label.modulate = Color(1, 1, 1, 0.7)
		vbox.add_child(pet_label)

	card.pressed.connect(func(): _choose_preset(str(preset.get("id", ""))))
	return card

func _make_gear_icon(item: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(48, 48)
	box.tooltip_text = str(item.get("name", "?"))
	var sb := StyleBoxFlat.new()
	var rarity_color := GameManager.get_rarity_color(item.get("rarity", "common"))
	sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	return box

func _choose_preset(preset_id: String) -> void:
	GameManager.apply_arena_loadout_preset(preset_id)
	Transition.change_scene("res://scenes/TheGrid.tscn")
