extends Node2D

# Thrown like a frag grenade, but on landing it deploys a lingering smoke
# cloud instead of exploding - anyone standing inside is much harder for
# enemies to spot (same concealment bonus as hiding in a bush).

@export var radius: float = 90.0
@export var duration: float = 20.0

var target_position: Vector2 = Vector2.ZERO
var deployed: bool = false

@onready var body: Polygon2D = $Body
@onready var cloud: Polygon2D = $Cloud

func _ready() -> void:
	add_to_group("smoke_zone")
	cloud.visible = false
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "rotation", TAU * 2.0, 0.45)
	tween.tween_callback(_deploy)

func _deploy() -> void:
	if not is_instance_valid(self):
		return
	deployed = true
	body.visible = false
	cloud.visible = true
	cloud.scale = Vector2(0.15, 0.15)
	Sfx.play_door()
	var tw := create_tween()
	tw.tween_property(cloud, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	deployed = false
	var fade := create_tween()
	fade.tween_property(cloud, "modulate:a", 0.0, 1.5)
	await fade.finished
	queue_free()

func is_point_inside(point: Vector2) -> bool:
	return deployed and global_position.distance_to(point) <= radius
