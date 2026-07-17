extends Node2D

# Thrown from the Hotbar (a "grenade"-type consumable). Travels in a short
# arc to the target point, then explodes: damages every enemy within
# radius, plays an expanding blast ring, and shakes the camera.

@export var damage: int = 55
@export var radius: float = 95.0
@export var travel_time: float = 0.45

# Set true by boss throws (Spike/Rattles) so the blast damages the player
# instead of enemies - same is_enemy_bullet pattern Bullet.gd already
# uses. Defaults false, matching the player's own frag grenade.
@export var is_enemy_grenade: bool = false

var target_position: Vector2 = Vector2.ZERO

@onready var body: Polygon2D = $Body

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "rotation", TAU * 2.0, travel_time)
	tween.tween_callback(_explode)

func _explode() -> void:
	if not is_instance_valid(self):
		return
	var player = get_tree().get_first_node_in_group("player")
	if is_enemy_grenade:
		if player != null and global_position.distance_to(player.global_position) <= radius and player.has_method("take_damage"):
			player.take_damage(damage, "An Enemy", "Grenade", global_position - player.global_position)
	else:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(enemy):
				continue
			if global_position.distance_to(enemy.global_position) <= radius and enemy.has_method("take_damage"):
				if enemy.health <= damage:
					GameManager.notify_event("grenade_kill")
				enemy.take_damage(damage, "Grenade")

	Sfx.play_explosion()
	if player != null and player.has_node("Camera2D"):
		player.get_node("Camera2D").shake(10.0)

	_spawn_blast_visual()
	body.visible = false
	# The blast visuals (flash, particles, ring) all finish well within
	# this window, so nothing pops out of existence mid-effect - but the
	# grenade itself is gone right after, instead of sitting around.
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _spawn_blast_visual() -> void:
	# A bright white-orange flash that pops in and fades fast - reads as
	# the actual detonation instant, with everything else (ring, debris)
	# expanding out from it.
	var flash := Polygon2D.new()
	var flash_pts := PackedVector2Array()
	for i in range(16):
		var fang := TAU * float(i) / 16.0
		flash_pts.append(Vector2(cos(fang), sin(fang)) * (radius * 0.5))
	flash.polygon = flash_pts
	flash.color = Color(1.0, 0.95, 0.8, 0.95)
	add_child(flash)
	var flash_tw := create_tween()
	flash_tw.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.18)
	flash_tw.tween_callback(flash.queue_free)

	# The expanding shockwave ring, same as before.
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var ang := TAU * float(i) / 24.0
		pts.append(Vector2(cos(ang), sin(ang)) * 6.0)
	ring.polygon = pts
	ring.color = Color(1.0, 0.65, 0.25, 0.65)
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(radius / 6.0, radius / 6.0), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)

	# A real burst of fire-colored debris particles flying outward -
	# this is the piece that was missing before; the ring alone read as
	# flat and cheap for something that's supposed to be an explosion.
	var particles := CPUParticles2D.new()
	add_child(particles)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 28
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2(0, 60)
	particles.initial_velocity_min = radius * 1.4
	particles.initial_velocity_max = radius * 2.6
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.color_ramp = _make_debris_gradient()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0

	# A handful of thicker smoke puffs that hang a beat longer than the
	# sharp debris, so the explosion has some visual weight instead of
	# vanishing the instant the bright flash fades.
	var smoke := CPUParticles2D.new()
	add_child(smoke)
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 10
	smoke.lifetime = 0.55
	smoke.explosiveness = 0.85
	smoke.direction = Vector2(0, -1)
	smoke.spread = 60.0
	smoke.gravity = Vector2(0, -20)
	smoke.initial_velocity_min = radius * 0.3
	smoke.initial_velocity_max = radius * 0.7
	smoke.scale_amount_min = 5.0
	smoke.scale_amount_max = 9.0
	smoke.color = Color(0.25, 0.22, 0.2, 0.55)

func _make_debris_gradient() -> Gradient:
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.9, 0.5, 1.0))
	grad.add_point(0.35, Color(1.0, 0.55, 0.15, 0.9))
	grad.add_point(1.0, Color(0.3, 0.15, 0.1, 0.0))
	return grad
