extends CharacterBody2D

# A small boat on the lake. Press F to board - your character is tucked
# inside and the boat becomes drivable with WASD. Press F again to get
# out. While driving you can reach the Floating Barrels out in the
# water, which aren't reachable on foot.

@export var speed: float = 190.0

var player_inside: bool = false
var player_in_range: bool = false
var driver: Node2D = null
var f_was_down: bool = false

@onready var prompt: Label = $Prompt
@onready var interact_zone: Area2D = $InteractZone

func _ready() -> void:
	add_to_group("boat")
	prompt.visible = false
	prompt.text = "Press F: Board Boat"
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not player_inside:
		player_in_range = true
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if not player_inside:
			prompt.visible = false

func _process(delta: float) -> void:
	var f_down := Input.is_key_pressed(GameManager.get_keybind("interact"))
	if f_down and not f_was_down:
		if player_inside:
			_exit_boat()
		elif player_in_range:
			_enter_boat()
	f_was_down = f_down

	if player_inside and driver != null and is_instance_valid(driver):
		var dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity = velocity.lerp(dir * speed, clamp(delta * 6.0, 0.0, 1.0))
			rotation = lerp_angle(rotation, dir.angle() + PI / 2.0, clamp(delta * 5.0, 0.0, 1.0))
		else:
			velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 4.0, 0.0, 1.0))
		move_and_slide()
		driver.global_position = global_position

func _enter_boat() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player_inside = true
	driver = player
	player.visible = false
	player.set_input_locked(true)
	prompt.text = "Press F: Exit Boat"

func _exit_boat() -> void:
	if driver != null and is_instance_valid(driver):
		driver.visible = true
		driver.set_input_locked(false)
		driver.global_position = global_position + Vector2(0, 45).rotated(rotation - PI / 2.0)
	player_inside = false
	driver = null
	prompt.text = "Press F: Board Boat"
	if not player_in_range:
		prompt.visible = false
