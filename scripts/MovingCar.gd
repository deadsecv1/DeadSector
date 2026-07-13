extends Node2D

# A purely decorative car that drives back and forth along a straight
# stretch of road, with a small trail of exhaust puffs from the back.
# No collision - same as the parked decorative Car scene and the roads
# themselves, so it can never block the player.

@export var travel_distance: float = 300.0
@export var speed: float = 55.0
@export var body_color: Color = Color(0.25, 0.28, 0.32, 1)

var _t: float = 0.0
var _dir: float = 1.0
var _exhaust_timer: float = 0.0

func _ready() -> void:
	z_index = 3
	_build_body()
	_t = randf() * travel_distance

func _build_body() -> void:
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([-16, -7, 12, -7, 16, -2, 16, 5, -16, 5])
	body.color = body_color
	add_child(body)

	var windshield := Polygon2D.new()
	windshield.polygon = PackedVector2Array([-2, -7, 9, -7, 12, -2, -2, -2])
	windshield.color = Color(0.5, 0.65, 0.75, 0.85)
	add_child(windshield)

	for wx in [-9.0, 9.0]:
		var wheel := Polygon2D.new()
		wheel.polygon = PackedVector2Array([-3, -2, 3, -2, 3, 2, -3, 2])
		wheel.color = Color(0.05, 0.05, 0.05, 1)
		wheel.position = Vector2(wx, 6)
		add_child(wheel)

func _process(delta: float) -> void:
	_t += speed * delta * _dir
	if _t > travel_distance:
		_t = travel_distance
		_dir = -1.0
		rotation = PI
	elif _t < 0.0:
		_t = 0.0
		_dir = 1.0
		rotation = 0.0
	position.x = _t

	_exhaust_timer -= delta
	if _exhaust_timer <= 0.0:
		_exhaust_timer = 0.08
		_spawn_exhaust_puff()

# A very small, quick-fading puff released from the rear bumper, opposite
# whichever way the car is currently driving.
func _spawn_exhaust_puff() -> void:
	var puff := Polygon2D.new()
	var s := randf_range(1.2, 2.2)
	puff.polygon = PackedVector2Array([-s, -s, s, -s, s, s, -s, s])
	puff.color = Color(0.5, 0.5, 0.52, 0.35)
	var rear_x: float = 17.0 if _dir > 0.0 else -17.0
	puff.position = Vector2(rear_x, 1.5)
	add_child(puff)
	var tw := puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "position", puff.position + Vector2(rear_x * 0.3, -4.0), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(puff, "modulate:a", 0.0, 0.6)
	tw.tween_property(puff, "scale", Vector2(2.0, 2.0), 0.6)
	tw.chain().tween_callback(puff.queue_free)
