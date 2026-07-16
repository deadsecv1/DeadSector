extends TestCase

# Regression coverage for the Lore system (2026-07-16) - scannable objects
# (LoreObject.gd) placed in raid maps/the Hideout, permanently marked found
# via GameManager.found_lore_objects. See GameManager.gd's "Lore" section.

func test_lore_entries_have_unique_non_empty_ids() -> void:
	var seen := {}
	for entry in GameManager.LORE_ENTRIES:
		var id: String = entry.get("id", "")
		assert_ne(id, "")
		assert_false(seen.has(id), "duplicate lore id: %s" % id)
		seen[id] = true

func test_lore_entries_all_have_title_text_and_location() -> void:
	for entry in GameManager.LORE_ENTRIES:
		assert_ne(String(entry.get("title", "")), "")
		assert_ne(String(entry.get("text", "")), "")
		assert_ne(String(entry.get("location", "")), "")

func test_object_is_not_found_by_default() -> void:
	assert_false(GameManager.is_lore_object_found("a_lore_id_that_was_never_scanned"))

func test_scan_marks_found_grants_reward_and_is_idempotent() -> void:
	const TEST_ID := "test_scan_marks_found_grants_reward_and_is_idempotent"
	var found_before: bool = GameManager.found_lore_objects.has(TEST_ID)
	var rubles_before: int = GameManager.rubles

	GameManager.scan_lore_object(TEST_ID)
	assert_true(GameManager.is_lore_object_found(TEST_ID))
	assert_eq(GameManager.rubles, rubles_before + GameManager.LORE_SCAN_RUBLES)

	GameManager.scan_lore_object(TEST_ID)
	assert_eq(GameManager.rubles, rubles_before + GameManager.LORE_SCAN_RUBLES, "scanning the same id twice should not double-grant")

	if not found_before:
		GameManager.found_lore_objects.erase(TEST_ID)
	GameManager.rubles = rubles_before

func test_scan_ignores_empty_id() -> void:
	var rubles_before: int = GameManager.rubles
	GameManager.scan_lore_object("")
	assert_eq(GameManager.rubles, rubles_before)

func test_get_lore_entry_returns_matching_entry_or_empty() -> void:
	var first: Dictionary = GameManager.LORE_ENTRIES[0]
	var found: Dictionary = GameManager.get_lore_entry(first.get("id", ""))
	assert_eq(found.get("title"), first.get("title"))
	assert_true(GameManager.get_lore_entry("not_a_real_lore_id").is_empty())

func test_every_raid_map_has_at_least_one_lore_entry() -> void:
	var maps := ["Overgrowth", "Boneclock", "Void Trench", "The Graveyard", "Ironscrap Yard", "The Foundry", "Hideout"]
	for map_name in maps:
		var count := 0
		for entry in GameManager.LORE_ENTRIES:
			if entry.get("location", "") == map_name:
				count += 1
		assert_gt(count, 0, "expected at least one lore entry located at %s" % map_name)
