extends "res://scripts/Enemy.gd"

# A pale, semi-transparent ghost - Boneclock's other signature enemy.
# Same core AI, just visually unsettling and a little faster since it
# doesn't have to worry about tripping over its own feet.

func _ready() -> void:
	super._ready()
	add_to_group("ghost")
	torso.color = Color(0.75, 0.85, 0.9, 0.55)
	chest_strap.color = Color(0.6, 0.72, 0.8, 0.5)
	mask.visible = false
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.85, 0.92, 0.95, 0.6)
	if has_node("Visuals/LeftLeg"):
		$Visuals/LeftLeg.visible = false
	if has_node("Visuals/RightLeg"):
		$Visuals/RightLeg.visible = false
	if has_node("Visuals/TorsoOutline"):
		$Visuals/TorsoOutline.default_color = Color(0.85, 0.92, 0.95, 0.4)
	modulate.a = 0.85
