extends TestCase

# Regression coverage for the Weapon Manufacturer / Origin Perks system
# (2026-07-16) - every named weapon deterministically belongs to one of 5
# manufacturer brands (hashed from its name, not stored on the item), each
# with a real mechanical tradeoff applied in Player.gd. See GameManager.gd's
# "Weapon Manufacturers" section.

func test_non_weapon_items_have_no_manufacturer() -> void:
	var armor := {"slot": "body", "name": "Field Vest"}
	assert_eq(GameManager.get_weapon_manufacturer_id(armor), "")
	assert_true(GameManager.get_weapon_manufacturer(armor).is_empty())

func test_nameless_weapon_has_no_manufacturer() -> void:
	var item := {"slot": "weapon", "name": ""}
	assert_eq(GameManager.get_weapon_manufacturer_id(item), "")

func test_manufacturer_id_is_deterministic_per_name() -> void:
	var item := {"slot": "weapon", "name": "Assault Rifle"}
	var first := GameManager.get_weapon_manufacturer_id(item)
	for i in range(10):
		assert_eq(GameManager.get_weapon_manufacturer_id(item), first, "the same weapon name must always resolve to the same manufacturer")

func test_manufacturer_id_is_always_a_known_brand() -> void:
	for weapon_name in GameManager.WEAPON_CATALOG.keys():
		var entry: Dictionary = GameManager.WEAPON_CATALOG[weapon_name]
		var item := {"slot": "weapon", "name": entry.get("name", weapon_name)}
		var id: String = GameManager.get_weapon_manufacturer_id(item)
		assert_true(id in GameManager.WEAPON_MANUFACTURER_IDS, "unexpected manufacturer id: %s" % id)

func test_real_weapon_catalog_produces_real_variety() -> void:
	# Not every bucket needs to be hit, but with 40+ distinct named weapons
	# hashing into 5 buckets, getting only 1 distinct manufacturer back
	# would mean the hash distribution (or the lookup itself) is broken.
	var seen := {}
	for weapon_name in GameManager.WEAPON_CATALOG.keys():
		var entry: Dictionary = GameManager.WEAPON_CATALOG[weapon_name]
		var item := {"slot": "weapon", "name": entry.get("name", weapon_name)}
		seen[GameManager.get_weapon_manufacturer_id(item)] = true
	assert_gt(seen.size(), 1, "expected real variety across the weapon compendium, got only: %s" % str(seen.keys()))

func test_manufacturer_dict_has_name_and_perk() -> void:
	var item := {"slot": "weapon", "name": "Scrap Pistol"}
	var mfr := GameManager.get_weapon_manufacturer(item)
	assert_true(mfr.has("name"))
	assert_true(mfr.has("perk"))
	assert_ne(str(mfr["name"]), "")
	assert_ne(str(mfr["perk"]), "")

func test_manufacturer_mult_defaults_to_one_for_unknown_key_or_null_item() -> void:
	var item := {"slot": "weapon", "name": "Scrap Pistol"}
	assert_eq(GameManager.get_weapon_manufacturer_mult(item, "not_a_real_key"), 1.0)
	assert_eq(GameManager.get_weapon_manufacturer_mult(null, "damage_mult"), 1.0)

func test_every_manufacturer_has_a_real_tradeoff() -> void:
	# Every brand must differ from the neutral 1.0 baseline on at least one
	# axis (it's a "brand"), and none should be a strict, no-cost upgrade
	# (every buffed axis must be offset by a nerfed one) - keeps this from
	# silently becoming a pay-to-win stat stick during future balance edits.
	for id in GameManager.WEAPON_MANUFACTURER_IDS:
		var mfr: Dictionary = GameManager.WEAPON_MANUFACTURERS[id]
		var mult_keys := ["reload_mult", "durability_mult", "damage_mult", "cooldown_mult", "mag_mult", "recoil_mult"]
		var has_buff := false
		var has_nerf := false
		for key in mult_keys:
			var v: float = float(mfr.get(key, 1.0))
			if v == 1.0:
				continue
			# For most of these axes, LOWER is the player-favorable direction
			# (less reload time, less wear, less recoil, faster cooldown)
			# except damage_mult and mag_mult, where HIGHER (more damage,
			# a bigger magazine) is player-favorable.
			var favorable: bool = v < 1.0
			if key == "damage_mult" or key == "mag_mult":
				favorable = v > 1.0
			if favorable:
				has_buff = true
			else:
				has_nerf = true
		assert_true(has_buff, "%s should have at least one favorable axis" % id)
		assert_true(has_nerf, "%s should have at least one unfavorable axis - no free lunch brands" % id)
