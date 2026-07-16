extends TestCase

# Regression coverage for Daily Bounties (2026-07-16) - 3 small personal
# objectives rerolled at a fixed real-calendar-day boundary (see
# GameManager's DAILY_BOUNTY_TYPES/_ensure_daily_bounties_current()).
# Deliberately a fixed day-boundary reset (like Clan Wars), not a
# rolling duration like Guild Contract's own weekly window - see
# test_guild_contract.gd for that system's equivalent coverage.

func before_each_file() -> void:
	GameManager.daily_bounty_day = -1

func test_three_slots_are_rolled() -> void:
	GameManager.daily_bounty_day = -1
	assert_eq(GameManager.get_daily_bounty_slots().size(), GameManager.DAILY_BOUNTY_SLOT_COUNT)

func test_slots_are_not_rerolled_on_the_same_day() -> void:
	GameManager.daily_bounty_day = -1
	var first_type_index: int = int(GameManager.get_daily_bounty_slots()[0]["type_index"])
	# Calling any getter again the same "day" should return the exact
	# same rolled slots, not reroll every time the panel refreshes.
	var second_type_index: int = int(GameManager.get_daily_bounty_slots()[0]["type_index"])
	assert_eq(first_type_index, second_type_index)

func test_progress_starts_at_zero() -> void:
	GameManager.daily_bounty_day = -1
	for i in range(GameManager.get_daily_bounty_slots().size()):
		assert_eq(GameManager.get_daily_bounty_progress(i), 0)

func test_progress_tracks_the_underlying_stat_since_the_baseline() -> void:
	GameManager.daily_bounty_day = -1
	var bounty_type: Dictionary = GameManager.get_daily_bounty_type(0)
	var stat_name: String = bounty_type["stat"]
	var before: int = int(GameManager.get(stat_name))
	GameManager.set(stat_name, before + 4)
	assert_eq(GameManager.get_daily_bounty_progress(0), 4)
	GameManager.set(stat_name, before)

func test_claiming_before_reaching_target_fails() -> void:
	GameManager.daily_bounty_day = -1
	var rubles_before: int = GameManager.rubles
	assert_false(GameManager.claim_daily_bounty(0))
	assert_eq(GameManager.rubles, rubles_before)

func test_claiming_a_reached_bounty_grants_reward_exactly_once() -> void:
	GameManager.daily_bounty_day = -1
	var bounty_type: Dictionary = GameManager.get_daily_bounty_type(0)
	var stat_name: String = bounty_type["stat"]
	var before: int = int(GameManager.get(stat_name))
	GameManager.set(stat_name, before + int(bounty_type["target"]))

	var rubles_before: int = GameManager.rubles
	assert_true(GameManager.claim_daily_bounty(0))
	assert_eq(GameManager.rubles, rubles_before + int(GameManager.DAILY_BOUNTY_REWARD["rubles"]))
	assert_true(GameManager.is_daily_bounty_claimed(0))

	assert_false(GameManager.claim_daily_bounty(0), "Should not be claimable a second time")
	assert_eq(GameManager.rubles, rubles_before + int(GameManager.DAILY_BOUNTY_REWARD["rubles"]), "Reward should not be granted twice")

	GameManager.set(stat_name, before)

func test_all_three_claimed_grants_the_bonus() -> void:
	GameManager.daily_bounty_day = -1
	var slots: Array = GameManager.get_daily_bounty_slots()
	var reset_values: Array = []
	for i in range(slots.size()):
		var bounty_type: Dictionary = GameManager.get_daily_bounty_type(i)
		var stat_name: String = bounty_type["stat"]
		var before: int = int(GameManager.get(stat_name))
		reset_values.append([stat_name, before])
		GameManager.set(stat_name, before + int(bounty_type["target"]))

	var rubles_before: int = GameManager.rubles
	for i in range(slots.size()):
		GameManager.claim_daily_bounty(i)
	var expected_min: int = rubles_before + int(GameManager.DAILY_BOUNTY_REWARD["rubles"]) * slots.size() + int(GameManager.DAILY_BOUNTY_ALL_CLEAR_BONUS["rubles"])
	assert_eq(GameManager.rubles, expected_min, "All-clear bonus should be granted once every slot is claimed")

	for pair in reset_values:
		GameManager.set(pair[0], pair[1])
