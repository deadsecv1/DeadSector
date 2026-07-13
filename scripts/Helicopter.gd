extends Node2D

# Flies in from off-screen toward the extraction zone, hovers with a
# dangling rope while the extraction timer runs, then flies off when
# depart() is called (successful extraction or the player left the zone).

signal arrived

const HOVER_OFFSET := Vector2(0, -130)
const APPROACH_SPEED := 280.0
const LEAVE_SPEED := 380.0

var target_pos: Vector2 = Vector2.ZERO
var state: String = "approaching"
var rotor_angle: float = 0.0
var bob_time: float = 0.0

@onready var body: Polygon2D = $Body
@onready var tail: Polygon2D = $Tail
@onready var rotor: Line2D = $Rotor
@onready var rope: Line2D = $Rope

func start_approach(landing_pos: Vector2) -> void:
	target_pos = landing_pos + HOVER_OFFSET
	global_position = target_pos + Vector2(-1100, -260)
	state = "approaching"
	rope.visible = false
	z_index = 50

func _process(delta: float) -> void:
	rotor_angle += delta * 34.0
	rotor.rotation = rotor_angle

	if state == "approaching":
		global_position = global_position.move_toward(target_pos, APPROACH_SPEED * delta)
		if global_position.distance_to(target_pos) < 4.0:
			state = "hovering"
			rope.visible = true
			arrived.emit()
	elif state == "hovering":
		bob_time += delta
		global_position = target_pos + Vector2(0, sin(bob_time * 2.0) * 4.0)
	elif state == "leaving":
		global_position += Vector2(-0.3, -1.0).normalized() * LEAVE_SPEED * delta
		if global_position.distance_to(target_pos) > 1300.0:
			queue_free()

func depart() -> void:
	state = "leaving"
	rope.visible = false
