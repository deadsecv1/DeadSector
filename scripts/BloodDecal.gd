extends Node2D

# A ground-level blood stain rendered by a procedural noise shader - each
# one gets a random seed, size, and rotation so no two look alike, with
# no image assets involved at all.

@onready var rect: ColorRect = $Rect

func _ready() -> void:
	z_index = -1
	var mat := rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("seed", randf() * 1000.0)
	var s := randf_range(28.0, 46.0)
	rect.size = Vector2(s, s)
	rect.position = Vector2(-s / 2.0, -s / 2.0)
	rotation = randf_range(0.0, TAU)
	await get_tree().create_timer(10.0).timeout
	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 2.0)
	tw.tween_callback(queue_free)
