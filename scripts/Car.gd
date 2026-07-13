extends Node2D

# Drives in from off-screen for the paid extraction point, idles while the
# timer runs, then drives off when depart() is called. Can also be placed
# as a permanently-parked decoration (static_decor = true) scattered
# around the map - it just sits still and never calls start_approach().

signal arrived

@export var static_decor: bool = false

const APPROACH_SPEED := 340.0
const LEAVE_SPEED := 420.0

const WRECK_VARIANTS := ["scrap", "flipped", "overgrown", "rust"]

var target_pos: Vector2 = Vector2.ZERO
var state: String = "idle"

@onready var body: Polygon2D = $Body
@onready var wheel_l: Polygon2D = $WheelL
@onready var wheel_r: Polygon2D = $WheelR
@onready var car_sprite: Sprite2D = $CarSprite

func _ready() -> void:
	_try_load_external_sprite()

# --- Optional external art: parked/wrecked decoration cars each pick a
# random weathered variant (res://assets/vehicles/car_<variant>.png) for
# visual variety across the many static_decor placements scattered around
# the maps, while the functional extraction pickup car always uses the
# plain res://assets/vehicles/car.png and gets rotated to face its travel
# direction (it only ever drives in +X). Falls back to the vector body
# if no external art is present. ---
func _try_load_external_sprite() -> void:
	var path := "res://assets/vehicles/car.png"
	if static_decor:
		path = "res://assets/vehicles/car_%s.png" % WRECK_VARIANTS[randi() % WRECK_VARIANTS.size()]
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	car_sprite.texture = tex
	car_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	car_sprite.visible = true
	body.visible = false
	wheel_l.visible = false
	wheel_r.visible = false
	var windshield := get_node_or_null("Windshield")
	if windshield:
		windshield.visible = false
	if static_decor:
		car_sprite.rotation_degrees = [0, 90, 180, 270][randi() % 4]
	else:
		car_sprite.rotation_degrees = 90

func start_approach(landing_pos: Vector2) -> void:
	target_pos = landing_pos
	global_position = target_pos + Vector2(-900, 0)
	state = "approaching"
	z_index = 4

func _process(delta: float) -> void:
	if static_decor:
		return
	if state == "approaching":
		global_position = global_position.move_toward(target_pos, APPROACH_SPEED * delta)
		if global_position.distance_to(target_pos) < 4.0:
			state = "idle"
			arrived.emit()
	elif state == "leaving":
		global_position += Vector2(1, 0) * LEAVE_SPEED * delta
		if global_position.x - target_pos.x > 1100.0:
			queue_free()

func depart() -> void:
	state = "leaving"
