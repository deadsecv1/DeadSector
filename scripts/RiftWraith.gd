extends "res://scripts/Enemy.gd"

# A translucent purple wraith drawn out of a reality rift - Void Trench's
# signature enemy. Same silhouette treatment as Ghost (legless, no
# outline showing through) but purple instead of pale blue, and hits
# harder to match the map's higher-risk theme.

func _ready() -> void:
	super._ready()
	add_to_group("rift_wraith")
	torso.color = Color(0.5, 0.15, 0.75, 0.55)
	chest_strap.color = Color(0.35, 0.08, 0.6, 0.5)
	mask.visible = false
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.65, 0.35, 0.85, 0.6)
	if has_node("Visuals/LeftLeg"):
		$Visuals/LeftLeg.visible = false
	if has_node("Visuals/RightLeg"):
		$Visuals/RightLeg.visible = false
	if has_node("Visuals/TorsoOutline"):
		$Visuals/TorsoOutline.default_color = Color(0.7, 0.4, 0.9, 0.4)
	modulate.a = 0.85
