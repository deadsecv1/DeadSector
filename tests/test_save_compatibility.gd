extends TestCase

# Regression coverage for loading an OLDER save file - every field in
# load_game() reads via parsed.get(key, current_default), so a save
# missing a field (because it predates that field) should fall back to
# a sane default instead of crashing. This deliberately does NOT touch
# user://savegame.json (the player's real save) even temporarily -
# GDScript has no try/finally, so a test that overwrote the real save
# and then hit an assertion failure or error partway through would leave
# it corrupted with no guaranteed restore. Instead this exercises
# _try_load_save_file() (the actual parsing/corruption-handling helper
# load_game() calls) against dedicated test-only paths, and checks the
# save-field defaults directly.

const TEST_SAVE_PATH := "user://test_fixture_save.json"
const TEST_CORRUPT_PATH := "user://test_fixture_corrupt_save.json"

func _write_fixture(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()

func _delete_fixture(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.open("user://").remove(path.trim_prefix("user://"))

func test_old_sparse_save_parses_as_a_dictionary() -> void:
	# Simulates a save from long before most of today's fields existed -
	# just enough to be a valid save at all.
	_write_fixture(TEST_SAVE_PATH, '{"save_format_version": 1, "rubles": 500, "player_name": "OldSave"}')
	var parsed = GameManager._try_load_save_file(TEST_SAVE_PATH)
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "A minimal old-format save should still parse as a Dictionary")
	if typeof(parsed) == TYPE_DICTIONARY:
		assert_eq(int(parsed.get("rubles", -1)), 500, "Fields the old save DOES have should read back correctly")
		assert_eq(parsed.get("equipped_items", "MISSING"), "MISSING", "Sanity check: this fixture deliberately has no equipped_items key")
	_delete_fixture(TEST_SAVE_PATH)

func test_corrupt_save_file_does_not_crash_and_returns_non_dictionary() -> void:
	_write_fixture(TEST_CORRUPT_PATH, '{"rubles": 500, this is not valid json!!!')
	var parsed = GameManager._try_load_save_file(TEST_CORRUPT_PATH)
	assert_true(typeof(parsed) != TYPE_DICTIONARY, "Corrupt JSON should come back as something load_game() recognizes as 'not a valid save', not crash")
	_delete_fixture(TEST_CORRUPT_PATH)

func test_missing_file_returns_null_not_a_crash() -> void:
	_delete_fixture("user://definitely_does_not_exist_fixture.json")
	var parsed = GameManager._try_load_save_file("user://definitely_does_not_exist_fixture.json")
	assert_null(parsed, "A nonexistent save path should return null, matching load_game()'s 'no save yet' branch")

func test_save_format_version_is_a_positive_integer() -> void:
	assert_true(typeof(GameManager.SAVE_FORMAT_VERSION) == TYPE_INT, "SAVE_FORMAT_VERSION should be an int")
	assert_gt(GameManager.SAVE_FORMAT_VERSION, 0, "SAVE_FORMAT_VERSION should be a positive, incrementing version number")

func test_equipped_items_default_shape_has_the_6_real_slots() -> void:
	# A save missing "equipped_items" entirely falls back to whatever
	# reset_character()/the class default initializes it to - confirms
	# that default itself is sane (matches FULLY_GEARED_SLOTS' 6 slots
	# plus the helmet_attachment extra), so an old save loading fresh
	# gear state doesn't end up with a malformed dictionary.
	var defaults: Dictionary = GameManager.equipped_items
	for slot in ["head", "body", "weapon", "accessory", "boots", "backpack"]:
		assert_has(defaults, slot, "equipped_items default is missing a real gear slot")
