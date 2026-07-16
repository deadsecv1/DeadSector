extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var title_label: Label = $VBox/TitleLabel
@onready var rarity_label: Label = $VBox/RarityLabel
@onready var hint_label: Label = $VBox/HintLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var showcase: Control = $VBox/Showcase
@onready var close_button: Button = $VBox/CloseButton

var icon_node: Control = null
var dragging: bool = false

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): closed.emit())

func open_for(item: Dictionary) -> void:
	visible = true
	title_label.text = item.get("name", "?")
	var rarity: String = item.get("rarity", "common")
	rarity_label.text = GameManager.get_rarity_label(rarity)
	rarity_label.add_theme_color_override("font_color", GameManager.get_display_color(item))
	desc_label.text = _build_description(item)

	if icon_node != null and is_instance_valid(icon_node):
		icon_node.queue_free()
	icon_node = ItemIconScene.instantiate()
	icon_node.icon_key = item.get("icon_key", "generic")
	icon_node.icon_color = GameManager.get_display_color(item)
	# Center via anchors (50%/50% anchor point, offsets forming a 120x120
	# box around it) rather than computing a pixel position from
	# showcase.size directly - reading .size the instant the panel becomes
	# visible can catch a stale/unresolved value before Godot's finished
	# laying out the newly-shown container, which was landing the icon
	# near the top-left corner (partly off-screen) instead of centered.
	icon_node.anchor_left = 0.5
	icon_node.anchor_top = 0.5
	icon_node.anchor_right = 0.5
	icon_node.anchor_bottom = 0.5
	icon_node.offset_left = -60
	icon_node.offset_top = -60
	icon_node.offset_right = 60
	icon_node.offset_bottom = 60
	icon_node.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_node.mouse_default_cursor_shape = Control.CURSOR_DRAG
	icon_node.gui_input.connect(_on_icon_input)
	showcase.add_child(icon_node)
	GameManager.focus_first_control(self)

# Individual loot rolls don't carry hand-written lore, so the description
# is built from what's actually known about the item: its category, its
# stat bonus (if any), and its value - a real description, just composed
# rather than authored line-by-line for every possible item name.
const CATEGORY_FLAVOR := {
	"weapon": "A weapon, recovered from the Sector - reliable enough to still be worth carrying.",
	"head": "Headgear. Whatever protection it still offers, it's earned the scuffs to prove it.",
	"body": "Body armor. Every dent in it is a hit that didn't get through to something softer.",
	"boots": "Footwear built for ground that doesn't forgive a bad step.",
	"backpack": "A pack for carrying more out than you walked in with.",
	"accessory": "A small piece of gear that punches above its size.",
	"key": "Opens something specific somewhere in the Sector. Useless anywhere else.",
	"trophy": "Proof of something that happened out there. Worth more as a story than as scrap.",
	"lootbag": "Unopened. Could be anything - that's the whole appeal.",
	"pet_case": "Grid storage built to hold every companion you've collected.",
}
const ICON_FLAVOR := {
	"medkit": "Field medicine. Patches you up enough to keep moving, not enough to feel it.",
	"grenade": "Standard frag. Pull, throw, don't linger.",
	"smoke_grenade": "Fills a room with cover in seconds - loud entrances only.",
	"stun_grenade": "Rattles anything nearby long enough to make the next move yours.",
	"molotov": "Improvised, unstable, and extremely convincing up close.",
	"flare": "Burns bright enough to mark a spot from across the map.",
	"blueprint": "Someone's notes on how to build something better. Worth researching.",
	"egg": "Warm to the touch. Something's in there, waiting on a hatchery.",
	"gpu": "High-end tech, stripped from a rig that isn't running anymore.",
	"gpcoin": "A currency nobody official ever backed. Spends fine out here anyway.",
	"dogtag": "Somebody's ID, somewhere they didn't expect to leave it.",
	"canned_food": "Shelf-stable, unglamorous, still edible. That's a win in the Sector.",
	"batteries": "Charge left in them is anyone's guess until you actually need it.",
	"screws": "Small, plentiful, and somehow always the thing you're short on.",
	"duct_tape": "Holds gear, wounds, and doors together with equal confidence.",
	"soap": "A small piece of normal life, out here of all places.",
	"chlorine": "Sharp-smelling and useful for exactly the reasons you'd guess.",
	"toothpaste": "Mundane. Somehow still worth fighting over at the right price.",
	"mil_filter": "Military-grade filtration, salvaged off something that needed clean air badly.",
	"paracord": "A few feet of cord that's talked its way out of a dozen bad situations.",
	"hard_plate": "Raw plating, waiting to be worked into something wearable.",
	"cloth": "Torn from somewhere. Still has plenty of uses left in it.",
	"antiseptic": "Stings first, helps after. Standard field medicine tradeoff.",
}

func _build_description(item: Dictionary) -> String:
	var parts: Array = []
	var icon_key: String = item.get("icon_key", "")
	var slot: String = item.get("slot", "")
	var real_desc: String = str(item.get("desc", ""))
	if real_desc != "":
		# A hand-written description (weapons, keys, event/Alpha gear all
		# carry one) always wins over the generic flavor text below - it's
		# more specific and more interesting than a category-wide line.
		parts.append(real_desc)
	elif ICON_FLAVOR.has(icon_key):
		parts.append(ICON_FLAVOR[icon_key])
	elif CATEGORY_FLAVOR.has(slot):
		parts.append(CATEGORY_FLAVOR[slot])
	else:
		parts.append("Salvaged gear from the Sector - useful to someone, if not to you.")

	if slot == "weapon":
		var effect_text: String = GameManager.get_weapon_effect_text(icon_key)
		if effect_text != "":
			parts.append(effect_text)
		var rarity: String = item.get("rarity", "common")
		if rarity in ["exotic", "multiversal", "divine"]:
			parts.append("Fires a 3-5 shot burst instead of a single round - this rarity earns it.")
	elif slot in ["head", "body", "boots", "backpack", "accessory"]:
		var armor_effect_text: String = GameManager.get_armor_effect_text(slot, str(item.get("stat_type", "")))
		if armor_effect_text != "":
			parts.append(armor_effect_text)

	var stat_label_map := {
		"speed": "Speed", "max_health": "Max Health", "damage": "Damage", "fire_rate": "Fire Rate",
		"loot_sense": "Loot Sense", "crit_chance": "Crit Chance", "vision_range": "Vision Range",
		"reload_speed": "Reload Speed", "health_regen": "HP/s Regen", "armor": "Armor", "ammo_reserve": "Reserve Ammo",
	}
	var stat_type: String = item.get("stat_type", "")
	var stat_value = item.get("stat_value", 0.0)
	if stat_type != "" and float(stat_value) != 0.0:
		parts.append("Grants +%s %s when equipped." % [str(stat_value), stat_label_map.get(stat_type, stat_type.capitalize())])
	var stat_type_2: String = item.get("stat_type_2", "")
	var stat_value_2 = item.get("stat_value_2", 0.0)
	if stat_type_2 != "" and float(stat_value_2) != 0.0:
		parts.append("Also grants +%s %s." % [str(stat_value_2), stat_label_map.get(stat_type_2, stat_type_2.capitalize())])

	var value: int = int(item.get("value", 0))
	if value > 0:
		parts.append("Worth %d Rubles." % value)

	if item.get("alpha_only", false):
		parts.append("Alpha Exclusive - only available during the Alpha test period.")
	elif item.get("beta_only", false):
		parts.append("Tech Test Exclusive - only available during the pre-Alpha Tech Test.")

	if item.get("alpha_only", false) or item.get("beta_only", false):
		parts.append("Character Bound - stays equipped even when you die, unlike everything else.")

	return " ".join(parts)

func _on_icon_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		var new_pos: Vector2 = icon_node.position + event.relative
		var max_pos: Vector2 = showcase.size - icon_node.size
		icon_node.position = Vector2(
			clamp(new_pos.x, 0.0, max(0.0, max_pos.x)),
			clamp(new_pos.y, 0.0, max(0.0, max_pos.y))
		)
