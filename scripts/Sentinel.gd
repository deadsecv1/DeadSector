extends "res://scripts/Enemy.gd"

# A tanky, slow-moving defensive unit - doesn't chase aggressively, but
# hits hard and has real health behind it once it's in range. Reads
# as a "hold this ground" enemy rather than a hunter.

func _ready() -> void:
	super._ready()
	add_to_group("sentinel")
	torso.color = Color(0.25, 0.3, 0.36, 1)
	chest_strap.color = Color(0.12, 0.15, 0.2, 1)
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.5, 0.54, 0.58, 1)
	if has_node("Visuals/Mask"):
		$Visuals/Mask.color = Color(0.15, 0.55, 0.75, 0.85)
