extends Control

# The "Vicinity" panel: a completely separate area from the Backpack that
# shows what you're currently searching. Instead of a moving progress
# bar, the items you're about to find show up immediately as locked
# tiles and reveal one by one as the search progresses - Tarkov style.
# Once finished, they become real tiles the player can drag into the
# Backpack, drag onto a matching Equip slot, or click to send straight
# to the Backpack.

const InventoryTileScene := preload("res://scenes/InventoryTile.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const CELL := 66.0

signal item_context_menu_requested(index: int, source: String, item: Dictionary, at_position: Vector2)

@onready var status_label: Label = $StatusLabel
@onready var scroll: ScrollContainer = $Scroll
@onready var tiles_area: Control = $Scroll/TilesArea
@onready var take_all_prompt: Label = $TakeAllPrompt

var f_was_down: bool = false
var searching_items: Array = []
var revealed_count: int = 0

func _ready() -> void:
	take_all_prompt.visible = false
	GameManager.search_started.connect(_on_search_started)
	GameManager.search_progress.connect(_on_search_progress)
	GameManager.search_finished.connect(_on_search_finished)
	GameManager.vicinity_changed.connect(refresh)
	refresh()
	# Lets a gamepad player drop a held carried/equipped item back into
	# Vicinity (see GameManager.try_gamepad_pickup_or_place), same as
	# dragging it out with a mouse - individual found-item tiles are their
	# own pickup targets already (InventoryTile), this is just what makes
	# the panel itself a valid PLACE target too.
	focus_mode = Control.FOCUS_ALL

func _gui_input(event: InputEvent) -> void:
	if GameManager.handle_gamepad_slot_input(event, self):
		accept_event()

func _process(_delta: float) -> void:
	var f_down := GameManager.is_action_pressed("interact")
	if f_down and not f_was_down and take_all_prompt.visible and is_visible_in_tree() and GameManager.inventory_tab_open:
		GameManager.vicinity_take_all()
	f_was_down = f_down

func _on_search_started(items: Array, _duration: float) -> void:
	searching_items = items
	revealed_count = 0
	status_label.text = "Searching..."
	_draw_search_tiles()

func _on_search_progress(pct: float) -> void:
	if searching_items.is_empty():
		return
	var should_be_revealed: int = int(floor(pct * searching_items.size()))
	if should_be_revealed > revealed_count:
		revealed_count = should_be_revealed
		_draw_search_tiles()

func _on_search_finished() -> void:
	searching_items = []
	revealed_count = 0
	status_label.text = "Found something - drag it out or click to stow."
	refresh()

func _draw_search_tiles() -> void:
	GameManager.cancel_gamepad_hold_if_within(tiles_area)
	for c in tiles_area.get_children():
		c.queue_free()
	if searching_items.is_empty():
		tiles_area.custom_minimum_size = Vector2(0, 0)
		return
	tiles_area.custom_minimum_size = Vector2(searching_items.size() * CELL, CELL - 4)
	for i in range(searching_items.size()):
		var slot := Panel.new()
		slot.position = Vector2(i * CELL + 2, 2)
		slot.custom_minimum_size = Vector2(CELL - 4, CELL - 4)
		slot.size = Vector2(CELL - 4, CELL - 4)
		var sb := StyleBoxFlat.new()
		var revealed: bool = i < revealed_count
		var item: Dictionary = searching_items[i]
		sb.bg_color = GameManager.get_rarity_color(item.get("rarity", "common")).darkened(0.6) if revealed else Color(0.1, 0.1, 0.1, 0.9)
		sb.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", sb)
		tiles_area.add_child(slot)
		if revealed:
			var icon = ItemIconScene.instantiate()
			icon.icon_key = item.get("icon_key", "generic")
			icon.icon_color = GameManager.get_display_color(item)
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			icon.offset_left = 3
			icon.offset_top = 3
			icon.offset_right = -3
			icon.offset_bottom = -3
			slot.add_child(icon)
		else:
			var q := Label.new()
			q.text = "?"
			q.anchor_right = 1.0
			q.anchor_bottom = 1.0
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.add_theme_font_size_override("font_size", 22)
			q.modulate = Color(1, 1, 1, 0.3)
			slot.add_child(q)

func refresh() -> void:
	if GameManager.is_searching:
		return
	GameManager.cancel_gamepad_hold_if_within(tiles_area)
	for c in tiles_area.get_children():
		c.queue_free()

	if GameManager.vicinity_items.is_empty():
		tiles_area.custom_minimum_size = Vector2(0, 0)
		take_all_prompt.visible = false
		status_label.text = "Nothing found yet. Search a container or body."
		return

	take_all_prompt.visible = true
	tiles_area.custom_minimum_size = Vector2(GameManager.vicinity_items.size() * CELL, CELL - 4)
	for i in range(GameManager.vicinity_items.size()):
		var item: Dictionary = GameManager.vicinity_items[i]
		var tile = InventoryTileScene.instantiate()
		tiles_area.add_child(tile)
		tile.setup(i, item, "vicinity")
		tile.vicinity_claim_requested.connect(_on_claim)
		tile.context_menu_requested.connect(func(idx, src, it, pos): item_context_menu_requested.emit(idx, src, it, pos))

func _on_claim(index: int) -> void:
	GameManager.vicinity_claim_to_next_free(index)

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var data_source: String = data.get("source", "")
	if data_source == "carried":
		return true
	if data_source == "equip":
		return data.get("equip_source", "") == "carried"
	return false

func _drop_data(_pos: Vector2, data) -> void:
	var data_source: String = data.get("source", "")
	var player = get_tree().get_first_node_in_group("player")
	var drop_pos: Vector2 = player.global_position if player != null else Vector2.ZERO
	if data_source == "carried":
		GameManager.drop_carried_to_vicinity(int(data.get("index", -1)), drop_pos)
	elif data_source == "equip":
		GameManager.drop_equipped_to_vicinity(str(data.get("equip_slot", "")), drop_pos)
	refresh()
