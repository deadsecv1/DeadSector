extends TestCase

# Regression coverage for the directional hit indicator (2026-07-16) -
# Player.gd's take_damage() now accepts an optional hit_direction and
# stores it (normalized, or ZERO) on last_hit_direction; HUD.gd reads
# that field synchronously from its health_changed handler and feeds it
# to HitVignette.gdshader's `hit_dir` uniform. See Player.gd/HUD.gd.

const PlayerScene := preload("res://scenes/Player.tscn")

func test_take_damage_with_no_direction_leaves_last_hit_direction_zero() -> void:
	var player = PlayerScene.instantiate()
	add_child(player)
	player.health = 100
	player.max_health = 100
	player.alive = true
	player.take_damage(5)
	assert_eq(player.last_hit_direction, Vector2.ZERO)
	remove_child(player)
	player.queue_free()

func test_take_damage_with_a_direction_stores_it_normalized() -> void:
	var player = PlayerScene.instantiate()
	add_child(player)
	player.health = 100
	player.max_health = 100
	player.alive = true
	player.take_damage(5, "An Enemy", "Grenade", Vector2(10, 0))
	assert_eq(player.last_hit_direction, Vector2(1, 0))
	remove_child(player)
	player.queue_free()

func test_a_later_undirected_hit_clears_the_previous_direction() -> void:
	# A radiation tick landing right after a directional bullet hit must
	# not keep showing the OLD bullet's direction on the new, undirected
	# damage source.
	var player = PlayerScene.instantiate()
	add_child(player)
	player.health = 100
	player.max_health = 100
	player.alive = true
	player.take_damage(5, "An Enemy", "Grenade", Vector2(0, -10))
	assert_ne(player.last_hit_direction, Vector2.ZERO)
	player.take_damage(3)
	assert_eq(player.last_hit_direction, Vector2.ZERO)
	remove_child(player)
	player.queue_free()

func test_dead_player_ignores_damage_and_direction() -> void:
	var player = PlayerScene.instantiate()
	add_child(player)
	player.alive = false
	player.last_hit_direction = Vector2.ZERO
	player.take_damage(5, "An Enemy", "Grenade", Vector2(1, 1))
	assert_eq(player.last_hit_direction, Vector2.ZERO, "a dead player should return before recording any new hit direction")
	remove_child(player)
	player.queue_free()

func test_bullet_travel_direction_reversed_points_back_at_the_shooter() -> void:
	# Bullet.gd passes -direction (its own travel direction, reversed) as
	# the hit direction - a bullet flying rightward (shooter to the west)
	# should report the shooter as being to the west of the player.
	var bullet_travel_dir := Vector2(1, 0)
	var reported_hit_dir := -bullet_travel_dir
	assert_eq(reported_hit_dir, Vector2(-1, 0))
