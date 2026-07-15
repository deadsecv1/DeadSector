extends CharacterBody2D

# A guildmate wandering the Guild Hall - same idle-wander, no-combat
# pattern as SocialPlaceNpc.gd (reuses Enemy.tscn's visuals via
# set_script(), never joins "enemy" so nothing here can take or deal
# damage), but represents an actual named member of the player's own
# guild roster (set externally via member_name/role before add_child(),
# same convention ArenaAlly.gd uses for team_index) instead of a random
# leaderboard name.

const ROAM_RADIUS := 90.0
const BASE_SPEED := 70.0

@export var member_name: String = "Guildmate"
@export var role: String = "Member"

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
	add_to_group("guild_hall_npc")
	origin = global_position
	# Guild-lavender tint family instead of Social Place's tactical green,
	# so a Guild Hall crowd reads as visually distinct from an Arena one.
	var tint := Color(randf_range(0.85, 1.15), randf_range(0.85, 1.15), randf_range(0.85, 1.15), 1)
	torso.color = Color(0.3, 0.2, 0.4, 1) * tint
	chest_strap.color = Color(0.18, 0.1, 0.26, 1) * tint
	mask.visible = false
	cap.visible = true
	_load_real_player_sprite(tint)
	name_tag.visible = true
	name_tag.text = "%s [%s]" % [member_name, role] if role != "Member" else member_name
	name_tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1) if role != "Member" else Color(0.85, 0.7, 0.95, 1))
	_pick_new_roam_target()

# Same real_player art Enemy.gd's Arena opponents use - this script is
# set_script()'d onto an Enemy.tscn instance, so it never runs Enemy.gd's
# own _ready()/_try_load_external_sprite().
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
