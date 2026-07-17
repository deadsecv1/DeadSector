extends TestCase

# Regression coverage (2026-07-17, controller audit) - _move_selection()
# (driven by gamepad LB/RB via _process(), and by mouse wheel via
# _unhandled_input()) only ever updated the local selected_index used for
# the highlight box, never GameManager.active_hotbar_slot - the only field
# Player.gd actually reads to decide whether a shot fires the weapon or
# uses a consumable. Only _select() (driven exclusively by number keys
# 1-5) wrote active_hotbar_slot. A gamepad-only player has no number keys,
# so bumping LB/RB visibly moved the highlight to e.g. a grenade slot, but
# pulling the trigger kept firing whatever slot was last set via keyboard
# (or slot 0 by default) - the consumable slot was cosmetically selected
# but functionally inert.

const HUDScene := preload("res://scenes/HUD.tscn")

func test_move_selection_actually_changes_the_active_hotbar_slot() -> void:
	var hud = HUDScene.instantiate()
	add_child(hud)
	var hotbar = hud.get_node("Hotbar")

	assert_eq(GameManager.active_hotbar_slot, 0, "test setup: should start on slot 0")
	assert_eq(hotbar.selected_index, 0)

	hotbar._move_selection(1)

	assert_eq(hotbar.selected_index, 1, "the highlight should move")
	assert_eq(GameManager.active_hotbar_slot, 1, "active_hotbar_slot must actually change too - this is what Player.gd reads to decide what fires")

	hotbar._move_selection(1)
	assert_eq(GameManager.active_hotbar_slot, 2)

	# Wraps correctly in both directions, same as before the fix.
	hotbar._move_selection(-3)
	assert_eq(hotbar.selected_index, 4)
	assert_eq(GameManager.active_hotbar_slot, 4)

	remove_child(hud)
	hud.queue_free()
	GameManager.active_hotbar_slot = 0
