extends TestCase

# Regression test for a real currency-loss bug found in this session's own
# audit pass: WeaponInspectionPanel.gd remembered a weapon by (index,
# source) only, so if the source array reordered while the panel was
# open (e.g. Sort), buying an attachment would graft it onto whatever
# unrelated item now sat at that index and still spend real Rubles. Fixed
# by having _get_weapon() refuse anything whose slot isn't "weapon".
# This test reproduces the exact scenario without needing a click.

const StashScene := preload("res://scenes/Stash.tscn")

func test_stale_index_pointing_at_non_weapon_is_rejected() -> void:
	var starting_rubles: int = GameManager.rubles
	GameManager.stash_items = [
		{"name": "Test Rifle", "value": 100, "slot": "weapon", "icon_key": "rifle", "rarity": "common"},
	]
	var stash = StashScene.instantiate()
	add_child(stash)

	var panel = stash.weapon_inspection_panel
	panel.open_for(0, "stash")
	assert_eq(panel.title_label.text, "Test Rifle", "Panel should show the real weapon initially")

	# Simulate Sort (or anything else) swapping index 0 out from under the
	# still-open panel - it's now a stack of bandages, not a weapon.
	GameManager.stash_items[0] = {"name": "Bandages", "value": 5, "slot": "consumable", "icon_key": "bandage", "rarity": "common"}
	panel.refresh()

	assert_eq(panel.title_label.text, "Weapon not found", "Panel must recognize the item at this index is no longer a weapon")

	# The real regression: even if something still tries to open the
	# per-slot menu against this stale state, there must be no weapon to
	# operate on, so no currency can be spent.
	panel._open_hotspot_menu("scope")
	assert_eq(GameManager.rubles, starting_rubles, "No Rubles should be spent when the index no longer points at a weapon")
	assert_false(GameManager.stash_items[0].has("attachments"), "A non-weapon item must never get an attachments dict grafted onto it")

	remove_child(stash)
	stash.queue_free()

func test_valid_weapon_index_still_works_normally() -> void:
	# Guards against an overzealous fix - a real weapon at a stable index
	# must still open and behave normally.
	GameManager.stash_items = [
		{"name": "Test Pistol", "value": 50, "slot": "weapon", "icon_key": "pistol", "rarity": "common"},
	]
	var stash = StashScene.instantiate()
	add_child(stash)
	var panel = stash.weapon_inspection_panel
	panel.open_for(0, "stash")
	assert_eq(panel.title_label.text, "Test Pistol", "A genuinely valid weapon should still open normally")
	for slot_key in panel.SLOT_ORDER:
		assert_true(panel.hotspot_buttons[slot_key].visible, "Hotspot dots should be visible for a valid weapon")
	remove_child(stash)
	stash.queue_free()
