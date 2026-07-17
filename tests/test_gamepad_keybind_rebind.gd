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

# Regression coverage (2026-07-17, controller audit) - set_joypad_binding()/
# set_keybind() used to blindly overwrite whatever was passed in, with no
# check for whether another action already used that same button/key. A
# player could silently bind two actions to the same physical input and
# both would fire together on every press, with no warning at all.
func test_set_joypad_binding_rejects_a_button_already_used_by_another_action() -> void:
	var original_jump: int = GameManager.get_joypad_binding("jump")
	var interact_binding: int = GameManager.get_joypad_binding("interact")

	var succeeded: bool = GameManager.set_joypad_binding("jump", interact_binding)

	assert_false(succeeded, "binding jump onto interact's existing button should be rejected")
	assert_eq(GameManager.get_joypad_binding("jump"), original_jump, "jump's binding should be untouched after a rejected rebind")
	assert_eq(GameManager.get_joypad_binding("interact"), interact_binding, "interact's binding should also be untouched")

	GameManager.set_joypad_binding("jump", original_jump)

func test_set_joypad_binding_rejects_conflicting_with_the_fixed_reload_button() -> void:
	# "reload" is deliberately not user-rebindable (fixed to X, same as
	# reload being keyboard-fixed to R) - but it must still count as
	# "occupied" when checking a REBINDABLE action against it, or a player
	# could bind e.g. nightvision onto X too and both would fire on every
	# X press.
	var original_nightvision: int = GameManager.get_joypad_binding("nightvision")
	var reload_binding: int = GameManager.get_joypad_binding("reload")

	var succeeded: bool = GameManager.set_joypad_binding("nightvision", reload_binding)

	assert_false(succeeded, "binding nightvision onto reload's fixed button should be rejected")
	assert_eq(GameManager.get_joypad_binding("nightvision"), original_nightvision)

	GameManager.set_joypad_binding("nightvision", original_nightvision)

func test_set_joypad_binding_allows_rebinding_an_action_to_its_own_current_button() -> void:
	# Re-confirming the same button for the same action must not count as
	# "already used by another action" - that would make it impossible to
	# ever re-press-and-confirm an unchanged binding.
	var current: int = GameManager.get_joypad_binding("chat")
	var succeeded: bool = GameManager.set_joypad_binding("chat", current)
	assert_true(succeeded)
	assert_eq(GameManager.get_joypad_binding("chat"), current)

func test_set_keybind_rejects_a_key_already_used_by_another_action() -> void:
	var original_jump: int = GameManager.get_keybind("jump")
	var interact_binding: int = GameManager.get_keybind("interact")

	var succeeded: bool = GameManager.set_keybind("jump", interact_binding)

	assert_false(succeeded, "binding jump onto interact's existing key should be rejected")
	assert_eq(GameManager.get_keybind("jump"), original_jump)
	assert_eq(GameManager.get_keybind("interact"), interact_binding)

	GameManager.set_keybind("jump", original_jump)

func test_every_rebindable_action_has_a_joypad_default() -> void:
	for action in ["interact", "prone", "jump", "dash", "nightvision", "chat", "inventory"]:
		assert_true(GameManager.JOYPAD_BUTTON_DEFAULTS.has(action), "Missing a JOYPAD_BUTTON_DEFAULTS entry for '%s'" % action)

# Regression coverage (2026-07-16) - a real save was found with "interact"
# rebound away from F to an unrelated key (M), with no memory of how or
# when, and no way back short of manually finding and re-rebinding the
# exact right row in Settings. reset_keybinds_to_defaults() (Settings'
# new "Reset to Defaults" button) is the escape hatch.
func test_reset_keybinds_to_defaults_restores_a_scrambled_keyboard_binding() -> void:
	var keybinds_before: Dictionary = GameManager.keybinds.duplicate()
	var joypad_before: Dictionary = GameManager.JOYPAD_BUTTON_BINDINGS.duplicate()

	GameManager.set_keybind("interact", KEY_M)
	GameManager.set_joypad_binding("jump", JOY_BUTTON_DPAD_LEFT)
	assert_ne(GameManager.get_keybind("interact"), KEY_F)

	GameManager.reset_keybinds_to_defaults()
	assert_eq(GameManager.get_keybind("interact"), KEY_F)
	for action in GameManager.KEYBIND_DEFAULTS:
		assert_eq(GameManager.get_keybind(action), GameManager.KEYBIND_DEFAULTS[action], "keybind '%s' should match its default after reset" % action)
	for action in GameManager.JOYPAD_BUTTON_DEFAULTS:
		assert_eq(GameManager.get_joypad_binding(action), GameManager.JOYPAD_BUTTON_DEFAULTS[action], "joypad binding '%s' should match its default after reset" % action)

	GameManager.keybinds = keybinds_before
	GameManager.JOYPAD_BUTTON_BINDINGS = joypad_before
