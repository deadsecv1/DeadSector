extends TestCase

# Regression coverage (2026-07-17 audit) for a stale-index bug:
# OpenLootBagPanel.gd is a floating (non-modal) popup, so the Stash's Sort
# and other stash_items-reordering actions stay clickable behind it.
# bag_index/bag_source used to be captured once at open_for() time and
# trusted as-is when Open was clicked - if a DIFFERENT loot bag shifted
# into that exact index in the meantime, the stale index would silently
# open and consume the wrong bag. Fixed by re-resolving the bag's current
# index by object identity (is_same() against the bag_item reference
# captured at open) right before actually opening it.

const StashScene := preload("res://scenes/Stash.tscn")

func test_reorder_does_not_open_a_different_bag() -> void:
	var bag_a := {"name": "Bag A", "value": 50, "slot": "lootbag", "bag_tier": "common", "rarity": "common"}
	var bag_b := {"name": "Bag B", "value": 90, "slot": "lootbag", "bag_tier": "rare", "rarity": "rare"}
	GameManager.stash_items = [bag_a, bag_b]
	var stash = StashScene.instantiate()
	add_child(stash)
	var panel = stash.open_bag_panel
	panel.open_for(0, "stash", bag_a)

	# Simulate a reorder that shifts Bag B into index 0 before Open is
	# actually clicked - the panel's originally-captured index now points
	# at a completely different real loot bag.
	var a = GameManager.stash_items.pop_front()
	GameManager.stash_items.append(a)
	assert_eq(GameManager.stash_items[0].get("name"), "Bag B", "test setup: Bag B should now sit at index 0")

	panel._on_open()

	# Opening a bag also deposits its rolled contents into stash_items, so
	# the array grows - check identity/presence instead of exact size.
	var still_has_bag_a := false
	var still_has_bag_b := false
	for it in GameManager.stash_items:
		if is_same(it, bag_a):
			still_has_bag_a = true
		if is_same(it, bag_b):
			still_has_bag_b = true
	assert_false(still_has_bag_a, "Bag A (the one actually opened) should be gone")
	assert_true(still_has_bag_b, "Bag B must still be untouched in the Stash")

	remove_child(stash)
	stash.queue_free()
	GameManager.stash_items = []

func test_bag_removed_entirely_shows_nothing_happened() -> void:
	var bag_a := {"name": "Bag A", "value": 50, "slot": "lootbag", "bag_tier": "common", "rarity": "common"}
	GameManager.stash_items = [bag_a]
	var stash = StashScene.instantiate()
	add_child(stash)
	var panel = stash.open_bag_panel
	panel.open_for(0, "stash", bag_a)

	GameManager.stash_items.clear()
	panel._on_open()

	assert_eq(panel.status_label.text, "Nothing happened...")

	remove_child(stash)
	stash.queue_free()
	GameManager.stash_items = []
