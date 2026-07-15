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

# Specialized Case sources are "case_medical"/"case_gun"/"case_armor"/
# "case_key" - same small grid for all four, just backed by a different
# storage array (see GameManager's CASE_TYPES/_case_storage()).
static func _is_case_source(s: String) -> bool:
	return s.begins_with("case_")

static func _case_type_of(s: String) -> String:
	return s.substr(5)

func _cell() -> float:
	if source == "stash":
		return CELL_STASH
	if source == "backpack_storage" or _is_case_source(source):
		return CELL_BACKPACK_STORAGE
	return CELL_CARRIED

func _cols() -> int:
	if source == "stash":
		return COLS_STASH
	if source == "backpack_storage":
		return GameManager.BACKPACK_STORAGE_COLS
	if _is_case_source(source):
		return GameManager.CASE_STORAGE_COLS
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
	elif _is_case_source(source):
		return GameManager.CASE_STORAGE_ROWS
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
		# (or an unlocked Case panel) sitting right next to it.
		if (source == "backpack_storage" or _is_case_source(source)) and equip_source == "stash":
			return true
		return false
	# The Backpack grid also accepts drags coming from the Vicinity panel
	# (freshly-searched loot not yet claimed).
	if source == "carried" and data_source == "vicinity":
		return true
	# A Safe Pocket can be dragged out into any of the three main grids -
	# Stash/Backpack Storage on the out-of-raid screen, or the in-raid
	# Backpack - same as an equip slot dragging out, just without a
	# slot-type restriction (Pockets accept any item).
	if data_source == "pocket" and (source == "stash" or source == "backpack_storage" or source == "carried"):
		return true
	# Stash and Backpack Storage can freely swap items between each other -
	# that's the whole point of stocking the backpack ahead of a raid.
	if source == "stash" and data_source == "backpack_storage":
		return true
	if source == "backpack_storage" and data_source == "stash":
		return true
	# Same idea for Stash <-> an unlocked Case - the actual category check
	# (does this item belong in THIS case) happens in GameManager, so a
	# non-matching drop is simply rejected there rather than refused here.
	if source == "stash" and _is_case_source(data_source):
		return true
	if _is_case_source(source) and data_source == "stash":
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
	elif _is_case_source(data_source):
		var case_items: Array = GameManager.get_case_storage(_case_type_of(data_source))
		if index >= 0 and index < case_items.size():
			fp = GameManager.get_item_footprint(case_items[index])
	elif data_source == "pocket":
		var pocket_index_fp: int = int(data.get("pocket_index", -1))
		if pocket_index_fp >= 0 and pocket_index_fp < GameManager.safe_pockets.size() and GameManager.safe_pockets[pocket_index_fp] != null:
			fp = GameManager.get_item_footprint(GameManager.safe_pockets[pocket_index_fp])
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
		elif _is_case_source(source):
			GameManager.unequip_to_case_cell(_case_type_of(source), equip_slot, gx, gy)
		else:
			GameManager.unequip_to_carried_cell(equip_slot, gx, gy)
	elif data_source == "stash" and source == "backpack_storage":
		# Moving from the Stash into Backpack Storage.
		GameManager.move_stash_item_to_backpack_storage_cell(index, gx, gy)
	elif data_source == "backpack_storage" and source == "stash":
		# Moving from Backpack Storage back into the Stash.
		GameManager.move_backpack_storage_item_to_stash_cell(index, gx, gy)
	elif data_source == "stash" and _is_case_source(source):
		# Moving from the Stash into an unlocked Case.
		GameManager.move_stash_item_to_case_cell(_case_type_of(source), index, gx, gy)
	elif _is_case_source(data_source) and source == "stash":
		# Moving from a Case back into the Stash.
		GameManager.move_case_item_to_stash_cell(_case_type_of(data_source), index, gx, gy)
	elif data_source == "pocket":
		var pocket_index: int = int(data.get("pocket_index", -1))
		if source == "stash":
			GameManager.remove_from_pocket_to_stash_cell(pocket_index, gx, gy)
		elif source == "backpack_storage":
			GameManager.remove_from_pocket_to_backpack_storage_cell(pocket_index, gx, gy)
		else:
			GameManager.remove_from_pocket_to_carried_cell(pocket_index, gx, gy)
	elif source == "stash":
		if index < 0 or index >= GameManager.stash_items.size():
			return
		GameManager.move_item_to_cell(index, gx, gy)
	elif source == "backpack_storage":
		GameManager.move_backpack_storage_item_to_cell(index, gx, gy)
	elif _is_case_source(source):
		GameManager.move_case_item_to_cell(_case_type_of(source), index, gx, gy)
	else:
		if index < 0 or index >= GameManager.carried_loot.size():
			return
		GameManager.move_carried_item_to_cell(index, gx, gy)
	if stash_controller != null:
		stash_controller.refresh()
