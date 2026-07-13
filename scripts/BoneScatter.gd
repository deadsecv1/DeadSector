extends Node2D

# Scatters small bone decorations across the whole map, purely
# procedural (same approach as Ground.gd's grass speckle) - no art
# assets, deterministic seed so it looks the same every raid.

@export var area_size: Vector2 = Vector2(3800, 2600)
@export var bone_count: int = 160

func _ready() -> void:
	z_index = -1
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var half := area_size / 2.0
	for i in range(bone_count):
		var x := rng.randf_range(-half.x, half.x)
		var y := rng.randf_range(-half.y, half.y)
		var rot := rng.randf_range(0.0, TAU)
		var scale_f := rng.randf_range(0.7, 1.3)
		_draw_bone(Vector2(x, y), rot, scale_f)

func _draw_bone(pos: Vector2, rot: float, s: float) -> void:
	var dir := Vector2(cos(rot), sin(rot))
	var a := pos - dir * 9.0 * s
	var b := pos + dir * 9.0 * s
	var bone_color := Color(0.82, 0.79, 0.7, 0.6)
	draw_line(a, b, bone_color, 3.0 * s)
	draw_circle(a, 3.2 * s, bone_color)
	draw_circle(b, 3.2 * s, bone_color)
