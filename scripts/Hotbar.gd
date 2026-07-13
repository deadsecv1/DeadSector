extends HBoxContainer

# 5-slot hotbar. Slot 1 always mirrors the currently equipped weapon
# (informational - only one weapon can be equipped at a time). Slots 2-5
# auto-fill with any "consumable" items in the Backpack (heal items,
# grenades) in the order they were picked up. Scroll wheel or number keys
# 1-5 just SELECT a slot (highlight it) - nothing is used until the player
# actually left-clicks in-game with that slot active (see Player.gd).

const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

var selected_index: int = 0
var _key_states: Array = [false, false, false, false, false]

@onready var slots: Array = [$Slot1, $Slot2, $Slot3, $Slot4, $Slot5]
@onready var icons: Array = [$Slot1/Icon1, $Slot2/Icon2, $Slot3/Icon3, $Slot4/Icon4, $Slot5/Icon5]

func _ready() -> void:
	GameManager.active_hotbar_slot = 0
	selected_index = 0
	_update_highlight()

func _process(_delta: float) -> void:
	_refresh_slots()
	if _input_blocked():
		return
	for i in range(5):
		var down := Input.is_key_pressed(KEYS[i])
		if down and not _key_states[i]:
			_select(i)
		_key_states[i] = down

func _unhandled_input(event: InputEvent) -> void:
	if _input_blocked():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_selection(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_selection(1)

func _input_blocked() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	return player != null and player.input_locked

func _move_selection(dir: int) -> void:
	selected_index = (selected_index + dir + 5) % 5
	_update_highlight()

func _select(index: int) -> void:
	selected_index = index
	GameManager.active_hotbar_slot = index
	_update_highlight()

func _get_consumable_entries() -> Array:
	return GameManager.get_consumable_entries()

func _refresh_slots() -> void:
	var weapon = GameManager.equipped_items.get("weapon")
	if weapon != null:
		icons[0].icon_key = weapon.get("icon_key", "pistol")
		icons[0].icon_color = GameManager.get_rarity_color(weapon.get("rarity", "common"))
		slots[0].tooltip_text = weapon.get("name", "Weapon")
	else:
		icons[0].icon_key = "pistol"
		icons[0].icon_color = Color(0.5, 0.5, 0.5, 1)
		slots[0].tooltip_text = "Unarmed"
	icons[0].visible = true
	icons[0].queue_redraw()

	var entries := _get_consumable_entries()
	if selected_index > 0 and selected_index - 1 >= entries.size():
		# The item we had selected got used/dropped/sold - fall back to
		# the weapon slot instead of silently pointing at nothing.
		_select(0)
	for i in range(4):
		var slot_index := i + 1
		if i < entries.size():
			var item: Dictionary = entries[i]["item"]
			icons[slot_index].icon_key = item.get("icon_key", "medkit")
			icons[slot_index].icon_color = GameManager.get_rarity_color(item.get("rarity", "common"))
			icons[slot_index].visible = true
			slots[slot_index].tooltip_text = item.get("name", "Item")
		else:
			icons[slot_index].visible = false
			slots[slot_index].tooltip_text = "Empty"
		icons[slot_index].queue_redraw()

func _update_highlight() -> void:
	for i in range(5):
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.09, 0.08, 0.85)
		sb.set_corner_radius_all(4)
		if i == selected_index:
			sb.border_color = Color(1, 0.8, 0.3, 1)
			sb.set_border_width_all(2)
		else:
			sb.border_color = Color(1, 1, 1, 0.18)
			sb.set_border_width_all(1)
		slots[i].add_theme_stylebox_override("panel", sb)
