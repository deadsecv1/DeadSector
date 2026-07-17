extends TestCase

# Regression coverage (2026-07-17 audit) - Enemy.gd's _current_chase_target()
# deliberately spreads opponent fire across the player AND every
# arena_ally ("so opponents spread fire across the team instead of every
# opponent dogpiling one person"), but ArenaAlly.gd had no health/
# take_damage() at all and Bullet.gd's enemy-bullet hit check only ever
# looked for group "player" - every ally was completely unkillable, making
# Arena matches easier than intended. Fixed by giving ArenaAlly.gd real
# health/take_damage()/death handling and adding the missing group check
# in Bullet.gd.

const EnemyScene := preload("res://scenes/Enemy.tscn")
const ArenaAllyScript := preload("res://scripts/ArenaAlly.gd")
const BulletScene := preload("res://scenes/Bullet.tscn")

func _make_ally():
	var ally = EnemyScene.instantiate()
	ally.set_script(ArenaAllyScript)
	add_child(ally)
	return ally

func test_ally_takes_damage_and_dies() -> void:
	var ally = _make_ally()
	assert_eq(ally.health, ally.max_health, "a fresh ally should start at full health")
	assert_false(ally.is_dead)

	ally.take_damage(ally.max_health + 50)
	assert_true(ally.is_dead, "an ally should actually die once health reaches 0")
	assert_true(ally.health <= 0, "health should not stay positive after a lethal hit")
	assert_false(ally.is_in_group("arena_ally"), "a dead ally should leave the arena_ally group so it stops drawing fire/being targetable")

	remove_child(ally)
	ally.queue_free()

func test_take_damage_after_death_is_a_no_op() -> void:
	var ally = _make_ally()
	ally.take_damage(ally.max_health + 50)
	var health_after_death: int = ally.health
	ally.take_damage(50)
	assert_eq(ally.health, health_after_death, "damage after death should not further change health")
	remove_child(ally)
	ally.queue_free()

func test_bullet_applies_damage_to_an_arena_ally() -> void:
	var ally = _make_ally()
	var bullet = BulletScene.instantiate()
	bullet.is_enemy_bullet = true
	bullet.damage = 30
	bullet.direction = Vector2.RIGHT
	add_child(bullet)
	bullet.global_position = ally.global_position

	bullet._on_body_entered(ally)

	assert_eq(ally.health, ally.max_health - 30, "an enemy bullet hitting an arena_ally must actually apply damage")

	remove_child(ally)
	ally.queue_free()
	if is_instance_valid(bullet):
		remove_child(bullet)
		bullet.queue_free()
