extends Node2D

# Rose's world sprite - a simple standing figure in the Hideout, pink
# top and brown hair. Purely decorative (same role as LilDirtyTable);
# the actual interaction is handled by a separate RoseStation
# (HideoutStation.tscn) placed at the same spot.

func _draw() -> void:
	var skin := Color(0.85, 0.68, 0.55, 1)
	var hair := Color(0.35, 0.22, 0.14, 1)
	var pink := Color(0.95, 0.55, 0.75, 1)
	var pink_dark := pink.darkened(0.15)
	var pants := Color(0.25, 0.22, 0.28, 1)

	# Ground shadow.
	draw_colored_polygon(PackedVector2Array([Vector2(-24, 2), Vector2(24, 2), Vector2(20, 10), Vector2(-20, 10)]), Color(0, 0, 0, 0.25))

	# Legs.
	draw_rect(Rect2(Vector2(-16, -36), Vector2(13, 40)), pants)
	draw_rect(Rect2(Vector2(3, -36), Vector2(13, 40)), pants)

	# Torso (pink top).
	var torso := PackedVector2Array([
		Vector2(-20, -100), Vector2(20, -100), Vector2(24, -60),
		Vector2(18, -34), Vector2(-18, -34), Vector2(-24, -60),
	])
	draw_colored_polygon(torso, pink)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -96), Vector2(6, -96), Vector2(4, -38), Vector2(-4, -38)]), pink_dark)

	# Arms.
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -92), Vector2(-14, -96), Vector2(-18, -50), Vector2(-28, -54)]), pink)
	draw_colored_polygon(PackedVector2Array([Vector2(24, -92), Vector2(14, -96), Vector2(18, -50), Vector2(28, -54)]), pink)

	# Head + hair (hair drawn first/wider so it frames the face).
	draw_circle(Vector2(0, -122), 20, hair)
	draw_circle(Vector2(0, -120), 15, skin)
	# Shoulder-length hair locks.
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -128), Vector2(-8, -132), Vector2(-11, -96), Vector2(-18, -100)]), hair)
	draw_colored_polygon(PackedVector2Array([Vector2(15, -128), Vector2(8, -132), Vector2(11, -96), Vector2(18, -100)]), hair)
	# Simple face.
	draw_circle(Vector2(-5, -120), 1.6, Color(0.2, 0.12, 0.1, 1))
	draw_circle(Vector2(5, -120), 1.6, Color(0.2, 0.12, 0.1, 1))
