extends CharacterBody2D

# A simulated teammate for Arena 2v2, matching the game's honest
# "simulated, not live netcode" framing used elsewhere. This script
# gets swapped onto an Enemy.tscn instance (via set_script(), before
# it's added to the tree) so it reuses that scene's rich visuals
# without inheriting any of Enemy.gd's hostile-to-player behavior.
#
# It never targets or damages the player - instead it moves toward and
# fires on the nearest opponent (group "enemy"), using the same bullet
# scene the player uses (is_enemy_bullet = false) so hits register
# normally on the opposing Enemy.gd instances. It doesn't join the
# "enemy" group itself, so the player's own shots can't hit it either.

@export var speed: float = 120.0
@export var detection_range: float = 480.0
@export var attack_range: float = 260.0
@export var shoot_cooldown: float = 1.1
# Which slot in current_arena_match["team1"] this particular ally
# represents - team1[0] is always the player, so the first ally is 1,
# the second is 2, and so on (set by TheGrid.gd right after spawning,
# before it's added to the tree, since matches can now field several
# allies at once instead of just one).
@export var team_index: int = 1

var can_shoot: bool = true
var target: Node2D = null
var walk_cycle: float = 0.0
var chat_cooldown_until_ms: int = 0

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const CHAT_LINES := [
	"On you!", "Covering!", "Got one!", "Watch your flank!", "Pushing up!",
	"Nice shot!", "Reloading!", "Stay close!", "I see them!", "Let's go!",
]

@onready var visuals: Node2D = $Visuals
@onready var gun_pivot: Node2D = $Visuals/GunPivot
@onready var muzzle: Marker2D = $Visuals/GunPivot/GunVisual/Muzzle
@onready var muzzle_flash: Polygon2D = $Visuals/GunPivot/GunVisual/MuzzleFlash
@onready var left_leg: Polygon2D = $Visuals/LeftLeg
@onready var right_leg: Polygon2D = $Visuals/RightLeg
@onready var torso: Polygon2D = $Visuals/Torso
@onready var chest_strap: Polygon2D = $Visuals/ChestStrap
@onready var mask: Polygon2D = $Visuals/Mask
@onready var cap: Polygon2D = $Visuals/Cap
@onready var name_tag: Label = $Visuals/NameTag

func _ready() -> void:
	add_to_group("arena_ally")
	torso.color = Color(0.14, 0.22, 0.5, 1)
	chest_strap.color = Color(0.07, 0.11, 0.28, 1)
	mask.visible = false
	cap.visible = true
	visuals.modulate = Color(0.8, 0.88, 1.05, 1)
	var teammate: Dictionary = {}
	var team1: Array = GameManager.current_arena_match.get("team1", [])
	if team1.size() > team_index:
		teammate = team1[team_index]
	name_tag.visible = true
	name_tag.text = str(teammate.get("name", "Teammate"))
	name_tag.add_theme_color_override("font_color", Color(0.45, 0.68, 1, 1))
	chat_cooldown_until_ms = Time.get_ticks_msec() + randi_range(500, 2000)

func _physics_process(delta: float) -> void:
	_maybe_chat()
	_acquire_target()
	if target == null or not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta)
		move_and_slide()
		return
	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	var dir: Vector2 = to_target.normalized()
	gun_pivot.rotation = dir.angle()
	if dist > attack_range:
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO
		if can_shoot:
			_shoot(dir)
	move_and_slide()
	walk_cycle += delta * 8.0
	if velocity.length() > 5.0:
		left_leg.position.y = 16 + sin(walk_cycle) * 3.0
		right_leg.position.y = 16 + sin(walk_cycle + PI) * 3.0
	else:
		left_leg.position.y = 16
		right_leg.position.y = 16

func _acquire_target() -> void:
	var best: Node2D = null
	var best_dist: float = detection_range
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	target = best

func _shoot(dir: Vector2) -> void:
	can_shoot = false
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = dir
	bullet.is_enemy_bullet = false
	bullet.damage = 16
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	_flash_muzzle()
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

# A speech bubble roughly every ~2s, same lightweight floating-Label
# pattern Pet.gd already uses for its own chat, just on a much shorter
# cooldown since this is meant to read as constant chatter from a
# teammate actually fighting alongside you, not an occasional aside.
func _maybe_chat() -> void:
	if Time.get_ticks_msec() < chat_cooldown_until_ms:
		return
	chat_cooldown_until_ms = Time.get_ticks_msec() + 2000
	var bubble := Label.new()
	bubble.text = CHAT_LINES[randi() % CHAT_LINES.size()]
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 3)
	bubble.position = Vector2(-30, -92)
	add_child(bubble)
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)

func _flash_muzzle() -> void:
	muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false
