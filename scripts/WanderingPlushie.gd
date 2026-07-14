extends Node2D

# A decorative Plushie critter wandering slowly near Rose in the Hideout -
# purely cosmetic (no combat, no following, no interaction), reusing the
# same quadruped body art as an equipped Pet (see Pet.gd), since these
# are literally what Rose turns a Plushie item into.

@export var wander_radius: float = 90.0
@export var speed: float = 34.0
# Extra pause before the very first move - lets a fresh vignette settle
# instead of every plushie immediately setting off at once.
@export var start_delay: float = 0.0

# When true, this plushie ambles toward the mouse cursor instead of
# picking random points - used by the Rose menu vignette. The tracked
# point trails well behind the real cursor (follow_lag) so it's a slow,
# delayed amble rather than an instant/teleporting follow, and is only
# clamped to the screen edges (not wander_radius, which is unused in
# this mode) - it can walk anywhere on screen, not just a small patch.
@export var follow_cursor: bool = false
@export var follow_lag: float = 2.2
@export var follow_edge_margin: float = 30.0

@export var body_color: Color = Color(0.85, 0.55, 0.65, 1)

var _anchor: Vector2
var _target: Vector2
var _wait_timer: float = 0.0
var _lagged_cursor: Vector2 = Vector2.ZERO

@onready var body: Polygon2D = $Body
@onready var head: Polygon2D = $Head
@onready var tail: Polygon2D = $TailBack
@onready var leg_fl: Polygon2D = $LegFrontLeft
@onready var leg_fr: Polygon2D = $LegFrontRight
@onready var leg_bl: Polygon2D = $LegBackLeft
@onready var leg_br: Polygon2D = $LegBackRight

func _ready() -> void:
	_anchor = global_position
	_lagged_cursor = _anchor
	var dark := Color(body_color.r * 0.75, body_color.g * 0.75, body_color.b * 0.75, 1.0)
	body.color = body_color
	head.color = body_color
	tail.color = body_color
	leg_fl.color = dark
	leg_fr.color = dark
	leg_bl.color = dark
	leg_br.color = dark
	_pick_new_target()
	_wait_timer = start_delay + randf_range(0.0, 2.0)

func _pick_new_target() -> void:
	var ang := randf_range(0.0, TAU)
	var dist := randf_range(20.0, wander_radius)
	_target = _anchor + Vector2(cos(ang), sin(ang)) * dist
	_wait_timer = randf_range(2.0, 4.5)

func _process(delta: float) -> void:
	if follow_cursor:
		var mouse := get_global_mouse_position()
		_lagged_cursor = _lagged_cursor.lerp(mouse, clamp(delta / follow_lag, 0.0, 1.0))
		var vp_size: Vector2 = get_viewport_rect().size
		_target = Vector2(
			clamp(_lagged_cursor.x, follow_edge_margin, vp_size.x - follow_edge_margin),
			clamp(_lagged_cursor.y, follow_edge_margin, vp_size.y - follow_edge_margin)
		)

	var to_target := _target - global_position
	var dist := to_target.length()
	if dist > 4.0:
		global_position += to_target.normalized() * speed * delta
		body.position.y = sin(Time.get_ticks_msec() * 0.008) * 1.5
	elif not follow_cursor:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_pick_new_target()
