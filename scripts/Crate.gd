extends Node2D

# A simple crate decoration. Falls back to a procedural vector box if no
# external art is present.

@export var box_size: float = 30.0
@export var box_color: Color = Color(0.32, 0.22, 0.13, 1)

const VARIANT_COUNT := 3

func _ready() -> void:
	_try_load_external_sprite()

# --- Optional external art: picks a random ammo-crate color variant
# (res://assets/props/crate_<1-3>.png) for visual variety across the
# many crates scattered around the maps.
func _try_load_external_sprite() -> void:
	var path := "res://assets/props/crate_%d.png" % (randi() % VARIANT_COUNT + 1)
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(3.2, 3.2)
	add_child(sprite)

func _draw() -> void:
	if has_node("Sprite2D"):
		return
	var h := box_size / 2.0
	draw_rect(Rect2(-h, -h, box_size, box_size), box_color)
	draw_rect(Rect2(-h, -h, box_size, box_size), Color(0, 0, 0, 0.5), false, 2.0)
	draw_line(Vector2(-h, 0), Vector2(h, 0), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(0, -h), Vector2(0, h), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(-h, -h), Vector2(h, h), Color(1, 1, 1, 0.08), 1.0)
