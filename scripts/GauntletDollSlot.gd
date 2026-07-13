extends Button

# Lets a carried-loot tile in the Gauntlet be dropped directly onto this
# doll slot to equip it, instead of needing the right-click menu every
# time. Set by GauntletInventoryPanel._ready() right after instancing.
var slot_name: String = ""

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("source", "") != "gauntlet_carried":
		return false
	var index = data.get("index", -1)
	if index < 0 or index >= GameManager.carried_loot.size():
		return false
	return GameManager.carried_loot[index].get("slot", "") == slot_name

func _drop_data(_pos: Vector2, data) -> void:
	var index = data.get("index", -1)
	if index >= 0 and index < GameManager.carried_loot.size():
		GameManager.gauntlet_equip_item(index)
