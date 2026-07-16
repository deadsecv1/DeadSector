extends TestCase

# Regression coverage for the project-wide sweep that gave every popup's
# existing "Escape closes this" handler a gamepad equivalent (D-pad Up,
# see GameManager.is_pause_pressed()) - 64 files got the exact same
# mechanical change, so this tests ONE representative popup rather than
# duplicating the same assertion 64 times. If this pattern regresses here,
# it regressed everywhere at once.

func _dpad_up_event() -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_DPAD_UP
	ev.pressed = true
	return ev

func test_gamepad_dpad_up_closes_backpack_storage_popup() -> void:
	var PopupScene := preload("res://scenes/BackpackStoragePopup.tscn")
	var popup = PopupScene.instantiate()
	add_child(popup)
	popup.open()
	await get_tree().process_frame
	assert_true(popup.visible, "Popup should be open before the test presses anything")

	# A single-element array, not a bare bool - GDScript lambdas capture
	# local variables by value, so `closed_fired = true` inside the lambda
	# would only mutate a private copy; mutating the contents of a
	# captured Array (a reference type) is what actually reaches back out.
	var closed_fired := [false]
	popup.closed.connect(func(): closed_fired[0] = true)
	popup._unhandled_input(_dpad_up_event())
	assert_true(closed_fired[0], "A synthetic D-pad Up press should trigger the same 'closed' signal Escape does")

	remove_child(popup)
	popup.queue_free()

func test_gamepad_dpad_up_does_nothing_while_popup_already_closed() -> void:
	var PopupScene := preload("res://scenes/BackpackStoragePopup.tscn")
	var popup = PopupScene.instantiate()
	add_child(popup)
	await get_tree().process_frame
	assert_false(popup.visible, "Popup should start closed (matches _ready() setting visible = false)")

	var closed_fired := [false]
	popup.closed.connect(func(): closed_fired[0] = true)
	popup._unhandled_input(_dpad_up_event())
	assert_false(closed_fired[0], "A D-pad Up press should be a no-op while the popup isn't even open")

	remove_child(popup)
	popup.queue_free()
