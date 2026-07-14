extends Control

# A small procedurally-drawn sad face for the Exit confirmation dialog -
# blinks every few seconds and occasionally lets a single tear roll,
# instead of a static frown. No external art needed.

@export var face_color: Color = Color(0.75, 0.82, 0.92, 1)

var _time: float = 0.0
var _blink_at: float = 0.0
var _blinking: float = 0.0
var _tear_at: float = 0.0
var _tear_t: float = -1.0

func _ready() -> void:
	set_process(true)
	_blink_at = randf_range(1.5, 3.0)
	_tear_at = randf_range(2.5, 5.0)

func _process(delta: float) -> void:
	_time += delta
	_blink_at -= delta
	if _blink_at <= 0.0:
		_blinking = 0.18
		_blink_at = randf_range(2.5, 5.0)
	if _blinking > 0.0:
		_blinking -= delta
	_tear_at -= delta
	if _tear_at <= 0.0 and _tear_t < 0.0:
		_tear_t = 0.0
		_tear_at = randf_range(4.0, 8.0)
	if _tear_t >= 0.0:
		_tear_t += delta * 0.5
		if _tear_t > 1.0:
			_tear_t = -1.0
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var center := Vector2(w / 2.0, h / 2.0)
	var r: float = min(w, h) * 0.42

	draw_circle(center, r, Color(face_color.r, face_color.g, face_color.b, 0.12))
	draw_arc(center, r, 0.0, TAU, 32, Color(face_color.r, face_color.g, face_color.b, 0.55), 2.0, true)

	var eye_y := center.y - r * 0.18
	var eye_dx := r * 0.36
	var eye_open: float = 1.0 - clamp(_blinking / 0.18, 0.0, 1.0)
	for side in [-1, 1]:
		var ex: float = center.x + eye_dx * side
		if eye_open > 0.15:
			draw_circle(Vector2(ex, eye_y), r * 0.09 * eye_open, Color(face_color.r, face_color.g, face_color.b, 0.9))
		else:
			draw_line(Vector2(ex - r * 0.08, eye_y), Vector2(ex + r * 0.08, eye_y), Color(face_color.r, face_color.g, face_color.b, 0.9), 2.0)

	# Downturned mouth - an arc curving the "wrong" way for a frown.
	var mouth_y := center.y + r * 0.42
	var pts := PackedVector2Array()
	var segs := 16
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var mx: float = center.x + lerp(-r * 0.32, r * 0.32, t)
		var my: float = mouth_y - sin(t * PI) * r * 0.14
		pts.append(Vector2(mx, my))
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(face_color.r, face_color.g, face_color.b, 0.75), 2.0)

	if _tear_t >= 0.0:
		var tx: float = center.x + eye_dx
		var ty: float = eye_y + _tear_t * r * 1.1
		var tear_alpha: float = sin(min(_tear_t, 1.0) * PI)
		draw_circle(Vector2(tx, ty), r * 0.07, Color(0.55, 0.75, 0.95, 0.75 * tear_alpha))
