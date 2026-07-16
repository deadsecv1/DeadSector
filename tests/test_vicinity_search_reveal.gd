extends TestCase

# Regression coverage for a real bug: items only ever landed in
# GameManager.vicinity_items in one batch, added by the CALLER (Chest/
# Corpse/DebrisStash/FloatingBarrel) after ITS OWN search loop finished -
# meaning a "revealed" item shown mid-search in VicinityPanel was a purely
# visual preview with nothing real behind it yet, so clicking it to claim
# early never worked. GameManager.report_search_progress now adds each
# item to vicinity_items itself, the instant its own reveal threshold is
# crossed - these tests check the real array, not just the visual preview.

func before_each_file() -> void:
	GameManager.vicinity_items = []

# before_each_file() only runs ONCE for the whole file, not before each
# test method - every test below starts with its own explicit reset too,
# or they leak vicinity_items into each other exactly the way
# GameManager.gamepad_held_data leaked across test FILES elsewhere in
# this suite (see test_stash_gamepad_navigation.gd).
func test_items_become_claimable_as_their_own_threshold_crosses_not_all_at_once() -> void:
	GameManager.vicinity_items = []
	var items := [
		{"name": "Alpha", "value": 10, "slot": "consumable", "icon_key": "medical", "rarity": "common"},
		{"name": "Bravo", "value": 20, "slot": "consumable", "icon_key": "medical", "rarity": "common"},
		{"name": "Charlie", "value": 30, "slot": "consumable", "icon_key": "medical", "rarity": "common"},
	]
	GameManager.start_search(items, 1.5, Vector2(100, 100))
	assert_eq(GameManager.vicinity_items.size(), 0, "Nothing should be claimable the instant a search starts")

	GameManager.report_search_progress(0.34)
	assert_eq(GameManager.vicinity_items.size(), 1, "1/3 progress should have revealed exactly the first item")
	assert_eq(GameManager.vicinity_items[0].get("name", ""), "Alpha", "The first revealed item should be Alpha, in order")

	GameManager.report_search_progress(0.67)
	assert_eq(GameManager.vicinity_items.size(), 2, "2/3 progress should reveal the second item too")
	assert_eq(GameManager.vicinity_items[1].get("name", ""), "Bravo")

	# Not yet fully done - Charlie should still be locked.
	assert_eq(GameManager.vicinity_items.size(), 2, "The third item should not be claimable before its own threshold crosses")

	GameManager.report_search_progress(1.0)
	assert_eq(GameManager.vicinity_items.size(), 3, "Full progress should reveal the last item")
	assert_eq(GameManager.vicinity_items[2].get("name", ""), "Charlie")

	GameManager.finish_search()

func test_finish_search_sweeps_up_anything_float_rounding_missed() -> void:
	GameManager.vicinity_items = []
	var items := [
		{"name": "Solo", "value": 10, "slot": "consumable", "icon_key": "medical", "rarity": "common"},
	]
	GameManager.start_search(items, 1.0, Vector2.ZERO)
	# A realistic near-miss - a caller's last progress tick landing at
	# 0.999... instead of exactly 1.0 due to float accumulation.
	GameManager.report_search_progress(0.999)
	assert_eq(GameManager.vicinity_items.size(), 0, "0.999 progress on a single item should not yet cross its threshold")
	GameManager.finish_search()
	assert_eq(GameManager.vicinity_items.size(), 1, "finish_search() should reveal anything still left over, regardless of the last reported progress")

func test_start_search_without_a_position_does_not_error() -> void:
	GameManager.vicinity_items = []
	# source_position is optional - UnstableRift.gd and similar direct
	# add_to_vicinity() callers never go through the search flow at all,
	# but nothing should require every caller to supply a position.
	GameManager.start_search([{"name": "NoPos", "value": 5, "slot": "consumable", "icon_key": "medical", "rarity": "common"}], 1.0)
	GameManager.report_search_progress(1.0)
	assert_eq(GameManager.vicinity_items.size(), 1, "Revealing should still work with no source_position supplied")
	GameManager.finish_search()

func test_vicinity_panel_search_tiles_use_the_same_cell_size_as_the_real_tiles() -> void:
	# The actual bug report: loot visibly shrank once a search finished,
	# because VicinityPanel had its own separately-hardcoded CELL (66.0)
	# instead of matching InventoryTile's real cell size for "vicinity".
	# VicinityPanel.gd isn't its own standalone scene - it's a VBoxContainer
	# nested inside HUD.tscn (InventoryPanel/VBox/Panels/VicinityPanel).
	GameManager.vicinity_items = []
	var InventoryTileScript = load("res://scripts/InventoryTile.gd")
	var hud = load("res://scenes/HUD.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var panel = hud.get_node("InventoryPanel/VBox/Panels/VicinityPanel")

	var items := [{"name": "Sized", "value": 10, "slot": "consumable", "icon_key": "medical", "rarity": "common"}]
	GameManager.start_search(items, 1.0, Vector2.ZERO)
	GameManager.report_search_progress(1.0)
	await get_tree().process_frame

	var revealed_tile = panel.tiles_area.get_child(0)
	assert_eq(revealed_tile.custom_minimum_size.x, InventoryTileScript.CELL_CARRIED - 2, "A revealed tile mid-search should be sized exactly like a real InventoryTile, not a separately-hardcoded constant")

	GameManager.finish_search()
	remove_child(hud)
	hud.queue_free()
