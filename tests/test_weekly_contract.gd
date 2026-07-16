extends TestCase

# Regression coverage for the Weekly Contract (2026-07-16) - one big
# pinnacle-style objective rerolled at a fixed real-calendar-week
# boundary (see GameManager's WEEKLY_CONTRACT_TYPES/
# _ensure_weekly_contract_current()). Same baseline-snapshot progress
# idea as Daily Bounty/Guild Contract, just a single slot and a 7-day
# window instead of 1 - see test_daily_bounties.gd for that system's
# equivalent coverage.

func before_each_file() -> void:
	GameManager.weekly_contract_week = -1

func test_a_contract_is_rolled() -> void:
	GameManager.weekly_contract_week = -1
	var contract_type: Dictionary = GameManager.get_weekly_contract_type()
	assert_true(contract_type.has("stat"))

func test_contract_is_not_rerolled_within_the_same_week() -> void:
	GameManager.weekly_contract_week = -1
	GameManager.get_weekly_contract_type()
	var first_index: int = int(GameManager.weekly_contract_type_index)
	# Calling any getter again the same "week" should return the exact
	# same rolled contract, not reroll every time the panel refreshes.
	GameManager.get_weekly_contract_type()
	var second_index: int = int(GameManager.weekly_contract_type_index)
	assert_eq(first_index, second_index)

func test_progress_starts_at_zero() -> void:
	GameManager.weekly_contract_week = -1
	assert_eq(GameManager.get_weekly_contract_progress(), 0)

func test_progress_tracks_the_underlying_stat_since_the_baseline() -> void:
	GameManager.weekly_contract_week = -1
	var contract_type: Dictionary = GameManager.get_weekly_contract_type()
	var stat_name: String = contract_type["stat"]
	var before: int = int(GameManager.get(stat_name))
	GameManager.set(stat_name, before + 7)
	assert_eq(GameManager.get_weekly_contract_progress(), 7)
	GameManager.set(stat_name, before)

func test_claiming_before_reaching_target_fails() -> void:
	GameManager.weekly_contract_week = -1
	var rubles_before: int = GameManager.rubles
	assert_false(GameManager.claim_weekly_contract())
	assert_eq(GameManager.rubles, rubles_before)

func test_claiming_a_reached_contract_grants_reward_exactly_once() -> void:
	GameManager.weekly_contract_week = -1
	var contract_type: Dictionary = GameManager.get_weekly_contract_type()
	var stat_name: String = contract_type["stat"]
	var before: int = int(GameManager.get(stat_name))
	GameManager.set(stat_name, before + int(contract_type["target"]))

	var rubles_before: int = GameManager.rubles
	assert_true(GameManager.claim_weekly_contract())
	assert_eq(GameManager.rubles, rubles_before + int(GameManager.WEEKLY_CONTRACT_REWARD["rubles"]))
	assert_true(GameManager.is_weekly_contract_claimed())

	assert_false(GameManager.claim_weekly_contract(), "Should not be claimable a second time")
	assert_eq(GameManager.rubles, rubles_before + int(GameManager.WEEKLY_CONTRACT_REWARD["rubles"]), "Reward should not be granted twice")

	GameManager.set(stat_name, before)

func test_seconds_left_is_within_one_week() -> void:
	var seconds_left: int = GameManager.weekly_contract_seconds_left()
	assert_true(seconds_left >= 0 and seconds_left <= 604800)
