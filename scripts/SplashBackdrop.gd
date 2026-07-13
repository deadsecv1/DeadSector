extends Control

# A simple vertical gradient backdrop for splash screens, reused across
# the partner credit screens - each one just sets its own top/bottom
# color pair rather than duplicating this drawing code.

@export var top_color: Color = Color(0.05, 0.08, 0.15, 1)
@export var bottom_color: Color = Color(0.01, 0.01, 0.02, 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var steps := 28
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1.5), top_color.lerp(bottom_color, t0))
