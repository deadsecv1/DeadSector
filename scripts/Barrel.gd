extends Node2D

# A simple rusted barrel decoration - purely visual dressing, same
# non-blocking approach as Crate.gd. Falls back to a procedural vector
# barrel if no external art is present.

@export var barrel_radius: float = 16.0
@export var barrel_color: Color = Color(0.32, 0.28, 0.12, 1)

const VARIANT_COUNT := 4

func _ready() -> void:
	_try_load_external_sprite()

# --- Optional external art: picks a random weathered variant
# (res://assets/props/barrel_<1-4>.png) for visual variety across the
# many barrels scattered around the maps.
func _try_load_external_sprite() -> void:
	var path := "res://assets/props/barrel_%d.png" % (randi() % VARIANT_COUNT + 1)
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.2, 2.2)
	add_child(sprite)

func _draw() -> void:
	if has_node("Sprite2D"):
		return
	draw_circle(Vector2.ZERO, barrel_radius, barrel_color)
	draw_arc(Vector2.ZERO, barrel_radius, 0.0, TAU, 24, Color(0, 0, 0, 0.55), 2.0)
	draw_circle(Vector2.ZERO, barrel_radius * 0.62, Color(0, 0, 0, 0.18))
	draw_line(Vector2(-barrel_radius, -barrel_radius * 0.35), Vector2(barrel_radius, -barrel_radius * 0.35), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(-barrel_radius, barrel_radius * 0.35), Vector2(barrel_radius, barrel_radius * 0.35), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(-barrel_radius * 0.5, -barrel_radius * 0.7), Vector2(-barrel_radius * 0.5, barrel_radius * 0.7), Color(1, 1, 1, 0.1), 1.0)
