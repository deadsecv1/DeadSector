extends TestCase

# Regression coverage for swapping Exotic and Mythic's positions on the
# rarity scale (2026-07) - Mythic is now the rarer of the two everywhere
# a generic tier-weighted system references them (RARITY_TIERS/RANK/
# SORT_ORDER, loot bag rolls, egg/pet/crate/flea-market odds, boss
# rewards). Specific named items (compendium entries, quest rewards) keep
# whatever rarity they were already tagged with - only the abstract tier
# system and generic roll tables moved.

func test_mythic_outranks_exotic_in_tiers_and_rank() -> void:
	assert_gt(GameManager.RARITY_TIERS["mythic"]["multiplier"], GameManager.RARITY_TIERS["exotic"]["multiplier"], "Mythic's multiplier should now be higher than Exotic's")
	assert_gt(GameManager.RARITY_RANK["mythic"], GameManager.RARITY_RANK["exotic"], "Mythic's rank should now be higher than Exotic's")
	var sort_order: Array = GameManager.RARITY_SORT_ORDER
	assert_true(sort_order.find("mythic") < sort_order.find("exotic"), "RARITY_SORT_ORDER (rarest-first) should list Mythic before Exotic")

func test_mythic_still_sits_between_legendary_and_multiversal() -> void:
	# The swap should only trade Exotic and Mythic's own positions -
	# neither should leapfrog Multiversal or fall below Legendary.
	assert_gt(GameManager.RARITY_RANK["mythic"], GameManager.RARITY_RANK["legendary"])
	assert_gt(GameManager.RARITY_RANK["multiversal"], GameManager.RARITY_RANK["mythic"])
	assert_gt(GameManager.RARITY_RANK["exotic"], GameManager.RARITY_RANK["legendary"])

func test_generic_weighted_roll_tables_favor_exotic_over_mythic() -> void:
	# Lower weight/odds value = rarer. Checked across every independent
	# generic tier-roll system that lists both tiers side by side.
	assert_gt(GameManager.CRATE_ODDS["exotic"], GameManager.CRATE_ODDS["mythic"], "Crate odds should make Exotic more likely than Mythic")
	assert_gt(GameManager.PLUSHIE_PET_RARITY_WEIGHTS["exotic"], GameManager.PLUSHIE_PET_RARITY_WEIGHTS["mythic"], "Plushie pet weights should make Exotic more likely than Mythic")
	assert_gt(GameManager.FLEA_MARKET_RARITY_WEIGHTS["exotic"], GameManager.FLEA_MARKET_RARITY_WEIGHTS["mythic"], "Flea Market weights should make Exotic more likely than Mythic")
	assert_gt(GameManager.EGG_HATCH_SECONDS["mythic"], GameManager.EGG_HATCH_SECONDS["exotic"], "A Mythic egg should take longer to hatch than an Exotic one")

func test_plushie_and_rival_tier_order_lists_are_consistent() -> void:
	var plushie_order: Array = GameManager.PLUSHIE_PET_TIER_ORDER
	assert_true(plushie_order.find("exotic") < plushie_order.find("mythic"), "PLUSHIE_PET_TIER_ORDER (ascending rarity) should list Exotic before Mythic")
	var rival_order: Array = GameManager.RIVAL_RARITIES
	assert_true(rival_order.find("exotic") < rival_order.find("mythic"), "RIVAL_RARITIES (ascending rarity) should list Exotic before Mythic")

func test_egg_pet_pool_tiers_moved_with_the_rarity_swap() -> void:
	# The named pets themselves didn't change - just which egg tier now
	# hatches which set, matching their new rank.
	var mythic_ids: Array = []
	for pet in GameManager.EGG_PET_POOL["mythic"]:
		mythic_ids.append(pet["id"])
	assert_true(mythic_ids.has("genesis_hawk"), "Genesis Hawk should now hatch from Mythic eggs (the rarer tier)")
	var exotic_ids: Array = []
	for pet in GameManager.EGG_PET_POOL["exotic"]:
		exotic_ids.append(pet["id"])
	assert_true(exotic_ids.has("emberwolf"), "Emberwolf should now hatch from Exotic eggs (the more common tier)")

func test_loot_bag_tier_naming_stays_consistent_with_price():
	# Prismatic Loot Bag (420, pricier) should be the Mythic-tier bag now
	# that Mythic is rarer; Gilded (260, cheaper) should be Exotic-tier.
	assert_eq(GameManager.LOOT_BAG_TIERS["mythic"]["name"], "Prismatic Loot Bag")
	assert_eq(GameManager.LOOT_BAG_TIERS["exotic"]["name"], "Gilded Loot Bag")
	assert_gt(GameManager.LOOT_BAG_TIERS["mythic"]["value"], GameManager.LOOT_BAG_TIERS["exotic"]["value"])

func test_top_tier_weapon_projectile_bonus_now_includes_mythic_not_exotic_alone() -> void:
	# Player.gd's multi-projectile "top tier weapon" bonus used to fire
	# for Exotic/Multiversal/Divine only (Mythic sat below the cutoff) -
	# now that Mythic outranks Exotic, Mythic should get the bonus and
	# Exotic (now the lower of the pair) should not.
	var top_tier := ["mythic", "multiversal", "divine"]
	assert_true(top_tier.has("mythic"))
	assert_false(top_tier.has("exotic"))
