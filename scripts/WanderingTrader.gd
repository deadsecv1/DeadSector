extends CharacterBody2D

# A rare NPC that roams Overgrowth during a raid (50% chance to appear
# at all). Wanders between random points on the map; walk up and press
# F to trade - he deals exclusively in Blossoms, and sells nothing but
# the best gear in the game.

const SPEED := 90.0
const WANDER_RADIUS := 1600.0

var stock: Array = []
var target_pos: Vector2 = Vector2.ZERO
var wait_timer: float = 0.0
var player_in_range: bool = false
var f_was_down: bool = false

signal trade_requested

@onready var prompt: Label = $Prompt
@onready var interact_zone: Area2D = $InteractZone

func _ready() -> void:
	add_to_group("wandering_trader")
	stock = GameManager.roll_wandering_trader_stock()
	prompt.visible = false
	target_pos = global_position
	interact_zone.body_entered.connect(_on_entered)
	interact_zone.body_exited.connect(_on_exited)
	_pick_new_target()

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt.text = GameManager.format_prompt("Press F: Trade (Blossoms)")
		prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _pick_new_target() -> void:
	target_pos = global_position + Vector2(randf_range(-WANDER_RADIUS, WANDER_RADIUS), randf_range(-WANDER_RADIUS, WANDER_RADIUS))
	wait_timer = randf_range(2.0, 5.0)

func _physics_process(delta: float) -> void:
	if player_in_range:
		var f_down := GameManager.is_action_pressed("interact")
		if f_down and not f_was_down:
			trade_requested.emit()
		f_was_down = f_down

	var dist := global_position.distance_to(target_pos)
	if dist < 20.0:
		wait_timer -= delta
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 6.0, 0.0, 1.0))
		if wait_timer <= 0.0:
			_pick_new_target()
	else:
		var dir := (target_pos - global_position).normalized()
		velocity = velocity.lerp(dir * SPEED, clamp(delta * 4.0, 0.0, 1.0))
	move_and_slide()
