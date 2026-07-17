extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const SLOT_ORDER := ["scope", "mag", "barrel", "grip", "laser"]
const SLOT_LABELS := {
	"scope": "Scope", "mag": "Magazine", "barrel": "Barrel",
	"grip": "Grip", "laser": "Laser",
}

@onready var weapon_label: Label = $VBox/WeaponLabel
@onready var slot_list: VBoxContainer = $VBox/SlotList
@onready var close_button: Button = $VBox/CloseButton

# Which weapon we're editing - identified by object reference (not index)
# + which array it lives in ("carried" or "stash"). A plain index goes
# stale the moment anything earlier in that array is removed/reordered
# while this panel is left open (Sort, another Install consuming a spare
# attachment, etc.) - re-resolving by reference in _get_weapon() below
# means Install/Remove always operate on the actual weapon being shown,
# never a different item that happened to shift into a stale index.
var _weapon_ref: Dictionary = {}
var weapon_source: String = "carried"

func _ready() -> void:
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	visible = false

# index/source identify the WEAPON being edited (from the same right-click
# context menu that's used everywhere else); attachments are then pulled
# from and returned to that same source array (Backpack while in a raid,
# Stash while at the Hideout/Main Menu).
func open_for(index: int, source: String) -> void:
	weapon_source = source
	var arr := _source_array()
	_weapon_ref = arr[index] if index >= 0 and index < arr.size() else {}
	visible = true
	refresh()
	GameManager.focus_first_control(self)

func _source_array() -> Array:
	return GameManager.carried_loot if weapon_source == "carried" else GameManager.stash_items

func _get_weapon() -> Dictionary:
	if _weapon_ref.is_empty():
		return {}
	for item in _source_array():
		# is_same() (true reference identity) rather than == (deep value
		# equality) - two distinct items could otherwise have identical
		# contents and falsely match.
		if is_same(item, _weapon_ref) and item.get("slot", "") == "weapon":
			return item
	return {}

func refresh() -> void:
	for c in slot_list.get_children():
		slot_list.remove_child(c)
		c.queue_free()
	var weapon := _get_weapon()
	if weapon.is_empty():
		weapon_label.text = "Weapon not found - it may have moved."
		return
	weapon_label.text = "Weapon: %s" % weapon.get("name", "?")
	var attachments := GameManager.get_weapon_attachments_for(weapon)
	for slot_key in SLOT_ORDER:
		slot_list.add_child(_make_row(weapon, slot_key, attachments.get(slot_key)))

func _make_row(weapon: Dictionary, slot_key: String, installed) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 58)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var label_box := VBoxContainer.new()
	label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = SLOT_LABELS.get(slot_key, slot_key.capitalize())
	title.add_theme_font_size_override("font_size", 15)
	label_box.add_child(title)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.75)
	label_box.add_child(sub)
	hbox.add_child(label_box)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 44)
	var is_carried: bool = weapon_source == "carried"

	if installed != null:
		sub.text = "Installed: %s" % installed.get("name", "?")
		btn.text = "Remove"
		btn.pressed.connect(func():
			GameManager.remove_attachment_from_item(weapon, slot_key, _source_array(), is_carried)
			refresh()
		)
	else:
		var found_index := _find_attachment(slot_key)
		var location: String = "Backpack" if is_carried else "Stash"
		if found_index >= 0:
			var item: Dictionary = _source_array()[found_index]
			sub.text = "In %s: %s" % [location, item.get("name", "?")]
			btn.text = "Install"
			btn.pressed.connect(func():
				# Re-resolve at click time instead of trusting the index
				# captured when this row was built - the Stash's Sort
				# button (and others) stay clickable behind this panel,
				# and a reorder in between could shift which item that
				# stale index actually pointed at.
				var live_index := _find_attachment(slot_key)
				if live_index < 0:
					refresh()
					return
				GameManager.install_attachment_on_item(weapon, _source_array(), live_index, is_carried)
				refresh()
			)
		else:
			sub.text = "Empty - none in %s" % location
			btn.text = "Install"
			btn.disabled = true

	hbox.add_child(btn)
	return row

func _find_attachment(slot_key: String) -> int:
	var arr := _source_array()
	for i in range(arr.size()):
		var item = arr[i]
		if item.get("slot", "") == "attachment" and item.get("attachment_slot", "") == slot_key:
			return i
	return -1
