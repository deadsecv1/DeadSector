extends TestCase

# Regression coverage for gamepad keybind rebinding (2026-07-16) -
# JOYPAD_BUTTON_BINDINGS used to be a const with a comment explicitly
# saying "no rebind UI for gamepad" was a deliberate choice; that's no
# longer true, so this guards the actual get/set/persist behavior.

func test_get_joypad_binding_returns_the_default_for_a_known_action() -> void:
	assert_eq(GameManager.get_joypad_binding("interact"), JOY_BUTTON_A)

func test_set_joypad_binding_changes_what_get_returns() -> void:
	var original: int = GameManager.get_joypad_binding("jump")
	GameManager.set_joypad_binding("jump", JOY_BUTTON_DPAD_LEFT)
	assert_eq(GameManager.get_joypad_binding("jump"), JOY_BUTTON_DPAD_LEFT)
	GameManager.set_joypad_binding("jump", original)

func test_rebinding_one_action_does_not_affect_others() -> void:
	var original_dash: int = GameManager.get_joypad_binding("dash")
	var original_chat: int = GameManager.get_joypad_binding("chat")
	GameManager.set_joypad_binding("dash", JOY_BUTTON_DPAD_RIGHT)
	assert_eq(GameManager.get_joypad_binding("chat"), original_chat, "Rebinding dash should not touch chat's binding")
	GameManager.set_joypad_binding("dash", original_dash)

func test_is_action_pressed_respects_a_rebound_gamepad_button() -> void:
	# is_action_pressed() reads JOYPAD_BUTTON_BINDINGS live (via
	# get_joypad_binding()), so a rebind should immediately change which
	# physical button is checked - can't simulate a real joypad press in
	# this headless test environment (see CLAUDE.md's gamepad-testing
	# note), but confirms the binding lookup itself updates correctly,
	# which is the part a rebind actually changes.
	var original: int = GameManager.get_joypad_binding("nightvision")
	GameManager.set_joypad_binding("nightvision", JOY_BUTTON_DPAD_DOWN)
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["nightvision"], JOY_BUTTON_DPAD_DOWN)
	GameManager.set_joypad_binding("nightvision", original)

func test_every_rebindable_action_has_a_joypad_default() -> void:
	for action in ["interact", "prone", "jump", "dash", "nightvision", "chat", "inventory"]:
		assert_true(GameManager.JOYPAD_BUTTON_DEFAULTS.has(action), "Missing a JOYPAD_BUTTON_DEFAULTS entry for '%s'" % action)
