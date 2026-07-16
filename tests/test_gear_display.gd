extends TestCase

# Covers get_display_color()'s skin-vs-rarity precedence (the rule every
# gear-rendering spot in the game is supposed to follow after the v3.65.1
# skin-consistency fixes) and the Enemy.gd gear-visuals overlay system
# added for "Real Player" enemies (v3.64.0).

const EnemyScene := preload("res://scenes/Enemy.tscn")

func before_each_file() -> void:
	# Isolate from whatever the real save file happens to have equipped -
	# this exact confusion (a real equipped skin bleeding into a supposedly
	# "default" test item) cost real debugging time earlier this session.
	GameManager.equipped_skins.clear()

func test_display_color_falls_back_to_rarity_with_no_skin() -> void:
	var item := {"name": "Plain Rifle", "icon_key": "rifle", "rarity": "epic"}
	assert_eq(GameManager.get_display_color(item), GameManager.get_rarity_color("epic"), "With no skin equipped, display color should equal the rarity color")

func test_equipped_skin_overrides_rarity_color() -> void:
	var skins: Array = GameManager.get_skins_for("rifle")
	if skins.is_empty():
		return # no rifle skins defined - nothing to test against
	var skin: Dictionary = skins[0]
	GameManager.equipped_skins["rifle"] = skin.get("id", "")
	var item := {"name": "Skinned Rifle", "icon_key": "rifle", "rarity": "common"}
	assert_eq(GameManager.get_display_color(item), skin.get("color", Color.WHITE), "An equipped skin should override the rarity color entirely")
	GameManager.equipped_skins.erase("rifle")

func test_lootbag_uses_lootbag_color_not_rarity_color() -> void:
	var item := {"name": "A Loot Bag", "icon_key": "lootbag", "slot": "lootbag", "rarity": "rare"}
	assert_eq(GameManager.get_display_color(item), GameManager.get_lootbag_color("rare"), "Loot bags should use get_lootbag_color(), not the generic rarity color")

func test_enemy_gear_visuals_show_and_hide_per_slot() -> void:
	var enemy = EnemyScene.instantiate()
	enemy.is_real_player = true
	enemy.gear = {
		"head": {"name": "Test Helm", "icon_key": "helmet", "rarity": "rare"},
		"weapon": {"name": "Test Rifle", "icon_key": "rifle", "rarity": "common"},
		# body/boots/backpack/accessory deliberately left unset
	}
	add_child(enemy)
	# Enemy.gd's _ready() schedules call_deferred("_find_player") - give it
	# a frame to fire while the enemy is still validly in the tree, rather
	# than free()ing immediately and having it run against a null tree.
	await get_tree().process_frame

	assert_true(enemy.helmet_icon.visible, "Helmet icon should show when gear.head is set")
	assert_eq(enemy.helmet_icon.icon_key, "helmet")
	assert_false(enemy.backpack_icon.visible, "Backpack icon should stay hidden when gear.backpack is unset")
	assert_false(enemy.accessory_icon.visible, "Accessory icon should stay hidden when gear.accessory is unset")
	assert_false(enemy.boots_icon.visible, "Boots icon should stay hidden when gear.boots is unset")

	remove_child(enemy)
	enemy.queue_free()

func test_enemy_auto_generates_gear_when_unset() -> void:
	var enemy = EnemyScene.instantiate()
	enemy.is_real_player = true
	# gear left at its default {} - Enemy.gd's _ready() should auto-roll
	# one via GameManager.generate_random_enemy_gear() rather than leaving
	# every slot empty (the pre-v3.64.0 behavior).
	add_child(enemy)
	await get_tree().process_frame
	assert_false(enemy.gear.is_empty(), "A Real Player enemy with no explicitly-assigned gear should auto-roll a loadout, not stay empty")
	remove_child(enemy)
	enemy.queue_free()
