extends Control

# A small drawn button-glyph badge - a colored rounded square with the
# bound button's short label centered in it (Xbox-style: A/B/X/Y face
# buttons get their real controller colors via
# GameManager.get_gamepad_button_color(), everything else a neutral
# gray). No controller glyph texture assets exist anywhere in this
# project (checked), so this is procedural like SmallIcon.gd/
# CaseMarkerBadge.gd rather than sprite-based.

@export var button_index: int = -1

func _ready() -> void:
	resized.connect(queue_redraw)

func set_button(index: int) -> void:
	button_index = index
	queue_redraw()

func _draw() -> void:
	var s: float = min(size.x, size.y)
	if s <= 0.0:
		return
	var center := size / 2.0
	var color: Color = GameManager.get_gamepad_button_color(button_index)
	var rect := Rect2(center - Vector2(s, s) / 2.0, Vector2(s, s))
	draw_rect(rect, color, true, -1.0, true)
	draw_rect(rect, Color(0, 0, 0, 0.5), false, max(1.0, s * 0.06), true)
	# Longer labels (L-Stick, D-Pad Down, Back, Start...) don't fit legibly
	# in a badge this small and the adjacent Button already shows the full
	# name in text - skip cramming a second, unreadable copy in there and
	# just leave the plain colored square as a quiet accent instead.
	var label: String = GameManager.get_gamepad_button_label(button_index)
	if label.length() <= 2:
		var font_size: int = int(s * 0.55)
		var text_pos := Vector2(rect.position.x, center.y + font_size * 0.35)
		draw_string(ThemeDB.fallback_font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, s, font_size, Color(0.05, 0.05, 0.05, 1))
