extends TestCase

# Settings.gd's Controller section is a hand-written reference string
# (not generated live from GameManager.JOYPAD_BUTTON_BINDINGS), matching
# this project's existing "catalogs stay hand-curated" convention - these
# tests are the safety net: if a binding ever changes, one of these should
# fail loudly rather than the Settings screen silently showing a stale
# button next to the wrong action.

func test_controller_status_shows_not_detected_with_no_controller() -> void:
	var scene := preload("res://scenes/Settings.tscn")
	var settings = scene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	settings._show_keybinds()
	await get_tree().process_frame

	assert_eq(Input.get_connected_joypads(), [] as Array, "Sanity check for this test environment: no real controller connected")
	assert_true(settings.controller_status_label.text.contains("No controller detected"), "With nothing connected, the status label should say so")

	remove_child(settings)
	settings.queue_free()

func test_controller_mapping_matches_the_actual_runtime_bindings() -> void:
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["interact"], JOY_BUTTON_A, "Settings' reference text claims Interact is A")
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["jump"], JOY_BUTTON_Y, "Settings' reference text claims Jump is Y")
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["dash"], JOY_BUTTON_B, "Settings' reference text claims Dash is B")
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["nightvision"], JOY_BUTTON_DPAD_DOWN, "Settings' reference text claims Nightvision is D-Pad Down")
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["reload"], JOY_BUTTON_X, "Settings' reference text claims Reload is X (fixed, not user-rebindable, matching the rest of the genre)")
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["prone"], JOY_BUTTON_LEFT_STICK, "Settings' reference text claims Prone is Left Stick Click")
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["chat"], JOY_BUTTON_BACK, "Settings' reference text claims Chat is Back")
	assert_eq(GameManager.JOYPAD_BUTTON_BINDINGS["inventory"], JOY_BUTTON_START, "Settings' reference text claims Inventory is Start")
