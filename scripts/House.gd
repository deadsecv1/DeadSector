extends Node2D

# Procedurally builds a complete lootable house - perimeter walls, a front
# door, an inner vault room behind a locked door with a chest, a roof, a
# name tag, and the roof-fade InteriorZone - from a handful of exported
# parameters instead of the ~140 lines of hand-placed, absolute-position
# nodes each original house (Main.tscn's Ashen House/Blackthorn Estate)
# needed. Everything here is built in LOCAL space and parented to this
# node itself, so an entire house is just one node with a position in a
# map's .tscn. Preserves the exact walls/door/vault/chest/roof shape those
# original houses use - RoofFade.gd (already proven there) still works
# unchanged since it just looks for a "Roof" sibling of "InteriorZone".

@export var house_name: String = "Safehouse"
@export var house_size: Vector2 = Vector2(400, 300)
@export var vault_width: float = 150.0
@export var wall_thickness: float = 25.0
@export var door_width: float = 90.0
@export var wall_color: Color = Color(0.35, 0.35, 0.42, 1)
@export var roof_color: Color = Color(0.18, 0.13, 0.1, 1)
@export var key_id: String = ""
@export var key_label: String = "Key"

@export_group("Vault Chest")
@export var chest_item_name: String = "Salvaged Gear"
@export var chest_value: int = 90
@export var chest_slot: String = "weapon"
@export var chest_stat_type: String = "damage"
@export var chest_stat_value: float = 10.0
@export var chest_icon_key: String = "pistol"
@export var chest_rarity: String = "uncommon"
@export var grants_artifacts: int = 1

const WallScene := preload("res://scenes/Wall.tscn")
const DoorScene := preload("res://scenes/Door.tscn")
const ChestScene := preload("res://scenes/Chest.tscn")

func _ready() -> void:
	_build()

func _add_wall(local_pos: Vector2, size: Vector2) -> void:
	var w = WallScene.instantiate()
	w.size = size
	w.wall_color = wall_color
	add_child(w)
	w.position = local_pos

func _build() -> void:
	var half := house_size / 2.0
	var main_width: float = house_size.x - vault_width
	var main_center_x: float = -half.x + main_width / 2.0
	var vault_center_x: float = half.x - vault_width / 2.0
	var inner_x: float = -half.x + main_width
	var t := wall_thickness

	# Main room perimeter (front door gap centered in the bottom wall).
	_add_wall(Vector2(main_center_x, -half.y), Vector2(main_width + t, t))
	var door_gap_half: float = door_width / 2.0
	var bl_width: float = main_width / 2.0 - door_gap_half
	_add_wall(Vector2(-half.x + bl_width / 2.0, half.y), Vector2(bl_width, t))
	_add_wall(Vector2(main_center_x + door_gap_half + bl_width / 2.0, half.y), Vector2(bl_width, t))
	_add_wall(Vector2(-half.x, 0), Vector2(t, house_size.y + t))

	# Inner wall between main room and vault (locked door gap centered).
	var inner_seg_h: float = (house_size.y - door_width) / 2.0
	_add_wall(Vector2(inner_x, -half.y + inner_seg_h / 2.0), Vector2(t, inner_seg_h))
	_add_wall(Vector2(inner_x, half.y - inner_seg_h / 2.0), Vector2(t, inner_seg_h))

	# Vault room perimeter (fully enclosed - only reachable via the locked door).
	_add_wall(Vector2(vault_center_x, -half.y), Vector2(vault_width + t, t))
	_add_wall(Vector2(vault_center_x, half.y), Vector2(vault_width + t, t))
	_add_wall(Vector2(half.x, 0), Vector2(t, house_size.y + t))

	var front_door = DoorScene.instantiate()
	front_door.size = Vector2(door_width, t)
	add_child(front_door)
	front_door.position = Vector2(main_center_x, half.y)

	var locked_door = DoorScene.instantiate()
	locked_door.size = Vector2(t, door_width)
	locked_door.locked = true
	locked_door.key_id = key_id
	locked_door.door_color = Color(0.5, 0.35, 0.1, 1)
	add_child(locked_door)
	locked_door.position = Vector2(inner_x, 0)

	var chest = ChestScene.instantiate()
	chest.item_name = chest_item_name
	chest.base_value = chest_value
	chest.slot = chest_slot
	chest.stat_type = chest_stat_type
	chest.base_stat_value = chest_stat_value
	chest.icon_key = chest_icon_key
	chest.rarity = chest_rarity
	chest.grants_artifacts = grants_artifacts
	add_child(chest)
	chest.position = Vector2(vault_center_x, 0)

	var roof := Polygon2D.new()
	roof.name = "Roof"
	roof.z_index = 5
	roof.color = roof_color
	roof.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	add_child(roof)

	var name_tag := Label.new()
	name_tag.name = "NameTag"
	name_tag.z_index = 6
	name_tag.position = Vector2(-house_size.x * 0.35, -half.y - 45.0)
	name_tag.add_theme_font_size_override("font_size", 20)
	name_tag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1))
	name_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_tag.add_theme_constant_override("outline_size", 5)
	name_tag.text = house_name
	add_child(name_tag)

	var izone := Area2D.new()
	izone.name = "InteriorZone"
	izone.set_script(load("res://scripts/RoofFade.gd"))
	var izone_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = house_size * 0.9
	izone_shape.shape = rect
	izone.add_child(izone_shape)
	add_child(izone)
