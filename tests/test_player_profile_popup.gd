extends TestCase

# Regression coverage for PlayerContextMenu's profile popup. Added
# alongside the "on: controller/keyboard" indicator (2026-07-16) - while
# adding it, a misplaced function definition landed in the middle of
# _open_profile_popup()'s body, silently truncating it right before its
# own add_child(profile_popup) call. The popup object still got fully
# built (every property set correctly) but was never actually attached
# to the tree - caught only by checking is_inside_tree() directly, not
# by reading the object's own properties, which all looked fine.

const PlayerContextMenuScript := preload("res://scripts/PlayerContextMenu.gd")

func _make_menu() -> Control:
	var menu: Control = PlayerContextMenuScript.new()
	menu.anchor_right = 1.0
	menu.anchor_bottom = 1.0
	add_child(menu)
	return menu

func test_profile_popup_is_actually_added_to_the_tree() -> void:
	var menu := _make_menu()
	menu._open_profile_popup({"name": "TestPlayer1", "level": 10})
	assert_true(menu.profile_popup.is_inside_tree(), "profile_popup was built but never attached to the scene tree")
	remove_child(menu)
	menu.queue_free()

func test_profile_popup_has_a_real_nonzero_size() -> void:
	var menu := _make_menu()
	menu._open_profile_popup({"name": "TestPlayer2", "level": 5})
	await get_tree().process_frame
	var rect: Rect2 = menu.profile_popup.get_global_rect()
	assert_gt(rect.size.x, 0.0)
	assert_gt(rect.size.y, 0.0)
	remove_child(menu)
	menu.queue_free()

func test_device_indicator_is_deterministic_per_name() -> void:
	var menu := _make_menu()
	var first: bool = menu._is_on_gamepad("SomePlayer")
	var second: bool = menu._is_on_gamepad("SomePlayer")
	assert_eq(first, second, "Same player name should always report the same input device")
	remove_child(menu)
	menu.queue_free()

func test_reopening_the_popup_frees_the_previous_one() -> void:
	var menu := _make_menu()
	menu._open_profile_popup({"name": "PlayerA", "level": 1})
	var first_popup: PanelContainer = menu.profile_popup
	menu._open_profile_popup({"name": "PlayerB", "level": 2})
	assert_true(menu.profile_popup.is_inside_tree(), "Second popup should be attached to the tree")
	assert_ne(menu.profile_popup, first_popup, "Reopening should build a fresh popup, not reuse the freed one")
	remove_child(menu)
	menu.queue_free()
