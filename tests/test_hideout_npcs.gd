extends TestCase

# Regression coverage for the two new Hideout NPCs (2026-07-16): Whisper
# (info broker, once-per-real-day tip) and Old Harmon (war-stories
# veteran, one-time welcome gift). Pure GameManager-state tests - the
# world/panel wiring is checked by booting scenes/Hideout.tscn headlessly.

func test_whisper_tip_available_by_default() -> void:
	var day_before: int = GameManager.whisper_tip_day
	GameManager.whisper_tip_day = -1
	assert_true(GameManager.whisper_tip_available())
	GameManager.whisper_tip_day = day_before

func test_claim_whisper_tip_grants_currency_and_locks_for_today() -> void:
	var day_before: int = GameManager.whisper_tip_day
	var rubles_before: int = GameManager.rubles
	var artifacts_before: int = GameManager.artifacts
	GameManager.whisper_tip_day = -1

	var claimed: bool = GameManager.claim_whisper_tip()
	assert_true(claimed)
	assert_eq(GameManager.rubles, rubles_before + GameManager.WHISPER_TIP_RUBLES)
	assert_eq(GameManager.artifacts, artifacts_before + GameManager.WHISPER_TIP_ARTIFACTS)
	assert_false(GameManager.whisper_tip_available(), "should be locked again immediately after claiming")

	var second_claim: bool = GameManager.claim_whisper_tip()
	assert_false(second_claim, "should not be claimable twice in the same day")
	assert_eq(GameManager.rubles, rubles_before + GameManager.WHISPER_TIP_RUBLES, "reward should not double-grant")

	GameManager.whisper_tip_day = day_before

func test_whisper_rumors_pool_is_non_empty_and_all_real_text() -> void:
	assert_gt(GameManager.WHISPER_RUMORS.size(), 0)
	for line in GameManager.WHISPER_RUMORS:
		assert_ne(String(line), "")

func test_harmon_welcome_grants_rubles_exactly_once() -> void:
	var talked_before: bool = GameManager.harmon_talked_to
	var rubles_before: int = GameManager.rubles
	GameManager.harmon_talked_to = false

	GameManager._maybe_grant_harmon_welcome()
	assert_true(GameManager.harmon_talked_to)
	assert_eq(GameManager.rubles, rubles_before + GameManager.HARMON_WELCOME_RUBLES)

	GameManager._maybe_grant_harmon_welcome()
	assert_eq(GameManager.rubles, rubles_before + GameManager.HARMON_WELCOME_RUBLES, "welcome gift should not grant twice")

	GameManager.harmon_talked_to = talked_before

func test_harmon_stories_pool_is_non_empty_and_all_real_text() -> void:
	assert_gt(GameManager.HARMON_WAR_STORIES.size(), 0)
	for line in GameManager.HARMON_WAR_STORIES:
		assert_ne(String(line), "")

func test_harmon_met_achievement_exists_and_is_wired() -> void:
	assert_has(GameManager.ACHIEVEMENTS, "harmon_met")
