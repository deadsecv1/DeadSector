extends Control

# Draws the grid lines and accepts dropped items, repositioning them to
# whichever cell they were dropped on (Tarkov-style free placement).
# Row count is dynamic - it grows with the "stash_grid" Store upgrade.
# Works for both the Stash (source="stash") and the in-run Backpack
# (source="carried") depending on how the owning controller configures it.

const CELL_CARRIED := 54.0
const CELL_STASH := 42.0
const CELL_BACKPACK_STORAGE := 42.0
const COLS_CARRIED := 8
const COLS_STASH := 11

var stash_controller = null  # set by the owning controller; must expose refresh()
var source: String = "stash"

func _cell() -> float:
	if source == "stash":
		return CELL_STASH
	if source == "backpack_storage":
		return CELL_BACKPACK_STORAGE
	return CELL_CARRIED

func _cols() -> int:
	if source == "stash":
		return COLS_STASH
	if source == "backpack_storage":
		return GameManager.BACKPACK_STORAGE_COLS
	return COLS_CARRIED

func _ready() -> void:
	custom_minimum_size = Vector2(_cols() * _cell(), _rows() * _cell())

func recompute_size() -> void:
	custom_minimum_size = Vector2(_cols() * _cell(), _rows() * _cell())
	queue_redraw()

func _rows() -> int:
	if source == "carried":
		return GameManager.get_grid_rows() + int(GameManager.get_upgrade_bonus("backpack_rows"))
	elif source == "stash":
		return GameManager.get_stash_grid_rows()
	elif source == "backpack_storage":
		return GameManager.BACKPACK_STORAGE_ROWS
	return GameManager.get_grid_rows()

func _draw() -> void:
	var rows := _rows()
	var cols := _cols()
	var cell := _cell()
	var grid_color := Color(1, 1, 1, 0.12)
	for x in range(cols + 1):
		draw_line(Vector2(x * cell, 0), Vector2(x * cell, rows * cell), grid_color, 1.0)
	for y in range(rows + 1):
		draw_line(Vector2(0, y * cell), Vector2(cols * cell, y * cell), grid_color, 1.0)

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var data_source: String = data.get("source", "")
	if data_source == source:
		return true
	if data_source == "equip":
		var equip_source: String = data.get("equip_source", "")
		if equip_source == source:
			return true
		# On the Stash screen, doll slots are tagged "stash" but should
		# also be able to drop straight onto the Backpack Storage panel
		# sitting right next to it.
		if source == "backpack_storage" and equip_source == "stash":
			return true
		return false
	# The Backpack grid also accepts drags coming from the Vicinity panel
	# (freshly-searched loot not yet claimed).
	if source == "carried" and data_source == "vicinity":
		return true
	# Stash and Backpack Storage can freely swap items between each other -
	# that's the whole point of stocking the backpack ahead of a raid.
	if source == "stash" and data_source == "backpack_storage":
		return true
	if source == "backpack_storage" and data_source == "stash":
		return true
	return false

func _drop_data(pos: Vector2, data) -> void:
	var index = data.get("index", -1)
	var data_source: String = data.get("source", "")
	var fp := Vector2i(1, 1)
	if data_source == "vicinity" and index >= 0 and index < GameManager.vicinity_items.size():
		fp = GameManager.get_item_footprint(GameManager.vicinity_items[index])
	elif data_source == "equip":
		var equip_slot: String = data.get("equip_slot", "")
		if GameManager.equipped_items.get(equip_slot) != null:
			fp = GameManager.get_item_footprint(GameManager.equipped_items[equip_slot])
	elif data_source == "stash" and index >= 0 and index < GameManager.stash_items.size():
		fp = GameManager.get_item_footprint(GameManager.stash_items[index])
	elif data_source == "carried" and index >= 0 and index < GameManager.carried_loot.size():
		fp = GameManager.get_item_footprint(GameManager.carried_loot[index])
	elif data_source == "backpack_storage" and index >= 0 and index < GameManager.backpack_storage.size():
		fp = GameManager.get_item_footprint(GameManager.backpack_storage[index])
	var gx := int(clamp(floor(pos.x / _cell()), 0, max(_cols() - fp.x, 0)))
	var gy := int(clamp(floor(pos.y / _cell()), 0, max(_rows() - fp.y, 0)))
	if data_source == "vicinity":
		GameManager.vicinity_claim_to_cell(index, gx, gy)
	elif data_source == "equip":
		var equip_slot: String = data.get("equip_slot", "")
		if source == "stash":
			GameManager.unequip_to_stash_cell(equip_slot, gx, gy)
		elif source == "backpack_storage":
			GameManager.unequip_to_backpack_storage_cell(equip_slot, gx, gy)
		else:
			GameManager.unequip_to_carried_cell(equip_slot, gx, gy)
	elif data_source == "stash" and source == "backpack_storage":
		# Moving from the Stash into Backpack Storage.
		if index < 0 or index >= GameManager.stash_items.size():
			return
		var item: Dictionary = GameManager.stash_items[index]
		GameManager.stash_items.remove_at(index)
		item["grid_x"] = gx
		item["grid_y"] = gy
		GameManager.backpack_storage.append(item)
		GameManager.save_game()
	elif data_source == "backpack_storage" and source == "stash":
		# Moving from Backpack Storage back into the Stash.
		if index < 0 or index >= GameManager.backpack_storage.size():
			return
		var item2: Dictionary = GameManager.backpack_storage[index]
		GameManager.backpack_storage.remove_at(index)
		item2["grid_x"] = gx
		item2["grid_y"] = gy
		GameManager.stash_items.append(item2)
		GameManager.save_game()
	elif source == "stash":
		if index < 0 or index >= GameManager.stash_items.size():
			return
		GameManager.move_item_to_cell(index, gx, gy)
	elif source == "backpack_storage":
		GameManager.move_backpack_storage_item_to_cell(index, gx, gy)
	else:
		if index < 0 or index >= GameManager.carried_loot.size():
			return
		GameManager.move_carried_item_to_cell(index, gx, gy)
	if stash_controller != null:
		stash_controller.refresh()
