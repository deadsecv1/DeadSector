extends Button

# A compact icon-only Social button - draws a simple two-person
# "friends" icon instead of text, with a hover glow and a tooltip
# ("Social") since there's no room for a label at this size.

var _hovered: bool = false
var glow_alpha: float = 0.0

func _ready() -> void:
	tooltip_text = "Social"
	flat = true
	mouse_entered.connect(func():
		_hovered = true
		var tw := create_tween()
		tw.tween_property(self, "glow_alpha", 1.0, 0.15)
		tw.parallel().tween_property(self, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	mouse_exited.connect(func():
		_hovered = false
		var tw := create_tween()
		tw.tween_property(self, "glow_alpha", 0.0, 0.2)
		tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	)
	pivot_offset = size / 2.0

func _process(_delta: float) -> void:
	queue_redraw()

func _p(nx: float, ny: float) -> Vector2:
	return Vector2(nx, ny) * size

func _draw() -> void:
	var w: float = size.x
	if w <= 0.0:
		return
	var accent := Color(1, 0.42, 0.24, 1)

	if glow_alpha > 0.01:
		draw_circle(_p(0.5, 0.5), w * 0.62, Color(accent.r, accent.g, accent.b, 0.18 * glow_alpha))

	var base_col := accent if _hovered else Color(0.85, 0.85, 0.88, 1)
	# Back person (smaller, offset up-right, dimmer).
	draw_circle(_p(0.62, 0.34), w * 0.14, Color(base_col.r, base_col.g, base_col.b, 0.55))
	draw_colored_polygon(PackedVector2Array([
		_p(0.44, 0.82), _p(0.5, 0.56), _p(0.74, 0.56), _p(0.82, 0.82),
	]), Color(base_col.r, base_col.g, base_col.b, 0.55))
	# Front person (bigger, offset down-left, full brightness).
	draw_circle(_p(0.38, 0.42), w * 0.17, base_col)
	draw_colored_polygon(PackedVector2Array([
		_p(0.16, 0.92), _p(0.24, 0.6), _p(0.52, 0.6), _p(0.6, 0.92),
	]), base_col)
