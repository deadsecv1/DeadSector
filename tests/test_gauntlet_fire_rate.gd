extends TestCase

# Regression coverage (2026-07-17 audit) - _recompute_gauntlet_stats() only
# ever read max_health/speed/damage equipment bonuses, never fire_rate,
# even though Gauntlet loot generation (ENEMY_LOOT_POOL) can and does roll
# fire_rate-stat gear that lands on the Bloodline doll, and
# GauntletInventoryPanel.gd even displays a real "+X% Fire Rate" tooltip
# line for it. shoot_cooldown was a fixed SHOOT_COOLDOWN constant never
# adjusted by any equipped bonus - unlike Player.gd's non-Gauntlet
# equivalent, which genuinely reduces its own shoot_cooldown via
# get_equipped_bonus("fire_rate").

const GauntletPlayerScene := preload("res://scenes/GauntletPlayer.tscn")

func test_fire_rate_gear_actually_reduces_shoot_cooldown() -> void:
	var equipped_before: Dictionary = GameManager.gauntlet_equipped_items.duplicate(true)
	GameManager.gauntlet_equipped_items = {}

	var player = GauntletPlayerScene.instantiate()
	add_child(player)
	var base_cooldown: float = player.shoot_cooldown
	assert_eq(base_cooldown, player.SHOOT_COOLDOWN, "with no gear equipped, shoot_cooldown should just be the base constant")

	GameManager.gauntlet_equipped_items["helmet_attachment"] = {"name": "Test Comms Headset", "slot": "helmet_attachment", "stat_type": "fire_rate", "stat_value": 0.15, "rarity": "rare"}
	player._recompute_gauntlet_stats()

	assert_true(player.shoot_cooldown < base_cooldown, "equipping real fire_rate gear should actually reduce shoot_cooldown")
	assert_eq(player.shoot_cooldown, max(0.08, base_cooldown - 0.15))

	GameManager.gauntlet_equipped_items = equipped_before
	remove_child(player)
	player.queue_free()

func test_shoot_cooldown_never_drops_below_the_floor() -> void:
	var equipped_before: Dictionary = GameManager.gauntlet_equipped_items.duplicate(true)
	GameManager.gauntlet_equipped_items = {
		"helmet_attachment": {"name": "Absurd Comms Array", "slot": "helmet_attachment", "stat_type": "fire_rate", "stat_value": 99.0, "rarity": "mythic"},
	}

	var player = GauntletPlayerScene.instantiate()
	add_child(player)

	assert_eq(player.shoot_cooldown, 0.08, "an absurdly large fire_rate bonus should still be floored at 0.08s")

	GameManager.gauntlet_equipped_items = equipped_before
	remove_child(player)
	player.queue_free()
