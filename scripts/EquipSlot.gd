extends Button

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

# One equipment slot on a character panel (Head/Body/Weapon/Accessory/
# Boots/Backpack). Accepts a dragged inventory tile if its slot type
# matches. Works with both the out-of-run Stash and the in-run Backpack,
# depending on how "source" is configured by the owning controller.
#
# Left-click (the normal "pressed" signal) is reserved for showing item
# info, since that's also what a click on any other item tile does now -
# unequipping happens via right-click or by dragging the item back out,
# not by a plain click, so a click never accidentally strips your gear.

@export var slot_name: String = "head"

var source: String = "stash"
var current_item = null  # Dictionary when occupied, else null; set by the controller

signal dropped
signal context_menu_requested(slot_name: String, item: Dictionary, at_position: Vector2)

func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)

var _hovered: bool = false
var _wiggle_time: float = 0.0

func _on_hover_enter() -> void:
	if current_item == null:
		return
	_hovered = true
	_wiggle_time = 0.0
	set_process(true)

func _on_hover_exit() -> void:
	_hovered = false
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "rotation", 0.0, 0.12)

func _process(delta: float) -> void:
	if not _hovered:
		return
	_wiggle_time += delta * 9.0
	rotation = sin(_wiggle_time) * 0.04

var _last_click_time_ms: int = -999999
const DOUBLE_CLICK_WINDOW_MS := 400
var _did_drag: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		if current_item != null:
			context_menu_requested.emit(slot_name, current_item, get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_did_drag = false
		elif not _did_drag and current_item != null:
			# _get_drag_data() below already catches a double-click whose
			# second press has enough motion for Godot to call it at all -
			# same story as InventoryTile.gd's equip side: a genuinely
			# still double-click (no drift on either press) never triggers
			# _get_drag_data(), so both releases land here via _gui_input()
			# instead, and without checking here too, a steady double-click
			# just never registered as one at all.
			var now_ms := Time.get_ticks_msec()
			var is_double_click: bool = (now_ms - _last_click_time_ms) < DOUBLE_CLICK_WINDOW_MS
			_last_click_time_ms = now_ms
			if is_double_click:
				_last_click_time_ms = -999999
				accept_event()
				if source == "stash":
					GameManager.unequip_item(slot_name)
				else:
					GameManager.unequip_to_carried(slot_name)
				dropped.emit()
			else:
				# A single left-click was never actually implemented despite
				# the class comment above promising it shows item info, same
				# as any other tile - same disambiguation-by-timer as
				# InventoryTile.gd's _handle_click_release: wait out the
				# double-click window before popping anything up, so a real
				# double-click's first release doesn't show a popup right as
				# (or after) the unequip above already happened.
				var my_stamp := now_ms
				var click_pos := get_global_mouse_position()
				get_tree().create_timer(DOUBLE_CLICK_WINDOW_MS / 1000.0).timeout.connect(func():
					if not is_instance_valid(self) or _last_click_time_ms != my_stamp:
						return
					_show_click_popup(click_pos)
				)

func _show_click_popup(at_position: Vector2) -> void:
	if current_item == null:
		return
	var popup := PopupPanel.new()
	popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	get_tree().current_scene.add_child(popup)
	var content := ItemTooltip.build(current_item)
	popup.add_child(content)
	popup.position = Vector2i(at_position) + Vector2i(16, 16)
	popup.popup()

	var fallback_timer := get_tree().create_timer(6.0)
	var fallback_close := func():
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
	fallback_timer.timeout.connect(fallback_close)

	mouse_exited.connect(func():
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
		if is_instance_valid(fallback_timer) and fallback_timer.timeout.is_connected(fallback_close):
			fallback_timer.timeout.disconnect(fallback_close)
	, CONNECT_ONE_SHOT)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_item == null:
		return null
	# Double-click-to-unequip detection lives here rather than on
	# mouse-release, same reasoning as InventoryTile.gd - Godot calls
	# _get_drag_data() on essentially any motion during a press, so a
	# fast double-click's second click needs to be caught here to be
	# reliable. A genuine single-press drag always still returns valid
	# data below - only a confirmed double-click returns null, and only
	# after unequipping is already done (which just triggered a doll
	# refresh that may have invalidated this exact slot's state, so
	# there's nothing safe left to build a drag preview from anyway).
	var now_ms := Time.get_ticks_msec()
	var is_double_click: bool = (now_ms - _last_click_time_ms) < DOUBLE_CLICK_WINDOW_MS
	_last_click_time_ms = now_ms
	if is_double_click:
		_last_click_time_ms = -999999
		if source == "stash":
			GameManager.unequip_item(slot_name)
		else:
			GameManager.unequip_to_carried(slot_name)
		dropped.emit()
		return null

	_did_drag = true
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(48, 48)
	preview.modulate.a = 0.9
	var rarity_color: Color = GameManager.get_rarity_color(current_item.get("rarity", "common"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", sb)
	var item_icon = ItemIconScene.instantiate()
	item_icon.icon_key = current_item.get("icon_key", "generic")
	item_icon.icon_color = rarity_color
	preview.add_child(item_icon)
	preview.position = -preview.custom_minimum_size / 2.0
	set_drag_preview(preview)
	return {"source": "equip", "equip_slot": slot_name, "equip_source": source}

func _make_custom_tooltip(_for_text: String) -> Control:
	if current_item == null:
		return null
	return ItemTooltip.build(current_item)

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var data_source: String = data.get("source", "")
	var index = data.get("index", -1)
	if data_source == source:
		var items: Array = GameManager.stash_items if source == "stash" else GameManager.carried_loot
		if index < 0 or index >= items.size():
			return false
		return items[index].get("slot", "") == slot_name
	if source == "carried" and data_source == "vicinity":
		if index < 0 or index >= GameManager.vicinity_items.size():
			return false
		return GameManager.vicinity_items[index].get("slot", "") == slot_name
	return false

func _drop_data(_pos: Vector2, data) -> void:
	var index = data.get("index", -1)
	var data_source: String = data.get("source", "")
	if data_source == "vicinity":
		GameManager.vicinity_equip(index)
	elif source == "stash":
		GameManager.equip_item(index)
	else:
		GameManager.equip_from_carried(index)
	dropped.emit()
