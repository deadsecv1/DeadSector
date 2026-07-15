extends CharacterBody2D

# A purely decorative "real player" for the Social Place hub - reuses
# Enemy.tscn's rich visuals via set_script() (same technique ArenaAlly.gd
# uses), but with idle wander instead of any combat AI, and deliberately
# never joins the "enemy" group - Bullet.gd only damages "enemy"-group
# bodies (see Bullet.gd's hit checks), so the player can fire here
# freely without anyone, including these NPCs, ever taking damage.

const ROAM_RADIUS := 90.0
const BASE_SPEED := 70.0

var origin: Vector2 = Vector2.ZERO
var roam_target: Vector2 = Vector2.ZERO
var roam_timer: float = 0.0

@onready var visuals: Node2D = $Visuals
@onready var left_leg: Polygon2D = $Visuals/LeftLeg
@onready var right_leg: Polygon2D = $Visuals/RightLeg
@onready var torso: Polygon2D = $Visuals/Torso
@onready var chest_strap: Polygon2D = $Visuals/ChestStrap
@onready var mask: Polygon2D = $Visuals/Mask
@onready var cap: Polygon2D = $Visuals/Cap
@onready var name_tag: Label = $Visuals/NameTag
@onready var external_sprite: Sprite2D = $Visuals/ExternalSprite

var walk_cycle: float = 0.0

func _ready() -> void:
	add_to_group("social_place_npc")
	origin = global_position
	# Same tactical-green look Enemy.gd's real-player variant uses, with
	# a little per-instance tint variety so a crowd of 5-8 doesn't read
	# as identical clones.
	var tint := Color(randf_range(0.85, 1.15), randf_range(0.85, 1.15), randf_range(0.85, 1.15), 1)
	torso.color = Color(0.14, 0.3, 0.17, 1) * tint
	chest_strap.color = Color(0.07, 0.17, 0.09, 1) * tint
	mask.visible = false
	cap.visible = true
	_load_real_player_sprite(tint)
	name_tag.visible = true
	name_tag.text = GameManager.LEADERBOARD_NAMES[randi() % GameManager.LEADERBOARD_NAMES.size()]
	name_tag.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	_pick_new_roam_target()

# Same real_player art Enemy.gd's Arena opponents use - this script is
# set_script()'d onto an Enemy.tscn instance, so it never runs Enemy.gd's
# own _ready()/_try_load_external_sprite(). Reuses the same per-instance
# tint already computed for the vector fallback so both paths stay in sync.
func _load_real_player_sprite(tint: Color) -> void:
	if not ResourceLoader.exists("res://assets/enemy_real_player.png"):
		return
	var tex: Texture2D = load("res://assets/enemy_real_player.png")
	if tex == null:
		return
	external_sprite.texture = tex
	external_sprite.visible = true
	external_sprite.modulate = tint
	for n in ["LeftLeg", "RightLeg", "Torso", "ChestStrap", "Head", "Mask", "Cap", "TorsoOutline", "HeadOutline"]:
		var node = get_node_or_null("Visuals/" + n)
		if node:
			node.visible = false

func _pick_new_roam_target() -> void:
	var ang := randf_range(0.0, TAU)
	var dist := randf_range(20.0, ROAM_RADIUS)
	roam_target = origin + Vector2(cos(ang), sin(ang)) * dist
	roam_timer = randf_range(3.0, 6.0)

func _physics_process(delta: float) -> void:
	roam_timer -= delta
	if roam_timer <= 0.0:
		_pick_new_roam_target()
	var dist := global_position.distance_to(roam_target)
	if dist > 10.0:
		var dir := (roam_target - global_position).normalized()
		velocity = velocity.lerp(dir * BASE_SPEED, clamp(delta * 4.0, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 4.0, 0.0, 1.0))
	move_and_slide()
	walk_cycle += delta * 6.0
	if velocity.length() > 5.0:
		left_leg.position.y = 16 + sin(walk_cycle) * 3.0
		right_leg.position.y = 16 + sin(walk_cycle + PI) * 3.0
	else:
		left_leg.position.y = 16
		right_leg.position.y = 16
