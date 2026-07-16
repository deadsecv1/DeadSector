extends StaticBody2D

# A door blocking a gap in a wall. If locked, it needs the matching key
# CURRENTLY in the player's backpack (not just picked up at some point -
# see GameManager.has_key_in_backpack).

@export var size: Vector2 = Vector2(50, 20)
@export var door_color: Color = Color(0.35, 0.22, 0.12, 1)
@export var locked: bool = false
@export var key_id: String = ""

var is_open: bool = false
var player_in_range: bool = false

@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var poly_node: Polygon2D = $Polygon2D
@onready var interact_zone: Area2D = $InteractZone
@onready var interact_shape: CollisionShape2D = $InteractZone/CollisionShape2D
@onready var prompt: Label = $Prompt

func _ready() -> void:
	add_to_group("doors")

	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape

	var half := size / 2.0
	poly_node.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	])
	poly_node.color = door_color

	var izone_shape := RectangleShape2D.new()
	izone_shape.size = size + Vector2(40, 40)
	interact_shape.shape = izone_shape

	prompt.visible = false
	_update_prompt()
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)

func _update_prompt() -> void:
	if not locked:
		prompt.text = GameManager.format_prompt("Press F: Open Door")
	elif GameManager.has_key_in_backpack(key_id):
		prompt.text = GameManager.format_prompt("Press F: Unlock Door")
	else:
		prompt.text = "Locked - find the matching key"

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not is_open:
			prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(_delta: float) -> void:
	if is_open or not player_in_range:
		return
	# Keep the prompt fresh in case the key is now in the backpack (or a
	# key was dropped/consumed since we last checked).
	_update_prompt()
	if GameManager.is_action_pressed("interact"):
		_try_open()

func _try_open() -> void:
	if locked and not GameManager.has_key_in_backpack(key_id):
		return
	if locked:
		GameManager.notify_event("unlock_door")
		if key_id == "gas_station_key":
			GameManager.notify_event("open_gas_station")
	is_open = true
	shape_node.disabled = true
	# Don't hide the door entirely - turn it into a dark open-doorway marker
	# instead. Otherwise, once the roof fades back to full opacity right as
	# you step outside, there's nothing left showing where the entrance is.
	poly_node.color = Color(0.04, 0.04, 0.05, 0.92)
	prompt.visible = false
	Sfx.play_door()
