extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var title_label: Label = $VBox/TitleLabel
@onready var list: VBoxContainer = $VBox/Scroll/List
@onready var close_button: Button = $VBox/CloseButton

var current_icon_key: String = ""

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	GameManager.skins_changed.connect(_refresh)

func open_for(item: Dictionary) -> void:
	current_icon_key = item.get("icon_key", "")
	title_label.text = "Skins - %s" % item.get("name", "?")
	visible = true
	_refresh()
	GameManager.focus_first_control(self)

func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var skins: Array = GameManager.get_skins_for(current_icon_key)
	if skins.is_empty():
		var lbl := Label.new()
		lbl.text = "No skins available for this item type."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(lbl)
		return

	list.add_child(_make_row({"id": "", "name": "Default (No Skin)", "cost": 0}, true))
	for skin in skins:
		list.add_child(_make_row(skin, false))

func _make_row(skin: Dictionary, is_default: bool) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 58)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(28, 28)
	swatch.color = Color(0.35, 0.35, 0.38, 1) if is_default else skin.get("color", Color.WHITE)
	hbox.add_child(swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = skin.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(name_lbl)
	if not is_default:
		var cost_lbl := Label.new()
		cost_lbl.text = "%d Rubles" % int(skin.get("cost", 0))
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.modulate = Color(1, 1, 1, 0.7)
		info.add_child(cost_lbl)
	hbox.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 42)
	var skin_id: String = skin.get("id", "")
	var owned: bool = is_default or GameManager.owned_skins.has(skin_id)
	var is_equipped: bool = GameManager.equipped_skins.get(current_icon_key, "") == skin_id

	if is_equipped:
		btn.text = "Equipped"
		btn.disabled = true
	elif owned:
		btn.text = "Equip"
		btn.pressed.connect(func():
			GameManager.equip_skin(skin_id, current_icon_key)
			_refresh()
		)
	else:
		btn.text = "Buy"
		btn.pressed.connect(func():
			GameManager.buy_skin(skin_id, current_icon_key)
			_refresh()
		)
	hbox.add_child(btn)

	return row
