extends Node2D

# A short burst of small fading squares at the hit location. Self-destructs
# once the fade-out finishes. No external assets needed.
#
# particle_count/size_mult/distance_mult let a specific caller (e.g. the
# Lil Dirty cursor cameo) ask for a bigger, chunkier splatter without
# touching the normal in-combat look every other caller (Bullet.gd) uses -
# defaults reproduce the original fixed behavior exactly.

@export var particle_count: int = 6
@export var size_mult: float = 1.0
@export var distance_mult: float = 1.0

func _ready() -> void:
	z_index = 8
	for i in range(particle_count):
		var p := Polygon2D.new()
		var s := randf_range(2.5, 5.0) * size_mult
		p.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		p.color = Color(0.55, 0.05, 0.05, 1)
		p.rotation = randf_range(0, TAU)
		add_child(p)

		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		var dist := randf_range(10.0, 28.0) * distance_mult
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", dir * dist, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.4)

	await get_tree().create_timer(0.45).timeout
	queue_free()
