extends Node2D

# Rose's world sprite - a real pixel-art sprite now (recolored from the
# Kenney top-down-shooter pack's "Woman Green" character - the same
# source pack the player body itself was built from - green jacket hue-
# shifted to pink), replacing the old hand-drawn vector figure. Purely
# decorative (same role as LilDirtyTable); the actual interaction is
# handled by a separate RoseStation (HideoutStation.tscn) placed at the
# same spot.

func _draw() -> void:
	# Ground shadow only - the figure itself is the Sprite2D child now.
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 24), Vector2(16, 24), Vector2(13, 32), Vector2(-13, 32)]), Color(0, 0, 0, 0.25))
