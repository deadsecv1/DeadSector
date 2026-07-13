extends Node2D

# Paints a mottled grass/dirt ground instead of a flat rectangle: a base
# color, soft color-variation patches, speckled grass detail, and scattered
# pebbles/dirt spots. Drawn once (not animated) since the arena is static.

@export var ground_size: Vector2 = Vector2(2700, 1840)
@export var base_color: Color = Color(0.13, 0.18, 0.12, 1)

func _ready() -> void:
	if not _try_load_external_texture():
		queue_redraw()

# --- Optional external art: if res://assets/ground_tile.png exists, tile it
# across the whole arena instead of the procedural grass texture.
func _try_load_external_texture() -> bool:
	var path := "res://assets/ground_tile.png"
	if not ResourceLoader.exists(path):
		return false
	var tex: Texture2D = load(path)
	if tex == null:
		return false
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, ground_size.x, ground_size.y)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(sprite)
	return true

func _draw() -> void:
	var half := ground_size / 2.0
	draw_rect(Rect2(-half.x, -half.y, ground_size.x, ground_size.y), base_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	# Broad soft patches of lighter/darker grass for variation.
	for i in range(220):
		var px: float = rng.randf_range(-half.x, half.x)
		var py: float = rng.randf_range(-half.y, half.y)
		var r: float = rng.randf_range(20, 70)
		var patch_color: Color
		if rng.randf() < 0.7:
			patch_color = base_color.lightened(rng.randf_range(0.03, 0.09))
		else:
			patch_color = base_color.darkened(rng.randf_range(0.03, 0.1))
		patch_color.a = 0.3
		draw_circle(Vector2(px, py), r, patch_color)

	# Fine grass speckle detail.
	for i in range(900):
		var px: float = rng.randf_range(-half.x, half.x)
		var py: float = rng.randf_range(-half.y, half.y)
		var speck_color := base_color.lightened(rng.randf_range(0.06, 0.2))
		speck_color.a = 0.5
		draw_rect(Rect2(px, py, 2.0, 2.0), speck_color)

	# Sparse dirt patches / pebbles.
	for i in range(70):
		var px: float = rng.randf_range(-half.x, half.x)
		var py: float = rng.randf_range(-half.y, half.y)
		draw_circle(Vector2(px, py), rng.randf_range(3, 7), Color(0.3, 0.28, 0.24, 0.4))
