extends CharacterBody2D

# A simple Gauntlet enemy - patrols a platform, charges the player when
# close, deals contact damage. Health and damage scale with the level's
# difficulty via GameManager.get_gauntlet_difficulty().

const GRAVITY := 1400.0
const PATROL_SPEED := 70.0
const CHASE_SPEED := 130.0
const AGGRO_RANGE := 220.0
const CONTACT_DAMAGE := 24
const CONTACT_INTERVAL := 0.8

@export var base_health: int = 160
@export var patrol_distance: float = 120.0
@export var idle_texture: Texture2D = preload("res://assets/sprites/gauntlet_enemy/idle.png")
@export var walk_texture: Texture2D = preload("res://assets/sprites/gauntlet_enemy/walk.png")
@export var idle_frames: int = 6
@export var walk_frames: int = 6

var health: int
var max_health: int
var facing: int = 1
var start_x: float = 0.0
var contact_timer: float = 0.0
var player_ref: Node = null
var difficulty: float = 1.0

# queue_free() only removes the node at end of frame, so without this
# guard a second take_damage() landing in the same frame (e.g. the
# player's melee and a pet's own attack both connecting at once) could
# re-enter _die() and double-grant its loot/ticket/engram rolls.
var is_dead: bool = false

const LOOT_SCENE := preload("res://scenes/GauntletLoot.tscn")

@onready var sprite: Node = $AnimatedSprite
@onready var hp_bar: ProgressBar = $HpBar

func _ready() -> void:
	add_to_group("gauntlet_enemy")
	start_x = global_position.x
	difficulty = GameManager.get_gauntlet_difficulty(GameManager.gauntlet_current_level)
	max_health = int(base_health * difficulty)
	health = max_health
	player_ref = get_tree().get_first_node_in_group("gauntlet_player")

	sprite.add_animation("idle", idle_texture, idle_frames)
	sprite.add_animation("walk", walk_texture, walk_frames)
	sprite.frame_rate = 8.0
	sprite.play("idle")

	hp_bar.max_value = max_health
	hp_bar.value = health

var is_aggroed: bool = false
const DEAGGRO_RANGE := 480.0

func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta

	if player_ref != null and is_instance_valid(player_ref):
		var dist := global_position.distance_to(player_ref.global_position)
		if dist < AGGRO_RANGE:
			is_aggroed = true
		elif dist > DEAGGRO_RANGE:
			is_aggroed = false
		if is_aggroed:
			var dir_to_player: float = sign(player_ref.global_position.x - global_position.x)
			facing = int(dir_to_player) if dir_to_player != 0 else facing
			velocity.x = dir_to_player * CHASE_SPEED
		else:
			_patrol()
	else:
		_patrol()

	sprite.flip_h = facing < 0
	sprite.play("walk" if abs(velocity.x) > 5.0 else "idle")
	move_and_slide()

	contact_timer -= delta
	if contact_timer <= 0.0 and player_ref != null and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < 34.0:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(int(CONTACT_DAMAGE * difficulty))
			contact_timer = CONTACT_INTERVAL

func _patrol() -> void:
	var offset := global_position.x - start_x
	if offset > patrol_distance:
		facing = -1
	elif offset < -patrol_distance:
		facing = 1
	velocity.x = facing * PATROL_SPEED

func take_damage(amount: int) -> void:
	if is_dead:
		return
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
	if is_dead:
		return
	is_dead = true
	_spawn_death_particles(Color(1, 0.3, 0.3, 1))
	GameManager.mark_enemy_discovered("gauntlet_stalker")
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
