extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var grid: GridContainer = $VBox/ScrollContainer/Grid
@onready var close_button: Button = $VBox/CloseButton
@onready var title_label: Label = $VBox/Title

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()

func refresh() -> void:
	for c in grid.get_children():
		c.queue_free()

	var all_pets: Array = []
	for id in GameManager.owned_pets:
		all_pets.append({"id": id, "data": GameManager.get_pet_data(id)})
	for instance_id in GameManager.owned_pet_instances:
		all_pets.append({"id": instance_id, "data": GameManager.get_pet_data(instance_id)})

	title_label.text = "PET CASE (%d)" % all_pets.size()

	if all_pets.is_empty():
		var lbl := Label.new()
		lbl.text = "No pets yet - hatch Eggs at Salvaged Beasts or buy one at the Hideout's Pet Shop."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.custom_minimum_size = Vector2(300, 0)
		grid.add_child(lbl)
		return

	for entry in all_pets:
		grid.add_child(_make_pet_tile(entry["id"], entry["data"]))

func _make_pet_tile(pet_id: String, data: Dictionary) -> Control:
	var is_equipped: bool = GameManager.equipped_pet == pet_id
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(56, 56)
	btn.tooltip_text = "%s\n%s" % [data.get("name", "?"), "Equipped" if is_equipped else "Click to equip"]

	var sb := StyleBoxFlat.new()
	var pet_color: Color = data.get("color", Color.WHITE)
	sb.bg_color = Color(pet_color.r, pet_color.g, pet_color.b, 0.22 if is_equipped else 0.1)
	sb.border_color = pet_color if is_equipped else Color(pet_color.r, pet_color.g, pet_color.b, 0.5)
	sb.set_border_width_all(3 if is_equipped else 1)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)

	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "pet_dog")
	icon.icon_color = pet_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	btn.add_child(icon)

	btn.pressed.connect(func():
		GameManager.equip_pet(pet_id)
		refresh()
	)
	return btn
