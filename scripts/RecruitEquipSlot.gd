extends Button

# One equipment slot on a Recruit's customization doll. Only accepts
# drags coming from the Stash (recruits are gearing up back at the
# Hideout, not mid-run).

@export var slot_name: String = "head"

var recruit_id: String = "clarity"
var current_item = null

signal changed

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)

func _make_custom_tooltip(_for_text: String) -> Control:
	if current_item == null:
		return null
	return ItemTooltip.build(current_item)

func _on_pressed() -> void:
	if current_item != null:
		GameManager.unequip_recruit_item(recruit_id, slot_name)
		changed.emit()

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("source", "") != "stash":
		return false
	var index = data.get("index", -1)
	if index < 0 or index >= GameManager.stash_items.size():
		return false
	return GameManager.stash_items[index].get("slot", "") == slot_name

func _drop_data(_pos: Vector2, data) -> void:
	var index = data.get("index", -1)
	GameManager.equip_recruit_item(recruit_id, index)
	changed.emit()
