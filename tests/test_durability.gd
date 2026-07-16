extends TestCase

# Regression coverage for the weapon/armor Durability system (2026-07-16) -
# gear wears down with use and Torque (a new Hideout NPC) repairs it back
# to full for Rubles. See GameManager.gd's "Durability" section.

func test_item_with_no_durability_key_reads_as_full() -> void:
	var item := {"name": "Old Save Pistol", "slot": "weapon", "value": 50}
	assert_eq(GameManager.get_item_durability(item), 100.0)
	assert_false(GameManager.is_item_broken(item))

func test_has_durability_only_applies_to_weapon_armor_slots() -> void:
	assert_true(GameManager.has_durability({"slot": "weapon"}))
	assert_true(GameManager.has_durability({"slot": "body"}))
	assert_true(GameManager.has_durability({"slot": "head"}))
	assert_false(GameManager.has_durability({"slot": "lootbag"}))
	assert_false(GameManager.has_durability({"consumable_type": "heal"}))
	assert_false(GameManager.has_durability({}))

func test_damage_item_durability_clamps_between_zero_and_a_hundred() -> void:
	var item := {"slot": "weapon", "durability": 5.0}
	GameManager.damage_item_durability(item, 50.0)
	assert_eq(GameManager.get_item_durability(item), 0.0, "should clamp at 0, not go negative")

	var full_item := {"slot": "weapon", "durability": 100.0}
	GameManager.damage_item_durability(full_item, -10.0)
	assert_eq(GameManager.get_item_durability(full_item), 100.0, "should clamp at 100")

func test_damage_item_durability_is_a_noop_on_items_without_durability() -> void:
	var item := {"slot": "lootbag", "durability": 100.0}
	GameManager.damage_item_durability(item, 50.0)
	assert_eq(GameManager.get_item_durability(item), 100.0, "lootbags don't wear down")

func test_item_is_broken_at_exactly_zero_durability() -> void:
	var item := {"slot": "weapon", "durability": 1.0}
	assert_false(GameManager.is_item_broken(item))
	GameManager.damage_item_durability(item, 1.0)
	assert_true(GameManager.is_item_broken(item))

func test_repair_cost_is_zero_at_full_durability() -> void:
	var item := {"slot": "weapon", "durability": 100.0, "value": 500}
	assert_eq(GameManager.get_repair_cost(item), 0)

func test_repair_cost_scales_with_missing_durability_and_value() -> void:
	var cheap_item := {"slot": "weapon", "durability": 50.0, "value": 30}
	var expensive_item := {"slot": "weapon", "durability": 50.0, "value": 3000}
	assert_gt(GameManager.get_repair_cost(expensive_item), GameManager.get_repair_cost(cheap_item))

	var slightly_worn := {"slot": "weapon", "durability": 90.0, "value": 500}
	var badly_worn := {"slot": "weapon", "durability": 10.0, "value": 500}
	assert_gt(GameManager.get_repair_cost(badly_worn), GameManager.get_repair_cost(slightly_worn))

func test_repair_item_restores_to_full_and_spends_currency() -> void:
	var rubles_before: int = GameManager.rubles
	GameManager.rubles = 100000
	var item := {"slot": "body", "durability": 40.0, "value": 200}
	var cost: int = GameManager.get_repair_cost(item)
	var repaired: bool = GameManager.repair_item(item)
	assert_true(repaired)
	assert_eq(GameManager.get_item_durability(item), 100.0)
	assert_eq(GameManager.rubles, 100000 - cost)
	GameManager.rubles = rubles_before

func test_repair_item_fails_without_enough_currency() -> void:
	var rubles_before: int = GameManager.rubles
	GameManager.rubles = 0
	var item := {"slot": "weapon", "durability": 10.0, "value": 5000}
	var repaired: bool = GameManager.repair_item(item)
	assert_false(repaired)
	assert_eq(GameManager.get_item_durability(item), 10.0, "a failed repair should not touch durability")
	GameManager.rubles = rubles_before

func test_broken_weapon_contributes_no_damage_bonus() -> void:
	# Compared against "no weapon equipped" rather than an absolute 0.0 -
	# GameManager is a shared singleton across the whole test suite run, so
	# real pets/other equipped slots from earlier test files can already be
	# contributing a nonzero "damage" bonus of their own.
	var weapon_before = GameManager.equipped_items.get("weapon")
	GameManager.equipped_items["weapon"] = null
	var bonus_without_weapon := GameManager.get_equipped_bonus("damage")
	GameManager.equipped_items["weapon"] = {"slot": "weapon", "stat_type": "damage", "stat_value": 100.0, "durability": 0.0}
	var bonus_with_broken_weapon := GameManager.get_equipped_bonus("damage")
	assert_eq(bonus_with_broken_weapon, bonus_without_weapon, "a broken weapon should add nothing, same as no weapon at all")
	GameManager.equipped_items["weapon"] = weapon_before

func test_half_durability_weapon_contributes_half_its_stat() -> void:
	# Same "diff against a no-weapon baseline" approach as above, since a
	# plain full_bonus/half_bonus ratio isn't safe when other equipped
	# items/pets already contribute a nonzero constant to "damage".
	var weapon_before = GameManager.equipped_items.get("weapon")
	GameManager.equipped_items["weapon"] = null
	var baseline := GameManager.get_equipped_bonus("damage")

	GameManager.equipped_items["weapon"] = {"slot": "weapon", "stat_type": "damage", "stat_value": 100.0, "durability": 100.0}
	var full_delta: float = GameManager.get_equipped_bonus("damage") - baseline

	GameManager.equipped_items["weapon"] = {"slot": "weapon", "stat_type": "damage", "stat_value": 100.0, "durability": 50.0}
	var half_delta: float = GameManager.get_equipped_bonus("damage") - baseline

	# WEAPON_DAMAGE_MULT halves it again on top of the durability scaling -
	# asserting the durability half-scaling relationship holds (not the
	# exact number) so this doesn't silently drift if that base multiplier
	# ever changes for balance reasons.
	assert_eq(half_delta, full_delta * 0.5)
	GameManager.equipped_items["weapon"] = weapon_before

func test_get_repairable_items_only_lists_items_below_full_durability() -> void:
	var body_before = GameManager.equipped_items.get("body")
	GameManager.equipped_items["body"] = {"slot": "body", "durability": 60.0, "value": 100, "name": "Test Vest"}
	var found: bool = false
	for item in GameManager.get_repairable_items():
		if item.get("name") == "Test Vest":
			found = true
	assert_true(found, "a worn equipped item should show up as repairable")
	GameManager.equipped_items["body"] = body_before

func test_loadout_preset_matching_ignores_durability() -> void:
	var pristine := {"name": "Field Vest", "slot": "body", "value": 45, "durability": 100.0}
	var worn := {"name": "Field Vest", "slot": "body", "value": 45, "durability": 63.0}
	assert_true(GameManager._items_match_ignoring_position(pristine, worn), "a saved preset should still find its gear after combat wear changed the number")
