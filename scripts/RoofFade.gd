extends Area2D

# Attached to an "InteriorZone" Area2D that's a sibling of a "Roof" CanvasItem
# (both children of a shared House wrapper node). While the player is inside
# this zone, the roof smoothly fades down so you can see the character and
# the room, instead of snapping instantly.

var target_alpha := 1.0
var roof: CanvasItem = null

func _ready() -> void:
	roof = get_parent().get_node_or_null("Roof")
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		target_alpha = 0.0

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		target_alpha = 1.0

func _process(delta: float) -> void:
	if roof == null:
		return
	var a: float = lerp(roof.modulate.a, target_alpha, delta * 6.0)
	roof.modulate.a = a
