extends TestCase

# Regression coverage for the gamepad-support input helpers added to
# GameManager.gd (is_action_pressed/get_movement_vector/is_shoot_pressed/
# is_aim_down_sights_pressed/get_gamepad_aim_direction/is_hotbar_*_pressed).
#
# Keyboard presses are simulated via Input.parse_input_event() - confirmed
# by hand that Godot's Input singleton only reflects a parsed key event
# on the NEXT process frame, not synchronously, hence the `await
# get_tree().process_frame` after every simulated key press below.
#
# Joypad button/axis presses can NOT be reliably simulated this way in a
# headless/no-hardware environment (confirmed: parse_input_event() for a
# joypad device Godot doesn't consider "connected" - which is every
# device in CI and most dev machines without one plugged in - never
# updates is_joy_button_pressed()/get_joy_axis(), unlike keyboard). So the
# joypad-specific paths are tested for what actually matters when no
# controller is present: they must return a calm false/zero, never error -
# that's the normal, common case (a player with no gamepad) these
# functions have to handle correctly regardless.

func _press_key(keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)

func _release_key(keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = false
	Input.parse_input_event(ev)

func test_nothing_pressed_gives_false_and_zero_baseline() -> void:
	assert_false(GameManager.is_action_pressed("interact"), "Nothing pressed - interact should read as not pressed")
	assert_false(GameManager.is_shoot_pressed(), "Nothing pressed - shoot should read as not pressed")
	assert_eq(GameManager.get_movement_vector(), Vector2.ZERO, "No input - movement vector should be zero")
	assert_eq(GameManager.get_gamepad_aim_direction(), Vector2.ZERO, "No input - gamepad aim direction should be zero")
	assert_false(GameManager.is_hotbar_next_pressed(), "No controller connected - hotbar-next must calmly return false, not error")
	assert_false(GameManager.is_hotbar_prev_pressed(), "No controller connected - hotbar-prev must calmly return false, not error")

func test_keyboard_interact_press_is_detected() -> void:
	_press_key(GameManager.get_keybind("interact"))
	await get_tree().process_frame
	assert_true(GameManager.is_action_pressed("interact"), "Simulated keyboard interact press should be detected")
	_release_key(GameManager.get_keybind("interact"))
	await get_tree().process_frame

func test_keyboard_movement_keys_drive_movement_vector() -> void:
	_press_key(KEY_D)
	await get_tree().process_frame
	var move: Vector2 = GameManager.get_movement_vector()
	assert_gt(move.x, 0.5, "Holding D should drive movement_vector.x strongly positive")
	assert_eq(move.y, 0.0, "Holding only D should not add any vertical movement")
	_release_key(KEY_D)
	await get_tree().process_frame
	assert_eq(GameManager.get_movement_vector(), Vector2.ZERO, "Releasing D should bring movement back to zero")

func test_opposite_keys_cancel_out() -> void:
	_press_key(KEY_A)
	_press_key(KEY_D)
	await get_tree().process_frame
	assert_eq(GameManager.get_movement_vector().x, 0.0, "A and D held together should cancel out horizontally")
	_release_key(KEY_A)
	_release_key(KEY_D)
	await get_tree().process_frame

func test_reload_keybind_was_added_and_does_not_break_default() -> void:
	# reload used to be a hardcoded KEY_R with no keybind entry at all -
	# confirms it's now a real, defaulted action like the other 7.
	assert_eq(GameManager.get_keybind("reload"), KEY_R, "Default reload keybind should still be R")
	assert_true(GameManager.JOYPAD_BUTTON_BINDINGS.has("reload"), "reload should have a joypad binding too")

func test_every_keybind_action_has_a_joypad_binding_or_is_intentionally_keyboard_only() -> void:
	# Every action actually read via is_action_pressed() should resolve
	# to SOME joypad button when one's connected - catches a future
	# keybind added without its gamepad counterpart being forgotten.
	for action in GameManager.KEYBIND_DEFAULTS.keys():
		assert_has(GameManager.JOYPAD_BUTTON_BINDINGS, action, "Keybind action '%s' has no matching joypad button binding" % action)

func test_joypad_helpers_are_safe_with_no_controller_connected() -> void:
	# The realistic, common case (this session's whole starting point -
	# "my friend only has a controller" implies most OTHER players don't
	# have one at all) - these must never error just because
	# Input.get_connected_joypads() is empty.
	assert_eq(Input.get_connected_joypads(), [] as Array, "Sanity check for this test environment: no real controller connected")
	assert_false(GameManager.is_action_pressed("jump"), "is_action_pressed must stay false, not error, with no controller")
	assert_false(GameManager.is_shoot_pressed(), "is_shoot_pressed must stay false, not error, with no controller")
	assert_false(GameManager.is_aim_down_sights_pressed(), "is_aim_down_sights_pressed must stay false, not error, with no controller")
	assert_eq(GameManager.get_gamepad_aim_direction(), Vector2.ZERO, "get_gamepad_aim_direction must stay zero, not error, with no controller")
	assert_false(GameManager.is_pause_pressed(), "is_pause_pressed must stay false, not error, with no controller")

# Escape is a fixed system convention on keyboard, never routed through the
# rebindable keybinds dictionary - is_pause_pressed() is its gamepad
# equivalent, kept just as fixed (see every _process()'s esc_down check
# across HUD/GauntletHUD/Hideout/SocialPlace/TheGrid).
func test_pause_is_not_accidentally_bound_to_any_existing_keybind_action() -> void:
	for action in GameManager.KEYBIND_DEFAULTS.keys():
		assert_ne(GameManager.JOYPAD_BUTTON_BINDINGS.get(action, -1), JOY_BUTTON_DPAD_UP, "D-pad Up is reserved for pause/back - action '%s' should not also claim it" % action)

# Regression coverage (2026-07-17, controller audit) - using_gamepad used
# to flip to true on ANY InputEventJoypadMotion with no deadzone check.
# Analog sticks/triggers on a connected-but-untouched controller routinely
# report small nonzero noise, which would flip every visible prompt to
# gamepad glyphs even while the player is only using keyboard/mouse.
func test_tiny_joypad_motion_does_not_flip_using_gamepad() -> void:
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = false

	var noise := InputEventJoypadMotion.new()
	noise.axis = JOY_AXIS_LEFT_X
	noise.axis_value = 0.05
	GameManager._unhandled_input(noise)

	assert_false(GameManager.using_gamepad, "stick noise well under the deadzone should not switch to gamepad mode")

	var real_push := InputEventJoypadMotion.new()
	real_push.axis = JOY_AXIS_LEFT_X
	real_push.axis_value = 0.8
	GameManager._unhandled_input(real_push)

	assert_true(GameManager.using_gamepad, "a real stick push past the deadzone should switch to gamepad mode")

	GameManager.using_gamepad = was_gamepad

func test_joypad_button_press_flips_using_gamepad_regardless_of_deadzone() -> void:
	# Buttons are already discrete/deliberate - no deadzone concept
	# applies, unlike continuous stick/trigger motion.
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = false

	var btn := InputEventJoypadButton.new()
	btn.button_index = JOY_BUTTON_A
	btn.pressed = true
	GameManager._unhandled_input(btn)

	assert_true(GameManager.using_gamepad)
	GameManager.using_gamepad = was_gamepad

# Regression coverage (2026-07-17, controller audit) - _update_gamepad_cursor()'s
# Input.warp_mouse() call can itself generate a real InputEventMouseMotion
# on some platforms, which would otherwise flip using_gamepad straight back
# to false every frame while steering the menu cursor with a controller - a
# flicker loop. _suppress_next_gamepad_cursor_mouse_motion consumes exactly
# one such self-generated motion event without swallowing a genuine one.
func test_suppressed_mouse_motion_does_not_flip_using_gamepad_but_a_real_one_does() -> void:
	var was_gamepad: bool = GameManager.using_gamepad
	var was_suppress: bool = GameManager._suppress_next_gamepad_cursor_mouse_motion
	GameManager.using_gamepad = true
	GameManager._suppress_next_gamepad_cursor_mouse_motion = true

	var motion := InputEventMouseMotion.new()
	GameManager._unhandled_input(motion)
	assert_true(GameManager.using_gamepad, "a suppressed (self-generated) mouse motion must not flip using_gamepad")
	assert_false(GameManager._suppress_next_gamepad_cursor_mouse_motion, "the suppression flag should be consumed by that one event")

	var real_motion := InputEventMouseMotion.new()
	GameManager._unhandled_input(real_motion)
	assert_false(GameManager.using_gamepad, "a genuine subsequent mouse motion should flip using_gamepad normally")

	GameManager.using_gamepad = was_gamepad
	GameManager._suppress_next_gamepad_cursor_mouse_motion = was_suppress
