extends CharacterBody2D

# A stationary/lightly-patrolling Gauntlet enemy that shoots instead of
# charging in. Shows up starting Level 2 to break up the pacing so it's
# not just melee enemies the whole way through.

const GRAVITY := 1400.0
const SHOOT_RANGE := 500.0
const SHOOT_COOLDOWN := 0.2
const PATROL_SPEED := 30.0

@export var base_health: int = 120
@export var patrol_distance: float = 40.0

var health: int
var max_health: int
var facing: int = 1
var start_x: float = 0.0
var shoot_timer: float = 0.0
var player_ref: Node = null
var difficulty: float = 1.0

const PROJECTILE_SCENE := preload("res://scenes/GauntletProjectile.tscn")
const LOOT_SCENE := preload("res://scenes/GauntletLoot.tscn")
const TEX_IDLE := preload("res://assets/sprites/gauntlet_ranged/idle.png")
const TEX_WALK := preload("res://assets/sprites/gauntlet_ranged/walk.png")

@onready var sprite: Node = $AnimatedSprite
@onready var hp_bar: ProgressBar = $HpBar
@onready var muzzle: Marker2D = $Muzzle

func _ready() -> void:
	add_to_group("gauntlet_enemy")
	start_x = global_position.x
	difficulty = GameManager.get_gauntlet_difficulty(GameManager.gauntlet_current_level)
	max_health = int(base_health * difficulty)
	health = max_health
	player_ref = get_tree().get_first_node_in_group("gauntlet_player")
	shoot_timer = randf_range(0.0, SHOOT_COOLDOWN)

	sprite.add_animation("idle", TEX_IDLE, 6)
	sprite.add_animation("walk", TEX_WALK, 8)
	sprite.frame_rate = 8.0
	sprite.play("idle")

	hp_bar.max_value = max_health
	hp_bar.value = health

func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta

	var offset := global_position.x - start_x
	if offset > patrol_distance:
		facing = -1
	elif offset < -patrol_distance:
		facing = 1
	velocity.x = facing * PATROL_SPEED
	sprite.flip_h = facing < 0
	sprite.play("walk" if abs(velocity.x) > 5.0 else "idle")
	move_and_slide()

	if player_ref == null or not is_instance_valid(player_ref):
		return
	var to_player: Vector2 = player_ref.global_position - global_position
	if to_player.length() > SHOOT_RANGE:
		return
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		_shoot(to_player.normalized())
		shoot_timer = SHOOT_COOLDOWN

func _shoot(dir: Vector2) -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = muzzle.global_position
	proj.direction = dir
	proj.rotation = dir.angle()
	proj.damage = int(30 * difficulty)

func take_damage(amount: int) -> void:
	health -= amount
	hp_bar.value = health
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color(1, 0.4, 0.4, 1), 0.05)
	flash.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	if health <= 0:
		_die()

func _spawn_death_particles(color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 22
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 260)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.color = color
	var parent := get_parent()
	if parent == null:
		return
	parent.call_deferred("add_child", particles)
	particles.call_deferred("set", "global_position", global_position)
	particles.call_deferred("set", "emitting", true)
	get_tree().create_timer(particles.lifetime + 0.15).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _die() -> void:
	_spawn_death_particles(Color(1, 0.55, 0.2, 1))
	GameManager.mark_enemy_discovered("gauntlet_ranged")
	if randf() < 0.5:
		GameManager.grant_salvaged_beasts_tickets(randi_range(1, 3))
	if randf() < 0.008:
		var rare_pet_rarity: String = ["rare", "epic", "legendary"][randi() % 3]
		var pet_instance_id := GameManager.hatch_egg(rare_pet_rarity)
		var pet_data := GameManager.get_pet_data(pet_instance_id)
		GameManager.toast_requested.emit("A wild %s followed you home!" % pet_data.get("name", "creature"))
	var drop_count := randi_range(1, 3)
	for i in range(drop_count):
		var item := GameManager.roll_gauntlet_loot()
		var loot = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", loot)
		loot.call_deferred("setup", item)
		var spawn_pos: Vector2 = global_position + Vector2(randf_range(-20, 20), -10)
		loot.set_deferred("global_position", spawn_pos)
	var engram := GameManager.roll_gauntlet_engram()
	if not engram.is_empty():
		GameManager.add_engram(engram)
	queue_free()
