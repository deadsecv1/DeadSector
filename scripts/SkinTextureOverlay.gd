extends Control

# Sits on top of an item icon to make a skin preview actually look like
# a skin - diagonal racing stripes, a metallic sheen highlight, and a
# thin border - instead of just a flat color tint.

@export var skin_color: Color = Color(0.8, 0.8, 0.8, 1)

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	var light := skin_color.lightened(0.35)
	var dark := skin_color.darkened(0.3)

	# Diagonal racing stripes across the whole icon.
	var stripe_count := 4
	for i in range(stripe_count):
		var offset: float = (float(i) / float(stripe_count)) * (w + h) - h * 0.5
		var stripe := PackedVector2Array([
			Vector2(offset, 0), Vector2(offset + h * 0.28, 0),
			Vector2(offset + h * 0.28 - h, h), Vector2(offset - h, h),
		])
		draw_colored_polygon(stripe, Color(light.r, light.g, light.b, 0.35))

	# A soft diagonal sheen highlight, like light catching a painted finish.
	var sheen := PackedVector2Array([
		Vector2(w * 0.05, h * 0.15), Vector2(w * 0.35, h * 0.05),
		Vector2(w * 0.25, h * 0.45), Vector2(w * -0.05, h * 0.55),
	])
	draw_colored_polygon(sheen, Color(1, 1, 1, 0.18))

	# Thin border to frame the preview.
	draw_rect(Rect2(1, 1, w - 2, h - 2), Color(dark.r, dark.g, dark.b, 0.8), false, 1.5)
