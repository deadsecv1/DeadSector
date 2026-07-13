extends Node2D

# The recruited Ghost, chilling in the Hideout - just floats gently in
# place. Visibility is controlled by Hideout.gd based on
# GameManager.ghost_recruited, since he doesn't exist here at all
# until you've actually brought him back from a raid.

var bob_phase: float = 0.0

func _ready() -> void:
	bob_phase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	bob_phase += delta * 1.3
	queue_redraw()

func _draw() -> void:
	var col := Color(0.7, 0.9, 0.95, 1)
	var bob: float = sin(bob_phase) * 4.0
	draw_circle(Vector2(0, -10 + bob), 9.0, col)
	var wisp_tail := PackedVector2Array([
		Vector2(-9, -6), Vector2(9, -6), Vector2(7, 10), Vector2(3, 4), Vector2(0, 12),
		Vector2(-3, 4), Vector2(-7, 10),
	])
	var offset_tail := PackedVector2Array()
	for p in wisp_tail:
		offset_tail.append(p + Vector2(0, bob))
	draw_colored_polygon(offset_tail, col)
	draw_circle(Vector2(-3, -12 + bob), 1.4, Color(0.05, 0.1, 0.1, 0.8))
	draw_circle(Vector2(3, -12 + bob), 1.4, Color(0.05, 0.1, 0.1, 0.8))
