extends TestCase

# Regression coverage (2026-07-17 audit) for the same stale-index bug class
# fixed in WeaponInspectionPanel.gd (see test_weapon_inspection.gd) -
# WeaponAttachmentsPanel.gd (the in-raid HUD's simpler list-style
# Attachments panel, HUD.gd's attachments_panel) had the identical
# weapon_index-based tracking with no "still a weapon" check at all, so a
# reorder while the panel was open could silently redirect Install/Remove
# onto a completely different item - even a non-weapon one, since this
# panel (unlike WeaponInspectionPanel) never guarded on slot=="weapon".
# Fixed the same way: track the weapon by object reference (_weapon_ref),
# re-resolved by identity (is_same()) plus a slot=="weapon" check in
# _get_weapon() every time.

const HUDScene := preload("res://scenes/HUD.tscn")

func test_reorder_does_not_switch_the_panel_to_a_different_item() -> void:
	GameManager.carried_loot = [
		{"name": "Weapon A", "value": 100, "slot": "weapon", "icon_key": "rifle", "rarity": "common"},
		{"name": "Bandages", "value": 5, "slot": "consumable", "icon_key": "bandage", "rarity": "common"},
	]
	var hud = HUDScene.instantiate()
	add_child(hud)
	var panel = hud.attachments_panel
	panel.open_for(0, "carried")
	assert_eq(panel.weapon_label.text, "Weapon: Weapon A", "Panel should open on Weapon A")

	# Simulate a reorder that shifts the Bandages stack into index 0 -
	# the panel's originally-captured index now points at a non-weapon
	# item entirely.
	var a = GameManager.carried_loot.pop_front()
	GameManager.carried_loot.append(a)
	assert_eq(GameManager.carried_loot[0].get("name"), "Bandages", "test setup: Bandages should now sit at index 0")

	panel.refresh()
	assert_eq(panel.weapon_label.text, "Weapon: Weapon A", "Panel must keep tracking the original weapon by identity, not whatever now sits at the old index")
	assert_false(GameManager.carried_loot[0].has("attachments"), "The non-weapon item that shifted into the old index must never get an attachments dict grafted onto it")

	remove_child(hud)
	hud.queue_free()
	GameManager.carried_loot = []

func test_item_removed_entirely_shows_not_found() -> void:
	GameManager.carried_loot = [
		{"name": "Weapon A", "value": 100, "slot": "weapon", "icon_key": "rifle", "rarity": "common"},
	]
	var hud = HUDScene.instantiate()
	add_child(hud)
	var panel = hud.attachments_panel
	panel.open_for(0, "carried")
	assert_eq(panel.weapon_label.text, "Weapon: Weapon A")

	GameManager.carried_loot.clear()
	panel.refresh()
	assert_eq(panel.weapon_label.text, "Weapon not found - it may have moved.")

	remove_child(hud)
	hud.queue_free()
	GameManager.carried_loot = []
