extends StaticBody2D

# A reusable wall/obstacle. Instead of a flat colored rectangle, it draws a
# brick-coursing texture (alternating shaded bricks + grout lines) scaled to
# whatever size this instance is given.

@export var size: Vector2 = Vector2(64, 64)
@export var wall_color: Color = Color(0.35, 0.35, 0.42, 1)

@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var poly_node: Polygon2D = $Polygon2D

const BRICK_W := 26.0
const BRICK_H := 13.0

func _ready() -> void:
	add_to_group("walls")
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	poly_node.visible = false
	if not _try_load_external_texture():
		queue_redraw()

# --- Optional external art: if res://assets/wall_tile.png exists, tile it
# across this wall instead of the procedural brick pattern. Works for any
# wall size since the sprite is region-tiled to fit.
func _try_load_external_texture() -> bool:
	var path := "res://assets/wall_tile.png"
	if not ResourceLoader.exists(path):
		return false
	var tex: Texture2D = load(path)
	if tex == null:
		return false
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, size.x, size.y)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(sprite)
	return true

func _draw() -> void:
	var half := size / 2.0
	draw_rect(Rect2(-half.x, -half.y, size.x, size.y), wall_color)

	var grout := Color(0, 0, 0, 0.3)
	var light := wall_color.lightened(0.14)
	var dark := wall_color.darkened(0.14)

	var row := 0
	var y := -half.y
	while y < half.y:
		var row_h: float = min(BRICK_H, half.y - y)
		var offset: float = (BRICK_W * 0.5) if row % 2 == 1 else 0.0
		var col := 0
		var x: float = -half.x - offset
		while x < half.x:
			var bx: float = max(x, -half.x)
			var bw: float = min(BRICK_W, half.x - bx)
			if bw > 1.5:
				var shade: Color = light if (row + col) % 2 == 0 else dark
				draw_rect(Rect2(bx, y, bw, row_h), shade)
			x += BRICK_W
			col += 1
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), grout, 1.0)
		y += BRICK_H
		row += 1

	draw_line(Vector2(-half.x, half.y), Vector2(half.x, half.y), grout, 1.0)
	draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), grout, 1.0)
	draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), grout, 1.0)
