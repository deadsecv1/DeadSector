extends Control

var recruit_color: Color = Color(0.4, 0.4, 0.4, 1)
var doll_scale: float = 1.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var cx: float = w / 2.0
	var body_w: float = w * 0.24 * doll_scale
	var head_r: float = h * 0.08 * doll_scale
	var top: float = h * 0.16

	draw_circle(Vector2(cx, top), head_r, recruit_color.lightened(0.2))

	var torso_top: float = top + head_r + h * 0.02
	var torso_bottom: float = h * 0.62
	var torso := PackedVector2Array([
		Vector2(cx - body_w * 0.5, torso_top), Vector2(cx + body_w * 0.5, torso_top),
		Vector2(cx + body_w * 0.42, torso_bottom), Vector2(cx - body_w * 0.42, torso_bottom),
	])
	draw_colored_polygon(torso, recruit_color)

	var leg_w: float = body_w * 0.36
	var leg_gap: float = body_w * 0.08
	var leg_bottom: float = h * 0.92
	draw_rect(Rect2(cx - leg_gap - leg_w, torso_bottom - 4, leg_w, leg_bottom - torso_bottom + 4), recruit_color.darkened(0.2))
	draw_rect(Rect2(cx + leg_gap, torso_bottom - 4, leg_w, leg_bottom - torso_bottom + 4), recruit_color.darkened(0.2))
