extends TestCase

# Regression coverage (2026-07-17 audit) - _update_egg_slot()'s reconnect
# guard checked is_connected() against the UNBOUND _on_slot_button, but the
# connection actually made was the BOUND _on_slot_button.bind(index) - a
# different Callable, so the guard never once detected an existing
# connection. _refresh_egg_slots() -> _update_egg_slot() runs every frame
# from _process() while this panel is visible and reuses the same 5 button
# nodes indefinitely, so a fresh duplicate connection stacked up every
# single frame, which would have fired _on_slot_button(index) more and
# more times per real click the longer the panel stayed open. Fixed with a
# plain "already wired" flag instead of relying on bound-Callable equality.
#
# Every new Button in this project auto-gets one Sfx.gd click-sound
# connection (see Sfx.gd:104) on top of whatever the panel itself wires -
# so the real regression to check for is that connection count stays FLAT
# across repeated refreshes, not that it equals some fixed literal.

const MainMenuScene := preload("res://scenes/MainMenu.tscn")

func test_repeated_refreshes_do_not_stack_duplicate_button_connections() -> void:
	var main_menu = MainMenuScene.instantiate()
	add_child(main_menu)
	var panel = main_menu.salvaged_beasts_panel

	panel._refresh_egg_slots()
	var baseline_counts: Array = []
	for i in range(GameManager.MAX_HATCH_SLOTS):
		var box: Control = panel.egg_slots_row.get_child(i)
		var btn: Button = box.get_node("VBox/ActionButton")
		baseline_counts.append(btn.pressed.get_connections().size())
		assert_gt(baseline_counts[i], 0, "slot %d's button should have at least one connection after the first refresh" % i)

	# Simulate several more _process() ticks worth of refreshes while the
	# panel is open (the real trigger for the bug - the same button nodes
	# get reused, never rebuilt, across every call).
	for i in range(5):
		panel._refresh_egg_slots()

	for i in range(GameManager.MAX_HATCH_SLOTS):
		var box: Control = panel.egg_slots_row.get_child(i)
		var btn: Button = box.get_node("VBox/ActionButton")
		assert_eq(btn.pressed.get_connections().size(), baseline_counts[i], "slot %d's connection count must not grow across repeated refreshes" % i)

	remove_child(main_menu)
	main_menu.queue_free()
