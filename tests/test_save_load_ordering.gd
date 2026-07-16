extends TestCase

# Regression coverage for a real, live data-corruption bug found by a
# 2026-07-16 code audit: load_game() used to call _sync_season_pass_tier()
# right after stat_extractions loaded, but BEFORE ~40 other fields
# further down the function had been assigned from the save file yet.
# _sync_season_pass_tier() can call _advance_season_pass_tier() (once per
# tier a save is catching up on), which ends with save_game() - and
# save_game() always serializes whatever is CURRENTLY in memory. Calling
# it mid-load wrote a half-loaded snapshot to disk: every field not yet
# reached by that point in load_game() got silently reverted to its
# class-default value on write, AND that corrupted write clobbered the
# one rotating .bak backup meant to protect against exactly this. Fixed
# by moving the _sync_season_pass_tier() call to the very end of
# load_game(), after every field is loaded (see GameManager.gd).
#
# This test exercises the REAL load_game()/save_game() code path (not
# just in-memory state, which stayed correct even under the old bug -
# the corruption only showed up in what got WRITTEN) via load_game()'s
# override_path param and GameManager._test_save_path_override/
# _test_save_write_log, so it never touches the developer's real
# user://savegame.json/.bak. It inspects the FIRST logged write
# specifically, not just the final one - a later, unrelated save_game()
# call from one of load_game()'s own trailing migration helpers could
# otherwise silently overwrite (and hide) evidence of an earlier,
# premature write, since by that point in the function everything really
# has finished loading. Confirmed this test actually catches the bug by
# temporarily moving _sync_season_pass_tier() back to its old buggy call
# site and re-running - it failed exactly as expected, then passed again
# once reverted.

const FIXTURE_INPUT_PATH := "user://test_fixture_ordering_input.json"

func _delete_fixture(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.open("user://").remove(path.trim_prefix("user://"))

func test_mid_load_season_pass_catchup_does_not_write_a_half_loaded_save() -> void:
	var season_pass_tier_before: int = GameManager.season_pass_tier
	var stat_extractions_before: int = GameManager.stat_extractions
	var harmon_talked_to_before: bool = GameManager.harmon_talked_to

	_delete_fixture(FIXTURE_INPUT_PATH)

	# stat_extractions=10 at 2-per-tier targets tier 5 - enough real
	# catch-up iterations (5x _advance_season_pass_tier(), each ending in
	# save_game()) to reliably reproduce the bug if it ever regresses.
	# harmon_talked_to is loaded near the very end of load_game(), well
	# after the old (buggy) call site and still before the new one -
	# exactly the kind of field the old bug would have reverted to false
	# in whatever got written to disk mid-load.
	var fixture := {
		"save_format_version": GameManager.SAVE_FORMAT_VERSION,
		"season_pass_tier": 0,
		"stat_extractions": 10,
		"harmon_talked_to": true,
	}
	var f := FileAccess.open(FIXTURE_INPUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(fixture))
	f.close()

	# Must start false so the fixture's "harmon_talked_to": true is the
	# ONLY thing that can make it true - otherwise, if this dev machine's
	# already-loaded state (or a prior test) happened to leave it true
	# already, a premature mid-load save would still show true and this
	# test would pass regardless of whether the bug was actually present.
	GameManager.harmon_talked_to = false
	GameManager._test_save_write_log = []
	GameManager._test_save_path_override = "logging"
	GameManager.load_game(FIXTURE_INPUT_PATH)
	GameManager._test_save_path_override = ""
	var write_log: Array = GameManager._test_save_write_log
	GameManager._test_save_write_log = []

	# Sanity check the catch-up actually ran (and therefore actually
	# exercised save_game() during load) - otherwise this test would
	# trivially pass by never writing anything at all.
	assert_eq(GameManager.season_pass_tier, 5, "Fixture's stat_extractions should have caught the season pass up to tier 5")
	assert_gt(write_log.size(), 0, "The mid-load catch-up should have triggered at least one real save_game() call")

	if write_log.size() > 0:
		var first_write: Dictionary = write_log[0]
		assert_true(bool(first_write.get("harmon_talked_to", false)), "A field loaded AFTER the season-pass sync point must already be present in the VERY FIRST save made DURING that same load - proves the sync no longer fires before the load is complete")

	GameManager.season_pass_tier = season_pass_tier_before
	GameManager.stat_extractions = stat_extractions_before
	GameManager.harmon_talked_to = harmon_talked_to_before
	_delete_fixture(FIXTURE_INPUT_PATH)
