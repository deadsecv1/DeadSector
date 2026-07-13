extends Node2D

# Drives in from off-screen for the paid extraction point, idles while the
# timer runs, then drives off when depart() is called. Can also be placed
# as a permanently-parked decoration (static_decor = true) scattered
# around the map - it just sits still and never calls start_approach().

signal arrived

@export var static_decor: bool = false

const APPROACH_SPEED := 340.0
const LEAVE_SPEED := 420.0

var target_pos: Vector2 = Vector2.ZERO
var state: String = "idle"

@onready var body: Polygon2D = $Body
@onready var wheel_l: Polygon2D = $WheelL
@onready var wheel_r: Polygon2D = $WheelR

func start_approach(landing_pos: Vector2) -> void:
	target_pos = landing_pos
	global_position = target_pos + Vector2(-900, 0)
	state = "approaching"
	z_index = 4

func _process(delta: float) -> void:
	if static_decor:
		return
	if state == "approaching":
		global_position = global_position.move_toward(target_pos, APPROACH_SPEED * delta)
		if global_position.distance_to(target_pos) < 4.0:
			state = "idle"
			arrived.emit()
	elif state == "leaving":
		global_position += Vector2(1, 0) * LEAVE_SPEED * delta
		if global_position.x - target_pos.x > 1100.0:
			queue_free()

func depart() -> void:
	state = "leaving"
