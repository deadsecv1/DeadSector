extends "res://scripts/Enemy.gd"

# A small glowing wisp - the enemy that spawns in Commune's wave
# survival. Weaker than regular raiders but drops Souls on death.

signal wisp_died

func _ready() -> void:
	super._ready()
	add_to_group("wisp")
	torso.color = Color(0.4, 0.9, 0.75, 0.85)
	chest_strap.color = Color(0.3, 0.7, 0.9, 0.7)
	mask.visible = false
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.55, 0.95, 0.85, 0.9)
	if has_node("Visuals/LeftLeg"):
		$Visuals/LeftLeg.visible = false
	if has_node("Visuals/RightLeg"):
		$Visuals/RightLeg.visible = false
	modulate.a = 0.9

func die() -> void:
	# Same is_dead guard base Enemy.gd's die() has - lost by overriding
	# die() entirely. Without it, a shotgun/burst weapon's several bullets
	# landing in the same frame (queue_free() doesn't remove the node until
	# end-of-frame) could each independently re-emit wisp_died, and
	# SoulRealm.gd's wave-clear counter only expects exactly one emit per
	# real death - a double-emit from one overkilled Wisp could end a
	# Commune wave (or trigger the Wave 20 finale) while real Wisps are
	# still alive.
	if is_dead:
		return
	is_dead = true
	wisp_died.emit()
	var souls_amount: int = randi_range(3, 8)
	GameManager.add_currency("souls", souls_amount)
	died.emit()
	var death_pos := global_position
	call_deferred("_spawn_kill_burst", death_pos)
	queue_free()
