extends TestCase

# Regression coverage (2026-07-17, controller audit) - Player.gd's
# _get_aim_point() was recomputed from scratch on every call (2 joypad
# axis reads + a sqrt, and a second sqrt when past deadzone) - independently
# called up to 5x per physics tick from Player.gd's own aim/body-turn/
# shoot/laser logic, PLUS once per living enemy via Enemy.gd's
# can_see_point() vision check. Now cached per physics frame (keyed off
# Engine.get_physics_frames()) so repeated calls within the same tick
# reuse one computed value instead of redoing the work.

const PlayerScene := preload("res://scenes/Player.tscn")

func test_aim_point_is_cached_for_the_current_physics_frame() -> void:
	var player = PlayerScene.instantiate()
	add_child(player)

	var point_a: Vector2 = player._get_aim_point()
	assert_eq(player._cached_aim_point_physics_frame, Engine.get_physics_frames(), "caching the aim point should stamp the current physics frame")

	var point_b: Vector2 = player._get_aim_point()
	assert_eq(point_a, point_b, "two calls within the same physics frame should return the identical cached value")

	remove_child(player)
	player.queue_free()

func test_aim_point_updates_after_a_real_physics_frame_passes() -> void:
	var player = PlayerScene.instantiate()
	add_child(player)

	player._get_aim_point()
	var stamped_frame: int = player._cached_aim_point_physics_frame

	await get_tree().physics_frame
	await get_tree().physics_frame

	player._get_aim_point()
	assert_gt(player._cached_aim_point_physics_frame, stamped_frame, "a later call after physics frames have actually advanced should re-stamp a newer frame, not keep serving a stale cache")

	remove_child(player)
	player.queue_free()
