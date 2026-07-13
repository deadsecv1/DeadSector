extends Control

# A lightweight "scope view" effect: darkens the screen edges and draws a
# reticle in the middle. Toggled by HUD.gd based on the player's is_scoped
# state - no shaders needed, just a few rectangles + an arc.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	resized.connect(queue_redraw)

func _draw() -> void:
	var c := size
	var center := c * 0.5
	var radius: float = min(c.x, c.y) * 0.40
	var dark := Color(0.0, 0.0, 0.0, 0.93)

	draw_rect(Rect2(0.0, 0.0, c.x, max(0.0, center.y - radius)), dark)
	draw_rect(Rect2(0.0, center.y + radius, c.x, max(0.0, c.y - (center.y + radius))), dark)
	draw_rect(Rect2(0.0, center.y - radius, max(0.0, center.x - radius), radius * 2.0), dark)
	draw_rect(Rect2(center.x + radius, center.y - radius, max(0.0, c.x - (center.x + radius)), radius * 2.0), dark)

	var reticle := Color(0.15, 0.9, 0.35, 0.85)
	draw_arc(center, radius, 0.0, TAU, 48, reticle, 2.0, true)
	draw_line(center - Vector2(radius * 0.9, 0), center + Vector2(radius * 0.9, 0), reticle, 1.4)
	draw_line(center - Vector2(0, radius * 0.9), center + Vector2(0, radius * 0.9), reticle, 1.4)
	draw_circle(center, 2.0, reticle)
