extends Panel

signal inspect_requested(item: Dictionary)
signal attachments_requested(index: int, source: String, item: Dictionary)
signal skins_requested(item: Dictionary)
signal open_bag_requested(index: int, source: String, item: Dictionary)
signal rotate_requested(index: int, source: String, item: Dictionary)
signal equip_requested(index: int, source: String, item: Dictionary)
signal use_requested(index: int, source: String, item: Dictionary)
signal unequip_requested(slot_name: String)
signal deposit_egg_requested(index: int, source: String, item: Dictionary)
signal tag_requested(index: int, source: String, item: Dictionary)

@export var show_attachments_option: bool = true

var current_item: Dictionary = {}
var is_equipped_context: bool = false
var current_slot_name: String = ""

@onready var equip_button: Button = $VBox/EquipButton
@onready var inspect_button: Button = $VBox/InspectButton
@onready var use_button: Button = $VBox/UseButton
@onready var attachments_button: Button = $VBox/AttachmentsButton
@onready var skins_button: Button = $VBox/SkinsButton
@onready var open_bag_button: Button = $VBox/OpenBagButton
@onready var deposit_egg_button: Button = $VBox/DepositEggButton
@onready var rotate_button: Button = $VBox/RotateButton
@onready var tag_button: Button = $VBox/TagButton
@onready var cancel_button: Button = $VBox/CancelButton

var current_index: int = -1
var current_source: String = ""

func _ready() -> void:
	visible = false
	equip_button.pressed.connect(func():
		visible = false
		if is_equipped_context:
			unequip_requested.emit(current_slot_name)
		else:
			equip_requested.emit(current_index, current_source, current_item)
	)
	inspect_button.pressed.connect(func():
		visible = false
		inspect_requested.emit(current_item)
	)
	use_button.pressed.connect(func():
		visible = false
		use_requested.emit(current_index, current_source, current_item)
	)
	attachments_button.pressed.connect(func():
		visible = false
		attachments_requested.emit(current_index, current_source, current_item)
	)
	skins_button.pressed.connect(func():
		visible = false
		skins_requested.emit(current_item)
	)
	open_bag_button.pressed.connect(func():
		visible = false
		open_bag_requested.emit(current_index, current_source, current_item)
	)
	deposit_egg_button.pressed.connect(func():
		visible = false
		deposit_egg_requested.emit(current_index, current_source, current_item)
	)
	rotate_button.pressed.connect(func():
		visible = false
		rotate_requested.emit(current_index, current_source, current_item)
	)
	tag_button.pressed.connect(func():
		visible = false
		tag_requested.emit(current_index, current_source, current_item)
	)
	cancel_button.pressed.connect(func(): visible = false)

# Clicking (or right-clicking) anywhere outside the menu closes it -
# no need to hit Cancel every time. Uses _input (not gui_input) since
# it needs to see clicks that land outside this Control's own rect.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not get_global_rect().has_point(event.global_position):
			visible = false

func open_for(index: int, source: String, item: Dictionary, at_position: Vector2) -> void:
	current_index = index
	current_source = source
	current_item = item
	is_equipped_context = false
	current_slot_name = ""
	var is_bag: bool = item.get("slot", "") == "lootbag"
	var is_pet_case: bool = item.get("slot", "") == "pet_case"
	var is_backpack_item: bool = item.get("slot", "") == "backpack"
	var is_egg: bool = item.get("slot", "") == "egg"
	var is_specialized_case: bool = item.get("slot", "") in ["medical_case", "gun_case", "armor_case", "key_case"]
	equip_button.text = "Equip"
	equip_button.visible = not is_bag and not is_pet_case and not is_egg and not is_specialized_case
	inspect_button.visible = true
	# Available from both the in-raid Backpack and the Stash. There's no
	# live HP/Hunger to restore outside a raid, so Stash.gd's own
	# use_requested handler gives an explanatory toast instead of
	# applying an effect there - see Stash.gd for that path.
	use_button.visible = source in ["carried", "stash"] and item.get("consumable_type", "") in ["heal", "food"]
	attachments_button.visible = show_attachments_option and not is_bag and not is_pet_case and not is_specialized_case and item.get("slot", "") == "weapon"
	skins_button.visible = not is_bag and not is_pet_case and not is_egg and not is_specialized_case and GameManager.get_skins_for(item.get("icon_key", "")).size() > 0
	open_bag_button.visible = is_bag or is_pet_case or is_backpack_item or is_specialized_case
	open_bag_button.text = "Open Bag" if is_bag else "Open"
	deposit_egg_button.visible = is_egg and source == "stash"
	var fp := GameManager.get_item_footprint(item)
	rotate_button.visible = (source == "stash" or source == "carried") and fp.x != fp.y
	tag_button.visible = is_bag or is_pet_case

	_position_and_show(at_position)

# Opens the same menu for an item currently equipped in a doll slot -
# right-click on gear you're wearing gets the same "pick from a menu"
# treatment as everything else, instead of instantly unequipping.
func open_for_equipped(slot_name: String, item: Dictionary, at_position: Vector2) -> void:
	current_index = -1
	current_source = "equipped"
	current_item = item
	is_equipped_context = true
	current_slot_name = slot_name
	equip_button.text = "Unequip"
	equip_button.visible = true
	inspect_button.visible = true
	use_button.visible = false
	attachments_button.visible = show_attachments_option and item.get("slot", "") == "weapon"
	skins_button.visible = GameManager.get_skins_for(item.get("icon_key", "")).size() > 0
	open_bag_button.visible = item.get("slot", "") == "backpack"
	open_bag_button.text = "Open"
	deposit_egg_button.visible = false
	rotate_button.visible = false
	tag_button.visible = false

	_position_and_show(at_position)

func _position_and_show(at_position: Vector2) -> void:
	var vp := get_viewport_rect().size
	var menu_size := custom_minimum_size
	position = Vector2(
		clamp(at_position.x, 0.0, max(0.0, vp.x - menu_size.x)),
		clamp(at_position.y, 0.0, max(0.0, vp.y - menu_size.y))
	)
	visible = true
