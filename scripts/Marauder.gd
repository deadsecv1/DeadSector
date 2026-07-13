extends "res://scripts/Enemy.gd"

# A fast, aggressive raider that closes distance quickly and fights at
# close range instead of hanging back - reads as more dangerous up
# close, easier to outrange if you keep your distance.

func _ready() -> void:
	super._ready()
	add_to_group("marauder")
	# A Real Player Marauder should actually look like the tactical
	# Real Player operator (set by super._ready() above) - skip the
	# usual red Marauder recolor so it doesn't get immediately
	# overwritten back to red right after.
	if is_real_player:
		return
	torso.color = Color(0.5, 0.08, 0.06, 1)
	chest_strap.color = Color(0.15, 0.03, 0.02, 1)
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.55, 0.4, 0.32, 1)
	if has_node("Visuals/Mask"):
		$Visuals/Mask.color = Color(0.08, 0.02, 0.02, 1)
