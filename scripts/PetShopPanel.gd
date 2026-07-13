extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var list: VBoxContainer = $VBox/ListScroll/PetList
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	GameManager.traders_rotated.connect(func():
		if visible:
			refresh()
	)

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for pet_id in GameManager.pet_shop_stock:
		list.add_child(_make_row(pet_id))

func _make_row(pet_id: String) -> Control:
	var pet: Dictionary = GameManager.PET_CATALOG[pet_id]
	var owned: bool = GameManager.owned_pets.has(pet_id)
	var equipped: bool = GameManager.equipped_pet == pet_id

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 84)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.32, 0.15, 0.25) if equipped else Color(0.1, 0.1, 0.1, 0.6)
	sb.border_color = Color(0.85, 0.7, 0.3, 1) if equipped else Color(0.3, 0.3, 0.3, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(64, 64)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = pet.get("icon_key", "generic")
	icon.icon_color = pet.get("color", Color.WHITE)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(pet.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	info.add_child(name_lbl)
	var stat_lbl := Label.new()
	stat_lbl.text = ItemTooltip._format_stat(pet.get("stat_type", ""), pet.get("stat_value", 0.0))
	stat_lbl.add_theme_font_size_override("font_size", 13)
	stat_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7, 1))
	info.add_child(stat_lbl)
	var quote_lbl := Label.new()
	quote_lbl.text = str(pet.get("quote", ""))
	quote_lbl.add_theme_font_size_override("font_size", 11)
	quote_lbl.modulate = Color(1, 1, 1, 0.6)
	info.add_child(quote_lbl)
	hbox.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 0)
	if equipped:
		btn.text = "Equipped"
		btn.disabled = true
	elif owned:
		btn.text = "Equip"
		btn.pressed.connect(func():
			GameManager.equip_pet(pet_id)
			refresh()
		)
	else:
		btn.text = "Buy (%d Rubles)" % int(pet.get("cost", 0))
		btn.disabled = GameManager.rubles < int(pet.get("cost", 0))
		btn.pressed.connect(func():
			if GameManager.purchase_pet(pet_id):
				refresh()
		)
	hbox.add_child(btn)

	return row
