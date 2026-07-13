extends Node2D

# Lilly - the Arena's NPC, tucked into her own side room off The Grid so
# she's never in the way of an actual match. Blonde hair, all black
# clothes. Purely decorative; LillyStation (HideoutStation.tscn) handles
# the actual interaction at the same spot.

func _draw() -> void:
	var skin := Color(0.85, 0.68, 0.55, 1)
	var hair := Color(0.85, 0.72, 0.35, 1)
	var black := Color(0.08, 0.08, 0.1, 1)
	var black_dark := black.darkened(0.2)

	draw_colored_polygon(PackedVector2Array([Vector2(-24, 2), Vector2(24, 2), Vector2(20, 10), Vector2(-20, 10)]), Color(0, 0, 0, 0.25))

	draw_rect(Rect2(Vector2(-16, -36), Vector2(13, 40)), black_dark)
	draw_rect(Rect2(Vector2(3, -36), Vector2(13, 40)), black_dark)

	var torso := PackedVector2Array([
		Vector2(-20, -100), Vector2(20, -100), Vector2(24, -60),
		Vector2(18, -34), Vector2(-18, -34), Vector2(-24, -60),
	])
	draw_colored_polygon(torso, black)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -96), Vector2(6, -96), Vector2(4, -38), Vector2(-4, -38)]), black_dark)

	draw_colored_polygon(PackedVector2Array([Vector2(-24, -92), Vector2(-14, -96), Vector2(-18, -50), Vector2(-28, -54)]), black)
	draw_colored_polygon(PackedVector2Array([Vector2(24, -92), Vector2(14, -96), Vector2(18, -50), Vector2(28, -54)]), black)

	draw_circle(Vector2(0, -122), 20, hair)
	draw_circle(Vector2(0, -120), 15, skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -130), Vector2(-9, -136), Vector2(-12, -90), Vector2(-19, -96)]), hair)
	draw_colored_polygon(PackedVector2Array([Vector2(16, -130), Vector2(9, -136), Vector2(12, -90), Vector2(19, -96)]), hair)
	draw_circle(Vector2(-5, -120), 1.6, Color(0.2, 0.12, 0.1, 1))
	draw_circle(Vector2(5, -120), 1.6, Color(0.2, 0.12, 0.1, 1))
