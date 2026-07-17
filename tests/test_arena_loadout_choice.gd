extends TestCase

# Regression coverage (2026-07-17 audit) - Transition.change_scene() fades
# out over 0.5s before actually swapping scenes, and _choose_preset()
# already guards against a second interaction during that window
# (_choice_made). The Escape/D-pad-Up handler in _input() never checked
# the same guard, so pressing Escape during that fade window still called
# end_arena_loadout_if_active() (silently reverting the just-applied
# preset back to the player's real gear) and cleared is_arena_match/
# is_clan_war - even though the match was already committed to loading
# TheGrid.tscn via the in-flight change_scene() call.

const ArenaLoadoutChoiceScene := preload("res://scenes/ArenaLoadoutChoice.tscn")

func test_escape_after_choosing_a_preset_does_not_revert_it() -> void:
	var was_arena_match: bool = GameManager.is_arena_match
	var was_clan_war: bool = GameManager.is_clan_war
	var equipped_before: Dictionary = GameManager.equipped_items.duplicate(true)
	GameManager.is_arena_match = true
	GameManager.is_clan_war = true

	var screen = ArenaLoadoutChoiceScene.instantiate()
	add_child(screen)
	# Set the guard flag directly rather than calling the real
	# _choose_preset() - that also kicks off a real (async,
	# fade-then-swap) Transition.change_scene() to TheGrid.tscn, which
	# would actually navigate the test harness away mid-suite once its
	# 0.5s fade elapses. Setting the flag this way still exercises exactly
	# what this test is about: _input()'s own guard check.
	screen._choice_made = true

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	screen._input(escape_event)

	assert_true(GameManager.is_arena_match, "Escape after a preset was already chosen must not clear is_arena_match")
	assert_true(GameManager.is_clan_war, "Escape after a preset was already chosen must not clear is_clan_war (would silently skip Clan War rewards)")

	GameManager.is_arena_match = was_arena_match
	GameManager.is_clan_war = was_clan_war
	GameManager.equipped_items = equipped_before
	remove_child(screen)
	screen.queue_free()

# Deliberately no "escape before choosing still backs out" test here - that
# path calls the real Transition.change_scene_instant("MainMenu.tscn"),
# which would actually swap the test harness's own running scene out from
# under the rest of the suite. That pre-existing behavior isn't what this
# fix touches (the guard only ever early-returns when _choice_made is
# already true), so it's left unverified here rather than risking the
# harness.
