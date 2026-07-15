extends Button

# A Safe Pocket slot: unlike normal Equip slots, ANY item can go here - no
# slot-type restriction - and whatever's inside survives to your Stash
# even if you die with everything else in your Backpack lost.

signal dropped

@export var pocket_index: int = 0
# Which grid an emptied pocket should return its item to when clicked -
# "carried" for the in-raid HUD (the original/default behavior), "stash"
# for the out-of-raid Stash screen, which has no meaningful use for
# carried_loot at all outside a raid.
@export var context_source: String = "carried"

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	GameManager.pockets_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var item = GameManager.safe_pockets[pocket_index] if pocket_index < GameManager.safe_pockets.size() else null
	for child in get_children():
		child.queue_free()
	if item == null:
		text = "Empty"
		tooltip_text = "Safe Pocket - drag any item here. It survives even if you die."
		remove_theme_stylebox_override("normal")
	else:
		text = ""
		tooltip_text = "%s\nSafe - protected even on death." % item.get("name", "?")
		var rarity_color: Color = GameManager.get_display_color(item)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.16, 0.1, 0.95)
		sb.border_color = Color(0.5, 0.95, 0.6, 1)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(4)
		add_theme_stylebox_override("normal", sb)
		add_theme_stylebox_override("hover", sb)
		add_theme_stylebox_override("pressed", sb)

		var icon_scene := preload("res://scenes/ItemIcon.tscn")
		var item_icon = icon_scene.instantiate()
		item_icon.icon_key = item.get("icon_key", "generic")
		item_icon.icon_color = rarity_color
		item_icon.anchor_right = 1.0
		item_icon.anchor_bottom = 1.0
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(item_icon)

# Emptying a filled pocket now needs a DOUBLE click (single click used to
# empty it instantly, which was too easy to trigger by accident given a
# pocket's whole purpose is protecting an item you don't want to lose) -
# matching the double-click-to-equip convention InventoryTile.gd/EquipSlot.gd
# already use elsewhere. Detection is split across two functions for the
# same reason it is there: Godot calls _get_drag_data() below on a double-
# click whose second press has any drift, so only a genuinely STILL
# double-click (no drift on either press) ever needs to be caught here.
const DOUBLE_CLICK_WINDOW_MS := 400
var _last_click_time_ms: int = -999999
var _did_drag: bool = false

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_did_drag = false
		return
	if _did_drag or GameManager.safe_pockets[pocket_index] == null:
		return
	var now_ms := Time.get_ticks_msec()
	var is_double_click: bool = (now_ms - _last_click_time_ms) < DOUBLE_CLICK_WINDOW_MS
	_last_click_time_ms = now_ms
	if is_double_click:
		_last_click_time_ms = -999999
		accept_event()
		GameManager.remove_from_pocket(pocket_index, context_source)
		dropped.emit()

# Drag-out: lets a filled pocket be dragged onto the Stash/Backpack Storage
# grids (or the in-raid Backpack) same as any other item, landing at the
# exact cell dropped on - see InventoryGrid.gd's "pocket" data_source
# handling. Only a genuine single-press drag reaches the preview/return
# below; a double-click (still or drifted) is caught first and empties the
# pocket immediately instead, same as _gui_input() above.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var item = GameManager.safe_pockets[pocket_index] if pocket_index < GameManager.safe_pockets.size() else null
	if item == null:
		return null
	var now_ms := Time.get_ticks_msec()
	var is_double_click: bool = (now_ms - _last_click_time_ms) < DOUBLE_CLICK_WINDOW_MS
	_last_click_time_ms = now_ms
	if is_double_click:
		_last_click_time_ms = -999999
		GameManager.remove_from_pocket(pocket_index, context_source)
		dropped.emit()
		return null

	_did_drag = true
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(48, 48)
	preview.modulate.a = 0.9
	var rarity_color: Color = GameManager.get_display_color(item)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", sb)
	var icon_scene := preload("res://scenes/ItemIcon.tscn")
	var item_icon = icon_scene.instantiate()
	item_icon.icon_key = item.get("icon_key", "generic")
	item_icon.icon_color = rarity_color
	preview.add_child(item_icon)
	preview.position = -preview.custom_minimum_size / 2.0
	set_drag_preview(preview)
	return {"source": "pocket", "pocket_index": pocket_index}

const ACCEPTED_SOURCES := ["carried", "vicinity", "stash", "backpack_storage"]

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var data_source: String = data.get("source", "")
	return ACCEPTED_SOURCES.has(data_source)

func _drop_data(_pos: Vector2, data) -> void:
	var index = data.get("index", -1)
	var data_source: String = data.get("source", "")
	match data_source:
		"vicinity":
			GameManager.move_vicinity_to_pocket(index, pocket_index)
		"stash":
			GameManager.move_stash_to_pocket(index, pocket_index)
		"backpack_storage":
			GameManager.move_backpack_storage_to_pocket(index, pocket_index)
		_:
			GameManager.move_carried_to_pocket(index, pocket_index)
	dropped.emit()
