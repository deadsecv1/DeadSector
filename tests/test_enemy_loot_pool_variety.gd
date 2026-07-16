extends TestCase

# Regression coverage for the 2026-07-16 batch of new ENEMY_LOOT_POOL
# items (raid ground/enemy loot) - guards against future additions
# accidentally duplicating a name, or landing outside the pool's
# established common-through-epic range.

func test_no_duplicate_item_names_in_enemy_loot_pool() -> void:
	var seen: Dictionary = {}
	for item in GameManager.ENEMY_LOOT_POOL:
		var item_name: String = item.get("name", "")
		assert_false(seen.has(item_name), "Duplicate ENEMY_LOOT_POOL item name: %s" % item_name)
		seen[item_name] = true

func test_every_item_has_a_valid_rarity_and_slot() -> void:
	var valid_rarities := ["common", "uncommon", "rare", "epic"]
	var valid_slots := ["weapon", "body", "head", "boots", "backpack", "accessory", "helmet_attachment"]
	for item in GameManager.ENEMY_LOOT_POOL:
		assert_true(valid_rarities.has(item.get("rarity", "")), "%s has an unexpected rarity for this pool: %s" % [item.get("name", "?"), item.get("rarity", "")])
		assert_true(valid_slots.has(item.get("slot", "")), "%s has an unexpected slot: %s" % [item.get("name", "?"), item.get("slot", "")])

func test_new_variety_batch_covers_every_weapon_icon_key() -> void:
	var weapon_icon_keys: Dictionary = {}
	for item in GameManager.ENEMY_LOOT_POOL:
		if item.get("slot", "") == "weapon":
			weapon_icon_keys[item.get("icon_key", "")] = true
	for expected in ["pistol", "rifle", "sniper", "shotgun", "thorn", "railgun", "flamethrower"]:
		assert_true(weapon_icon_keys.has(expected), "No weapon icon_key '%s' found in ENEMY_LOOT_POOL" % expected)

func test_new_items_are_actually_present() -> void:
	var names: Array = []
	for item in GameManager.ENEMY_LOOT_POOL:
		names.append(item.get("name", ""))
	for expected_name in ["Junkyard .22", "Requiem Sniper", "Pyroclast", "Titanium Aegis", "Ironbound Crest", "Tempest Striders", "Voidtouched Satchel", "Executioner's Ring"]:
		assert_true(names.has(expected_name), "Expected new item '%s' missing from ENEMY_LOOT_POOL" % expected_name)

func test_pool_still_rolls_a_valid_item() -> void:
	var valid_rarities := ["common", "uncommon", "rare", "epic"]
	for i in range(20):
		var rolled: Dictionary = GameManager.roll_enemy_loot()
		assert_true(rolled.has("name"))
		assert_true(rolled.has("rarity"))
		assert_true(String(rolled.get("name", "")) != "", "Rolled item has an empty name: %s" % str(rolled))
		assert_true(valid_rarities.has(rolled.get("rarity", "")), "Rolled item '%s' has an unexpected rarity: %s" % [rolled.get("name", "?"), rolled.get("rarity", "")])
