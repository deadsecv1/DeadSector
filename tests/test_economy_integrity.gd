extends TestCase

# Regression coverage (2026-07-17 audit) for two real economy/progression
# bugs found by a full-codebase review.

# _rotate_traders() used to subtract LOOT_BAG_TIERS.size() (7, including the
# rank-1/one-time-claim-only "alpha" tier) from the Quartermaster's item
# count, but the Quartermaster's own static starting catalog only ever
# listed 6 loot bags (no "alpha"). That off-by-one meant the very first
# rotation rolled one fewer random gear item AND unconditionally
# re-appended an "Exclusive Alpha Chest" that was never there before -
# permanently, for 2000 Rubles, breaking its intended exclusivity. Fixed by
# introducing QUARTERMASTER_STOCKED_BAG_TIERS (the same 6 tiers the static
# catalog always had) and rotating/re-appending only those.
func test_quartermaster_rotation_never_stocks_the_exclusive_alpha_chest() -> void:
	var catalog_before: Array = GameManager.TRADER_CATALOG["quartermaster"]["items"].duplicate(true)

	for i in range(4):
		GameManager._rotate_traders()
		var items: Array = GameManager.TRADER_CATALOG["quartermaster"]["items"]
		var has_alpha := false
		for it in items:
			if it.get("bag_tier", "") == "alpha":
				has_alpha = true
		assert_false(has_alpha, "Quartermaster rotation #%d should never stock the exclusive Alpha Chest" % (i + 1))
		# Every stocked loot bag tier should still be exactly the 6
		# non-exclusive ones, every rotation, not creeping over time.
		var bag_tiers_present := []
		for it in items:
			if it.get("slot", "") == "lootbag":
				bag_tiers_present.append(it.get("bag_tier", ""))
		assert_eq(bag_tiers_present.size(), GameManager.QUARTERMASTER_STOCKED_BAG_TIERS.size(), "rotation #%d should stock exactly the non-exclusive bag tiers" % (i + 1))

	GameManager.TRADER_CATALOG["quartermaster"]["items"] = catalog_before

# check_achievements()'s "big_score" used to check the live, continuously-
# mutating carried_value directly - so the moment a player was carrying
# >=5000 loot value AT ANY POINT MID-RAID, the next periodic autosave tick
# permanently unlocked it, even if the player then died and lost
# everything without ever actually extracting. Fixed with a one-shot
# achievement_flag_big_score, set only in end_run()'s success branch (the
# same pattern close_call/achievement_flag_close_call already used).
func test_big_score_does_not_unlock_from_carried_value_alone() -> void:
	var unlocked_before: Dictionary = GameManager.unlocked_achievements.duplicate(true)
	var carried_value_before: int = GameManager.carried_value
	var flag_before: bool = GameManager.achievement_flag_big_score

	GameManager.unlocked_achievements.erase("big_score")
	GameManager.achievement_flag_big_score = false
	GameManager.carried_value = 5000

	GameManager.check_achievements()
	assert_false(GameManager.unlocked_achievements.has("big_score"), "carrying >=5000 mid-raid alone must not unlock Big Score")

	GameManager.achievement_flag_big_score = true
	GameManager.check_achievements()
	assert_true(GameManager.unlocked_achievements.has("big_score"), "the one-shot flag (set only on a real successful extraction) should unlock Big Score")

	GameManager.unlocked_achievements = unlocked_before
	GameManager.carried_value = carried_value_before
	GameManager.achievement_flag_big_score = flag_before
