extends Node2D

# The Molotov: thrown like a frag grenade, but on landing it ignites the
# ground instead of exploding - anyone standing in the fire (player or
# enemy alike, it doesn't discriminate) takes damage over time for a
# few seconds before it burns out.

@export var radius: float = 75.0
@export var duration: float = 4.5
@export var damage_per_tick: int = 8
@export var tick_interval: float = 0.5

var target_position: Vector2 = Vector2.ZERO
var deployed: bool = false
var tick_timer: float = 0.0

@onready var body: Polygon2D = $Body
@onready var fire_visual: Node2D = $FireVisual

func _ready() -> void:
	add_to_group("fire_zone")
	fire_visual.visible = false
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "rotation", TAU * 2.0, 0.45)
	tween.tween_callback(_ignite)

func _ignite() -> void:
	if not is_instance_valid(self):
		return
	deployed = true
	body.visible = false
	fire_visual.visible = true
	fire_visual.scale = Vector2(0.2, 0.2)
	Sfx.play_explosion()
	var tw := create_tween()
	tw.tween_property(fire_visual, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	deployed = false
	var fade := create_tween()
	fade.tween_property(fire_visual, "modulate:a", 0.0, 0.7)
	await fade.finished
	queue_free()

func _process(delta: float) -> void:
	if not deployed:
		return
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		_deal_damage()
	var flicker: float = 0.7 + 0.25 * sin(Time.get_ticks_msec() * 0.025)
	fire_visual.modulate.a = flicker
	fire_visual.rotation = sin(Time.get_ticks_msec() * 0.006) * 0.15

func _deal_damage() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.alive:
		if global_position.distance_to(player.global_position) <= radius:
			player.take_damage(damage_per_tick, "An Enemy", "Molotov", global_position - player.global_position)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_per_tick, "Molotov")
