extends CharacterBody2D

# A simulated Recruit-invite party member - same follow/fight AI as
# Recruit.gd (open-map companion behavior: follows the player loosely,
# retargets on a throttle, requires line-of-sight to shoot), just with
# its identity coming from a chat invite's party entry (name/portrait/
# rank, the same shape used everywhere else simulated players are
# rendered) instead of GameManager.RECRUITS. Spawned via set_script()
# onto a Recruit.tscn instance - reuses that scene's visuals exactly
# the way ArenaAlly.gd reuses Enemy.tscn's.

@export var move_speed: float = 235.0
@export var detection_range: float = 420.0
@export var attack_damage: int = 14
@export var shoot_cooldown: float = 0.5
# Set by whoever instantiates this, before add_child() - which invite
# party member this instance represents, and where it should idle
# relative to the player when nothing's fighting.
var party_entry: Dictionary = {}
var follow_offset: Vector2 = Vector2(-70, 0)

# Retargeting every physics tick is an O(members x enemies) group scan -
# a new nearest target every 0.25s is imperceptible during combat but
# cuts that scan rate 15x. Matches Recruit.gd/Pet.gd's own pattern.
const RETARGET_INTERVAL := 0.25

var player: Node2D = null
var target_enemy: Node2D = null
var can_shoot: bool = true
var recoil: float = 0.0
var walk_cycle: float = 0.0
var _retarget_timer: float = 0.0
var _chat_cooldown_until_ms: int = 0

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const CHAT_LINES := [
	"On it!", "Covering you!", "Got your six!", "Nice shot!", "Push up!",
	"Reloading!", "I see them!", "Watch your flank!", "Let's go!", "Clear!",
]

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
	var rank_idx: int = int(party_entry.get("rank_full_idx", 0))
	var tier: Dictionary = GameManager.get_rank_tier(rank_idx)
	var base_color: Color = tier.get("color", Color(0.4, 0.4, 0.4, 1))
	torso.color = base_color
	chest_strap.color = base_color.darkened(0.35)
	mask.visible = false
	cap.visible = true
	cap.color = base_color.darkened(0.2)
	name_tag.visible = true
	name_tag.text = str(party_entry.get("name", "Operative"))
	name_tag.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1))
	_chat_cooldown_until_ms = Time.get_ticks_msec() + randi_range(2000, 6000)
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		call_deferred("_find_player")
		return
	_maybe_chat()
	walk_cycle += delta
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or target_enemy == null or not is_instance_valid(target_enemy):
		_retarget_timer = RETARGET_INTERVAL
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
		var follow_point: Vector2 = player.global_position + follow_offset
		var to_follow: Vector2 = follow_point - global_position
		if to_follow.length() > 75.0:
			_move_toward(follow_point, delta)
		else:
			velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 10.0, 0.0, 1.0))
			move_and_slide()
		if to_follow.length() > 4.0:
			gun_pivot.rotation = lerp_angle(gun_pivot.rotation, to_follow.angle(), delta * 4.0)

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
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	recoil = -6.0
	muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false
	await get_tree().create_timer(shoot_cooldown).timeout
	if is_instance_valid(self):
		can_shoot = true

# Occasional speech bubble (~15-30s), same lightweight floating-Label
# pattern Pet.gd/ArenaAlly.gd already use for their own chat.
func _maybe_chat() -> void:
	if Time.get_ticks_msec() < _chat_cooldown_until_ms:
		return
	_chat_cooldown_until_ms = Time.get_ticks_msec() + randi_range(15000, 30000)
	var bubble := Label.new()
	bubble.text = CHAT_LINES[randi() % CHAT_LINES.size()]
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 3)
	bubble.position = Vector2(-30, -60)
	add_child(bubble)
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
