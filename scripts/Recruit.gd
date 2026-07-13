extends CharacterBody2D

# A hired companion (Clarity, Sorrow, Glenn, or Big Crax): follows the
# player around the map and automatically fights whatever's nearby.
# Not in the "player" or "enemy" groups, so bullets pass through it -
# a simple, always-reliable teammate rather than a fragile one.

@export var recruit_id: String = "clarity"
@export var move_speed: float = 235.0
@export var detection_range: float = 420.0
@export var attack_damage: int = 14
@export var shoot_cooldown: float = 0.5

var player: Node2D = null
var target_enemy: Node2D = null
var can_shoot: bool = true
var recoil: float = 0.0
var walk_cycle: float = 0.0

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const USERNAME_PREFIXES := ["Shadow", "Ghost", "Raven", "Viper", "Reaper", "Rogue", "Silent", "Iron", "Night", "Rusty", "Grim", "Cold", "Wolf", "Blaze", "Dusty", "Steel"]
const USERNAME_SUFFIXES := ["Hunter", "99", "Actual", "One", "Six", "Wolf", "Fang", "X", "Zero", "13", "Prime", "Runner", "Vex", "77", "Reaper", "Ash"]

@onready var visuals: Node2D = $Visuals
@onready var torso: Polygon2D = $Visuals/Torso
@onready var chest_strap: Polygon2D = $Visuals/ChestStrap
@onready var mask: Polygon2D = $Visuals/Mask
@onready var cap: Polygon2D = $Visuals/Cap
@onready var name_tag: Label = $Visuals/NameTag
@onready var gun_pivot: Node2D = $Visuals/GunPivot
@onready var gun_visual: Node2D = $Visuals/GunPivot/GunVisual
@onready var muzzle: Marker2D = $Visuals/GunPivot/GunVisual/Muzzle
@onready var muzzle_flash: Polygon2D = $Visuals/GunPivot/GunVisual/MuzzleFlash

func _ready() -> void:
	add_to_group("recruit")
	var data: Dictionary = GameManager.RECRUITS.get(recruit_id, {})
	var base_color: Color = data.get("color", Color(0.4, 0.4, 0.4, 1))
	torso.color = base_color
	chest_strap.color = base_color.darkened(0.35)
	mask.visible = false
	cap.visible = true
	cap.color = base_color.darkened(0.2)
	name_tag.visible = true
	name_tag.text = "%s%s" % [USERNAME_PREFIXES[randi() % USERNAME_PREFIXES.size()], USERNAME_SUFFIXES[randi() % USERNAME_SUFFIXES.size()]]
	name_tag.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1))

	attack_damage = int(data.get("base_damage", 14)) + int(GameManager.get_recruit_bonus(recruit_id, "damage"))
	move_speed += GameManager.get_recruit_bonus(recruit_id, "speed")

	var equipment: Dictionary = GameManager.recruit_equipment.get(recruit_id, {})
	var weapon_item = equipment.get("weapon")
	if weapon_item != null:
		var weapon_icon: String = weapon_item.get("icon_key", "pistol")
		if weapon_icon == "rifle":
			gun_visual.scale = Vector2(1.35, 1.0)
		elif weapon_icon == "sniper":
			gun_visual.scale = Vector2(1.65, 1.0)

	if recruit_id == "big_crax":
		gun_visual.scale = Vector2(1.8, 1.8)

	scale = Vector2.ONE * float(data.get("scale", 1.0))
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		call_deferred("_find_player")
		return

	walk_cycle += delta
	_find_target_enemy()

	if target_enemy != null and is_instance_valid(target_enemy):
		gun_pivot.look_at(target_enemy.global_position)
		var dist_to_target: float = global_position.distance_to(target_enemy.global_position)
		if dist_to_target <= detection_range and can_shoot and _has_line_of_sight(target_enemy):
			_shoot()
		if dist_to_target > 160.0:
			_move_toward(target_enemy.global_position, delta)
		else:
			velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 10.0, 0.0, 1.0))
			move_and_slide()
	else:
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() > 75.0:
			_move_toward(player.global_position, delta)
		else:
			velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 10.0, 0.0, 1.0))
			move_and_slide()
		if to_player.length() > 4.0:
			gun_pivot.rotation = lerp_angle(gun_pivot.rotation, to_player.angle(), delta * 4.0)

	recoil = lerp(recoil, 0.0, delta * 14.0)
	gun_visual.position = Vector2(recoil, 0)
	var amp: float = clamp(velocity.length() / move_speed, 0.0, 1.0)
	var bob: float = sin(walk_cycle * 10.0) * amp * 2.0
	visuals.position = Vector2(0, bob)

func _move_toward(target_pos: Vector2, delta: float) -> void:
	var dir: Vector2 = (target_pos - global_position).normalized()
	velocity = velocity.lerp(dir * move_speed, clamp(delta * 10.0, 0.0, 1.0))
	move_and_slide()

func _find_target_enemy() -> void:
	var best: Node2D = null
	var best_dist: float = detection_range
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	target_enemy = best

func _has_line_of_sight(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(muzzle.global_position, target.global_position)
	query.collision_mask = 1
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider = result.get("collider")
	return collider == target or (collider != null and collider.is_in_group("enemy"))

func _shoot() -> void:
	can_shoot = false
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = (target_enemy.global_position - muzzle.global_position).normalized()
	bullet.is_enemy_bullet = false
	bullet.damage = attack_damage
	if recruit_id == "big_crax":
		bullet.modulate = Color(0.8, 0.3, 0.95, 1)
		bullet.scale = Vector2(2.1, 2.1)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	recoil = -6.0
	muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
