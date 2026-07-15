extends Button

# A Safe Pocket slot: unlike normal Equip slots, ANY item can go here - no
# slot-type restriction - and whatever's inside survives to your Stash
# even if you die with everything else in your Backpack lost.

signal dropped

@export var pocket_index: int = 0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
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
		var rarity_color: Color = GameManager.get_rarity_color(item.get("rarity", "common"))
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

func _on_pressed() -> void:
	if GameManager.safe_pockets[pocket_index] != null:
		GameManager.remove_from_pocket(pocket_index)
		dropped.emit()

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
