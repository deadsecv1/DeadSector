extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var list: VBoxContainer = $VBox/ListScroll/ItemList
@onready var close_button: Button = $VBox/CloseButton
@onready var empty_label: Label = $VBox/EmptyLabel

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	refresh()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var items: Array = GameManager.get_repairable_items()
	empty_label.visible = items.is_empty()
	for item in items:
		list.add_child(_make_row(item))

func _make_row(item: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 74)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var icon = preload("res://scenes/ItemIcon.tscn").instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(name_lbl)

	var durability := GameManager.get_item_durability(item)
	var dur_lbl := Label.new()
	dur_lbl.text = "BROKEN" if durability <= 0.0 else "Durability: %d%%" % int(round(durability))
	dur_lbl.add_theme_font_size_override("font_size", 12)
	dur_lbl.modulate = Color(1, 0.55, 0.55, 1) if durability <= 30.0 else Color(1, 1, 1, 0.7)
	vbox.add_child(dur_lbl)

	var cost: int = GameManager.get_repair_cost(item)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 44)
	btn.text = "Repair (%d Rubles)" % cost
	btn.disabled = GameManager.get_currency("rubles") < cost
	btn.pressed.connect(func():
		if GameManager.repair_item(item):
			refresh()
	)
	hbox.add_child(btn)

	return row
