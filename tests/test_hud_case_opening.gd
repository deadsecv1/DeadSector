extends TestCase

# Regression coverage (2026-07-17, follow-up to the full-codebase audit) -
# specialized cases (Medical/Gun/Armor/Key) found mid-raid showed a real
# "Open" button (ItemContextMenu.gd shows it for is_specialized_case
# regardless of context), but HUD.gd's open_bag_requested handler always
# forwarded to OpenLootBagPanel, which only understands plain Loot Bags and
# silently rejects anything else ("Nothing happened...") - a case found
# mid-raid could never actually be opened until extracting to the Stash,
# even though the button was visibly offered. Fixed by giving HUD.gd the
# same specialized-case branch Stash.gd's own handler already has, plus a
# CasePanel instance added to HUD.tscn to show the result (previously
# in-raid had no CasePanel node at all).

const HUDScene := preload("res://scenes/HUD.tscn")

func test_opening_a_specialized_case_in_raid_unlocks_it_and_shows_the_case_panel() -> void:
	var unlocked_before: Dictionary = GameManager.unlocked_cases.duplicate(true)
	var carried_before: Array = GameManager.carried_loot.duplicate(true)
	GameManager.unlocked_cases["medical"] = false
	GameManager.carried_loot = [
		{"name": "Medical Case", "value": 0, "slot": "medical_case", "rarity": "legendary"},
	]

	var hud = HUDScene.instantiate()
	add_child(hud)

	hud.item_context_menu.open_bag_requested.emit(0, "carried", GameManager.carried_loot[0])

	assert_true(GameManager.unlocked_cases.get("medical", false), "opening a Medical Case in-raid should unlock it, same as opening one from the Stash")
	assert_true(GameManager.carried_loot.is_empty(), "the sealed case item should be consumed")
	assert_true(hud.case_panel.visible, "the CasePanel should open to show the result, same as Stash.gd's own handler does")
	assert_eq(hud.case_panel.case_type, "medical")

	GameManager.unlocked_cases = unlocked_before
	GameManager.carried_loot = carried_before
	remove_child(hud)
	hud.queue_free()

func test_plain_loot_bag_still_routes_to_open_loot_bag_panel() -> void:
	var carried_before: Array = GameManager.carried_loot.duplicate(true)
	var bag := {"name": "Loot Bag", "value": 50, "slot": "lootbag", "bag_tier": "common", "rarity": "common"}
	GameManager.carried_loot = [bag]

	var hud = HUDScene.instantiate()
	add_child(hud)

	hud.item_context_menu.open_bag_requested.emit(0, "carried", bag)

	assert_true(hud.open_bag_panel.visible, "a plain Loot Bag should still open OpenLootBagPanel, not CasePanel")
	assert_false(hud.case_panel.visible)

	GameManager.carried_loot = carried_before
	remove_child(hud)
	hud.queue_free()
