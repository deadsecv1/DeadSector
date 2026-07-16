extends TestCase

# Regression coverage for the Monochrome rarity added for Alpha/Tech-Test
# exclusive items. Before this, those items kept an ordinary color-
# associated rarity (legendary/exotic/multiversal) despite always
# rendering with a black-and-white chrome look - correct in the Stash
# grid (which special-cases alpha_only/beta_only directly) but wrong the
# instant you dragged one, since InventoryTile.gd's drag preview used
# get_rarity_color(item.rarity) instead of get_display_color(item).

func test_monochrome_is_a_real_rarity_tier() -> void:
	assert_eq(GameManager.get_rarity_color("monochrome"), Color(1.0, 1.0, 1.0, 1), "Monochrome's flat color should be white")
	assert_eq(GameManager.get_rarity_label("monochrome"), "Monochrome")
	assert_true(GameManager.RARITY_TIERS.has("monochrome"))

func test_monochrome_sits_above_godforged() -> void:
	assert_gt(GameManager.RARITY_TIERS["monochrome"]["multiplier"], GameManager.RARITY_TIERS["godforged"]["multiplier"], "Monochrome should be the single highest tier")

func test_rarity_rank_and_sort_order_include_every_tier() -> void:
	# RARITY_RANK and RARITY_SORT_ORDER are separately-maintained lists
	# that had already drifted out of sync with RARITY_TIERS before this
	# fix (missing divine/godforged entirely) - catches that regressing.
	for rarity in GameManager.RARITY_TIERS.keys():
		assert_true(GameManager.RARITY_RANK.has(rarity), "RARITY_RANK is missing '%s'" % rarity)
		assert_true(GameManager.RARITY_SORT_ORDER.has(rarity), "RARITY_SORT_ORDER is missing '%s'" % rarity)

func test_display_color_is_monochrome_for_alpha_beta_items_regardless_of_stored_rarity() -> void:
	# The actual bug report: dragging an Alpha/Tech-Test item showed its
	# OLD stored rarity's color (e.g. Legendary's orange) instead of
	# white. Checked against every rarity string these items might still
	# carry on an old save, not just "monochrome" - get_display_color must
	# never trust the stored rarity for one of these, the flag always wins.
	var white := Color(1.0, 1.0, 1.0, 1)
	for old_rarity in ["legendary", "exotic", "multiversal", "monochrome", "common"]:
		var alpha_item := {"name": "Test Alpha Item", "rarity": old_rarity, "alpha_only": true, "icon_key": "generic"}
		assert_eq(GameManager.get_display_color(alpha_item), white, "An alpha_only item stored with rarity '%s' should still display Monochrome white" % old_rarity)
		var beta_item := {"name": "Test Beta Item", "rarity": old_rarity, "beta_only": true, "icon_key": "generic"}
		assert_eq(GameManager.get_display_color(beta_item), white, "A beta_only item stored with rarity '%s' should still display Monochrome white" % old_rarity)

func test_display_color_ignores_an_equipped_skin_for_alpha_beta_items() -> void:
	# Monochrome status is meant to always win over a generic icon_key-
	# matched skin - otherwise an equipped "pistol" skin would silently
	# recolor Tech Tester's Sidearm away from its exclusive look.
	var had_skin: Variant = GameManager.equipped_skins.get("pistol")
	GameManager.equipped_skins["pistol"] = "pistol_gold"
	var item := {"name": "Tech Tester's Sidearm", "rarity": "monochrome", "beta_only": true, "icon_key": "pistol"}
	assert_eq(GameManager.get_display_color(item), Color(1.0, 1.0, 1.0, 1), "A Monochrome item should ignore an equipped skin on the same icon_key")
	if had_skin == null:
		GameManager.equipped_skins.erase("pistol")
	else:
		GameManager.equipped_skins["pistol"] = had_skin

func test_compendium_alpha_beta_items_are_tagged_monochrome() -> void:
	var weapon_ids := ["the_prototype", "tech_testers_sidearm"]
	for wid in weapon_ids:
		assert_eq(GameManager.WEAPON_CATALOG[wid].get("rarity", ""), "monochrome", "%s should be tagged Monochrome in WEAPON_CATALOG" % wid)
	var armor_ids := ["alpha_pioneers_rig", "veterans_plate", "early_access_visor", "founders_boots"]
	for aid in armor_ids:
		assert_eq(GameManager.ARMOR_CATALOG[aid].get("rarity", ""), "monochrome", "%s should be tagged Monochrome in ARMOR_CATALOG" % aid)

func test_inventory_tile_drag_preview_uses_display_color_not_flat_rarity_color() -> void:
	# The exact reported symptom: drag a Monochrome item and the preview
	# used to show its old rarity's flat color instead of white.
	var tile_scene := preload("res://scenes/InventoryTile.tscn")
	var tile = tile_scene.instantiate()
	add_child(tile)
	var item := {"name": "The Prototype", "rarity": "monochrome", "alpha_only": true, "icon_key": "alpha_cannon", "slot": "weapon"}
	tile.setup(0, item, "stash")
	await get_tree().process_frame

	var data = tile._get_drag_data(Vector2.ZERO)
	assert_not_null(data, "Dragging a real item should produce drag data")

	remove_child(tile)
	tile.queue_free()
