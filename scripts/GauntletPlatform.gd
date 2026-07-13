extends Control

# A worn stone-and-metal platform texture - replaces the flat red
# rectangle look with actual surface detail: a base slab color, subtle
# panel seams, a few cracks, and a thin glowing top edge so platforms
# read clearly against the dark background.

@export var base_color: Color = Color(0.22, 0.2, 0.24, 1)
@export var edge_glow_color: Color = Color(0.55, 0.15, 0.65, 0.8)

var seed_offset: float = 0.0

func _ready() -> void:
	seed_offset = randf_range(0.0, 100.0)
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(0, 0, w, h), base_color)

	# Panel seams every ~60px.
	var seam_color := base_color.darkened(0.35)
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, 2), Vector2(x, h - 2), seam_color, 1.0)
		x += 58.0

	# A few procedural cracks for texture.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_offset * 1000) + int(w)
	var crack_count: int = max(1, int(w / 90.0))
	for i in range(crack_count):
		var cx: float = rng.randf_range(10.0, w - 10.0)
		var cy: float = rng.randf_range(h * 0.3, h * 0.7)
		var pts := PackedVector2Array([Vector2(cx, cy)])
		var cur := Vector2(cx, cy)
		for j in range(3):
			cur += Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(2.0, 6.0))
			cur.x = clamp(cur.x, 2.0, w - 2.0)
			cur.y = clamp(cur.y, 2.0, h - 2.0)
			pts.append(cur)
		draw_polyline(pts, base_color.darkened(0.45), 1.0)

	# Glowing top edge - the "lit rim" that makes platforms pop against
	# the dark background instead of blending into it.
	draw_line(Vector2(0, 1), Vector2(w, 1), edge_glow_color, 2.0)
	draw_line(Vector2(0, 3), Vector2(w, 3), Color(edge_glow_color.r, edge_glow_color.g, edge_glow_color.b, 0.25), 1.5)
