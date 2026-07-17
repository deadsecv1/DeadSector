extends TestCase

# Regression coverage (2026-07-17, controller audit) - 4 full-screen Control
# menus never called GameManager.focus_first_control(), unlike every
# sibling full-screen menu (Stash.gd, Traders.gd, SkillTree.gd, etc.) - a
# gamepad player landing on any of them had nothing focused to navigate
# stick/d-pad from. RaidRewards.gd is the highest-traffic one by far,
# shown after every single successful extraction.

const RaidRewardsScene := preload("res://scenes/RaidRewards.tscn")
const TraderShopScene := preload("res://scenes/TraderShop.tscn")
const BarterPanelScene := preload("res://scenes/BarterPanel.tscn")
const LoreIntroScene := preload("res://scenes/LoreIntro.tscn")

func test_raid_rewards_focuses_itself() -> void:
	var rewards_before: Dictionary = GameManager.last_raid_rewards.duplicate(true)
	GameManager.last_raid_rewards = {
		"loot_value": 100, "loot_items": [], "quests": [], "was_scav": false,
		"is_ranked": false, "xp_gained": 50, "rank_points_gained": 0,
		"rank_index_before": 0, "rank_index_after": 0,
		"level_before": 1, "xp_before": 0, "level_after": 1, "xp_after": 50,
	}
	var screen = RaidRewardsScene.instantiate()
	add_child(screen)
	assert_true(screen.get_viewport().gui_get_focus_owner() != null, "RaidRewards should focus something on _ready() - it's shown after every successful extraction")
	remove_child(screen)
	screen.queue_free()
	GameManager.last_raid_rewards = rewards_before

func test_trader_shop_focuses_itself() -> void:
	var screen = TraderShopScene.instantiate()
	add_child(screen)
	assert_true(screen.get_viewport().gui_get_focus_owner() != null, "TraderShop should focus something on _ready()")
	remove_child(screen)
	screen.queue_free()

func test_barter_panel_focuses_itself() -> void:
	var screen = BarterPanelScene.instantiate()
	add_child(screen)
	assert_true(screen.get_viewport().gui_get_focus_owner() != null, "BarterPanel should focus something on _ready()")
	remove_child(screen)
	screen.queue_free()

func test_lore_intro_focuses_itself() -> void:
	var screen = LoreIntroScene.instantiate()
	add_child(screen)
	assert_true(screen.get_viewport().gui_get_focus_owner() != null, "LoreIntro should focus something on _ready()")
	remove_child(screen)
	screen.queue_free()
