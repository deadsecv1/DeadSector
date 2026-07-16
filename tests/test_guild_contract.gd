extends TestCase

# Regression coverage for the Guild Contract system (2026-07-16) - a
# rotating weekly guild-wide objective at the Guild Hall's statue.
# Progress is derived from the player's own existing lifetime stats
# (multiplayer's simulated, so there's no separate "the guild's"
# counter) via a baseline snapshot taken whenever a new contract starts.

func before_each_file() -> void:
	# Force a fresh contract each test run so leftover state from a
	# previous test (or a real save loaded earlier in the suite) doesn't
	# leak in - same class of bug documented elsewhere in this project's
	# test suite (before_each_file only runs once per file, not per test).
	GameManager.guild_contract_index = -1

func test_a_contract_is_always_active() -> void:
	var contract: Dictionary = GameManager.get_current_guild_contract()
	assert_true(contract.has("title"))
	assert_true(contract.has("stat"))
	assert_true(contract.has("target"))

func test_progress_starts_at_zero_for_a_freshly_started_contract() -> void:
	GameManager.guild_contract_index = -1
	assert_eq(GameManager.get_guild_contract_progress(), 0)

func test_progress_tracks_the_underlying_stat_since_the_baseline() -> void:
	GameManager.guild_contract_index = -1
	var contract: Dictionary = GameManager.get_current_guild_contract()
	var stat_name: String = contract["stat"]
	var before: int = int(GameManager.get(stat_name))
	GameManager.set(stat_name, before + 7)
	assert_eq(GameManager.get_guild_contract_progress(), 7)
	GameManager.set(stat_name, before)

func test_tier_targets_scale_with_the_fraction_list() -> void:
	GameManager.guild_contract_index = -1
	var contract: Dictionary = GameManager.get_current_guild_contract()
	var target: int = int(contract["target"])
	for i in range(GameManager.GUILD_CONTRACT_TIER_FRACTIONS.size()):
		var expected: int = int(ceil(float(target) * GameManager.GUILD_CONTRACT_TIER_FRACTIONS[i]))
		assert_eq(GameManager.get_guild_contract_tier_target(i), expected)
	assert_eq(GameManager.get_guild_contract_tier_target(GameManager.GUILD_CONTRACT_TIER_FRACTIONS.size() - 1), target, "The last tier should require the full target")

func test_claiming_a_tier_before_reaching_it_fails_and_grants_nothing() -> void:
	GameManager.guild_contract_index = -1
	var rubles_before: int = GameManager.rubles
	var claimed: bool = GameManager.claim_guild_contract_tier(0)
	assert_false(claimed, "Should not be claimable with zero progress")
	assert_eq(GameManager.rubles, rubles_before)

func test_claiming_a_reached_tier_grants_reward_exactly_once() -> void:
	GameManager.guild_contract_index = -1
	var contract: Dictionary = GameManager.get_current_guild_contract()
	var stat_name: String = contract["stat"]
	var before: int = int(GameManager.get(stat_name))
	GameManager.set(stat_name, before + GameManager.get_guild_contract_tier_target(0))

	var rubles_before: int = GameManager.rubles
	var first_claim: bool = GameManager.claim_guild_contract_tier(0)
	assert_true(first_claim, "Should be claimable once the target is reached")
	var reward_rubles: int = int(GameManager.GUILD_CONTRACT_TIER_REWARDS[0].get("rubles", 0))
	assert_eq(GameManager.rubles, rubles_before + reward_rubles)

	var second_claim: bool = GameManager.claim_guild_contract_tier(0)
	assert_false(second_claim, "Should not be claimable a second time")
	assert_eq(GameManager.rubles, rubles_before + reward_rubles, "Reward should not be granted twice")
	assert_true(GameManager.is_guild_contract_tier_claimed(0))

	GameManager.set(stat_name, before)

func test_seconds_remaining_is_never_negative() -> void:
	GameManager.guild_contract_index = -1
	assert_gte(GameManager.get_guild_contract_seconds_remaining(), 0)
