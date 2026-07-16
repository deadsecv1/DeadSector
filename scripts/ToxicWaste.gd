extends "res://scripts/Enemy.gd"

# A sickly, irradiated raider that spawns near the Radiation Zone - looks
# distinct (toxic green) and always has a good chance of dropping a Gas
# Mask when killed.

func _ready() -> void:
	super._ready()
	add_to_group("toxic_waste")
	torso.color = Color(0.28, 0.42, 0.08, 1)
	chest_strap.color = Color(0.15, 0.24, 0.04, 1)
	mask.color = Color(0.35, 0.5, 0.15, 1)

func die() -> void:
	# Overriding die() entirely (for the custom gas-mask-chance loot) means
	# this class never inherited base Enemy.gd's is_dead guard - a shotgun's
	# 5 pellets (or a top-tier weapon's 3-5 shot burst) landing in the same
	# physics frame, before queue_free() actually removes this node, could
	# each independently trigger a full die() call, re-rolling loot/currency
	# every extra time. Setting is_dead here restores the same guard
	# take_damage() already checks.
	if is_dead:
		return
	is_dead = true
	died.emit()
	GameManager.notify_event("kill_enemy")
	GameManager.record_kill()
	GameManager.mark_enemy_discovered("toxic_waste")
	if player != null and is_instance_valid(player) and player.in_bush:
		GameManager.notify_event("sneak_kill")
	var death_pos := global_position
	var effective_loot_chance: float = clamp(loot_drop_chance + GameManager.get_equipped_bonus("loot_sense") + GameManager.get_upgrade_bonus("loot_sense"), 0.0, 1.0)
	var loot_data: Dictionary = GameManager.roll_corpse_loot(false, drop_key_id, drop_key_label, effective_loot_chance)
	var items: Array = loot_data.get("items", [])
	if randf() < 0.6:
		items.append(GameManager.roll_gas_mask())
	call_deferred("_spawn_corpse_toxic", death_pos, items, loot_data.get("currency", {}))
	call_deferred("_spawn_kill_burst", death_pos)
	queue_free()

func _spawn_corpse_toxic(pos: Vector2, items: Array, currency: Dictionary) -> void:
	var corpse = CORPSE_SCENE.instantiate()
	corpse.loot_items = items
	corpse.currency_drops = currency
	corpse.is_real_player = false
	get_tree().current_scene.add_child(corpse)
	corpse.global_position = pos
