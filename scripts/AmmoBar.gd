extends Node2D

# A small circular ammo gauge drawn off to the side of the character - a
# simple ring that fills clockwise from the top as ammo increases, drains
# with every shot, refills on reload. Turns red once you're low.

var current: int = 12
var max_val: int = 12

func _ready() -> void:
	visible = false

const RADIUS := 8.0
const THICKNESS := 2.5
const CENTER := Vector2(34, -22)

func update_ammo(cur: int, mx: int) -> void:
	current = cur
	max_val = max(mx, 1)
	visible = cur <= 5
	queue_redraw()

func _draw() -> void:
	var pct: float = clamp(float(current) / float(max_val), 0.0, 1.0)

	# Background track (empty ring).
	draw_arc(CENTER, RADIUS, 0.0, TAU, 24, Color(0, 0, 0, 0.55), THICKNESS, true)

	# Filled portion, starting at the top and sweeping clockwise.
	if pct > 0.0:
		var start_angle := -PI / 2.0
		var end_angle: float = start_angle + TAU * pct
		var fill_color: Color = Color(0.85, 0.2, 0.15, 1) if pct <= 0.2 else Color(0.9, 0.75, 0.25, 1)
		draw_arc(CENTER, RADIUS, start_angle, end_angle, 24, fill_color, THICKNESS, true)
