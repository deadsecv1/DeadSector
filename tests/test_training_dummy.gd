extends TestCase

# Regression coverage (2026-07-17 audit) - the Hideout's shooting-range
# TrainingDummy is in group "enemy" (so bullet hit-detection works for
# free) but never matched the fuller contract Grenade.gd/FireGrenade.gd
# expect from anything in that group: Grenade.gd's _explode() reads
# `enemy.health` directly (TrainingDummy had no such property) and both
# grenade scripts call `enemy.take_damage(damage, "weapon name")` with an
# optional second arg (for kill-log/kill-credit) that TrainingDummy's
# original 1-arg take_damage(amount) couldn't accept. Either one threw a
# real runtime script error the instant a thrown grenade landed near the
# dummy, aborting the rest of _explode()/_deal_damage(). Fixed by giving
# TrainingDummy a large never-actually-depleting `health` and an optional
# `_weapon_name` param on take_damage().

const GRENADE_SCENE := preload("res://scenes/Grenade.tscn")
const FIRE_GRENADE_SCENE := preload("res://scenes/FireGrenade.tscn")
const TRAINING_DUMMY_SCENE := preload("res://scenes/TrainingDummy.tscn")

func test_frag_grenade_explosion_damages_the_training_dummy_without_erroring() -> void:
	var dummy = TRAINING_DUMMY_SCENE.instantiate()
	add_child(dummy)
	dummy.global_position = Vector2.ZERO

	var grenade = GRENADE_SCENE.instantiate()
	grenade.damage = 40
	grenade.radius = 95.0
	grenade.target_position = Vector2.ZERO
	add_child(grenade)
	grenade.global_position = Vector2.ZERO
	# Skip the travel tween (_ready() already queued it) and detonate
	# directly - this is the exact call site that used to error.
	grenade._explode()

	assert_eq(dummy.total_damage, 40, "the dummy should have taken the grenade's full damage with no script error")

	remove_child(dummy)
	dummy.queue_free()
	if is_instance_valid(grenade):
		remove_child(grenade)
		grenade.queue_free()

func test_fire_grenade_tick_damages_the_training_dummy_without_erroring() -> void:
	var dummy = TRAINING_DUMMY_SCENE.instantiate()
	add_child(dummy)
	dummy.global_position = Vector2.ZERO

	var fire = FIRE_GRENADE_SCENE.instantiate()
	fire.damage_per_tick = 10
	fire.radius = 95.0
	add_child(fire)
	fire.global_position = Vector2.ZERO
	fire._deal_damage()

	assert_eq(dummy.total_damage, 10, "the dummy should have taken one fire tick's damage with no script error")

	remove_child(dummy)
	dummy.queue_free()
	remove_child(fire)
	fire.queue_free()
