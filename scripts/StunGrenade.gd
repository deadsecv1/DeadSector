extends Node2D

@export var radius: float = 110.0
@export var stun_duration: float = 3.0
@export var player_stun_duration: float = 2.0

var target_position: Vector2 = Vector2.ZERO

@onready var body: Polygon2D = $Body

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "rotation", TAU * 2.0, 0.45)
	tween.tween_callback(_explode)

func _explode() -> void:
	if not is_instance_valid(self):
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= radius and enemy.has_method("apply_stun"):
			enemy.apply_stun(stun_duration)

	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.has_method("apply_stun"):
		if global_position.distance_to(player.global_position) <= radius:
			player.apply_stun(player_stun_duration)

	Sfx.play_explosion()
	_spawn_flash_visual()
	body.visible = false
	await get_tree().create_timer(0.4).timeout
	queue_free()

func _spawn_flash_visual() -> void:
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var ang := TAU * float(i) / 24.0
		pts.append(Vector2(cos(ang), sin(ang)) * 6.0)
	ring.polygon = pts
	ring.color = Color(1.0, 1.0, 0.9, 0.8)
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(radius / 6.0, radius / 6.0), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.35)
