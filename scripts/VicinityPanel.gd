extends Control

# The "Vicinity" panel: a completely separate area from the Backpack that
# shows what you're currently searching. Instead of a moving progress
# bar, the items you're about to find show up immediately as locked
# tiles and reveal one by one as the search progresses - Tarkov style.
# Once finished, they become real tiles the player can drag into the
# Backpack, drag onto a matching Equip slot, or click to send straight
# to the Backpack.

const InventoryTileScene := preload("res://scenes/InventoryTile.tscn")
# Referencing InventoryTile's own cell size directly instead of a second,
# separately-maintained constant - the "loot looks smaller once searching
# finishes" bug was exactly this: CELL used to be a hardcoded 66.0 here,
# while the real tiles InventoryTile.gd builds for "vicinity" render at
# CELL_CARRIED (54.0), a mismatch nobody had a reason to notice since the
# two never used to appear on screen at the same time.
const InventoryTileScript := preload("res://scripts/InventoryTile.gd")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

signal item_context_menu_requested(index: int, source: String, item: Dictionary, at_position: Vector2)

@onready var status_label: Label = $StatusLabel
@onready var scroll: ScrollContainer = $Scroll
@onready var tiles_area: Control = $Scroll/TilesArea
@onready var take_all_prompt: Label = $TakeAllPrompt

var f_was_down: bool = false
var searching_items: Array = []
var revealed_count: int = 0
var _last_search_pct: float = 0.0
var _searching_label: Label = null
var _searching_fill: ColorRect = null

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
	_animate_searching_slot()

# A smooth per-frame pulse/fill on whatever's currently being searched,
# computed fresh from absolute time and the latest known progress rather
# than from a Tween - _draw_search_tiles() rebuilds this slot's Control
# from scratch on every progress tick (~10/sec), which would otherwise
# reset any Tween-driven animation state right as it started.
func _animate_searching_slot() -> void:
	if _searching_label == null or not is_instance_valid(_searching_label):
		return
	var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	_searching_label.modulate.a = pulse
	_searching_label.scale = Vector2.ONE * (0.92 + pulse * 0.12)
	if searching_items.is_empty():
		return
	var local_progress: float = clamp(_last_search_pct * searching_items.size() - revealed_count, 0.0, 1.0)
	if _searching_fill != null and is_instance_valid(_searching_fill):
		var parent_width: float = _searching_fill.get_parent().size.x
		_searching_fill.size = Vector2(parent_width * local_progress, _searching_fill.size.y)

func _on_search_started(items: Array, _duration: float) -> void:
	searching_items = items
	revealed_count = 0
	_last_search_pct = 0.0
	status_label.text = "Searching..."
	_draw_search_tiles()

func _on_search_progress(pct: float) -> void:
	_last_search_pct = pct
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

# Renders every item already claimable in GameManager.vicinity_items as a
# real, fully interactive InventoryTile - the SAME array a completed
# search's items are added to as each one's reveal threshold crosses (see
# GameManager.report_search_progress) - so a found item is click-to-stow
# or drag-to-equip immediately, not just once the whole search finishes.
# Any leftover still-locked items from the CURRENT search get placeholder
# slots appended after them, with the very next one to reveal animated
# (see _animate_searching_slot) instead of sitting there looking inert.
func _draw_search_tiles() -> void:
	GameManager.cancel_gamepad_hold_if_within(tiles_area)
	for c in tiles_area.get_children():
		c.queue_free()
	_searching_label = null
	_searching_fill = null

	var cell: float = InventoryTileScript.CELL_CARRIED
	var real_count: int = GameManager.vicinity_items.size()
	var locked_count: int = max(searching_items.size() - revealed_count, 0)
	if real_count + locked_count == 0:
		tiles_area.custom_minimum_size = Vector2(0, 0)
		return
	tiles_area.custom_minimum_size = Vector2((real_count + locked_count) * cell, cell - 4)

	for i in range(real_count):
		var item: Dictionary = GameManager.vicinity_items[i]
		var tile = InventoryTileScene.instantiate()
		tiles_area.add_child(tile)
		tile.setup(i, item, "vicinity")
		tile.position = Vector2(i * cell + 2, 2)
		tile.vicinity_claim_requested.connect(_on_claim)
		tile.context_menu_requested.connect(func(idx, src, it, pos): item_context_menu_requested.emit(idx, src, it, pos))

	for j in range(locked_count):
		var slot := Panel.new()
		slot.position = Vector2((real_count + j) * cell + 2, 2)
		slot.custom_minimum_size = Vector2(cell - 4, cell - 4)
		slot.size = Vector2(cell - 4, cell - 4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		sb.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", sb)
		tiles_area.add_child(slot)
		var q := Label.new()
		q.text = "?"
		q.anchor_right = 1.0
		q.anchor_bottom = 1.0
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 22)
		q.modulate = Color(1, 1, 1, 0.3)
		q.pivot_offset = (cell - 4) * 0.5 * Vector2.ONE
		slot.add_child(q)
		if j == 0:
			var fill := ColorRect.new()
			fill.color = Color(0.5, 0.85, 1.0, 0.35)
			fill.position = Vector2(0, cell - 8)
			fill.size = Vector2(0, 4)
			slot.add_child(fill)
			_searching_label = q
			_searching_fill = fill

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
	var cell: float = InventoryTileScript.CELL_CARRIED
	tiles_area.custom_minimum_size = Vector2(GameManager.vicinity_items.size() * cell, cell - 4)
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
