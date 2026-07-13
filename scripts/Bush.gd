extends Area2D

# Walkable cover. While the player is inside, enemies detect them from much
# closer range (see Enemy.gd's effective_range calculation). Also sways
# gently and independently so the map doesn't feel static.

var sway_phase: float = 0.0
var sway_speed: float = 0.0

func _ready() -> void:
	add_to_group("bushes")
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	sway_phase = randf() * TAU
	sway_speed = randf_range(0.6, 1.1)

func _process(delta: float) -> void:
	sway_phase += delta * sway_speed
	rotation = sin(sway_phase) * 0.05

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("set_in_bush"):
		body.set_in_bush(true)

func _on_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("set_in_bush"):
		body.set_in_bush(false)
