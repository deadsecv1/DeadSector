extends StaticBody2D

# A clump of alien flora that sits harmlessly until shot - then it
# bursts, releasing a blinding spore cloud that lingers and scrambles
# anyone's flashlight who wanders through it.

const SPORE_CLOUD_SCENE := preload("res://scenes/SporeBlindCloud.tscn")

var health: int = 15
var burst: bool = false

@onready var plant_body: Polygon2D = $PlantBody

func _ready() -> void:
	add_to_group("shootable_hazard")

func take_damage(amount: int) -> void:
	if burst:
		return
	health -= amount
	plant_body.modulate = Color(1, 1, 1, 1).lerp(Color(2, 2, 2, 1), 0.3)
	if health <= 0:
		_burst()

func _burst() -> void:
	burst = true
	var cloud = SPORE_CLOUD_SCENE.instantiate()
	get_parent().call_deferred("add_child", cloud)
	cloud.set_deferred("global_position", global_position)
	queue_free()
