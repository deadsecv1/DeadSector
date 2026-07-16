extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# PMC Loadout Presets: save your currently equipped gear into one of 3
# fixed slots from the Stash, then one-click re-equip it later. Unlike
# Arena's disposable loadout presets, this is real gear - applying a
# preset actually swaps what's equipped and what's sitting in the Stash.

signal closed

const SLOT_ORDER := ["head", "body", "weapon", "accessory", "boots", "backpack"]

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var list: VBoxContainer = $VBox/Scroll/List
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	GameManager.equipped_changed.connect(_refresh)

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug as Flea Market/Mail - force the
	# designed centered layout back explicitly.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -220.0
	offset_top = -190.0
	offset_right = 220.0
	offset_bottom = 190.0
	_refresh()

func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	for i in range(GameManager.LOADOUT_PRESET_SLOT_COUNT):
		list.add_child(_make_row(i))

func _summary_for(preset) -> String:
	if preset == null:
		return "Empty"
	var names: Array = []
	for slot in SLOT_ORDER:
		var it = preset.get(slot)
		if it != null:
			names.append(str(it.get("name", "?")))
	if names.is_empty():
		return "Empty (nothing was equipped when saved)"
	return ", ".join(names)

func _make_row(index: int) -> Control:
	var preset = GameManager.player_loadout_presets[index]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.09, 0.9)
	sb.border_color = Color(0.5, 0.7, 0.9, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "Loadout %d" % (index + 1)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
	vbox.add_child(title)

	var summary := Label.new()
	summary.text = _summary_for(preset)
	summary.add_theme_font_size_override("font_size", 11)
	summary.modulate = Color(1, 1, 1, 0.7)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(summary)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	vbox.add_child(button_row)

	var save_button := Button.new()
	save_button.text = "Save Current Gear"
	save_button.custom_minimum_size = Vector2(140, 32)
	save_button.pressed.connect(func():
		GameManager.save_loadout_preset(index)
		_refresh()
	)
	button_row.add_child(save_button)

	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.custom_minimum_size = Vector2(70, 32)
	apply_button.disabled = preset == null
	apply_button.pressed.connect(func():
		GameManager.apply_loadout_preset(index)
	)
	button_row.add_child(apply_button)

	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.custom_minimum_size = Vector2(60, 32)
	clear_button.disabled = preset == null
	clear_button.pressed.connect(func():
		GameManager.delete_loadout_preset(index)
		_refresh()
	)
	button_row.add_child(clear_button)

	return card
