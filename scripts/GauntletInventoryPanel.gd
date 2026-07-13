extends Control

# The Gauntlet's inventory view - a real equipment doll (drag carried
# loot onto a slot to equip, drag back out to unequip) next to the
# carried loot grid. Right-click on anything opens a small context
# menu (Equip/Unequip, Info, Inspect) instead of instantly acting -
# no more accidental right-click auto-equips or auto-moves.

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const GauntletDollSlotScript := preload("res://scripts/GauntletDollSlot.gd")
const GauntletLootTileScript := preload("res://scripts/GauntletLootTile.gd")
const SLOT_NAMES := ["head", "weapon", "body", "accessory", "boots", "backpack"]

@onready var backdrop: ColorRect = $Backdrop
@onready var grid: GridContainer = $MainRow/LootCol/ScrollContainer/Grid
@onready var title_label: Label = $MainRow/LootCol/Title
@onready var doll_area: Control = $MainRow/DollCol/DollArea

var slot_buttons: Dictionary = {}

# --- Custom tooltip: a styled, rarity-colored popup that follows the
# mouse, replacing the default tiny plain-text OS tooltip.
var tooltip_panel: PanelContainer
var tooltip_style: StyleBoxFlat
var tooltip_name_label: Label
var tooltip_rarity_label: Label
var tooltip_stat_label: Label
var tooltip_hint_label: Label

# --- Right-click context menu: Equip/Unequip, Info, Inspect. Closes
# automatically the moment you click anywhere outside it.
var context_menu: PanelContainer
var context_equip_btn: Button
var context_info_btn: Button
var context_inspect_btn: Button
var context_source: String = ""
var context_index: int = -1
var context_slot: String = ""
var context_item: Dictionary = {}

# --- Info / Inspect popups, both close on click-away too.
var info_popup: PanelContainer
var info_name_label: Label
var info_rarity_label: Label
var info_stat_label: Label
var info_value_label: Label

var inspect_popup: PanelContainer
var inspect_icon_holder: Control
var inspect_name_label: Label
var inspect_rarity_label: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	for slot_name in SLOT_NAMES:
		var btn: Button = doll_area.get_node(_slot_node_name(slot_name))
		slot_buttons[slot_name] = btn
		btn.set_script(GauntletDollSlotScript)
		btn.slot_name = slot_name
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				var item = GameManager.gauntlet_equipped_items.get(slot_name)
				if item != null:
					_open_context_menu("doll", -1, slot_name, item, event.global_position)
		)
		btn.mouse_entered.connect(func(): _on_slot_hover(slot_name))
		btn.mouse_exited.connect(_hide_tooltip)
	GameManager.gauntlet_equipment_changed.connect(refresh)
	_build_tooltip()
	_build_context_menu()
	_build_info_popup()
	_build_inspect_popup()

func _build_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.visible = false
	tooltip_panel.z_index = 200
	tooltip_panel.custom_minimum_size = Vector2(190, 0)
	tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.05, 0.05, 0.08, 0.97)
	tooltip_style.set_border_width_all(2)
	tooltip_style.set_corner_radius_all(6)
	tooltip_style.set_content_margin_all(10)
	tooltip_style.shadow_size = 10
	tooltip_style.shadow_color = Color(0, 0, 0, 0.55)
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	tooltip_panel.add_child(vb)
	tooltip_name_label = Label.new()
	tooltip_name_label.add_theme_font_size_override("font_size", 15)
	tooltip_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(tooltip_name_label)
	tooltip_rarity_label = Label.new()
	tooltip_rarity_label.add_theme_font_size_override("font_size", 11)
	vb.add_child(tooltip_rarity_label)
	vb.add_child(HSeparator.new())
	tooltip_stat_label = Label.new()
	tooltip_stat_label.add_theme_font_size_override("font_size", 12)
	tooltip_stat_label.modulate = Color(0.75, 1.0, 0.8, 1)
	vb.add_child(tooltip_stat_label)
	tooltip_hint_label = Label.new()
	tooltip_hint_label.add_theme_font_size_override("font_size", 10)
	tooltip_hint_label.modulate = Color(1, 1, 1, 0.55)
	vb.add_child(tooltip_hint_label)
	add_child(tooltip_panel)

func _format_stat(item: Dictionary) -> String:
	var stat_type: String = item.get("stat_type", "")
	var stat_value: float = item.get("stat_value", 0.0)
	var labels := {"damage": "Damage", "max_health": "Max Health", "speed": "Speed", "fire_rate": "Fire Rate"}
	var label: String = labels.get(stat_type, stat_type.capitalize())
	if stat_type == "fire_rate":
		return "+%.1f%% %s" % [stat_value * 100.0, label]
	return "+%.0f %s" % [stat_value, label]

func _show_tooltip(item: Dictionary, hint: String) -> void:
	var rarity: String = item.get("rarity", "common")
	var color := GameManager.get_rarity_color(rarity)
	tooltip_name_label.text = item.get("name", "?")
	tooltip_name_label.modulate = color
	tooltip_rarity_label.text = GameManager.get_rarity_label(rarity).to_upper()
	tooltip_rarity_label.modulate = color
	var weapon_label: String = GameManager.get_gauntlet_weapon_type_label(item)
	if weapon_label != "":
		tooltip_stat_label.text = "%s\n%s" % [weapon_label, _format_stat(item)]
		tooltip_stat_label.modulate = Color(1.0, 0.6, 0.4, 1) if GameManager.is_gauntlet_item_melee(item) else Color(0.5, 0.85, 1.0, 1)
	else:
		tooltip_stat_label.text = _format_stat(item)
		tooltip_stat_label.modulate = Color(0.75, 1.0, 0.8, 1)
	tooltip_hint_label.text = hint
	tooltip_style.border_color = color
	tooltip_panel.visible = true
	_position_tooltip()

func _hide_tooltip() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = false

func _position_tooltip() -> void:
	if tooltip_panel == null or not tooltip_panel.visible:
		return
	var mouse_pos := get_local_mouse_position()
	var target := mouse_pos + Vector2(18, 18)
	var max_x: float = size.x - tooltip_panel.size.x - 6
	var max_y: float = size.y - tooltip_panel.size.y - 6
	target.x = clamp(target.x, 6, max(6.0, max_x))
	target.y = clamp(target.y, 6, max(6.0, max_y))
	tooltip_panel.position = target

func _process(_delta: float) -> void:
	_position_tooltip()

# Clicking anywhere outside an open popup closes it - no Close button
# needed. Uses _input (not gui_input) so it catches clicks that land
# outside the popup's own rect, not just inside it.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if context_menu != null and context_menu.visible and not context_menu.get_global_rect().has_point(event.global_position):
		context_menu.visible = false
	if info_popup != null and info_popup.visible and not info_popup.get_global_rect().has_point(event.global_position):
		info_popup.visible = false
	if inspect_popup != null and inspect_popup.visible and not inspect_popup.get_global_rect().has_point(event.global_position):
		inspect_popup.visible = false

func _build_context_menu() -> void:
	context_menu = PanelContainer.new()
	context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	context_menu.visible = false
	context_menu.z_index = 210
	context_menu.custom_minimum_size = Vector2(150, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.98)
	sb.border_color = Color(0.6, 0.6, 0.68, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(6)
	context_menu.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	context_menu.add_child(vb)

	context_equip_btn = Button.new()
	context_equip_btn.text = "Equip"
	context_equip_btn.custom_minimum_size = Vector2(0, 30)
	context_equip_btn.pressed.connect(_on_context_equip)
	vb.add_child(context_equip_btn)

	context_info_btn = Button.new()
	context_info_btn.text = "Info"
	context_info_btn.custom_minimum_size = Vector2(0, 30)
	context_info_btn.pressed.connect(func():
		context_menu.visible = false
		_show_info_popup(context_item)
	)
	vb.add_child(context_info_btn)

	context_inspect_btn = Button.new()
	context_inspect_btn.text = "Inspect"
	context_inspect_btn.custom_minimum_size = Vector2(0, 30)
	context_inspect_btn.pressed.connect(func():
		context_menu.visible = false
		_show_inspect_popup(context_item)
	)
	vb.add_child(context_inspect_btn)

	add_child(context_menu)

func _open_context_menu(source: String, index: int, slot_name: String, item: Dictionary, _at_position: Vector2) -> void:
	_hide_tooltip()
	info_popup.visible = false
	inspect_popup.visible = false
	context_source = source
	context_index = index
	context_slot = slot_name
	context_item = item
	context_equip_btn.text = "Unequip" if source == "doll" else "Equip"
	context_menu.visible = true
	var target := get_local_mouse_position()
	var max_x: float = size.x - context_menu.size.x - 6
	var max_y: float = size.y - context_menu.size.y - 6
	target.x = clamp(target.x, 6, max(6.0, max_x))
	target.y = clamp(target.y, 6, max(6.0, max_y))
	context_menu.position = target

func _on_context_equip() -> void:
	context_menu.visible = false
	if context_source == "doll":
		GameManager.gauntlet_unequip_item(context_slot)
	else:
		GameManager.gauntlet_equip_item(context_index)

func _build_info_popup() -> void:
	info_popup = PanelContainer.new()
	info_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	info_popup.visible = false
	info_popup.z_index = 210
	info_popup.custom_minimum_size = Vector2(200, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	sb.border_color = Color(0.6, 0.6, 0.68, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	info_popup.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	info_popup.add_child(vb)
	info_name_label = Label.new()
	info_name_label.add_theme_font_size_override("font_size", 16)
	info_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(info_name_label)
	info_rarity_label = Label.new()
	info_rarity_label.add_theme_font_size_override("font_size", 12)
	vb.add_child(info_rarity_label)
	vb.add_child(HSeparator.new())
	info_stat_label = Label.new()
	info_stat_label.add_theme_font_size_override("font_size", 12)
	info_stat_label.modulate = Color(0.75, 1.0, 0.8, 1)
	vb.add_child(info_stat_label)
	info_value_label = Label.new()
	info_value_label.add_theme_font_size_override("font_size", 11)
	info_value_label.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(info_value_label)
	add_child(info_popup)

func _show_info_popup(item: Dictionary) -> void:
	var rarity: String = item.get("rarity", "common")
	var color := GameManager.get_rarity_color(rarity)
	info_name_label.text = item.get("name", "?")
	info_name_label.modulate = color
	info_rarity_label.text = GameManager.get_rarity_label(rarity).to_upper()
	info_rarity_label.modulate = color
	var weapon_label: String = GameManager.get_gauntlet_weapon_type_label(item)
	info_stat_label.text = ("%s\n%s" % [weapon_label, _format_stat(item)]) if weapon_label != "" else _format_stat(item)
	info_value_label.text = "Worth %d" % int(item.get("value", 0))
	info_popup.visible = true
	var target := get_local_mouse_position()
	var max_x: float = size.x - info_popup.size.x - 6
	var max_y: float = size.y - info_popup.size.y - 6
	target.x = clamp(target.x, 6, max(6.0, max_x))
	target.y = clamp(target.y, 6, max(6.0, max_y))
	info_popup.position = target

func _build_inspect_popup() -> void:
	inspect_popup = PanelContainer.new()
	inspect_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	inspect_popup.visible = false
	inspect_popup.z_index = 210
	inspect_popup.custom_minimum_size = Vector2(180, 220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	sb.border_color = Color(0.6, 0.6, 0.68, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	inspect_popup.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	inspect_popup.add_child(vb)
	inspect_icon_holder = Control.new()
	inspect_icon_holder.custom_minimum_size = Vector2(0, 120)
	inspect_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(inspect_icon_holder)
	inspect_name_label = Label.new()
	inspect_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_name_label.add_theme_font_size_override("font_size", 15)
	inspect_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(inspect_name_label)
	inspect_rarity_label = Label.new()
	inspect_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_rarity_label.add_theme_font_size_override("font_size", 12)
	vb.add_child(inspect_rarity_label)
	add_child(inspect_popup)

func _show_inspect_popup(item: Dictionary) -> void:
	for c in inspect_icon_holder.get_children():
		c.queue_free()
	var rarity: String = item.get("rarity", "common")
	var color := GameManager.get_rarity_color(rarity)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = color
	icon.custom_minimum_size = Vector2(110, 110)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.offset_left = -55
	icon.offset_right = 55
	icon.offset_top = 4
	icon.offset_bottom = 114
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_icon_holder.add_child(icon)
	inspect_name_label.text = item.get("name", "?")
	inspect_name_label.modulate = color
	inspect_rarity_label.text = GameManager.get_rarity_label(rarity).to_upper()
	inspect_rarity_label.modulate = color
	inspect_popup.visible = true
	var target := (size - inspect_popup.custom_minimum_size) / 2.0
	inspect_popup.position = target

func _on_slot_hover(slot_name: String) -> void:
	var item = GameManager.gauntlet_equipped_items.get(slot_name)
	if item == null:
		return
	_show_tooltip(item, "Right-click for options")

func _slot_node_name(slot_name: String) -> String:
	return slot_name.capitalize() + "Slot"

func refresh() -> void:
	_hide_tooltip()
	title_label.text = "CARRIED LOOT (%d)" % GameManager.carried_loot.size()
	_refresh_doll()
	for c in grid.get_children():
		c.queue_free()
	if GameManager.carried_loot.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing picked up yet."
		lbl.modulate = Color(1, 1, 1, 0.6)
		grid.add_child(lbl)
		return
	for i in range(GameManager.carried_loot.size()):
		grid.add_child(_make_tile(GameManager.carried_loot[i], i))

func _refresh_doll() -> void:
	for slot_name in SLOT_NAMES:
		var btn: Button = slot_buttons[slot_name]
		var item = GameManager.gauntlet_equipped_items.get(slot_name)
		for c in btn.get_children():
			c.queue_free()
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.remove_theme_stylebox_override("focus")
		if item == null:
			btn.text = slot_name.capitalize()
			continue
		btn.text = ""
		var rarity: String = item.get("rarity", "common")
		var rarity_color := GameManager.get_rarity_color(rarity)

		# Rarity-colored border on the slot itself (not just the icon
		# tint) so equipped gear reads at a glance - a Legendary piece
		# should make the square itself look Legendary.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.14, 0.13, 0.95)
		sb.border_color = Color(0, 0, 0, 0) if GameManager.get_gradient_colors(rarity).size() > 0 else rarity_color
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)

		var gradient_border = GameManager.make_gradient_border(rarity)
		if gradient_border != null:
			btn.add_child(gradient_border)
			var slot_bg := ColorRect.new()
			slot_bg.color = Color(0.12, 0.14, 0.13, 0.95)
			slot_bg.anchor_right = 1.0
			slot_bg.anchor_bottom = 1.0
			slot_bg.offset_left = 3
			slot_bg.offset_top = 3
			slot_bg.offset_right = -3
			slot_bg.offset_bottom = -3
			slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(slot_bg)

		var icon = ItemIconScene.instantiate()
		icon.icon_key = item.get("icon_key", "generic")
		icon.icon_color = rarity_color
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)


func _make_tile(item: Dictionary, index: int) -> Control:
	var rarity_color := GameManager.get_rarity_color(item.get("rarity", "common"))
	var box := PanelContainer.new()
	box.set_script(GauntletLootTileScript)
	box.tile_index = index
	box.tile_item = item
	box.custom_minimum_size = Vector2(56, 56)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.mouse_entered.connect(func(): _show_tooltip(item, "Right-click for options"))
	box.mouse_exited.connect(_hide_tooltip)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.16)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	box.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_open_context_menu("carried", index, "", item, event.global_position)
	)
	return box
