extends Control

# A full-body procedural preview - build affects overall width, torso
# style swaps between a lean jacket silhouette and a wide armored one,
# a glow accent shows on the chest/eyes, and a backpack style shows on
# the back. Click and drag left/right to cycle between front, side,
# and back views instead of a single static front-on pose.

var build: float = 0.5
var torso_style: String = "sleek"
var glow_color: Color = Color(0.7, 0.3, 1.0, 1)
var backpack_style: String = "sleek_rig"
var hair_color: Color = Color(0.15, 0.12, 0.1, 1)
var eye_color: Color = Color(0.25, 0.45, 0.75, 1)
var mouth_style: String = "neutral"
var skin_color: Color = Color(0.75, 0.6, 0.48, 1)

const VIEWS := ["front", "side", "back"]
var view_index: int = 0
var _drag_start_x: float = 0.0

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_default_cursor_shape = Control.CURSOR_HSPLIT
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_start_x = event.position.x
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var delta_x: float = event.position.x - _drag_start_x
		if abs(delta_x) > 40.0:
			view_index = (view_index + (1 if delta_x > 0 else -1) + VIEWS.size()) % VIEWS.size()
			_drag_start_x = event.position.x
			queue_redraw()

func current_view() -> String:
	return VIEWS[view_index]

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var cx: float = w / 2.0
	var view := current_view()
	var facing_mult: float = 1.0 if view != "side" else 0.55

	var torso_flare: float = 0.34 if torso_style == "bulky" else 0.24
	var body_w: float = lerp(w * 0.14, w * facing_mult * torso_flare * 2.0, build) * (0.7 if view == "side" else 1.0)
	var head_r: float = lerp(h * 0.055, h * 0.07, build)
	var top: float = h * 0.1
	var skin := skin_color
	var suit_color := Color(0.3, 0.32, 0.3, 1) if torso_style == "bulky" else Color(0.22, 0.24, 0.26, 1)

	var torso_top: float = top + head_r + h * 0.015
	var torso_bottom: float = h * 0.58
	var leg_bottom: float = h * 0.95

	if view == "back":
		_draw_limbs(cx, body_w, torso_top, torso_bottom, leg_bottom, suit_color, skin)
		_draw_torso(cx, body_w, torso_top, torso_bottom, torso_style, suit_color)
		draw_circle(Vector2(cx, top), head_r, skin)
		_draw_hair_back(cx, top, head_r)
		_draw_backpack(cx, body_w, torso_top, torso_bottom, backpack_style, true)
		return

	_draw_limbs(cx, body_w, torso_top, torso_bottom, leg_bottom, suit_color, skin)
	if view == "front":
		_draw_backpack(cx, body_w, torso_top, torso_bottom, backpack_style, false)
	_draw_torso(cx, body_w, torso_top, torso_bottom, torso_style, suit_color)

	var glow_pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003)
	draw_rect(Rect2(cx - body_w * 0.08, torso_top + (torso_bottom - torso_top) * 0.3, body_w * 0.16, (torso_bottom - torso_top) * 0.35),
		Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * glow_pulse))

	draw_circle(Vector2(cx, top), head_r, skin)
	if view == "front":
		draw_circle(Vector2(cx - head_r * 0.35, top - head_r * 0.05), head_r * 0.12, eye_color)
		draw_circle(Vector2(cx + head_r * 0.35, top - head_r * 0.05), head_r * 0.12, eye_color)
		_draw_mouth(cx, top, head_r)
	else:
		draw_circle(Vector2(cx + head_r * 0.5, top - head_r * 0.05), head_r * 0.12, eye_color)
	_draw_hair_front(cx, top, head_r)

	if view == "side":
		_draw_backpack(cx, body_w, torso_top, torso_bottom, backpack_style, true)

func _draw_mouth(cx: float, top: float, head_r: float) -> void:
	# Small enough at this scale that the expression mostly reads as
	# "there's clearly a mouth doing something", not fine detail - the
	# FacePreview panel is where the real expressive version lives.
	var my: float = top + head_r * 0.42
	var mc := Color(0.35, 0.15, 0.15, 1)
	match mouth_style:
		"grim":
			draw_line(Vector2(cx - head_r * 0.22, my), Vector2(cx + head_r * 0.22, my), mc, max(1.0, head_r * 0.09))
		"smirk":
			draw_line(Vector2(cx - head_r * 0.2, my - head_r * 0.03), Vector2(cx, my + head_r * 0.05), mc, max(1.0, head_r * 0.09))
			draw_line(Vector2(cx, my + head_r * 0.05), Vector2(cx + head_r * 0.24, my - head_r * 0.06), mc, max(1.0, head_r * 0.09))
		"happy":
			var grin := PackedVector2Array([
				Vector2(cx - head_r * 0.28, my - head_r * 0.05), Vector2(cx + head_r * 0.28, my - head_r * 0.05),
				Vector2(cx + head_r * 0.2, my + head_r * 0.2), Vector2(cx - head_r * 0.2, my + head_r * 0.2),
			])
			draw_colored_polygon(grin, Color(0.5, 0.15, 0.15, 1))
			var teeth := PackedVector2Array([
				Vector2(cx - head_r * 0.24, my - head_r * 0.03), Vector2(cx + head_r * 0.24, my - head_r * 0.03),
				Vector2(cx + head_r * 0.2, my + head_r * 0.06), Vector2(cx - head_r * 0.2, my + head_r * 0.06),
			])
			draw_colored_polygon(teeth, Color(0.97, 0.95, 0.9, 1))
		_:
			draw_arc(Vector2(cx, my), head_r * 0.22, 0.2, PI - 0.2, 8, mc, max(1.0, head_r * 0.09), true)

func _draw_torso(cx: float, body_w: float, torso_top: float, torso_bottom: float, style: String, col: Color) -> void:
	if style == "bulky":
		var torso := PackedVector2Array([
			Vector2(cx - body_w * 0.55, torso_top), Vector2(cx + body_w * 0.55, torso_top),
			Vector2(cx + body_w * 0.5, torso_bottom), Vector2(cx - body_w * 0.5, torso_bottom),
		])
		draw_colored_polygon(torso, col)
		draw_line(Vector2(cx - body_w * 0.3, torso_top + 4), Vector2(cx - body_w * 0.3, torso_bottom - 4), Color(0, 0, 0, 0.3), 1.5)
		draw_line(Vector2(cx + body_w * 0.3, torso_top + 4), Vector2(cx + body_w * 0.3, torso_bottom - 4), Color(0, 0, 0, 0.3), 1.5)
	elif style == "tactical":
		# A plate carrier over a base layer - visible rectangular plate
		# panel on the chest and shoulder straps, reads distinctly
		# "geared up" compared to the plain jacket.
		var torso := PackedVector2Array([
			Vector2(cx - body_w * 0.45, torso_top), Vector2(cx + body_w * 0.45, torso_top),
			Vector2(cx + body_w * 0.34, torso_bottom), Vector2(cx - body_w * 0.34, torso_bottom),
		])
		draw_colored_polygon(torso, col.darkened(0.15))
		var plate_top := torso_top + (torso_bottom - torso_top) * 0.12
		var plate_bottom := torso_top + (torso_bottom - torso_top) * 0.75
		draw_rect(Rect2(cx - body_w * 0.28, plate_top, body_w * 0.56, plate_bottom - plate_top), Color(0.16, 0.17, 0.15, 1))
		draw_rect(Rect2(cx - body_w * 0.28, plate_top, body_w * 0.56, plate_bottom - plate_top), Color(0, 0, 0, 0.4), false, 1.5)
		draw_line(Vector2(cx - body_w * 0.2, torso_top), Vector2(cx - body_w * 0.12, plate_top), Color(0.3, 0.3, 0.28, 1), 3.0)
		draw_line(Vector2(cx + body_w * 0.2, torso_top), Vector2(cx + body_w * 0.12, plate_top), Color(0.3, 0.3, 0.28, 1), 3.0)
	elif style == "trench_coat":
		# Long and heavy, flares out well past the hips - the widest
		# silhouette at the bottom of any style.
		var flare_bottom: float = torso_bottom + (torso_bottom - torso_top) * 0.45
		var torso := PackedVector2Array([
			Vector2(cx - body_w * 0.4, torso_top), Vector2(cx + body_w * 0.4, torso_top),
			Vector2(cx + body_w * 0.62, flare_bottom), Vector2(cx - body_w * 0.62, flare_bottom),
		])
		draw_colored_polygon(torso, col.darkened(0.08))
		draw_line(Vector2(cx, torso_top + 2), Vector2(cx, flare_bottom - 2), Color(0, 0, 0, 0.35), 1.5)
		draw_line(Vector2(cx - body_w * 0.15, torso_top + 6), Vector2(cx - body_w * 0.28, flare_bottom - 4), Color(0, 0, 0, 0.2), 1.0)
		draw_line(Vector2(cx + body_w * 0.15, torso_top + 6), Vector2(cx + body_w * 0.28, flare_bottom - 4), Color(0, 0, 0, 0.2), 1.0)
	else:
		var torso := PackedVector2Array([
			Vector2(cx - body_w * 0.42, torso_top), Vector2(cx + body_w * 0.42, torso_top),
			Vector2(cx + body_w * 0.3, torso_bottom), Vector2(cx - body_w * 0.3, torso_bottom),
		])
		draw_colored_polygon(torso, col)
		draw_line(Vector2(cx, torso_top + 3), Vector2(cx, torso_bottom - 3), Color(0, 0, 0, 0.25), 1.0)

func _draw_limbs(cx: float, body_w: float, torso_top: float, torso_bottom: float, leg_bottom: float, suit_color: Color, skin: Color) -> void:
	var leg_w: float = body_w * 0.32
	var leg_gap: float = body_w * 0.06
	draw_rect(Rect2(cx - leg_gap - leg_w, torso_bottom - 4, leg_w, leg_bottom - torso_bottom + 4), suit_color.darkened(0.15))
	draw_rect(Rect2(cx + leg_gap, torso_bottom - 4, leg_w, leg_bottom - torso_bottom + 4), suit_color.darkened(0.15))
	var arm_w: float = body_w * 0.2
	draw_rect(Rect2(cx - body_w * 0.55 - arm_w * 0.5, torso_top + 4, arm_w, (torso_bottom - torso_top) * 0.75), skin)
	draw_rect(Rect2(cx + body_w * 0.55 - arm_w * 0.5, torso_top + 4, arm_w, (torso_bottom - torso_top) * 0.75), skin)

func _draw_backpack(cx: float, body_w: float, torso_top: float, torso_bottom: float, style: String, prominent: bool) -> void:
	if style == "none":
		return
	var pack_col := Color(0.18, 0.16, 0.12, 1)
	if style == "massive_pack":
		var w: float = body_w * (0.55 if prominent else 0.4)
		var pack := Rect2(cx - w * 0.5, torso_top - 2, w, (torso_bottom - torso_top) * 1.15)
		draw_rect(pack, pack_col)
		draw_rect(Rect2(pack.position.x + 2, pack.position.y + 4, pack.size.x - 4, pack.size.y * 0.3), pack_col.lightened(0.15))
	else:
		var w: float = body_w * (0.32 if prominent else 0.22)
		var pack := Rect2(cx - w * 0.5, torso_top + 6, w, (torso_bottom - torso_top) * 0.7)
		draw_rect(pack, pack_col.lightened(0.1))

func _draw_hair_front(cx: float, top: float, head_r: float) -> void:
	var pts := PackedVector2Array([
		Vector2(cx - head_r * 1.05, top - head_r * 0.2), Vector2(cx - head_r * 0.6, top - head_r * 1.1),
		Vector2(cx + head_r * 0.6, top - head_r * 1.1), Vector2(cx + head_r * 1.05, top - head_r * 0.2),
		Vector2(cx + head_r * 0.85, top - head_r * 0.5), Vector2(cx - head_r * 0.85, top - head_r * 0.5),
	])
	draw_colored_polygon(pts, hair_color)

func _draw_hair_back(cx: float, top: float, head_r: float) -> void:
	var pts := PackedVector2Array([
		Vector2(cx - head_r * 1.05, top - head_r * 0.1), Vector2(cx - head_r * 0.9, top - head_r * 1.1),
		Vector2(cx + head_r * 0.9, top - head_r * 1.1), Vector2(cx + head_r * 1.05, top - head_r * 0.1),
		Vector2(cx + head_r * 0.95, top + head_r * 0.4), Vector2(cx - head_r * 0.95, top + head_r * 0.4),
	])
	draw_colored_polygon(pts, hair_color)
