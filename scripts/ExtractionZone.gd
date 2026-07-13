extends Area2D

# Stand in the zone to start the extraction countdown - unchanged core
# rule - but now a helicopter (or car, for the paid zone) flies/drives in
# and stays for the whole countdown, for a much better payoff than just
# standing still. If `is_paid` is set, the zone starts LOCKED (yellow) and
# the player must pay `unlock_cost` Rubles (press F) before it can be used
# at all - it turns green once unlocked.

@export var extraction_time: float = 5.0
@export var is_paid: bool = false
@export var unlock_cost: int = 500
@export var pickup_type: String = "helicopter"  # "helicopter" or "car"
@export var custom_color: Color = Color(0, 0, 0, 0)  # if alpha > 0, overrides the default zone color

const HELICOPTER_SCENE := preload("res://scenes/Helicopter.tscn")
const CAR_SCENE := preload("res://scenes/Car.tscn")

var time_left: float
var player_inside: bool = false
var extracting: bool = false
var unlocked: bool = false
var pickup_vehicle: Node2D = null
var pickup_summoned: bool = false
var f_was_down: bool = false

@onready var label: Label = $Label
@onready var zone_poly: Polygon2D = $Polygon2D

func _ready() -> void:
	time_left = _effective_extraction_time()
	unlocked = not is_paid
	zone_poly.color = _zone_color()
	_update_label()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _effective_extraction_time() -> float:
	return max(1.0, extraction_time - GameManager.get_upgrade_bonus("extraction_speed"))

func _zone_color() -> Color:
	if custom_color.a > 0.0:
		return custom_color
	if is_paid and not unlocked:
		return Color(0.85, 0.75, 0.1, 0.3)
	return Color(0.15, 0.8, 0.3, 0.28)

func _update_label() -> void:
	if is_paid and not unlocked:
		label.text = "LOCKED\nPress F: Pay %d Rubles" % unlock_cost
	else:
		label.text = "EXTRACTION ZONE"

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		time_left = _effective_extraction_time()
		pickup_summoned = false
		if pickup_vehicle != null and is_instance_valid(pickup_vehicle):
			pickup_vehicle.depart()
			pickup_vehicle = null
		if not extracting:
			_update_label()

func _process(delta: float) -> void:
	if extracting:
		return

	if is_paid and not unlocked:
		var f_down := player_inside and Input.is_key_pressed(GameManager.get_keybind("interact"))
		if f_down and not f_was_down:
			_try_unlock()
		f_was_down = f_down
		return

	if player_inside:
		if not pickup_summoned:
			_summon_pickup()
		time_left -= delta
		label.text = "Extracting... %.1f" % time_left
		if time_left <= 0:
			extracting = true
			label.text = "EXTRACTED!"
			if pickup_vehicle != null and is_instance_valid(pickup_vehicle):
				pickup_vehicle.depart()
			if is_paid:
				GameManager.notify_event("pay_car_extract")
			GameManager.end_run(true)
	else:
		time_left = _effective_extraction_time()

func _try_unlock() -> void:
	if GameManager.spend_currency("rubles", unlock_cost):
		unlocked = true
		zone_poly.color = _zone_color()
		_update_label()
		GameManager.toast_requested.emit("Extraction point unlocked!")
	else:
		GameManager.toast_requested.emit("Not enough Rubles to unlock this extraction")

func _summon_pickup() -> void:
	pickup_summoned = true
	var scene: PackedScene = HELICOPTER_SCENE if pickup_type == "helicopter" else CAR_SCENE
	pickup_vehicle = scene.instantiate()
	get_tree().current_scene.add_child(pickup_vehicle)
	pickup_vehicle.start_approach(global_position)
