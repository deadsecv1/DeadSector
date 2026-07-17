extends TestCase

# Regression coverage for the shared gamepad UI navigation helpers
# (GameManager.focus_first_control/try_gamepad_pickup_or_place/
# cancel_gamepad_hold) - the foundation every panel's gamepad support is
# built on, so a bug here would silently break navigation everywhere at
# once rather than in just one screen.

# Minimal test double standing in for a real inventory slot - implements
# the same 3 drag-and-drop methods InventoryTile.gd/EquipSlot.gd/etc.
# already do, just with a plain "item" Variant instead of real game data.
class FakeSlot:
	extends Control
	var item: Variant = null
	var accepts: bool = true

	func _get_drag_data(_pos: Vector2) -> Variant:
		return item

	func _can_drop_data(_pos: Vector2, _data: Variant) -> bool:
		return accepts

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		item = data

func before_each_file() -> void:
	GameManager.cancel_gamepad_hold()

func test_focus_first_control_finds_the_first_focusable_descendant() -> void:
	var root := Control.new()
	var not_focusable := Control.new()
	not_focusable.focus_mode = Control.FOCUS_NONE
	root.add_child(not_focusable)
	var button := Button.new()
	button.text = "Target"
	root.add_child(button)
	add_child(root)

	GameManager.focus_first_control(root)
	assert_true(button.has_focus(), "focus_first_control should land on the first FOCUS_ALL descendant, skipping FOCUS_NONE ones")

	remove_child(root)
	root.queue_free()

# Regression coverage (2026-07-17, controller audit) - Godot's newer
# accessibility framework gives RichTextLabel (and potentially other
# controls) a default focus_mode of FOCUS_ACCESSIBILITY (screen-reader-
# only) rather than FOCUS_NONE. The old `!= FOCUS_NONE` check treated that
# as a real focusable target and called grab_focus() on it, which just
# warns and silently does nothing outside an active screen reader -
# leaving a gamepad player with nothing actually focused whenever a panel
# has a RichTextLabel/similar control before its real buttons (exactly
# LoreIntro.gd's shape: lore text above its Continue/Enter buttons).
func test_focus_first_control_skips_accessibility_only_controls() -> void:
	var root := Control.new()
	var rich_text := RichTextLabel.new()
	assert_eq(rich_text.focus_mode, Control.FOCUS_ACCESSIBILITY, "test assumption: RichTextLabel defaults to FOCUS_ACCESSIBILITY, not FOCUS_NONE")
	root.add_child(rich_text)
	var button := Button.new()
	button.text = "Target"
	root.add_child(button)
	add_child(root)

	GameManager.focus_first_control(root)
	assert_true(button.has_focus(), "focus_first_control must skip an accessibility-only control and land on the real button instead")

	remove_child(root)
	root.queue_free()

func test_focus_first_control_is_safe_with_nothing_focusable() -> void:
	var root := Control.new()
	var not_focusable := Control.new()
	not_focusable.focus_mode = Control.FOCUS_NONE
	root.add_child(not_focusable)
	add_child(root)
	GameManager.focus_first_control(root) # should not error
	assert_true(true, "focus_first_control with no focusable children should not crash")
	remove_child(root)

func test_focus_first_control_skips_a_disabled_button() -> void:
	# A disabled BaseButton keeps focus_mode == FOCUS_ALL and visible == true -
	# without an explicit disabled check, an unaffordable recruit card or
	# DeathScreen's "Killed By" button (disabled when there was no
	# attacker) would steal initial focus and strand a gamepad player on
	# a button that does nothing when pressed.
	var root := Control.new()
	var disabled_button := Button.new()
	disabled_button.text = "Disabled"
	disabled_button.disabled = true
	root.add_child(disabled_button)
	var enabled_button := Button.new()
	enabled_button.text = "Enabled"
	root.add_child(enabled_button)
	add_child(root)

	GameManager.focus_first_control(root)
	assert_true(enabled_button.has_focus(), "focus_first_control should skip a disabled button and land on the next enabled one")

	remove_child(root)
	root.queue_free()

func test_pickup_then_place_moves_the_item_via_the_slots_own_drop_data() -> void:
	var slot_a := FakeSlot.new()
	slot_a.item = "sword"
	var slot_b := FakeSlot.new()
	slot_b.item = null
	slot_b.accepts = true
	add_child(slot_a)
	add_child(slot_b)

	var picked_up: bool = GameManager.try_gamepad_pickup_or_place(slot_a)
	assert_true(picked_up, "Picking up from a slot with an item should succeed")
	assert_eq(GameManager.gamepad_held_data, "sword", "Held data should be exactly what the source slot's _get_drag_data returned")
	assert_eq(GameManager.gamepad_held_source, slot_a, "Held source should track which slot the item was picked up from")

	var placed: bool = GameManager.try_gamepad_pickup_or_place(slot_b)
	assert_true(placed, "Placing into an accepting slot should succeed")
	assert_eq(slot_b.item, "sword", "Target slot's _drop_data should have actually received the held item")
	assert_null(GameManager.gamepad_held_data, "Held data should clear after a successful place")
	assert_null(GameManager.gamepad_held_source, "Held source should clear after a successful place")

	remove_child(slot_a)
	remove_child(slot_b)
	slot_a.queue_free()
	slot_b.queue_free()

func test_place_into_a_rejecting_slot_keeps_the_item_held_for_another_try() -> void:
	var slot_a := FakeSlot.new()
	slot_a.item = "shield"
	var slot_b := FakeSlot.new()
	slot_b.accepts = false
	add_child(slot_a)
	add_child(slot_b)

	GameManager.try_gamepad_pickup_or_place(slot_a)
	GameManager.try_gamepad_pickup_or_place(slot_b)
	assert_eq(GameManager.gamepad_held_data, "shield", "A rejected placement should leave the item still held, not silently drop it")
	assert_null(slot_b.item, "A rejecting slot's _drop_data should never actually be called")

	# This test's whole point is leaving a hold dangling past its own two
	# calls above - clean it up now that both assertions have run, or the
	# next test file to touch gamepad_held_data inherits a fake String
	# "held" item instead of starting from a clean null state.
	GameManager.cancel_gamepad_hold()
	remove_child(slot_a)
	remove_child(slot_b)
	slot_a.queue_free()
	slot_b.queue_free()

func test_picking_up_an_empty_slot_does_nothing() -> void:
	var slot_a := FakeSlot.new()
	slot_a.item = null
	add_child(slot_a)
	var picked_up: bool = GameManager.try_gamepad_pickup_or_place(slot_a)
	assert_false(picked_up, "A slot with no item (_get_drag_data returns null) should not start a hold")
	assert_null(GameManager.gamepad_held_data)
	remove_child(slot_a)
	slot_a.queue_free()

func test_cancel_gamepad_hold_clears_state_without_calling_drop_data() -> void:
	var slot_a := FakeSlot.new()
	slot_a.item = "bow"
	add_child(slot_a)
	GameManager.try_gamepad_pickup_or_place(slot_a)
	GameManager.cancel_gamepad_hold()
	assert_null(GameManager.gamepad_held_data, "Canceling a hold should clear the held data")
	assert_eq(slot_a.item, "bow", "Canceling should leave the source slot's item untouched - nothing actually moved")
	remove_child(slot_a)
	slot_a.queue_free()
