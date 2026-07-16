extends TestCase

# Regression coverage for the Destiny-style gamepad menu cursor. The
# actual OS-cursor warp + hover convergence can only be verified with a
# real GPU/window (confirmed via a throwaway scratch probe during
# development - Input.warp_mouse() needs its target converted through
# get_viewport().get_screen_transform() before it lands correctly,
# since this project's "canvas_items"/"expand" stretch mode means
# window-space and viewport-space are almost never the same). What's
# covered here is the state-tracking logic headless CAN verify.

func test_crosshair_and_menu_cursor_setters_track_gameplay_mode() -> void:
	GameManager.set_crosshair_cursor()
	assert_true(GameManager._in_gameplay_cursor_mode, "set_crosshair_cursor() should mark gameplay cursor mode")
	GameManager.set_default_cursor()
	assert_false(GameManager._in_gameplay_cursor_mode, "set_default_cursor() should clear gameplay cursor mode")

func test_gamepad_cursor_texture_is_generated() -> void:
	assert_not_null(GameManager._gamepad_cursor_texture, "Gamepad cursor texture should be built at startup")

func test_update_gamepad_cursor_is_a_noop_outside_menu_context() -> void:
	# Should never touch the cursor position while in gameplay/crosshair
	# mode, regardless of using_gamepad - the left stick means movement
	# there, not cursor steering.
	GameManager.set_crosshair_cursor()
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = true
	var pos_before: Vector2 = GameManager._gamepad_cursor_pos
	GameManager._update_gamepad_cursor(0.1)
	assert_eq(GameManager._gamepad_cursor_pos, pos_before, "_update_gamepad_cursor should no-op during gameplay/crosshair mode")
	GameManager.using_gamepad = was_gamepad
	GameManager.set_default_cursor()

func test_update_gamepad_cursor_is_a_noop_without_a_gamepad() -> void:
	GameManager.set_default_cursor()
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = false
	var pos_before: Vector2 = GameManager._gamepad_cursor_pos
	GameManager._update_gamepad_cursor(0.1)
	assert_eq(GameManager._gamepad_cursor_pos, pos_before, "_update_gamepad_cursor should no-op when not using a gamepad")
	GameManager.using_gamepad = was_gamepad
