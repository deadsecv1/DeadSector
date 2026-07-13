extends "res://scripts/Enemy.gd"

# A skeletal raider - bone-white and rattling, Boneclock's signature
# enemy. Same AI as a regular raider, just a very different look.

func _ready() -> void:
	super._ready()
	add_to_group("skeleton")
	torso.color = Color(0.88, 0.86, 0.78, 1)
	chest_strap.color = Color(0.55, 0.52, 0.44, 1)
	mask.visible = false
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.92, 0.9, 0.82, 1)
	if has_node("Visuals/LeftLeg"):
		$Visuals/LeftLeg.color = Color(0.85, 0.83, 0.75, 1)
	if has_node("Visuals/RightLeg"):
		$Visuals/RightLeg.color = Color(0.85, 0.83, 0.75, 1)
