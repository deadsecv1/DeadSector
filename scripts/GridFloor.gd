extends Node2D

# The Grid's floor - every inch laid out in grid tiles, drawn as a
# simple checkerboard over a fixed area (the arena's playable footprint,
# not the whole infinite world like other maps).

@export var half_size: Vector2 = Vector2(500, 400)
@export var tile_size: float = 50.0

func _draw() -> void:
	var base_a := Color(0.14, 0.14, 0.17, 1)
	var base_b := Color(0.11, 0.11, 0.14, 1)
	var line_color := Color(0.4, 0.4, 0.5, 0.4)
	var cols := int(half_size.x * 2.0 / tile_size)
	var rows := int(half_size.y * 2.0 / tile_size)
	for row in range(rows):
		for col in range(cols):
			var x: float = -half_size.x + col * tile_size
			var y: float = -half_size.y + row * tile_size
			var c: Color = base_a if (row + col) % 2 == 0 else base_b
			draw_rect(Rect2(Vector2(x, y), Vector2(tile_size, tile_size)), c)
	for col in range(cols + 1):
		var x: float = -half_size.x + col * tile_size
		draw_line(Vector2(x, -half_size.y), Vector2(x, half_size.y), line_color, 1.0)
	for row in range(rows + 1):
		var y: float = -half_size.y + row * tile_size
		draw_line(Vector2(-half_size.x, y), Vector2(half_size.x, y), line_color, 1.0)
