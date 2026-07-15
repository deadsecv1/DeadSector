extends CharacterBody2D

# A purely ambient guildmate NPC that appears in the Hideout once the
# player is in a guild - "sharing the Hideout" in spirit, matching the
# game's established simulated-multiplayer pattern (Global Chat, Find a
# Team, etc.) rather than any real shared session. No combat, no
# following into raids, no player interaction - just gentle wandering
# presence. Reuses Recruit.tscn's visuals via set_script(), the same
# swap ArenaAlly.gd already does with Enemy.tscn.

var guildmate_name: String = "Operative"

var _home_position: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
const WANDER_RADIUS := 90.0
const WANDER_SPEED := 45.0

@onready var visuals: Node2D = $Visuals
@onready var torso: Polygon2D = $Visuals/Torso
@onready var chest_strap: Polygon2D = $Visuals/ChestStrap
@onready var mask: Polygon2D = $Visuals/Mask
@onready var cap: Polygon2D = $Visuals/Cap
@onready var name_tag: Label = $Visuals/NameTag
@onready var gun_pivot: Node2D = $Visuals/GunPivot

func _ready() -> void:
	_home_position = global_position
	_wander_target = global_position
	torso.color = Color(0.55, 0.4, 0.75, 1)
	chest_strap.color = Color(0.4, 0.28, 0.55, 1)
	mask.visible = false
	cap.visible = true
	cap.color = Color(0.35, 0.24, 0.5, 1)
	name_tag.visible = true
	name_tag.text = guildmate_name
	name_tag.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0, 1))
	gun_pivot.visible = false

func _physics_process(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(3.0, 6.0)
		_wander_target = _home_position + Vector2(randf_range(-WANDER_RADIUS, WANDER_RADIUS), randf_range(-WANDER_RADIUS, WANDER_RADIUS))
	var to_target: Vector2 = _wander_target - global_position
	if to_target.length() > 6.0:
		velocity = to_target.normalized() * WANDER_SPEED
		move_and_slide()
	else:
		velocity = Vector2.ZERO
