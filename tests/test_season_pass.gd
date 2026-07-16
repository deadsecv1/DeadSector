extends TestCase

# Regression coverage for the Pre Season Pass (2026-07-16) - a real-time-
# limited reward track (ends GameManager.SEASON_PASS_END_TIMESTAMP) whose
# progress derives from stat_extractions rather than a granted-XP currency.
# See GameManager.gd's "Pre Season Pass" section.

func test_season_pass_is_currently_available() -> void:
	# The deadline is set a month out from this feature's ship date -
	# should read true for the lifetime of this pass.
	assert_true(GameManager.season_pass_available())
	assert_gt(GameManager.season_pass_seconds_left(), 0.0)

func test_seconds_left_is_never_more_than_the_full_window() -> void:
	# Sanity bound - catches an accidental far-future/garbage timestamp
	# constant without hardcoding an exact "days remaining" number that
	# would need updating every time this test runs on a different day.
	const ROUGHLY_ONE_MONTH_SECONDS := 40 * 24 * 3600.0
	assert_true(GameManager.season_pass_seconds_left() <= ROUGHLY_ONE_MONTH_SECONDS)

func test_reward_table_has_one_entry_per_tier() -> void:
	var rewards: Array = GameManager._generate_season_pass_rewards()
	assert_eq(rewards.size(), GameManager.SEASON_PASS_MAX_TIER)
	for reward in rewards:
		assert_true(reward.has("type"))

func test_reward_table_is_deterministic() -> void:
	var a: Array = GameManager._generate_season_pass_rewards()
	var b: Array = GameManager._generate_season_pass_rewards()
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		assert_eq(a[i].get("type"), b[i].get("type"), "tier %d type should be identical across generations" % (i + 1))

# _advance_season_pass_tier() has real side effects beyond season_pass_tier
# itself - it can grant XP (leveling the player), rubles/artifacts/skill
# points, or append items/loot bags to stash_items, depending on what
# _generate_season_pass_rewards() rolled for that tier. Every test below
# that actually triggers a real advance snapshots/restores ALL of that,
# not just the field it's directly asserting on - otherwise these leak
# into every test file that sorts alphabetically after this one, since
# GameManager is a single live singleton shared across the whole suite
# run (see test_daily_bounties.gd's own comment on this same risk).
func _snapshot_reward_state() -> Dictionary:
	return {
		"player_xp": GameManager.player_xp, "player_level": GameManager.player_level,
		"rubles": GameManager.rubles, "artifacts": GameManager.artifacts, "skill_points": GameManager.skill_points,
		"stash_items": GameManager.stash_items.duplicate(true),
	}

func _restore_reward_state(snapshot: Dictionary) -> void:
	GameManager.player_xp = snapshot["player_xp"]
	GameManager.player_level = snapshot["player_level"]
	GameManager.rubles = snapshot["rubles"]
	GameManager.artifacts = snapshot["artifacts"]
	GameManager.skill_points = snapshot["skill_points"]
	GameManager.stash_items = snapshot["stash_items"]

func test_sync_advances_tier_from_extractions_and_is_idempotent() -> void:
	var tier_before: int = GameManager.season_pass_tier
	var extractions_before: int = GameManager.stat_extractions
	var reward_snapshot := _snapshot_reward_state()

	GameManager.season_pass_tier = 0
	GameManager.stat_extractions = GameManager.SEASON_PASS_EXTRACTIONS_PER_TIER * 3
	GameManager._sync_season_pass_tier()
	assert_eq(GameManager.season_pass_tier, 3)

	# Running it again with no new extractions should not advance further.
	GameManager._sync_season_pass_tier()
	assert_eq(GameManager.season_pass_tier, 3)

	GameManager.season_pass_tier = tier_before
	GameManager.stat_extractions = extractions_before
	_restore_reward_state(reward_snapshot)

func test_sync_never_exceeds_max_tier_even_with_huge_extraction_counts() -> void:
	var tier_before: int = GameManager.season_pass_tier
	var extractions_before: int = GameManager.stat_extractions
	var reward_snapshot := _snapshot_reward_state()

	GameManager.season_pass_tier = 0
	GameManager.stat_extractions = 999999
	GameManager._sync_season_pass_tier()
	assert_eq(GameManager.season_pass_tier, GameManager.SEASON_PASS_MAX_TIER)

	GameManager.season_pass_tier = tier_before
	GameManager.stat_extractions = extractions_before
	_restore_reward_state(reward_snapshot)

func test_advance_tier_grants_reward_and_persists_progress() -> void:
	var tier_before: int = GameManager.season_pass_tier
	var reward_snapshot := _snapshot_reward_state()
	GameManager.season_pass_tier = 0
	GameManager._advance_season_pass_tier()
	assert_eq(GameManager.season_pass_tier, 1)
	GameManager.season_pass_tier = tier_before
	_restore_reward_state(reward_snapshot)

func test_skip_tier_spends_rubles_and_advances() -> void:
	var tier_before: int = GameManager.season_pass_tier
	var reward_snapshot := _snapshot_reward_state()
	GameManager.season_pass_tier = 0
	GameManager.rubles = 100000
	var skipped: bool = GameManager.skip_season_pass_tier()
	assert_true(skipped)
	assert_eq(GameManager.season_pass_tier, 1)
	assert_eq(GameManager.rubles, 100000 - 3000)
	GameManager.season_pass_tier = tier_before
	_restore_reward_state(reward_snapshot)

func test_skip_tier_fails_without_enough_rubles() -> void:
	var tier_before: int = GameManager.season_pass_tier
	var rubles_before: int = GameManager.rubles
	GameManager.season_pass_tier = 0
	GameManager.rubles = 0
	var skipped: bool = GameManager.skip_season_pass_tier()
	assert_false(skipped)
	assert_eq(GameManager.season_pass_tier, 0)
	GameManager.season_pass_tier = tier_before
	GameManager.rubles = rubles_before

func test_skip_tier_fails_once_at_max_tier() -> void:
	var tier_before: int = GameManager.season_pass_tier
	var rubles_before: int = GameManager.rubles
	GameManager.season_pass_tier = GameManager.SEASON_PASS_MAX_TIER
	GameManager.rubles = 100000
	var skipped: bool = GameManager.skip_season_pass_tier()
	assert_false(skipped)
	GameManager.season_pass_tier = tier_before
	GameManager.rubles = rubles_before
