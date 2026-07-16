extends Area2D

@export var item_name: String = "Gold Bar"
@export var base_value: int = 50
@export var slot: String = "accessory"       # head, body, weapon, accessory, boots, backpack, key
@export var stat_type: String = "speed"      # speed, max_health, damage, fire_rate
@export var base_stat_value: float = 10.0
@export var icon_key: String = "generic"     # pistol, sword, chestplate, helmet, ring, watch, medkit, grenade, flare, rifle, boots, backpack, key
@export var rarity: String = "common"        # common, uncommon, rare, epic, legendary, mythic

# If set, this item is a key: it doesn't equip to any slot, it just sits in
# the backpack, and matching Door nodes (with the same key_id) check for it.
@export var door_key_id: String = ""

var player_in_range: bool = false
var final_value: int
var final_stat_value: float
var f_was_down: bool = false

@onready var prompt: Label = $Prompt
@onready var backdrop: Polygon2D = $Backdrop
@onready var icon_holder = $IconHolder

func _stat_label() -> String:
	match stat_type:
		"speed":
			return "+%s Speed" % final_stat_value
		"max_health":
			return "+%s Health" % final_stat_value
		"damage":
			return "+%s Damage" % final_stat_value
		"fire_rate":
			return "+%s Fire Rate" % final_stat_value
		_:
			return ""

func _ready() -> void:
	add_to_group("loot")

	var mult := GameManager.get_rarity_multiplier(rarity)
	final_value = int(round(base_value * mult))
	final_stat_value = snapped(base_stat_value * mult, 0.01)

	prompt.visible = false
	if door_key_id != "":
		prompt.text = "Press F: Pick up %s" % item_name
	else:
		prompt.text = "Press F: %s [%s - %s] (%s)" % [item_name, GameManager.get_rarity_label(rarity), slot.capitalize(), _stat_label()]
	backdrop.color = GameManager.get_rarity_color(rarity)
	icon_holder.icon_key = icon_key
	icon_holder.icon_color = Color(0.08, 0.08, 0.08, 1)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(_delta: float) -> void:
	var f_down := player_in_range and GameManager.is_action_pressed("interact")
	if f_down and not f_was_down:
		var item := {
			"name": item_name,
			"value": final_value,
			"slot": slot,
			"stat_type": stat_type,
			"stat_value": final_stat_value,
			"icon_key": icon_key,
			"rarity": rarity,
		}
		if door_key_id != "":
			item["door_key_id"] = door_key_id
		if GameManager.add_loot(item):
			queue_free()
	f_was_down = f_down
