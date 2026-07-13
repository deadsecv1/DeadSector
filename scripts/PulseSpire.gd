extends Node2D

# A tall pylon that periodically emits an electromagnetic pulse -
# visible as an expanding purple ring. Anyone caught in range when it
# fires gets their flashlight scrambled (disabled) for a few seconds.

const PULSE_INTERVAL := 6.0
const PULSE_RADIUS := 180.0
const WARNING_TIME := 1.2
const DISABLE_DURATION := 4.0

var pulse_timer: float = 0.0
var pulse_life: float = -1.0
var warning_life: float = -1.0

@onready var body: Polygon2D = $Body
@onready var core: Polygon2D = $Core

func _ready() -> void:
	pulse_timer = randf_range(2.0, PULSE_INTERVAL)
	set_process(true)

func _process(delta: float) -> void:
	pulse_timer -= delta
	if pulse_timer <= WARNING_TIME and warning_life < 0.0 and pulse_life < 0.0:
		warning_life = WARNING_TIME
	if warning_life >= 0.0:
		warning_life -= delta
		var flicker: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		core.modulate = Color(1, 1, 1, 0.6 + flicker * 0.4)
		if warning_life <= 0.0:
			warning_life = -1.0
	if pulse_timer <= 0.0:
		pulse_timer = PULSE_INTERVAL
		_fire_pulse()
	if pulse_life >= 0.0:
		pulse_life -= delta
		if pulse_life <= 0.0:
			pulse_life = -1.0
	queue_redraw()

func _fire_pulse() -> void:
	pulse_life = 0.6
	core.modulate = Color(1, 1, 1, 1)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= PULSE_RADIUS:
			if player.has_method("disable_flashlight"):
				player.disable_flashlight(DISABLE_DURATION)

func _draw() -> void:
	if pulse_life >= 0.0:
		var t: float = 1.0 - (pulse_life / 0.6)
		var r: float = PULSE_RADIUS * t
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.6, 0.3, 0.9, 0.5 * (1.0 - t)), 4.0, true)
		draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 48, Color(0.75, 0.45, 1.0, 0.3 * (1.0 - t)), 2.5, true)
