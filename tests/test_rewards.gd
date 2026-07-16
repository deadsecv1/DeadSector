extends TestCase

# Regression coverage for the "double every reward" pass (v3.63.0) - catches
# a hand-typed tier that got missed, doubled twice, or given a bag_tier
# string that doesn't exist in LOOT_BAG_TIERS.

const VALID_BAG_TIERS := ["common", "rare", "epic", "legendary", "mythic", "exotic", "alpha"]

func _amounts_by_type(tiers: Array, type_name: String) -> Array:
	var amounts: Array = []
	for tier in tiers:
		if tier.get("type", "") == type_name:
			amounts.append(int(tier.get("amount", 0)))
	return amounts

func _assert_non_decreasing(amounts: Array, label: String) -> void:
	for i in range(1, amounts.size()):
		assert_gte(amounts[i], amounts[i - 1], "%s tier %d (%d) should be >= tier %d (%d)" % [label, i, amounts[i], i - 1, amounts[i - 1]])

func _assert_valid_bag_tiers(tiers: Array, label: String) -> void:
	for tier in tiers:
		if tier.get("type", "") == "lootbag":
			var bag_tier: String = str(tier.get("bag_tier", ""))
			assert_true(VALID_BAG_TIERS.has(bag_tier), "%s: unknown bag_tier '%s'" % [label, bag_tier])

func test_guild_battle_pass_tiers_increase_and_valid() -> void:
	var tiers: Array = GameManager.GUILD_BATTLE_PASS_TIER_DATA
	assert_eq(tiers.size(), 20, "Guild Battle Pass should have 20 tiers")
	_assert_non_decreasing(_amounts_by_type(tiers, "rubles"), "GuildBattlePass rubles")
	_assert_non_decreasing(_amounts_by_type(tiers, "xp"), "GuildBattlePass xp")
	_assert_non_decreasing(_amounts_by_type(tiers, "skill_points"), "GuildBattlePass skill_points")
	_assert_valid_bag_tiers(tiers, "GuildBattlePass")

func test_milestone_tiers_increase_and_valid() -> void:
	var tiers: Array = GameManager.MILESTONE_TIER_DATA
	assert_eq(tiers.size(), 24, "Milestones should have 24 tiers")
	_assert_non_decreasing(_amounts_by_type(tiers, "rubles"), "Milestone rubles")
	_assert_non_decreasing(_amounts_by_type(tiers, "xp"), "Milestone xp")
	_assert_non_decreasing(_amounts_by_type(tiers, "skill_points"), "Milestone skill_points")
	_assert_valid_bag_tiers(tiers, "Milestone")

func test_arena_reward_tiers_increase_and_valid() -> void:
	var tiers: Array = GameManager.ARENA_REWARD_TIERS
	assert_eq(tiers.size(), 6, "Arena should have 6 rank tiers")
	var rubles: Array = []
	var artifacts: Array = []
	var alloys: Array = []
	var skill_points: Array = []
	for tier in tiers:
		rubles.append(int(tier.get("rubles", 0)))
		artifacts.append(int(tier.get("artifacts", 0)))
		alloys.append(int(tier.get("alloys", 0)))
		skill_points.append(int(tier.get("skill_points", 0)))
	_assert_non_decreasing(rubles, "Arena rubles")
	_assert_non_decreasing(artifacts, "Arena artifacts")
	_assert_non_decreasing(alloys, "Arena alloys")
	_assert_non_decreasing(skill_points, "Arena skill_points")
	for tier in tiers:
		for bag_tier in tier.get("bags", []):
			assert_true(VALID_BAG_TIERS.has(str(bag_tier)), "Arena: unknown bag_tier '%s'" % str(bag_tier))

func test_battle_pass_rewards_all_positive() -> void:
	var rewards: Array = GameManager._generate_battle_pass_rewards()
	assert_eq(rewards.size(), GameManager.BATTLE_PASS_MAX_TIER, "Battle Pass reward count should match BATTLE_PASS_MAX_TIER")
	for i in range(rewards.size()):
		var reward: Dictionary = rewards[i]
		var type: String = reward.get("type", "")
		assert_true(type != "", "Battle Pass tier %d has no type" % (i + 1))
		if type in ["souls", "rubles", "xp"]:
			assert_gt(int(reward.get("amount", 0)), 0, "Battle Pass tier %d (%s) should grant a positive amount" % [i + 1, type])

func test_bloodline_and_salvaged_beasts_rewards_all_positive() -> void:
	var bloodline: Array = GameManager._generate_bloodline_rewards()
	assert_eq(bloodline.size(), GameManager.BLOODLINE_MAX_TIER)
	for reward in bloodline:
		if reward.get("type", "") in ["rubles", "blood_shards"]:
			assert_gt(int(reward.get("amount", 0)), 0, "Bloodline reward should be positive: %s" % str(reward))

	var beasts: Array = GameManager._generate_salvaged_beasts_rewards()
	assert_eq(beasts.size(), GameManager.SALVAGED_BEASTS_MAX_TIER)
	for reward in beasts:
		if reward.get("type", "") in ["rubles", "tickets"]:
			assert_gt(int(reward.get("amount", 0)), 0, "Salvaged Beasts reward should be positive: %s" % str(reward))

func test_key_catalog_has_no_duplicate_ids_and_matching_house_keys() -> void:
	var catalog: Dictionary = GameManager.KEY_CATALOG
	# The 4 new house keys added alongside the 4 new houses this session -
	# a typo between a House's key_id, its guard's drop_key_id, and this
	# catalog entry would make the key exist but be permanently unusable.
	var expected_keys := ["house_a_key", "house_b_key", "gas_station_key", "graveyard_key", "trench_bunker_key", "foreman_shack_key", "foundry_office_key", "caretakers_cottage_key"]
	for key_id in expected_keys:
		assert_has(catalog, key_id, "KEY_CATALOG missing expected key")
