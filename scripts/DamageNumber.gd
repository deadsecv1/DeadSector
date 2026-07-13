extends Node2D

# Floating damage number that rises and fades - shown wherever the player's
# bullets land a hit, so damage output is visible at a glance.

func setup(amount: int, crit: bool = false) -> void:
	var label := Label.new()
	label.text = str(amount)
	var fsize := 22 if crit else 18
	label.add_theme_font_size_override("font_size", fsize)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1) if crit else Color(1, 0.95, 0.6, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	label.position = Vector2(-10, -10)

	var drift := Vector2(randf_range(-8, 8), -32)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + drift, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)

	await get_tree().create_timer(0.7).timeout
	queue_free()
