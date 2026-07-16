extends TestCase

# End-to-end regression test for gamepad navigation actually wired into
# the real Stash screen (not the isolated FakeSlot double in
# test_gamepad_ui_navigation.gd) - opening the screen grabs initial
# focus, and a real inventory tile can be picked up and placed onto a
# real equip slot via GameManager.try_gamepad_pickup_or_place(), the
# same path a controller's Accept button drives through Stash.gd's
# _gui_input() hooks.

const StashScene := preload("res://scenes/Stash.tscn")

func before_each_file() -> void:
	# Defensive: GameManager.gamepad_held_data/held_source is shared
	# singleton state, so a test in another file that intentionally leaves
	# a hold dangling (see test_gamepad_ui_navigation.gd's rejecting-slot
	# test) would otherwise bleed into every test below and make the
	# _can_drop_data() checks here fail for reasons that have nothing to
	# do with Stash/EquipSlot/GameManager.equip_item() themselves.
	GameManager.cancel_gamepad_hold()

func test_opening_stash_grabs_initial_focus() -> void:
	GameManager.stash_items = []
	var stash = StashScene.instantiate()
	add_child(stash)
	await get_tree().process_frame
	var focused := get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Opening Stash should grab focus on something so gamepad navigation has a starting point")
	remove_child(stash)
	stash.queue_free()

func test_picking_up_a_stash_item_and_placing_it_on_an_equip_slot_actually_equips_it() -> void:
	# Both of these are live GameManager singleton state, not test-local -
	# restore whatever was really there when the test is done rather than
	# permanently leaving this fake fixture in place for the rest of the
	# process (see test_gear_display.gd's before_each_file for the same
	# risk class with equipped_skins).
	var original_weapon = GameManager.equipped_items.get("weapon")
	var original_stash_items: Array = GameManager.stash_items
	GameManager.equipped_items["weapon"] = null
	GameManager.stash_items = [
		{"name": "Test Rifle", "value": 100, "slot": "weapon", "icon_key": "rifle", "rarity": "common"},
	]
	var stash = StashScene.instantiate()
	add_child(stash)
	await get_tree().process_frame

	var tile = stash.inventory_grid.get_child(0)
	assert_not_null(tile, "Stash should have built a tile for the one stash item")

	var picked_up: bool = GameManager.try_gamepad_pickup_or_place(tile)
	assert_true(picked_up, "Picking up a real Stash tile via the gamepad path should succeed")
	assert_not_null(GameManager.gamepad_held_data, "Something should now be held")

	var weapon_slot = stash.slot_buttons["weapon"]
	var placed: bool = GameManager.try_gamepad_pickup_or_place(weapon_slot)
	assert_true(placed, "Placing the held weapon onto the weapon EquipSlot should succeed")
	assert_null(GameManager.gamepad_held_data, "Nothing should be held any more after a successful place")
	assert_not_null(GameManager.equipped_items.get("weapon"), "The weapon should now actually be equipped, not just visually moved")
	assert_eq(GameManager.equipped_items["weapon"].get("name", ""), "Test Rifle", "The equipped weapon should be the exact one that was picked up")

	remove_child(stash)
	stash.queue_free()
	GameManager.equipped_items["weapon"] = original_weapon
	GameManager.stash_items = original_stash_items

func test_refresh_while_holding_cancels_the_hold_instead_of_leaving_a_dangling_reference() -> void:
	GameManager.stash_items = [
		{"name": "Test Pistol", "value": 50, "slot": "weapon", "icon_key": "pistol", "rarity": "common"},
	]
	var stash = StashScene.instantiate()
	add_child(stash)
	await get_tree().process_frame

	var tile = stash.inventory_grid.get_child(0)
	GameManager.try_gamepad_pickup_or_place(tile)
	assert_not_null(GameManager.gamepad_held_data, "Should be holding the pistol now")

	stash.refresh() # rebuilds every tile, freeing the one we picked up from
	assert_null(GameManager.gamepad_held_data, "refresh() should have canceled the hold rather than leaving gamepad_held_source pointing at a freed tile")
	assert_null(GameManager.gamepad_held_source)

	remove_child(stash)
	stash.queue_free()
