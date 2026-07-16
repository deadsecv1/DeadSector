extends TestCase

# GameManager.using_gamepad is shared singleton state, same class of
# cross-test-file leak risk as gamepad_held_data elsewhere in this suite -
# defensively start every test in this file from the common mouse state.
func before_each_file() -> void:
	var mouse_event := InputEventMouseMotion.new()
	GameManager._unhandled_input(mouse_event)

# Regression coverage for the default Button focus ring only being visible
# to gamepad players. Godot's built-in default "focus" StyleBox for
# Button is a plain white outline - since focus_first_control() grabs
# focus unconditionally on whatever's first in scene-tree order (e.g.
# Main Menu's Roadmap button, simply because it's declared before the
# others), a mouse-only player would otherwise see a stray white outline
# around a semi-random button every time a screen opens, which reads as
# a bug rather than a feature meant for the tiny fraction of players
# actually using a controller.

func test_focus_ring_is_hidden_by_default() -> void:
	var theme := ThemeDB.get_default_theme()
	assert_true(theme.get_stylebox("focus", "Button") is StyleBoxEmpty, "With no gamepad input yet, the default Button focus stylebox should be invisible")

func test_focus_ring_becomes_visible_after_gamepad_input() -> void:
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressed = true
	GameManager._unhandled_input(joy_event)
	assert_true(GameManager.using_gamepad, "A joypad button event should flip using_gamepad true")
	var theme := ThemeDB.get_default_theme()
	assert_false(theme.get_stylebox("focus", "Button") is StyleBoxEmpty, "Once a gamepad is actually used, the real focus stylebox should be restored so gamepad players can see where they are")

	# Clean up so later tests (and the real game) start back in the
	# overwhelmingly-more-common mouse/keyboard state.
	var mouse_event := InputEventMouseMotion.new()
	GameManager._unhandled_input(mouse_event)
	assert_false(GameManager.using_gamepad, "Mouse motion should flip using_gamepad back false")
	assert_true(theme.get_stylebox("focus", "Button") is StyleBoxEmpty, "Returning to mouse input should hide the focus ring again")
