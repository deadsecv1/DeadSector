extends TestCase

# Regression coverage (2026-07-17, controller audit) - ItemContextMenu.gd
# and PlayerContextMenu.gd had no Escape/D-pad-Up close handling at all
# (mouse-click-outside or a button only). Separately, Stash.gd's
# _any_sub_panel_open() was missing item_context_menu.visible, so pressing
# Escape/D-pad-Up while the right-click menu was open in the Stash fell
# through every branch and exited the entire Stash screen instead of just
# closing the menu.

const StashScene := preload("res://scenes/Stash.tscn")

func _make_escape_event() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e

func test_item_context_menu_closes_itself_on_escape() -> void:
	var menu = load("res://scenes/Stash.tscn").instantiate()
	add_child(menu)
	var item_context_menu = menu.item_context_menu
	item_context_menu.visible = true

	item_context_menu._unhandled_input(_make_escape_event())

	assert_false(item_context_menu.visible, "ItemContextMenu should close itself on Escape")

	remove_child(menu)
	menu.queue_free()

func test_stash_escape_closes_only_the_context_menu_not_the_whole_screen() -> void:
	var stash = StashScene.instantiate()
	add_child(stash)
	stash.item_context_menu.visible = true

	# Stash._input() runs first (same as the real engine event order) -
	# it should see the context menu is open and let the press fall
	# through instead of exiting to stash_return_scene.
	stash._input(_make_escape_event())
	assert_true(stash.item_context_menu.visible, "Stash's own _input() must not have closed the menu directly - it should have deferred to the menu's own handler")

	# Now simulate that deferred handler actually running (same press,
	# reaching ItemContextMenu's _unhandled_input as it would in a real
	# frame).
	stash.item_context_menu._unhandled_input(_make_escape_event())
	assert_false(stash.item_context_menu.visible, "the context menu should now be closed")

	remove_child(stash)
	stash.queue_free()

func test_player_context_menu_closes_context_menu_on_escape() -> void:
	var menu := Control.new()
	menu.set_script(load("res://scripts/PlayerContextMenu.gd"))
	add_child(menu)
	menu.context_menu.visible = true

	menu._unhandled_input(_make_escape_event())

	assert_false(menu.context_menu.visible, "PlayerContextMenu's small context menu should close on Escape")

	remove_child(menu)
	menu.queue_free()

func test_player_context_menu_closes_profile_popup_first_when_both_are_open() -> void:
	var menu := Control.new()
	menu.set_script(load("res://scripts/PlayerContextMenu.gd"))
	add_child(menu)
	menu._open_profile_popup({"name": "Test Operative", "level": 5})
	assert_not_null(menu.profile_popup)
	assert_true(menu.profile_popup.visible)

	menu._unhandled_input(_make_escape_event())

	assert_false(is_instance_valid(menu.profile_popup) and menu.profile_popup.visible, "the profile popup should close on Escape")

	remove_child(menu)
	menu.queue_free()
