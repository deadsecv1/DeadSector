extends Control

# A bigger, more detailed face preview than the small portrait gallery -
# shows the actual hair color, eye color, skin color, and mouth style the
# player has picked, combined into one face. Purely procedural, with
# added facial structure (eyebrows, nose, jaw shading, almond-shaped
# eyes) instead of the earlier flat circle-eyes-and-line-mouth version.

var hair_color: Color = Color(0.15, 0.12, 0.1, 1)
var eye_color: Color = Color(0.25, 0.45, 0.75, 1)
var mouth_style: String = "neutral"
var skin_color: Color = Color(0.78, 0.6, 0.47, 1)

var _side: float = 1.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _p(nx: float, ny: float) -> Vector2:
	# Centered square drawing area sized to the smaller dimension, so the
	# face reads correctly instead of stretching to fill a wide, short
	# panel (which is what FacePreviewPanel actually is - full width,
	# fixed ~140px height).
	var origin: Vector2 = Vector2((size.x - _side) / 2.0, (size.y - _side) / 2.0)
	return origin + Vector2(nx, ny) * _side

func _s(n: float) -> float:
	return n * _side

func _draw() -> void:
	_side = min(size.x, size.y)
	if _side <= 0.0:
		return
	draw_circle(_p(0.5, 0.5), _s(0.48), Color(0.08, 0.09, 0.1, 1))

	# Shoulders.
	var shoulders := PackedVector2Array([_p(0.16, 1.0), _p(0.84, 1.0), _p(0.72, 0.66), _p(0.28, 0.66)])
	draw_colored_polygon(shoulders, Color(0.2, 0.22, 0.2, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.44, 0.66), _p(0.56, 0.66), _p(0.54, 0.72), _p(0.46, 0.72)]), Color(0.14, 0.16, 0.14, 1))

	# Head - slightly tapered toward the jaw instead of a plain circle.
	var head := PackedVector2Array([
		_p(0.28, 0.36), _p(0.72, 0.36), _p(0.71, 0.48), _p(0.62, 0.62),
		_p(0.5, 0.66), _p(0.38, 0.62), _p(0.29, 0.48),
	])
	draw_colored_polygon(head, skin_color)
	# Subtle jaw/cheek shading for depth.
	draw_colored_polygon(PackedVector2Array([_p(0.29, 0.48), _p(0.35, 0.48), _p(0.38, 0.6), _p(0.32, 0.56)]), skin_color.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([_p(0.71, 0.48), _p(0.65, 0.48), _p(0.62, 0.6), _p(0.68, 0.56)]), skin_color.darkened(0.12))

	# Hair.
	var hair := PackedVector2Array([
		_p(0.25, 0.38), _p(0.75, 0.38), _p(0.71, 0.2), _p(0.5, 0.13), _p(0.29, 0.2),
	])
	draw_colored_polygon(hair, hair_color)
	draw_colored_polygon(PackedVector2Array([_p(0.24, 0.32), _p(0.31, 0.32), _p(0.29, 0.46), _p(0.23, 0.43)]), hair_color)
	draw_colored_polygon(PackedVector2Array([_p(0.69, 0.32), _p(0.76, 0.32), _p(0.77, 0.43), _p(0.71, 0.46)]), hair_color)

	# Eyebrows - raised a bit for the "happy" expression, matching the
	# more open, delighted eyes and big smile.
	var brow_col := hair_color.darkened(0.1)
	var brow_lift: float = 0.012 if mouth_style == "happy" else 0.0
	draw_line(_p(0.38, 0.415 - brow_lift), _p(0.46, 0.4 - brow_lift), brow_col, max(1.3, _s(0.009)))
	draw_line(_p(0.54, 0.4 - brow_lift), _p(0.62, 0.415 - brow_lift), brow_col, max(1.3, _s(0.009)))

	# Eyes - almond shape instead of plain circles. Happy expression
	# scrunches them slightly, like a real smile pulls at the eyes too.
	var eye_scrunch: float = 0.006 if mouth_style == "happy" else 0.0
	for ex in [0.42, 0.58]:
		var eye_shape := PackedVector2Array([
			_p(ex - 0.045, 0.44 + eye_scrunch), _p(ex, 0.428 + eye_scrunch), _p(ex + 0.045, 0.44 + eye_scrunch),
			_p(ex + 0.045, 0.452 - eye_scrunch), _p(ex, 0.462 - eye_scrunch), _p(ex - 0.045, 0.452 - eye_scrunch),
		])
		draw_colored_polygon(eye_shape, Color(0.95, 0.93, 0.9, 1))
		draw_circle(_p(ex, 0.444), _s(0.02), eye_color)
		draw_circle(_p(ex, 0.444), _s(0.008), Color(0.05, 0.05, 0.05, 1))

	# Nose - a soft triangular shadow, not a full outline.
	draw_colored_polygon(PackedVector2Array([_p(0.495, 0.45), _p(0.51, 0.45), _p(0.515, 0.5), _p(0.49, 0.5)]), skin_color.darkened(0.15))

	# Mouth - varies by style.
	var mc := Color(0.35, 0.15, 0.15, 1)
	match mouth_style:
		"grim":
			draw_line(_p(0.44, 0.55), _p(0.56, 0.55), mc, max(1.5, _s(0.012)))
		"smirk":
			draw_line(_p(0.43, 0.54), _p(0.5, 0.555), mc, max(1.5, _s(0.012)))
			draw_line(_p(0.5, 0.555), _p(0.58, 0.52), mc, max(1.5, _s(0.012)))
		"happy":
			# A real open, toothy smile - a wide grin shape with a
			# visible row of teeth, not just a curved line.
			var grin := PackedVector2Array([
				_p(0.4, 0.53), _p(0.6, 0.53), _p(0.585, 0.575), _p(0.5, 0.6), _p(0.415, 0.575),
			])
			draw_colored_polygon(grin, Color(0.5, 0.15, 0.15, 1))
			var teeth := PackedVector2Array([
				_p(0.415, 0.535), _p(0.585, 0.535), _p(0.575, 0.558), _p(0.425, 0.558),
			])
			draw_colored_polygon(teeth, Color(0.97, 0.95, 0.9, 1))
			for tx in [0.465, 0.5, 0.535]:
				draw_line(_p(tx, 0.535), _p(tx, 0.558), Color(0.75, 0.72, 0.68, 0.8), max(1.0, _s(0.004)))
			# Smile crease lines at the corners for a genuine grin read.
			draw_line(_p(0.4, 0.53), _p(0.37, 0.51), mc, max(1.2, _s(0.008)))
			draw_line(_p(0.6, 0.53), _p(0.63, 0.51), mc, max(1.2, _s(0.008)))
		_:
			draw_arc(_p(0.5, 0.52), _s(0.055), 0.15, PI - 0.15, 10, mc, max(1.5, _s(0.012)), true)
