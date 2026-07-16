extends TestCase

# Regression test for a staleness bug found in this session's audit:
# ItemIcon.gd cached whether real external art existed only once, at
# _ready() - Player.gd/Enemy.gd/WeaponInspectionPanel.gd all now swap
# icon_key on an already-live icon (a gear slot changing weapon type, a
# different weapon opened in the inspection screen), which used to leave
# whichever texture (or lack of one) was current at creation time stuck
# forever. Fixed with a custom setter on icon_key that re-runs
# _check_external_art(). Uses a tiny real fixture file (assets/icons/
# test_fixture_icon.png) since the bug is specifically about real-art
# detection, which an icon_key with no matching file can't exercise.

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

func test_icon_key_change_picks_up_and_drops_real_art() -> void:
	var icon = ItemIconScene.instantiate()
	icon.icon_key = "nonexistent_icon_key_xyz"
	icon.size = Vector2(32, 32)
	add_child(icon)

	assert_null(icon._art_rect, "No art file exists for this icon_key - _art_rect should stay unset")

	icon.icon_key = "test_fixture_icon"
	assert_not_null(icon._art_rect, "Switching to an icon_key with real art at res://assets/icons/ should create _art_rect")
	assert_true(icon._art_rect.visible, "_art_rect should be visible once real art is found")

	icon.icon_key = "nonexistent_icon_key_xyz"
	assert_not_null(icon._art_rect, "_art_rect node itself can stay around (reused if this icon_key ever gets real art again)")
	assert_false(icon._art_rect.visible, "Switching back to an icon_key with no art must hide the stale texture, not leave the previous icon_key's art showing")

	remove_child(icon)
	icon.queue_free()

func test_setting_icon_key_to_same_value_is_a_no_op() -> void:
	var icon = ItemIconScene.instantiate()
	icon.icon_key = "test_fixture_icon"
	icon.size = Vector2(32, 32)
	add_child(icon)
	var art_rect_before = icon._art_rect
	icon.icon_key = "test_fixture_icon"
	assert_eq(icon._art_rect, art_rect_before, "Re-setting the same icon_key should not tear down and rebuild _art_rect")
	remove_child(icon)
	icon.queue_free()
