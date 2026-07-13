extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var blossoms_label: Label = $VBox/BlossomsLabel
@onready var list: VBoxContainer = $VBox/ListScroll/ItemList
@onready var close_button: Button = $VBox/CloseButton

var trader_ref: Node = null

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open_for(trader: Node) -> void:
	trader_ref = trader
	visible = true
	refresh()

func refresh() -> void:
	if trader_ref == null or not is_instance_valid(trader_ref):
		return
	blossoms_label.text = "Your Blossoms: %d" % GameManager.blossoms
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for i in range(trader_ref.stock.size()):
		list.add_child(_make_row(trader_ref.stock[i], i))
	if trader_ref.stock.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sold out - come back another raid."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty_lbl)

func _make_row(item: Dictionary, index: int) -> Control:
	var rarity: String = item.get("rarity", "legendary")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var gradient_colors: Array = GameManager.get_gradient_colors(rarity)
	var is_top_tier: bool = gradient_colors.size() > 0

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 80)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.12, 0.85)
	sb.border_color = gradient_colors[0] if is_top_tier else rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(52, 52)
	icon_frame.clip_contents = true
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_top_tier:
		var border = GameManager.make_gradient_border(rarity)
		if border != null:
			icon_frame.add_child(border)
		var slot_bg := ColorRect.new()
		slot_bg.color = Color(0.08, 0.1, 0.13, 0.9)
		slot_bg.anchor_right = 1.0
		slot_bg.anchor_bottom = 1.0
		slot_bg.offset_left = 3
		slot_bg.offset_top = 3
		slot_bg.offset_right = -3
		slot_bg.offset_bottom = -3
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(slot_bg)
	else:
		var icon_sb := StyleBoxFlat.new()
		icon_sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
		icon_sb.set_corner_radius_all(4)
		icon_frame.add_theme_stylebox_override("panel", icon_sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.custom_minimum_size = Vector2(44, 44)
	icon_frame.add_child(icon)
	hbox.add_child(icon_frame)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", gradient_colors[1] if is_top_tier else rarity_color)
	info.add_child(name_lbl)
	var rarity_lbl := Label.new()
	rarity_lbl.text = GameManager.get_rarity_label(rarity)
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.modulate = Color(1, 1, 1, 0.65)
	info.add_child(rarity_lbl)
	hbox.add_child(info)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(150, 0)
	buy_btn.text = "%d Blossoms" % int(item.get("cost", 0))
	buy_btn.disabled = GameManager.blossoms < int(item.get("cost", 0))
	buy_btn.pressed.connect(func():
		if GameManager.buy_from_wandering_trader(trader_ref.stock, index):
			refresh()
	)
	hbox.add_child(buy_btn)

	return row
