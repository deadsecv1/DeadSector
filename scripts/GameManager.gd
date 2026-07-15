extends Node

# Global game state. Autoloaded as "GameManager".

signal run_ended(success: bool, loot_value: int)
signal equipped_changed
signal toast_requested(text: String)
signal gauntlet_equipment_changed
signal quest_toast_requested(text: String)
signal quest_state_changed
signal search_started(items: Array, duration: float)
signal search_progress(pct: float)
signal search_finished
signal vicinity_changed
signal pockets_changed

# 2 Safe Pocket slots - anything can go in, and whatever's inside survives
# to the Stash even if the run ends in death.
var safe_pockets: Array = [null, null]

# Set by MapSelect.tscn before loading Main.tscn - Main.gd reads this to
# darken the world for a Night Raid (and it also gates the "Extract from a
# Night Raid" quest).
var is_night_raid: bool = false

# Only one container/corpse can be searched at a time.
var is_searching: bool = false

# Which Hotbar slot is currently selected: 0 = weapon (normal shooting),
# 1-4 = a consumable slot (left-click uses it instead of firing).
var active_hotbar_slot: int = 0

# Which Main Menu quote was shown last time, so it visibly changes each
# time you return to the menu instead of repeating.
var last_quote_index: int = -1

# Rarity tiers: multiply an item's base value/stat_value, and give it a
# color used for borders, names, and tooltips across the UI.
const RARITY_TIERS := {
	"common": {"multiplier": 1.0, "color": Color(0.75, 0.75, 0.75, 1), "label": "Common"},
	"uncommon": {"multiplier": 1.3, "color": Color(0.35, 0.85, 0.35, 1), "label": "Uncommon"},
	"rare": {"multiplier": 1.7, "color": Color(0.3, 0.55, 0.95, 1), "label": "Rare"},
	"epic": {"multiplier": 2.2, "color": Color(0.65, 0.35, 0.95, 1), "label": "Epic"},
	"legendary": {"multiplier": 3.0, "color": Color(1.0, 0.6, 0.1, 1), "label": "Legendary"},
	"mythic": {"multiplier": 4.0, "color": Color(0.95, 0.15, 0.35, 1), "label": "Mythic"},
	"exotic": {"multiplier": 6.0, "color": Color(0.85, 0.4, 0.85, 1), "label": "Exotic"},
	"multiversal": {"multiplier": 10.0, "color": Color(0.95, 0.9, 0.5, 1), "label": "Multiversal"},
	"divine": {"multiplier": 15.0, "color": Color(1.0, 0.98, 0.9, 1), "label": "Divine"},
	"godforged": {"multiplier": 25.0, "color": Color(1.0, 0.8, 0.95, 1), "label": "Godforged"},
}

# The Exotic tier is a blend of several colors rather than one flat
# color - used by anything that can draw a real gradient (see
# InventoryTile.gd). Anything that only supports a single flat color
# falls back to RARITY_TIERS["exotic"]["color"] above.
const EXOTIC_GRADIENT := [
	Color(0.95, 0.25, 0.35, 0.3), Color(0.95, 0.75, 0.15, 0.3), Color(0.3, 0.9, 0.55, 0.3),
	Color(0.25, 0.65, 0.95, 0.3), Color(0.75, 0.35, 0.95, 0.3),
]

# Mythic - a fiery red-orange-gold blend, sitting one tier below Exotic
# on the ladder and now visually distinct with its own gradient instead
# of a single flat color.
const MYTHIC_GRADIENT := [
	Color(0.95, 0.15, 0.35, 0.3), Color(1.0, 0.5, 0.15, 0.3), Color(0.95, 0.75, 0.2, 0.3),
	Color(0.85, 0.1, 0.25, 0.3), Color(1.0, 0.35, 0.1, 0.3),
]

# Multiversal - the rarest tier of all, a shimmering gold-white-prismatic
# blend distinct from the Exotic gradient. Lower alpha than a flat rarity
# color on purpose - this renders as a full background behind item names
# in a few places (Alpha Rewards cards especially), and the original
# fully-opaque version, particularly the near-white point, was washing
# out light-colored text sitting on top of it.
const MULTIVERSAL_GRADIENT := [
	Color(1.0, 0.95, 0.75, 0.3), Color(0.95, 0.8, 0.3, 0.3), Color(1.0, 1.0, 1.0, 0.25),
	Color(0.9, 0.7, 1.0, 0.3), Color(1.0, 0.9, 0.5, 0.3),
]

# Divine - one tier above Multiversal, a radiant white-gold-sky blend
# instead of Multiversal's more saturated gold-purple-white prismatic
# mix, so the two read as clearly distinct at a glance rather than
# just "the same shimmer, slightly different."
const DIVINE_GRADIENT := [
	Color(1.0, 1.0, 1.0, 0.3), Color(1.0, 0.95, 0.7, 0.3), Color(0.85, 0.95, 1.0, 0.3),
	Color(1.0, 1.0, 0.9, 0.3), Color(0.9, 0.98, 1.0, 0.3),
]

# Godforged - one tier above Divine, and the only tier never reachable
# through Loot Bags/Eggs/crates at all (see PLUSHIE_PET_RARITY_WEIGHTS)
# - a pink-to-gold blend, distinct from every gradient above it.
const GODFORGED_GRADIENT := [
	Color(1.0, 0.55, 0.85, 0.3), Color(1.0, 0.8, 0.35, 0.3), Color(1.0, 0.6, 0.9, 0.3),
	Color(1.0, 0.85, 0.55, 0.3), Color(1.0, 0.5, 0.8, 0.3),
]


# --- Skins: purely cosmetic recolors, bought with Rubles, equipped per
# icon_key (so a "pistol" skin applies to whichever pistol you're using).
# No stat effect - just a different tint on the icon and in-hand weapon.
const SKIN_CATALOG := {
	"pistol": [
		{"id": "pistol_gold", "name": "Gilded", "cost": 150, "color": Color(0.85, 0.7, 0.25, 1)},
		{"id": "pistol_blue", "name": "Arctic", "cost": 120, "color": Color(0.4, 0.7, 0.95, 1)},
		{"id": "pistol_red", "name": "Crimson", "cost": 130, "color": Color(0.75, 0.15, 0.15, 1)},
		{"id": "pistol_prismatic", "name": "Prismatic", "cost": 0, "color": Color(0.95, 0.55, 0.9, 1), "premium_price": "$4.99"},
		{"id": "pistol_inferno", "name": "Inferno", "cost": 0, "color": Color(1.0, 0.45, 0.1, 1), "premium_price": "$4.99"},
		{"id": "pistol_abyssal", "name": "Abyssal", "cost": 0, "color": Color(0.15, 0.35, 0.9, 1), "premium_price": "$4.99"},
		{"id": "pistol_venom", "name": "Venom", "cost": 0, "color": Color(0.35, 0.85, 0.2, 1), "premium_price": "$4.99"},
		{"id": "pistol_royal", "name": "Royal Amethyst", "cost": 0, "color": Color(0.55, 0.2, 0.85, 1), "premium_price": "$4.99"},
		{"id": "pistol_bone", "name": "Boneclock", "cost": 0, "color": Color(0.85, 0.82, 0.72, 1), "premium_price": "$4.99"},
		{"id": "pistol_nebula", "name": "Nebula", "cost": 0, "color": Color(0.4, 0.25, 0.75, 1), "premium_price": "$4.99"},
		{"id": "pistol_wildfire", "name": "Wildfire", "cost": 0, "color": Color(0.95, 0.4, 0.05, 1), "premium_price": "$4.99"},
	],
	"rifle": [
		{"id": "rifle_red", "name": "Bloodfire", "cost": 200, "color": Color(0.8, 0.15, 0.1, 1)},
		{"id": "rifle_green", "name": "Toxic", "cost": 180, "color": Color(0.3, 0.85, 0.25, 1)},
		{"id": "rifle_urban", "name": "Urban Grey", "cost": 160, "color": Color(0.55, 0.55, 0.58, 1)},
		{"id": "rifle_prismatic", "name": "Prismatic", "cost": 0, "color": Color(0.95, 0.55, 0.9, 1), "premium_price": "$4.99"},
		{"id": "rifle_inferno", "name": "Inferno", "cost": 0, "color": Color(1.0, 0.45, 0.1, 1), "premium_price": "$4.99"},
		{"id": "rifle_abyssal", "name": "Abyssal", "cost": 0, "color": Color(0.15, 0.35, 0.9, 1), "premium_price": "$4.99"},
		{"id": "rifle_venom", "name": "Venom", "cost": 0, "color": Color(0.35, 0.85, 0.2, 1), "premium_price": "$4.99"},
		{"id": "rifle_royal", "name": "Royal Amethyst", "cost": 0, "color": Color(0.55, 0.2, 0.85, 1), "premium_price": "$4.99"},
		{"id": "rifle_glacier", "name": "Glacier", "cost": 0, "color": Color(0.6, 0.85, 0.95, 1), "premium_price": "$4.99"},
		{"id": "rifle_obsidian", "name": "Obsidian", "cost": 0, "color": Color(0.12, 0.06, 0.1, 1), "premium_price": "$4.99"},
	],
	"sniper": [
		{"id": "sniper_black", "name": "Shadow", "cost": 220, "color": Color(0.08, 0.08, 0.1, 1)},
		{"id": "sniper_purple", "name": "Void", "cost": 240, "color": Color(0.5, 0.2, 0.75, 1)},
		{"id": "sniper_white", "name": "Frostbite", "cost": 230, "color": Color(0.85, 0.9, 0.95, 1)},
		{"id": "sniper_abyssal", "name": "Abyssal", "cost": 0, "color": Color(0.15, 0.35, 0.9, 1), "premium_price": "$4.99"},
		{"id": "sniper_prismatic", "name": "Prismatic", "cost": 0, "color": Color(0.95, 0.55, 0.9, 1), "premium_price": "$4.99"},
		{"id": "sniper_inferno", "name": "Inferno", "cost": 0, "color": Color(1.0, 0.45, 0.1, 1), "premium_price": "$4.99"},
		{"id": "sniper_venom", "name": "Venom", "cost": 0, "color": Color(0.35, 0.85, 0.2, 1), "premium_price": "$4.99"},
		{"id": "sniper_solaris", "name": "Solaris", "cost": 0, "color": Color(1.0, 0.9, 0.55, 1), "premium_price": "$4.99"},
		{"id": "sniper_radiant", "name": "Radiant", "cost": 0, "color": Color(0.98, 0.97, 0.85, 1), "premium_price": "$4.99"},
	],
	"shotgun": [
		{"id": "shotgun_rust", "name": "Rustbelt", "cost": 170, "color": Color(0.65, 0.4, 0.2, 1)},
		{"id": "shotgun_steel", "name": "Cold Steel", "cost": 150, "color": Color(0.6, 0.62, 0.66, 1)},
		{"id": "shotgun_prismatic", "name": "Prismatic", "cost": 0, "color": Color(0.95, 0.55, 0.9, 1), "premium_price": "$4.99"},
		{"id": "shotgun_inferno", "name": "Inferno", "cost": 0, "color": Color(1.0, 0.45, 0.1, 1), "premium_price": "$4.99"},
		{"id": "shotgun_obsidian", "name": "Obsidian", "cost": 0, "color": Color(0.12, 0.06, 0.1, 1), "premium_price": "$4.99"},
	],
	"flamethrower": [
		{"id": "flamethrower_scorch", "name": "Scorched", "cost": 190, "color": Color(0.35, 0.16, 0.08, 1)},
		{"id": "flamethrower_hazard", "name": "Hazard Yellow", "cost": 170, "color": Color(0.9, 0.75, 0.15, 1)},
		{"id": "flamethrower_inferno", "name": "Inferno", "cost": 0, "color": Color(1.0, 0.45, 0.1, 1), "premium_price": "$4.99"},
		{"id": "flamethrower_abyssal", "name": "Abyssal", "cost": 0, "color": Color(0.15, 0.35, 0.9, 1), "premium_price": "$4.99"},
		{"id": "flamethrower_solaris", "name": "Solaris", "cost": 0, "color": Color(1.0, 0.9, 0.55, 1), "premium_price": "$4.99"},
	],
	"thorn": [
		{"id": "thorn_blight", "name": "Blight", "cost": 180, "color": Color(0.35, 0.25, 0.5, 1)},
		{"id": "thorn_autumn", "name": "Autumn Rot", "cost": 160, "color": Color(0.7, 0.45, 0.15, 1)},
		{"id": "thorn_venom", "name": "Venom", "cost": 0, "color": Color(0.35, 0.85, 0.2, 1), "premium_price": "$4.99"},
		{"id": "thorn_prismatic", "name": "Prismatic", "cost": 0, "color": Color(0.95, 0.55, 0.9, 1), "premium_price": "$4.99"},
		{"id": "thorn_radiant", "name": "Radiant", "cost": 0, "color": Color(0.98, 0.97, 0.85, 1), "premium_price": "$4.99"},
	],
	"railgun": [
		{"id": "railgun_chrome", "name": "Chrome", "cost": 240, "color": Color(0.82, 0.85, 0.9, 1)},
		{"id": "railgun_void", "name": "Void", "cost": 230, "color": Color(0.5, 0.2, 0.75, 1)},
		{"id": "railgun_prismatic", "name": "Prismatic", "cost": 0, "color": Color(0.95, 0.55, 0.9, 1), "premium_price": "$4.99"},
		{"id": "railgun_nebula", "name": "Nebula", "cost": 0, "color": Color(0.4, 0.25, 0.75, 1), "premium_price": "$4.99"},
		{"id": "railgun_radiant", "name": "Radiant", "cost": 0, "color": Color(0.98, 0.97, 0.85, 1), "premium_price": "$4.99"},
	],
	"chestplate": [
		{"id": "chest_white", "name": "Ghost", "cost": 160, "color": Color(0.9, 0.9, 0.9, 1)},
		{"id": "chest_black", "name": "Nightwatch", "cost": 170, "color": Color(0.1, 0.1, 0.12, 1)},
		{"id": "chest_gold", "name": "Royal", "cost": 200, "color": Color(0.8, 0.65, 0.2, 1)},
	],
	"helmet": [
		{"id": "helm_gold", "name": "Regal", "cost": 160, "color": Color(0.85, 0.7, 0.25, 1)},
		{"id": "helm_red", "name": "Warlord", "cost": 170, "color": Color(0.7, 0.15, 0.12, 1)},
	],
	"boots": [
		{"id": "boots_gold", "name": "Gilded Step", "cost": 110, "color": Color(0.85, 0.7, 0.25, 1)},
		{"id": "boots_blue", "name": "Frostwalker", "cost": 100, "color": Color(0.4, 0.7, 0.95, 1)},
	],
}

var owned_skins: Dictionary = {}
var equipped_skins: Dictionary = {}
signal skins_changed

func get_skins_for(icon_key: String) -> Array:
	return SKIN_CATALOG.get(icon_key, [])

func _find_skin(skin_id: String, icon_key: String) -> Dictionary:
	for skin in SKIN_CATALOG.get(icon_key, []):
		if skin.get("id", "") == skin_id:
			return skin
	return {}

# Public: the tint color for whatever skin is currently equipped for this
# icon_key, or plain white (no tint) if none is equipped.
func get_equipped_skin_color(icon_key: String) -> Color:
	if not equipped_skins.has(icon_key):
		return Color.WHITE
	var skin := _find_skin(equipped_skins[icon_key], icon_key)
	return skin.get("color", Color.WHITE) if not skin.is_empty() else Color.WHITE

func buy_skin(skin_id: String, icon_key: String) -> bool:
	if owned_skins.has(skin_id):
		return false
	var skin := _find_skin(skin_id, icon_key)
	if skin.is_empty():
		return false
	if not spend_currency("rubles", int(skin.get("cost", 0))):
		toast_requested.emit("Not enough Rubles for that skin")
		return false
	owned_skins[skin_id] = true
	toast_requested.emit("Purchased skin: %s" % skin.get("name", skin_id))
	skins_changed.emit()
	return true

func equip_skin(skin_id: String, icon_key: String) -> void:
	if skin_id == "":
		equipped_skins.erase(icon_key)
		toast_requested.emit("Skin removed")
	else:
		equipped_skins[icon_key] = skin_id
		toast_requested.emit("Skin equipped")
	skins_changed.emit()

# Returns the color an item's icon (or in-hand weapon) should render
# with - a skin tint if one's equipped for that icon_key, else rarity color.
func get_display_color(item: Dictionary) -> Color:
	var icon_key: String = item.get("icon_key", "generic")
	if equipped_skins.has(icon_key):
		var skin := _find_skin(equipped_skins[icon_key], icon_key)
		if not skin.is_empty():
			return skin.get("color", get_rarity_color(item.get("rarity", "common")))
	if item.get("slot", "") == "lootbag":
		return get_lootbag_color(item.get("rarity", "common"))
	return get_rarity_color(item.get("rarity", "common"))

# --- Item variety: every rolled piece of gear gets its primary stat
# randomized within a range (so two drops of the same item are never
# identical), plus a real chance at a second, different stat entirely -
# "Speed 47, Health 195" style, Borderlands-esque.
const ALL_STAT_TYPES := ["speed", "max_health", "damage", "fire_rate"]
const SECOND_STAT_CHANCE := 0.65

func _roll_stat_value(stat_type: String, base_value: float) -> float:
	if stat_type == "" or base_value == 0.0:
		return base_value
	var rolled: float = base_value * randf_range(0.75, 1.3)
	if stat_type == "fire_rate":
		return snappedf(rolled, 0.001)
	return float(round(rolled))

func finalize_rolled_item(item: Dictionary) -> Dictionary:
	var primary_type: String = item.get("stat_type", "")
	if primary_type != "":
		item["stat_value"] = _roll_stat_value(primary_type, float(item.get("stat_value", 0.0)))
		if randf() < SECOND_STAT_CHANCE:
			var choices: Array = []
			for t in ALL_STAT_TYPES:
				if t != primary_type:
					choices.append(t)
			var second_type: String = choices[randi() % choices.size()]
			# Scale the second stat off a reasonable baseline per type so it
			# feels proportional regardless of which stat got picked.
			var baseline := {"speed": 20.0, "max_health": 25.0, "damage": 6.0, "fire_rate": 0.02}
			var rarity_mult: float = get_rarity_multiplier(item.get("rarity", "common"))
			var second_base: float = float(baseline.get(second_type, 10.0)) * (0.5 + rarity_mult * 0.35)
			item["stat_type_2"] = second_type
			item["stat_value_2"] = _roll_stat_value(second_type, second_base)
	if item.get("rarity", "") == "multiversal":
		achievement_flag_multiversal_pull = true
	return item

func roll_gear_from_pool(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	return finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))

func get_gradient_colors(rarity: String) -> Array:
	if rarity == "godforged":
		return GODFORGED_GRADIENT
	if rarity == "divine":
		return DIVINE_GRADIENT
	if rarity == "multiversal":
		return MULTIVERSAL_GRADIENT
	if rarity == "exotic":
		return EXOTIC_GRADIENT
	if rarity == "mythic":
		return MYTHIC_GRADIENT
	return []

# A full-fill gradient TextureRect for Exotic/Multiversal items - meant
# to sit BEHIND a slightly-inset icon/background so it reads as a
# shimmering border, same trick InventoryTile uses for Stash tiles.
func make_gradient_border(rarity: String) -> TextureRect:
	var colors: Array = get_gradient_colors(rarity)
	if colors.is_empty():
		return null
	var grad := Gradient.new()
	for i in range(colors.size()):
		grad.add_point(float(i) / float(colors.size() - 1), colors[i])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(1, 1)
	grad_tex.width = 128
	grad_tex.height = 128
	var rect := TextureRect.new()
	rect.texture = grad_tex
	# expand_mode + set_anchors_and_offsets_preset (rather than bare
	# anchor_right/anchor_bottom) are both needed here - this TextureRect
	# gets its texture assigned and anchored BEFORE it has a parent (see
	# every caller below), and without expand_mode set, Godot sizes it to
	# the texture's own native resolution (128x128) and the plain anchor
	# assignment doesn't reliably override that once actually parented.
	# Confirmed by rendering this exact scene: this was the real cause of
	# the Alpha Rewards gradient washing out across cards at 128x128
	# instead of hugging each 44x44 icon - anchors alone weren't taking
	# effect, so it was rendering at its raw texture size, docked to
	# whatever corner it happened to inherit. This is shared by every
	# gradient border in the game (Stash, Traders, Battle Pass, Gamble,
	# and more) - fixing it here fixes it everywhere it's used.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.clip_contents = true
	return rect

func get_rarity_color(rarity: String) -> Color:
	var r = RARITY_TIERS.get(rarity)
	if r == null:
		return RARITY_TIERS["common"]["color"]
	return r["color"]

func get_rarity_label(rarity: String) -> String:
	var r = RARITY_TIERS.get(rarity)
	if r == null:
		return "Common"
	return r["label"]

# A one-line summary of what a weapon actually DOES in combat, keyed
# off icon_key the same way Bullet.gd picks its projectile behavior -
# shared by the item tooltip, the right-click Info popup, and the Data
# screen's Weapons tab, so all three always agree with each other and
# with what the gun actually does when fired.
func get_weapon_effect_text(icon_key: String) -> String:
	match icon_key:
		"pistol":
			return "A light, fast-handling sidearm - lower damage, but always reliable."
		"rifle":
			return "A steady, reliable all-rounder - balanced damage and rate of fire at any range."
		"thorn":
			return "Poisons on hit - deals extra damage over time."
		"railgun":
			return "Pierces through targets and arcs lightning to a second one."
		"sniper":
			return "Chills on hit, slowing the target - hits hardest of any single-target weapon."
		"flamethrower":
			return "Sets the target burning for damage over time - short range, high sustained damage."
		"shotgun":
			return "Fires 5 pellets in a spread - devastating up close, weak at range."
		"alpha_cannon":
			return "Pierces through multiple targets and arcs to a second one on every hit."
		"sword":
			return "A melee-styled weapon with real weight behind every hit."
		_:
			return ""

# The armor equivalent of get_weapon_effect_text() above - a real
# one-line description per gear slot instead of leaving armor with
# nothing but a bare stat line, the same gap weapons had before.
func get_armor_effect_text(slot: String, stat_type: String) -> String:
	match slot:
		"head":
			return "Headgear - absorbs damage before it reaches anywhere more vital."
		"body":
			return "Body armor - the biggest single chunk of damage reduction you can wear."
		"boots":
			return "Footwear - every point of Speed here is Speed you carry into every fight."
		"backpack":
			return "A pack - carries its own protection on top of whatever it lets you haul."
		"accessory":
			if stat_type == "damage":
				return "A small accessory that quietly adds real damage to every shot."
			return "A small accessory - modest on its own, real once it's part of a full loadout."
		_:
			return ""

func get_rarity_multiplier(rarity: String) -> float:
	var r = RARITY_TIERS.get(rarity)
	if r == null:
		return 1.0
	return r["multiplier"]

# Items picked up during the CURRENT run, not yet banked to the stash.
# Each item: {"name": String, "value": int, "slot": String, "stat_type": String,
#             "stat_value": float, "icon_key": String, "rarity": String,
#             "grid_x": int, "grid_y": int}
# slot is one of: "head", "body", "weapon", "accessory", "boots", "backpack"
# stat_type is one of: "speed", "max_health", "damage", "fire_rate"
var carried_loot: Array = []
var carried_value: int = 0

# Permanent stash: items successfully extracted, not currently equipped.
# Each item also has a free-form grid_x/grid_y position for the Tarkov-style inventory.
var stash_items: Array = []

const GRID_COLS := 8
const GRID_ROWS_BASE := 6
# The Stash (long-term storage) is its own, much bigger grid than the
# in-run Backpack - they used to share the same 8-wide layout, which
# didn't leave nearly enough room for a real stockpile.
const STASH_GRID_COLS := 11
const STASH_GRID_ROWS_BASE := 20

func get_stash_grid_rows() -> int:
	return STASH_GRID_ROWS_BASE + int(upgrades["stash_grid"].level) * 2

# --- Currencies ---
# Rubles: earned ONLY by selling gear to traders (does not drop in the
#         world). Spent buying gear from most traders.
# Junk: earned by scrapping gear at the Scrapper. Spent on the Scrapper's
#       rare/mythic catalog.
# Artifacts: found only in high-value loot (vault chests). Spent in the
#            Skill Tree.
# Alloys: bought from the Alloy Dealer using Rubles. Spent at the Hideout.
var rubles: int = 0
var junk: int = 0
var artifacts: int = 0
var alloys: int = 0
var souls: int = 0
var blossoms: int = 0
var skill_points: int = 0
var stones: int = 0

func get_currency(currency: String) -> int:
	match currency:
		"rubles": return rubles
		"junk": return junk
		"artifacts": return artifacts
		"alloys": return alloys
		"souls": return souls
		"blossoms": return blossoms
		"blood_shards": return blood_shards
		"tickets": return salvaged_beasts_tickets
		"skill_points": return skill_points
		"stones": return stones
		"honor": return guild_honor
		_: return 0

func add_currency(currency: String, amount: int) -> void:
	match currency:
		"rubles": rubles += amount
		"junk": junk += amount
		"artifacts": artifacts += amount
		"alloys": alloys += amount
		"blossoms": blossoms += amount
		"blood_shards": blood_shards += amount
		"tickets": salvaged_beasts_tickets += amount
		"skill_points": skill_points += amount
		"stones": stones += amount
		"honor": guild_honor += amount
		"souls":
			souls += amount
			if souls >= 500:
				notify_event("earn_500_souls")
	if amount > 0:
		toast_requested.emit("+%d %s" % [amount, currency.capitalize()])

func spend_currency(currency: String, amount: int) -> bool:
	if get_currency(currency) < amount:
		return false
	add_currency(currency, -amount)
	return true

# --- Spectral Tide: a limited-time event with its own currency (Souls),
# a 100-tier Battle Pass, new soul-themed loot, and the Commune wave
# survival activity. Reward table is generated once, deterministically
# (fixed seed) so it's identical every time without needing to store 100
# reward entries in the save file - only progress is saved.
const EVENT_NAME := "Spectral Tide"

const SOUL_ITEM_POOL := [
	{"name": "Wraith's Grasp", "value": 260, "slot": "weapon", "stat_type": "damage", "stat_value": 32.4, "icon_key": "rifle", "rarity": "epic"},
	{"name": "Spectral Ward", "value": 250, "slot": "body", "stat_type": "max_health", "stat_value": 48.6, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Hollow Cowl", "value": 230, "slot": "head", "stat_type": "max_health", "stat_value": 43.2, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Wisp-Step Boots", "value": 220, "slot": "boots", "stat_type": "speed", "stat_value": 40.5, "icon_key": "boots", "rarity": "epic"},
	{"name": "Mistbound Sniper", "value": 300, "slot": "weapon", "stat_type": "damage", "stat_value": 39.2, "icon_key": "sniper", "rarity": "epic"},
	{"name": "Soulbinder Pack", "value": 240, "slot": "backpack", "stat_type": "max_health", "stat_value": 45.9, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Ghostlight Ring", "value": 235, "slot": "accessory", "stat_type": "speed", "stat_value": 36.5, "icon_key": "ring", "rarity": "epic"},
	{"name": "Harvester's Reach", "value": 620, "slot": "weapon", "stat_type": "damage", "stat_value": 51.3, "icon_key": "rifle", "rarity": "mythic"},
	{"name": "Veil of the Tide", "value": 600, "slot": "body", "stat_type": "max_health", "stat_value": 74.2, "icon_key": "chestplate", "rarity": "mythic"},
	{"name": "Crown of Hollow Souls", "value": 580, "slot": "head", "stat_type": "max_health", "stat_value": 67.5, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Harvester's Scythe", "value": 950, "slot": "weapon", "stat_type": "damage", "stat_value": 59.4, "icon_key": "sniper", "rarity": "exotic"},
	{"name": "Shroud of the Tide", "value": 920, "slot": "body", "stat_type": "max_health", "stat_value": 87.8, "icon_key": "chestplate", "rarity": "exotic"},
	{"name": "Heart of the Multiverse", "value": 2000, "slot": "weapon", "stat_type": "damage", "stat_value": 81.0, "icon_key": "sniper", "rarity": "multiversal"},
	{"name": "Reality Fracture Plate", "value": 1900, "slot": "body", "stat_type": "max_health", "stat_value": 121.5, "icon_key": "chestplate", "rarity": "multiversal"},
]

var battle_pass_tier: int = 0
var battle_pass_progress: int = 0
const BATTLE_PASS_XP_PER_TIER := 100
const BATTLE_PASS_MAX_TIER := 200

func _soul_pool_for_tier(tier: int) -> Array:
	var target_rarity := "epic"
	if tier >= 198:
		target_rarity = "multiversal"
	elif tier >= 190:
		target_rarity = "exotic"
	elif tier >= 100:
		target_rarity = "mythic"
	var pool: Array = []
	for pool_item in SOUL_ITEM_POOL:
		if pool_item.get("rarity", "") == target_rarity:
			pool.append(pool_item)
	if pool.is_empty():
		pool = SOUL_ITEM_POOL
	return pool

func _generate_battle_pass_rewards() -> Array:
	var rewards: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(BATTLE_PASS_MAX_TIER):
		var tier := i + 1
		# Milestone every 10 tiers - always an item, quality rises with tier.
		if tier % 10 == 0:
			var pool := _soul_pool_for_tier(tier)
			var item: Dictionary = pool[rng.randi() % pool.size()].duplicate(true)
			item["event_tag"] = EVENT_NAME
			rewards.append({"type": "item", "data": item})
			continue
		# Every 20 tiers on an off-beat, a Loot Bag instead.
		if tier % 20 == 5:
			rewards.append({"type": "lootbag"})
			continue
		var roll: int = tier % 8
		match roll:
			0:
				rewards.append({"type": "souls", "amount": int(20 + tier * 1.6)})
			1:
				rewards.append({"type": "rubles", "amount": int(120 + tier * 12)})
			2:
				rewards.append({"type": "xp", "amount": int(60 + tier * 4)})
			3:
				var pool := _soul_pool_for_tier(tier)
				var item: Dictionary = pool[rng.randi() % pool.size()].duplicate(true)
				item["event_tag"] = EVENT_NAME
				rewards.append({"type": "item", "data": item})
			4:
				rewards.append({"type": "skill_points", "amount": 1 + int(tier / 40.0)})
			5:
				rewards.append({"type": "item", "data": AMMO_POOL[rng.randi() % AMMO_POOL.size()].duplicate(true)})
			6:
				rewards.append({"type": "item", "data": {"name": "Plushie", "value": 35, "slot": "plushie", "stat_type": "", "stat_value": 0.0, "icon_key": "plushie", "rarity": "common", "desc": "A soft, slightly-worn stuffed toy - somebody's favorite, once. Rose would probably know what to do with this."}})
			_:
				rewards.append({"type": "souls", "amount": int(12 + tier * 1.4)})
	return rewards

func grant_battle_pass_xp(amount: int) -> void:
	if amount <= 0 or battle_pass_tier >= BATTLE_PASS_MAX_TIER:
		return
	battle_pass_progress += amount
	while battle_pass_progress >= BATTLE_PASS_XP_PER_TIER and battle_pass_tier < BATTLE_PASS_MAX_TIER:
		battle_pass_progress -= BATTLE_PASS_XP_PER_TIER
		_advance_battle_pass_tier()

func skip_battle_pass_tier() -> bool:
	if battle_pass_tier >= BATTLE_PASS_MAX_TIER:
		return false
	if not spend_currency("rubles", 5000):
		return false
	battle_pass_progress = 0
	_advance_battle_pass_tier()
	return true

const SOULS_PER_TIER_SKIP := 100

func skip_battle_pass_tier_with_souls() -> bool:
	if battle_pass_tier >= BATTLE_PASS_MAX_TIER:
		return false
	if not spend_currency("souls", SOULS_PER_TIER_SKIP):
		return false
	battle_pass_progress = 0
	_advance_battle_pass_tier()
	return true

func _advance_battle_pass_tier() -> void:
	battle_pass_tier += 1
	var rewards := _generate_battle_pass_rewards()
	var reward: Dictionary = rewards[battle_pass_tier - 1]
	match reward.get("type", ""):
		"souls":
			add_currency("souls", int(reward.get("amount", 0)))
		"rubles":
			add_currency("rubles", int(reward.get("amount", 0)))
		"xp":
			grant_xp(int(reward.get("amount", 0)))
		"skill_points":
			add_currency("skill_points", int(reward.get("amount", 0)))
		"item":
			_add_to_stash(reward.get("data", {}).duplicate(true))
		"lootbag":
			var bp_bag := make_loot_bag("legendary")
			bp_bag["event_tag"] = EVENT_NAME
			_add_to_stash(bp_bag)
	toast_requested.emit("Battle Pass Tier %d unlocked!" % battle_pass_tier)
	save_game()

# --- Milestones: a permanent (non-limited-time) progression track themed
# around raid/Arena career moments. Its currency (Stones) is earned from
# successful extractions, killing real-player enemies, and winning Arena
# matches - see end_run() and Enemy.gd's die(). Unlike the Battle Pass's
# procedurally-generated 200 tiers, this is a small, curated, hand-authored
# list, and its rewards are deliberately never more Stones themselves.
const REAL_PLAYER_KILL_STONES := 5
const EXTRACTION_STONES := 10
const ARENA_WIN_STONES := 15

var milestone_tier: int = 0
var milestone_progress: int = 0
const MILESTONE_STONES_PER_TIER := 50
const MILESTONE_MAX_TIER := 24

const MILESTONE_TIER_DATA := [
	{"name": "First Extraction", "type": "rubles", "amount": 150},
	{"name": "Blooded", "type": "rubles", "amount": 200},
	{"name": "Scavenger", "type": "skill_points", "amount": 1},
	{"name": "Marksman", "type": "rubles", "amount": 300},
	{"name": "Silent Professional", "type": "xp", "amount": 150},
	{"name": "Grid Contender", "type": "rubles", "amount": 400},
	{"name": "Loadout Specialist", "type": "lootbag", "bag_tier": "common"},
	{"name": "Extraction Veteran", "type": "rubles", "amount": 500},
	{"name": "Real Threat", "type": "skill_points", "amount": 1},
	{"name": "Grid Duelist", "type": "rubles", "amount": 650},
	{"name": "Night Operator", "type": "xp", "amount": 250},
	{"name": "Arena Regular", "type": "lootbag", "bag_tier": "rare"},
	{"name": "Extraction Expert", "type": "rubles", "amount": 800},
	{"name": "Sharpshooter", "type": "skill_points", "amount": 2},
	{"name": "Grid Veteran", "type": "rubles", "amount": 1000},
	{"name": "Field Tactician", "type": "xp", "amount": 350},
	{"name": "Arena Contender", "type": "lootbag", "bag_tier": "rare"},
	{"name": "Elite Extractor", "type": "rubles", "amount": 1300},
	{"name": "Marked Hunter", "type": "skill_points", "amount": 2},
	{"name": "Grid Champion", "type": "rubles", "amount": 1600},
	{"name": "Operator of Note", "type": "xp", "amount": 500},
	{"name": "Arena Elite", "type": "lootbag", "bag_tier": "epic"},
	{"name": "Sector Veteran", "type": "rubles", "amount": 2000},
	{"name": "Legend of the Grid", "type": "lootbag", "bag_tier": "legendary"},
]

func grant_stones(amount: int) -> void:
	if amount <= 0:
		return
	add_currency("stones", amount)
	if milestone_tier >= MILESTONE_MAX_TIER:
		return
	milestone_progress += amount
	while milestone_progress >= MILESTONE_STONES_PER_TIER and milestone_tier < MILESTONE_MAX_TIER:
		milestone_progress -= MILESTONE_STONES_PER_TIER
		_advance_milestone_tier()

func _advance_milestone_tier() -> void:
	milestone_tier += 1
	var tier_data: Dictionary = MILESTONE_TIER_DATA[milestone_tier - 1]
	match tier_data.get("type", ""):
		"rubles":
			add_currency("rubles", int(tier_data.get("amount", 0)))
		"xp":
			grant_xp(int(tier_data.get("amount", 0)))
		"skill_points":
			add_currency("skill_points", int(tier_data.get("amount", 0)))
		"lootbag":
			_add_to_stash(make_loot_bag(str(tier_data.get("bag_tier", "rare"))))
	toast_requested.emit("Milestone reached: %s!" % str(tier_data.get("name", "Tier %d" % milestone_tier)))
	save_game()

# --- Enemy loot drops: the ONLY sources of loot are enemies and vault
# chests inside houses. Enemies roll against this pool on death for a
# chance to also drop a gear item, spanning every slot. No currency drops
# from enemies - Rubles only come from selling gear.
const ENEMY_LOOT_POOL := [
	{"name": "Scrap Pistol", "value": 45, "slot": "weapon", "stat_type": "damage", "stat_value": 6.8, "icon_key": "pistol", "rarity": "common"},
	{"name": "Field Vest", "value": 45, "slot": "body", "stat_type": "max_health", "stat_value": 16.2, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Steel Helm", "value": 40, "slot": "head", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "helmet", "rarity": "common"},
	{"name": "Worn Boots", "value": 35, "slot": "boots", "stat_type": "speed", "stat_value": 16.2, "icon_key": "boots", "rarity": "common"},
	{"name": "Salvaged Pack", "value": 50, "slot": "backpack", "stat_type": "max_health", "stat_value": 20.2, "icon_key": "backpack", "rarity": "common"},
	{"name": "Lucky Charm", "value": 65, "slot": "accessory", "stat_type": "speed", "stat_value": 18.9, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Combat Boots", "value": 70, "slot": "boots", "stat_type": "speed", "stat_value": 27.0, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Ranger Pack", "value": 75, "slot": "backpack", "stat_type": "fire_rate", "stat_value": 0.0, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Assault Rifle", "value": 110, "slot": "weapon", "stat_type": "damage", "stat_value": 18.9, "icon_key": "rifle", "rarity": "rare"},
	{"name": "Reinforced Plate", "value": 120, "slot": "body", "stat_type": "max_health", "stat_value": 37.8, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Ghost Sniper Rifle", "value": 150, "slot": "weapon", "stat_type": "damage", "stat_value": 35.1, "icon_key": "sniper", "rarity": "rare"},
	{"name": "Rusty Revolver", "value": 38, "slot": "weapon", "stat_type": "damage", "stat_value": 5.4, "icon_key": "pistol", "rarity": "common"},
	{"name": "Riot Helmet", "value": 42, "slot": "head", "stat_type": "max_health", "stat_value": 12.2, "icon_key": "helmet", "rarity": "common"},
	{"name": "Padded Jacket", "value": 40, "slot": "body", "stat_type": "max_health", "stat_value": 14.9, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Runner's Sneakers", "value": 37, "slot": "boots", "stat_type": "speed", "stat_value": 17.6, "icon_key": "boots", "rarity": "common"},
	{"name": "Hunting Carbine", "value": 95, "slot": "weapon", "stat_type": "damage", "stat_value": 16.2, "icon_key": "rifle", "rarity": "uncommon"},
	{"name": "Marksman Rifle", "value": 105, "slot": "weapon", "stat_type": "damage", "stat_value": 17.6, "icon_key": "sniper", "rarity": "uncommon"},
	{"name": "Kevlar Vest", "value": 85, "slot": "body", "stat_type": "max_health", "stat_value": 27.0, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Recon Helmet", "value": 80, "slot": "head", "stat_type": "max_health", "stat_value": 24.3, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Trench Coat", "value": 78, "slot": "body", "stat_type": "speed", "stat_value": 13.5, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Heavy Cannon", "value": 130, "slot": "weapon", "stat_type": "damage", "stat_value": 24.3, "icon_key": "rifle", "rarity": "rare"},
	{"name": "Vanguard Helmet", "value": 125, "slot": "head", "stat_type": "max_health", "stat_value": 40.5, "icon_key": "helmet", "rarity": "rare"},
	{"name": "Overwatch Scope Rifle", "value": 155, "slot": "weapon", "stat_type": "damage", "stat_value": 36.5, "icon_key": "sniper", "rarity": "rare"},
	{"name": "Sentinel Boots", "value": 90, "slot": "boots", "stat_type": "speed", "stat_value": 29.7, "icon_key": "boots", "rarity": "rare"},
	{"name": "Bandit Pistol", "value": 30, "slot": "weapon", "stat_type": "damage", "stat_value": 4.1, "icon_key": "pistol", "rarity": "common"},
	{"name": "Scout Cap", "value": 32, "slot": "head", "stat_type": "max_health", "stat_value": 10.8, "icon_key": "helmet", "rarity": "common"},
	{"name": "Denim Jacket", "value": 30, "slot": "body", "stat_type": "max_health", "stat_value": 12.2, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Canvas Pack", "value": 42, "slot": "backpack", "stat_type": "max_health", "stat_value": 16.2, "icon_key": "backpack", "rarity": "common"},
	{"name": "Tactical Gloves", "value": 72, "slot": "accessory", "stat_type": "fire_rate", "stat_value": 0.0, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Sharpshooter Rifle", "value": 115, "slot": "weapon", "stat_type": "damage", "stat_value": 20.2, "icon_key": "sniper", "rarity": "rare"},
	{"name": "Bulwark Plate", "value": 128, "slot": "body", "stat_type": "max_health", "stat_value": 40.5, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Falcon Boots", "value": 95, "slot": "boots", "stat_type": "speed", "stat_value": 32.4, "icon_key": "boots", "rarity": "rare"},
	{"name": "Phantom SMG", "value": 220, "slot": "weapon", "stat_type": "damage", "stat_value": 40.5, "icon_key": "rifle", "rarity": "epic"},
	{"name": "Juggernaut Plate", "value": 230, "slot": "body", "stat_type": "max_health", "stat_value": 56.7, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Warden Helm", "value": 210, "slot": "head", "stat_type": "max_health", "stat_value": 51.3, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Blitz Boots", "value": 190, "slot": "boots", "stat_type": "speed", "stat_value": 43.2, "icon_key": "boots", "rarity": "epic"},
	{"name": "Void Pack", "value": 225, "slot": "backpack", "stat_type": "max_health", "stat_value": 54.0, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Specter Ring", "value": 215, "slot": "accessory", "stat_type": "speed", "stat_value": 37.8, "icon_key": "ring", "rarity": "epic"},
	{"name": "Railgun", "value": 250, "slot": "weapon", "stat_type": "damage", "stat_value": 45.9, "icon_key": "railgun", "rarity": "epic"},
	{"name": "Ironclad Vest", "value": 235, "slot": "body", "stat_type": "max_health", "stat_value": 60.8, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Scorcher", "value": 90, "slot": "weapon", "stat_type": "damage", "stat_value": 10.8, "icon_key": "flamethrower", "rarity": "uncommon"},
	{"name": "Inferno Cannon", "value": 170, "slot": "weapon", "stat_type": "damage", "stat_value": 16.2, "icon_key": "flamethrower", "rarity": "rare"},
	{"name": "Ashmaker", "value": 260, "slot": "weapon", "stat_type": "damage", "stat_value": 21.6, "icon_key": "flamethrower", "rarity": "epic"},
	{"name": "Thorn", "value": 85, "slot": "weapon", "stat_type": "damage", "stat_value": 12.2, "icon_key": "thorn", "rarity": "uncommon"},
	{"name": "Barbed Thorn", "value": 165, "slot": "weapon", "stat_type": "damage", "stat_value": 17.6, "icon_key": "thorn", "rarity": "rare"},
	{"name": "Toxinbrand", "value": 255, "slot": "weapon", "stat_type": "damage", "stat_value": 23.0, "icon_key": "thorn", "rarity": "epic"},
	{"name": "Coilbreaker", "value": 95, "slot": "weapon", "stat_type": "damage", "stat_value": 13.5, "icon_key": "railgun", "rarity": "uncommon"},
	{"name": "Magrail", "value": 175, "slot": "weapon", "stat_type": "damage", "stat_value": 20.2, "icon_key": "railgun", "rarity": "rare"},
	{"name": "Rustbelt Shiv", "value": 25, "slot": "weapon", "stat_type": "damage", "stat_value": 2.7, "icon_key": "pistol", "rarity": "common"},
	{"name": "Patchwork Vest", "value": 33, "slot": "body", "stat_type": "max_health", "stat_value": 10.8, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Cracked Visor Helm", "value": 36, "slot": "head", "stat_type": "max_health", "stat_value": 10.8, "icon_key": "helmet", "rarity": "common"},
	{"name": "Duct-Taped Boots", "value": 28, "slot": "boots", "stat_type": "speed", "stat_value": 12.2, "icon_key": "boots", "rarity": "common"},
	{"name": "Scrapper's Satchel", "value": 40, "slot": "backpack", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "backpack", "rarity": "common"},
	{"name": "Bent Copper Ring", "value": 38, "slot": "accessory", "stat_type": "speed", "stat_value": 8.1, "icon_key": "ring", "rarity": "common"},
	{"name": "Wasteland Shotgun", "value": 88, "slot": "weapon", "stat_type": "damage", "stat_value": 14.9, "icon_key": "shotgun", "rarity": "uncommon"},
	{"name": "Outrider's Vest", "value": 82, "slot": "body", "stat_type": "speed", "stat_value": 12.2, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Watchman's Helm", "value": 76, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Sprinter's Wraps", "value": 74, "slot": "boots", "stat_type": "speed", "stat_value": 28.4, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Prospector's Pack", "value": 79, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Copper Loop", "value": 70, "slot": "accessory", "stat_type": "max_health", "stat_value": 21.6, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Riftline Shotgun", "value": 145, "slot": "weapon", "stat_type": "damage", "stat_value": 32.4, "icon_key": "shotgun", "rarity": "rare"},
	{"name": "Deadbolt Plate", "value": 122, "slot": "body", "stat_type": "max_health", "stat_value": 39.2, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Hound's Helm", "value": 118, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "rare"},
	{"name": "Ridgeline Boots", "value": 92, "slot": "boots", "stat_type": "speed", "stat_value": 31.1, "icon_key": "boots", "rarity": "rare"},
	{"name": "Hollowpoint Ring", "value": 130, "slot": "accessory", "stat_type": "damage", "stat_value": 10.8, "icon_key": "ring", "rarity": "rare"},
	{"name": "Widowmaker Sniper", "value": 160, "slot": "weapon", "stat_type": "damage", "stat_value": 39.2, "icon_key": "sniper", "rarity": "rare"},
	# "shot_cooldown" (seconds) is a per-item override Player.gd's
	# _recompute_stats() checks for - it replaces the shared base fire-rate
	# entirely instead of just trimming it, so this specific rifle fires far
	# slower than the rest of the "sniper" family despite sharing its
	# icon_key (same reload/mag/ammo-type/scope-zoom/frost-on-hit behavior).
	# 2.5s here becomes ~3.0s in practice once the heavy-ammo 1.2x cooldown
	# multiplier is applied in _apply_ammo_type_tradeoff().
	{"name": "Behemoth Anti-Materiel Rifle", "value": 280, "slot": "weapon", "stat_type": "damage", "stat_value": 62.0, "icon_key": "sniper", "rarity": "epic", "shot_cooldown": 2.5},
	{"name": "Reaper's Shotgun", "value": 240, "slot": "weapon", "stat_type": "damage", "stat_value": 43.2, "icon_key": "shotgun", "rarity": "epic"},
	{"name": "Aegis Plate", "value": 245, "slot": "body", "stat_type": "max_health", "stat_value": 64.8, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Oracle Visor", "value": 220, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Wraithwalker Boots", "value": 200, "slot": "boots", "stat_type": "speed", "stat_value": 45.9, "icon_key": "boots", "rarity": "epic"},
	{"name": "Sovereign's Signet", "value": 230, "slot": "accessory", "stat_type": "damage", "stat_value": 16.2, "icon_key": "ring", "rarity": "epic"},
	{"name": "Tac Visor", "value": 60, "slot": "helmet_attachment", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "visor", "rarity": "uncommon"},
	{"name": "Comms Headset", "value": 65, "slot": "helmet_attachment", "stat_type": "fire_rate", "stat_value": 0.0, "icon_key": "headset", "rarity": "uncommon"},
	{"name": "Nightvision Goggles", "value": 140, "slot": "helmet_attachment", "stat_type": "max_health", "stat_value": 6.8, "icon_key": "nightvision_goggles", "rarity": "rare", "grants_nightvision": true},
]

func roll_enemy_loot() -> Dictionary:
	return finalize_rolled_item(ENEMY_LOOT_POOL[randi() % ENEMY_LOOT_POOL.size()].duplicate(true))

# --- Ruble Stacks: Rubles as a real, physical, stackable item you carry
# and can lose - not just an abstract number. Multiple stacks picked up
# merge into one tile showing the combined total, same idea as ammo/currency
# stacks in other extraction shooters.
# --- Valuables: found in containers - not equippable, just sellable/
# tradeable loot (like keys), and also the raw materials the Hideout
# workbench uses for crafting.
const VALUABLES_POOL := [
	{"name": "Canned Food", "value": 25, "icon_key": "canned_food", "rarity": "common"},
	{"name": "Batteries", "value": 30, "icon_key": "batteries", "rarity": "common"},
	{"name": "Bar of Soap", "value": 15, "icon_key": "soap", "rarity": "common"},
	{"name": "Chlorine", "value": 35, "icon_key": "chlorine", "rarity": "uncommon"},
	{"name": "Toothpaste", "value": 12, "icon_key": "toothpaste", "rarity": "common"},
	{"name": "Military Filter", "value": 60, "icon_key": "mil_filter", "rarity": "rare"},
	{"name": "Paracord", "value": 20, "icon_key": "paracord", "rarity": "common"},
	{"name": "Screws", "value": 10, "icon_key": "screws", "rarity": "common"},
	{"name": "Hard Plate", "value": 55, "icon_key": "hard_plate", "rarity": "uncommon"},
	{"name": "Duct Tape", "value": 18, "icon_key": "duct_tape", "rarity": "common"},
	{"name": "Cloth", "value": 14, "icon_key": "cloth", "rarity": "common"},
	{"name": "Antiseptic", "value": 40, "icon_key": "antiseptic", "rarity": "uncommon"},
	{"name": "Graphics Card", "value": 180, "icon_key": "gpu", "rarity": "rare"},
	{"name": "GPCoin", "value": 40, "icon_key": "gpcoin", "rarity": "uncommon"},
]

func roll_valuable() -> Dictionary:
	var pool_item: Dictionary = VALUABLES_POOL[randi() % VALUABLES_POOL.size()].duplicate(true)
	pool_item["slot"] = "valuable"
	pool_item["stat_type"] = ""
	pool_item["stat_value"] = 0.0
	return pool_item

# --- Gas Mask: a helmet that lets you survive the Radiation Zone. Drops
# from Toxic Waste enemies that spawn near (not inside) it.
func roll_gas_mask() -> Dictionary:
	return {
		"name": "Gas Mask", "value": 90, "slot": "head", "stat_type": "max_health",
		"stat_value": 8.0, "icon_key": "gas_mask", "rarity": "rare",
		"grants_radiation_immunity": true,
	}

func has_gas_mask() -> bool:
	var head = equipped_items.get("head")
	return head != null and bool(head.get("grants_radiation_immunity", false))

# Quest 14: hand 2 Batteries over to the Scrapper. No currency reward here
# beyond the quest reward itself - this is a delivery, not a sale.
func deliver_batteries() -> bool:
	if quest_status.get("deliver_batteries", "") != "active":
		return false
	var indices: Array = []
	for i in range(stash_items.size()):
		if stash_items[i].get("name", "") == "Batteries":
			indices.append(i)
			if indices.size() >= 2:
				break
	if indices.size() < 2:
		toast_requested.emit("Need 2 Batteries in your Stash to deliver")
		return false
	indices.reverse()
	for idx in indices:
		stash_items.remove_at(idx)
	toast_requested.emit("Delivered 2 Batteries to the Scrapper")
	notify_event("deliver_batteries")
	return true

func roll_ruble_item() -> Dictionary:
	var amt := randi_range(20, 80)
	return {
		"name": "Rubles x%d" % amt, "base_name": "Rubles", "value": amt,
		"slot": "currency_item", "currency_type": "rubles", "icon_key": "rubles_item", "rarity": "common",
	}

# Tries to merge a currency-item stack into an existing matching stack in
# `items`. Returns the amount actually merged in (0 if no merge happened,
# meaning the caller should place it as a normal new tile instead).
func _would_merge_currency(items: Array, item: Dictionary) -> bool:
	if item.get("slot", "") != "currency_item":
		return false
	for existing in items:
		if existing.get("slot", "") == "currency_item" and existing.get("currency_type", "rubles") == item.get("currency_type", "rubles"):
			return true
	return false

func _would_merge_grenade(items: Array, item: Dictionary) -> bool:
	if item.get("consumable_type", "") != "grenade":
		return false
	var gtype: String = item.get("grenade_type", "frag")
	for existing in items:
		if existing.get("consumable_type", "") == "grenade" and existing.get("grenade_type", "") == gtype and int(existing.get("stack_count", 1)) < GRENADE_STACK_MAX:
			return true
	return false

func _try_merge_currency_item(items: Array, item: Dictionary) -> int:
	if item.get("slot", "") != "currency_item":
		return 0
	for existing in items:
		if existing.get("slot", "") == "currency_item" and existing.get("currency_type", "rubles") == item.get("currency_type", "rubles"):
			var add_amt := int(item.get("value", 0))
			existing["value"] = int(existing.get("value", 0)) + add_amt
			existing["name"] = "%s x%d" % [existing.get("base_name", "Rubles"), existing["value"]]
			return add_amt
	return 0

# Grenades (and other consumables) stack up to 10x in one tile, same
# idea as the currency-item stacks above.
const GRENADE_STACK_MAX := 10

func _try_merge_grenade_stack(items: Array, item: Dictionary) -> bool:
	if item.get("consumable_type", "") != "grenade":
		return false
	var gtype: String = item.get("grenade_type", "frag")
	for existing in items:
		if existing.get("consumable_type", "") == "grenade" and existing.get("grenade_type", "") == gtype:
			var current: int = int(existing.get("stack_count", 1))
			if current >= GRENADE_STACK_MAX:
				continue
			if not existing.has("base_name"):
				existing["base_name"] = existing.get("name", "Grenade")
			existing["stack_count"] = current + 1
			existing["name"] = "%s x%d" % [existing["base_name"], current + 1]
			return true
	return false

# --- Consumables: usable from the Hotbar (slots 2-5), not equippable gear -
# they just sit in carried_loot/stash_items with slot "consumable" until
# used (heal), eaten (food), or thrown (grenade), then they're removed.
const CONSUMABLE_POOL := [
	{"name": "Field Bandage", "value": 20, "slot": "consumable", "icon_key": "bandage", "rarity": "common", "consumable_type": "heal", "heal_amount": 35.0},
	{"name": "Trauma Kit", "value": 45, "slot": "consumable", "icon_key": "medkit", "rarity": "uncommon", "consumable_type": "heal", "heal_amount": 60.0},
	{"name": "Ration Pack", "value": 22, "slot": "consumable", "icon_key": "canned_food", "rarity": "common", "consumable_type": "food", "food_amount": 35.0},
	{"name": "MRE", "value": 48, "slot": "consumable", "icon_key": "mre_pouch", "rarity": "uncommon", "consumable_type": "food", "food_amount": 60.0},
	{"name": "Frag Grenade", "value": 30, "slot": "consumable", "icon_key": "grenade", "rarity": "uncommon", "consumable_type": "grenade", "grenade_type": "frag", "grenade_damage": 55, "grenade_radius": 95.0},
	{"name": "Smoke Grenade", "value": 25, "slot": "consumable", "icon_key": "smoke_grenade", "rarity": "common", "consumable_type": "grenade", "grenade_type": "smoke"},
	{"name": "Molotov", "value": 35, "slot": "consumable", "icon_key": "molotov", "rarity": "uncommon", "consumable_type": "grenade", "grenade_type": "molotov"},
	{"name": "Stun Grenade", "value": 35, "slot": "consumable", "icon_key": "stun_grenade", "rarity": "uncommon", "consumable_type": "grenade", "grenade_type": "stun"},
]

# --- Ammo: Light/Medium/Heavy, matching which weapons take which (see
# WEAPON_AMMO_TYPE below). A real backpack/Stash item like Bandages or
# Grenades - NOT Hotbar-usable (slot "ammo", not "consumable" - there's
# nothing to "use", it just sits in your inventory as reserve stock that
# reload draws from directly). Stacks in one tile up to AMMO_STACK_MAX
# for its type, same idea as the Grenade stack below. Deliberately its
# own pool, separate from CONSUMABLE_POOL, so ammo drop rates can be
# tuned on their own without also changing how often heals/grenades show up.
# Rarity here is purely a color choice (green/blue/purple per type, via
# the shared rarity-color system every other item already uses) - NOT
# a drop-weight or value signal the way it is for real gear. See
# get_ammo_rarity() below, the single source every OTHER hardcoded ammo
# dict in this file derives its own "rarity" field from, so this
# mapping only ever needs to change in one place.
const AMMO_POOL := [
	{"name": "Light Ammo", "value": 15, "slot": "ammo", "icon_key": "ammo_light", "rarity": "uncommon", "consumable_type": "ammo", "ammo_type": "light"},
	{"name": "Medium Ammo", "value": 20, "slot": "ammo", "icon_key": "ammo_medium", "rarity": "rare", "consumable_type": "ammo", "ammo_type": "medium"},
	{"name": "Heavy Ammo", "value": 28, "slot": "ammo", "icon_key": "ammo_heavy", "rarity": "epic", "consumable_type": "ammo", "ammo_type": "heavy"},
]

func get_ammo_rarity(ammo_type: String) -> String:
	for pool_item in AMMO_POOL:
		if pool_item.get("ammo_type", "") == ammo_type:
			return str(pool_item.get("rarity", "common"))
	return "common"

# How many rounds a single pickup grants - randomized per pickup rather
# than a flat amount, so finding ammo doesn't feel identical every time.
const AMMO_PICKUP_MIN := 100
const AMMO_PICKUP_MAX := 150

# How many rounds of a given type can pile up in one backpack/Stash tile
# before a fresh pickup of that type has to start a new tile instead.
const AMMO_STACK_MAX := {"light": 2000, "medium": 1000, "heavy": 500}

# Guaranteed static ammo stock added to the Scavenger's shop (see
# TRADER_CATALOG below) - always in stock regardless of the 10-minute
# rotation reroll (see _rotate_traders, which re-appends a fresh copy each
# cycle the same way Quartermaster's Loot Bags are), so there's a reliable
# place to restock reserve ammo without waiting on RNG. Priced on this
# catalog's existing ~50-140 Ruble scale, cheapest to priciest matching
# Light/Medium/Heavy's relative rarity - these are purchase prices, NOT
# the AMMO_POOL "value" above (that's calibrated for sell-back value, not
# what a trader charges to buy).
const SCAVENGER_AMMO_STOCK := [
	{"name": "Light Ammo x150", "base_name": "Light Ammo", "cost": 50, "value": 15, "slot": "ammo", "icon_key": "ammo_light", "rarity": "uncommon", "consumable_type": "ammo", "ammo_type": "light", "ammo_amount": 150},
	{"name": "Medium Ammo x150", "base_name": "Medium Ammo", "cost": 80, "value": 20, "slot": "ammo", "icon_key": "ammo_medium", "rarity": "rare", "consumable_type": "ammo", "ammo_type": "medium", "ammo_amount": 150},
	{"name": "Heavy Ammo x150", "base_name": "Heavy Ammo", "cost": 120, "value": 28, "slot": "ammo", "icon_key": "ammo_heavy", "rarity": "epic", "consumable_type": "ammo", "ammo_type": "heavy", "ammo_amount": 150},
]

func roll_ammo() -> Dictionary:
	return _stack_ammo(AMMO_POOL[randi() % AMMO_POOL.size()].duplicate(true))

# Stamps a random AMMO_PICKUP_MIN..MAX quantity onto a raw AMMO_POOL entry
# (or a duplicate of one) - shared by roll_ammo() above and by anywhere
# else that already picked a specific ammo type/rarity and just needs it
# turned into a real stack with a "x123" display name, e.g. the Flea
# Market's "other sellers" roll (see _roll_flea_market_item).
func _stack_ammo(base: Dictionary) -> Dictionary:
	var amount := randi_range(AMMO_PICKUP_MIN, AMMO_PICKUP_MAX)
	base["base_name"] = base["name"]
	base["ammo_amount"] = amount
	base["name"] = "%s x%d" % [base["base_name"], amount]
	return base

func _would_merge_ammo(items: Array, item: Dictionary) -> bool:
	if item.get("consumable_type", "") != "ammo":
		return false
	var atype: String = item.get("ammo_type", "light")
	var cap: int = int(AMMO_STACK_MAX.get(atype, 500))
	for existing in items:
		if existing.get("consumable_type", "") == "ammo" and existing.get("ammo_type", "") == atype and int(existing.get("ammo_amount", 0)) < cap:
			return true
	return false

func _try_merge_ammo_stack(items: Array, item: Dictionary) -> bool:
	if item.get("consumable_type", "") != "ammo":
		return false
	var atype: String = item.get("ammo_type", "light")
	var cap: int = int(AMMO_STACK_MAX.get(atype, 500))
	# Unlike grenades (always +1, so "this stack's full, keep looking" and
	# "no room anywhere, spill to a new stack" are the only two outcomes),
	# an ammo pickup is a variable amount that can PARTLY fit into one
	# stack's remaining headroom - the old version merged as much as fit
	# into the first eligible stack and returned true unconditionally,
	# discarding whatever didn't fit instead of continuing to look for
	# room elsewhere or spilling it into a new stack.
	var remaining: int = int(item.get("ammo_amount", 0))
	for existing in items:
		if remaining <= 0:
			break
		if existing.get("consumable_type", "") == "ammo" and existing.get("ammo_type", "") == atype:
			var current: int = int(existing.get("ammo_amount", 0))
			if current >= cap:
				continue
			if not existing.has("base_name"):
				existing["base_name"] = "%s Ammo" % atype.capitalize()
			var added: int = min(remaining, cap - current)
			existing["ammo_amount"] = current + added
			existing["name"] = "%s x%d" % [existing["base_name"], current + added]
			remaining -= added
	if remaining <= 0:
		return true
	# Didn't fully fit - hand back what's left instead of letting it just
	# vanish. The caller (add_loot()/_add_to_stash()) treats a false
	# return as "couldn't merge" and spills item into a fresh stack, same
	# as grenades already do; item now correctly holds only the leftover.
	item["ammo_amount"] = remaining
	return false

# Total rounds of `ammo_type` currently sitting in the Backpack - this
# IS the reserve ammo number now, not a separate hidden counter.
#
# Checks carried_loot (found/looted so far THIS raid) and
# backpack_storage (ammo you deliberately loaded in before deploying) -
# deliberately NOT stash_items, since the design is that Backpack
# Storage is what you actually bring with you; ammo left sitting in
# the main Stash grid doesn't count until it's moved into Backpack
# Storage first. (An earlier version of this also counted stash_items,
# which was more lenient but blurred that distinction - reverted per
# explicit direction.) Originally this only checked carried_loot, which
# is empty at the moment a raid is chosen (nothing seeds it pre-raid)
# and only ever gains anything from in-raid pickups - meaning the
# pre-raid "no ammo" gate in MapSelect.gd was structurally unable to
# ever pass, blocking every player regardless of what they owned.
# backpack_storage is untouched by end_run()'s death/loss cleanup
# (unlike equipped_items), so counting it here doesn't put it at any
# more risk than it already was sitting there between raids.
func get_backpack_ammo_amount(ammo_type: String) -> int:
	var total := 0
	for item in carried_loot:
		if item.get("consumable_type", "") == "ammo" and item.get("ammo_type", "") == ammo_type:
			total += int(item.get("ammo_amount", 0))
	for item in backpack_storage:
		if item.get("consumable_type", "") == "ammo" and item.get("ammo_type", "") == ammo_type:
			total += int(item.get("ammo_amount", 0))
	return total

# Deducts up to `amount` rounds of `ammo_type` from Backpack ammo stacks
# (used by reload) - removes a stack entirely once it hits 0. Returns
# how much was actually available/deducted, which may be less than asked.
# Drains carried_loot first (already "in hand" from this raid), then
# backpack_storage - see get_backpack_ammo_amount() above for why
# stash_items is deliberately excluded.
func consume_backpack_ammo(ammo_type: String, amount: int) -> int:
	var remaining := amount
	for pool in [carried_loot, backpack_storage]:
		var i := 0
		while i < pool.size() and remaining > 0:
			var item: Dictionary = pool[i]
			if item.get("consumable_type", "") == "ammo" and item.get("ammo_type", "") == ammo_type:
				var have: int = int(item.get("ammo_amount", 0))
				var taken: int = min(have, remaining)
				remaining -= taken
				var left: int = have - taken
				if left <= 0:
					pool.remove_at(i)
					continue
				item["ammo_amount"] = left
				item["name"] = "%s x%d" % [item.get("base_name", "%s Ammo" % ammo_type.capitalize()), left]
			i += 1
		if remaining <= 0:
			break
	return amount - remaining

# Which weapon family each weapon type draws from - pistols and Thorns
# run on the same light rounds, rifles/shotguns share medium, and the
# heavy hitters (sniper, railgun, flamethrower, Alpha Cannon) all pull
# from the same heavy reserve. Keeps 3 ammo types meaningful instead of
# needing one per weapon family. Individual weapon items can still
# override this with their own "ammo_type" field (see
# get_ammo_type_for_weapon_item) - this table is just the fallback.
const WEAPON_AMMO_TYPE := {
	"pistol": "light", "thorn": "light", "sword": "light",
	"rifle": "medium", "shotgun": "medium",
	"sniper": "heavy", "railgun": "heavy", "flamethrower": "heavy", "alpha_cannon": "heavy",
}

func get_ammo_type_for_weapon(weapon_icon: String) -> String:
	return WEAPON_AMMO_TYPE.get(weapon_icon, "light")

# Prefers an explicit per-weapon "ammo_type" field (so a specific unique
# weapon item could one day diverge from its family) and falls back to
# the family-wide WEAPON_AMMO_TYPE lookup for the vast majority of items
# that don't set one.
func get_ammo_type_for_weapon_item(weapon_item) -> String:
	if weapon_item != null and weapon_item.has("ammo_type"):
		return weapon_item["ammo_type"]
	var icon: String = weapon_item.get("icon_key", "pistol") if weapon_item != null else "pistol"
	return get_ammo_type_for_weapon(icon)

# --- Plushie: a universal drop from any enemy, on any map. Its own
# rarity is purely cosmetic (a colored border in the Stash) - it does
# NOT affect the pet rarity Rose gives back for one, that's a fully
# separate roll (see PLUSHIE_PET_RARITY_WEIGHTS below). Its only real
# purpose is Rose in the Hideout: hand her one and she'll turn it into
# a real pet with the Plushie buff. Slot "plushie" is its own thing
# (not "valuable"/"consumable") so it's trivial to check for and
# consume specifically. Capped at Legendary - a stuffed toy standing
# out with a nicer color is enough, it shouldn't read as build-defining
# loot the way a Multiversal weapon would.
const PLUSHIE_ITEM_RARITY_WEIGHTS := {
	"common": 50.0, "uncommon": 25.0, "rare": 15.0, "epic": 7.0, "legendary": 3.0,
}

func _roll_plushie_item_rarity() -> String:
	var total := 0.0
	for w in PLUSHIE_ITEM_RARITY_WEIGHTS.values():
		total += float(w)
	var roll := randf() * total
	var cumulative := 0.0
	for rarity in PLUSHIE_ITEM_RARITY_WEIGHTS:
		cumulative += float(PLUSHIE_ITEM_RARITY_WEIGHTS[rarity])
		if roll <= cumulative:
			return rarity
	return "common"

func roll_plushie() -> Dictionary:
	return {
		"name": "Plushie", "value": 35, "slot": "plushie", "stat_type": "",
		"stat_value": 0.0, "icon_key": "plushie", "rarity": _roll_plushie_item_rarity(),
		"desc": "A soft, slightly-worn stuffed toy - somebody's favorite, once. Rose would probably know what to do with this.",
	}

func roll_consumable() -> Dictionary:
	return CONSUMABLE_POOL[randi() % CONSUMABLE_POOL.size()].duplicate(true)

# Consumables currently in the Backpack, with their carried_loot index -
# shared by Hotbar.gd (for display) and Player.gd (for use-on-click).
func get_consumable_entries() -> Array:
	var entries := []
	for i in range(carried_loot.size()):
		var item = carried_loot[i]
		if item.get("slot", "") == "consumable":
			entries.append({"index": i, "item": item})
	return entries

# --- Weapon attachments: scope/mag/barrel/grip/laser. Not equipped through
# the normal 6-slot system - they nest inside the currently equipped
# weapon's own "attachments" dictionary, managed via a dedicated panel
# (the "Attachments" button next to the Weapon slot).
const ATTACHMENT_POOL := [
	{"name": "Precision Scope", "value": 60, "slot": "attachment", "attachment_slot": "scope", "stat_type": "damage", "stat_value": 4.0, "icon_key": "scope", "rarity": "uncommon", "enables_zoom": true},
	{"name": "Red Dot Sight", "value": 40, "slot": "attachment", "attachment_slot": "scope", "stat_type": "damage", "stat_value": 2.0, "icon_key": "scope", "rarity": "common", "enables_zoom": false},
	{"name": "Extended Mag", "value": 45, "slot": "attachment", "attachment_slot": "mag", "stat_type": "fire_rate", "stat_value": 0.02, "icon_key": "mag", "rarity": "common"},
	{"name": "Heavy Barrel", "value": 50, "slot": "attachment", "attachment_slot": "barrel", "stat_type": "damage", "stat_value": 3.0, "icon_key": "barrel", "rarity": "uncommon"},
	{"name": "Tactical Grip", "value": 35, "slot": "attachment", "attachment_slot": "grip", "stat_type": "speed", "stat_value": 5.0, "icon_key": "grip", "rarity": "common"},
	{"name": "Laser Sight", "value": 30, "slot": "attachment", "attachment_slot": "laser", "stat_type": "damage", "stat_value": 1.5, "icon_key": "laser", "rarity": "common"},
]
const ATTACHMENT_SLOTS := ["scope", "mag", "barrel", "grip", "laser"]

func roll_attachment() -> Dictionary:
	return ATTACHMENT_POOL[randi() % ATTACHMENT_POOL.size()].duplicate(true)

# Returns (and lazily creates) the attachments dictionary living on the
# currently equipped weapon. Empty dict if no weapon is equipped.
# Returns (and lazily creates) the attachments dictionary living on the
# given weapon item - works for a weapon anywhere (equipped, carried, or
# in the Stash), not just the one on your character doll.
func get_weapon_attachments_for(weapon_item: Dictionary) -> Dictionary:
	if not weapon_item.has("attachments"):
		var fresh := {}
		for s in ATTACHMENT_SLOTS:
			fresh[s] = null
		weapon_item["attachments"] = fresh
	return weapon_item["attachments"]

func install_attachment_on_item(weapon_item: Dictionary, source_array: Array, attachment_index: int, is_carried: bool) -> bool:
	if attachment_index < 0 or attachment_index >= source_array.size():
		return false
	var item: Dictionary = source_array[attachment_index]
	if item.get("slot", "") != "attachment":
		return false
	var att_slot: String = item.get("attachment_slot", "")
	var attachments := get_weapon_attachments_for(weapon_item)
	if not attachments.has(att_slot):
		return false
	var current = attachments[att_slot]
	source_array.remove_at(attachment_index)
	if is_carried:
		carried_value -= int(item.get("value", 0))
	if current != null:
		var cell := _next_free_cell_in(source_array, is_carried)
		current["grid_x"] = cell.x
		current["grid_y"] = cell.y
		source_array.append(current)
		if is_carried:
			carried_value += int(current.get("value", 0))
	attachments[att_slot] = item
	equipped_changed.emit()
	toast_requested.emit("Installed %s" % item.get("name", "Attachment"))
	notify_event("equip_attachment")
	return true

func remove_attachment_from_item(weapon_item: Dictionary, att_slot: String, dest_array: Array, is_carried: bool) -> bool:
	var attachments := get_weapon_attachments_for(weapon_item)
	var current = attachments.get(att_slot)
	if current == null:
		return false
	attachments[att_slot] = null
	var cell := _next_free_cell_in(dest_array, is_carried)
	current["grid_x"] = cell.x
	current["grid_y"] = cell.y
	dest_array.append(current)
	if is_carried:
		carried_value += int(current.get("value", 0))
	equipped_changed.emit()
	return true

# Removes and returns a carried item (used when consuming a hotbar item).
func consume_carried_item(index: int) -> Dictionary:
	if index < 0 or index >= carried_loot.size():
		return {}
	var item: Dictionary = carried_loot[index]
	var stack: int = int(item.get("stack_count", 1))
	if stack > 1:
		item["stack_count"] = stack - 1
		item["name"] = "%s x%d" % [item.get("base_name", item.get("name", "Item")), stack - 1]
		return item.duplicate(true)
	carried_loot.remove_at(index)
	carried_value -= int(item.get("value", 0))
	return item

# --- Blueprints: a rare (5%) drop from enemies, or occasionally found in
# containers. They're not equippable - they sit in the Stash/Backpack with
# slot "blueprint" until researched at Lil Dirty's bench in the Hideout,
# which consumes the blueprint and grants the mythic item it unlocks.
const BLUEPRINT_RESULTS := [
	{"name": "Widowmaker", "value": 500, "slot": "weapon", "stat_type": "damage", "stat_value": 43.2, "icon_key": "rifle", "rarity": "mythic"},
	{"name": "Aegis Plate", "value": 500, "slot": "body", "stat_type": "max_health", "stat_value": 81.0, "icon_key": "chestplate", "rarity": "mythic"},
	{"name": "Phantom Visor", "value": 450, "slot": "head", "stat_type": "max_health", "stat_value": 74.2, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Ghostwalker Boots", "value": 400, "slot": "boots", "stat_type": "speed", "stat_value": 60.8, "icon_key": "boots", "rarity": "mythic"},
	{"name": "Cataclysm", "value": 520, "slot": "weapon", "stat_type": "damage", "stat_value": 34.0, "icon_key": "sniper", "rarity": "mythic"},
	{"name": "Sentinel's Ward", "value": 480, "slot": "body", "stat_type": "max_health", "stat_value": 58.0, "icon_key": "chestplate", "rarity": "mythic"},
	{"name": "Oracle Crown", "value": 440, "slot": "head", "stat_type": "max_health", "stat_value": 52.0, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Quicksilver Treads", "value": 410, "slot": "boots", "stat_type": "speed", "stat_value": 48.0, "icon_key": "boots", "rarity": "mythic"},
	{"name": "Titan's Grip", "value": 430, "slot": "accessory", "stat_type": "fire_rate", "stat_value": 0.05, "icon_key": "ring", "rarity": "mythic"},
	{"name": "Reaper's Cloak", "value": 460, "slot": "backpack", "stat_type": "max_health", "stat_value": 50.0, "icon_key": "backpack", "rarity": "mythic"},
]

# --- Loot Bags: a rare (20%) bonus roll from any enemy or container. Not a
# separate item to search again - it just dumps a big bonus bundle
# straight into the loot: ~2 Mythic/Legendary gear pieces, plus a hefty
# chunk of every currency.
const LOOT_BAG_GEAR_POOL := [
	{"name": "Widowmaker", "value": 500, "slot": "weapon", "stat_type": "damage", "stat_value": 43.2, "icon_key": "rifle", "rarity": "mythic"},
	{"name": "Aegis Plate", "value": 500, "slot": "body", "stat_type": "max_health", "stat_value": 81.0, "icon_key": "chestplate", "rarity": "mythic"},
	{"name": "Phantom Visor", "value": 450, "slot": "head", "stat_type": "max_health", "stat_value": 74.2, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Ghostwalker Boots", "value": 400, "slot": "boots", "stat_type": "speed", "stat_value": 60.8, "icon_key": "boots", "rarity": "mythic"},
	{"name": "Ironclad Bulwark", "value": 480, "slot": "body", "stat_type": "max_health", "stat_value": 78.3, "icon_key": "chestplate", "rarity": "mythic"},
	{"name": "Sentinel's Crown", "value": 460, "slot": "head", "stat_type": "max_health", "stat_value": 70.2, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Quickstep Boots", "value": 420, "slot": "boots", "stat_type": "speed", "stat_value": 56.7, "icon_key": "boots", "rarity": "mythic"},
	{"name": "Executioner's Mark", "value": 510, "slot": "weapon", "stat_type": "damage", "stat_value": 44.6, "icon_key": "sniper", "rarity": "mythic"},
	{"name": "Warlord's Greatcoat", "value": 320, "slot": "body", "stat_type": "max_health", "stat_value": 60.8, "icon_key": "chestplate", "rarity": "legendary"},
	{"name": "Deathmark Rifle", "value": 300, "slot": "weapon", "stat_type": "damage", "stat_value": 29.7, "icon_key": "rifle", "rarity": "legendary"},
	{"name": "Nightfall Cloak", "value": 280, "slot": "accessory", "stat_type": "speed", "stat_value": 40.5, "icon_key": "watch", "rarity": "legendary"},
	{"name": "Juggernaut Helm", "value": 300, "slot": "head", "stat_type": "max_health", "stat_value": 54.0, "icon_key": "helmet", "rarity": "legendary"},
	{"name": "Reaper's Embrace", "value": 310, "slot": "weapon", "stat_type": "damage", "stat_value": 31.1, "icon_key": "sniper", "rarity": "legendary"},
	{"name": "Bastion Vest", "value": 290, "slot": "body", "stat_type": "max_health", "stat_value": 56.7, "icon_key": "chestplate", "rarity": "legendary"},
	{"name": "Hunter's Cloak", "value": 270, "slot": "accessory", "stat_type": "speed", "stat_value": 37.8, "icon_key": "watch", "rarity": "legendary"},
	{"name": "Marauder's Boots", "value": 260, "slot": "boots", "stat_type": "speed", "stat_value": 43.2, "icon_key": "boots", "rarity": "legendary"},
	{"name": "Hellfire Reaper", "value": 330, "slot": "weapon", "stat_type": "damage", "stat_value": 32.4, "icon_key": "flamethrower", "rarity": "legendary"},
	{"name": "Venomfang", "value": 320, "slot": "weapon", "stat_type": "damage", "stat_value": 31.1, "icon_key": "thorn", "rarity": "legendary"},
	{"name": "Ionstorm", "value": 300, "slot": "weapon", "stat_type": "damage", "stat_value": 29.7, "icon_key": "railgun", "rarity": "legendary"},
	{"name": "Prism Reaver", "value": 800, "slot": "weapon", "stat_type": "damage", "stat_value": 54.0, "icon_key": "sniper", "rarity": "exotic"},
	{"name": "Voidwalker's Cloak", "value": 750, "slot": "accessory", "stat_type": "speed", "stat_value": 67.5, "icon_key": "watch", "rarity": "exotic"},
	{"name": "Eclipse Ward", "value": 780, "slot": "body", "stat_type": "max_health", "stat_value": 91.8, "icon_key": "chestplate", "rarity": "exotic"},
	{"name": "Void-Touched Helm", "value": 760, "slot": "head", "stat_type": "max_health", "stat_value": 86.4, "icon_key": "helmet", "rarity": "exotic"},
	{"name": "Starfall Treads", "value": 740, "slot": "boots", "stat_type": "speed", "stat_value": 74.2, "icon_key": "boots", "rarity": "exotic"},
	{"name": "Wraithbone Helm", "value": 480, "slot": "head", "stat_type": "max_health", "stat_value": 78.3, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Riot Carapace", "value": 420, "slot": "body", "stat_type": "armor", "stat_value": 18.0, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Bastion Plate", "value": 620, "slot": "body", "stat_type": "armor", "stat_value": 26.0, "icon_key": "chestplate", "rarity": "legendary"},
	{"name": "Aegis Faceguard", "value": 400, "slot": "head", "stat_type": "armor", "stat_value": 14.0, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Quartermaster's Rig", "value": 380, "slot": "backpack", "stat_type": "ammo_reserve", "stat_value": 60.0, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Logistics Pack", "value": 560, "slot": "backpack", "stat_type": "ammo_reserve", "stat_value": 90.0, "icon_key": "backpack", "rarity": "legendary"},
	{"name": "Bandolier Rig", "value": 340, "slot": "accessory", "stat_type": "ammo_reserve", "stat_value": 45.0, "icon_key": "ring", "rarity": "rare"},
]

const LOOT_BAG_TIERS := {
	"common": {"name": "Loot Bag", "rarity": "common", "value": 50},
	"rare": {"name": "Sturdy Loot Bag", "rarity": "rare", "value": 90},
	"epic": {"name": "Armored Loot Bag", "rarity": "epic", "value": 120},
	"legendary": {"name": "Reinforced Loot Bag", "rarity": "legendary", "value": 160},
	"mythic": {"name": "Gilded Loot Bag", "rarity": "mythic", "value": 260},
	"exotic": {"name": "Prismatic Loot Bag", "rarity": "exotic", "value": 420},
	"alpha": {"name": "Exclusive Alpha Chest", "rarity": "multiversal", "value": 2000},
}

# Loot bags get their own color language instead of borrowing the generic
# gear-rarity colors: the common/rare bags are just a plain sackcloth
# brown (two shades) since a "Common Loot Bag" being pale grey never
# actually read as a bag - it's legendary and up where the real rarity
# colors (and, for mythic/exotic/multiversal, the shimmering gradient
# border) kick in and it starts looking like something worth grabbing.
const LOOTBAG_BROWN_COMMON := Color(0.42, 0.3, 0.18, 1)
const LOOTBAG_BROWN_RARE := Color(0.55, 0.38, 0.2, 1)

func get_lootbag_color(rarity: String) -> Color:
	match rarity:
		"common":
			return LOOTBAG_BROWN_COMMON
		"rare":
			return LOOTBAG_BROWN_RARE
		_:
			return get_rarity_color(rarity)

func make_loot_bag(tier: String = "common") -> Dictionary:
	var data: Dictionary = LOOT_BAG_TIERS.get(tier, LOOT_BAG_TIERS["common"])
	return {
		"name": data["name"], "value": data["value"], "slot": "lootbag", "stat_type": "", "stat_value": 0.0,
		"icon_key": "lootbag", "rarity": data["rarity"], "bag_tier": tier,
	}

# Weighted pick for a "natural" loot bag find (containers, etc.) - mostly
# Common, but with a real shot at something better.
func roll_loot_bag_tier() -> String:
	var roll := randf()
	if roll < 0.03:
		return "exotic"
	elif roll < 0.1:
		return "mythic"
	elif roll < 0.25:
		return "legendary"
	elif roll < 0.55:
		return "rare"
	return "common"

func roll_loot_bag_contents(bag_tier: String = "common") -> Dictionary:
	var count := 2
	var currency_mult := 1.0
	match bag_tier:
		"alpha":
			count = 20
			currency_mult = 15.0
		"rare":
			count = 2
			currency_mult = 1.6
		"epic":
			count = 2
			currency_mult = 2.0
		"legendary":
			count = 3
			currency_mult = 2.5
		"mythic":
			count = 3
			currency_mult = 4.0
		"exotic":
			count = 4
			currency_mult = 7.0
	var items: Array = []
	for i in range(count):
		items.append(_roll_weighted_loot_bag_item(bag_tier))
	# Higher-tier bags have a shot at a bonus egg on top of the usual gear.
	var egg_chance: float = {"common": 0.0, "rare": 0.05, "epic": 0.08, "legendary": 0.12, "mythic": 0.2, "exotic": 0.3, "alpha": 0.9}.get(bag_tier, 0.0)
	if randf() < egg_chance:
		var bag_egg := roll_pet_egg_drop(1.0)
		if not bag_egg.is_empty():
			items.append(bag_egg)
	var currency: Dictionary = {}
	for cur in ["rubles", "junk", "artifacts", "alloys"]:
		currency[cur] = int(randi_range(30, 50) * currency_mult)
	return {"items": items, "currency": currency}

# Loot Bags favor good gear but aren't guaranteed top-tier every time -
# a real spread from common all the way up to Exotic, case-opening style.
func _roll_weighted_loot_bag_item(bag_tier: String = "common") -> Dictionary:
	var roll := randf()
	var tier := ""
	match bag_tier:
		"alpha":
			tier = "multiversal" if roll < 0.35 else "exotic"
		"exotic":
			tier = "exotic" if roll < 0.55 else "mythic"
		"mythic":
			if roll < 0.3:
				tier = "exotic"
			elif roll < 0.85:
				tier = "mythic"
			else:
				tier = "legendary"
		"legendary":
			if roll < 0.08:
				tier = "mythic"
			elif roll < 0.6:
				tier = "legendary"
			else:
				tier = "epic"
		"rare":
			if roll < 0.08:
				tier = "legendary"
			elif roll < 0.4:
				tier = "epic"
			else:
				tier = "rare"
		"epic":
			if roll < 0.05:
				tier = "mythic"
			elif roll < 0.3:
				tier = "legendary"
			elif roll < 0.75:
				tier = "epic"
			else:
				tier = "rare"
		_:
			if roll < 0.04:
				tier = "exotic"
			elif roll < 0.14:
				tier = "mythic"
			elif roll < 0.34:
				tier = "legendary"
			elif roll < 0.64:
				tier = "epic"
			elif roll < 0.85:
				tier = "rare"
			else:
				tier = "common_uncommon"

	var pool: Array = []
	if tier == "common_uncommon":
		# Ammo is common/uncommon-tier loot itself, so give bags a real
		# chance at it here instead of only ever handing back gear.
		if randf() < 0.35:
			return roll_ammo()
		for pool_item in ENEMY_LOOT_POOL:
			if pool_item.get("rarity", "") in ["common", "uncommon"]:
				pool.append(pool_item)
	elif tier == "multiversal":
		pool = MULTIVERSAL_ITEM_POOL.duplicate()
	else:
		for pool_item in LOOT_BAG_GEAR_POOL:
			if pool_item.get("rarity", "") == tier:
				pool.append(pool_item)
		if pool.is_empty():
			for pool_item in ENEMY_LOOT_POOL:
				if pool_item.get("rarity", "") == tier:
					pool.append(pool_item)

	if pool.is_empty():
		return roll_enemy_loot()
	return finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))

# The Loot Bag itself is just a normal item (like a key) until opened -
# the contents are only rolled at open time, CS:GO-case style.
func roll_loot_bag_item() -> Dictionary:
	return make_loot_bag(roll_loot_bag_tier())

# Returns how many items didn't fit and had to fall back to Vicinity,
# so the panel that revealed this bag can say so accurately instead of
# always claiming full success into the Backpack.
func _collect_bag_contents(contents: Dictionary, into_stash: bool) -> int:
	var overflow := 0
	for item in contents.get("items", []):
		if into_stash:
			_add_to_stash(item)
		elif not add_loot(item):
			# Every other loot source falls back to the uncapped Vicinity
			# staging area when the Backpack is full - a Loot Bag opened
			# mid-raid used to be the one path that just discarded whatever
			# didn't fit while still reporting full success.
			add_to_vicinity(item)
			overflow += 1
	for cur in contents.get("currency", {}):
		add_currency(cur, int(contents["currency"][cur]))
	return overflow

func open_carried_loot_bag(index: int) -> Dictionary:
	if index < 0 or index >= carried_loot.size() or carried_loot[index].get("slot", "") != "lootbag":
		return {}
	var bag_tier: String = carried_loot[index].get("bag_tier", "common")
	carried_loot.remove_at(index)
	var contents := roll_loot_bag_contents(bag_tier)
	contents["overflow_count"] = _collect_bag_contents(contents, false)
	notify_event("open_loot_bag")
	return contents

func open_stash_loot_bag(index: int) -> Dictionary:
	if index < 0 or index >= stash_items.size() or stash_items[index].get("slot", "") != "lootbag":
		return {}
	var bag_tier: String = stash_items[index].get("bag_tier", "common")
	stash_items.remove_at(index)
	var contents := roll_loot_bag_contents(bag_tier)
	contents["overflow_count"] = _collect_bag_contents(contents, true)
	notify_event("open_loot_bag")
	return contents

func open_vicinity_loot_bag(index: int) -> Dictionary:
	if index < 0 or index >= vicinity_items.size() or vicinity_items[index].get("slot", "") != "lootbag":
		return {}
	var bag_tier: String = vicinity_items[index].get("bag_tier", "common")
	vicinity_items.remove_at(index)
	_reindex_vicinity()
	var contents := roll_loot_bag_contents(bag_tier)
	contents["overflow_count"] = _collect_bag_contents(contents, false)
	vicinity_changed.emit()
	notify_event("open_loot_bag")
	return contents

const CASE_ITEM_DATA := {
	"medical": {"name": "Medical Case", "value": 180, "desc": "A dedicated case for medical supplies. Opening it clears space in your Stash for good - every bandage and MRE gets its own home from here on."},
	"gun": {"name": "Gun Case", "value": 220, "desc": "A padded case built for weapons. Opening it clears space in your Stash for good - every gun gets its own home from here on."},
	"armor": {"name": "Armor Case", "value": 200, "desc": "A reinforced case for protective gear. Opening it clears space in your Stash for good - every helmet, plate, and boot gets its own home from here on."},
	"key": {"name": "Key Case", "value": 160, "desc": "A small case built to keep keys from getting lost in the shuffle. Opening it clears space in your Stash for good - every key gets its own home from here on."},
}

# Empty once all 4 are unlocked - nothing left to roll.
func roll_specialized_case() -> Dictionary:
	var missing: Array = []
	for case_type in CASE_TYPES:
		if not unlocked_cases.get(case_type, false):
			missing.append(case_type)
	if missing.is_empty():
		return {}
	var case_type: String = missing[randi() % missing.size()]
	var data: Dictionary = CASE_ITEM_DATA[case_type]
	return {
		"name": data["name"], "value": data["value"], "slot": case_type + "_case",
		"icon_key": "pet_case", "rarity": "epic", "desc": data["desc"],
	}

func roll_blueprint() -> Dictionary:
	var result: Dictionary = BLUEPRINT_RESULTS[randi() % BLUEPRINT_RESULTS.size()]
	return {
		"name": "Blueprint: %s" % result["name"],
		"value": 150,
		"slot": "blueprint",
		"icon_key": "blueprint",
		"rarity": "epic",
		"blueprint_result": result.duplicate(true),
	}

# Called by Lil Dirty's research panel (works off the Stash - out of run).
func research_blueprint(stash_index: int) -> bool:
	if stash_index < 0 or stash_index >= stash_items.size():
		return false
	var bp: Dictionary = stash_items[stash_index]
	if bp.get("slot", "") != "blueprint":
		return false
	var result: Dictionary = bp.get("blueprint_result", {})
	if result.is_empty():
		return false
	stash_items.remove_at(stash_index)
	_add_to_stash(finalize_rolled_item(result.duplicate(true)))
	stat_blueprints_researched += 1
	toast_requested.emit("Researched %s!" % result.get("name", "Mythic Item"))
	notify_event("research_blueprint")
	return true

# --- Hideout Workbench: craft consumables/gear from Valuables found out
# in the sector. Materials are matched by item name against the Stash.
const CRAFTING_RECIPES := [
	{"id": "bandage", "name": "Bandage", "materials": {"Cloth": 2, "Antiseptic": 1},
		"result": {"name": "Field Bandage", "value": 20, "slot": "consumable", "stat_type": "", "stat_value": 0.0, "icon_key": "medkit", "rarity": "common", "consumable_type": "heal", "heal_amount": 35.0}},
	{"id": "trauma_kit", "name": "Trauma Kit", "materials": {"Cloth": 3, "Antiseptic": 2, "Paracord": 1},
		"result": {"name": "Trauma Kit", "value": 45, "slot": "consumable", "stat_type": "", "stat_value": 0.0, "icon_key": "medkit", "rarity": "uncommon", "consumable_type": "heal", "heal_amount": 60.0}},
	{"id": "frag_grenade", "name": "Frag Grenade", "materials": {"Duct Tape": 2, "Screws": 2},
		"result": {"name": "Frag Grenade", "value": 30, "slot": "consumable", "stat_type": "", "stat_value": 0.0, "icon_key": "grenade", "rarity": "uncommon", "consumable_type": "grenade", "grenade_type": "frag", "grenade_damage": 55, "grenade_radius": 95.0}},
	{"id": "smoke_grenade", "name": "Smoke Grenade", "materials": {"Cloth": 3, "Paracord": 1},
		"result": {"name": "Smoke Grenade", "value": 25, "slot": "consumable", "stat_type": "", "stat_value": 0.0, "icon_key": "smoke_grenade", "rarity": "common", "consumable_type": "grenade", "grenade_type": "smoke"}},
	{"id": "molotov", "name": "Molotov", "materials": {"Chlorine": 1, "Cloth": 2, "Duct Tape": 1},
		"result": {"name": "Molotov", "value": 35, "slot": "consumable", "stat_type": "", "stat_value": 0.0, "icon_key": "molotov", "rarity": "uncommon", "consumable_type": "grenade", "grenade_type": "molotov"}},
	{"id": "stun_grenade", "name": "Stun Grenade", "materials": {"Batteries": 2, "Screws": 2},
		"result": {"name": "Stun Grenade", "value": 35, "slot": "consumable", "stat_type": "", "stat_value": 0.0, "icon_key": "stun_grenade", "rarity": "uncommon", "consumable_type": "grenade", "grenade_type": "stun"}},
	{"id": "reinforced_vest", "name": "Reinforced Vest", "materials": {"Hard Plate": 2, "Cloth": 2},
		"result": {"name": "Crafted Vest", "value": 90, "slot": "body", "stat_type": "max_health", "stat_value": 22.0, "icon_key": "chestplate", "rarity": "uncommon"}},
	{"id": "scrap_smg", "name": "Scrap SMG", "materials": {"Screws": 4, "Duct Tape": 2},
		"result": {"name": "Scrap SMG", "value": 100, "slot": "weapon", "stat_type": "damage", "stat_value": 13.0, "icon_key": "rifle", "rarity": "uncommon"}},
	{"id": "scrap_sniper", "name": "Scrap Sniper", "materials": {"Screws": 5, "Duct Tape": 3, "Hard Plate": 1},
		"result": {"name": "Scrap Sniper", "value": 135, "slot": "weapon", "stat_type": "damage", "stat_value": 17.0, "icon_key": "sniper", "rarity": "rare"}},
	{"id": "utility_belt", "name": "Utility Belt", "materials": {"Duct Tape": 2, "Paracord": 2},
		"result": {"name": "Utility Belt", "value": 70, "slot": "accessory", "stat_type": "speed", "stat_value": 16.0, "icon_key": "ring", "rarity": "uncommon"}},
	{"id": "makeshift_helmet", "name": "Makeshift Helmet", "materials": {"Hard Plate": 2, "Duct Tape": 1},
		"result": {"name": "Makeshift Helmet", "value": 65, "slot": "head", "stat_type": "max_health", "stat_value": 17.0, "icon_key": "helmet", "rarity": "uncommon"}},
	{"id": "scavenger_boots", "name": "Scavenger Boots", "materials": {"Cloth": 2, "Duct Tape": 2},
		"result": {"name": "Scavenger Boots", "value": 55, "slot": "boots", "stat_type": "speed", "stat_value": 18.0, "icon_key": "boots", "rarity": "uncommon"}},
	{"id": "reinforced_backpack", "name": "Reinforced Backpack", "materials": {"Cloth": 3, "Hard Plate": 1, "Duct Tape": 2},
		"result": {"name": "Reinforced Backpack", "value": 80, "slot": "backpack", "stat_type": "max_health", "stat_value": 20.0, "icon_key": "backpack", "rarity": "uncommon"}},
	{"id": "crafted_gas_mask", "name": "Crafted Gas Mask", "materials": {"Military Filter": 1, "Cloth": 2, "Duct Tape": 1},
		"result": {"name": "Crafted Gas Mask", "value": 60, "slot": "head", "stat_type": "max_health", "stat_value": 6.0, "icon_key": "gas_mask", "rarity": "uncommon", "grants_radiation_immunity": true}},
]

# --- The Barterer: trades items for other, better items - no currency
# involved. "give" lists item names -> counts needed; "receive" is the
# item you get back.
const BARTER_RECIPES := [
	{"id": "gpcoin_to_btc", "name": "GPCoin -> BTC Voucher", "give": {"GPCoin": 5},
		"receive": {"name": "BTC Voucher", "value": 900, "slot": "valuable", "stat_type": "", "stat_value": 0.0, "icon_key": "gpcoin", "rarity": "epic"}},
	{"id": "batteries_to_filter", "name": "Batteries -> Military Filter", "give": {"Batteries": 5},
		"receive": {"name": "Military Filter", "value": 60, "slot": "valuable", "stat_type": "", "stat_value": 0.0, "icon_key": "mil_filter", "rarity": "rare"}},
	{"id": "scraps_to_plate", "name": "Screws + Duct Tape -> Hard Plate", "give": {"Screws": 3, "Duct Tape": 3},
		"receive": {"name": "Hard Plate", "value": 55, "slot": "valuable", "stat_type": "", "stat_value": 0.0, "icon_key": "hard_plate", "rarity": "uncommon"}},
	{"id": "bundle_to_vest", "name": "Salvage Bundle -> Barterer's Vest", "give": {"Hard Plate": 2, "Cloth": 2, "Antiseptic": 1},
		"receive": {"name": "Barterer's Vest", "value": 140, "slot": "body", "stat_type": "max_health", "stat_value": 32.0, "icon_key": "chestplate", "rarity": "rare"}},
]

func find_barter_recipe(recipe_id: String) -> Dictionary:
	for r in BARTER_RECIPES:
		if r.get("id", "") == recipe_id:
			return r
	return {}

func can_barter(recipe_id: String) -> bool:
	var recipe := find_barter_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var give: Dictionary = recipe["give"]
	for item_name in give.keys():
		if count_stash_material(item_name) < int(give[item_name]):
			return false
	return true

func do_barter(recipe_id: String) -> bool:
	var recipe := find_barter_recipe(recipe_id)
	if recipe.is_empty() or not can_barter(recipe_id):
		return false
	var give: Dictionary = recipe["give"]
	for item_name in give.keys():
		var needed: int = int(give[item_name])
		var removed := 0
		var i := stash_items.size() - 1
		while i >= 0 and removed < needed:
			if stash_items[i].get("name", "") == item_name:
				stash_items.remove_at(i)
				removed += 1
			i -= 1
	_add_to_stash(finalize_rolled_item(recipe["receive"].duplicate(true)))
	toast_requested.emit("Bartered for %s!" % recipe["receive"].get("name", "Item"))
	return true

func count_stash_material(mat_name: String) -> int:
	var count := 0
	for item in stash_items:
		if item.get("name", "") == mat_name:
			count += 1
	return count

func find_recipe(recipe_id: String) -> Dictionary:
	for r in CRAFTING_RECIPES:
		if r.get("id", "") == recipe_id:
			return r
	return {}

func can_craft(recipe_id: String) -> bool:
	var recipe := find_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var materials: Dictionary = recipe["materials"]
	for mat_name in materials.keys():
		if count_stash_material(mat_name) < int(materials[mat_name]):
			return false
	return true

func craft_item(recipe_id: String) -> bool:
	var recipe := find_recipe(recipe_id)
	if recipe.is_empty() or not can_craft(recipe_id):
		return false
	var materials: Dictionary = recipe["materials"]
	for mat_name in materials.keys():
		var needed: int = int(materials[mat_name])
		var removed := 0
		var i := stash_items.size() - 1
		while i >= 0 and removed < needed:
			if stash_items[i].get("name", "") == mat_name:
				stash_items.remove_at(i)
				removed += 1
			i -= 1
	_add_to_stash(finalize_rolled_item(recipe["result"].duplicate(true)))
	toast_requested.emit("Crafted %s!" % recipe.get("name", "Item"))
	if recipe_id == "bandage":
		notify_event("craft_bandage")
	return true

# --- Bitcoin Farm: a real-time idle system in the Hideout. Insert a
# Graphics Card into a GPU slot and it mines for 2 real hours (tracked by
# wall-clock time, so it keeps going even with the game closed), then can
# be claimed for a big Ruble payout.
const BITCOIN_SLOT_COUNT := 4
const BITCOIN_MINE_DURATION := 7200.0
const BITCOIN_REWARD := 50000
var bitcoin_gpu_slots: Array = [null, null, null, null]

func count_carried_graphics_cards() -> int:
	var count := 0
	for item in stash_items:
		if item.get("name", "") == "Graphics Card":
			count += 1
	return count

func insert_graphics_card(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= bitcoin_gpu_slots.size():
		return false
	if bitcoin_gpu_slots[slot_index] != null:
		return false
	var idx := -1
	for i in range(stash_items.size()):
		if stash_items[i].get("name", "") == "Graphics Card":
			idx = i
			break
	if idx == -1:
		toast_requested.emit("No Graphics Card in your Stash")
		return false
	stash_items.remove_at(idx)
	bitcoin_gpu_slots[slot_index] = {"start_time": Time.get_unix_time_from_system()}
	toast_requested.emit("GPU installed - mining started.")
	save_game()
	return true

func get_gpu_progress(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= bitcoin_gpu_slots.size():
		return 0.0
	var slot = bitcoin_gpu_slots[slot_index]
	if slot == null:
		return 0.0
	var elapsed: float = Time.get_unix_time_from_system() - float(slot.get("start_time", 0.0))
	return clamp(elapsed / BITCOIN_MINE_DURATION, 0.0, 1.0)

func claim_gpu(slot_index: int) -> bool:
	if get_gpu_progress(slot_index) < 1.0:
		return false
	bitcoin_gpu_slots[slot_index] = null
	add_currency("rubles", BITCOIN_REWARD)
	toast_requested.emit("Claimed %d Rubles from the mining rig!" % BITCOIN_REWARD)
	save_game()
	return true

# --- Quest chain: one active quest at a time. Each has a single trigger
# event (fired from wherever that thing actually happens in the game -
# Hideout, a Trader, a Door, an Enemy death, or a successful extraction).
# Completing the trigger just marks it "ready" - the player still has to
# open the Quests panel and turn it in before the next one unlocks.
const QUEST_ORDER := [
	"meet_lil_dirty", "talk_to_recruits", "kill_first_enemy", "scrap_item", "unlock_door", "find_midnight_bones",
	"bring_recruit_raid",
	"sneak_kill", "night_extract", "kill_spike", "research_blueprint",
	"low_hp_extract", "ashen_house_power", "pay_car_extract",
	"equip_attachment", "grenade_kill", "deliver_batteries", "craft_bandage",
	"open_loot_bag", "find_lake", "find_screws_mechanic", "open_gas_station",
	"journey_to_boneclock", "find_gas_station", "kill_a_ghost", "find_skeleton_cave",
	"kill_rattles", "earn_500_souls", "survive_wave_20_commune", "play_bloodline_event", "decipher_engram_justin",
	"extract_5000_loot",
	"find_wandering_ghost", "extract_with_ghost",
	"echo_return_favor", "echo_final_test",
	"warden_gauntlet", "warden_encore",
	"tinkerer_hatchery", "tinkerer_masterwork",
	"cartographer_void", "cartographer_bigscore",
	"reaper_ascension", "reaper_finale",
]
const QUEST_NPC_CATALOG := {
	"echo": {"name": "Echo", "title": "The Guide", "glow_color": Color(0.6, 0.3, 0.85, 1), "blurb": "The one who's been here longest. Nobody's sure if he's helping you or just watching to see what happens."},
	"warden": {"name": "Warden", "title": "Combat Contracts", "glow_color": Color(0.85, 0.2, 0.2, 1), "blurb": "Doesn't care about your reasons. Only cares if you can fight."},
	"tinkerer": {"name": "Sprocket", "title": "Salvage & Repairs", "glow_color": Color(0.2, 0.75, 0.55, 1), "blurb": "Half machine, half grudge against everything that's ever broken on her."},
	"cartographer": {"name": "Atlas", "title": "Exploration", "glow_color": Color(0.85, 0.65, 0.2, 1), "blurb": "Maps the Sector one dead operative's route at a time. Efficient, if grim."},
	"reaper": {"name": "Reaper", "title": "Deep Contracts", "glow_color": Color(0.7, 0.1, 0.35, 1), "blurb": "Only shows up once you've survived long enough to be worth talking to."},
}

const QUEST_DATA := {
	"meet_lil_dirty": {"title": "A New Contact", "desc": "Go meet Lil Dirty in the Hideout.", "trigger": "meet_lil_dirty", "reward_text": "125 Rubles", "reward": {"rubles": 125}, "icon": "contact", "npc": "echo", "lore": "Lil Dirty's been running scrap deals out of the Hideout longer than anyone can remember. He doesn't trust new faces - so go prove you're not another ghost passing through."},
	"kill_first_enemy": {"title": "First Blood", "desc": "Kill your first enemy.", "trigger": "kill_enemy", "reward_text": "150 Rubles", "reward": {"rubles": 150}, "icon": "combat", "npc": "echo", "lore": "Everyone remembers their first kill in the Sector. Not fondly - just clearly. It's the moment the place stops being a rumor and starts being real."},
	"scrap_item": {"title": "Waste Not", "desc": "Scrap an item at the Scrapper.", "trigger": "scrap_item", "reward_text": "200 Rubles", "reward": {"rubles": 200}, "icon": "gear", "npc": "echo", "lore": "The Scrapper doesn't care what it used to be. Bring it in, break it down, and it becomes something useful again. Nothing goes to waste out here - not even you, eventually."},
	"unlock_door": {"title": "Breaking In", "desc": "Unlock a door using a key.", "trigger": "unlock_door", "reward_text": "250 Rubles", "reward": {"rubles": 250}, "icon": "key", "npc": "echo", "lore": "Locked doors in the Sector usually mean someone thought what's behind them was worth protecting. Sometimes they were right."},
	"talk_to_recruits": {"title": "New Faces", "desc": "Talk to the recruits in the Hideout.", "trigger": "talk_to_recruits", "reward_text": "200 Rubles", "reward": {"rubles": 200}, "icon": "recruits", "npc": "echo", "lore": "The recruits watch every new operative the same way: waiting to see if you're worth following into the Sector, or another name they'll have to remember for the wrong reasons."},
	"find_midnight_bones": {"title": "Something in the Dark", "desc": "Find and talk to Midnight Bones somewhere in Boneclock, during a Night Raid.", "trigger": "find_midnight_bones", "reward_text": "300 Rubles (Graveyard Key handed over on the spot)", "reward": {"rubles": 300}, "icon": "key", "npc": "echo", "lore": "Echo won't say much about him - just that he's real, he's out there at night, and he's been waiting on someone to finally show up worth talking to."},
	"bring_recruit_raid": {"title": "Bring Backup", "desc": "Bring a Recruit into a raid with you.", "trigger": "bring_recruit_raid", "reward_text": "375 Rubles + Ranger Pack", "reward": {"rubles": 375, "gear": {"name": "Ranger Pack", "value": 75, "slot": "backpack", "stat_type": "fire_rate", "stat_value": 0.0, "icon_key": "backpack", "rarity": "uncommon"}}, "icon": "squad", "npc": "warden", "lore": "A recruit at your back doubles your odds and halves your loot. Most operatives decide that's a trade worth making, at least once."},
	"sneak_kill": {"title": "Ghost Protocol", "desc": "Kill an enemy while hiding in a bush.", "trigger": "sneak_kill", "reward_text": "300 Rubles", "reward": {"rubles": 300}, "icon": "stealth", "npc": "warden", "lore": "The bushes don't hide you from everything out here - but they hide you from enough. Patience kills more raiders than bullets ever will."},
	"night_extract": {"title": "Into the Dark", "desc": "Successfully extract from a Night Raid.", "trigger": "night_extract", "reward_text": "375 Rubles + Combat Boots", "reward": {"rubles": 375, "gear": {"name": "Combat Boots", "value": 70, "slot": "boots", "stat_type": "speed", "stat_value": 20.0, "icon_key": "boots", "rarity": "uncommon"}}, "icon": "vehicle", "npc": "warden", "lore": "Night raids pay better because almost nobody survives them clean. The Sector doesn't get quieter after dark. It just gets harder to see what's coming."},
	"kill_spike": {"title": "The Big One", "desc": "Kill Spike.", "trigger": "kill_spike", "reward_text": "750 Rubles + Reinforced Plate", "reward": {"rubles": 750, "gear": {"name": "Reinforced Plate", "value": 120, "slot": "body", "stat_type": "max_health", "stat_value": 28.0, "icon_key": "chestplate", "rarity": "rare"}}, "icon": "spike_crown", "npc": "warden", "lore": "Spike used to be a person, allegedly. Whatever's left of that is buried somewhere under all that scar tissue and rage. Good luck finding it before he finds you."},
	"research_blueprint": {"title": "Mad Science", "desc": "Research a blueprint with Lil Dirty.", "trigger": "research_blueprint", "reward_text": "440 Rubles", "reward": {"rubles": 440}, "icon": "tech", "npc": "tinkerer", "lore": "Somewhere in the ruins, someone was still designing things right up until the day they weren't. Their notes are still worth something, if you can read past the bloodstains."},
	"low_hp_extract": {"title": "Cutting It Close", "desc": "Successfully extract while under 50 HP.", "trigger": "low_hp_extract", "reward_text": "500 Rubles", "reward": {"rubles": 500}, "icon": "medical", "npc": "cartographer", "lore": "Making it to extraction with nothing left in the tank is either the smartest call you'll make all raid, or the last one."},
	"ashen_house_power": {"title": "Lights On", "desc": "Turn on the power for the Ashen House.", "trigger": "ashen_house_power", "reward_text": "375 Rubles", "reward": {"rubles": 375}, "icon": "tech", "npc": "tinkerer", "lore": "Somewhere in Overgrowth, a house still has power running to it. That shouldn't be possible anymore. Go find out why it still is."},
	"pay_car_extract": {"title": "Priority Pickup", "desc": "Pay the car driver 2000 Rubles to extract.", "trigger": "pay_car_extract", "reward_text": "450 Rubles", "reward": {"rubles": 450}, "icon": "vehicle", "npc": "cartographer", "lore": "Some extractions have a toll. Pay it, or don't - but the car doesn't wait for operatives who hesitate."},
	"equip_attachment": {"title": "Modded Out", "desc": "Equip a weapon attachment.", "trigger": "equip_attachment", "reward_text": "350 Rubles", "reward": {"rubles": 350}, "icon": "gear", "npc": "tinkerer", "lore": "A gun is a promise. An attachment is you making sure it keeps it."},
	"grenade_kill": {"title": "Fire in the Hole", "desc": "Kill an enemy with a grenade.", "trigger": "grenade_kill", "reward_text": "550 Rubles + 300 Heavy Ammo", "reward": {"rubles": 550, "ammo": {"type": "heavy", "amount": 300}}, "icon": "combat", "npc": "warden", "lore": "Subtlety has its place. This isn't it. Sometimes the fastest way through a room is to not leave much of the room standing."},
	"deliver_batteries": {"title": "Power Supply", "desc": "Deliver 2 Batteries to the Scrapper.", "trigger": "deliver_batteries", "reward_text": "400 Rubles", "reward": {"rubles": 400}, "icon": "tech", "npc": "tinkerer", "lore": "The Scrapper's been running half his rig on hope and spare parts. A couple batteries won't fix everything he's short on, but it'll buy you some goodwill."},
	"craft_bandage": {"title": "Field Medicine", "desc": "Craft a Bandage at the Workbench.", "trigger": "craft_bandage", "reward_text": "375 Rubles", "reward": {"rubles": 375}, "icon": "medical", "npc": "tinkerer", "lore": "You learn fast that the Sector doesn't wait for you to patch yourself up. Better to already know how before you need to."},
	"open_loot_bag": {"title": "Jackpot", "desc": "Open a Loot Bag.", "trigger": "open_loot_bag", "reward_text": "875 Rubles + Vanguard Helmet", "reward": {"rubles": 875, "gear": {"name": "Vanguard Helmet", "value": 125, "slot": "head", "stat_type": "max_health", "stat_value": 30.0, "icon_key": "helmet", "rarity": "rare"}}, "icon": "money", "npc": "cartographer", "lore": "Loot bags are a gamble dressed up as a reward. Sometimes it's junk. Sometimes it's the thing that changes your whole run."},
	"find_lake": {"title": "Uncharted Waters", "desc": "Find the lake somewhere out in the sector.", "trigger": "find_lake", "reward_text": "400 Rubles", "reward": {"rubles": 400}, "icon": "compass", "npc": "cartographer", "lore": "Charts of the Sector are mostly guesswork stitched together from operatives who made it back. Add the lake to the map. Someone else will need it."},
	"find_screws_mechanic": {"title": "Spare Parts", "desc": "Find Screws near the Mechanic Shop.", "trigger": "find_screws_mechanic", "reward_text": "350 Rubles", "reward": {"rubles": 350}, "icon": "gear", "npc": "tinkerer", "lore": "The Mechanic doesn't ask where the parts come from. She just asks if there's more where that came from."},
	"open_gas_station": {"title": "Fill 'Er Up", "desc": "Open the Gas Station in Boneclock.", "trigger": "open_gas_station", "reward_text": "500 Rubles", "reward": {"rubles": 500}, "icon": "key", "npc": "cartographer", "lore": "Fuel's a currency out here same as rubles. A working pump is worth defending - or worth being the first to find."},
	"journey_to_boneclock": {"title": "Journey to Boneclock", "desc": "Deploy into the Boneclock sector.", "trigger": "journey_to_boneclock", "reward_text": "300 Rubles", "reward": {"rubles": 300}, "icon": "skull", "npc": "cartographer", "lore": "Boneclock wasn't always called that. Nobody agrees on when it changed, only that it did, and that whatever did it is still down there."},
	"find_gas_station": {"title": "Fumes on the Wind", "desc": "Find the Gas Station in Boneclock.", "trigger": "find_gas_station", "reward_text": "325 Rubles", "reward": {"rubles": 325}, "icon": "compass", "npc": "cartographer", "lore": "Fumes on the wind usually mean something's still burning that shouldn't be. Follow it and find out what."},
	"kill_a_ghost": {"title": "Exorcism", "desc": "Kill a Ghost.", "trigger": "kill_a_ghost", "reward_text": "450 Rubles", "reward": {"rubles": 450}, "icon": "ghost_kill", "npc": "reaper", "lore": "Ghosts in Boneclock aren't metaphors. They're just what's left of people who didn't make it, still walking the same streets they died on."},
	"find_skeleton_cave": {"title": "Into the Dark Earth", "desc": "Find the Skeleton Cave in Boneclock.", "trigger": "find_skeleton_cave", "reward_text": "550 Rubles", "reward": {"rubles": 550}, "icon": "skull", "npc": "cartographer", "lore": "Some caves collapse. This one didn't - it just filled up with the people who couldn't get out in time, and whatever's left of them now."},
	"kill_rattles": {"title": "Silence the Bones", "desc": "Kill Rattles at the Bone Clocktower.", "trigger": "kill_rattles", "reward_text": "1250 Rubles", "reward": {"rubles": 1250}, "icon": "bone_crown", "npc": "reaper", "lore": "Rattles doesn't chase you. It doesn't have to. It just waits for the clock to run out, and in Boneclock, it always does."},
	"earn_500_souls": {"title": "Soul Collector", "desc": "Earn 500 Souls total.", "trigger": "earn_500_souls", "reward_text": "750 Rubles", "reward": {"rubles": 750}, "icon": "soul_wisp", "npc": "reaper", "lore": "Souls don't spend like rubles, but out here they're worth more. Everyone's trying to collect enough of them to matter."},
	"survive_wave_20_commune": {"title": "Favored by the Harvester", "desc": "Survive to Wave 20 in Commune.", "trigger": "survive_wave_20_commune", "reward_text": "1500 Rubles", "reward": {"rubles": 1500}, "icon": "harvester", "npc": "reaper", "lore": "The Commune doesn't stop sending things at you. Surviving twenty waves isn't a victory. It's just proof you haven't lost yet."},
	"play_bloodline_event": {"title": "Into the Refuge", "desc": "Enter the Bloodline Gauntlet at least once.", "trigger": "play_bloodline_event", "reward_text": "625 Rubles", "reward": {"rubles": 625}, "icon": "refuge", "npc": "reaper", "lore": "The Refuge doesn't appear on any map Echo will show you. He knows exactly where it is. He just doesn't like talking about it."},
	"decipher_engram_justin": {"title": "Cracking the Code", "desc": "Decipher an Engram at Justin's Decompilation Rig.", "trigger": "decipher_engram_justin", "reward_text": "750 Rubles", "reward": {"rubles": 750}, "icon": "cipher", "npc": "reaper", "lore": "Justin's spent years trying to read what the engrams are actually saying. Every one you bring him gets him a little closer to an answer he's not sure he wants."},
	"extract_5000_loot": {"title": "Big Score", "desc": "Extract with at least 5000 worth of loot.", "trigger": "extract_5000_loot", "reward_text": "1250 Rubles + Aegis Plate", "reward": {"rubles": 1250, "gear": {"name": "Aegis Plate", "value": 500, "slot": "body", "stat_type": "max_health", "stat_value": 60.0, "icon_key": "chestplate", "rarity": "mythic"}}, "icon": "money", "npc": "reaper", "lore": "Most operatives measure a good run in rubles. The really good ones measure it in how many trips it took to add up."},
	"find_wandering_ghost": {"title": "Find Ghost", "desc": "Find and interact with the Wandering Ghost during a raid.", "trigger": "find_wandering_ghost", "reward_text": "375 Rubles", "reward": {"rubles": 375}, "icon": "ghost_kill", "npc": "reaper", "lore": "Most ghosts in the Sector just drift and fade. This one's different - it stops. It looks at you. That's never happened before."},
	"extract_with_ghost": {"title": "Extract with Ghost", "desc": "Successfully extract from a raid with the Ghost following you.", "trigger": "extract_with_ghost", "reward_text": "550 Rubles", "reward": {"rubles": 550}, "icon": "ghost_kill", "npc": "reaper", "lore": "Whatever it is, it followed you all the way to extraction and didn't let go. Now it's not going back. Better clear it a room in the Hideout."},

	"echo_return_favor": {"title": "One Good Turn", "desc": "Scrap another item at the Scrapper - for Echo this time, not for scrap value.", "trigger": "scrap_item", "reward_text": "450 Rubles", "reward": {"rubles": 450}, "icon": "gear", "npc": "echo", "lore": "Echo doesn't need the scrap. He wants to see if you'll still do the small, unglamorous jobs now that he's not the only one who trusts you."},
	"echo_final_test": {"title": "Prove It Again", "desc": "Kill another enemy - the Sector doesn't grade on a curve, and neither does Echo.", "trigger": "kill_enemy", "reward_text": "625 Rubles + Ghost Cloak", "reward": {"rubles": 625, "gear": {"name": "Ghost Cloak", "value": 150, "slot": "body", "stat_type": "speed", "stat_value": 15.0, "icon_key": "chestplate", "rarity": "rare"}}, "icon": "combat", "npc": "echo", "lore": "\"First blood was luck,\" Echo says. \"Let's see if it still is.\" He's not being cruel. He's being honest, which out here is close enough."},

	"warden_gauntlet": {"title": "Refuge Cleanup", "desc": "Defeat a boss inside the Bloodline Gauntlet.", "trigger": "gauntlet_boss_kill", "reward_text": "1000 Rubles + Warlord Rig", "reward": {"rubles": 1000, "gear": {"name": "Warlord Rig", "value": 220, "slot": "body", "stat_type": "damage", "stat_value": 6.0, "icon_key": "chestplate", "rarity": "epic"}}, "icon": "spike_crown", "npc": "warden", "lore": "Warden doesn't care that the Refuge isn't technically the Sector. A kill's a kill. Bring back proof and he'll treat you like it counts, because to him it does."},
	"warden_encore": {"title": "Round Two", "desc": "Successfully extract from another Night Raid.", "trigger": "night_extract", "reward_text": "700 Rubles + Night Ops Boots", "reward": {"rubles": 700, "gear": {"name": "Night Ops Boots", "value": 160, "slot": "boots", "stat_type": "speed", "stat_value": 26.0, "icon_key": "boots", "rarity": "epic"}}, "icon": "vehicle", "npc": "warden", "lore": "Warden's theory is simple: anyone can get lucky once in the dark. Twice means you actually learned something. He wants to know which one you are."},

	"tinkerer_hatchery": {"title": "New Arrivals", "desc": "Hatch an Egg at Salvaged Beasts.", "trigger": "hatch_egg_salvaged_beasts", "reward_text": "550 Rubles", "reward": {"rubles": 550}, "icon": "tech", "npc": "tinkerer", "lore": "Sprocket insists the hatchery is \"just chemistry with legs.\" She still checks on every egg personally, which tells you everything about how convincing her own argument is."},
	"tinkerer_masterwork": {"title": "One More Blueprint", "desc": "Research another blueprint with Lil Dirty.", "trigger": "research_blueprint", "reward_text": "750 Rubles + Sprocket's Rig", "reward": {"rubles": 750, "gear": {"name": "Sprocket's Rig", "value": 240, "slot": "body", "stat_type": "max_health", "stat_value": 35.0, "icon_key": "chestplate", "rarity": "epic"}}, "icon": "tech", "npc": "tinkerer", "lore": "Sprocket hands over one of her own spare rigs without much ceremony. \"Don't get attached,\" she says, already attached to whatever she's building next."},

	"cartographer_void": {"title": "Into the Trench", "desc": "Deploy into the Void Trench sector.", "trigger": "journey_to_void_trench", "reward_text": "600 Rubles", "reward": {"rubles": 600}, "icon": "compass", "npc": "cartographer", "lore": "Atlas has a whole shelf of maps that just say \"the Trench\" with no further detail. She wants to know if that's because nobody's come back, or because nobody's bothered to write it down."},
	"cartographer_bigscore": {"title": "Chart the Riches", "desc": "Open another Loot Bag.", "trigger": "open_loot_bag", "reward_text": "875 Rubles + Surveyor's Coat", "reward": {"rubles": 875, "gear": {"name": "Surveyor's Coat", "value": 200, "slot": "body", "stat_type": "speed", "stat_value": 18.0, "icon_key": "chestplate", "rarity": "epic"}}, "icon": "money", "npc": "cartographer", "lore": "Atlas doesn't gamble, but she keeps meticulous odds on everyone else's loot bags. She wants your result for the ledger - the gear is just how she says thanks."},

	"reaper_ascension": {"title": "Silence Them Again", "desc": "Defeat Rattles once more, for Reaper's private tally.", "trigger": "kill_rattles", "reward_text": "2000 Rubles + Reaper's Mark", "reward": {"rubles": 2000, "gear": {"name": "Reaper's Mark", "value": 400, "slot": "head", "stat_type": "damage", "stat_value": 10.0, "icon_key": "helmet", "rarity": "legendary"}}, "icon": "bone_crown", "npc": "reaper", "lore": "Reaper doesn't celebrate. He just marks a tally somewhere nobody else can read and hands you something heavier than what you brought in with."},
	"reaper_finale": {"title": "The Long Watch", "desc": "Survive to Wave 20 in Commune again, to prove the first time wasn't luck.", "trigger": "survive_wave_20_commune", "reward_text": "2250 Rubles + Harvester's Aegis", "reward": {"rubles": 2250, "gear": {"name": "Harvester's Aegis", "value": 550, "slot": "body", "stat_type": "max_health", "stat_value": 70.0, "icon_key": "chestplate", "rarity": "mythic"}}, "icon": "harvester", "npc": "reaper", "lore": "\"The Commune doesn't remember who beat it once,\" Reaper says. \"It only remembers who's still standing.\" This is as close as he gets to a compliment."},
}

const MAX_ACTIVE_QUESTS := 3

# A few quest chains cross between NPCs - Reaper's line of work doesn't
# open up until you've proven yourself to Warden first. Anything not
# listed here just requires the previous quest in its own NPC's chain
# (computed from QUEST_ORDER + the "npc" field, see _quest_requires).
const QUEST_EXTRA_REQUIRES := {
	"kill_a_ghost": "kill_spike",
}

# quest_status[key] is "active" (accepted, not yet done), "ready"
# (objective met, awaiting turn-in), or "done". A key absent from this
# dict has never been accepted - it's either "available" (unlocked, can
# be accepted) or locked, both computed on demand rather than stored.
var quest_status: Dictionary = {}
# Tracked separately from "active" so a quest already turned in doesn't
# re-lock anything behind it if quest_status is ever cleared/migrated.
var quest_acknowledged_key: String = ""

func acknowledge_current_quest() -> void:
	pass # kept only so any stray old callers don't hard-crash; no longer needed - accepting a quest IS the acknowledgment now.

func is_quest_acknowledged(key: String) -> bool:
	return quest_status.get(key, "") == "active" or quest_status.get(key, "") == "ready"

# The ordered list of quests belonging to one NPC, in the same relative
# order they appear in QUEST_ORDER - this is what turns the single flat
# QUEST_ORDER array into 5 independent per-NPC chains.
func _npc_chain(npc_id: String) -> Array:
	var result: Array = []
	for key in QUEST_ORDER:
		if QUEST_DATA.get(key, {}).get("npc", "") == npc_id:
			result.append(key)
	return result

func _quest_requires(key: String) -> String:
	if QUEST_EXTRA_REQUIRES.has(key):
		return QUEST_EXTRA_REQUIRES[key]
	var npc: String = QUEST_DATA.get(key, {}).get("npc", "")
	var chain := _npc_chain(npc)
	var idx := chain.find(key)
	if idx <= 0:
		return ""
	return chain[idx - 1]

func is_quest_done(key: String) -> bool:
	return quest_status.get(key, "") == "done"

func quest_status_for(key: String) -> String:
	return quest_status.get(key, "")

func is_quest_locked(key: String) -> bool:
	if quest_status.has(key):
		return false
	var req := _quest_requires(key)
	return req != "" and not is_quest_done(req)

func is_quest_available(key: String) -> bool:
	return not quest_status.has(key) and not is_quest_locked(key)

func active_quest_count() -> int:
	var n := 0
	for key in quest_status:
		if quest_status[key] == "active" or quest_status[key] == "ready":
			n += 1
	return n

# Every quest currently occupying one of the player's 3 contract slots,
# in QUEST_ORDER order, regardless of which NPC it belongs to - what the
# in-raid HUD and the Character screen both want to show.
func active_quest_keys() -> Array:
	var result: Array = []
	for key in QUEST_ORDER:
		var status: String = quest_status.get(key, "")
		if status == "active" or status == "ready":
			result.append(key)
	return result

func accept_quest(key: String) -> bool:
	if not QUEST_DATA.has(key) or quest_status.has(key):
		return false
	if is_quest_locked(key):
		return false
	if active_quest_count() >= MAX_ACTIVE_QUESTS:
		toast_requested.emit("You're already tracking %d contracts - turn one in or abandon it first." % MAX_ACTIVE_QUESTS)
		return false
	quest_status[key] = "active"
	quest_state_changed.emit()
	quest_toast_requested.emit("Contract accepted: %s" % QUEST_DATA[key].get("title", key))
	# check_achievements() as a whole only runs from save_game() - without
	# this, "Full Docket" (hit 3 active contracts at once) could go
	# unnoticed for up to a minute (until the next autosave) instead of
	# unlocking the moment it's actually true, and would miss it entirely
	# if the 3rd contract was turned in/abandoned before that.
	_maybe_unlock("full_docket", active_quest_count() >= MAX_ACTIVE_QUESTS)
	return true

# Called from wherever an objective might just have happened. Checks it
# against every currently ACTIVE quest (not just one), so multiple
# accepted contracts can each track their own trigger independently.
func notify_event(event_key: String) -> void:
	var changed := false
	for key in quest_status.keys():
		if quest_status[key] != "active":
			continue
		if QUEST_DATA.get(key, {}).get("trigger", "") == event_key:
			quest_status[key] = "ready"
			var quest_title: String = QUEST_DATA[key].get("title", key)
			quest_toast_requested.emit("QUEST COMPLETE: %s" % quest_title)
			raid_quests_completed.append(quest_title)
			changed = true
	if changed:
		quest_state_changed.emit()

func turn_in_quest(key: String) -> bool:
	if quest_status.get(key, "") != "ready":
		return false
	var reward: Dictionary = QUEST_DATA.get(key, {}).get("reward", {})
	if reward.has("rubles"):
		add_currency("rubles", int(reward["rubles"]))
	if reward.has("gear"):
		_add_to_stash(reward["gear"].duplicate(true))
	if reward.has("ammo"):
		var ammo_spec: Dictionary = reward["ammo"]
		var atype: String = ammo_spec.get("type", "light")
		var amount: int = int(ammo_spec.get("amount", 100))
		var base: Dictionary = {}
		for pool_item in AMMO_POOL:
			if pool_item.get("ammo_type", "") == atype:
				base = pool_item.duplicate(true)
				break
		if base.is_empty():
			base = AMMO_POOL[0].duplicate(true)
		base["base_name"] = base["name"]
		base["ammo_amount"] = amount
		base["name"] = "%s x%d" % [base["base_name"], amount]
		_add_to_stash(base)
	quest_status[key] = "done"
	quest_state_changed.emit()
	grant_pet_xp(15)
	return true

# Drops a quest without granting its reward, freeing up a contract slot.
# Unlike the old single-chain version, this doesn't burn the quest
# forever - it just goes back to "available" so it can be re-accepted
# later if the player changes their mind.
func abandon_quest(key: String) -> bool:
	var current_status: String = quest_status.get(key, "")
	if current_status == "" or current_status == "done":
		# Erasing a completed quest would re-lock every later quest that
		# checks for it via is_quest_locked()/_quest_requires(). Not
		# reachable through the current UI (Abandon only shows for
		# active/ready quests), but guarding here regardless in case a
		# future caller reaches this directly.
		return false
	var title: String = QUEST_DATA.get(key, {}).get("title", "that contract")
	quest_status.erase(key)
	quest_state_changed.emit()
	toast_requested.emit("Abandoned: %s" % title)
	return true

func all_quests_done() -> bool:
	for key in QUEST_DATA.keys():
		if quest_status.get(key, "") != "done":
			return false
	return true

# Recruits are locked behind quest "talk_to_recruits": talking to them at
# the Hideout only works once that quest is unlocked (available, active,
# or done - i.e. no longer locked behind an earlier quest), and bringing
# one on a raid only works once it's actually done.
func recruits_hideout_unlocked() -> bool:
	return not is_quest_locked("talk_to_recruits")

func recruit_raid_unlocked() -> bool:
	return is_quest_done("talk_to_recruits")

# --- Corpse loot: rolled ONCE the moment an enemy dies and stored on its
# Corpse node, then handed to the player all at once when the body is
# searched (key, gear roll, rare blueprint roll, consumable roll, and -
# for the "Real Player" enemy variant - guaranteed Dog Tags).
func roll_corpse_loot(is_real_player: bool, key_id: String, key_label: String, loot_chance: float, is_boss: bool = false) -> Dictionary:
	var loot: Array = []
	var currency: Dictionary = {}
	if randf() < 0.5:
		currency["tickets"] = randi_range(1, 3)
	var pet_drop_chance: float = 0.05 if is_boss else 0.008
	if randf() < pet_drop_chance:
		var rare_pet_rarity: String = ["epic", "legendary", "mythic"][randi() % 3] if is_boss else ["rare", "epic", "legendary"][randi() % 3]
		var pet_instance_id := hatch_egg(rare_pet_rarity)
		var pet_data := get_pet_data(pet_instance_id)
		toast_requested.emit("A wild %s followed you home!" % pet_data.get("name", "creature"))
	if key_id != "":
		loot.append({
			"name": key_label, "value": 100, "slot": "key", "stat_type": "",
			"stat_value": 0.0, "icon_key": "key", "rarity": "rare", "door_key_id": key_id,
		})
	if randf() < loot_chance:
		loot.append(roll_enemy_loot())
	if randf() < 0.05:
		loot.append(roll_blueprint())
	if randf() < 0.5:
		loot.append(roll_attachment())
	if randf() < 0.5:
		loot.append(roll_ruble_item())
	if randf() < 0.25:
		loot.append(roll_consumable())
	# A generous, dedicated roll (not tied to the general consumable
	# chance above) so ammo actually shows up often enough to matter -
	# running completely dry mid-raid with no way to find more wasn't
	# fun for anyone.
	if randf() < 0.55:
		loot.append(roll_ammo())
	# Plushies: a common, universal drop from any enemy on any map -
	# their only purpose is handing one to Rose in the Hideout.
	if randf() < 0.45:
		loot.append(roll_plushie())
	# A deliberate exception to "no currency drops from enemies" above -
	# Skill Points are meant to show up all over the place (loot, mail,
	# Battle Pass, the free Starter Pack) rather than being gated behind
	# selling gear like Rubles are.
	if randf() < 0.06:
		add_currency("skill_points", 1)
	var egg := roll_pet_egg_drop(0.16)
	if not egg.is_empty():
		loot.append(egg)
	if randf() < 0.015:
		loot.append(make_pet_case())
	if is_real_player:
		loot.append({
			"name": "Dog Tags", "value": 300, "slot": "trophy", "stat_type": "",
			"stat_value": 0.0, "icon_key": "dogtag", "rarity": "rare",
		})
		# Real Players are geared up - a much bigger, more random haul than
		# a regular raider, plus a wad of every currency.
		for i in range(5):
			var roll := randf()
			if roll < 0.5:
				loot.append(roll_enemy_loot())
			elif roll < 0.75:
				loot.append(roll_attachment())
			elif roll < 0.9:
				loot.append(roll_consumable())
			else:
				loot.append(roll_blueprint())
		for cur in ["rubles", "junk", "artifacts", "alloys"]:
			currency[cur] = randi_range(5, 50)
	if randf() < 0.2:
		loot.append(roll_loot_bag_item())
	return {"items": loot, "currency": currency}

# --- Traders: each has its own currency for buying AND for what you get
# when selling gear to them. Catalog items are normally gear, but an item
# can instead have "grants_currency"/"grants_amount" (used by the Alloy
# Dealer) to sell a currency bundle instead of an equippable item.

var TRADER_CATALOG := {
	"medic": {
		"name": "Dr. Reyes - Medic",
		"icon_key": "medkit",
		"tagline": "Sells medical & survival gear",
		"currency": "rubles",
		"items": [
			{"name": "Combat Bandages", "cost": 40, "value": 40, "slot": "accessory", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "medkit", "rarity": "common"},
			{"name": "Adrenaline Shot", "cost": 70, "value": 70, "slot": "accessory", "stat_type": "speed", "stat_value": 20.2, "icon_key": "medkit", "rarity": "uncommon"},
			{"name": "Trauma Kit", "cost": 80, "value": 80, "slot": "body", "stat_type": "max_health", "stat_value": 27.0, "icon_key": "medkit", "rarity": "uncommon"},
			{"name": "Field Surgery Rig", "cost": 150, "value": 150, "slot": "body", "stat_type": "max_health", "stat_value": 47.2, "icon_key": "medkit", "rarity": "rare"},
			{"name": "IV Drip Rig", "cost": 65, "value": 65, "slot": "accessory", "stat_type": "health_regen", "stat_value": 0.4, "icon_key": "medkit", "rarity": "uncommon"},
			{"name": "Trauma Surgeon's Coat", "cost": 190, "value": 190, "slot": "body", "stat_type": "max_health", "stat_value": 56.7, "icon_key": "chestplate", "rarity": "rare"},
		],
	},
	"quartermaster": {
		"name": "Quartermaster",
		"icon_key": "pistol",
		"tagline": "Sells guns & armor",
		"currency": "rubles",
		"items": [
			{"name": "Sidearm", "cost": 60, "value": 60, "slot": "weapon", "stat_type": "damage", "stat_value": 8.1, "icon_key": "pistol", "rarity": "common"},
			{"name": "Combat Helmet Mk2", "cost": 100, "value": 100, "slot": "head", "stat_type": "max_health", "stat_value": 33.8, "icon_key": "helmet", "rarity": "uncommon"},
			{"name": "Marching Boots", "cost": 90, "value": 90, "slot": "boots", "stat_type": "speed", "stat_value": 29.7, "icon_key": "boots", "rarity": "uncommon"},
			{"name": "Tactical Rifle", "cost": 120, "value": 120, "slot": "weapon", "stat_type": "damage", "stat_value": 16.2, "icon_key": "rifle", "rarity": "rare"},
			{"name": "Longshot DMR", "cost": 160, "value": 160, "slot": "weapon", "stat_type": "damage", "stat_value": 32.4, "icon_key": "sniper", "rarity": "rare"},
			{"name": "Riot Armor", "cost": 130, "value": 130, "slot": "body", "stat_type": "max_health", "stat_value": 40.5, "icon_key": "chestplate", "rarity": "rare"},
			{"name": "Loot Bag", "cost": 50, "value": 50, "slot": "lootbag", "stat_type": "", "stat_value": 0.0, "icon_key": "lootbag", "rarity": "common", "bag_tier": "common"},
			{"name": "Sturdy Loot Bag", "cost": 90, "value": 90, "slot": "lootbag", "stat_type": "", "stat_value": 0.0, "icon_key": "lootbag", "rarity": "rare", "bag_tier": "rare"},
			{"name": "Armored Loot Bag", "cost": 120, "value": 120, "slot": "lootbag", "stat_type": "", "stat_value": 0.0, "icon_key": "lootbag", "rarity": "epic", "bag_tier": "epic"},
			{"name": "Reinforced Loot Bag", "cost": 160, "value": 160, "slot": "lootbag", "stat_type": "", "stat_value": 0.0, "icon_key": "lootbag", "rarity": "legendary", "bag_tier": "legendary"},
			{"name": "Gilded Loot Bag", "cost": 260, "value": 260, "slot": "lootbag", "stat_type": "", "stat_value": 0.0, "icon_key": "lootbag", "rarity": "mythic", "bag_tier": "mythic"},
			{"name": "Prismatic Loot Bag", "cost": 420, "value": 420, "slot": "lootbag", "stat_type": "", "stat_value": 0.0, "icon_key": "lootbag", "rarity": "exotic", "bag_tier": "exotic"},
			{"name": "Combat Visor", "cost": 75, "value": 75, "slot": "helmet_attachment", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "visor", "rarity": "uncommon"},
			{"name": "Squad Headset", "cost": 80, "value": 80, "slot": "helmet_attachment", "stat_type": "fire_rate", "stat_value": 0.0, "icon_key": "headset", "rarity": "uncommon"},
			{"name": "Issued Nightvision", "cost": 170, "value": 170, "slot": "helmet_attachment", "stat_type": "max_health", "stat_value": 8.1, "icon_key": "nightvision_goggles", "rarity": "rare", "grants_nightvision": true},
			{"name": "Combat Shotgun", "cost": 135, "value": 135, "slot": "weapon", "stat_type": "damage", "stat_value": 24.3, "icon_key": "shotgun", "rarity": "rare"},
			{"name": "Recon Pauldrons", "cost": 95, "value": 95, "slot": "accessory", "stat_type": "speed", "stat_value": 21.6, "icon_key": "ring", "rarity": "uncommon"},
		],
	},
	"scavenger": {
		"name": "The Scavenger",
		"icon_key": "grenade",
		"tagline": "Sells grenades, flares & ammo",
		"currency": "rubles",
		"items": [
			{"name": "Flare Kit", "cost": 50, "value": 50, "slot": "accessory", "stat_type": "speed", "stat_value": 13.5, "icon_key": "flare", "rarity": "common"},
			{"name": "Scavver's Pack", "cost": 85, "value": 85, "slot": "backpack", "stat_type": "max_health", "stat_value": 24.3, "icon_key": "backpack", "rarity": "uncommon"},
			{"name": "Frag Grenade Belt", "cost": 90, "value": 90, "slot": "accessory", "stat_type": "damage", "stat_value": 13.5, "icon_key": "grenade", "rarity": "uncommon"},
			{"name": "Smoke Canister Rig", "cost": 100, "value": 100, "slot": "accessory", "stat_type": "fire_rate", "stat_value": 0.0, "icon_key": "grenade", "rarity": "uncommon"},
			{"name": "Signal Flare Pack", "cost": 110, "value": 110, "slot": "accessory", "stat_type": "speed", "stat_value": 24.3, "icon_key": "flare", "rarity": "rare"},
			{"name": "Demolition Charge Belt", "cost": 140, "value": 140, "slot": "accessory", "stat_type": "damage", "stat_value": 18.9, "icon_key": "grenade", "rarity": "rare"},
			{"name": "Salvager's Satchel", "cost": 100, "value": 100, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
		] + SCAVENGER_AMMO_STOCK.duplicate(true),
	},
	"scrapper": {
		"name": "The Scrapper",
		"icon_key": "boots",
		"tagline": "Scraps your gear for Junk - sells rare finds",
		"currency": "junk",
		"items": [
			{"name": "Prototype Rifle", "cost": 150, "value": 200, "slot": "weapon", "stat_type": "damage", "stat_value": 29.7, "icon_key": "rifle", "rarity": "legendary"},
			{"name": "Nano-Weave Vest", "cost": 180, "value": 250, "slot": "body", "stat_type": "max_health", "stat_value": 60.8, "icon_key": "chestplate", "rarity": "legendary"},
			{"name": "War Crown", "cost": 220, "value": 300, "slot": "head", "stat_type": "max_health", "stat_value": 67.5, "icon_key": "helmet", "rarity": "mythic"},
			{"name": "Heart of the Sector", "cost": 260, "value": 350, "slot": "accessory", "stat_type": "speed", "stat_value": 54.0, "icon_key": "ring", "rarity": "mythic"},
		],
	},
	"alloy_dealer": {
		"name": "Alloy Dealer",
		"icon_key": "backpack",
		"tagline": "Sells Alloys for use at your Hideout",
		"currency": "rubles",
		"items": [
			{"name": "Alloy Bundle (Small)", "cost": 40, "grants_currency": "alloys", "grants_amount": 10, "icon_key": "backpack", "rarity": "common"},
			{"name": "Alloy Bundle (Medium)", "cost": 90, "grants_currency": "alloys", "grants_amount": 25, "icon_key": "backpack", "rarity": "uncommon"},
			{"name": "Alloy Bundle (Large)", "cost": 160, "grants_currency": "alloys", "grants_amount": 50, "icon_key": "backpack", "rarity": "rare"},
		],
	},
}

# Which trader the player picked, from the Traders hub, before opening TraderShop.
var current_trader_id: String = "medic"

# --- Trader stock rotation: every 10 minutes (real time, runs regardless
# of which screen you're on), the gear-selling traders swap in a fresh
# random selection. The Scrapper and Alloy Dealer keep their fixed
# specialty catalogs.
const TRADER_ROTATION_INTERVAL := 600.0
var _trader_rotation_timer: float = 0.0
signal traders_rotated

func get_trader_rotation_seconds_left() -> float:
	return max(0.0, TRADER_ROTATION_INTERVAL - _trader_rotation_timer)

func _rotate_traders() -> void:
	for trader_id in ["medic", "quartermaster", "scavenger"]:
		var trader: Dictionary = TRADER_CATALOG[trader_id]
		var count: int = trader["items"].size()
		# The Scavenger's static ammo stock (see SCAVENGER_AMMO_STOCK) is
		# re-appended below every rotation same as it is up front, so it
		# must NOT be counted toward how many random gear items get rolled
		# here - otherwise the reroll count would creep upward every cycle
		# as its own previous ammo entries got counted back in.
		if trader_id == "scavenger":
			count -= SCAVENGER_AMMO_STOCK.size()
		# Medic/Quartermaster have no guaranteed static ammo stock, so mix
		# ammo into their rotating pool too - ammo entries get rolled
		# through roll_ammo() below so they come out with a real
		# ammo_amount, not a bare stack. Scavenger skips this mix-in since
		# its ammo need is already covered by the guaranteed static stock.
		var pool: Array = ENEMY_LOOT_POOL.duplicate()
		if trader_id != "scavenger":
			pool.append_array(AMMO_POOL)
		pool.shuffle()
		var new_items: Array = []
		for i in range(count):
			var raw: Dictionary = pool[i % pool.size()]
			var pick: Dictionary
			if raw.get("consumable_type", "") == "ammo":
				pick = roll_ammo()
			else:
				pick = finalize_rolled_item(raw.duplicate(true))
			pick["cost"] = int(pick.get("value", 50))
			new_items.append(pick)
		if trader_id == "quartermaster":
			for bag_tier in LOOT_BAG_TIERS.keys():
				var bag := make_loot_bag(bag_tier)
				bag["cost"] = int(bag["value"])
				new_items.append(bag)
		elif trader_id == "scavenger":
			new_items.append_array(SCAVENGER_AMMO_STOCK.duplicate(true))
		trader["items"] = new_items
	_reroll_featured_skins()
	_roll_scav_loadout()
	_roll_pet_shop_stock()
	traders_rotated.emit()

# --- Pet Shop stock rotation: rotates on the same 10-minute cycle as
# Trader stock, showing a random subset of PET_CATALOG instead of every
# pet always being available - matches how the rest of the shops rotate
# rather than sitting static.
const PET_SHOP_STOCK_SIZE := 5
var pet_shop_stock: Array = []

func _roll_pet_shop_stock() -> void:
	var pool: Array = PET_CATALOG.keys()
	pool.shuffle()
	pet_shop_stock = pool.slice(0, min(PET_SHOP_STOCK_SIZE, pool.size()))

# --- Scav loadout: a free, no-strings-attached loadout for players who
# don't want to risk their real gear. Rotates on the same 10-minute
# cycle as Trader stock - always Common/Uncommon rarity, always a full
# kit (weapon, body, head, boots), and refreshed together so it feels
# like a believable "here's what's on hand right now" pool.
var scav_loadout: Dictionary = {}
var is_scav_run: bool = false
# Remembers which screen opened the Stash via Tab, so pressing Tab again
# from the Stash returns you there instead of always landing on the
# Main Menu - lets Tab work as a real toggle from anywhere it's used.
var stash_return_scene: String = "res://scenes/MainMenu.tscn"
# Remembers exactly where the player was standing in the Hideout so that
# tabbing into the Stash and back doesn't snap them back to the Hideout's
# fixed spawn point - the Hideout scene fully reloads on the way back,
# which would otherwise lose the player's in-scene position entirely.
var hideout_player_position: Vector2 = Vector2.ZERO
var hideout_position_saved: bool = false
var _saved_pmc_equipped: Dictionary = {}

func _roll_scav_loadout() -> void:
	var rarity_pool := ["common", "common", "uncommon"]
	var rarity: String = rarity_pool[randi() % rarity_pool.size()]
	var loadout := {}
	for slot in ["weapon", "body", "head", "boots"]:
		var pool: Array = ENEMY_LOOT_POOL.filter(func(i): return i.get("slot", "") == slot and i.get("rarity", "") == rarity)
		if pool.is_empty():
			pool = ENEMY_LOOT_POOL.filter(func(i): return i.get("slot", "") == slot)
		if not pool.is_empty():
			loadout[slot] = finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))
	scav_loadout = loadout

func start_scav_run() -> void:
	if scav_loadout.is_empty():
		_roll_scav_loadout()
	is_scav_run = true
	_saved_pmc_equipped = equipped_items.duplicate(true)
	for slot in scav_loadout:
		equipped_items[slot] = scav_loadout[slot].duplicate(true)
	# A Scav's real Backpack (carried_loot) might have none of whatever
	# ammo type this run's random weapon actually takes, so hand them a
	# modest starting supply of all three types - same as any other
	# backpack loot, it's kept on a successful extract and lost on
	# death, just like the rest of what they're carrying.
	for ammo_type in ["light", "medium", "heavy"]:
		add_loot({
			"name": "%s Ammo" % ammo_type.capitalize(), "value": 15, "slot": "ammo",
			"icon_key": "ammo_%s" % ammo_type, "rarity": get_ammo_rarity(ammo_type),
			"consumable_type": "ammo", "ammo_type": ammo_type, "ammo_amount": 60,
		})
	equipped_changed.emit()

func start_pmc_run() -> void:
	is_scav_run = false

# Called at the end of a raid (extract or death) to restore the real
# PMC loadout underneath a Scav run - the temporary Scav gear was never
# really "equipped" on the actual character.
func end_scav_run_if_active() -> void:
	if not is_scav_run:
		return
	is_scav_run = false
	equipped_items = _saved_pmc_equipped.duplicate(true)
	_saved_pmc_equipped = {}
	equipped_changed.emit()

# The Store's premium skin selection rotates on the exact same interval
# as trader stock, so it's one predictable "everything refreshes" beat.
var featured_premium_skins: Array = []

func _reroll_featured_skins() -> void:
	var pool: Array = []
	for weapon_type in ["pistol", "rifle", "sniper", "shotgun", "flamethrower", "thorn", "railgun"]:
		for skin in SKIN_CATALOG.get(weapon_type, []):
			if skin.has("premium_price"):
				pool.append({"id": skin.get("id", ""), "weapon_type": weapon_type})
	pool.shuffle()
	featured_premium_skins = pool.slice(0, min(6, pool.size()))
	toast_requested.emit("Trader stock has refreshed.")

func get_discounted_trader_cost(base_cost: int) -> int:
	var discount: float = clamp(get_upgrade_bonus("market_discount"), 0.0, 0.6)
	if player_trait == "silver_tongued":
		discount = clamp(discount + 0.1, 0.0, 0.6)
	return int(round(base_cost * (1.0 - discount)))

func buy_trader_item(trader_id: String, item_index: int) -> bool:
	if not TRADER_CATALOG.has(trader_id):
		return false
	var trader: Dictionary = TRADER_CATALOG[trader_id]
	var items: Array = trader["items"]
	if item_index < 0 or item_index >= items.size():
		return false
	var catalog_item: Dictionary = items[item_index]
	var cost := get_discounted_trader_cost(int(catalog_item.get("cost", 0)))
	var currency: String = trader.get("currency", "rubles")
	if not spend_currency(currency, cost):
		return false
	if catalog_item.has("grants_currency"):
		add_currency(catalog_item["grants_currency"], int(catalog_item.get("grants_amount", 0)))
	else:
		# Duplicate so each purchase is its own independent item, not a shared reference.
		var item: Dictionary = catalog_item.duplicate(true)
		_add_to_stash(item)
	return true

# Sells multiple Stash items at once for Rubles - the "Quick Sell"
# convenience option, so you don't have to walk to a Trader and sell
# them one at a time.
func quick_sell_items(indices: Array) -> int:
	var sorted_indices: Array = indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	var total := 0
	for idx in sorted_indices:
		if idx < 0 or idx >= stash_items.size():
			continue
		var item: Dictionary = stash_items[idx]
		var sale_value: int = int(round(float(item.get("value", 0)) * (1.0 + get_upgrade_bonus("currency_boost"))))
		total += sale_value
		stash_items.remove_at(idx)
	if total > 0:
		add_currency("rubles", total)
		stat_total_sold += total
		save_game()
	return total

func sell_item(trader_id: String, stash_index: int) -> bool:
	if stash_index < 0 or stash_index >= stash_items.size():
		return false
	var item: Dictionary = stash_items[stash_index]
	var currency := "rubles"
	if TRADER_CATALOG.has(trader_id):
		currency = TRADER_CATALOG[trader_id].get("currency", "rubles")
	var sale_value: int = int(item.get("value", 0))
	if currency == "rubles":
		sale_value = int(round(float(sale_value) * (1.0 + get_upgrade_bonus("currency_boost"))))
	add_currency(currency, sale_value)
	stat_total_sold += sale_value
	stash_items.remove_at(stash_index)
	if trader_id == "scrapper":
		notify_event("scrap_item")
	return true

# --- Skill Tree: permanent upgrades funded by Artifacts (found only in
# vault chests). "per_level" is added (or subtracted, for fire_rate) to the
# player's BASE stats, stacking with equipped-gear bonuses.
var upgrades: Dictionary = {
	"max_health": {"level": 0, "base_cost": 6, "cost_step": 4, "per_level": 10.0, "max_level": 10, "label": "Vitality", "desc": "+10 Max Health per level"},
	"speed": {"level": 0, "base_cost": 6, "cost_step": 4, "per_level": 8.0, "max_level": 10, "label": "Agility", "desc": "+8 Move Speed per level"},
	"damage": {"level": 0, "base_cost": 7, "cost_step": 5, "per_level": 2.0, "max_level": 10, "label": "Firepower", "desc": "+2 Bullet Damage per level"},
	"fire_rate": {"level": 0, "base_cost": 8, "cost_step": 5, "per_level": 0.02, "max_level": 10, "label": "Trigger Speed", "desc": "-0.02s Shot Cooldown per level"},
	"stash_grid": {"level": 0, "base_cost": 10, "cost_step": 8, "per_level": 2, "max_level": 10, "label": "Stash Expansion", "desc": "+2 rows of Stash (and Backpack) space per level"},
	"vision_range": {"level": 0, "base_cost": 8, "cost_step": 5, "per_level": 40.0, "max_level": 10, "label": "Night Vision", "desc": "+40 Flashlight range per level"},
	"health_regen": {"level": 0, "base_cost": 9, "cost_step": 6, "per_level": 0.4, "max_level": 10, "label": "Regeneration", "desc": "+0.4 HP/sec regen per level"},
	"reload_speed": {"level": 0, "base_cost": 8, "cost_step": 5, "per_level": 0.08, "max_level": 10, "label": "Quick Hands", "desc": "-0.08s Reload Time per level"},
	"loot_sense": {"level": 0, "base_cost": 9, "cost_step": 6, "per_level": 0.03, "max_level": 10, "label": "Loot Sense", "desc": "+3% Gear Drop Chance per level"},
	"search_speed": {"level": 0, "base_cost": 8, "cost_step": 5, "per_level": 0.1, "max_level": 10, "label": "Quick Search", "desc": "-0.1s Search Time per level"},
	"grenade_power": {"level": 0, "base_cost": 9, "cost_step": 6, "per_level": 6.0, "max_level": 10, "label": "Demolitions", "desc": "+6 Grenade Damage per level"},
	"ammo_reserve": {"level": 0, "base_cost": 7, "cost_step": 4, "per_level": 15, "max_level": 10, "label": "Pack Mule", "desc": "+15 Reserve Ammo per level"},
	"xp_boost": {"level": 0, "base_cost": 10, "cost_step": 7, "per_level": 0.05, "max_level": 10, "label": "Fast Learner", "desc": "+5% XP earned per level"},
	"currency_boost": {"level": 0, "base_cost": 10, "cost_step": 7, "per_level": 0.05, "max_level": 10, "label": "Haggler", "desc": "+5% Ruble sell value per level"},
	"extraction_speed": {"level": 0, "base_cost": 9, "cost_step": 6, "per_level": 0.3, "max_level": 10, "label": "Fast Hands", "desc": "-0.3s Extraction Time per level"},
	"crit_chance": {"level": 0, "base_cost": 9, "cost_step": 6, "per_level": 0.04, "max_level": 10, "label": "Precision", "desc": "+4% chance to deal 1.5x damage per level"},
	"backpack_rows": {"level": 0, "base_cost": 12, "cost_step": 9, "per_level": 1, "max_level": 10, "label": "Extra Pockets", "desc": "+1 row of Backpack space per level"},
	"stealth": {"level": 0, "base_cost": 9, "cost_step": 6, "per_level": 15.0, "max_level": 10, "label": "Silent Step", "desc": "-15 Enemy Detection Range per level"},
	"melee_damage": {"level": 0, "base_cost": 7, "cost_step": 5, "per_level": 3.0, "max_level": 10, "label": "Brawler", "desc": "+3 Melee Damage per level"},
	"market_discount": {"level": 0, "base_cost": 10, "cost_step": 7, "per_level": 0.02, "max_level": 10, "label": "Silver Tongue", "desc": "-2% Trader Prices per level"},
	"pet_bond": {"level": 0, "base_cost": 10, "cost_step": 7, "per_level": 0.04, "max_level": 10, "label": "Companion Bond", "desc": "+4% Equipped Pet bonus per level"},
}

# Enemies get tougher as you invest more into the Skill Tree, so a
# fully-decked-out late-game build doesn't trivialize every fight now
# that upgrades go all the way to level 10. Scales off total levels
# purchased across every skill, not player level, since that's the
# actual source of the extra power.
# --- Wandering Trader: a rare in-raid NPC (Overgrowth only, 50% chance
# to appear) who deals exclusively in Blossoms - the currency you collect
# from the little blue plants scattered around the map. Stock is the
# best gear in the game: Legendary through Multiversal.
func roll_wandering_trader_stock(count: int = 6) -> Array:
	var pool: Array = []
	for pool_item in LOOT_BAG_GEAR_POOL:
		if pool_item.get("rarity", "") in ["legendary", "mythic", "exotic"]:
			pool.append(pool_item)
	for pool_item in MULTIVERSAL_ITEM_POOL:
		pool.append(pool_item)
	pool.shuffle()
	var stock: Array = []
	for i in range(min(count, pool.size())):
		var item: Dictionary = finalize_rolled_item(pool[i].duplicate(true))
		# Blossoms only come from 6 plants scattered on Overgrowth (3 each,
		# 18/raid at best) - these multipliers used to be 8/14/22/40, which
		# priced the cheapest Legendary at 2000+ Blossoms (100+ flawless
		# raids) and the cheapest Multiversal at 180,000+ (10,000+ raids),
		# making the whole shop unusable. Tuned instead so Legendary is a
		# real short-term goal, Multiversal a real but achievable long-term
		# one - not monotonic with rarity because "value" itself already
		# scales steeply per tier, so a flatter multiplier is what keeps
		# the final Blossom cost increasing sensibly tier to tier.
		var rarity_mult := {"legendary": 0.4, "mythic": 0.9, "exotic": 1.3, "multiversal": 0.55}
		item["cost"] = int(item.get("value", 100) * rarity_mult.get(item.get("rarity", "legendary"), 0.5))
		stock.append(item)
	return stock

func buy_from_wandering_trader(stock: Array, index: int) -> bool:
	if index < 0 or index >= stock.size():
		return false
	var item: Dictionary = stock[index]
	var cost: int = int(item.get("cost", 0))
	if is_carried_full():
		toast_requested.emit("Backpack is full")
		return false
	if not spend_currency("blossoms", cost):
		return false
	stock.remove_at(index)
	var bought: Dictionary = item.duplicate(true)
	var cell := _next_free_cell_in(carried_loot)
	bought["grid_x"] = cell.x
	bought["grid_y"] = cell.y
	carried_loot.append(bought)
	carried_value += int(bought.get("value", 0))
	toast_requested.emit("Bought %s!" % bought.get("name", "Item"))
	return true

# --- Data / Codex: enemy bestiary (locked until you've killed one),
# collectible reference, and a map overview. All shown on the "Data"
# Main Menu screen.
const ENEMY_CATALOG := {
	"raider": {"name": "Raider", "icon_key": "raider_icon", "desc": "A scavenger fighting for the same loot you are. Armed and unpredictable."},
	"real_player": {"name": "Rogue Operator", "icon_key": "dogtag", "desc": "Another PMC gone hostile. Tougher and faster than a normal raider, and drops far better loot."},
	"skeleton": {"name": "Skeleton", "icon_key": "sword", "desc": "Boneclock's signature undead raider. Faster and tougher than the ones in Overgrowth."},
	"ghost": {"name": "Ghost", "icon_key": "ghost_icon", "desc": "A translucent, legless horror that moves faster than it has any right to."},
	"wisp": {"name": "Wisp", "icon_key": "wisp_icon", "desc": "A drifting soul-light that appears during the Spectral Tide's Commune event. Harmless alone, dangerous in numbers."},
	"ghoul": {"name": "Ghoul", "icon_key": "ghoul_icon", "desc": "A rotting, hunched horror that guards the Bone Clocktower, leashed close to Rattles."},
	"noxious_bat": {"name": "Noxious Bat", "icon_key": "bat_icon", "desc": "A mutated bat that swarms in the dark corners of Overgrowth."},
	"toxic_waste": {"name": "Goblin", "icon_key": "goblin_icon", "desc": "A sickly green creature born from the Radiation Zone. Often carries a gas mask."},
	"spike": {"name": "Spike", "icon_key": "warden_icon", "desc": "Overgrowth's boss. A hulking mutant guarding a fortified arena."},
	"rattles": {"name": "Rattles", "icon_key": "warden_icon", "desc": "Boneclock's boss. An ancient, bone-white horror ruling the Clocktower."},
	"gauntlet_stalker": {"name": "Stalker", "icon_key": "stalker_icon", "desc": "A Bloodline Gauntlet enemy - patrols the Refuge's platforms and charges when it spots you."},
	"gauntlet_boss": {"name": "Refuge Warden", "icon_key": "warden_icon", "desc": "A hulking guardian found at the end of each Gauntlet level. Always drops an engram."},
	"gauntlet_ranged": {"name": "Refuge Sniper", "icon_key": "sniper_enemy_icon", "desc": "A Gauntlet enemy that holds its ground and shoots from a distance instead of charging in. First appears on Level 2 onward."},
	"marauder": {"name": "Marauder", "icon_key": "raider_icon", "desc": "A fast, aggressive raider that closes distance quickly and fights up close. Dangerous if you let it get near."},
	"sentinel": {"name": "Sentinel", "icon_key": "sentinel_icon", "desc": "A slow, tanky defensive unit that holds its ground and hits hard once you're in range."},
	"rift_wraith": {"name": "Rift Wraith", "icon_key": "rift_wraith_icon", "desc": "A translucent purple horror torn out of a reality rift. Void Trench's signature threat."},
}
var discovered_enemies: Dictionary = {}

func mark_enemy_discovered(enemy_id: String) -> void:
	if not discovered_enemies.has(enemy_id):
		discovered_enemies[enemy_id] = true
		save_game()

const COLLECTIBLE_CATALOG := {
	"blossom": {"name": "Blossom", "icon_key": "blossom_icon", "color": Color(0.35, 0.55, 0.95, 1), "desc": "A glowing blue flower found around Overgrowth. The only currency the Wandering Trader accepts."},
	"rust_shard": {"name": "Rust Shard", "icon_key": "rust_shard_icon", "color": Color(0.85, 0.45, 0.15, 1), "desc": "A glowing fragment of corroded metal found around Boneclock. Worth a couple of Artifacts."},
	"static_mote": {"name": "Static Mote", "icon_key": "static_mote_icon", "color": Color(0.85, 0.9, 0.95, 1), "desc": "A crackling white spark found on any map. Grants a small burst of XP."},
	"void_shard": {"name": "Void Shard", "icon_key": "void_shard_icon", "color": Color(0.55, 0.3, 0.9, 1), "desc": "A fractured crystal shard pulled loose from a collapsed rift in Void Trench. Worth a couple of Alloys."},
	"spectral_ash": {"name": "Spectral Ash", "icon_key": "spectral_ash_icon", "color": Color(0.65, 0.9, 0.75, 1), "desc": "Pale ash left behind by a pacified shadow-beast in the Graveyard. Worth a handful of Souls."},
}
var seen_collectibles: Dictionary = {}

func mark_collectible_seen(collectible_id: String) -> void:
	if not seen_collectibles.has(collectible_id):
		seen_collectibles[collectible_id] = true
		save_game()

const MAP_CATALOG := {
	"overgrowth": {"name": "Overgrowth", "icon_key": "map_overgrowth_icon", "color": Color(0.45, 0.8, 0.45, 1), "desc": "Overgrown houses, a lake with a boat and floating loot, a radiation zone, and Spike's boss arena. Home to Blossoms and the Wandering Trader."},
	"boneclock": {"name": "Boneclock", "icon_key": "map_boneclock_icon", "color": Color(0.8, 0.75, 0.55, 1), "desc": "A dead town locked behind Level 10 - pavement streets, a gas station, the Skeleton Cave, and Rattles' Bone Clocktower. Only reachable at night from Overgrowth's discovery quest chain."},
	"void_trench": {"name": "Void Trench", "icon_key": "map_void_trench_icon", "color": Color(0.65, 0.4, 0.95, 1), "desc": "A fractured, purple-lit rift zone locked behind Level 20 - a deep central trench splits the map. Pulse Spires scramble your flashlight, Spore Clouds blind anyone who shoots them carelessly, Irradiated Puddles slow and damage, and Unstable Rifts hit hard but drop real loot if you collapse them. Rift Wraiths and Marauders patrol the ruins around the Neon Plaza, the Research Bio-Dome, and the Smuggling Bay."},
	"graveyard": {"name": "The Graveyard", "icon_key": "map_graveyard_icon", "color": Color(0.65, 0.68, 0.7, 1), "desc": "An overgrown, foggy pet cemetery at midnight, locked until you've earned the Loom-weaver. Rows of headstones, rusted gates, and shattered stone angels. Two Spectral Bowls let you defend against waves of shadow-beasts and pacify the survivor into a companion - extract with it alive to keep it."},
}

# --- Weapon Compendium: every distinct named gun in the game, hand-
# curated for the Data screen's Weapons tab - deliberately separate from
# the loot pools above (ENEMY_LOOT_POOL, LOOT_BAG_GEAR_POOL, etc.) so
# editing this catalog can never change drop rates or in-raid balance.
# Entries with the same icon_key fire the exact same projectile (see
# Bullet.gd) - that visual is what the Weapons tab previews.
const WEAPON_CATALOG := {
	# --- Pistols: cheap, common, low damage - the gun almost everyone
	# starts a raid with. ---
	"scrap_pistol": {"name": "Scrap Pistol", "icon_key": "pistol", "rarity": "common", "value": 45, "stat_type": "damage", "stat_value": 5.0, "desc": "Held together with tape and hope. The first gun most operators ever fire in Overgrowth, and the last one some of them ever put down."},
	"rusty_revolver": {"name": "Rusty Revolver", "icon_key": "pistol", "rarity": "common", "value": 38, "stat_type": "damage", "stat_value": 4.0, "desc": "The cylinder sticks if you don't slap it first. Reliable in the way an old dog is reliable - slow, but it shows up."},
	"bandit_pistol": {"name": "Bandit Pistol", "icon_key": "pistol", "rarity": "common", "value": 30, "stat_type": "damage", "stat_value": 3.0, "desc": "Pulled off a raider who didn't need it anymore. Light, cheap, and about as threatening as it looks."},
	"rustbelt_shiv": {"name": "Rustbelt Shiv", "icon_key": "pistol", "rarity": "common", "value": 25, "stat_type": "damage", "stat_value": 2.0, "desc": "Less a sidearm, more a bad idea with a trigger. The weakest gun in the Sector - better than throwing rocks, barely."},
	"sidearm": {"name": "Sidearm", "icon_key": "pistol", "rarity": "common", "value": 60, "stat_type": "damage", "stat_value": 6.0, "desc": "The standard-issue backup piece. Nothing special, nothing broken - just a gun that does exactly what it says on the box."},
	# --- Rifles: the all-rounder primary, mid-to-high damage at a
	# steady fire rate. ---
	"assault_rifle": {"name": "Assault Rifle", "icon_key": "rifle", "rarity": "rare", "value": 110, "stat_type": "damage", "stat_value": 14.0, "desc": "A dependable full-auto workhorse. Not the hardest hitter in the Sector, but it never asks you to compromise on range or rate of fire."},
	"hunting_carbine": {"name": "Hunting Carbine", "icon_key": "rifle", "rarity": "uncommon", "value": 95, "stat_type": "damage", "stat_value": 12.0, "desc": "Built for deer, repurposed for raiders. Lighter and cheaper than a full Assault Rifle, with almost as much bite."},
	"heavy_cannon": {"name": "Heavy Cannon", "icon_key": "rifle", "rarity": "rare", "value": 130, "stat_type": "damage", "stat_value": 18.0, "desc": "Heavier barrel, heavier punch. What it gives up in handling it makes back in how fast things stop moving."},
	"phantom_smg": {"name": "Phantom SMG", "icon_key": "rifle", "rarity": "epic", "value": 220, "stat_type": "damage", "stat_value": 30.0, "desc": "Near-silent action and a brutal rate of fire. Raiders rarely hear this one coming - they just stop getting up."},
	"scrap_smg": {"name": "Scrap SMG", "icon_key": "rifle", "rarity": "uncommon", "value": 100, "stat_type": "damage", "stat_value": 13.0, "desc": "Cobbled together from three different guns and a prayer. Ugly, loud, and it still puts rounds where you point it."},
	"tactical_rifle": {"name": "Tactical Rifle", "icon_key": "rifle", "rarity": "rare", "value": 120, "stat_type": "damage", "stat_value": 12.0, "desc": "Traders' bread-and-butter stock. A safe, well-balanced pick for anyone gearing up without a specific plan yet."},
	"prototype_rifle": {"name": "Prototype Rifle", "icon_key": "rifle", "rarity": "legendary", "value": 200, "stat_type": "damage", "stat_value": 22.0, "desc": "An unmarked test build with the serial number filed off. Whoever built it clearly wasn't done - it already outperforms most finished guns."},
	"fang_ripper": {"name": "Fang Ripper", "icon_key": "rifle", "rarity": "epic", "value": 340, "stat_type": "damage", "stat_value": 26.0, "desc": "Salvaged Beasts trophy gear - the stock is wrapped in something that used to have teeth. Hits like it remembers being alive."},
	"wraiths_grasp": {"name": "Wraith's Grasp", "icon_key": "rifle", "rarity": "epic", "value": 260, "stat_type": "damage", "stat_value": 24.0, "desc": "Spectral Tide reward gear - cold to the touch even after firing. Souls-forged rifles don't ask where the recoil energy goes."},
	"harvesters_reach": {"name": "Harvester's Reach", "icon_key": "rifle", "rarity": "mythic", "value": 620, "stat_type": "damage", "stat_value": 38.0, "desc": "Named for what it's designed to do to a crowd. One of the hardest-hitting rifles that isn't locked behind an event or the Alpha."},
	"widowmaker": {"name": "Widowmaker", "icon_key": "rifle", "rarity": "mythic", "value": 500, "stat_type": "damage", "stat_value": 32.0, "desc": "Full-auto and unforgiving. Traders don't like keeping this one in stock long - it doesn't sit on the shelf."},
	"deathmark_rifle": {"name": "Deathmark Rifle", "icon_key": "rifle", "rarity": "legendary", "value": 300, "stat_type": "damage", "stat_value": 22.0, "desc": "Every operator who's carried one into Boneclock says the same thing: whatever it's aimed at doesn't get back up."},
	"paradox_engine": {"name": "Paradox Engine", "icon_key": "rifle", "rarity": "multiversal", "value": 5200, "stat_type": "damage", "stat_value": 85.0, "desc": "It shouldn't be possible to build something like this from parts found in a dead sector. Multiversal-tier - the ceiling of what a rifle can be."},
	# --- Snipers: the highest single-target damage in the game, and
	# every hit chills the target, slowing them down. ---
	"marksman_rifle": {"name": "Marksman Rifle", "icon_key": "sniper", "rarity": "uncommon", "value": 105, "stat_type": "damage", "stat_value": 13.0, "desc": "A first real step up from scoped scrap. Every hit chills the target, slowing them down just enough to land the follow-up."},
	"scrap_sniper": {"name": "Scrap Sniper", "icon_key": "sniper", "rarity": "rare", "value": 135, "stat_type": "damage", "stat_value": 17.0, "desc": "A bolt-action built from a workbench blueprint, not a factory. Slow to cycle, but every round it sends out chills on impact."},
	"sharpshooter_rifle": {"name": "Sharpshooter Rifle", "icon_key": "sniper", "rarity": "rare", "value": 115, "stat_type": "damage", "stat_value": 15.0, "desc": "Balanced for operators who want range without giving up too much handling. The frost bite on every hit buys you the space to reposition."},
	"ghost_sniper_rifle": {"name": "Ghost Sniper Rifle", "icon_key": "sniper", "rarity": "rare", "value": 150, "stat_type": "damage", "stat_value": 26.0, "desc": "Painted the color of dead fog. Whatever it hits slows down cold, and rarely gets the chance to warm back up."},
	"overwatch_scope_rifle": {"name": "Overwatch Scope Rifle", "icon_key": "sniper", "rarity": "rare", "value": 155, "stat_type": "damage", "stat_value": 27.0, "desc": "Built to watch a choke point and punish anyone who walks through it. The frost effect on every hit makes sure they don't walk far."},
	"longshot_dmr": {"name": "Longshot DMR", "icon_key": "sniper", "rarity": "rare", "value": 160, "stat_type": "damage", "stat_value": 24.0, "desc": "Faster-cycling than a true bolt-action sniper, hits nearly as hard. A designated marksman's answer to 'why not both.'"},
	"widowmaker_sniper": {"name": "Widowmaker Sniper", "icon_key": "sniper", "rarity": "rare", "value": 160, "stat_type": "damage", "stat_value": 29.0, "desc": "No relation to the rifle of a similar name, other than the reputation. Chills on every hit, and hits hard enough that the chill barely matters."},
	"mistbound_sniper": {"name": "Mistbound Sniper", "icon_key": "sniper", "rarity": "epic", "value": 300, "stat_type": "damage", "stat_value": 29.0, "desc": "Spectral Tide event gear, wreathed in a permanent low fog. It slows what it hits - fitting, for a gun that never quite looks fully there."},
	"cataclysm": {"name": "Cataclysm", "icon_key": "sniper", "rarity": "mythic", "value": 520, "stat_type": "damage", "stat_value": 34.0, "desc": "A one-shot conversation-ender against anything short of a boss. The chill it leaves behind is almost an afterthought at this damage."},
	"executioners_mark": {"name": "Executioner's Mark", "icon_key": "sniper", "rarity": "mythic", "value": 510, "stat_type": "damage", "stat_value": 33.0, "desc": "Every operator who's carried it swears the scope finds the kill shot on its own. It probably doesn't. Probably."},
	"reapers_embrace": {"name": "Reaper's Embrace", "icon_key": "sniper", "rarity": "legendary", "value": 310, "stat_type": "damage", "stat_value": 23.0, "desc": "Cold iron and colder aim. A Legendary marksman rifle that chills its target before the sound of the shot even finishes traveling."},
	"wraithbone_cannon": {"name": "Wraithbone Cannon", "icon_key": "sniper", "rarity": "legendary", "value": 480, "stat_type": "damage", "stat_value": 38.0, "desc": "Salvaged Beasts' top marksman prize. The barrel looks carved from something that used to have a spine."},
	"prism_reaver": {"name": "Prism Reaver", "icon_key": "sniper", "rarity": "exotic", "value": 800, "stat_type": "damage", "stat_value": 40.0, "desc": "Fires a shot that seems to bend light on the way out. Exotic-tier, and it plays the part - a single hit chills and staggers almost anything."},
	"harvesters_scythe": {"name": "Harvester's Scythe", "icon_key": "sniper", "rarity": "exotic", "value": 950, "stat_type": "damage", "stat_value": 44.0, "desc": "The Harvester's Reach's older, meaner sibling. Exotic-tier damage with the same freezing bite on every connecting round."},
	"genesis_ripper": {"name": "Genesis Ripper", "icon_key": "sniper", "rarity": "multiversal", "value": 5000, "stat_type": "damage", "stat_value": 80.0, "desc": "The kind of damage number that shouldn't exist outside a boss fight. Multiversal-tier, and it chills everything it touches."},
	"heart_of_the_multiverse": {"name": "Heart of the Multiverse", "icon_key": "sniper", "rarity": "multiversal", "value": 2000, "stat_type": "damage", "stat_value": 60.0, "desc": "The single hardest-hitting sniper in Dead Sector. Whatever this thing is actually forged from, it isn't from this sector - or this reality."},
	# --- Shotguns: fire 5 pellets in a spread instead of one bullet -
	# devastating up close, weak at range. ---
	"wasteland_shotgun": {"name": "Wasteland Shotgun", "icon_key": "shotgun", "rarity": "uncommon", "value": 88, "stat_type": "damage", "stat_value": 11.0, "desc": "Sawed down and welded back together. Fires a full pellet spread - miserable at range, nightmarish in a doorway."},
	"combat_shotgun": {"name": "Combat Shotgun", "icon_key": "shotgun", "rarity": "rare", "value": 135, "stat_type": "damage", "stat_value": 18.0, "desc": "A pump-action built for clearing rooms, not sniping across a street. Every pellet in the spread can land, and they all hurt."},
	"riftline_shotgun": {"name": "Riftline Shotgun", "icon_key": "shotgun", "rarity": "rare", "value": 145, "stat_type": "damage", "stat_value": 24.0, "desc": "Pulled off something that came out of Void Trench and didn't survive the trip. The spread pattern is unnervingly tight for a shotgun."},
	"reapers_shotgun": {"name": "Reaper's Shotgun", "icon_key": "shotgun", "rarity": "epic", "value": 240, "stat_type": "damage", "stat_value": 32.0, "desc": "Land all 5 pellets and there usually isn't a second shot needed. The single scariest close-range option in the Sector."},
	# --- Flamethrowers: short-range, sets targets burning for damage
	# over time on top of the direct hit. ---
	"scorcher": {"name": "Scorcher", "icon_key": "flamethrower", "rarity": "uncommon", "value": 90, "stat_type": "damage", "stat_value": 8.0, "desc": "A short-range gout of promethium fire. Anything it touches keeps burning long after you've moved on to the next target."},
	"inferno_cannon": {"name": "Inferno Cannon", "icon_key": "flamethrower", "rarity": "rare", "value": 170, "stat_type": "damage", "stat_value": 12.0, "desc": "Bigger tank, bigger flame, bigger burn. Whatever survives the initial blast rarely survives the fire it leaves behind."},
	"ashmaker": {"name": "Ashmaker", "icon_key": "flamethrower", "rarity": "epic", "value": 260, "stat_type": "damage", "stat_value": 16.0, "desc": "It doesn't kill things so much as insist they stop existing, slowly, while on fire. Deeply unpleasant to be near."},
	"hellfire_reaper": {"name": "Hellfire Reaper", "icon_key": "flamethrower", "rarity": "legendary", "value": 330, "stat_type": "damage", "stat_value": 24.0, "desc": "Legendary-tier fire that doesn't go out when you'd expect it to. The burn alone can finish what the blast didn't."},
	# --- Thorns: bio-organic weapons that poison on hit, dealing
	# damage over time alongside the direct impact. ---
	"thorn": {"name": "Thorn", "icon_key": "thorn", "rarity": "uncommon", "value": 85, "stat_type": "damage", "stat_value": 9.0, "desc": "Grown, not built. Fires a barbed spine that keeps poisoning the target long after it lands."},
	"barbed_thorn": {"name": "Barbed Thorn", "icon_key": "thorn", "rarity": "rare", "value": 165, "stat_type": "damage", "stat_value": 13.0, "desc": "A meaner cultivar of the base Thorn. The poison it leaves behind ticks harder and lingers longer."},
	"toxinbrand": {"name": "Toxinbrand", "icon_key": "thorn", "rarity": "epic", "value": 255, "stat_type": "damage", "stat_value": 17.0, "desc": "The poison alone can finish a fight the initial hit didn't. Epic-tier bio-weaponry that nobody's fully explained the origin of."},
	"venomfang": {"name": "Venomfang", "icon_key": "thorn", "rarity": "legendary", "value": 320, "stat_type": "damage", "stat_value": 23.0, "desc": "Legendary bio-tech, and it shows - the poison it applies is nearly as dangerous as the impact itself."},
	"the_butchers_toll": {"name": "The Butcher's Toll", "icon_key": "thorn", "rarity": "exotic", "value": 950, "stat_type": "damage", "stat_value": 55.0, "desc": "Bloodline event gear at its most brutal - massive direct damage on top of a poison tick that keeps punishing long after."},
	# --- Railguns: pierce through 2 targets and chain an electric arc
	# to a nearby second enemy on every hit. ---
	"coilbreaker": {"name": "Coilbreaker", "icon_key": "railgun", "rarity": "uncommon", "value": 95, "stat_type": "damage", "stat_value": 10.0, "desc": "An entry-level magrail build. Pierces through the first target and arcs a chain of electricity to a second one nearby."},
	"magrail": {"name": "Magrail", "icon_key": "railgun", "rarity": "rare", "value": 175, "stat_type": "damage", "stat_value": 15.0, "desc": "A refined coil weapon with real stopping power. Every shot punches through its target and chains lightning to whatever's standing next to them."},
	"railgun": {"name": "Railgun", "icon_key": "railgun", "rarity": "epic", "value": 250, "stat_type": "damage", "stat_value": 34.0, "desc": "Full-size mag-accelerated ordnance. Pierces, chains lightning to a second target, and hits like it means it."},
	"ionstorm": {"name": "Ionstorm", "icon_key": "railgun", "rarity": "legendary", "value": 300, "stat_type": "damage", "stat_value": 22.0, "desc": "Legendary coil tech that arcs electricity almost as an afterthought. The piercing shot alone is worth the price."},
	# --- Sword: the one melee-flavored weapon in the compendium - still
	# fires like the others in a raid, but the name and art commit hard
	# to the blade fantasy. ---
	"bloodfang_blade": {"name": "Bloodfang Blade", "icon_key": "sword", "rarity": "legendary", "value": 340, "stat_type": "damage", "stat_value": 26.0, "desc": "Boneclock's signature weapon, reforged. Skeletons carry crude versions of this - this one's actually been sharpened."},
	# --- Alpha Cannon: the single Alpha-exclusive weapon in the game. ---
	"the_prototype": {"name": "The Prototype", "icon_key": "alpha_cannon", "rarity": "multiversal", "value": 1200, "stat_type": "damage", "stat_value": 26.0, "desc": "Nobody outside the Alpha will ever see one of these fire. Pierces through multiple targets and arcs to a second one on every hit.", "alpha_only": true},
	# --- Divine: one tier above Multiversal, a 0.01% Undertow crate
	# roll. Every one leans on the flashiest existing projectile
	# behavior in the game instead of a flat single-target hit.
	"seraphs_verdict": {"name": "Seraph's Verdict", "icon_key": "railgun", "rarity": "divine", "value": 12000, "stat_type": "damage", "stat_value": 175.5, "desc": "Pierces every target in its path and arcs lightning to a second one on every shot - a Railgun's whole kit, turned up past what should be possible."},
	"halo_reaver": {"name": "Halo Reaver", "icon_key": "alpha_cannon", "rarity": "divine", "value": 12500, "stat_type": "damage", "stat_value": 182.2, "desc": "Fires the same piercing, sparkle-trailed bolt as the Alpha Cannon - except this one wasn't handed out during a Tech Test. Nobody's quite sure where it came from."},
	"judgments_reach": {"name": "Judgment's Reach", "icon_key": "sniper", "rarity": "divine", "value": 13000, "stat_type": "damage", "stat_value": 189.0, "desc": "Chills, staggers, and drops nearly anything in the Sector in a single shot. The scope shows the kill before you've even pulled the trigger."},
	# --- Tech Test exclusive: boosts fire rate instead of raw damage. ---
	"tech_testers_sidearm": {"name": "Tech Tester's Sidearm", "icon_key": "pistol", "rarity": "legendary", "value": 400, "stat_type": "fire_rate", "stat_value": 0.03, "desc": "A memento from the Tech Test, before Dead Sector was even in Alpha. Trades raw damage for a genuinely absurd fire rate.", "beta_only": true},
}

# --- Key Compendium: every door key that actually exists in the game
# right now, shown on the Data screen's Keys tab. Kept in sync by hand
# with the door_key_id values set on Enemy.gd instances in the map
# scenes, and with grant_graveyard_key() above.
const KEY_CATALOG := {
	"house_a_key": {"name": "Ashen House Key", "icon_key": "key", "rarity": "rare", "value": 100, "desc": "Opens the locked Ashen House in Overgrowth. Drops off raiders patrolling nearby - nobody's found a way in without it."},
	"house_b_key": {"name": "Blackthorn Estate Key", "icon_key": "key", "rarity": "rare", "value": 100, "desc": "Opens the Blackthorn Estate in Overgrowth. A rarer find than the Ashen House Key, guarding a rarer loot room."},
	"gas_station_key": {"name": "Gas Station Key", "icon_key": "key", "rarity": "rare", "value": 100, "desc": "Opens the locked Gas Station in Boneclock. Skeletons and Ghouls patrol close enough to the pumps that finding one takes real work."},
	"graveyard_key": {"name": "Graveyard Key", "icon_key": "key", "rarity": "legendary", "value": 0, "desc": "A cold iron key Midnight Bones handed you in the dark. Has to be in your Backpack Storage or a Safe Pocket - not just your Stash - to get through the Graveyard's gate."},
}

# --- Bloodline: a second limited-time-style event, separate from
# Spectral Tide. Its own progression track (30 tiers, funded by Blood
# Shards earned in the Gauntlet) and its own exclusive loot pool -
# nothing here overlaps with Spectral Tide's Souls/Battle Pass.
const BLOODLINE_NAME := "Bloodline"
const BLOODLINE_MAX_TIER := 200
var blood_shards: int = 0
var bloodline_tier: int = 0
var bloodline_progress: int = 0

# How far into the Gauntlet (the side-scroller) the player has gotten.
# 5 levels total; each completed level is tougher than the last.
const GAUNTLET_MAX_LEVEL := 5
var gauntlet_best_level: int = 0
var gauntlet_current_level: int = 1
var gauntlet_session_active: bool = false
var gauntlet_session_loot: Array = []
var gauntlet_session_engrams: Array = []

func start_gauntlet_session() -> void:
	gauntlet_session_active = true
	gauntlet_session_loot = []
	gauntlet_session_engrams = []
	reset_gauntlet_equipment()

func end_gauntlet_session() -> void:
	gauntlet_session_active = false
	# Anything still equipped on the Bloodline doll was being silently
	# discarded here - reset_gauntlet_equipment() just nulled the dict
	# out with no record of what had been in it. Now it goes home to
	# the Stash first, same as everything sitting in the Backpack does
	# in GauntletComplete.gd's own back-button handler.
	for slot in gauntlet_equipped_items:
		var item = gauntlet_equipped_items[slot]
		if item != null:
			_add_to_stash(item)
	reset_gauntlet_equipment()

# Quitting out early (Esc -> Exit to Main Menu mid-run) should lose
# everything from that run, same as dying or bailing out of a regular
# raid does via end_run(false) - carried_loot cleared, nothing equipped
# on the Bloodline doll saved to the Stash. Deliberately separate from
# end_gauntlet_session() above, which is the "you actually finished/
# banked this run" path and is supposed to keep what you equipped.
func abandon_gauntlet_session() -> void:
	gauntlet_session_active = false
	carried_loot.clear()
	carried_value = 0
	gauntlet_session_loot.clear()
	gauntlet_session_engrams.clear()
	reset_gauntlet_equipment()
	save_game()

# --- Bloodline equipment: a separate, lightweight doll just for the
# Gauntlet run - resets each session, has real stat impact, and gives
# the player a real visual change (tint/glow) mid-run.
var gauntlet_equipped_items: Dictionary = {
	"head": null, "body": null, "weapon": null, "accessory": null, "boots": null, "backpack": null,
}

func gauntlet_equip_item(index: int) -> void:
	if index < 0 or index >= carried_loot.size():
		return
	var item: Dictionary = carried_loot[index]
	var slot: String = item.get("slot", "")
	if not gauntlet_equipped_items.has(slot):
		toast_requested.emit("Can't equip that")
		return
	var previous = gauntlet_equipped_items[slot]
	gauntlet_equipped_items[slot] = item
	carried_loot.remove_at(index)
	if previous != null:
		# Every other equip path allocates a fresh, non-overlapping cell
		# before appending back to carried_loot - this one skipped it and
		# kept the item's stale grid_x/grid_y from wherever it used to
		# sit, which can now overlap whatever's already in that cell.
		var cell := _next_free_cell_in(carried_loot, true, get_item_footprint(previous))
		previous["grid_x"] = cell.x
		previous["grid_y"] = cell.y
		carried_loot.append(previous)
	toast_requested.emit("Equipped %s" % item.get("name", "Item"))
	gauntlet_equipment_changed.emit()

func gauntlet_unequip_item(slot: String) -> void:
	var item = gauntlet_equipped_items.get(slot)
	if item == null:
		return
	gauntlet_equipped_items[slot] = null
	var cell := _next_free_cell_in(carried_loot, true, get_item_footprint(item))
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	carried_loot.append(item)
	gauntlet_equipment_changed.emit()

func get_gauntlet_equipped_bonus(stat_type: String) -> float:
	var total := 0.0
	for slot in gauntlet_equipped_items:
		var item = gauntlet_equipped_items[slot]
		if item != null:
			if item.get("stat_type", "") == stat_type:
				total += float(item.get("stat_value", 0.0))
			if item.get("stat_type_2", "") == stat_type:
				total += float(item.get("stat_value_2", 0.0))
	return total

# The single highest-rarity equipped piece - used to drive the player's
# visual tint/glow, so gearing up actually looks different mid-run.
const RARITY_RANK := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4, "mythic": 5, "exotic": 6, "multiversal": 7}
func get_gauntlet_best_equipped_rarity() -> String:
	var best := "common"
	var best_rank := -1
	for slot in gauntlet_equipped_items:
		var item = gauntlet_equipped_items[slot]
		if item != null:
			var r: String = item.get("rarity", "common")
			var rank: int = RARITY_RANK.get(r, 0)
			if rank > best_rank:
				best_rank = rank
				best = r
	return best

func reset_gauntlet_equipment() -> void:
	gauntlet_equipped_items = {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null, "backpack": null}

func roll_gauntlet_loot() -> Dictionary:
	# Mostly regular gear (scaled up a tier for the trouble), with a
	# chance at the Bloodline-exclusive pool the deeper you get, and a
	# rare shot at Mythic/Multiversal gear so the top two rarity tiers
	# aren't completely unobtainable from regular Bloodline drops.
	#
	# These bands are deliberately non-overlapping (unlike before, where
	# every one of these checks reused the same `roll` value with ranges
	# that were subsets of each other - since the egg check came first
	# and always returns immediately when it hits, the Mythic/Multiversal
	# and Bloodline-exclusive branches below it were unreachable dead
	# code, so top-tier GEAR specifically could never actually drop here).
	var level := gauntlet_current_level
	var roll := randf()
	# Pet egg drop - checked first, doubled rate per request (was 0.1).
	if roll < 0.2:
		var egg := roll_pet_egg_drop(1.0)
		if not egg.is_empty():
			return egg
	if level >= 4 and roll < 0.22:
		var top_pool: Array = SOUL_ITEM_POOL.filter(func(i): return i.get("rarity", "") in ["mythic", "multiversal"])
		if not top_pool.is_empty():
			return finalize_rolled_item(top_pool[randi() % top_pool.size()].duplicate(true))
	if level >= 3 and roll < 0.35:
		return finalize_rolled_item(BLOODLINE_ITEM_POOL[randi() % BLOODLINE_ITEM_POOL.size()].duplicate(true))
	var rarity_roll := randf()
	var rarity := "common"
	if rarity_roll < 0.05 + level * 0.02:
		rarity = "epic"
	elif rarity_roll < 0.2 + level * 0.03:
		rarity = "rare"
	elif rarity_roll < 0.5:
		rarity = "uncommon"
	var pool: Array = []
	for pool_item in ENEMY_LOOT_POOL:
		if pool_item.get("rarity", "") == rarity:
			pool.append(pool_item)
	if pool.is_empty():
		return roll_enemy_loot()
	return finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))

const BLOODLINE_ITEM_POOL := [
	{"name": "Bloodfang Blade", "value": 340, "slot": "weapon", "stat_type": "damage", "stat_value": 35.1, "icon_key": "sword", "rarity": "legendary"},
	{"name": "Crimson Wraith Cowl", "value": 320, "slot": "head", "stat_type": "max_health", "stat_value": 56.7, "icon_key": "helmet", "rarity": "legendary"},
	{"name": "Hollow Vein Plate", "value": 330, "slot": "body", "stat_type": "max_health", "stat_value": 64.8, "icon_key": "chestplate", "rarity": "legendary"},
	{"name": "Gutter Runner Boots", "value": 300, "slot": "boots", "stat_type": "speed", "stat_value": 51.3, "icon_key": "boots", "rarity": "legendary"},
	{"name": "Reaver's Harness", "value": 310, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "legendary"},
	{"name": "The Butcher's Toll", "value": 950, "slot": "weapon", "stat_type": "damage", "stat_value": 74.2, "icon_key": "thorn", "rarity": "exotic"},
	{"name": "Bloodline Sigil", "value": 900, "slot": "accessory", "stat_type": "speed", "stat_value": 64.8, "icon_key": "watch", "rarity": "exotic"},
]
const BLOODLINE_PET_ID := "wraith"
const BLOODLINE_PET_DATA := {"name": "Wraith", "cost": "Gauntlet exclusive", "color": Color(0.5, 0.05, 0.1, 1), "icon_key": "pet_crow", "stat_type": "damage", "stat_value": 8.0, "quote": "\"It doesn't bark. It doesn't bite. It just watches.\""}

func grant_blood_shards(amount: int) -> void:
	if amount <= 0:
		return
	blood_shards += amount
	toast_requested.emit("+%d Blood Shards" % amount)
	grant_bloodline_xp(amount)
	save_game()

func grant_bloodline_xp(amount: int) -> void:
	if amount <= 0 or bloodline_tier >= BLOODLINE_MAX_TIER:
		return
	bloodline_progress += amount
	var needed := 100 + bloodline_tier * 20
	while bloodline_tier < BLOODLINE_MAX_TIER and bloodline_progress >= needed:
		bloodline_progress -= needed
		_advance_bloodline_tier()
		needed = 100 + bloodline_tier * 20

func _advance_bloodline_tier() -> void:
	bloodline_tier += 1
	var rewards := _generate_bloodline_rewards()
	var reward: Dictionary = rewards[bloodline_tier - 1]
	match reward.get("type", ""):
		"item":
			_add_to_stash(finalize_rolled_item(reward.get("data", {}).duplicate(true)))
		"pet":
			if not owned_pets.has(BLOODLINE_PET_ID):
				owned_pets.append(BLOODLINE_PET_ID)
		"rubles":
			add_currency("rubles", int(reward.get("amount", 0)))
		"blood_shards":
			blood_shards += int(reward.get("amount", 0))
	toast_requested.emit("Bloodline Tier %d unlocked!" % bloodline_tier)
	save_game()

func skip_bloodline_tier() -> bool:
	if bloodline_tier >= BLOODLINE_MAX_TIER:
		return false
	if not spend_currency("blood_shards", 50):
		return false
	bloodline_progress = 0
	_advance_bloodline_tier()
	return true

# Deterministic (fixed seed) so it doesn't need to be saved tier-by-tier.
func _generate_bloodline_rewards() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6699
	var rewards: Array = []
	for tier in range(1, BLOODLINE_MAX_TIER + 1):
		if tier == BLOODLINE_MAX_TIER:
			rewards.append({"type": "pet"})
		elif tier % 10 == 0:
			var pool := BLOODLINE_ITEM_POOL.filter(func(i): return i.get("rarity", "") == "exotic")
			rewards.append({"type": "item", "data": pool[rng.randi() % pool.size()]})
		elif tier % 5 == 0:
			var pool := BLOODLINE_ITEM_POOL.filter(func(i): return i.get("rarity", "") == "legendary")
			rewards.append({"type": "item", "data": pool[rng.randi() % pool.size()]})
		elif tier % 3 == 0:
			rewards.append({"type": "blood_shards", "amount": 20 + tier})
		else:
			rewards.append({"type": "rubles", "amount": 400 + tier * 60})
	return rewards

# Called when the player extracts after clearing a Gauntlet level -
# rewards scale with how deep they got, and enemies get harder each
# level via get_gauntlet_difficulty().
func complete_gauntlet_level(level: int) -> void:
	gauntlet_best_level = max(gauntlet_best_level, level)
	grant_blood_shards(30 + level * 15)
	if level >= GAUNTLET_MAX_LEVEL:
		# The big finale payout - several exclusive items plus a
		# guaranteed pet, only obtainable by clearing all 5 levels.
		for i in range(3):
			_add_to_stash(finalize_rolled_item(BLOODLINE_ITEM_POOL[randi() % BLOODLINE_ITEM_POOL.size()].duplicate(true)))
		if not owned_pets.has(BLOODLINE_PET_ID):
			owned_pets.append(BLOODLINE_PET_ID)
		add_currency("rubles", 15000)
		grant_blood_shards(200)
	save_game()

func get_gauntlet_difficulty(level: int) -> float:
	return 1.0 + float(level - 1) * 0.5

# --- Engrams: a 50% chance drop from Gauntlet enemies. Undeciphered
# until brought to Justin at his Decompilation Rig in the Hideout, who
# converts them into Bloodline-exclusive weapons/armor. Rarity mirrors
# the main game's tiers, weighted toward Common.
const ENGRAM_RARITY_WEIGHTS := {"common": 0.55, "rare": 0.28, "legendary": 0.13, "exotic": 0.04}
var engrams: Array = []

func roll_gauntlet_engram() -> Dictionary:
	if randf() >= 0.5:
		return {}
	var roll := randf()
	var cumulative := 0.0
	var rarity := "common"
	for tier in ["exotic", "legendary", "rare", "common"]:
		cumulative += ENGRAM_RARITY_WEIGHTS[tier]
		if roll < cumulative:
			rarity = tier
			break
	return {"rarity": rarity, "name": "%s Engram" % rarity.capitalize()}

func add_engram(engram: Dictionary) -> void:
	if engram.is_empty():
		return
	engrams.append(engram)
	if gauntlet_session_active:
		gauntlet_session_engrams.append(engram.duplicate(true))
	toast_requested.emit("Found a %s Engram!" % engram.get("rarity", "common").capitalize())
	save_game()

# Justin's Decompilation Rig: turns an undeciphered Engram into a real
# Bloodline-exclusive item. Higher-rarity engrams weight toward the
# stronger half of the pool (Exotic-tier entries), lower ones lean
# toward the Legendary-tier entries - everything in BLOODLINE_ITEM_POOL
# is already event-exclusive either way.
func decipher_engram(index: int) -> Dictionary:
	if index < 0 or index >= engrams.size():
		return {}
	var engram: Dictionary = engrams[index]
	var rarity: String = engram.get("rarity", "common")
	var exotic_chance := {"common": 0.05, "rare": 0.15, "legendary": 0.4, "exotic": 0.85}
	var pool: Array
	if randf() < float(exotic_chance.get(rarity, 0.05)):
		pool = BLOODLINE_ITEM_POOL.filter(func(i): return i.get("rarity", "") == "exotic")
	else:
		pool = BLOODLINE_ITEM_POOL.filter(func(i): return i.get("rarity", "") == "legendary")
	if pool.is_empty():
		pool = BLOODLINE_ITEM_POOL
	var result := finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))
	engrams.remove_at(index)
	_add_to_stash(result)
	notify_event("decipher_engram_justin")
	toast_requested.emit("Justin deciphered your engram into %s!" % result.get("name", "an item"))
	save_game()
	return result

func get_enemy_scaling_factor() -> float:
	var total_levels := 0
	for key in upgrades:
		total_levels += int(upgrades[key].level)
	return 1.0 + float(total_levels) * 0.015

func get_grid_rows() -> int:
	return GRID_ROWS_BASE + int(upgrades["stash_grid"].level) * 2

func get_upgrade_cost(key: String) -> int:
	var u = upgrades.get(key)
	if u == null:
		return -1
	return int(u.base_cost + u.level * u.cost_step)

func can_afford_upgrade(key: String) -> bool:
	var u = upgrades.get(key)
	if u == null or u.level >= u.max_level:
		return false
	return artifacts >= get_upgrade_cost(key)

func purchase_upgrade(key: String) -> bool:
	if not can_afford_upgrade(key):
		return false
	artifacts -= get_upgrade_cost(key)
	upgrades[key].level += 1
	add_score(15)
	return true

# --- Skill Points: an alternate way to pay for Skill Tree upgrades,
# earned from the free 5-minute Starter Pack and sprinkled into loot
# (mail, Battle Pass, enemy drops, containers) rather than bought with
# Artifacts. Flat 1 Skill Point per level, regardless of which node or
# how deep into it you are - simple and predictable, since it's meant
# to feel like a bonus track rather than a second grind.
const SKILL_POINT_COST_PER_LEVEL := 1

func can_afford_upgrade_with_skill_points(key: String) -> bool:
	var u = upgrades.get(key)
	if u == null or u.level >= u.max_level:
		return false
	return skill_points >= SKILL_POINT_COST_PER_LEVEL

func purchase_upgrade_with_skill_points(key: String) -> bool:
	if not can_afford_upgrade_with_skill_points(key):
		return false
	skill_points -= SKILL_POINT_COST_PER_LEVEL
	upgrades[key].level += 1
	add_score(15)
	save_game()
	return true

# Sums the permanent bonus from purchased Skill Tree upgrades for a given stat.
func get_upgrade_bonus(stat_type: String) -> float:
	var u = upgrades.get(stat_type)
	if u == null:
		return 0.0
	return float(u.level) * float(u.per_level)

# --- Hideout Gym: separate upgrade track funded by Alloys. ---
const HIDEOUT_STAT_MAP := {
	"gym_health": "max_health", "gym_speed": "speed", "gym_damage": "damage",
	"gym_regen": "health_regen", "gym_reload": "reload_speed",
}
var hideout_upgrades: Dictionary = {
	"gym_health": {"level": 0, "base_cost": 15, "cost_step": 10, "per_level": 8.0, "max_level": 8, "label": "Vitality Training", "desc": "+8 Max Health per level"},
	"gym_speed": {"level": 0, "base_cost": 15, "cost_step": 10, "per_level": 6.0, "max_level": 8, "label": "Agility Training", "desc": "+6 Move Speed per level"},
	"gym_damage": {"level": 0, "base_cost": 18, "cost_step": 12, "per_level": 1.5, "max_level": 6, "label": "Combat Training", "desc": "+1.5 Bullet Damage per level"},
	"gym_regen": {"level": 0, "base_cost": 18, "cost_step": 12, "per_level": 0.3, "max_level": 6, "label": "Recovery Training", "desc": "+0.3 HP/sec regen per level"},
	"gym_reload": {"level": 0, "base_cost": 16, "cost_step": 10, "per_level": 0.06, "max_level": 6, "label": "Handling Drills", "desc": "-0.06s Reload Time per level"},
}

func get_hideout_upgrade_cost(key: String) -> int:
	var u = hideout_upgrades.get(key)
	if u == null:
		return -1
	return int(u.base_cost + u.level * u.cost_step)

func can_afford_hideout_upgrade(key: String) -> bool:
	var u = hideout_upgrades.get(key)
	if u == null or u.level >= u.max_level:
		return false
	return alloys >= get_hideout_upgrade_cost(key)

func purchase_hideout_upgrade(key: String) -> bool:
	if not can_afford_hideout_upgrade(key):
		return false
	alloys -= get_hideout_upgrade_cost(key)
	hideout_upgrades[key].level += 1
	equipped_changed.emit()
	return true

func get_hideout_bonus(stat_type: String) -> float:
	var total := 0.0
	for key in hideout_upgrades.keys():
		if HIDEOUT_STAT_MAP.get(key, "") == stat_type:
			var u = hideout_upgrades[key]
			total += float(u.level) * float(u.per_level)
	return total

# Currently equipped items, one per slot.
var equipped_items: Dictionary = {
	"head": null,
	"body": null,
	"weapon": null,
	"accessory": null,
	"boots": null,
	"backpack": null,
	"helmet_attachment": null,
}

var run_over: bool = false
var run_timed_out: bool = false

# True while inside a safe, no-stakes hangout hub (currently just the
# Guild Hall) that still uses the shared HUD/Pause Menu - lets HUD's
# generic "Exit to Main Menu" skip end_run() entirely instead of
# treating leaving a hangout as abandoning a raid (which would strip
# equipped gear, exactly like a real voluntary raid exit does).
var in_social_hub: bool = false

# --- Player level/XP and lifetime stats, shown on the Character screen. ---
signal xp_changed

const MAX_LEVEL := 500
var player_level: int = 1
var player_score: int = 0

func add_score(amount: int) -> void:
	player_score += amount

# --- Leaderboard: a handful of believable rival names with scores that
# drift slightly each time it's opened, so it feels like a live board
# even though there's no real server behind it. The player's own entry
# is the only one that's actually real.
# --- Leaderboard: a handful of believable rival names with stats that
# drift slightly each time it's opened, so it feels like a live board
# even though there's no real server behind it. The player's own entry
# is the only one that's actually real. Supports multiple categories -
# score, kills, pets owned, and Rubles - each with its own simulated
# rival values so switching tabs doesn't just re-sort the same numbers.
const LEADERBOARD_NAMES := [
	"LilDirtysFanboy", "ClarityIsMyDaddy", "JustinSimp2024", "EchoWasRightTho", "TeamLilDirty_",
	"xX_NoScope_Xx", "GoblinSlayer2000", "urMomsFavRaider", "Sweatlord420", "Big_Chungus_Prime",
	"CrimsonFangYT", "ItzDrizzyy", "NotAScriptKid", "Zer0_Deaths", "PixelPirateGG",
	"sadboi_hours", "im_actually_12", "certified_dirtbag", "Camper_King_69", "TeaBagTactician",
	"definitely_not_a_bot", "L_Ratio_Machine", "SkillIssueSteve", "MythicMisfit", "cracked_out_carl",
	"yeet_or_be_yeeted", "extraction_enjoyer", "clutch_or_kick",
]

# --- Rival profile flavor: portraits, titles, badges, and gear so the
# Leaderboard's Info popup has something real to show, not just a name
# and a number. All purely cosmetic/simulated - see _ensure_leaderboard_seeds().
const RIVAL_PORTRAITS := ["portrait_1", "portrait_2", "portrait_3", "portrait_4", "portrait_5", "portrait_6"]
const RIVAL_TITLES := [
	"", "", "Ghost of the Sector", "Veteran Operative", "Extraction Specialist",
	"The Undying", "Night Raider", "Loot Hound", "Sector Legend", "No Fear",
	"Iron Lungs", "Silent Runner", "The Collector", "Bonecrusher", "First In, Last Out",
]
const RIVAL_BADGE_POOL := ["here_from_the_start", "alpha_pioneer", "day_one"]
const RIVAL_GEAR_SLOTS := ["head", "body", "weapon", "boots", "accessory", "backpack"]
const RIVAL_GEAR_ICONS := {
	"head": ["helmet", "visor", "headset", "nightvision_goggles"],
	"body": ["chestplate"], "weapon": ["pistol", "rifle", "shotgun", "sniper", "flamethrower", "thorn", "railgun"],
	"boots": ["boots"], "accessory": ["ring", "watch"], "backpack": ["backpack"],
}
const RIVAL_RARITIES := ["uncommon", "rare", "epic", "legendary", "mythic", "exotic"]

# Procedurally builds a big, varied roster of usernames instead of one
# short hand-written list - mixed casing, some plain, some with an
# underscore + number, some fully lowercase, so it reads like something
# a hundred different actual people typed in, not one style repeated.
const NAME_PREFIXES := [
	"Ash", "Vector", "Night", "Rust", "Kettle", "Wraith", "Grim", "Copper", "Dusk", "Marrow",
	"Fen", "Sable", "Hollow", "Bramble", "Ferro", "Quick", "Shiv", "Black", "Tallow", "Ratchet",
	"Cinder", "Under", "Latch", "Bone", "Static", "Grey", "Iron", "Salt", "Bleak", "Crow",
	"Hex", "Feral", "Void", "Scrap", "Husk", "Gutter", "Moth", "Rot", "Ember", "Frost",
	"Bog", "Cracked", "Lost", "Nine", "Old", "Pale", "Rag", "Sump", "Thorn", "Wither",
	"xX", "shadow", "toxic", "raw", "dark", "lil", "big", "the", "real", "not",
]
const NAME_SUFFIXES := [
	"fall", "scav", "belt", "bone", "lure", "toll", "haze", "runner", "wick", "claw",
	"point", "fade", "grass", "water", "jane", "moss", "growth", "key", "wash", "spire",
	"howl", "shade", "step", "yard", "light", "gnaw", "reaper", "fang", "wolf", "raider",
	"hunter", "ghost", "killer", "sniper", "queen", "king", "boy", "girl", "gamer", "player",
	"420", "69", "1", "88", "og", "tv", "yt", "pro", "gg", "dev",
]

var _generated_leaderboard_names: Array = []

func _generate_leaderboard_names() -> Array:
	if not _generated_leaderboard_names.is_empty():
		return _generated_leaderboard_names
	var used := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 778899
	var result: Array = []
	# The original 28 hand-written names stay first, for anyone who
	# already saw them - the rest fills out to 100 procedurally.
	for n in LEADERBOARD_NAMES:
		used[n] = true
		result.append(n)
	while result.size() < 100:
		var prefix: String = NAME_PREFIXES[rng.randi() % NAME_PREFIXES.size()]
		var suffix: String = NAME_SUFFIXES[rng.randi() % NAME_SUFFIXES.size()]
		var style := rng.randi() % 4
		var candidate := ""
		match style:
			0:
				candidate = prefix + suffix
			1:
				candidate = prefix + "_" + suffix
			2:
				candidate = prefix.to_lower() + suffix.to_lower() + str(rng.randi_range(1, 999))
			_:
				candidate = prefix + "_" + suffix + str(rng.randi_range(1, 99))
		if used.has(candidate):
			continue
		used[candidate] = true
		result.append(candidate)
	_generated_leaderboard_names = result
	return result
const LEADERBOARD_CATEGORIES := ["score", "kills", "pets", "stash_worth", "extractions", "level", "arena"]
var leaderboard_seeds: Dictionary = {}

func _ensure_leaderboard_seeds() -> void:
	if not leaderboard_seeds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 445566
	for rival_name in _generate_leaderboard_names():
		var gear := {}
		for slot in RIVAL_GEAR_SLOTS:
			if rng.randf() < 0.8:
				var icons: Array = RIVAL_GEAR_ICONS.get(slot, ["generic"])
				gear[slot] = {
					"icon_key": icons[rng.randi() % icons.size()],
					"rarity": RIVAL_RARITIES[rng.randi() % RIVAL_RARITIES.size()],
				}
		var badge_count: int = rng.randi_range(0, 2)
		var badges: Array = []
		var badge_pool: Array = RIVAL_BADGE_POOL.duplicate()
		badge_pool.shuffle()
		for i in range(min(badge_count, badge_pool.size())):
			badges.append(badge_pool[i])
		var title: String = RIVAL_TITLES[rng.randi() % RIVAL_TITLES.size()]
		# A small slice of the roster are real Tech Test Veterans, same
		# as a player who claimed Alpha Rewards - the title and badge
		# always come as a matching pair here, never one without the
		# other, and this exact flag is what Global Chat checks before
		# showing the Tech Test Prism background behind their messages,
		# so anyone with that background truly does have both if you
		# check their Info.
		var is_tech_test_veteran: bool = rng.randf() < 0.09
		if is_tech_test_veteran:
			title = "Tech Test Veteran"
			if not badges.has("here_from_the_start"):
				badges.append("here_from_the_start")
		leaderboard_seeds[rival_name] = {
			"score": rng.randi_range(200, 3200),
			"kills": rng.randi_range(15, 450),
			"pets": rng.randi_range(0, 14),
			"stash_worth": rng.randi_range(500, 80000),
			"extractions": rng.randi_range(2, 90),
			"level": rng.randi_range(3, 120),
			"deaths": rng.randi_range(5, 200),
			"rank_points": rng.randi_range(11000, 19000) if rng.randf() < 0.12 else rng.randi_range(0, 11000),
			"arena": rng.randi_range(0, 2600),
			"portrait": RIVAL_PORTRAITS[rng.randi() % RIVAL_PORTRAITS.size()],
			"title": title,
			"badges": badges,
			"gear": gear,
			"is_tech_test_veteran": is_tech_test_veteran,
		}

# --- Leaderboard: no season/reset concept yet - categories just show
# real lifetime stats. (leaderboard_player_baseline/leaderboard_season_start
# still exist as inert saved fields for old saves; nothing reads or
# writes them anymore.)
var leaderboard_season_start: float = 0.0
var leaderboard_player_baseline: Dictionary = {}

# --- Ranked: picking Ranked flags the next run as ranked (shown on the
# Searching screen) and shows the rank ladder before you deploy.
# Rank Points are a real, standalone progression track (separate from
# Level) that only move on a SUCCESSFUL extraction from a Ranked raid -
# dying or timing out in Ranked earns nothing. Each of the 6 tiers below
# has 3 sub-ranks (3 -> 2 -> 1, 1 being the strongest before promoting
# into the next tier's 3), for 18 total steps from Stray 3 up to
# Syndicate 1. Still a local, single-player progression (your own Rank
# Points vs your own thresholds) rather than a live matchmaking ELO
# against other real players - same honest framing as everywhere else
# "Ranked" is a preview.
var is_ranked_match: bool = false
var rank_points: int = 0
const RANK_TIERS := [
	{"id": "stray", "label": "Stray", "icon": "compass", "color": Color(0.65, 0.65, 0.65, 1), "desc": "No name, no crew, no plan. Just surviving."},
	{"id": "scavenger", "label": "Scavenger", "icon": "gear", "color": Color(0.55, 0.75, 0.45, 1), "desc": "Knows the Sector well enough to live off it."},
	{"id": "enforcer", "label": "Enforcer", "icon": "combat", "color": Color(0.85, 0.4, 0.3, 1), "desc": "Fights first, asks questions never."},
	{"id": "prowler", "label": "Prowler", "icon": "stealth", "color": Color(0.4, 0.65, 0.55, 1), "desc": "You won't see them coming. That's the point."},
	{"id": "spectre", "label": "Spectre", "icon": "soul_wisp", "color": Color(0.65, 0.55, 0.95, 1), "desc": "Rumored more than seen. The Sector talks about them anyway."},
	{"id": "syndicate", "label": "Syndicate", "icon": "bone_crown", "color": Color(1.0, 0.82, 0.35, 1), "desc": "Runs the Sector in every way that matters. The top."},
]
# Cumulative Rank Points needed to REACH each of the 18 steps (index 0 =
# Stray 3, index 17 = Syndicate 1). Grows faster near the top so the
# highest ranks actually mean something.
const RANK_POINT_THRESHOLDS := [
	0, 120, 360, 720, 1200, 1800, 2520, 3360, 4320, 5400,
	6600, 7920, 9360, 10920, 12600, 14400, 16320, 18360,
]

func get_rank_full_index_for_points(points: int) -> int:
	var idx := 0
	for i in range(RANK_POINT_THRESHOLDS.size()):
		if points >= RANK_POINT_THRESHOLDS[i]:
			idx = i
	return idx

func get_rank_full_index() -> int:
	return get_rank_full_index_for_points(rank_points)

func get_rank_tier_index(full_idx: int) -> int:
	return clampi(int(full_idx / 3.0), 0, RANK_TIERS.size() - 1)

# Sub-rank counts DOWN within a tier (3 -> 2 -> 1), so 1 is the strongest
# before promoting into the next tier's 3.
func get_rank_sub_number(full_idx: int) -> int:
	return 3 - (full_idx % 3)

func get_rank_tier(full_idx: int) -> Dictionary:
	return RANK_TIERS[get_rank_tier_index(full_idx)]

func get_rank_display_name(full_idx: int) -> String:
	return "%s %d" % [get_rank_tier(full_idx).get("label", "?"), get_rank_sub_number(full_idx)]

func get_rank_points_for_index(full_idx: int) -> int:
	return RANK_POINT_THRESHOLDS[clampi(full_idx, 0, RANK_POINT_THRESHOLDS.size() - 1)]

func is_max_rank(full_idx: int) -> bool:
	return full_idx >= RANK_POINT_THRESHOLDS.size() - 1

# Points earned into the CURRENT step and points needed to reach the
# next one - the ratio of these two is what the progress bar shows.
# At max rank both come back equal (1, 1) so the bar just reads full.
func get_rank_progress(full_idx: int = -1) -> Vector2i:
	var idx: int = full_idx if full_idx >= 0 else get_rank_full_index()
	var current_floor := get_rank_points_for_index(idx)
	if is_max_rank(idx):
		return Vector2i(1, 1)
	var next_floor := get_rank_points_for_index(idx + 1)
	return Vector2i(rank_points - current_floor, next_floor - current_floor)

# --- Arena rank ladder: a separate, simpler 6-step progression (no
# sub-numbers, unlike the main Rank ladder) just for Arena's 1v1/2v2
# matches - won by Matchmake wins, not raid extractions.
var arena_rank_points: int = 0
# Highest ARENA_REWARD_TIERS index already paid out - see
# grant_arena_rank_points() below for why this starts at -1.
var arena_reward_tiers_granted: int = -1
const ARENA_RANK_TIERS := [
	{"id": "arena_initiate", "label": "Initiate", "icon": "arena_initiate", "color": Color(0.75, 0.7, 0.8, 1), "desc": "Everyone starts here. Show up, take a hit, take a win."},
	{"id": "arena_rival", "label": "Rival", "icon": "arena_rival", "color": Color(0.55, 0.6, 0.9, 1), "desc": "You've got someone's number now - and they've got yours."},
	{"id": "arena_duelist", "label": "Duelist", "icon": "arena_duelist", "color": Color(0.65, 0.45, 0.9, 1), "desc": "Two blades, no wasted movement. You've made a habit of winning."},
	{"id": "arena_gladiator", "label": "Gladiator", "icon": "arena_gladiator", "color": Color(0.8, 0.3, 0.85, 1), "desc": "The Grid knows your name. Most people would rather not queue against you."},
	{"id": "arena_champion", "label": "Champion", "icon": "arena_champion", "color": Color(0.85, 0.55, 0.3, 1), "desc": "Genuinely one of the best 1v1/2v2 records on the board."},
	{"id": "arena_grandmaster", "label": "Grandmaster", "icon": "arena_grandmaster", "color": Color(1.0, 0.85, 0.3, 1), "desc": "The very top of the Arena ladder. Almost nobody gets here."},
]
const ARENA_RANK_POINT_THRESHOLDS := [0, 150, 450, 900, 1600, 2600]

# What each Arena Rank tier actually grants - index-aligned with
# ARENA_RANK_TIERS/ARENA_RANK_POINT_THRESHOLDS above. Same shape as
# LEADERBOARD_REWARD_TIERS (see ArenaRankRewardsPanel.gd, modeled
# directly on LeaderboardRewardsPanel.gd), scaled down since reaching
# a given Arena Rank is a real but much more attainable milestone than
# a Leaderboard placement.
const ARENA_REWARD_TIERS := [
	{"label": "Initiate", "badge": "", "rubles": 500, "artifacts": 0, "alloys": 0, "skill_points": 0, "bags": []},
	{"label": "Rival", "badge": "", "rubles": 3000, "artifacts": 10, "alloys": 10, "skill_points": 2, "bags": ["common"]},
	{"label": "Duelist", "badge": "", "rubles": 8000, "artifacts": 25, "alloys": 25, "skill_points": 5, "bags": ["rare"]},
	{"label": "Gladiator", "badge": "", "rubles": 18000, "artifacts": 50, "alloys": 50, "skill_points": 10, "bags": ["rare", "epic"]},
	{"label": "Champion", "badge": "", "rubles": 40000, "artifacts": 100, "alloys": 100, "skill_points": 20, "bags": ["epic", "legendary"]},
	{"label": "Grandmaster", "badge": "", "rubles": 90000, "artifacts": 250, "alloys": 250, "skill_points": 40, "bags": ["legendary", "mythic"]},
]

func get_arena_rank_index_for_points(points: int) -> int:
	var idx := 0
	for i in range(ARENA_RANK_POINT_THRESHOLDS.size()):
		if points >= ARENA_RANK_POINT_THRESHOLDS[i]:
			idx = i
	return idx

func get_arena_rank_index() -> int:
	return get_arena_rank_index_for_points(arena_rank_points)

# Adds Arena Rank Points and grants ARENA_REWARD_TIERS's reward for any
# tier newly crossed. Previously arena_rank_points was mutated directly
# by TheGrid.gd with nothing ever consulting this table, so every tier's
# itemized reward was UI text with no backing grant. The first call after
# this fix lazily baselines arena_reward_tiers_granted to the CURRENT
# tier with no retroactive payout - an existing save doesn't suddenly
# cash in every tier it already passed, only tiers reached from here on.
func grant_arena_rank_points(amount: int) -> void:
	if arena_reward_tiers_granted < 0:
		arena_reward_tiers_granted = get_arena_rank_index()
	arena_rank_points += amount
	var new_index := get_arena_rank_index()
	while arena_reward_tiers_granted < new_index:
		arena_reward_tiers_granted += 1
		_grant_arena_reward_tier(arena_reward_tiers_granted)
	save_game()

func _grant_arena_reward_tier(index: int) -> void:
	if index < 0 or index >= ARENA_REWARD_TIERS.size():
		return
	var tier: Dictionary = ARENA_REWARD_TIERS[index]
	if int(tier.get("rubles", 0)) > 0:
		add_currency("rubles", int(tier["rubles"]))
	if int(tier.get("artifacts", 0)) > 0:
		add_currency("artifacts", int(tier["artifacts"]))
	if int(tier.get("alloys", 0)) > 0:
		add_currency("alloys", int(tier["alloys"]))
	if int(tier.get("skill_points", 0)) > 0:
		skill_points += int(tier["skill_points"])
	for bag_tier in tier.get("bags", []):
		_add_to_stash(make_loot_bag(str(bag_tier)))
	var badge_id: String = str(tier.get("badge", ""))
	if badge_id != "":
		grant_badge(badge_id)
	toast_requested.emit("Arena Rank Up: %s! Rewards added to your Stash/currency." % str(tier.get("label", "?")))

func get_arena_rank_tier(index: int = -1) -> Dictionary:
	var idx: int = index if index >= 0 else get_arena_rank_index()
	return ARENA_RANK_TIERS[clampi(idx, 0, ARENA_RANK_TIERS.size() - 1)]

func get_arena_rank_display_name(index: int = -1) -> String:
	return str(get_arena_rank_tier(index).get("label", "?"))

func is_max_arena_rank(index: int) -> bool:
	return index >= ARENA_RANK_POINT_THRESHOLDS.size() - 1

# The current Arena match's two simulated rosters - rolled fresh by
# Matchmake (see ArenaMatchmaking.gd) right before heading into The
# Grid, and read by ArenaCurrentTeamsPanel via Lilly. Team 1 is always
# the player's own team (blue); Team 2 is the opposing team (red).
var current_arena_match: Dictionary = {}

# True for the whole time the player is inside TheGrid.tscn (set in
# TheGrid.gd's _ready(), read/reset by end_run() below) - lets end_run()
# treat an Arena win/loss differently from a normal raid: no gear-strip
# on loss (nothing to actually lose here), and routes to the Arena's own
# win/loss screens instead of RaidRewards/DeathScreen.
var is_arena_match: bool = false
var last_arena_kills: int = 0
var last_arena_rank_points_gained: int = 0

# One-shot handoff from ArenaModeChoice.gd's 1v1/2v2 pick to
# ArenaMatchmaking.gd - 0 means "no explicit choice made", which falls
# back to the original random 4v4-7v7 squad roll (defensive fallback in
# case ArenaMatchmaking.tscn is ever reached by a path other than the
# mode-choice screen).
var arena_queued_team_size: int = 0

# One-shot handoff from a Recruit-channel invite's Join flow
# (GlobalChatBox.gd) to whichever raid map scene loads next - a list of
# simulated {name, portrait, rank_full_idx, level, ...} entries (same
# shape the Leaderboard/chat pools already use) for the party that
# "joined" the invite. The target map's _ready() spawns a follower per
# entry and MUST clear this back to [] right after reading it, so a
# later raid entered normally doesn't also spawn a leftover party.
var pending_raid_party: Array = []

# --- Arena Loadout Presets: a named, ready-made weapon/gear/pet/ammo
# combo picked on the "Choose Your Loadout" screen right before entering
# The Grid. Applied the exact same way start_scav_run() temporarily
# swaps equipped_items for a Scav run - snapshot the player's REAL
# loadout first, swap in the preset, then restore the snapshot the
# moment the match ends (see end_arena_loadout, called from end_run()).
# Pets are set directly from PET_CATALOG's base (always-defined) pets
# rather than the player's own collection, since this is a temporary
# loaner for the match, not a real equip - ownership doesn't matter.
const ARENA_LOADOUT_PRESETS := [
	{
		"id": "marksman", "name": "Marksman", "desc": "One shot, one kill - if you can land it. Slow-firing, hits like a truck.",
		"ammo_type": "heavy",
		"gear": {
			"weapon": {"name": "Behemoth Anti-Materiel Rifle", "value": 280, "slot": "weapon", "stat_type": "damage", "stat_value": 62.0, "icon_key": "sniper", "rarity": "epic", "shot_cooldown": 2.5},
			"body": {"name": "Ghost Cloak", "value": 150, "slot": "body", "stat_type": "speed", "stat_value": 15.0, "icon_key": "chestplate", "rarity": "rare"},
			"boots": {"name": "Sentinel Boots", "value": 90, "slot": "boots", "stat_type": "speed", "stat_value": 29.7, "icon_key": "boots", "rarity": "rare"},
			"head": {"name": "Oracle Visor", "value": 220, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "epic"},
			"accessory": null, "backpack": null,
		},
		"pet_id": "scout",
	},
	{
		"id": "assault", "name": "Assault", "desc": "No gimmicks - a solid rifle and gear built to trade fire and win.",
		"ammo_type": "medium",
		"gear": {
			"weapon": {"name": "Phantom SMG", "value": 220, "slot": "weapon", "stat_type": "damage", "stat_value": 40.5, "icon_key": "rifle", "rarity": "epic"},
			"body": {"name": "Ironclad Vest", "value": 235, "slot": "body", "stat_type": "max_health", "stat_value": 60.8, "icon_key": "chestplate", "rarity": "epic"},
			"boots": {"name": "Blitz Boots", "value": 190, "slot": "boots", "stat_type": "speed", "stat_value": 43.2, "icon_key": "boots", "rarity": "epic"},
			"head": {"name": "Warden Helm", "value": 210, "slot": "head", "stat_type": "max_health", "stat_value": 51.3, "icon_key": "helmet", "rarity": "epic"},
			"accessory": null, "backpack": null,
		},
		"pet_id": "shadow",
	},
	{
		"id": "bruiser", "name": "Bruiser", "desc": "Get in close and don't stop moving forward. Built to soak hits and answer with a shotgun.",
		"ammo_type": "medium",
		"gear": {
			"weapon": {"name": "Reaper's Shotgun", "value": 240, "slot": "weapon", "stat_type": "damage", "stat_value": 43.2, "icon_key": "shotgun", "rarity": "epic"},
			"body": {"name": "Juggernaut Plate", "value": 230, "slot": "body", "stat_type": "max_health", "stat_value": 56.7, "icon_key": "chestplate", "rarity": "epic"},
			"boots": {"name": "Ridgeline Boots", "value": 92, "slot": "boots", "stat_type": "speed", "stat_value": 31.1, "icon_key": "boots", "rarity": "rare"},
			"head": {"name": "Vanguard Helmet", "value": 125, "slot": "head", "stat_type": "max_health", "stat_value": 40.5, "icon_key": "helmet", "rarity": "rare"},
			"accessory": null, "backpack": null,
		},
		"pet_id": "whiskers",
	},
]

var _saved_arena_equipped: Dictionary = {}
var _saved_arena_pet: String = ""
var _arena_loadout_active: bool = false

func get_arena_loadout_preset(preset_id: String) -> Dictionary:
	for preset in ARENA_LOADOUT_PRESETS:
		if preset.get("id", "") == preset_id:
			return preset
	return {}

func apply_arena_loadout_preset(preset_id: String) -> void:
	var preset: Dictionary = get_arena_loadout_preset(preset_id)
	if preset.is_empty():
		return
	_saved_arena_equipped = equipped_items.duplicate(true)
	_saved_arena_pet = equipped_pet
	_arena_loadout_active = true
	var gear: Dictionary = preset.get("gear", {})
	for slot in gear:
		# Accessory/backpack are explicitly null in every preset - real
		# gear equipped there before the match used to stay mechanically
		# active for the whole thing, against the standardized-loadout
		# premise. null itself has no duplicate() method, so guard it.
		equipped_items[slot] = gear[slot].duplicate(true) if gear[slot] != null else null
	if preset.has("pet_id"):
		equipped_pet = str(preset["pet_id"])
	# Same starting-ammo grant start_scav_run() uses for the ammo type its
	# random weapon happens to need - real Backpack ammo, kept if you win,
	# gone with the rest of your temp loadout either way.
	var ammo_type: String = str(preset.get("ammo_type", "medium"))
	add_loot({
		"name": "%s Ammo" % ammo_type.capitalize(), "value": 15, "slot": "ammo",
		"icon_key": "ammo_%s" % ammo_type, "rarity": get_ammo_rarity(ammo_type),
		"consumable_type": "ammo", "ammo_type": ammo_type, "ammo_amount": 200,
	})
	equipped_changed.emit()

func end_arena_loadout_if_active() -> void:
	if not _arena_loadout_active:
		return
	_arena_loadout_active = false
	equipped_items = _saved_arena_equipped.duplicate(true)
	equipped_pet = _saved_arena_pet
	_saved_arena_equipped = {}
	_saved_arena_pet = ""
	equipped_changed.emit()

func generate_arena_match(team_size: int) -> void:
	var pool: Array = get_leaderboard("arena").filter(func(e): return not e.get("is_player", false))
	pool.shuffle()
	var team1 := [{
		"name": player_name if player_name != "" else "You", "portrait": player_portrait_id if player_portrait_id != "" else "portrait_1",
		"is_player": true, "level": player_level, "gear": equipped_items, "title": equipped_title, "badges": owned_badges,
		"arena_rank": get_arena_rank_display_name(), "arena_color": get_arena_rank_tier().get("color", Color.WHITE),
	}]
	var team2 := []
	var idx := 0
	for i in range(team_size - 1):
		if idx < pool.size():
			team1.append(_arena_roster_entry(pool[idx]))
			idx += 1
	for i in range(team_size):
		if idx < pool.size():
			team2.append(_arena_roster_entry(pool[idx]))
			idx += 1
	current_arena_match = {"team_size": team_size, "team1": team1, "team2": team2}

func _arena_roster_entry(entry: Dictionary) -> Dictionary:
	var arena_idx: int = get_arena_rank_index_for_points(int(entry.get("value", 0)))
	var tier: Dictionary = get_arena_rank_tier(arena_idx)
	return {
		"name": entry.get("name", "?"), "portrait": entry.get("portrait", "portrait_1"), "is_player": false,
		"level": entry.get("level", 1), "gear": entry.get("gear", {}), "title": entry.get("title", ""), "badges": entry.get("badges", []),
		"arena_rank": str(tier.get("label", "?")), "arena_color": tier.get("color", Color.WHITE),
	}

# Builds current_arena_match from a team the player actually joined via
# Find a Team (ArenaFindTeamPanel), instead of a freshly-rolled
# matchmake team like generate_arena_match() builds above. team_members
# is that team's simple {name, portrait[, is_player]} roster - the
# player's own slot gets upgraded to full self data the same way
# generate_arena_match() does for team1[0], and a fresh opposing
# roster is rolled the same way generate_arena_match() rolls team2.
func generate_arena_match_from_team(team_members: Array, team_size: int) -> void:
	var team1: Array = []
	for m in team_members:
		if m.get("is_player", false):
			team1.append({
				"name": player_name if player_name != "" else "You", "portrait": player_portrait_id if player_portrait_id != "" else "portrait_1",
				"is_player": true, "level": player_level, "gear": equipped_items, "title": equipped_title, "badges": owned_badges,
				"arena_rank": get_arena_rank_display_name(), "arena_color": get_arena_rank_tier().get("color", Color.WHITE),
			})
		else:
			team1.append({
				"name": m.get("name", "?"), "portrait": m.get("portrait", "portrait_1"), "is_player": false,
				"arena_rank": get_arena_rank_display_name(), "arena_color": get_arena_rank_tier().get("color", Color.WHITE),
			})
	var pool: Array = get_leaderboard("arena").filter(func(e): return not e.get("is_player", false))
	pool.shuffle()
	var team2 := []
	for i in range(team_size):
		if i < pool.size():
			team2.append(_arena_roster_entry(pool[i]))
	current_arena_match = {"team_size": team_size, "team1": team1, "team2": team2}

# Rough illustrative share of players actually sitting in each of the 18
# ranks (index-aligned with RANK_POINT_THRESHOLDS) - a steep drop-off
# toward the top, same spirit as any ranked ladder: most people sit in
# the bottom few tiers, and the very top rank is genuinely rare.
const RANK_POPULATION_PERCENT := [
	24.2, 17.0, 13.0, 10.0, 8.0, 6.5, 5.5, 4.5, 3.5,
	2.7, 2.0, 1.3, 0.9, 0.5, 0.25, 0.1, 0.02, 0.001,
]

func get_rank_population_percent(full_idx: int) -> float:
	return RANK_POPULATION_PERCENT[clampi(full_idx, 0, RANK_POPULATION_PERCENT.size() - 1)]

# --- Post-raid rewards screen: tracks what happened during THIS specific
# raid so it can all be shown together on RaidRewards.tscn right after a
# successful extraction (loot secured, quests wrapped up, and - if this
# was a Ranked raid - Rank Points gained and the rank-up itself).
# raid_quests_completed collects titles as quests go active -> ready
# (see notify_event below); begin_raid_session() clears it right before
# deploying so a fresh raid never shows a previous raid's completions.
var raid_quests_completed: Array = []
var last_raid_rewards: Dictionary = {}
var last_death_info: Dictionary = {}

func begin_raid_session() -> void:
	raid_quests_completed.clear()
	in_social_hub = false
	MenuMusic.stop_menu_music()

# --- Leaderboard season rewards: a preview/showcase of what each rank
# band would earn (not yet a real claim flow - there's no live server
# actually tracking a finished season to claim against). Deliberately
# pulls from loot bag tiers and gear pools that already exist rather
# than inventing a whole new reward catalog, and shrinks hard tier to
# tier - Top 1 should feel like an actual jackpot, Top 50 should still
# feel worth doing but nowhere close.
const LEADERBOARD_REWARD_TIERS := [
	{"label": "Top 1", "badge": "rank_1_champion", "rubles": 1000000, "artifacts": 1000, "alloys": 1000, "skill_points": 150, "bags": ["alpha", "exotic", "exotic", "mythic"]},
	{"label": "Top 2", "badge": "rank_2_elite", "rubles": 600000, "artifacts": 600, "alloys": 600, "skill_points": 90, "bags": ["exotic", "exotic", "mythic"]},
	{"label": "Top 3", "badge": "rank_3_podium", "rubles": 400000, "artifacts": 400, "alloys": 400, "skill_points": 60, "bags": ["exotic", "mythic"]},
	{"label": "Top 5", "badge": "", "rubles": 200000, "artifacts": 200, "alloys": 200, "skill_points": 35, "bags": ["mythic", "legendary"]},
	{"label": "Top 10", "badge": "", "rubles": 100000, "artifacts": 100, "alloys": 100, "skill_points": 20, "bags": ["legendary"]},
	{"label": "Top 25", "badge": "", "rubles": 40000, "artifacts": 40, "alloys": 40, "skill_points": 10, "bags": ["rare"]},
	{"label": "Top 50", "badge": "", "rubles": 15000, "artifacts": 15, "alloys": 15, "skill_points": 5, "bags": ["common"]},
]

# Rival leaderboard stats used to drift a little on every single call to
# get_leaderboard()/get_ranked_leaderboard() - harmless-looking, but with
# popup checks, Global Chat, and panel refreshes all calling these
# independently, scores climbed far faster than intended just from the
# game being open and doing normal things. Now gated to real elapsed
# time, with smaller per-tick amounts on top of that.
var _leaderboard_last_tick: float = 0.0
const LEADERBOARD_TICK_INTERVAL := 45.0

func _leaderboard_should_tick() -> bool:
	var now := Time.get_unix_time_from_system()
	if now - _leaderboard_last_tick < LEADERBOARD_TICK_INTERVAL:
		return false
	_leaderboard_last_tick = now
	return true

func get_leaderboard(category: String = "score") -> Array:
	_ensure_leaderboard_seeds()
	var should_tick: bool = _leaderboard_should_tick()
	var entries: Array = []
	for rival_name in leaderboard_seeds:
		var stats: Dictionary = leaderboard_seeds[rival_name]
		if should_tick:
			stats["score"] = max(0, int(stats["score"]) + randi_range(-8, 14))
			stats["kills"] = max(0, int(stats["kills"]) + randi_range(-1, 2))
			stats["stash_worth"] = max(0, int(stats["stash_worth"]) + randi_range(-80, 180))
			if randf() < 0.01:
				stats["pets"] = min(30, int(stats["pets"]) + 1)
			if randf() < 0.008:
				stats["extractions"] = int(stats["extractions"]) + 1
			if randf() < 0.005:
				stats["level"] = min(MAX_LEVEL, int(stats["level"]) + 1)
			if randf() < 0.02:
				stats["arena"] = max(0, int(stats.get("arena", 0)) + randi_range(-20, 40))
		entries.append({
			"name": rival_name, "value": int(stats.get(category, 0)), "is_player": false,
			"portrait": stats.get("portrait", "portrait_1"), "title": stats.get("title", ""),
			"badges": stats.get("badges", []), "gear": stats.get("gear", {}),
			"level": int(stats.get("level", 1)), "kills": int(stats.get("kills", 0)),
			"deaths": int(stats.get("deaths", 1)), "pets": int(stats.get("pets", 0)),
		})
	var player_value: int
	match category:
		"kills":
			player_value = stat_enemies_killed
		"pets":
			player_value = owned_pet_instances.size()
		"stash_worth":
			player_value = get_total_value()
		"extractions":
			player_value = stat_extractions
		"level":
			player_value = player_level
		"arena":
			player_value = arena_rank_points
		_:
			player_value = player_score
	entries.append({
		"name": player_name if player_name != "" else "You", "value": player_value, "is_player": true,
		"portrait": player_portrait_id if player_portrait_id != "" else "portrait_1", "title": "",
		"badges": owned_badges, "gear": equipped_items,
		"level": player_level, "kills": stat_enemies_killed, "deaths": stat_deaths,
		"pets": owned_pet_instances.size(),
	})
	entries.sort_custom(func(a, b): return a["value"] > b["value"])
	return entries

# The same 100-name rival pool as the regular Leaderboard, but ranked by
# Rank Points instead - each entry carries its own rank_full_idx so the
# UI can show the actual rank icon/name (Stray 3 through Syndicate 1)
# next to every row, not just a bare number.
func get_ranked_leaderboard() -> Array:
	_ensure_leaderboard_seeds()
	var should_tick: bool = _leaderboard_should_tick()
	var entries: Array = []
	for rival_name in leaderboard_seeds:
		var stats: Dictionary = leaderboard_seeds[rival_name]
		var rp: int = int(stats.get("rank_points", 0))
		if should_tick:
			rp = max(0, rp + randi_range(-2, 4))
		stats["rank_points"] = rp
		entries.append({
			"name": rival_name, "value": rp, "rank_full_idx": get_rank_full_index_for_points(rp), "is_player": false,
			"portrait": stats.get("portrait", "portrait_1"), "title": stats.get("title", ""),
			"badges": stats.get("badges", []), "gear": stats.get("gear", {}),
			"level": int(stats.get("level", 1)), "kills": int(stats.get("kills", 0)),
			"deaths": int(stats.get("deaths", 1)), "pets": int(stats.get("pets", 0)),
			"is_tech_test_veteran": bool(stats.get("is_tech_test_veteran", false)),
		})
	entries.append({
		"name": player_name if player_name != "" else "You", "value": rank_points, "rank_full_idx": get_rank_full_index(), "is_player": true,
		"portrait": player_portrait_id if player_portrait_id != "" else "portrait_1", "title": "",
		"badges": owned_badges, "gear": equipped_items,
		"level": player_level, "kills": stat_enemies_killed, "deaths": stat_deaths,
		"pets": owned_pet_instances.size(),
	})
	entries.sort_custom(func(a, b): return a["value"] > b["value"])
	return entries

# --- Achievements: checked opportunistically (every save_game() call,
# which already happens after most meaningful state changes) rather
# than wired into every individual trigger point. Cheap to re-check
# since the list is short and each condition is a simple comparison.
const ACHIEVEMENTS := {
	"first_blood": {"name": "First Blood", "desc": "Kill your first enemy.", "icon": "combat"},
	"century": {"name": "Century", "desc": "Kill 100 enemies total.", "icon": "combat"},
	"thousand_cuts": {"name": "Death by a Thousand Cuts", "desc": "Kill 1,000 enemies total.", "icon": "combat"},
	"extraction_expert": {"name": "Extraction Expert", "desc": "Successfully extract 10 times.", "icon": "vehicle"},
	"seasoned_operative": {"name": "Seasoned Operative", "desc": "Successfully extract 50 times.", "icon": "vehicle"},
	"deep_pockets": {"name": "Deep Pockets", "desc": "Have 100,000 Rubles at once.", "icon": "money"},
	"millionaire": {"name": "Millionaire", "desc": "Have 1,000,000 Rubles at once.", "icon": "money"},
	"pet_collector": {"name": "Pet Collector", "desc": "Own 5 pets.", "icon": "recruits"},
	"menagerie": {"name": "Menagerie", "desc": "Own 15 pets.", "icon": "recruits"},
	"egg_hatcher": {"name": "Egg-cellent", "desc": "Hatch 10 Eggs.", "icon": "gear"},
	"loom_bound": {"name": "Ten Legs, One Bond", "desc": "Earn the Loom-weaver.", "icon": "recruits"},
	"ghost_whisperer": {"name": "Ghost Whisperer", "desc": "Recruit the Wandering Ghost.", "icon": "ghost_kill"},
	"tamer": {"name": "Tamer", "desc": "Pacify a shadow-beast at a Spectral Bowl and extract with it.", "icon": "recruits"},
	"bloodline_initiate": {"name": "Into the Refuge", "desc": "Earn your first Blood Shards in the Bloodline Gauntlet.", "icon": "refuge"},
	"bloodline_veteran": {"name": "Bloodline Veteran", "desc": "Reach Bloodline Tier 50.", "icon": "refuge"},
	"spike_slayer": {"name": "Spike Slayer", "desc": "Kill Spike.", "icon": "spike_crown"},
	"rattles_silenced": {"name": "Silence the Bones", "desc": "Kill Rattles.", "icon": "bone_crown"},
	"boneclock_bound": {"name": "Boneclock Bound", "desc": "Reach Level 10 and unlock Boneclock.", "icon": "skull"},
	"void_walker": {"name": "Void Walker", "desc": "Reach Level 20 and unlock Void Trench.", "icon": "compass"},
	"graveyard_shift": {"name": "Graveyard Shift", "desc": "Kill 100 enemies inside the Graveyard.", "icon": "skull"},
	"high_roller": {"name": "High Roller", "desc": "Open 50 crates at the Undertow's table.", "icon": "money"},
	"jackpot": {"name": "JACKPOT", "desc": "Pull a Multiversal item from any source.", "icon": "money"},
	"blueprint_master": {"name": "Blueprint Master", "desc": "Research 10 Blueprints.", "icon": "tech"},
	"level_50": {"name": "Level 50", "desc": "Reach Player Level 50.", "icon": "star"},
	"well_traveled": {"name": "Well Traveled", "desc": "Encounter enemies in Overgrowth, Boneclock, Void Trench, and the Graveyard.", "icon": "compass"},
	"close_call": {"name": "Cutting It Close", "desc": "Extract with less than 50 HP remaining.", "icon": "medical"},
	"big_score": {"name": "Big Score", "desc": "Extract with at least 5,000 worth of loot in one run.", "icon": "money"},

	# --- Combat milestones ---
	"first_steps": {"name": "First Steps", "desc": "Reach Player Level 5.", "icon": "star"},
	"ten_kills": {"name": "Getting Started", "desc": "Kill 10 enemies total.", "icon": "combat"},
	"five_hundred_kills": {"name": "Body Count", "desc": "Kill 500 enemies total.", "icon": "combat"},
	"twenty_five_hundred_kills": {"name": "Reaper's Apprentice", "desc": "Kill 2,500 enemies total.", "icon": "combat"},
	"five_thousand_kills": {"name": "Harbinger", "desc": "Kill 5,000 enemies total.", "icon": "skull"},

	# --- Enemy discovery ---
	"met_a_raider": {"name": "Meet the Raiders", "desc": "Encounter a Raider.", "icon": "combat"},
	"met_a_real_player": {"name": "Not Actually a Bot", "desc": "Encounter a Real Player enemy.", "icon": "combat"},
	"met_a_ghost": {"name": "Boo", "desc": "Encounter a Ghost.", "icon": "ghost_kill"},
	"met_a_wisp": {"name": "Will-o'-the-Wisp", "desc": "Encounter a Wisp.", "icon": "ghost_kill"},
	"met_a_ghoul": {"name": "Fresh Rot", "desc": "Encounter a Ghoul.", "icon": "combat"},
	"met_a_noxious_bat": {"name": "Rabies Shot Recommended", "desc": "Encounter a Noxious Bat.", "icon": "combat"},
	"met_a_toxic_waste": {"name": "Biohazard", "desc": "Encounter a Goblin.", "icon": "combat"},
	"met_a_marauder": {"name": "Scavenger's Scavenger", "desc": "Encounter a Marauder.", "icon": "combat"},
	"met_a_sentinel": {"name": "Standing Guard", "desc": "Encounter a Sentinel.", "icon": "combat"},

	# --- Extraction milestones ---
	"first_extraction": {"name": "Made It Out", "desc": "Successfully extract for the first time.", "icon": "vehicle"},
	"extraction_veteran": {"name": "Extraction Veteran", "desc": "Successfully extract 100 times.", "icon": "vehicle"},
	"sector_legend": {"name": "Sector Legend", "desc": "Successfully extract 250 times.", "icon": "vehicle"},

	# --- Death (the Sector doesn't forgive) ---
	"hard_to_kill": {"name": "Hard to Kill", "desc": "Die 10 times. You keep coming back anyway.", "icon": "skull"},
	"comes_back_anyway": {"name": "Comes Back Anyway", "desc": "Die 50 times. Still here.", "icon": "skull"},

	# --- Economy ---
	"getting_by": {"name": "Getting By", "desc": "Have 10,000 Rubles at once.", "icon": "money"},
	"half_a_million": {"name": "Half a Million", "desc": "Have 500,000 Rubles at once.", "icon": "money"},
	"first_sale": {"name": "First Sale", "desc": "Sell an item to a Trader.", "icon": "money"},
	"merchant": {"name": "Merchant", "desc": "Sell a total of 50,000 Rubles worth of gear to Traders.", "icon": "money"},
	"loot_goblin": {"name": "Loot Goblin", "desc": "Collect a lifetime total of 100,000 Rubles worth of loot.", "icon": "money"},
	"junk_hoarder": {"name": "Junk Hoarder", "desc": "Have 1,000 Junk at once.", "icon": "gear"},
	"artifact_collector": {"name": "Artifact Collector", "desc": "Have 100 Artifacts at once.", "icon": "tech"},
	"alloy_baron": {"name": "Alloy Baron", "desc": "Have 500 Alloys at once.", "icon": "tech"},
	"soul_hoarder": {"name": "Soul Hoarder", "desc": "Have 1,000 Souls at once.", "icon": "soul_wisp"},

	# --- Gear ---
	"fully_geared": {"name": "Fully Geared", "desc": "Have all 6 equipment slots filled at once.", "icon": "gear"},
	"first_blueprint": {"name": "First Blueprint", "desc": "Research your first Blueprint.", "icon": "tech"},
	"master_engineer": {"name": "Master Engineer", "desc": "Research 25 Blueprints.", "icon": "tech"},
	"mythic_owner": {"name": "Mythic", "desc": "Own a Mythic-rarity item.", "icon": "star"},
	"exotic_owner": {"name": "Exotic Taste", "desc": "Own an Exotic-rarity item.", "icon": "star"},
	"skin_collector": {"name": "Skin Collector", "desc": "Own 5 weapon or armor skins.", "icon": "gear"},
	"skin_fanatic": {"name": "Skin Fanatic", "desc": "Own 20 weapon or armor skins.", "icon": "gear"},
	"well_armed": {"name": "Well Armed", "desc": "Equip a weapon with at least one attachment installed.", "icon": "gear"},

	# --- Stash ---
	"stash_worth_10k": {"name": "Building a Stockpile", "desc": "Have 10,000 Rubles worth of gear in your Stash.", "icon": "money"},
	"stash_worth_100k": {"name": "Warehouse", "desc": "Have 100,000 Rubles worth of gear in your Stash.", "icon": "money"},
	"pack_rat": {"name": "Pack Rat", "desc": "Have 50 items in your Stash at once.", "icon": "gear"},

	# --- Skills ---
	"specialist": {"name": "Specialist", "desc": "Max out any single Skill Tree node.", "icon": "star"},
	"well_rounded": {"name": "Well Rounded", "desc": "Put at least one point into every Skill Tree node.", "icon": "star"},
	"grand_master": {"name": "Grand Master", "desc": "Max out every Skill Tree node.", "icon": "star"},

	# --- Pets ---
	"new_friend": {"name": "New Friend", "desc": "Own your first pet.", "icon": "recruits"},
	"zoo_keeper": {"name": "Zoo Keeper", "desc": "Own 30 pets.", "icon": "recruits"},
	"mythic_companion": {"name": "Mythic Companion", "desc": "Hatch a Mythic-rarity pet.", "icon": "recruits"},

	# --- Hideout ---
	"gym_rat": {"name": "Gym Rat", "desc": "Put a level into any Hideout upgrade.", "icon": "medical"},
	"hideout_investor": {"name": "Hideout Investor", "desc": "Reach a combined total of 10 levels across all Hideout upgrades.", "icon": "gear"},

	# --- Quests (Contracts) ---
	"first_contract": {"name": "First Contract", "desc": "Complete a contract for any contact.", "icon": "contact"},
	"five_contracts": {"name": "Reliable", "desc": "Complete 5 contracts.", "icon": "contact"},
	"fifteen_contracts": {"name": "In Demand", "desc": "Complete 15 contracts.", "icon": "contact"},
	"contract_completionist": {"name": "Nothing Left Unsaid", "desc": "Complete every contract from every contact.", "icon": "star"},
	"echo_favorite": {"name": "Echo's Favorite", "desc": "Complete every contract Echo has to offer.", "icon": "contact"},
	"full_docket": {"name": "Full Docket", "desc": "Have all 3 contract slots active at once.", "icon": "contact"},

	# --- Bloodline Gauntlet ---
	"refuge_regular": {"name": "Refuge Regular", "desc": "Clear Level 1 of the Bloodline Gauntlet.", "icon": "refuge"},
	"deep_refuge": {"name": "Deep Refuge", "desc": "Clear Level 3 of the Bloodline Gauntlet.", "icon": "refuge"},
	"refuge_conqueror": {"name": "Refuge Conqueror", "desc": "Clear Level 5 of the Bloodline Gauntlet.", "icon": "refuge"},
	"blood_shard_hoarder": {"name": "Blood Shard Hoarder", "desc": "Have 500 Blood Shards at once.", "icon": "refuge"},

	# --- Salvaged Beasts & Spectral Tide ---
	"beast_tamer": {"name": "Beast Tamer", "desc": "Reach Salvaged Beasts Tier 50.", "icon": "recruits"},
	"beast_master": {"name": "Beast Master", "desc": "Reach Salvaged Beasts Tier 200 (max).", "icon": "recruits"},
	"tide_rider": {"name": "Tide Rider", "desc": "Reach Spectral Tide Tier 50.", "icon": "event"},
	"tide_master": {"name": "Tide Master", "desc": "Reach Spectral Tide Tier 200 (max).", "icon": "event"},

	# --- Justin's Decompilation Rig ---
	"code_breaker": {"name": "Code Breaker", "desc": "Decipher your first Engram.", "icon": "cipher"},
	"master_decompiler": {"name": "Master Decompiler", "desc": "Decipher 10 Engrams.", "icon": "cipher"},

	# --- Level ---
	"level_100": {"name": "Level 100", "desc": "Reach Player Level 100.", "icon": "star"},
	"level_250": {"name": "Level 250", "desc": "Reach Player Level 250.", "icon": "star"},
	"max_level": {"name": "The End?", "desc": "Reach Player Level 500 (max).", "icon": "star"},

	# --- Graveyard ---
	"graveyard_regular": {"name": "Regular Visitor", "desc": "Kill 25 enemies inside the Graveyard.", "icon": "skull"},
	"graveyard_master": {"name": "Master of the Graveyard", "desc": "Kill 500 enemies inside the Graveyard.", "icon": "skull"},

	# --- Crates ---
	"first_crate": {"name": "First Crate", "desc": "Open a crate at the Undertow's table.", "icon": "money"},
	"crate_addict": {"name": "Crate Addict", "desc": "Open 200 crates at the Undertow's table.", "icon": "money"},

	# --- Store ---
	"monthly_supporter": {"name": "Monthly Supporter", "desc": "Own the Monthly Pass.", "icon": "money"},
	"double_trouble": {"name": "Double Trouble", "desc": "Own Permanent Double XP.", "icon": "money"},
	"need_for_speed": {"name": "Need for Speed", "desc": "Own Fast Hatching.", "icon": "money"},

	# --- Ranked ---
	"ranked_rookie": {"name": "Enter the Ladder", "desc": "Successfully extract from your first Ranked raid.", "icon": "compass"},
	"ranked_enforcer": {"name": "Enforcer Rank", "desc": "Reach Enforcer rank or higher.", "icon": "combat"},
	"ranked_spectre": {"name": "Spectre Rank", "desc": "Reach Spectre rank or higher.", "icon": "soul_wisp"},
	"ranked_peak": {"name": "Peak of the Sector", "desc": "Reach Syndicate 1, the highest rank in the game.", "icon": "bone_crown"},
	"leaderboard_podium": {"name": "On the Podium", "desc": "Finish a Leaderboard season in the top 3.", "icon": "star"},

	# --- Scav ---
	"scav_life": {"name": "Scav Life", "desc": "Successfully extract as a Scav 10 times.", "icon": "vehicle"},

	# --- Rose & Plushies ---
	"rose_met": {"name": "Nice to Meet You", "desc": "Talk to Rose in the Hideout.", "icon": "recruits"},
	"plushie_pioneer": {"name": "Plushie Pioneer", "desc": "Have Rose turn a Plushie into a pet.", "icon": "recruits"},
	"plushie_collector": {"name": "The Whole Shelf", "desc": "Own 5 Plushie-buffed pets.", "icon": "recruits"},
	"tag_organizer": {"name": "Everything In Its Place", "desc": "Tag 3 cases in your Stash or Backpack Storage.", "icon": "gear"},
	"armored_up": {"name": "Armored Up", "desc": "Equip a piece of gear with the Armor stat.", "icon": "medical"},
}
var unlocked_achievements: Dictionary = {}  # id -> date string

func check_achievements() -> void:
	_maybe_unlock("first_blood", stat_enemies_killed >= 1)
	_maybe_unlock("century", stat_enemies_killed >= 100)
	_maybe_unlock("thousand_cuts", stat_enemies_killed >= 1000)
	_maybe_unlock("extraction_expert", stat_extractions >= 10)
	_maybe_unlock("seasoned_operative", stat_extractions >= 50)
	_maybe_unlock("deep_pockets", rubles >= 100000)
	_maybe_unlock("millionaire", rubles >= 1000000)
	var pet_count: int = owned_pet_instances.size()
	_maybe_unlock("pet_collector", pet_count >= 5)
	_maybe_unlock("menagerie", pet_count >= 15)
	_maybe_unlock("egg_hatcher", stat_eggs_hatched >= 10)
	_maybe_unlock("loom_bound", owned_pets.has(LOOM_WEAVER_PET_ID))
	_maybe_unlock("ghost_whisperer", ghost_recruited)
	var has_pacified_pet: bool = false
	for id in owned_pet_instances.keys():
		if id.begins_with("pacified_"):
			has_pacified_pet = true
			break
	_maybe_unlock("tamer", has_pacified_pet)
	_maybe_unlock("bloodline_initiate", blood_shards > 0 or bloodline_tier > 0)
	_maybe_unlock("bloodline_veteran", bloodline_tier >= 50)
	_maybe_unlock("spike_slayer", discovered_enemies.has("spike"))
	_maybe_unlock("rattles_silenced", discovered_enemies.has("rattles"))
	_maybe_unlock("boneclock_bound", player_level >= 10)
	_maybe_unlock("void_walker", player_level >= 20)
	_maybe_unlock("graveyard_shift", graveyard_kills >= 100)
	_maybe_unlock("high_roller", stat_crates_opened >= 50)
	_maybe_unlock("jackpot", achievement_flag_multiversal_pull)
	_maybe_unlock("blueprint_master", stat_blueprints_researched >= 10)
	_maybe_unlock("level_50", player_level >= 50)
	_maybe_unlock("well_traveled", discovered_enemies.has("raider") and discovered_enemies.has("skeleton") and discovered_enemies.has("rift_wraith") and graveyard_kills > 0)
	_maybe_unlock("close_call", achievement_flag_close_call)
	_maybe_unlock("big_score", carried_value >= 5000)

	# --- Ranked ---
	_maybe_unlock("ranked_rookie", rank_points > 0)
	_maybe_unlock("ranked_enforcer", get_rank_tier_index(get_rank_full_index()) >= 2)
	_maybe_unlock("ranked_spectre", get_rank_tier_index(get_rank_full_index()) >= 4)
	_maybe_unlock("ranked_peak", is_max_rank(get_rank_full_index()))
	_maybe_unlock("leaderboard_podium", owned_badges.has("rank_1_champion") or owned_badges.has("rank_2_elite") or owned_badges.has("rank_3_podium"))

	# --- Scav ---
	_maybe_unlock("scav_life", stat_scav_extractions >= 10)

	# --- Combat milestones ---
	_maybe_unlock("first_steps", player_level >= 5)
	_maybe_unlock("ten_kills", stat_enemies_killed >= 10)
	_maybe_unlock("five_hundred_kills", stat_enemies_killed >= 500)
	_maybe_unlock("twenty_five_hundred_kills", stat_enemies_killed >= 2500)
	_maybe_unlock("five_thousand_kills", stat_enemies_killed >= 5000)

	# --- Enemy discovery ---
	_maybe_unlock("met_a_raider", discovered_enemies.has("raider"))
	_maybe_unlock("met_a_real_player", discovered_enemies.has("real_player"))
	_maybe_unlock("met_a_ghost", discovered_enemies.has("ghost"))
	_maybe_unlock("met_a_wisp", discovered_enemies.has("wisp"))
	_maybe_unlock("met_a_ghoul", discovered_enemies.has("ghoul"))
	_maybe_unlock("met_a_noxious_bat", discovered_enemies.has("noxious_bat"))
	_maybe_unlock("met_a_toxic_waste", discovered_enemies.has("toxic_waste"))
	_maybe_unlock("met_a_marauder", discovered_enemies.has("marauder"))
	_maybe_unlock("met_a_sentinel", discovered_enemies.has("sentinel"))

	# --- Extraction milestones ---
	_maybe_unlock("first_extraction", stat_extractions >= 1)
	_maybe_unlock("extraction_veteran", stat_extractions >= 100)
	_maybe_unlock("sector_legend", stat_extractions >= 250)

	# --- Death ---
	_maybe_unlock("hard_to_kill", stat_deaths >= 10)
	_maybe_unlock("comes_back_anyway", stat_deaths >= 50)

	# --- Economy ---
	_maybe_unlock("getting_by", rubles >= 10000)
	_maybe_unlock("half_a_million", rubles >= 500000)
	_maybe_unlock("first_sale", stat_total_sold >= 1)
	_maybe_unlock("merchant", stat_total_sold >= 50000)
	_maybe_unlock("loot_goblin", stat_total_loot_collected >= 100000)
	_maybe_unlock("junk_hoarder", junk >= 1000)
	_maybe_unlock("artifact_collector", artifacts >= 100)
	_maybe_unlock("alloy_baron", alloys >= 500)
	_maybe_unlock("soul_hoarder", souls >= 1000)

	# --- Gear ---
	var filled_slots := 0
	for slot in equipped_items:
		if equipped_items[slot] != null:
			filled_slots += 1
	_maybe_unlock("fully_geared", filled_slots >= equipped_items.size())
	_maybe_unlock("first_blueprint", stat_blueprints_researched >= 1)
	_maybe_unlock("master_engineer", stat_blueprints_researched >= 25)
	var has_mythic := false
	var has_exotic := false
	for it in stash_items:
		var r: String = it.get("rarity", "")
		if r == "mythic":
			has_mythic = true
		elif r == "exotic":
			has_exotic = true
	if not (has_mythic and has_exotic):
		for slot in equipped_items:
			var eq_item = equipped_items[slot]
			if eq_item == null:
				continue
			var r2: String = eq_item.get("rarity", "")
			if r2 == "mythic":
				has_mythic = true
			elif r2 == "exotic":
				has_exotic = true
	_maybe_unlock("mythic_owner", has_mythic)
	_maybe_unlock("exotic_owner", has_exotic)
	_maybe_unlock("skin_collector", owned_skins.size() >= 5)
	_maybe_unlock("skin_fanatic", owned_skins.size() >= 20)
	var weapon_item = equipped_items.get("weapon")
	_maybe_unlock("well_armed", weapon_item != null and weapon_item.has("attachments") and not weapon_item["attachments"].is_empty())

	# --- Stash ---
	var total_value := get_total_value()
	_maybe_unlock("stash_worth_10k", total_value >= 10000)
	_maybe_unlock("stash_worth_100k", total_value >= 100000)
	_maybe_unlock("pack_rat", stash_items.size() >= 50)

	# --- Skills ---
	var any_maxed := false
	var all_started := true
	var all_maxed := true
	for key in upgrades:
		var lvl: int = int(upgrades[key].get("level", 0))
		var mx: int = int(upgrades[key].get("max_level", 0))
		if lvl >= mx and mx > 0:
			any_maxed = true
		else:
			all_maxed = false
		if lvl <= 0:
			all_started = false
	_maybe_unlock("specialist", any_maxed)
	_maybe_unlock("well_rounded", all_started)
	_maybe_unlock("grand_master", all_maxed)

	# --- Pets ---
	_maybe_unlock("new_friend", pet_count >= 1)
	_maybe_unlock("zoo_keeper", pet_count >= 30)
	var has_mythic_pet := false
	for id in owned_pet_instances.keys():
		if String(owned_pet_instances[id].get("rarity", "")) == "mythic":
			has_mythic_pet = true
			break
	_maybe_unlock("mythic_companion", has_mythic_pet)

	# --- Hideout ---
	var hideout_started := false
	var hideout_level_sum := 0
	for key in hideout_upgrades:
		var lvl: int = int(hideout_upgrades[key].get("level", 0))
		hideout_level_sum += lvl
		if lvl > 0:
			hideout_started = true
	_maybe_unlock("gym_rat", hideout_started)
	_maybe_unlock("hideout_investor", hideout_level_sum >= 10)

	# --- Quests (Contracts) ---
	var quests_done := 0
	for key in QUEST_DATA.keys():
		if is_quest_done(key):
			quests_done += 1
	_maybe_unlock("first_contract", quests_done >= 1)
	_maybe_unlock("five_contracts", quests_done >= 5)
	_maybe_unlock("fifteen_contracts", quests_done >= 15)
	_maybe_unlock("contract_completionist", quests_done >= QUEST_DATA.size())
	var echo_chain := _npc_chain("echo")
	var echo_all_done: bool = not echo_chain.is_empty()
	for key in echo_chain:
		if not is_quest_done(key):
			echo_all_done = false
			break
	_maybe_unlock("echo_favorite", echo_all_done)
	_maybe_unlock("full_docket", active_quest_count() >= MAX_ACTIVE_QUESTS)

	# --- Bloodline Gauntlet ---
	_maybe_unlock("refuge_regular", gauntlet_best_level >= 1)
	_maybe_unlock("deep_refuge", gauntlet_best_level >= 3)
	_maybe_unlock("refuge_conqueror", gauntlet_best_level >= 5)
	_maybe_unlock("blood_shard_hoarder", blood_shards >= 500)

	# --- Salvaged Beasts & Spectral Tide ---
	_maybe_unlock("beast_tamer", salvaged_beasts_tier >= 50)
	_maybe_unlock("beast_master", salvaged_beasts_tier >= SALVAGED_BEASTS_MAX_TIER)
	_maybe_unlock("tide_rider", battle_pass_tier >= 50)
	_maybe_unlock("tide_master", battle_pass_tier >= 200)

	# --- Justin's Decompilation Rig ---
	_maybe_unlock("code_breaker", engrams.size() >= 1)
	_maybe_unlock("master_decompiler", engrams.size() >= 10)

	# --- Level ---
	_maybe_unlock("level_100", player_level >= 100)
	_maybe_unlock("level_250", player_level >= 250)
	_maybe_unlock("max_level", player_level >= MAX_LEVEL)

	# --- Graveyard ---
	_maybe_unlock("graveyard_regular", graveyard_kills >= 25)
	_maybe_unlock("graveyard_master", graveyard_kills >= 500)

	# --- Crates ---
	_maybe_unlock("first_crate", stat_crates_opened >= 1)
	_maybe_unlock("crate_addict", stat_crates_opened >= 200)

	# --- Store ---
	_maybe_unlock("monthly_supporter", monthly_pass_owned)
	_maybe_unlock("double_trouble", double_xp_owned)
	_maybe_unlock("need_for_speed", fast_hatching_owned)

	# --- Rose & Plushies ---
	var plushie_pet_count := 0
	for id in owned_pet_instances.keys():
		if String(id).begins_with("plushie_"):
			plushie_pet_count += 1
	_maybe_unlock("rose_met", rose_talked_to)
	_maybe_unlock("plushie_pioneer", plushie_pet_count >= 1)
	_maybe_unlock("plushie_collector", plushie_pet_count >= 5)
	var tagged_count := 0
	for it in stash_items:
		if String(it.get("tag_text", "")) != "":
			tagged_count += 1
	for it in backpack_storage:
		if String(it.get("tag_text", "")) != "":
			tagged_count += 1
	_maybe_unlock("tag_organizer", tagged_count >= 3)
	var has_armor_gear := false
	for slot in equipped_items:
		var eq = equipped_items[slot]
		if eq != null and (eq.get("stat_type", "") == "armor" or eq.get("stat_type_2", "") == "armor"):
			has_armor_gear = true
			break
	_maybe_unlock("armored_up", has_armor_gear)

func _maybe_unlock(id: String, condition: bool) -> void:
	if condition and not unlocked_achievements.has(id):
		unlocked_achievements[id] = Time.get_date_string_from_system()
		toast_requested.emit("Achievement unlocked: %s" % ACHIEVEMENTS.get(id, {}).get("name", id))
var player_xp: int = 0
var player_bio: String = "Just another operative trying to make it out alive."
var player_portrait_id: String = "portrait_1"

var stat_total_loot_collected: int = 0
var stat_total_sold: int = 0
var stat_enemies_killed: int = 0
var stat_deaths: int = 0
var stat_extractions: int = 0
var stat_scav_extractions: int = 0
var stat_crates_opened: int = 0
var stat_blueprints_researched: int = 0
var stat_eggs_hatched: int = 0
var achievement_flag_multiversal_pull: bool = false
var achievement_flag_close_call: bool = false

func xp_needed_for_level(level: int) -> int:
	return 80 + level * 40

func grant_xp(amount: int) -> void:
	if amount <= 0 or player_level >= MAX_LEVEL:
		return
	amount = int(round(float(amount) * (1.0 + get_upgrade_bonus("xp_boost"))))
	if double_xp_owned:
		amount *= 2
	player_xp += amount
	while player_level < MAX_LEVEL and player_xp >= xp_needed_for_level(player_level):
		player_xp -= xp_needed_for_level(player_level)
		player_level += 1
		add_score(50)
		toast_requested.emit("Level Up! Now Level %d" % player_level)
	xp_changed.emit()

# --- Prestige: once MAX_LEVEL is fully climbed, optionally reset back to
# Level 1 in exchange for a permanent, ever-climbing Prestige counter and
# a one-time reward - something to chase once the normal level ladder
# runs out. Deliberately narrow: only player_level/player_xp reset,
# nothing else (currencies, gear, pets, unlocks, other progression
# tracks) is touched.
var prestige_level: int = 0

func can_prestige() -> bool:
	return player_level >= MAX_LEVEL

func prestige() -> bool:
	if not can_prestige():
		return false
	prestige_level += 1
	player_level = 1
	player_xp = 0
	var reward_rubles: int = 5000 * prestige_level
	var reward_skill_points: int = 3
	add_currency("rubles", reward_rubles)
	skill_points += reward_skill_points
	toast_requested.emit("Prestige %d! Back to Level 1 - %d Rubles and %d Skill Points as thanks for the climb." % [prestige_level, reward_rubles, reward_skill_points])
	Sfx.play_reveal()
	xp_changed.emit()
	save_game()
	return true

func record_kill() -> void:
	stat_enemies_killed += 1
	add_score(5)
	if in_graveyard_run:
		graveyard_kills += 1
		_maybe_grant_loom_weaver()

func record_loot_collected(value: int) -> void:
	stat_total_loot_collected += value

# --- World Clock: a persistent day/night cycle computed straight from
# wall-clock time (no stored state needed) - always running, even with
# the game closed, so the "current sector time" is always meaningful.
const WORLD_CYCLE_REAL_SECONDS := 5400.0  # one in-game day = 90 real minutes
const WORLD_CYCLE_START_OFFSET := 6.3  # arbitrary phase so times feel varied, not tied to real clock

func get_world_time_hours() -> float:
	var t := Time.get_unix_time_from_system()
	var frac := fmod(t, WORLD_CYCLE_REAL_SECONDS) / WORLD_CYCLE_REAL_SECONDS
	return fmod(frac * 24.0 + WORLD_CYCLE_START_OFFSET, 24.0)

func format_world_time() -> String:
	var h := get_world_time_hours()
	var hh := int(h)
	var mm := int((h - float(hh)) * 60.0)
	return "%02d:%02d" % [hh, mm]

func is_world_currently_day() -> bool:
	var h := get_world_time_hours()
	return h >= 6.0 and h < 19.5

# The Day button shows a time rotating through 05:00-15:00, the Night
# button rotates through 15:00-05:00 (wrapping past midnight) - both
# driven by the same underlying always-on clock so they're in sync and
# genuinely change over a play session, not fixed at launch.
func get_day_display_hour() -> float:
	var frac: float = fmod(get_world_time_hours(), 24.0) / 24.0
	return 5.0 + frac * 10.0

func get_night_display_hour() -> float:
	var frac: float = fmod(get_world_time_hours(), 24.0) / 24.0
	return fmod(15.0 + frac * 14.0, 24.0)

func format_hour(h: float) -> String:
	var hh := int(h)
	var mm := int((h - float(hh)) * 60.0)
	return "%02d:%02d" % [hh, mm]

# 0.0 = full daylight brightness, 1.0 = pitch dark - later hours within
# whichever range the player picked read as darker, earlier as brighter.
var selected_raid_hour: float = 10.0

func get_darkness_factor_for_hour(h: float, night: bool) -> float:
	if night:
		# 15:00 (dusk, just turning dark) -> lightest night value; 00:00
		# (deep night) -> darkest; 05:00 (near dawn) -> lightening again.
		var dist_from_midnight: float = min(abs(h - 0.0), abs(h - 24.0))
		return clamp(1.0 - dist_from_midnight / 9.0, 0.35, 1.0)
	else:
		# 05:00 (early, brighter) -> lightest; 15:00 (later, dimmer
		# afternoon haze) -> darkest of the day range.
		return clamp((h - 5.0) / 10.0, 0.0, 1.0)

# --- Map selection: which raid map the player deploys to. ---
# --- Recruits: bring a companion into the raid with you. Costs Rubles
# up front, follows you around, and fights alongside you.
var selected_recruit: String = ""
const RECRUITS := {
	"clarity": {"label": "Clarity", "cost": 2000, "color": Color(0.55, 0.25, 0.6, 1), "scale": 1.0, "base_damage": 14, "quote": "\"Stay close. I've got you.\""},
	"sorrow": {"label": "Sorrow", "cost": 2000, "color": Color(0.3, 0.34, 0.44, 1), "scale": 1.0, "base_damage": 14, "quote": "\"Let's just get this over with.\""},
	"glenn": {"label": "Glenn", "cost": 2000, "color": Color(0.3, 0.42, 0.2, 1), "scale": 1.0, "base_damage": 14, "quote": "\"Point me at somethin' and watch.\""},
	"big_crax": {"label": "Big Crax", "cost": 50000, "color": Color(0.55, 0.32, 0.1, 1), "scale": 2.6, "base_damage": 26, "quote": "\"Crax smash. Crax loot. Crax happy.\""},
}

# --- Pets: bought once at the Hideout's Pet Shop, then equipped in the
# doll's Pet slot. Unlike Recruits they don't fight - each just grants a
# small passive stat bonus (via the same stat_type/stat_value system
# gear uses) and follows you around as a visual companion in-raid.
# Ellie's own pink used to be hand-copied as a literal in RosePanel.gd
# and StorePanel.gd (2 separate spots re-typing the same color instead
# of referencing this one) - both now read this constant instead.
const ELLIE_ICON_COLOR := Color(1.0, 0.65, 0.9, 1)
const PET_CATALOG := {
	"rex": {"name": "Rex", "cost": 3000, "color": Color(0.55, 0.4, 0.22, 1), "stat_type": "speed", "stat_value": 15.0, "icon_key": "pet_dog", "speed_mult": 1.0, "quote": "\"Loyal, and fast on his feet.\""},
	"whiskers": {"name": "Whiskers", "cost": 3000, "color": Color(0.32, 0.32, 0.36, 1), "stat_type": "max_health", "stat_value": 20.0, "icon_key": "pet_cat", "speed_mult": 0.85, "quote": "\"Nine lives, shared with you.\""},
	"sparky": {"name": "Sparky", "cost": 4500, "color": Color(0.65, 0.72, 0.78, 1), "stat_type": "fire_rate", "stat_value": 0.03, "icon_key": "pet_drone", "speed_mult": 1.3, "quote": "\"A little drone with a big battery.\""},
	"shadow": {"name": "Shadow", "cost": 4000, "color": Color(0.14, 0.14, 0.17, 1), "stat_type": "damage", "stat_value": 6.0, "icon_key": "pet_crow", "speed_mult": 1.15, "quote": "\"Watches from above, strikes when you do.\""},
	"biscuit": {"name": "Biscuit", "cost": 3500, "color": Color(0.75, 0.6, 0.35, 1), "stat_type": "loot_sense", "stat_value": 0.012, "icon_key": "pet_dog", "speed_mult": 1.05, "quote": "\"Sniffs out loot before you even see it.\""},
	"prowl": {"name": "Prowl", "cost": 5000, "color": Color(0.45, 0.55, 0.5, 1), "stat_type": "crit_chance", "stat_value": 0.015, "icon_key": "pet_lizard", "speed_mult": 1.1, "quote": "\"Finds the weak spot every time.\""},
	"scout": {"name": "Scout", "cost": 4200, "color": Color(0.7, 0.55, 0.35, 1), "stat_type": "vision_range", "stat_value": 22.0, "icon_key": "pet_bird", "speed_mult": 1.25, "quote": "\"Sees the raid coming before you do.\""},
	"bramble": {"name": "Bramble", "cost": 5500, "color": Color(0.4, 0.6, 0.3, 1), "stat_type": "reload_speed", "stat_value": 0.025, "icon_key": "pet_lizard", "speed_mult": 0.95, "quote": "\"Slow to spook, quick to help you reload.\""},
}
var owned_pets: Array = []
var equipped_pet: String = ""

# --- Egg-hatchable pets: a much bigger pool, organized by rarity, only
# obtainable by hatching an Egg at the Salvaged Beasts screen. Reuses
# the 4 existing pet icon shapes (dog/cat/drone/crow) with different
# colors and stats for real variety without needing new art per pet.
const EGG_HATCH_SECONDS := {
	"common": 5.0, "uncommon": 12.0, "rare": 20.0, "epic": 40.0,
	"legendary": 60.0, "mythic": 80.0, "exotic": 100.0, "multiversal": 120.0,
}
const EGG_PET_POOL := {
	"common": [
		{"id": "mutt", "name": "Mutt", "color": Color(0.5, 0.42, 0.3, 1), "icon_key": "pet_dog", "stat_type": "speed", "stat_value": 6.0, "speed_mult": 1.0},
		{"id": "tabby", "name": "Tabby", "color": Color(0.55, 0.45, 0.3, 1), "icon_key": "pet_cat", "stat_type": "max_health", "stat_value": 8.0, "speed_mult": 0.9},
		{"id": "scraplet", "name": "Scraplet", "color": Color(0.5, 0.5, 0.5, 1), "icon_key": "pet_drone", "stat_type": "loot_sense", "stat_value": 0.01, "speed_mult": 1.1},
		{"id": "gecko", "name": "Gecko", "color": Color(0.4, 0.6, 0.35, 1), "icon_key": "pet_lizard", "stat_type": "speed", "stat_value": 5.0, "speed_mult": 1.15},
		{"id": "sparrow", "name": "Sparrow", "color": Color(0.55, 0.4, 0.3, 1), "icon_key": "pet_bird", "stat_type": "loot_sense", "stat_value": 0.008, "speed_mult": 1.05},
		{"id": "finch", "name": "Finch", "color": Color(0.6, 0.5, 0.35, 1), "icon_key": "pet_bird", "stat_type": "speed", "stat_value": 5.5, "speed_mult": 1.05},
		{"id": "salamander", "name": "Salamander", "color": Color(0.45, 0.55, 0.4, 1), "icon_key": "pet_lizard", "stat_type": "max_health", "stat_value": 7.0, "speed_mult": 0.95},
	],
	"uncommon": [
		{"id": "hound", "name": "Hound", "color": Color(0.45, 0.32, 0.18, 1), "icon_key": "pet_dog", "stat_type": "speed", "stat_value": 10.0, "speed_mult": 1.1},
		{"id": "lynx", "name": "Lynx", "color": Color(0.6, 0.55, 0.4, 1), "icon_key": "pet_cat", "stat_type": "crit_chance", "stat_value": 0.01, "speed_mult": 1.15},
		{"id": "rookdrone", "name": "Rook Drone", "color": Color(0.4, 0.42, 0.48, 1), "icon_key": "pet_drone", "stat_type": "reload_speed", "stat_value": 0.02, "speed_mult": 1.2},
		{"id": "raven", "name": "Raven", "color": Color(0.2, 0.2, 0.25, 1), "icon_key": "pet_crow", "stat_type": "damage", "stat_value": 3.0, "speed_mult": 1.1},
		{"id": "monitor", "name": "Monitor", "color": Color(0.35, 0.5, 0.3, 1), "icon_key": "pet_lizard", "stat_type": "max_health", "stat_value": 12.0, "speed_mult": 1.0},
		{"id": "kestrel", "name": "Kestrel", "color": Color(0.6, 0.42, 0.25, 1), "icon_key": "pet_bird", "stat_type": "vision_range", "stat_value": 20.0, "speed_mult": 1.2},
		{"id": "badger", "name": "Badger", "color": Color(0.35, 0.32, 0.3, 1), "icon_key": "pet_dog", "stat_type": "max_health", "stat_value": 14.0, "speed_mult": 0.95},
		{"id": "owlet", "name": "Owlet", "color": Color(0.5, 0.44, 0.3, 1), "icon_key": "pet_bird", "stat_type": "vision_range", "stat_value": 18.0, "speed_mult": 1.15},
	],
	"rare": [
		{"id": "direwolf", "name": "Direwolf", "color": Color(0.35, 0.35, 0.4, 1), "icon_key": "pet_dog", "stat_type": "damage", "stat_value": 5.0, "speed_mult": 1.2},
		{"id": "ashcat", "name": "Ashcat", "color": Color(0.6, 0.3, 0.25, 1), "icon_key": "pet_cat", "stat_type": "max_health", "stat_value": 25.0, "speed_mult": 0.95},
		{"id": "sentrybot", "name": "Sentry-Bot", "color": Color(0.75, 0.6, 0.15, 1), "icon_key": "pet_drone", "stat_type": "fire_rate", "stat_value": 0.02, "speed_mult": 1.0},
		{"id": "nightowl", "name": "Night Owl", "color": Color(0.5, 0.4, 0.65, 1), "icon_key": "pet_crow", "stat_type": "vision_range", "stat_value": 30.0, "speed_mult": 1.25},
		{"id": "basilisk", "name": "Basilisk", "color": Color(0.3, 0.55, 0.4, 1), "icon_key": "pet_lizard", "stat_type": "damage", "stat_value": 6.0, "speed_mult": 1.1},
		{"id": "falconer", "name": "War Falcon", "color": Color(0.55, 0.5, 0.45, 1), "icon_key": "pet_bird", "stat_type": "crit_chance", "stat_value": 0.02, "speed_mult": 1.3},
		{"id": "shardback", "name": "Shardback", "color": Color(0.4, 0.6, 0.55, 1), "icon_key": "pet_lizard", "stat_type": "max_health", "stat_value": 28.0, "speed_mult": 1.0},
		{"id": "duskfalcon", "name": "Duskfalcon", "color": Color(0.45, 0.4, 0.55, 1), "icon_key": "pet_bird", "stat_type": "crit_chance", "stat_value": 0.018, "speed_mult": 1.28},
	],
	"epic": [
		{"id": "cinderfang", "name": "Cinderfang", "color": Color(0.85, 0.35, 0.1, 1), "icon_key": "pet_dog", "stat_type": "damage", "stat_value": 9.0, "speed_mult": 1.3},
		{"id": "voidling", "name": "Voidling", "color": Color(0.25, 0.1, 0.4, 1), "icon_key": "pet_cat", "stat_type": "crit_chance", "stat_value": 0.03, "speed_mult": 1.1},
		{"id": "hexdrone", "name": "Hex Drone", "color": Color(0.15, 0.75, 0.55, 1), "icon_key": "pet_drone", "stat_type": "ammo_reserve", "stat_value": 20.0, "speed_mult": 1.4},
		{"id": "stormcrow", "name": "Stormcrow", "color": Color(0.3, 0.55, 0.85, 1), "icon_key": "pet_crow", "stat_type": "speed", "stat_value": 18.0, "speed_mult": 1.5},
		{"id": "venomtail", "name": "Venomtail", "color": Color(0.5, 0.85, 0.25, 1), "icon_key": "pet_lizard", "stat_type": "damage", "stat_value": 10.0, "speed_mult": 1.25},
		{"id": "gale_hawk", "name": "Gale Hawk", "color": Color(0.65, 0.8, 0.9, 1), "icon_key": "pet_bird", "stat_type": "speed", "stat_value": 20.0, "speed_mult": 1.55},
		{"id": "emberkit", "name": "Emberkit", "color": Color(0.9, 0.45, 0.15, 1), "icon_key": "pet_cat", "stat_type": "damage", "stat_value": 8.5, "speed_mult": 1.2},
		{"id": "rimefang", "name": "Rimefang", "color": Color(0.6, 0.8, 0.9, 1), "icon_key": "pet_dog", "stat_type": "fire_rate", "stat_value": 0.022, "speed_mult": 1.35},
	],
	"legendary": [
		{"id": "bloodfang_wolf", "name": "Bloodfang", "color": Color(0.55, 0.05, 0.08, 1), "icon_key": "pet_dog", "stat_type": "damage", "stat_value": 14.0, "speed_mult": 1.35},
		{"id": "phantomcat", "name": "Phantom Cat", "color": Color(0.75, 0.78, 0.85, 0.85), "icon_key": "pet_cat", "stat_type": "crit_chance", "stat_value": 0.05, "speed_mult": 1.3},
		{"id": "aegisdrone", "name": "Aegis Drone", "color": Color(0.9, 0.75, 0.2, 1), "icon_key": "pet_drone", "stat_type": "max_health", "stat_value": 45.0, "speed_mult": 1.1},
		{"id": "wyrmling", "name": "Wyrmling", "color": Color(0.8, 0.2, 0.15, 1), "icon_key": "pet_lizard", "stat_type": "damage", "stat_value": 16.0, "speed_mult": 1.2},
		{"id": "thunderbird", "name": "Thunderbird", "color": Color(0.9, 0.85, 0.3, 1), "icon_key": "pet_bird", "stat_type": "fire_rate", "stat_value": 0.035, "speed_mult": 1.4},
		{"id": "duskviper", "name": "Duskviper", "color": Color(0.5, 0.15, 0.55, 1), "icon_key": "pet_lizard", "stat_type": "crit_chance", "stat_value": 0.045, "speed_mult": 1.3},
		{"id": "stormtalon", "name": "Stormtalon", "color": Color(0.3, 0.4, 0.85, 1), "icon_key": "pet_crow", "stat_type": "damage", "stat_value": 15.0, "speed_mult": 1.45},
	],
	"mythic": [
		{"id": "emberwolf", "name": "Emberwolf", "color": Color(1.0, 0.45, 0.1, 1), "icon_key": "pet_dog", "stat_type": "fire_rate", "stat_value": 0.05, "speed_mult": 1.45},
		{"id": "spectralynx", "name": "Spectralynx", "color": Color(0.55, 0.85, 0.95, 1), "icon_key": "pet_cat", "stat_type": "speed", "stat_value": 28.0, "speed_mult": 1.6},
		{"id": "chronowing", "name": "Chronowing", "color": Color(0.7, 0.55, 0.95, 1), "icon_key": "pet_bird", "stat_type": "reload_speed", "stat_value": 0.06, "speed_mult": 1.5},
		{"id": "voidhound", "name": "Voidhound", "color": Color(0.2, 0.1, 0.35, 1), "icon_key": "pet_dog", "stat_type": "crit_chance", "stat_value": 0.055, "speed_mult": 1.5},
		{"id": "aurorawing", "name": "Aurorawing", "color": Color(0.55, 0.95, 0.85, 1), "icon_key": "pet_bird", "stat_type": "max_health", "stat_value": 60.0, "speed_mult": 1.4},
	],
	"exotic": [
		{"id": "genesis_hawk", "name": "Genesis Hawk", "color": Color(1.0, 0.85, 0.3, 1), "icon_key": "pet_crow", "stat_type": "damage", "stat_value": 20.0, "speed_mult": 1.5},
		{"id": "riftlurker", "name": "Riftlurker", "color": Color(0.75, 0.3, 0.95, 1), "icon_key": "pet_lizard", "stat_type": "max_health", "stat_value": 55.0, "speed_mult": 1.3},
		{"id": "starforged_cat", "name": "Starforged Cat", "color": Color(1.0, 0.9, 0.6, 1), "icon_key": "pet_cat", "stat_type": "fire_rate", "stat_value": 0.04, "speed_mult": 1.45},
		{"id": "ironclad_drone", "name": "Ironclad Drone", "color": Color(0.6, 0.65, 0.7, 1), "icon_key": "pet_drone", "stat_type": "max_health", "stat_value": 65.0, "speed_mult": 1.2},
	],
	"multiversal": [
		{"id": "paradox_pup", "name": "Paradox Pup", "color": Color(0.9, 0.3, 0.9, 1), "icon_key": "pet_dog", "stat_type": "damage", "stat_value": 26.0, "speed_mult": 1.7},
		{"id": "eclipse_serpent", "name": "Eclipse Serpent", "color": Color(0.15, 0.15, 0.2, 1), "icon_key": "pet_lizard", "stat_type": "crit_chance", "stat_value": 0.08, "speed_mult": 1.6},
		{"id": "infinity_drone", "name": "Infinity Drone", "color": Color(0.95, 0.95, 1.0, 1), "icon_key": "pet_drone", "stat_type": "ammo_reserve", "stat_value": 60.0, "speed_mult": 1.65},
		{"id": "omega_serpent", "name": "Omega Serpent", "color": Color(0.85, 0.15, 0.35, 1), "icon_key": "pet_lizard", "stat_type": "damage", "stat_value": 30.0, "speed_mult": 1.7},
	],
	# One tier above Multiversal, same identity as DIVINE_ITEM_POOL - gold,
	# rarer than anything else, and only ever reachable through the
	# Plushie path right now (no egg/case currently rolls this high).
	"divine": [
		{"id": "godhound", "name": "Godhound", "color": Color(1.0, 0.85, 0.2, 1), "icon_key": "pet_dog", "stat_type": "damage", "stat_value": 38.0, "speed_mult": 1.85},
		{"id": "seraph_owl", "name": "Seraph Owl", "color": Color(1.0, 0.95, 0.75, 1), "icon_key": "pet_bird", "stat_type": "crit_chance", "stat_value": 0.1, "speed_mult": 1.8},
		{"id": "genesis_wyrm", "name": "Genesis Wyrm", "color": Color(1.0, 0.7, 0.15, 1), "icon_key": "pet_lizard", "stat_type": "max_health", "stat_value": 90.0, "speed_mult": 1.75},
	],
}
var owned_pet_instances: Dictionary = {}
var _pet_instance_counter: int = 0

# --- Pet Eggs: dropped by enemies (any raid, plus the Bloodline
# Gauntlet), carried in the Backpack/Stash like any other item, then
# brought to the Salvaged Beasts screen to actually hatch.
const EGG_ICON_KEY := "egg"
func make_pet_egg(rarity: String) -> Dictionary:
	return {
		"name": "%s Egg" % get_rarity_label(rarity), "value": 0, "slot": "egg",
		"stat_type": "", "stat_value": 0.0, "icon_key": EGG_ICON_KEY, "rarity": rarity,
	}

func roll_pet_egg_drop(chance: float = 0.12) -> Dictionary:
	if randf() >= chance:
		return {}
	var roll := randf()
	var cumulative := 0.0
	# Shifted noticeably toward higher tiers vs the old weights (Common
	# 45% -> 28%, Multiversal 0.2% -> 1%, etc.) per request - eggs should
	# have a real, felt chance at hatching into something good, not just
	# a token 0.2% shot at the best tier.
	var weights := {"common": 0.28, "uncommon": 0.22, "rare": 0.18, "epic": 0.14, "legendary": 0.09, "mythic": 0.05, "exotic": 0.025, "multiversal": 0.015}
	for tier in ["common", "uncommon", "rare", "epic", "legendary", "mythic", "exotic", "multiversal"]:
		cumulative += weights[tier]
		if roll < cumulative:
			return make_pet_egg(tier)
	return make_pet_egg("common")

# --- Salvaged Beasts: a third event alongside Spectral Tide and
# Bloodline. Its own currency (Tickets), earned by hatching Eggs, feeds
# a 200-tier reward track just like the others.
const SALVAGED_BEASTS_MAX_TIER := 200
var salvaged_beasts_tickets: int = 0
var salvaged_beasts_tier: int = 0
var salvaged_beasts_progress: int = 0
var pet_eggs: Array = []
const MAX_HATCH_SLOTS := 5
var egg_hatching_slots: Array = []

func add_pet_egg(egg: Dictionary) -> void:
	pet_eggs.append(egg)
	save_game()

func deposit_egg_from_stash(stash_index: int) -> bool:
	if stash_index < 0 or stash_index >= stash_items.size():
		return false
	var item: Dictionary = stash_items[stash_index]
	if item.get("slot", "") != "egg":
		return false
	stash_items.remove_at(stash_index)
	add_pet_egg(item)
	return true

func make_pet_case() -> Dictionary:
	return {
		"name": "Pet Case", "value": 4500, "slot": "pet_case",
		"stat_type": "", "stat_value": 0.0, "icon_key": "pet_case", "rarity": "rare",
	}

func start_hatching_egg(index: int) -> bool:
	if index < 0 or index >= pet_eggs.size():
		return false
	if egg_hatching_slots.size() >= MAX_HATCH_SLOTS:
		return false
	var egg: Dictionary = pet_eggs[index]
	var rarity: String = egg.get("rarity", "common")
	pet_eggs.remove_at(index)
	egg_hatching_slots.append({"rarity": rarity, "started_unix": Time.get_unix_time_from_system(), "duration": get_egg_hatch_duration(rarity)})
	save_game()
	return true

func get_hatching_progress(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= egg_hatching_slots.size():
		return 1.0
	var slot: Dictionary = egg_hatching_slots[slot_index]
	var elapsed: float = Time.get_unix_time_from_system() - float(slot.get("started_unix", 0))
	return clamp(elapsed / float(slot.get("duration", 5.0)), 0.0, 1.0)

func collect_hatched_egg(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= egg_hatching_slots.size():
		return ""
	if get_hatching_progress(slot_index) < 1.0:
		return ""
	var rarity: String = egg_hatching_slots[slot_index].get("rarity", "common")
	egg_hatching_slots.remove_at(slot_index)
	var instance_id := hatch_egg(rarity)
	var ticket_reward := {"common": 5, "uncommon": 8, "rare": 12, "epic": 20, "legendary": 30, "mythic": 45, "exotic": 65, "multiversal": 100}
	grant_salvaged_beasts_tickets(int(ticket_reward.get(rarity, 5)))
	notify_event("hatch_egg_salvaged_beasts")
	return instance_id

func grant_salvaged_beasts_tickets(amount: int) -> void:
	if amount <= 0:
		return
	add_currency("tickets", amount)
	if salvaged_beasts_tier < SALVAGED_BEASTS_MAX_TIER:
		salvaged_beasts_progress += amount
		var needed := 60 + salvaged_beasts_tier * 12
		while salvaged_beasts_tier < SALVAGED_BEASTS_MAX_TIER and salvaged_beasts_progress >= needed:
			salvaged_beasts_progress -= needed
			salvaged_beasts_tier += 1
			_advance_salvaged_beasts_tier()
			needed = 60 + salvaged_beasts_tier * 12
	save_game()

func _advance_salvaged_beasts_tier() -> void:
	var rewards := _generate_salvaged_beasts_rewards()
	var reward: Dictionary = rewards[salvaged_beasts_tier - 1]
	match reward.get("type", ""):
		"egg":
			add_pet_egg(make_pet_egg(reward.get("rarity", "common")))
		"tickets":
			salvaged_beasts_tickets += int(reward.get("amount", 0))
		"rubles":
			add_currency("rubles", int(reward.get("amount", 0)))
		"item":
			var item: Dictionary = reward.get("item", {}).duplicate(true)
			if not item.is_empty():
				_add_to_stash(item)
	toast_requested.emit("Salvaged Beasts Tier %d unlocked!" % salvaged_beasts_tier)

func skip_salvaged_beasts_tier() -> bool:
	if salvaged_beasts_tier >= SALVAGED_BEASTS_MAX_TIER:
		return false
	if not spend_currency("tickets", 40):
		return false
	salvaged_beasts_progress = 0
	salvaged_beasts_tier += 1
	_advance_salvaged_beasts_tier()
	save_game()
	return true

# Salvaged Beasts exclusive gear - beast/feral themed weapons and armor,
# only obtainable from this event's reward track. Granted at every 25th
# tier as a real milestone reward alongside the more frequent eggs/tickets.
const SALVAGED_BEASTS_ITEM_POOL := [
	{"name": "Fang Ripper", "value": 340, "slot": "weapon", "stat_type": "damage", "stat_value": 35.1, "icon_key": "rifle", "rarity": "epic"},
	{"name": "Beastmaster's Coat", "value": 320, "slot": "body", "stat_type": "max_health", "stat_value": 56.7, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Feral Claw Gauntlets", "value": 260, "slot": "accessory", "stat_type": "fire_rate", "stat_value": 0.0, "icon_key": "hard_plate", "rarity": "epic"},
	{"name": "Pack Leader's Hide", "value": 300, "slot": "boots", "stat_type": "speed", "stat_value": 32.4, "icon_key": "boots", "rarity": "epic"},
	{"name": "Salvaged Skull Helm", "value": 280, "slot": "head", "stat_type": "max_health", "stat_value": 40.5, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Wraithbone Cannon", "value": 480, "slot": "weapon", "stat_type": "damage", "stat_value": 51.3, "icon_key": "sniper", "rarity": "legendary"},
	{"name": "Alpha Predator Plate", "value": 460, "slot": "body", "stat_type": "max_health", "stat_value": 81.0, "icon_key": "chestplate", "rarity": "legendary"},
	{"name": "Menagerie Crown", "value": 440, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "legendary"},
]

func _generate_salvaged_beasts_rewards() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4477
	var rewards: Array = []
	for tier in range(1, SALVAGED_BEASTS_MAX_TIER + 1):
		if tier % 25 == 0:
			var item_pool: Array = SALVAGED_BEASTS_ITEM_POOL.filter(func(i): return i.get("rarity", "") == "legendary") if tier % 50 == 0 else SALVAGED_BEASTS_ITEM_POOL.filter(func(i): return i.get("rarity", "") == "epic")
			rewards.append({"type": "item", "item": item_pool[rng.randi() % item_pool.size()]})
		elif tier % 20 == 0:
			rewards.append({"type": "egg", "rarity": "exotic"})
		elif tier % 10 == 0:
			rewards.append({"type": "egg", "rarity": "legendary"})
		elif tier % 5 == 0:
			rewards.append({"type": "egg", "rarity": "rare"})
		elif tier % 3 == 0:
			rewards.append({"type": "tickets", "amount": 15 + tier})
		else:
			rewards.append({"type": "rubles", "amount": 300 + tier * 40})
	return rewards

# A premium pet only obtainable from the Store - unlike the Hideout
# pets, this one grants two stat bonuses at once.
const PREMIUM_PET_ID := "onyx"
const PREMIUM_PET_DATA := {"name": "Onyx", "cost": "$9.99", "color": Color(0.12, 0.1, 0.15, 1), "icon_key": "pet_crow", "quote": "\"A shadow that hunts alongside you.\""}

# --- The Loom-weaver: a unique 10-legged spider companion, earned (not
# bought) by killing 100 enemies inside the Graveyard map. Owning it is
# also what unlocks the Graveyard as a normal map choice from Play.
const LOOM_WEAVER_PET_ID := "loom_weaver"
const LOOM_WEAVER_PET_DATA := {"name": "Loom-weaver", "cost": "Graveyard exclusive", "color": Color(0.14, 0.08, 0.18, 1), "icon_key": "pet_spider", "stat_type": "damage", "stat_value": 12.0, "speed_mult": 1.15, "quote": "\"Ten legs. Zero mercy. All yours, if you earned it.\""}
const GRAVEYARD_KILLS_FOR_LOOM_WEAVER := 100
var graveyard_kills: int = 0
# True only while the active raid scene is the Graveyard - lets
# record_kill() know whether a kill should count toward the total.
var in_graveyard_run: bool = false

func graveyard_unlocked() -> bool:
	return owned_pets.has(LOOM_WEAVER_PET_ID)

func _maybe_grant_loom_weaver() -> void:
	if owned_pets.has(LOOM_WEAVER_PET_ID):
		return
	if graveyard_kills >= GRAVEYARD_KILLS_FOR_LOOM_WEAVER:
		owned_pets.append(LOOM_WEAVER_PET_ID)
		toast_requested.emit("The Loom-weaver has bonded to you! The Graveyard is now open from Play.")
		save_game()

# --- Spectral Bowls: defend one from waves of shadow-beasts, then
# pacify the survivor into a companion. Only one can follow you per
# raid - extracting with it is what actually makes it yours.
const GRAVEYARD_PACIFIED_POOL := [
	{"id": "shade_hound", "name": "Shade Hound", "color": Color(0.12, 0.1, 0.16, 1), "icon_key": "pet_dog", "stat_type": "speed", "stat_value": 16.0, "speed_mult": 1.25},
	{"id": "wailing_crow", "name": "Wailing Crow", "color": Color(0.18, 0.08, 0.2, 1), "icon_key": "pet_crow", "stat_type": "loot_sense", "stat_value": 0.02, "speed_mult": 1.3},
	{"id": "bone_serpent", "name": "Bone Serpent", "color": Color(0.2, 0.2, 0.22, 1), "icon_key": "pet_lizard", "stat_type": "max_health", "stat_value": 22.0, "speed_mult": 1.0},
]
var raid_pacified_pet_type: String = ""

func begin_pacifying(pet_type: String) -> void:
	raid_pacified_pet_type = pet_type

func _check_pacified_extraction() -> void:
	if raid_pacified_pet_type == "":
		return
	var picked: Dictionary = {}
	for entry in GRAVEYARD_PACIFIED_POOL:
		if entry.get("id", "") == raid_pacified_pet_type:
			picked = entry
			break
	raid_pacified_pet_type = ""
	if picked.is_empty():
		return
	_pet_instance_counter += 1
	var instance_id := "pacified_%d_%s" % [_pet_instance_counter, picked.get("id", "pet")]
	owned_pet_instances[instance_id] = {
		"pet_type": picked.get("id", ""), "rarity": "legendary", "custom_name": "",
		"found_date": Time.get_date_string_from_system(), "found_map": "Graveyard",
		"level": 1, "pet_xp": 0, "trait": roll_pet_trait(), "graveyard_pacified": true,
	}
	toast_requested.emit("%s followed you home from the Graveyard." % picked.get("name", "A pacified beast"))
	save_game()
const PREMIUM_PET_STATS := [{"stat_type": "damage", "stat_value": 5.0}, {"stat_type": "speed", "stat_value": 10.0}]

func purchase_premium_pet() -> bool:
	if owned_pets.has(PREMIUM_PET_ID):
		return false
	var cost: int = dollar_price_to_rubles(str(PREMIUM_PET_DATA.get("cost", "$9.99")))
	if rubles < cost:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= cost
	owned_pets.append(PREMIUM_PET_ID)
	toast_requested.emit("Onyx joined you for %d Rubles!" % cost)
	save_game()
	return true

func purchase_pet(pet_id: String) -> bool:
	if not PET_CATALOG.has(pet_id) or owned_pets.has(pet_id):
		return false
	var cost: int = int(PET_CATALOG[pet_id].get("cost", 0))
	if not spend_currency("rubles", cost):
		return false
	owned_pets.append(pet_id)
	toast_requested.emit("%s joined you!" % PET_CATALOG[pet_id].get("name", "Pet"))
	save_game()
	return true

func equip_pet(pet_id: String) -> void:
	if pet_id != "" and not owned_pets.has(pet_id) and not owned_pet_instances.has(pet_id):
		return
	equipped_pet = pet_id
	equipped_changed.emit()
	save_game()

func get_pet_data(pet_id: String) -> Dictionary:
	if pet_id == PREMIUM_PET_ID:
		return PREMIUM_PET_DATA
	if pet_id == BLOODLINE_PET_ID:
		return BLOODLINE_PET_DATA
	if pet_id == LOOM_WEAVER_PET_ID:
		return LOOM_WEAVER_PET_DATA
	if pet_id.begins_with("pacified_"):
		var instance: Dictionary = owned_pet_instances.get(pet_id, {})
		if instance.is_empty():
			return {}
		var base_type: String = instance.get("pet_type", "")
		var base: Dictionary = {}
		for entry in GRAVEYARD_PACIFIED_POOL:
			if entry.get("id", "") == base_type:
				base = entry
				break
		if base.is_empty():
			return {}
		var data := base.duplicate(true)
		data["rarity"] = instance.get("rarity", "legendary")
		if instance.get("custom_name", "") != "":
			data["name"] = instance["custom_name"]
		return data
	if pet_id.begins_with("hatched_") or pet_id.begins_with("plushie_"):
		var instance: Dictionary = owned_pet_instances.get(pet_id, {})
		if instance.is_empty():
			return {}
		var base_type: String = instance.get("pet_type", "")
		var rarity: String = instance.get("rarity", "common")
		var base: Dictionary = {}
		for entry in EGG_PET_POOL.get(rarity, []):
			if entry.get("id", "") == base_type:
				base = entry
				break
		if base.is_empty():
			for entry in PLUSHIE_EXCLUSIVE_PET_POOL.get(rarity, []):
				if entry.get("id", "") == base_type:
					base = entry
					break
		if base.is_empty():
			return {}
		var data := base.duplicate(true)
		data["rarity"] = rarity
		if instance.get("custom_name", "") != "":
			data["name"] = instance["custom_name"]
		return data
	# A raw pacified-pool type id (e.g. "shade_hound") resolves here too -
	# used for the temporary in-raid companion that follows you around
	# BEFORE extraction turns it into a permanent "pacified_N_id" instance.
	for entry in GRAVEYARD_PACIFIED_POOL:
		var pool_entry: Dictionary = entry
		if pool_entry.get("id", "") == pet_id:
			var data: Dictionary = pool_entry.duplicate(true)
			data["rarity"] = "legendary"
			return data
	return PET_CATALOG.get(pet_id, {})

# Rolls a brand new pet instance from an Egg's rarity tier and adds it
# to the collection - called when an egg finishes hatching.
# --- Plushie-exclusive pets: only obtainable by giving Rose a Plushie
# (or, rarely, from a Pet Case) - never from a regular Egg hatch. A
# couple of genuinely new pets (Cuddles, Bunbun) mixed in with the
# usual rarity pools for variety, gated to the higher rarities since
# a Plushie pet is meant to feel like a real reward.
const PLUSHIE_EXCLUSIVE_PET_POOL := {
	"legendary": [
		{"id": "cuddles", "name": "Cuddles", "color": Color(0.75, 0.5, 0.3, 1), "icon_key": "pet_teddy", "stat_type": "max_health", "stat_value": 30.0, "speed_mult": 0.9},
	],
	"mythic": [
		{"id": "bunbun", "name": "Bunbun", "color": Color(0.92, 0.85, 0.88, 1), "icon_key": "pet_bunny", "stat_type": "speed", "stat_value": 24.0, "speed_mult": 1.3},
	],
	# Godforged - one tier above Divine, and the only Plushie-exclusive
	# pet with its own "godforged_orbit" flag (see Pet.gd): while
	# equipped, a small ring of miniature plushies orbits the player in
	# raid, Arena, and Spectral Tide, not just a menu-only visual.
	"godforged": [
		{"id": "ellie", "name": "Ellie", "color": ELLIE_ICON_COLOR, "icon_key": "pet_elephant", "stat_type": "max_health", "stat_value": 50.0, "stat_type_2": "loot_sense", "stat_value_2": 0.02, "speed_mult": 1.0, "godforged_orbit": true},
	],
}

func has_plushie() -> bool:
	for item in stash_items:
		if item.get("slot", "") == "plushie":
			return true
	for item in backpack_storage:
		if item.get("slot", "") == "plushie":
			return true
	return false

func _consume_one_plushie() -> bool:
	for i in range(stash_items.size()):
		if stash_items[i].get("slot", "") == "plushie":
			stash_items.remove_at(i)
			return true
	for i in range(backpack_storage.size()):
		if backpack_storage[i].get("slot", "") == "plushie":
			backpack_storage.remove_at(i)
			return true
	return false

# Weighted toward the higher end - handing Rose a Plushie is meant to
# feel like a real event, not a coin flip that's usually disappointing.
# Multiversal and Divine ARE reachable here (unlike Loot Bags/Eggs),
# at notably better odds than a crate roll (see CRATE_ODDS) - giving
# Rose a Plushie is meant to be the best real shot at a top-tier pet in
# the game, not just a slightly-nicer version of the same long odds.
const PLUSHIE_PET_RARITY_WEIGHTS := {
	"rare": 25.0, "epic": 28.0, "legendary": 26.0, "mythic": 14.0, "exotic": 5.5, "multiversal": 1.2, "divine": 0.3, "godforged": 0.0001,
}

# Same tier-ordering convention GamblePanel.gd uses for its own odds
# readout - shared by the plushie trade result popup so it's a real
# "here's what you're working with" table, not just flavor text.
const PLUSHIE_PET_TIER_ORDER := ["rare", "epic", "legendary", "mythic", "exotic", "multiversal", "divine", "godforged"]

# The most recently obtained plushie pet instance, if any - Dictionary
# insertion order is preserved in GDScript, so the last "plushie_"-
# prefixed key encountered is the newest one. Used by PlushiesPanel to
# show what you currently have without needing a separate "current
# plushie pet" var to keep in sync.
func get_latest_plushie_pet_instance_id() -> String:
	var latest_id := ""
	for id in owned_pet_instances.keys():
		if str(id).begins_with("plushie_"):
			latest_id = id
	return latest_id

func get_plushie_pet_odds_text() -> String:
	var lines: Array = []
	for tier in PLUSHIE_PET_TIER_ORDER:
		var pct: float = PLUSHIE_PET_RARITY_WEIGHTS.get(tier, 0.0)
		# The Godforged sliver (0.0001%) would just print as "0.00%" and
		# read as literally impossible at 2 decimal places - give anything
		# under 0.01% enough precision to actually show up.
		var pct_text: String = ("%.4f%%" % pct) if pct < 0.01 else ("%.2f%%" % pct)
		lines.append("%s: %s" % [get_rarity_label(tier), pct_text])
	return " | ".join(lines)

func _roll_plushie_pet_rarity() -> String:
	var total := 0.0
	for w in PLUSHIE_PET_RARITY_WEIGHTS.values():
		total += float(w)
	var roll := randf() * total
	var cumulative := 0.0
	for rarity in PLUSHIE_PET_RARITY_WEIGHTS:
		cumulative += float(PLUSHIE_PET_RARITY_WEIGHTS[rarity])
		if roll <= cumulative:
			return rarity
	return "rare"

# The whole "give Rose a Plushie" flow - consumes one Plushie (Stash or
# Backpack Storage), rolls a rarity, picks a pet (mixing the usual Egg
# pool with the Plushie-exclusive ones at that rarity), and creates a
# new pet instance with the guaranteed Plushie buff. Returns the new
# instance id, or "" if there was no Plushie to give.
func give_plushie_to_rose() -> String:
	if not _consume_one_plushie():
		return ""
	var rarity := _roll_plushie_pet_rarity()
	# Rarities with no EGG_PET_POOL entry of their own (e.g. "godforged",
	# which is Plushie-exclusive) must NOT fall back to the Rare egg pool
	# here - that would silently dilute a guaranteed-Ellie roll with
	# ordinary Rare pets instead. Only fall back to Rare if BOTH pools
	# for this rarity end up genuinely empty.
	var pool: Array = EGG_PET_POOL.get(rarity, []).duplicate()
	pool.append_array(PLUSHIE_EXCLUSIVE_PET_POOL.get(rarity, []))
	if pool.is_empty():
		pool = EGG_PET_POOL["rare"]
	var picked: Dictionary = pool[randi() % pool.size()]
	_pet_instance_counter += 1
	var instance_id := "plushie_%d_%s" % [_pet_instance_counter, picked.get("id", "pet")]
	owned_pet_instances[instance_id] = {
		"pet_type": picked.get("id", ""), "rarity": rarity, "custom_name": "",
		"found_date": Time.get_date_string_from_system(), "found_map": "The Hideout",
		"level": 1, "pet_xp": 0, "trait": "plushie_buff",
	}
	save_game()
	return instance_id

func hatch_egg(rarity: String) -> String:
	var pool: Array = EGG_PET_POOL.get(rarity, EGG_PET_POOL["common"])
	if pool.is_empty():
		pool = EGG_PET_POOL["common"]
	var picked: Dictionary = pool[randi() % pool.size()]
	_pet_instance_counter += 1
	var instance_id := "hatched_%d_%s" % [_pet_instance_counter, picked.get("id", "pet")]
	owned_pet_instances[instance_id] = {
		"pet_type": picked.get("id", ""), "rarity": rarity, "custom_name": "",
		"found_date": Time.get_date_string_from_system(), "found_map": selected_map.capitalize() if selected_map != "" else "Overgrowth",
		"level": 1, "pet_xp": 0, "trait": roll_pet_trait(),
	}
	stat_eggs_hatched += 1
	save_game()
	return instance_id

# --- Pet Traits: a random bonus quirk rolled once at hatch time and kept
# forever after. Weighted so the flashy, powerful ones are genuinely
# rare - the rarest tier (0.1%) is a real "someone in a thousand hatches
# will ever see this" moment, and looks the part in-game.
const PET_TRAIT_POOL := [
	{"id": "quick_reflexes", "name": "Quick Reflexes", "weight": 18.0, "stat_type": "speed", "stat_value": 3.0, "tier": "common", "desc": "A touch faster on its feet than most."},
	{"id": "thick_hide", "name": "Thick Hide", "weight": 18.0, "stat_type": "max_health", "stat_value": 6.0, "tier": "common", "desc": "Tougher skin than you'd expect."},
	{"id": "keen_eye", "name": "Keen Eye", "weight": 18.0, "stat_type": "loot_sense", "stat_value": 0.005, "tier": "common", "desc": "Never misses a glint in the dark."},
	{"id": "steady_paws", "name": "Steady Paws", "weight": 16.0, "stat_type": "fire_rate", "stat_value": 0.008, "tier": "common", "desc": "Calm nerves rub off on you."},
	{"id": "predators_instinct", "name": "Predator's Instinct", "weight": 12.0, "stat_type": "damage", "stat_value": 2.0, "tier": "uncommon", "desc": "Born to hunt, and it shows."},
	{"id": "iron_will", "name": "Iron Will", "weight": 10.0, "stat_type": "max_health", "stat_value": 14.0, "tier": "uncommon", "desc": "Doesn't know when to quit."},
	{"id": "scavengers_nose", "name": "Scavenger's Nose", "weight": 9.0, "stat_type": "loot_sense", "stat_value": 0.012, "tier": "uncommon", "desc": "Can smell good loot through walls."},
	{"id": "alpha_presence", "name": "Alpha Presence", "weight": 5.5, "stat_type": "damage", "stat_value": 5.0, "tier": "rare", "desc": "Other creatures give it a wide berth.", "glow": true},
	{"id": "phantom_step", "name": "Phantom Step", "weight": 4.5, "stat_type": "speed", "stat_value": 10.0, "tier": "rare", "desc": "Moves like it's barely touching the ground.", "glow": true},
	{"id": "spectral_bond", "name": "Spectral Bond", "weight": 2.5, "stat_type": "max_health", "stat_value": 26.0, "tier": "epic", "desc": "Something about it feels like it isn't fully here.", "glow": true, "pulse": true},
	{"id": "bloodmarked", "name": "Bloodmarked", "weight": 1.4, "stat_type": "damage", "stat_value": 11.0, "tier": "epic", "desc": "Marked by something violent and ancient.", "glow": true, "pulse": true},
	{"id": "void_touched", "name": "Void Touched", "weight": 0.1, "stat_type": "damage", "stat_value": 22.0, "stat_type_2": "max_health", "stat_value_2": 40.0, "tier": "mythic", "desc": "It shouldn't exist. Somehow it does, and it's yours.", "glow": true, "pulse": true, "prismatic": true},
]

func roll_pet_trait() -> String:
	var total_weight := 0.0
	for t in PET_TRAIT_POOL:
		total_weight += float(t.get("weight", 1.0))
	var roll := randf() * total_weight
	var cumulative := 0.0
	for t in PET_TRAIT_POOL:
		cumulative += float(t.get("weight", 1.0))
		if roll <= cumulative:
			return t.get("id", "")
	return PET_TRAIT_POOL[0].get("id", "")

func get_trait_data(trait_id: String) -> Dictionary:
	if trait_id == PLUSHIE_TRAIT.get("id", ""):
		return PLUSHIE_TRAIT
	for t in PET_TRAIT_POOL:
		if t.get("id", "") == trait_id:
			return t
	return {}

# The Plushie buff - guaranteed (never randomly rolled, unlike the pool
# above), always both stats at once, and stronger than anything a
# normal hatch can roll. The reward for finding one of these was
# effort (finding Plushies, then Rose), not luck, so it's allowed to
# be generous. glow/pulse mirror the rarest natural trait for the
# borrowed shimmer effects; pet_aura is Plushie-specific (see
# PlushieAuraFX.gd) and drives the pet-colored aura + particles.
const PLUSHIE_TRAIT := {
	"id": "plushie_buff", "name": "Plushie Buff", "weight": 0.0,
	"stat_type": "max_health", "stat_value": 32.0, "stat_type_2": "damage", "stat_value_2": 14.0,
	"tier": "mythic", "desc": "Loved back into being by Rose herself. Somehow better for it.",
	"glow": true, "pulse": true, "pet_aura": true,
}

func rename_pet(instance_id: String, new_name: String) -> void:
	if owned_pet_instances.has(instance_id):
		owned_pet_instances[instance_id]["custom_name"] = new_name.strip_edges().substr(0, 20)
		save_game()

# --- Pet leveling: pets gain XP from successful extractions and turned-in
# quests (see end_run() and turn_in_quest()) - only the currently
# EQUIPPED instance-based pet (hatched/plushie/pacified) levels up, not
# the premium/Bloodline/Loom-weaver pets, which aren't instance-backed.
# The curve is deliberately slow at the top - a pet you've had since
# level 1 should still feel like it's climbing by the time you've done
# dozens of raids with it, not maxed out after a handful.
const PET_MAX_LEVEL := 30
const PET_XP_BASE := 40

func pet_xp_for_level(level: int) -> int:
	return int(PET_XP_BASE * pow(float(level), 1.35))

func get_pet_display_name(pet_id: String) -> String:
	var instance: Dictionary = owned_pet_instances.get(pet_id, {})
	var custom: String = str(instance.get("custom_name", ""))
	if custom != "":
		return custom
	return str(get_pet_data(pet_id).get("name", "Pet"))

func grant_pet_xp(amount: int) -> void:
	if amount <= 0 or equipped_pet == "":
		return
	if not owned_pet_instances.has(equipped_pet):
		return
	var instance: Dictionary = owned_pet_instances[equipped_pet]
	var level: int = int(instance.get("level", 1))
	if level >= PET_MAX_LEVEL:
		return
	var xp: int = int(instance.get("pet_xp", 0)) + amount
	var leveled_up := false
	while level < PET_MAX_LEVEL and xp >= pet_xp_for_level(level):
		xp -= pet_xp_for_level(level)
		level += 1
		leveled_up = true
	instance["level"] = level
	instance["pet_xp"] = xp
	if leveled_up:
		toast_requested.emit("%s reached Level %d!" % [get_pet_display_name(equipped_pet), level])

func get_pet_bonus(stat_type: String) -> float:
	if equipped_pet == "":
		return 0.0
	if equipped_pet == PREMIUM_PET_ID:
		var total := 0.0
		for entry in PREMIUM_PET_STATS:
			if entry.get("stat_type", "") == stat_type:
				total += float(entry.get("stat_value", 0.0))
		return total
	var pet: Dictionary = get_pet_data(equipped_pet)
	var bonus := 0.0
	if pet.get("stat_type", "") == stat_type:
		bonus += float(pet.get("stat_value", 0.0))
	if equipped_pet.begins_with("hatched_") or equipped_pet.begins_with("plushie_") or equipped_pet.begins_with("pacified_"):
		var instance: Dictionary = owned_pet_instances.get(equipped_pet, {})
		var trait_data := get_trait_data(instance.get("trait", ""))
		if not trait_data.is_empty():
			if trait_data.get("stat_type", "") == stat_type:
				bonus += float(trait_data.get("stat_value", 0.0))
			if trait_data.get("stat_type_2", "") == stat_type:
				bonus += float(trait_data.get("stat_value_2", 0.0))
	bonus *= (1.0 + get_upgrade_bonus("pet_bond"))
	return bonus
# --- The Store: cosmetic/currency packs "for real money" (not actually -
# this is a test build, so every purchase is free and just grants the
# listed rewards immediately). Dollar packs are repeatable; Monthly Pass
# and Double XP are one-time permanent unlocks.
const STORE_PACKS := [
	{"id": "pack_399", "price": "$3.99", "label": "Starter Pack", "rubles": 5000, "souls": 200, "item_rarity": "epic", "item_count": 1, "lootbags": 0, "bonus_exotic": 1},
	{"id": "pack_2999", "price": "$29.99", "label": "Value Pack", "rubles": 40000, "souls": 1500, "item_rarity": "legendary", "item_count": 2, "lootbags": 1, "bonus_exotic": 1},
	{"id": "pack_7999", "price": "$79.99", "label": "Premium Pack", "rubles": 120000, "souls": 5000, "item_rarity": "mythic", "item_count": 2, "lootbags": 3, "bonus_exotic": 2},
	{"id": "pack_12999", "price": "$129.99", "label": "Ultimate Pack", "rubles": 250000, "souls": 10000, "item_rarity": "mythic", "item_count": 3, "lootbags": 5, "bonus_exotic": 3},
	{"id": "pack_39999", "price": "$399.99", "label": "Elite Pack", "rubles": 700000, "souls": 25000, "item_rarity": "mythic", "item_count": 4, "lootbags": 8, "bonus_exotic": 4, "bonus_multiversal": 1},
	{"id": "pack_99999", "price": "$999.99", "label": "Legendary Vault", "rubles": 2000000, "souls": 75000, "item_rarity": "mythic", "item_count": 6, "lootbags": 15, "bonus_exotic": 8, "bonus_multiversal": 3},
	{"id": "pack_199", "price": "$1.99", "label": "Pocket Change", "rubles": 2000, "souls": 75, "item_rarity": "rare", "item_count": 1, "lootbags": 0, "bonus_exotic": 0},
	{"id": "pack_099", "price": "$0.99", "label": "Quick Grab", "rubles": 800, "souls": 25, "item_rarity": "uncommon", "item_count": 1, "lootbags": 0, "bonus_exotic": 0},
	{"id": "pack_1499", "price": "$14.99", "label": "Field Kit", "rubles": 15000, "souls": 600, "item_rarity": "epic", "item_count": 1, "lootbags": 1, "bonus_exotic": 0},
	{"id": "pack_19999", "price": "$199.99", "label": "Vanguard Pack", "rubles": 400000, "souls": 15000, "item_rarity": "mythic", "item_count": 3, "lootbags": 5, "bonus_exotic": 3, "bonus_multiversal": 1},
	{"id": "ammo_crate_small", "price": "$0.99", "label": "Ammo Crate (Small)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "ammo_count": 4},
	{"id": "ammo_crate_medium", "price": "$2.99", "label": "Ammo Crate (Medium)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "ammo_count": 10},
	{"id": "ammo_crate_large", "price": "$5.99", "label": "Ammo Crate (Large)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "ammo_count": 24},
	{"id": "rose_plushie_pack_small", "price": "$1.99", "label": "Rose's Plushie Pack (Small)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "plushie_count": 2},
	{"id": "rose_plushie_pack_medium", "price": "$4.99", "label": "Rose's Plushie Pack (Medium)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "plushie_count": 5},
	{"id": "rose_plushie_pack_large", "price": "$9.99", "label": "Rose's Plushie Pack (Large)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "plushie_count": 12},
	{"id": "rose_plushie_pack_sampler", "price": "$0.99", "label": "Rose's Plushie Pack (Sampler)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "plushie_count": 1},
	{"id": "rose_plushie_pack_mega", "price": "$19.99", "label": "Rose's Plushie Pack (Mega)", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "plushie_count": 20},
	{"id": "backpack_pack", "price": "$2.99", "label": "Quartermaster's Backpack Pack", "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "backpack_count": 1},
	# --- Free section: genuinely free, one-time-claimable packs (no real
	# money or Rubles cost) - see claim_free_store_pack() below. Never
	# put anything here with a real currency cost.
	{"id": "free_welcome_gift", "price": "Free", "label": "Welcome Gift", "free": true, "rubles": 500, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0},
	{"id": "free_soul_fragment", "price": "Free", "label": "Soul Fragment Gift", "free": true, "rubles": 0, "souls": 50, "item_count": 0, "lootbags": 0, "bonus_exotic": 0},
	{"id": "free_ammo_crate", "price": "Free", "label": "Free Ammo Crate", "free": true, "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "ammo_count": 2},
	{"id": "rose_free_pack", "price": "Free", "label": "Rose's Free Pack", "free": true, "rubles": 0, "souls": 0, "item_count": 0, "lootbags": 0, "bonus_exotic": 0, "grants_ellie": true},
]

var monthly_pass_owned: bool = false
var double_xp_owned: bool = false
var claimed_free_store_packs: Array = []

func purchase_store_pack(pack_id: String) -> void:
	var pack: Dictionary = _find_store_pack(pack_id)
	if pack.is_empty():
		return
	_grant_store_pack_contents(pack)
	toast_requested.emit("%s purchased!" % pack.get("label", "Pack"))
	save_game()

# A deliberately terrible-value alternative for anyone who wants to
# blow through Rubles instead of real money - costs 25x the Rubles the
# pack itself grants, so it's always a steep net loss even before
# counting the item/Soul bonuses. Absurd on purpose.
func get_store_pack_rubles_cost(pack_id: String) -> int:
	var pack: Dictionary = _find_store_pack(pack_id)
	if pack.is_empty():
		return 0
	return max(int(pack.get("rubles", 1000)) * 25, 10000)

func purchase_store_pack_with_rubles(pack_id: String) -> bool:
	var pack: Dictionary = _find_store_pack(pack_id)
	if pack.is_empty():
		return false
	var cost: int = get_store_pack_rubles_cost(pack_id)
	if rubles < cost:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= cost
	_grant_store_pack_contents(pack)
	toast_requested.emit("%s purchased for %d Rubles!" % [pack.get("label", "Pack"), cost])
	save_game()
	return true

# The Free section: genuinely free, no real money or Rubles involved -
# each pack in this section can only ever be claimed once per save.
# "rose_free_pack" is special-cased to hand over Ellie directly rather
# than rolling any RNG (see give_plushie_to_rose() for the normal
# random-roll path a Plushie takes).
func claim_free_store_pack(pack_id: String) -> bool:
	var pack: Dictionary = _find_store_pack(pack_id)
	if pack.is_empty():
		return false
	if not bool(pack.get("free", false)):
		return false
	if claimed_free_store_packs.has(pack_id):
		return false
	if pack.get("grants_ellie", false):
		_pet_instance_counter += 1
		var instance_id := "plushie_%d_ellie" % _pet_instance_counter
		owned_pet_instances[instance_id] = {
			"pet_type": "ellie", "rarity": "godforged", "custom_name": "",
			"found_date": Time.get_date_string_from_system(), "found_map": "The Hideout",
			"level": 1, "pet_xp": 0, "trait": "plushie_buff",
		}
	else:
		_grant_store_pack_contents(pack)
	claimed_free_store_packs.append(pack_id)
	toast_requested.emit("%s claimed!" % pack.get("label", "Pack"))
	save_game()
	return true

func _find_store_pack(pack_id: String) -> Dictionary:
	for p in STORE_PACKS:
		if p.get("id", "") == pack_id:
			return p
	return {}

func _grant_store_pack_contents(pack: Dictionary) -> void:
	add_currency("rubles", int(pack.get("rubles", 0)))
	add_currency("souls", int(pack.get("souls", 0)))
	var rarity: String = pack.get("item_rarity", "epic")
	var count: int = int(pack.get("item_count", 1))
	for i in range(count):
		_add_to_stash(_roll_store_item(rarity))
	for i in range(int(pack.get("bonus_exotic", 0))):
		_add_to_stash(_roll_store_item("exotic"))
	for i in range(int(pack.get("bonus_multiversal", 0))):
		_add_to_stash(finalize_rolled_item(MULTIVERSAL_ITEM_POOL[randi() % MULTIVERSAL_ITEM_POOL.size()].duplicate(true)))
	for i in range(int(pack.get("lootbags", 0))):
		_add_to_stash(make_loot_bag("legendary"))
	for i in range(int(pack.get("ammo_count", 0))):
		_add_to_stash(roll_ammo())
	for i in range(int(pack.get("plushie_count", 0))):
		_add_to_stash(roll_plushie())
	for i in range(int(pack.get("backpack_count", 0))):
		_add_to_stash(_roll_backpack_item())

func _roll_store_item(rarity: String) -> Dictionary:
	var pool: Array = []
	for pool_item in LOOT_BAG_GEAR_POOL:
		if pool_item.get("rarity", "") == rarity:
			pool.append(pool_item)
	if pool.is_empty():
		for pool_item in ENEMY_LOOT_POOL:
			if pool_item.get("rarity", "") == rarity:
				pool.append(pool_item)
	if pool.is_empty():
		return roll_enemy_loot()
	return finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))

# Dedicated puller for the Store's Backpack Pack - picks any slot:"backpack"
# gear, favoring the higher-tier LOOT_BAG_GEAR_POOL entries the same way
# _roll_store_item() favors them by rarity.
func _roll_backpack_item() -> Dictionary:
	var pool: Array = []
	for pool_item in LOOT_BAG_GEAR_POOL:
		if pool_item.get("slot", "") == "backpack":
			pool.append(pool_item)
	for pool_item in ENEMY_LOOT_POOL:
		if pool_item.get("slot", "") == "backpack":
			pool.append(pool_item)
	if pool.is_empty():
		return roll_enemy_loot()
	return finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))

# Also absurdly priced, and for the same reason as the packs above -
# this pass grants Rubles/Souls itself, so buying it WITH Rubles is
# circular by nature. Priced high enough that it's obviously a novelty
# option, not a real economic choice.
const MONTHLY_PASS_RUBLES_COST := 500000

func purchase_monthly_pass() -> bool:
	# Real-money purchasing isn't available - see purchase_monthly_pass_with_rubles for the Rubles alternative.
	return false

func purchase_monthly_pass_with_rubles() -> bool:
	if monthly_pass_owned:
		return false
	if rubles < MONTHLY_PASS_RUBLES_COST:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= MONTHLY_PASS_RUBLES_COST
	monthly_pass_owned = true
	add_currency("rubles", 8000)
	add_currency("souls", 300)
	toast_requested.emit("Monthly Pass activated for %d Rubles!" % MONTHLY_PASS_RUBLES_COST)
	save_game()
	return true

func purchase_double_xp() -> bool:
	if double_xp_owned:
		return false
	var cost: int = dollar_price_to_rubles("$14.99")
	if rubles < cost:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= cost
	double_xp_owned = true
	toast_requested.emit("Double XP is now permanent!")
	save_game()
	return true

# --- Pet Store: Egg bundles and a permanent faster-hatching upgrade,
# sold alongside the regular packs.
var fast_hatching_owned: bool = false
const PET_STORE_PACKS := [
	{"id": "egg_basket", "price": "$4.99", "label": "Egg Basket", "eggs": {"common": 2, "uncommon": 2, "rare": 1}},
	{"id": "rare_egg_bundle", "price": "$14.99", "label": "Rare Egg Bundle", "eggs": {"rare": 2, "epic": 1, "legendary": 1}},
	{"id": "exotic_egg", "price": "$49.99", "label": "Guaranteed Exotic Egg", "eggs": {"exotic": 1}},
	{"id": "pet_case", "price": "$3.99", "label": "Pet Case", "grants_pet_case": true},
	{"id": "guaranteed_pet", "price": "$24.99", "label": "Guaranteed Companion", "grants_pet_rarity": "legendary"},
	{"id": "multiversal_egg", "price": "$79.99", "label": "Guaranteed Multiversal Egg", "eggs": {"multiversal": 1}},
	{"id": "starter_bundle", "price": "$1.99", "label": "Starter Bundle", "eggs": {"common": 3, "uncommon": 1}},
]

func purchase_pet_pack(pack_id: String) -> void:
	var pack: Dictionary = {}
	for p in PET_STORE_PACKS:
		if p.get("id", "") == pack_id:
			pack = p
			break
	if pack.is_empty():
		return
	var eggs: Dictionary = pack.get("eggs", {})
	for rarity in eggs:
		for i in range(int(eggs[rarity])):
			add_pet_egg(make_pet_egg(rarity))
	if pack.get("grants_pet_case", false):
		_add_to_stash(make_pet_case())
	if pack.has("grants_pet_rarity"):
		var instance_id := hatch_egg(pack["grants_pet_rarity"])
		var pet_data := get_pet_data(instance_id)
		toast_requested.emit("Obtained %s!" % pet_data.get("name", "a pet"))
	toast_requested.emit("%s purchased!" % pack.get("label", "Pack"))
	save_game()

func purchase_pet_pack_with_rubles(pack_id: String, cost: int) -> bool:
	var pack: Dictionary = {}
	for p in PET_STORE_PACKS:
		if p.get("id", "") == pack_id:
			pack = p
			break
	if pack.is_empty():
		return false
	if rubles < cost:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= cost
	var eggs: Dictionary = pack.get("eggs", {})
	for rarity in eggs:
		for i in range(int(eggs[rarity])):
			add_pet_egg(make_pet_egg(rarity))
	if pack.get("grants_pet_case", false):
		_add_to_stash(make_pet_case())
	if pack.has("grants_pet_rarity"):
		var instance_id := hatch_egg(pack["grants_pet_rarity"])
		var pet_data := get_pet_data(instance_id)
		toast_requested.emit("Obtained %s!" % pet_data.get("name", "a pet"))
	toast_requested.emit("%s purchased for %d Rubles!" % [pack.get("label", "Pack"), cost])
	save_game()
	return true

func purchase_fast_hatching() -> bool:
	if fast_hatching_owned:
		return false
	var cost: int = dollar_price_to_rubles("$6.99")
	if rubles < cost:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= cost
	fast_hatching_owned = true
	toast_requested.emit("Fast Hatching is now permanent! Eggs hatch 40% quicker.")
	save_game()
	return true

func get_egg_hatch_duration(rarity: String) -> float:
	var base: float = EGG_HATCH_SECONDS.get(rarity, 5.0)
	return base * 0.6 if fast_hatching_owned else base

# --- Gamble: buy a crate for a chance at real gear, up to the ultra-rare
# Multiversal tier - and above that, Divine, at a razor-thin 0.01% (1 in
# 10,000). Odds are proportional to the numbers requested (50/40/30/20/
# 10/1), normalized to sum to 100%, with Divine sliced out of Common's
# share since it's such a small number it doesn't meaningfully change
# anything else's odds.
const CRATE_COST := 500
const CRATE_ODDS := {
	"divine": 0.01, "multiversal": 0.66, "exotic": 6.62, "mythic": 13.25,
	"legendary": 19.87, "rare": 26.49, "common": 33.10,
}

# Divine-exclusive items - one tier above Multiversal, only obtainable
# from crates at a 0.01% roll. Each one leans on the flashiest existing
# projectile behavior in the game (piercing, chaining, or the Alpha
# Cannon's sparkle trail) rather than a flat single-target hit, so they
# actually feel like the best weapon in the game to fire, not just the
# best on a stat sheet.
const DIVINE_ITEM_POOL := [
	{"name": "Seraph's Verdict", "value": 12000, "slot": "weapon", "stat_type": "damage", "stat_value": 175.5, "icon_key": "railgun", "rarity": "divine", "desc": "Pierces every target in its path and arcs lightning to a second one on every shot - a Railgun's whole kit, turned up past what should be possible."},
	{"name": "Halo Reaver", "value": 12500, "slot": "weapon", "stat_type": "damage", "stat_value": 182.2, "icon_key": "alpha_cannon", "rarity": "divine", "desc": "Fires the same piercing, sparkle-trailed bolt as the Alpha Cannon - except this one wasn't handed out during a Tech Test. Nobody's quite sure where it came from."},
	{"name": "Judgment's Reach", "value": 13000, "slot": "weapon", "stat_type": "damage", "stat_value": 189.0, "icon_key": "sniper", "rarity": "divine", "desc": "Chills, staggers, and drops nearly anything in the Sector in a single shot. The scope shows the kill before you've even pulled the trigger."},
	{"name": "Empyrean Aegis", "value": 11000, "slot": "body", "stat_type": "max_health", "stat_value": 243.0, "icon_key": "chestplate", "rarity": "divine", "desc": "Plate that shouldn't exist outside a Multiversal vault. Operators who've worn it say it feels warm, even in the Radiation Zone."},
	{"name": "Crown of Ascendance", "value": 10500, "slot": "head", "stat_type": "max_health", "stat_value": 216.0, "icon_key": "helmet", "rarity": "divine", "desc": "A helm with no visible seams or rivets. Whatever made it wasn't working from a blueprint."},
]

func roll_divine_or_multiversal_pool(tier: String) -> Array:
	return DIVINE_ITEM_POOL if tier == "divine" else MULTIVERSAL_ITEM_POOL

# Multiversal-exclusive items - only obtainable from crates, easily the
# best gear in the game.
const MULTIVERSAL_ITEM_POOL := [
	{"name": "Genesis Ripper", "value": 5000, "slot": "weapon", "stat_type": "damage", "stat_value": 108.0, "icon_key": "sniper", "rarity": "multiversal"},
	{"name": "Infinity Ward Plate", "value": 4800, "slot": "body", "stat_type": "max_health", "stat_value": 162.0, "icon_key": "chestplate", "rarity": "multiversal"},
	{"name": "Chronoshift Boots", "value": 4600, "slot": "boots", "stat_type": "speed", "stat_value": 121.5, "icon_key": "boots", "rarity": "multiversal"},
	{"name": "Eternum Visor", "value": 4700, "slot": "head", "stat_type": "max_health", "stat_value": 148.5, "icon_key": "helmet", "rarity": "multiversal"},
	{"name": "Paradox Engine", "value": 5200, "slot": "weapon", "stat_type": "damage", "stat_value": 114.8, "icon_key": "rifle", "rarity": "multiversal"},
]

func roll_crate_rarity() -> String:
	var roll := randf() * 100.0
	var cumulative := 0.0
	for tier in ["divine", "multiversal", "exotic", "mythic", "legendary", "rare", "common"]:
		cumulative += CRATE_ODDS[tier]
		if roll < cumulative:
			return tier
	return "common"

func roll_crate_item() -> Dictionary:
	var tier := roll_crate_rarity()
	var pool: Array = []
	if tier == "divine" or tier == "multiversal":
		pool = roll_divine_or_multiversal_pool(tier)
	elif tier in ["exotic", "mythic", "legendary"]:
		for pool_item in LOOT_BAG_GEAR_POOL:
			if pool_item.get("rarity", "") == tier:
				pool.append(pool_item)
	else:
		for pool_item in ENEMY_LOOT_POOL:
			if pool_item.get("rarity", "") == tier:
				pool.append(pool_item)
	if pool.is_empty():
		return finalize_rolled_item(roll_enemy_loot())
	return finalize_rolled_item(pool[randi() % pool.size()].duplicate(true))

func purchase_crate() -> Dictionary:
	if not spend_currency("rubles", CRATE_COST):
		return {}
	var item := roll_crate_item()
	_add_to_stash(item)
	stat_crates_opened += 1
	save_game()
	return item

func purchase_premium_skin(skin_id: String, icon_key: String) -> void:
	var skin := _find_skin(skin_id, icon_key)
	if skin.is_empty():
		return
	if not owned_skins.has(skin_id):
		owned_skins[skin_id] = true
	equipped_skins[icon_key] = skin_id
	skins_changed.emit()
	toast_requested.emit("%s skin unlocked!" % skin.get("name", "Skin"))
	save_game()

# Converts a display price like "$4.99" into a Rubles cost, so every
# store item that's normally real-money-only has a real in-game price
# instead - no per-item data entry needed, it's derived from the price
# that's already there.
func dollar_price_to_rubles(price_str: String) -> int:
	var digits := ""
	for c in price_str:
		if c.is_valid_float() or c == ".":
			digits += c
	var dollars := float(digits) if digits != "" else 1.0
	return int(round(dollars * 120.0 / 5.0)) * 5

func purchase_skin_with_rubles(skin_id: String, icon_key: String, cost: int) -> bool:
	var skin := _find_skin(skin_id, icon_key)
	if skin.is_empty():
		return false
	if rubles < cost:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= cost
	if not owned_skins.has(skin_id):
		owned_skins[skin_id] = true
	equipped_skins[icon_key] = skin_id
	skins_changed.emit()
	toast_requested.emit("%s skin unlocked for %d Rubles!" % [skin.get("name", "Skin"), cost])
	save_game()
	return true

var recruit_equipment: Dictionary = {
	"clarity": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
	"sorrow": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
	"glenn": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
	"big_crax": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
}

func equip_recruit_item(recruit_id: String, stash_index: int) -> bool:
	if stash_index < 0 or stash_index >= stash_items.size():
		return false
	if not recruit_equipment.has(recruit_id):
		return false
	var item: Dictionary = stash_items[stash_index]
	var slot: String = item.get("slot", "")
	if not recruit_equipment[recruit_id].has(slot):
		return false
	stash_items.remove_at(stash_index)
	var old = recruit_equipment[recruit_id][slot]
	recruit_equipment[recruit_id][slot] = item
	if old != null:
		_add_to_stash(old)
	toast_requested.emit("Equipped %s on %s" % [item.get("name", "Item"), RECRUITS.get(recruit_id, {}).get("label", recruit_id)])
	return true

func unequip_recruit_item(recruit_id: String, slot: String) -> void:
	if not recruit_equipment.has(recruit_id):
		return
	var item = recruit_equipment[recruit_id].get(slot)
	if item == null:
		return
	recruit_equipment[recruit_id][slot] = null
	_add_to_stash(item)

func get_recruit_bonus(recruit_id: String, stat_type: String) -> float:
	if not recruit_equipment.has(recruit_id):
		return 0.0
	var total := 0.0
	for slot in recruit_equipment[recruit_id]:
		var item = recruit_equipment[recruit_id][slot]
		if item != null and item.get("stat_type", "") == stat_type:
			total += float(item.get("stat_value", 0.0))
	return total

func can_afford_recruit(recruit_id: String) -> bool:
	if recruit_id == "":
		return true
	var data: Dictionary = RECRUITS.get(recruit_id, {})
	return rubles >= int(data.get("cost", 0))

func hire_recruit(recruit_id: String) -> bool:
	if recruit_id == "":
		selected_recruit = ""
		return true
	if not RECRUITS.has(recruit_id):
		return false
	var data: Dictionary = RECRUITS[recruit_id]
	var cost: int = int(data.get("cost", 0))
	if not spend_currency("rubles", cost):
		return false
	selected_recruit = recruit_id
	return true

var selected_map: String = "overgrowth"

const MAP_SCENES := {
	"overgrowth": "res://scenes/Main.tscn",
	"boneclock": "res://scenes/Boneclock.tscn",
	"void_trench": "res://scenes/VoidTrench.tscn",
	"graveyard": "res://scenes/Graveyard.tscn",
	"ironscrap": "res://scenes/IronscrapYard.tscn",
	"the_foundry": "res://scenes/TheFoundry.tscn",
}

var character_created: bool = false

# --- Character Backgrounds: chosen at Character Creation, each grants a
# real, distinct starting bonus - not just flavor text.
const BACKGROUNDS := {
	"military": {"label": "Ex-Military", "desc": "Started with combat training.", "bonus_desc": "+1 free Firepower skill level"},
	"scavenger": {"label": "Scavenger", "desc": "Knows how to find value in junk.", "bonus_desc": "+300 starting Rubles"},
	"mechanic": {"label": "Mechanic", "desc": "Handy with tools and scrap.", "bonus_desc": "Starts with Screws, Duct Tape, Hard Plate"},
	"drifter": {"label": "Drifter", "desc": "Used to fending for themselves.", "bonus_desc": "Starts with a Trauma Kit and a Frag Grenade"},
	"smuggler": {"label": "Smuggler", "desc": "Knows how to move fast and quiet.", "bonus_desc": "+1 free Agility skill level"},
	"medic": {"label": "Field Medic", "desc": "Trained to keep people alive.", "bonus_desc": "+1 free Regeneration skill level"},
	"hunter": {"label": "Hunter", "desc": "Grew up tracking things that could track back.", "bonus_desc": "+1 free Loot Sense skill level"},
}
var player_background: String = "drifter"

# --- Character creation appearance extras: torso silhouette, a glow
# accent color, and a backpack/rig style - all purely visual choices
# that also carry over onto the real in-raid player model.
const TORSO_STYLES := {
	"sleek": {"label": "Sleek Jacket", "desc": "A lean hunter's profile - fast and quiet."},
	"bulky": {"label": "Bulky Exo-Suit", "desc": "A wide, armored silhouette - unmistakable at a distance."},
	"tactical": {"label": "Tactical Vest", "desc": "Plate carrier over a rig - built for someone who expects a fight."},
	"trench_coat": {"label": "Trench Coat", "desc": "Long, heavy coat - flares out below the waist, hides a lot."},
}
var player_torso_style: String = "sleek"

const GLOW_COLORS := [
	{"label": "Neon Purple", "color": Color(0.7, 0.3, 1.0, 1)},
	{"label": "Toxic Green", "color": Color(0.4, 1.0, 0.35, 1)},
	{"label": "Stealth Gray", "color": Color(0.5, 0.5, 0.55, 0.6)},
]
var player_glow_color_idx: int = 0

const BACKPACK_STYLES := {
	"none": {"label": "No Pack", "desc": "Nothing on your back."},
	"sleek_rig": {"label": "Sleek Rig", "desc": "A compact chest rig - the mark of a Hunter build."},
	"massive_pack": {"label": "Massive Pack", "desc": "A hauler's rucksack - the mark of a Looter build."},
}
var player_backpack_style: String = "sleek_rig"

const PLAYER_TRAITS := {
	"adrenaline_junkie": {"label": "Adrenaline Junkie", "desc": "Something kicks in when it really shouldn't - the closer to dying, the faster they move.", "bonus_desc": "+30% Speed while below 30% HP"},
	"second_wind": {"label": "Second Wind", "desc": "Been dead before, at least once. Didn't take.", "bonus_desc": "Survive one lethal hit per raid at 1 HP"},
	"ghost_step": {"label": "Ghost Step", "desc": "Walks like the Sector already knows them - and mostly leaves them alone.", "bonus_desc": "Enemies detect you at 20% shorter range"},
	"lucky_break": {"label": "Lucky Break", "desc": "Doesn't believe in luck. Benefits from it anyway.", "bonus_desc": "10% chance any shot costs no ammo"},
	"loot_hound": {"label": "Loot Hound", "desc": "Finds things other people walk right past.", "bonus_desc": "+8% loot chance from enemies and containers"},
	"silver_tongued": {"label": "Silver-Tongued", "desc": "People give them a better deal, and can't quite say why.", "bonus_desc": "10% cheaper Trader prices"},
}
var player_trait: String = "adrenaline_junkie"

# --- Face customization: hair, eyes, mouth, skin - a handful of presets
# each, combined for real variety without needing a full color-picker UI.
const HAIR_COLORS := [Color(0.15, 0.12, 0.1, 1), Color(0.55, 0.4, 0.2, 1), Color(0.05, 0.05, 0.06, 1), Color(0.75, 0.7, 0.6, 1), Color(0.6, 0.15, 0.1, 1)]

# Preset swatches for the case-tagging system (Loot Bags / Pet Cases) -
# a small fixed palette instead of a full color picker, matching the
# rest of the UI's simple swatch-button style.
const TAG_COLORS := [
	Color(1.0, 0.35, 0.35, 1), Color(1.0, 0.65, 0.25, 1), Color(0.95, 0.85, 0.3, 1),
	Color(0.4, 0.85, 0.4, 1), Color(0.35, 0.85, 0.85, 1), Color(0.4, 0.6, 1.0, 1),
	Color(0.75, 0.45, 1.0, 1), Color(1.0, 1.0, 1.0, 1),
]
const EYE_COLORS := [Color(0.25, 0.45, 0.75, 1), Color(0.3, 0.55, 0.3, 1), Color(0.4, 0.28, 0.15, 1), Color(0.6, 0.6, 0.65, 1)]
const MOUTH_STYLES := ["neutral", "grim", "smirk", "happy"]
const SKIN_COLORS := [Color(0.96, 0.82, 0.68, 1), Color(0.87, 0.68, 0.53, 1), Color(0.78, 0.6, 0.47, 1), Color(0.62, 0.45, 0.32, 1), Color(0.42, 0.29, 0.19, 1), Color(0.28, 0.19, 0.13, 1)]
var player_hair_color_idx: int = 0
var player_eye_color_idx: int = 0
var player_mouth_style_idx: int = 0
var player_skin_color_idx: int = 2

# --- Particle Trail: a cosmetic effect that follows the player around,
# both in-raid and in the Hideout (both use the same Player.tscn, see
# Player.gd's _build_particle_trail()).
const PARTICLE_TRAILS := {
	"none": {"label": "None", "desc": "No trail."},
	"dust": {"label": "Dust Motes", "desc": "Faint floating dust motes drift up and behind you."},
	"shadow_smoke": {"label": "Dripping Shadow Smoke", "desc": "Dark smoke drips and curls off you like something's still burning."},
	"static": {"label": "Crackling Static", "desc": "Small crackling sparks of electricity pop off you as you move."},
}
var player_particle_trail: String = "none"

func reset_character() -> void:
	rubles = 0
	junk = 0
	artifacts = 0
	alloys = 0
	souls = 0
	blossoms = 0
	skill_points = 0
	stones = 0
	rank_points = 0
	arena_rank_points = 0
	arena_reward_tiers_granted = -1
	blood_shards = 0
	bloodline_tier = 0
	bloodline_progress = 0
	battle_pass_tier = 0
	battle_pass_progress = 0
	milestone_tier = 0
	milestone_progress = 0
	guild_honor = 0
	guild_battle_pass_tier = 0
	guild_battle_pass_progress = 0
	last_clan_war_day = -1
	gauntlet_best_level = 0
	engrams = []
	salvaged_beasts_tickets = 0
	salvaged_beasts_tier = 0
	salvaged_beasts_progress = 0
	graveyard_kills = 0
	monthly_pass_owned = false
	double_xp_owned = false
	fast_hatching_owned = false
	claimed_free_store_packs = []
	leaderboard_player_baseline = {}
	_last_starter_pack_claim = -STARTER_PACK_COOLDOWN
	stash_items = []
	backpack_storage = []
	unlocked_cases = {"medical": false, "gun": false, "armor": false, "key": false}
	medical_case_storage = []
	gun_case_storage = []
	armor_case_storage = []
	key_case_storage = []
	equipped_items = {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null, "backpack": null}
	player_loadout_presets = [null, null, null]
	player_guild_id = ""
	player_guild_name = ""
	player_guild_tag = ""
	player_guild_is_custom = false
	prestige_level = 0
	for key in upgrades.keys():
		upgrades[key]["level"] = 0
	for key in hideout_upgrades.keys():
		hideout_upgrades[key]["level"] = 0
	quest_status = {}
	owned_skins = {}
	equipped_skins = {}
	owned_titles = []
	owned_badges = []
	equipped_title = ""
	equipped_chat_background = ""
	unlocked_achievements = {}
	achievement_flag_multiversal_pull = false
	achievement_flag_close_call = false
	discovered_enemies = {}
	seen_collectibles = {}
	ghost_recruited = false
	rose_talked_to = false
	recruit_equipment = {
		"clarity": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
		"sorrow": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
		"glenn": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
		"big_crax": {"head": null, "body": null, "weapon": null, "accessory": null, "boots": null},
	}
	owned_pets = []
	equipped_pet = ""
	owned_pet_instances = {}
	_pet_instance_counter = 0
	pet_eggs = []
	egg_hatching_slots = []
	flea_market_listings = []
	_flea_listing_counter = 0
	mail_messages = []
	_mail_counter = 0
	welcome_mail_sent = false
	# Deliberately NOT reset to false: the "From Tech Test to Alpha" mail is a
	# one-time historical transition gift for saves that genuinely existed
	# before Dead Sector left its Tech Test period. A character reset isn't
	# that - it's a fresh start well after that transition already happened,
	# so it shouldn't re-grant a huge "welcome back, veteran" mail every time
	# someone deletes and remakes a character.
	tech_test_mail_sent = true
	alpha_rewards_claimed = false
	has_seen_welcome = false
	player_level = 1
	player_xp = 0
	player_score = 0
	stat_total_loot_collected = 0
	stat_total_sold = 0
	stat_enemies_killed = 0
	stat_deaths = 0
	stat_extractions = 0
	stat_scav_extractions = 0
	stat_crates_opened = 0
	stat_blueprints_researched = 0
	stat_eggs_hatched = 0
	bitcoin_gpu_slots = [null, null, null, null]
	character_created = false
	player_name = "Operative"
	player_build = 0.5
	player_bio = "Just another operative trying to make it out alive."
	player_portrait_id = "portrait_1"
	player_background = "drifter"
	player_hair_color_idx = 0
	player_eye_color_idx = 0
	player_mouth_style_idx = 0
	player_skin_color_idx = 2
	player_torso_style = "sleek"
	player_glow_color_idx = 0
	player_backpack_style = "sleek_rig"
	player_trait = "adrenaline_junkie"
	player_particle_trail = "none"
	save_game()

func apply_background_bonus(bg_id: String) -> void:
	match bg_id:
		"military":
			var lvl: int = int(upgrades["damage"].get("level", 0))
			var mx: int = int(upgrades["damage"].get("max_level", 0))
			upgrades["damage"]["level"] = min(lvl + 1, mx)
		"scavenger":
			add_currency("rubles", 300)
		"mechanic":
			_add_to_stash({"name": "Screws", "value": 10, "icon_key": "screws", "rarity": "common", "slot": "valuable", "stat_type": "", "stat_value": 0.0})
			_add_to_stash({"name": "Duct Tape", "value": 18, "icon_key": "duct_tape", "rarity": "common", "slot": "valuable", "stat_type": "", "stat_value": 0.0})
			_add_to_stash({"name": "Hard Plate", "value": 55, "icon_key": "hard_plate", "rarity": "uncommon", "slot": "valuable", "stat_type": "", "stat_value": 0.0})
		"drifter":
			_add_to_stash({"name": "Trauma Kit", "value": 45, "slot": "consumable", "icon_key": "medkit", "rarity": "uncommon", "consumable_type": "heal", "heal_amount": 60.0})
			_add_to_stash({"name": "Frag Grenade", "value": 30, "slot": "consumable", "icon_key": "grenade", "rarity": "uncommon", "consumable_type": "grenade", "grenade_type": "frag", "grenade_damage": 55, "grenade_radius": 95.0})
		"smuggler":
			var lvl: int = int(upgrades["speed"].get("level", 0))
			var mx: int = int(upgrades["speed"].get("max_level", 0))
			upgrades["speed"]["level"] = min(lvl + 1, mx)
		"medic":
			var lvl: int = int(upgrades["health_regen"].get("level", 0))
			var mx: int = int(upgrades["health_regen"].get("max_level", 0))
			upgrades["health_regen"]["level"] = min(lvl + 1, mx)
		"hunter":
			var lvl: int = int(upgrades["loot_sense"].get("level", 0))
			var mx: int = int(upgrades["loot_sense"].get("max_level", 0))
			upgrades["loot_sense"]["level"] = min(lvl + 1, mx)

func apply_trait_bonus(_trait_id: String) -> void:
	# Traits used to grant a one-time free skill level here. The new set
	# (Adrenaline Junkie, Second Wind, Ghost Step, Lucky Break, Loot
	# Hound, Silver-Tongued) are all live passive checks against
	# player_trait instead - see Player.gd, Enemy.gd, roll_corpse_loot(),
	# and get_discounted_trader_cost() - so there's nothing to grant
	# up front anymore. Kept as a real function (not deleted) since
	# CharacterCreation.gd calls it unconditionally on confirm.
	pass

var player_name: String = "Operative"
var player_build: float = 0.5  # 0.0 = lean, 0.5 = average, 1.0 = heavy

func timeout_run() -> void:
	run_timed_out = true
	end_run(false)

# A snapshot of equipped_items taken at the start of each run. Anything
# equipped or swapped DURING the run (from freshly-found loot) reverts to
# this snapshot if the player dies - only a successful extraction makes
# mid-run equip changes permanent.
var run_start_equipped_snapshot: Dictionary = {}

func snapshot_equipped_for_run() -> void:
	run_start_equipped_snapshot = equipped_items.duplicate(true)

# Keys are now regular loot items (slot "key") that live in carried_loot /
# stash_items just like everything else - see Loot.gd's door_key_id field.
# A door only opens if the matching key is CURRENTLY in the backpack.
func has_key_in_backpack(key_id: String) -> bool:
	for item in carried_loot:
		if item.get("door_key_id", "") == key_id:
			return true
	return false

# Settings (kept for the whole session; not saved to disk yet)
var master_volume: float = 100.0
var music_volume: float = 100.0
var sfx_volume: float = 100.0
var window_mode_setting: String = "windowed_fullscreen"
var vsync_enabled: bool = true
var screen_shake_enabled: bool = true

# --- Keybinds: Interact (F) is fixed for now (it's referenced directly
# across a couple dozen scripts, not worth the risk of rebinding
# project-wide in one pass) - Prone and Close-Up View are the two real,
# rebindable keys.
var keybinds: Dictionary = {"prone": KEY_Z, "interact": KEY_F, "jump": KEY_SPACE, "dash": KEY_SHIFT, "nightvision": KEY_N, "chat": KEY_ENTER, "inventory": KEY_TAB}
const KEYBIND_DEFAULTS := {"prone": KEY_Z, "interact": KEY_F, "jump": KEY_SPACE, "dash": KEY_SHIFT, "nightvision": KEY_N, "chat": KEY_ENTER, "inventory": KEY_TAB}

func get_keybind(action: String) -> int:
	return int(keybinds.get(action, KEYBIND_DEFAULTS.get(action, KEY_NONE)))

func set_keybind(action: String, keycode: int) -> void:
	keybinds[action] = keycode
	save_game()

func _ready() -> void:
	_setup_audio_buses()
	_crosshair_texture = _make_crosshair_texture()
	_menu_cursor_texture = _make_menu_cursor_texture()
	load_game()
	_reroll_featured_skins()
	_roll_scav_loadout()
	_roll_pet_shop_stock()
	_check_flea_market()
	_maybe_send_welcome_mail()
	_maybe_send_tech_test_mail()
	_maybe_send_daily_newsletter()
	get_tree().set_auto_accept_quit(false)
	# Wait a frame so the OS window actually exists before switching its
	# mode - calling window_set_mode() during autoload _ready (before the
	# window is mapped) glitches visibly and can silently fail to take.
	await get_tree().process_frame
	apply_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

# --- Save / Load: everything persistent (currencies, Stash, gear,
# upgrades, quest progress, skins) is written to disk so progress
# survives closing the game. Saved automatically when a run ends, when
# the window is closed, and periodically while playing.
const SAVE_PATH := "user://savegame.json"
const SAVE_BACKUP_PATH := "user://savegame.json.bak"

# A genuine full wipe for the Main Menu's Wipe button - deletes the save
# file outright rather than manually resetting every individual field
# (currencies, quests, mail, achievements, badges, titles, Rank Points,
# discovered enemies, everything). A hand-maintained reset list only
# stays correct until the next new feature adds a field somewhere and
# someone forgets to add it there too - deleting the file and actually
# restarting the game is the only way to guarantee a truly clean slate,
# matching exactly what a brand new install looks like.
func wipe_everything() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(SAVE_PATH.trim_prefix("user://")):
		dir.remove(SAVE_PATH.trim_prefix("user://"))
	# save_game()'s own rotate-backup write strategy guarantees a .bak
	# file exists from ordinary play - deleting only the primary save
	# left load_game() falling through to THAT on the next launch
	# (exactly the "couldn't read the main save, restored from backup"
	# path) and silently restoring the entire pre-wipe character,
	# Wipe having visibly done nothing at all.
	if dir != null and dir.file_exists(SAVE_BACKUP_PATH.trim_prefix("user://")):
		dir.remove(SAVE_BACKUP_PATH.trim_prefix("user://"))
	# Leaderboard rival stats were never actually written to the save
	# file (only your own baseline was), so the restart that follows
	# this already resets them naturally - clearing them directly here
	# too is a real guarantee rather than relying on that.
	leaderboard_seeds.clear()
	leaderboard_player_baseline.clear()
	_leaderboard_last_tick = 0.0

# Bumped whenever a save-breaking change goes out (new required fields,
# restructured data, etc). Old saves that don't match get wiped instead
# of loaded half-correctly, since a partially-applied old save is worse
# than a clean fresh start.
# --- Flea Market: list your own Stash items for other "players" to buy,
# and browse listings from them too. Everything runs on real wall-clock
# time (same idea as the Bitcoin Farm's GPU mining) so it keeps
# progressing even while the game is closed - your own listings get
# snapped up by a random simulated buyer somewhere between 5 and 10 real
# minutes after listing, and anything still unsold after 2 real days
# gets mailed back to you instead of just vanishing.
# --- Flea Market variety pool: 100 additional named items that exist
# purely to give the Flea Market's "other players' listings" real
# breadth, so the same handful of enemy-drop/loot-bag items don't cycle
# forever. Deliberately its own pool, separate from ENEMY_LOOT_POOL and
# LOOT_BAG_GEAR_POOL, so none of this touches actual raid drop rates -
# it only ever feeds _roll_flea_market_item() below.
const FLEA_MARKET_EXTRA_POOL := [
	{"name": "Threadbare Bracer Vest", "value": 118, "slot": "body", "stat_type": "max_health", "stat_value": 21.6, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Sundered Cover", "value": 31, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "common"},
	{"name": "Cinder Striders", "value": 81, "slot": "boots", "stat_type": "speed", "stat_value": 14.9, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Ironclad Skullguard", "value": 515, "slot": "head", "stat_type": "max_health", "stat_value": 41.9, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Rogue Trinket", "value": 231, "slot": "accessory", "stat_type": "damage", "stat_value": 13.5, "icon_key": "ring", "rarity": "epic"},
	{"name": "Longhaul Skullguard", "value": 313, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "legendary"},
	{"name": "Ironclad Faceplate", "value": 28, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "common"},
	{"name": "Nomad's Kit", "value": 185, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Silent Rucksack", "value": 164, "slot": "backpack", "stat_type": "max_health", "stat_value": 20.2, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Molted Loop", "value": 110, "slot": "accessory", "stat_type": "speed", "stat_value": 20.2, "icon_key": "ring", "rarity": "rare"},
	{"name": "Waylaid Soles", "value": 337, "slot": "boots", "stat_type": "speed", "stat_value": 39.2, "icon_key": "boots", "rarity": "legendary"},
	{"name": "Grim Rattler", "value": 118, "slot": "weapon", "stat_type": "damage", "stat_value": 21.6, "icon_key": "rifle", "rarity": "rare"},
	{"name": "Ghostwalk Chain", "value": 126, "slot": "accessory", "stat_type": "damage", "stat_value": 10.8, "icon_key": "ring", "rarity": "rare"},
	{"name": "Cutthroat Skullcap", "value": 49, "slot": "head", "stat_type": "max_health", "stat_value": 14.9, "icon_key": "helmet", "rarity": "common"},
	{"name": "Static Token", "value": 104, "slot": "accessory", "stat_type": "damage", "stat_value": 6.8, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Drifter's Frame Pack", "value": 86, "slot": "backpack", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Hairline Frame Pack", "value": 236, "slot": "backpack", "stat_type": "max_health", "stat_value": 25.7, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Tarnished Helm", "value": 78, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Fractured Skullcap", "value": 131, "slot": "head", "stat_type": "max_health", "stat_value": 23.0, "icon_key": "helmet", "rarity": "rare"},
	{"name": "Gutted Liner", "value": 26, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "common"},
	{"name": "Obsidian Clompers", "value": 127, "slot": "boots", "stat_type": "max_health", "stat_value": 18.9, "icon_key": "boots", "rarity": "rare"},
	{"name": "Afterhours Plate", "value": 23, "slot": "body", "stat_type": "max_health", "stat_value": 9.5, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Fractured Boots", "value": 73, "slot": "boots", "stat_type": "speed", "stat_value": 17.6, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Crimson Cargo Rig", "value": 164, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Waylaid Sling", "value": 46, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "common"},
	{"name": "Crimson Charm", "value": 138, "slot": "accessory", "stat_type": "damage", "stat_value": 9.5, "icon_key": "ring", "rarity": "rare"},
	{"name": "Corroded Clasp", "value": 84, "slot": "accessory", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Backalley Pinpoint", "value": 209, "slot": "weapon", "stat_type": "damage", "stat_value": 28.4, "icon_key": "sniper", "rarity": "epic"},
	{"name": "Obsidian Pack", "value": 878, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "exotic"},
	{"name": "Hollow Kicks", "value": 31, "slot": "boots", "stat_type": "speed", "stat_value": 13.5, "icon_key": "boots", "rarity": "common"},
	{"name": "Choke Kicks", "value": 33, "slot": "boots", "stat_type": "speed", "stat_value": 12.2, "icon_key": "boots", "rarity": "common"},
	{"name": "Fractured Coil", "value": 200, "slot": "accessory", "stat_type": "speed", "stat_value": 29.7, "icon_key": "ring", "rarity": "epic"},
	{"name": "Rustbound Clompers", "value": 111, "slot": "boots", "stat_type": "speed", "stat_value": 20.2, "icon_key": "boots", "rarity": "rare"},
	{"name": "Ragged Clompers", "value": 25, "slot": "boots", "stat_type": "speed", "stat_value": 14.9, "icon_key": "boots", "rarity": "common"},
	{"name": "Undertow Sneakers", "value": 39, "slot": "boots", "stat_type": "speed", "stat_value": 13.5, "icon_key": "boots", "rarity": "common"},
	{"name": "Jagged Platebody", "value": 286, "slot": "body", "stat_type": "max_health", "stat_value": 35.1, "icon_key": "chestplate", "rarity": "legendary"},
	{"name": "Bleak Palm Piece", "value": 941, "slot": "weapon", "stat_type": "damage", "stat_value": 62.1, "icon_key": "pistol", "rarity": "exotic"},
	{"name": "Hushed Striders", "value": 85, "slot": "boots", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Gutted Torso Rig", "value": 120, "slot": "body", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Gutted Boots", "value": 41, "slot": "boots", "stat_type": "speed", "stat_value": 14.9, "icon_key": "boots", "rarity": "common"},
	{"name": "Sundered Cap", "value": 52, "slot": "head", "stat_type": "max_health", "stat_value": 12.2, "icon_key": "helmet", "rarity": "common"},
	{"name": "Silent Guard", "value": 131, "slot": "body", "stat_type": "max_health", "stat_value": 20.2, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Cobalt Headpiece", "value": 487, "slot": "head", "stat_type": "max_health", "stat_value": 47.2, "icon_key": "helmet", "rarity": "mythic"},
	{"name": "Fractured Growth", "value": 84, "slot": "weapon", "stat_type": "damage", "stat_value": 13.5, "icon_key": "thorn", "rarity": "uncommon"},
	{"name": "Choke Pack", "value": 50, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "common"},
	{"name": "Threadbare Trudgers", "value": 802, "slot": "boots", "stat_type": "speed", "stat_value": 72.9, "icon_key": "boots", "rarity": "exotic"},
	{"name": "Scavenged Ring", "value": 84, "slot": "accessory", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Hushed Signet", "value": 115, "slot": "accessory", "stat_type": "damage", "stat_value": 9.5, "icon_key": "ring", "rarity": "rare"},
	{"name": "Cutrate Kicks", "value": 34, "slot": "boots", "stat_type": "max_health", "stat_value": 10.8, "icon_key": "boots", "rarity": "common"},
	{"name": "Waylaid Stalkers", "value": 141, "slot": "boots", "stat_type": "speed", "stat_value": 23.0, "icon_key": "boots", "rarity": "rare"},
	{"name": "Overdue Hood", "value": 27, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "common"},
	{"name": "Wired Platebody", "value": 116, "slot": "body", "stat_type": "speed", "stat_value": 21.6, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Barren Amulet", "value": 210, "slot": "accessory", "stat_type": "speed", "stat_value": 31.1, "icon_key": "ring", "rarity": "epic"},
	{"name": "Longhaul Stalkers", "value": 54, "slot": "boots", "stat_type": "speed", "stat_value": 12.2, "icon_key": "boots", "rarity": "common"},
	{"name": "Scorched Grips", "value": 147, "slot": "boots", "stat_type": "max_health", "stat_value": 20.2, "icon_key": "boots", "rarity": "rare"},
	{"name": "Deadline Carrier", "value": 181, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Cutrate Plate", "value": 172, "slot": "body", "stat_type": "max_health", "stat_value": 23.0, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Sideline Armor", "value": 87, "slot": "body", "stat_type": "max_health", "stat_value": 16.2, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Cutthroat Trinket", "value": 109, "slot": "accessory", "stat_type": "damage", "stat_value": 8.1, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Corroded Field Pack", "value": 81, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Nomad's Boomstick", "value": 211, "slot": "weapon", "stat_type": "damage", "stat_value": 31.1, "icon_key": "shotgun", "rarity": "epic"},
	{"name": "Cutrate Pack", "value": 51, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "common"},
	{"name": "Feral Loafers", "value": 28, "slot": "boots", "stat_type": "speed", "stat_value": 10.8, "icon_key": "boots", "rarity": "common"},
	{"name": "Slagline Talisman", "value": 96, "slot": "accessory", "stat_type": "speed", "stat_value": 14.9, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Foundry Torso Rig", "value": 33, "slot": "body", "stat_type": "speed", "stat_value": 12.2, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Static Stalkers", "value": 255, "slot": "boots", "stat_type": "max_health", "stat_value": 25.7, "icon_key": "boots", "rarity": "epic"},
	{"name": "Undertow Hood", "value": 174, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "rare"},
	{"name": "Hushed Kit", "value": 25, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "common"},
	{"name": "Ironclad Popgun", "value": 137, "slot": "weapon", "stat_type": "damage", "stat_value": 18.9, "icon_key": "pistol", "rarity": "rare"},
	{"name": "Fallow Waders", "value": 268, "slot": "boots", "stat_type": "speed", "stat_value": 29.7, "icon_key": "boots", "rarity": "epic"},
	{"name": "Verdigris Sneakers", "value": 70, "slot": "boots", "stat_type": "speed", "stat_value": 17.6, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Broken Pouch Set", "value": 125, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Cobalt Ring", "value": 25, "slot": "accessory", "stat_type": "max_health", "stat_value": 10.8, "icon_key": "ring", "rarity": "common"},
	{"name": "Hazard Signet", "value": 118, "slot": "accessory", "stat_type": "speed", "stat_value": 18.9, "icon_key": "ring", "rarity": "rare"},
	{"name": "Gutted Ring", "value": 23, "slot": "accessory", "stat_type": "speed", "stat_value": 16.2, "icon_key": "ring", "rarity": "common"},
	{"name": "Blighted Brainbucket", "value": 52, "slot": "head", "stat_type": "max_health", "stat_value": 14.9, "icon_key": "helmet", "rarity": "common"},
	{"name": "Tarnished Striders", "value": 110, "slot": "boots", "stat_type": "speed", "stat_value": 21.6, "icon_key": "boots", "rarity": "rare"},
	{"name": "Nightfall Field Pack", "value": 314, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "legendary"},
	{"name": "Broken Bracer Vest", "value": 28, "slot": "body", "stat_type": "max_health", "stat_value": 9.5, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Riftborn Ring", "value": 519, "slot": "accessory", "stat_type": "damage", "stat_value": 21.6, "icon_key": "ring", "rarity": "mythic"},
	{"name": "Shattered Grips", "value": 147, "slot": "boots", "stat_type": "speed", "stat_value": 21.6, "icon_key": "boots", "rarity": "rare"},
	{"name": "Cutthroat Clompers", "value": 46, "slot": "boots", "stat_type": "speed", "stat_value": 14.9, "icon_key": "boots", "rarity": "common"},
	{"name": "Waylaid Grips", "value": 54, "slot": "boots", "stat_type": "speed", "stat_value": 13.5, "icon_key": "boots", "rarity": "common"},
	{"name": "Cobalt Talisman", "value": 160, "slot": "accessory", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "ring", "rarity": "rare"},
	{"name": "Drifter's Signet", "value": 34, "slot": "accessory", "stat_type": "max_health", "stat_value": 12.2, "icon_key": "ring", "rarity": "common"},
	{"name": "Cutthroat Armor", "value": 109, "slot": "body", "stat_type": "max_health", "stat_value": 16.2, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Wired Boots", "value": 110, "slot": "boots", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Ghostwalk Cargo Rig", "value": 233, "slot": "backpack", "stat_type": "max_health", "stat_value": 24.3, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Fractured Rig", "value": 36, "slot": "body", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Cutthroat Satchel", "value": 234, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Nomad's Field Pack", "value": 267, "slot": "backpack", "stat_type": "max_health", "stat_value": 23.0, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Hushed Door Kicker", "value": 231, "slot": "weapon", "stat_type": "damage", "stat_value": 32.4, "icon_key": "shotgun", "rarity": "epic"},
	{"name": "Ironclad Sling", "value": 183, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Verdigris Band", "value": 170, "slot": "accessory", "stat_type": "speed", "stat_value": 20.2, "icon_key": "ring", "rarity": "rare"},
	{"name": "Undertow Boots", "value": 48, "slot": "boots", "stat_type": "speed", "stat_value": 16.2, "icon_key": "boots", "rarity": "common"},
	{"name": "Static Pack", "value": 105, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Frostline Firestarter", "value": 184, "slot": "weapon", "stat_type": "damage", "stat_value": 21.6, "icon_key": "flamethrower", "rarity": "rare"},
	{"name": "Cutrate Platebody", "value": 69, "slot": "body", "stat_type": "speed", "stat_value": 14.9, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Slagline Rucksack", "value": 231, "slot": "backpack", "stat_type": "max_health", "stat_value": 23.0, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Deadline Torso Rig", "value": 79, "slot": "body", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Nightfall Sparkgun", "value": 31, "slot": "weapon", "stat_type": "damage", "stat_value": 5.4, "icon_key": "railgun", "rarity": "common"},
	{"name": "Bleak Rucksack", "value": 119, "slot": "backpack", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Waylaid Liner", "value": 26, "slot": "head", "stat_type": "max_health", "stat_value": 12.2, "icon_key": "helmet", "rarity": "common"},
	{"name": "Threadbare Trinket", "value": 91, "slot": "accessory", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Blackout Chain", "value": 169, "slot": "accessory", "stat_type": "speed", "stat_value": 20.2, "icon_key": "ring", "rarity": "rare"},
	{"name": "Backalley Carrier", "value": 143, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Gutted Longshot", "value": 26, "slot": "weapon", "stat_type": "damage", "stat_value": 6.8, "icon_key": "sniper", "rarity": "common"},
	{"name": "Blackout Chestwrap", "value": 240, "slot": "body", "stat_type": "max_health", "stat_value": 24.3, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Gutted Snub", "value": 836, "slot": "weapon", "stat_type": "damage", "stat_value": 59.4, "icon_key": "pistol", "rarity": "exotic"},
	{"name": "Barren Trinket", "value": 95, "slot": "accessory", "stat_type": "speed", "stat_value": 17.6, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Mildewed Haul Bag", "value": 27, "slot": "backpack", "stat_type": "max_health", "stat_value": 9.5, "icon_key": "backpack", "rarity": "common"},
	{"name": "Dustveil Ribcage Guard", "value": 219, "slot": "body", "stat_type": "max_health", "stat_value": 27.0, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Salvage Field Pack", "value": 96, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Shattered Trinket", "value": 46, "slot": "accessory", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "ring", "rarity": "common"},
	{"name": "Ragged Rig", "value": 81, "slot": "body", "stat_type": "speed", "stat_value": 20.2, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Foundry Chain", "value": 68, "slot": "accessory", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Splinter Liner", "value": 71, "slot": "head", "stat_type": "max_health", "stat_value": 14.9, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Faded Chain", "value": 35, "slot": "accessory", "stat_type": "speed", "stat_value": 13.5, "icon_key": "ring", "rarity": "common"},
	{"name": "Fallow Guard", "value": 130, "slot": "body", "stat_type": "speed", "stat_value": 21.6, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Hollow Loadout", "value": 157, "slot": "backpack", "stat_type": "max_health", "stat_value": 18.9, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Hairline Charm", "value": 526, "slot": "accessory", "stat_type": "damage", "stat_value": 23.0, "icon_key": "ring", "rarity": "mythic"},
	{"name": "Crimson Loop", "value": 177, "slot": "accessory", "stat_type": "max_health", "stat_value": 21.6, "icon_key": "ring", "rarity": "rare"},
	{"name": "Deadline Talisman", "value": 51, "slot": "accessory", "stat_type": "damage", "stat_value": 5.4, "icon_key": "ring", "rarity": "common"},
	{"name": "Slagline Treads", "value": 66, "slot": "boots", "stat_type": "speed", "stat_value": 17.6, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Lowlight Field Pack", "value": 163, "slot": "backpack", "stat_type": "max_health", "stat_value": 18.9, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Hushed Rucksack", "value": 72, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Redline Ribcage Guard", "value": 522, "slot": "body", "stat_type": "speed", "stat_value": 51.3, "icon_key": "chestplate", "rarity": "mythic"},
	{"name": "Fallow Skullguard", "value": 257, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Ashen Trinket", "value": 84, "slot": "accessory", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Slagline Visor", "value": 107, "slot": "head", "stat_type": "max_health", "stat_value": 14.9, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Faded Cap", "value": 202, "slot": "head", "stat_type": "max_health", "stat_value": 23.0, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Ghostwalk Charm", "value": 26, "slot": "accessory", "stat_type": "max_health", "stat_value": 14.9, "icon_key": "ring", "rarity": "common"},
	{"name": "Copperline Rig", "value": 74, "slot": "backpack", "stat_type": "max_health", "stat_value": 16.2, "icon_key": "backpack", "rarity": "uncommon"},
	{"name": "Static Bracelet", "value": 94, "slot": "accessory", "stat_type": "max_health", "stat_value": 17.6, "icon_key": "ring", "rarity": "uncommon"},
	{"name": "Mildewed Faceplate", "value": 297, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "legendary"},
	{"name": "Choke Hood", "value": 295, "slot": "head", "stat_type": "max_health", "stat_value": 35.1, "icon_key": "helmet", "rarity": "legendary"},
	{"name": "Sundered Kicks", "value": 324, "slot": "boots", "stat_type": "max_health", "stat_value": 35.1, "icon_key": "boots", "rarity": "legendary"},
	{"name": "Offgrid Liner", "value": 112, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "rare"},
	{"name": "Blackout Loafers", "value": 82, "slot": "boots", "stat_type": "speed", "stat_value": 18.9, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Backfill Bracelet", "value": 335, "slot": "accessory", "stat_type": "speed", "stat_value": 35.1, "icon_key": "ring", "rarity": "legendary"},
	{"name": "Fractured Soles", "value": 69, "slot": "boots", "stat_type": "speed", "stat_value": 16.2, "icon_key": "boots", "rarity": "uncommon"},
	{"name": "Overdue Guard", "value": 210, "slot": "body", "stat_type": "max_health", "stat_value": 23.0, "icon_key": "chestplate", "rarity": "epic"},
	{"name": "Wired Ruck", "value": 121, "slot": "backpack", "stat_type": "max_health", "stat_value": 18.9, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Sideline Headwrap", "value": 93, "slot": "head", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Bleak Pouch Set", "value": 110, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Splinter Pack", "value": 117, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Cutthroat Carrier", "value": 27, "slot": "body", "stat_type": "speed", "stat_value": 14.9, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Afterhours Brainbucket", "value": 317, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "legendary"},
	{"name": "Scorched Visor", "value": 259, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "epic"},
	{"name": "Salvage Sling", "value": 160, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Wired Rucksack", "value": 533, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "mythic"},
	{"name": "Cinder Ruck", "value": 329, "slot": "backpack", "stat_type": "max_health", "stat_value": 32.4, "icon_key": "backpack", "rarity": "legendary"},
	{"name": "Wraithbound Cuirass", "value": 45, "slot": "body", "stat_type": "speed", "stat_value": 13.5, "icon_key": "chestplate", "rarity": "common"},
	{"name": "Afterhours Cap", "value": 50, "slot": "head", "stat_type": "max_health", "stat_value": 13.5, "icon_key": "helmet", "rarity": "common"},
	{"name": "Cobalt Armor", "value": 89, "slot": "body", "stat_type": "speed", "stat_value": 20.2, "icon_key": "chestplate", "rarity": "uncommon"},
	{"name": "Barren Visor", "value": 112, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "rare"},
	{"name": "Ironclad Harness", "value": 293, "slot": "body", "stat_type": "max_health", "stat_value": 35.1, "icon_key": "chestplate", "rarity": "legendary"},
	{"name": "Gutted Cuirass", "value": 530, "slot": "body", "stat_type": "max_health", "stat_value": 41.9, "icon_key": "chestplate", "rarity": "mythic"},
	{"name": "Backfill Cargo Rig", "value": 270, "slot": "backpack", "stat_type": "max_health", "stat_value": 23.0, "icon_key": "backpack", "rarity": "epic"},
	{"name": "Broken Skullguard", "value": 104, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Gutted Grips", "value": 507, "slot": "boots", "stat_type": "speed", "stat_value": 52.7, "icon_key": "boots", "rarity": "mythic"},
	{"name": "Foundry Ring", "value": 250, "slot": "accessory", "stat_type": "speed", "stat_value": 31.1, "icon_key": "ring", "rarity": "epic"},
	{"name": "Sundered Coil", "value": 28, "slot": "accessory", "stat_type": "max_health", "stat_value": 14.9, "icon_key": "ring", "rarity": "common"},
	{"name": "Riftborn Carrier", "value": 54, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "common"},
	{"name": "Threadbare Kindling", "value": 92, "slot": "weapon", "stat_type": "damage", "stat_value": 14.9, "icon_key": "flamethrower", "rarity": "uncommon"},
	{"name": "Hairline Carrier", "value": 159, "slot": "body", "stat_type": "speed", "stat_value": 24.3, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Drifter's Sling", "value": 115, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "rare"},
	{"name": "Sundered Skullcap", "value": 31, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "common"},
	{"name": "Hushed Visor", "value": 123, "slot": "head", "stat_type": "max_health", "stat_value": 18.9, "icon_key": "helmet", "rarity": "rare"},
	{"name": "Riftborn Sling", "value": 480, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "mythic"},
	{"name": "Waylaid Skullguard", "value": 81, "slot": "head", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "helmet", "rarity": "uncommon"},
	{"name": "Offgrid Satchel", "value": 306, "slot": "backpack", "stat_type": "loot_sense", "stat_value": 0.0, "icon_key": "backpack", "rarity": "legendary"},
	{"name": "Offgrid Carrier", "value": 165, "slot": "body", "stat_type": "max_health", "stat_value": 21.6, "icon_key": "chestplate", "rarity": "rare"},
	{"name": "Waylaid Band", "value": 96, "slot": "accessory", "stat_type": "speed", "stat_value": 20.2, "icon_key": "ring", "rarity": "uncommon"},
]

const FLEA_MARKET_LISTING_SECONDS := 86400.0 # 24 real hours
# 180 concurrent "other player" listings, spread across 6 gear
# categories (Weapon, Chestplate, Helmet, Boots, Backpack, Tactical
# Accessory) - enough for each category to realistically show around
# 30 items at once instead of the market feeling empty when filtered.
const FLEA_MARKET_OTHER_LISTING_TARGET := 180
# Other players' listings each get their own random lifespan in this range
# rather than one fixed duration - staggered, unpredictable turnover reads
# as "real people buying and listing things" instead of a market that
# resets on a visible timer.
const FLEA_MARKET_OTHER_MIN_SECONDS := 1800.0 # 30 real minutes
const FLEA_MARKET_OTHER_MAX_SECONDS := 5400.0 # 90 real minutes
# Weighted rarity roll for other players' listings - deliberately still
# common/uncommon-heavy so a Mythic or Exotic showing up feels like a
# real find, not the norm.
const FLEA_MARKET_RARITY_WEIGHTS := {
	"common": 24, "uncommon": 24, "rare": 18, "epic": 13,
	"legendary": 10, "mythic": 6, "exotic": 4,
}

# Fires whenever _check_flea_market() resolves a listing (sold/expired)
# in the background - FleaMarketPanel listens for this so a listing
# that resolves while the panel is open doesn't leave a stale row (live
# countdown, working-looking Cancel button) for something that's
# already gone.
signal flea_market_changed
var flea_market_listings: Array = []
var _flea_listing_counter: int = 0
var _flea_market_timer: float = 0.0
const FLEA_MARKET_CHECK_INTERVAL := 15.0

var _social_mail_timer: float = 0.0
var _next_social_mail_delay: float = 0.0

# Casual, unprompted mail from a random other operative - no rewards
# attached, purely social flavor to make the world feel populated even
# between raids.
const SOCIAL_MAIL_TEMPLATES := [
	["wants to party up", "hey, saw you online - wanna party up for a raid sometime? im down for boneclock or void trench, just lmk"],
	["is LFG", "yo LFG for a raid, you free? add me back if you're down to run something"],
	["wants to add you on Discord", "hey we should link up on discord and vc sometime - was gonna ask if you wanna run some raids together"],
	["has a gear question", "quick question - whats the best gear setup rn? trying to figure out a good loadout, any tips?"],
	["asked about your build", "saw your stash and it looked solid, what build are you running? wanna trade tips sometime"],
	["says gg", "gg on that last raid, you extracted clean. wanna squad up next time?"],
	["wants to duo rank", "im trying to push rank this reset, you tryna duo queue sometime?"],
	["has a question about the gauntlet", "how far have you gotten in the bloodline gauntlet? trying to figure out a good build for it"],
]

func _maybe_send_social_mail() -> void:
	var sender: String = LEADERBOARD_NAMES[randi() % LEADERBOARD_NAMES.size()]
	var pair: Array = SOCIAL_MAIL_TEMPLATES[randi() % SOCIAL_MAIL_TEMPLATES.size()]
	send_mail("%s %s" % [sender, pair[0]], str(pair[1]))

func _flea_now() -> float:
	return Time.get_unix_time_from_system()

# Rarity sets a soft floor/ceiling on what a listing can reasonably ask,
# so a Common item can't get listed for Mythic money - but the seller
# still picks the exact number within that band themselves.
func get_flea_market_price_range(item: Dictionary) -> Vector2i:
	var base_value: int = max(1, int(item.get("value", 10)))
	return Vector2i(int(base_value * 0.5), int(base_value * 3.0))

func list_item_on_flea_market(stash_index: int, price: int) -> bool:
	if stash_index < 0 or stash_index >= stash_items.size():
		return false
	if price <= 0:
		toast_requested.emit("Set a price above 0 first")
		return false
	var item: Dictionary = stash_items[stash_index]
	# Clamp to the same 0.5x-3x band the UI suggests - the price_edit field
	# is free-form text entry, so this is the only real enforcement against
	# listing junk for Mythic money and cashing out on the 75% sell chance.
	var price_range := get_flea_market_price_range(item)
	price = clampi(price, price_range.x, price_range.y)
	stash_items.remove_at(stash_index)
	_flea_listing_counter += 1
	var now := _flea_now()
	# 75% of listings genuinely sell, at a random point spread across
	# the full 24-hour window rather than always within a few minutes -
	# the other 25% really do expire unsold and mail the item back.
	# Deliberately not a guaranteed sale: this is meant to eventually
	# become a real multiplayer market, and one where everything always
	# sells isn't actually one.
	var will_sell: bool = randf() < 0.75
	var listing: Dictionary = {
		"id": _flea_listing_counter,
		"item": item,
		"price": price,
		"listed_at": now,
		"expire_at": now + FLEA_MARKET_LISTING_SECONDS,
		"will_sell": will_sell,
		"is_player": true,
		"seller_name": player_name if player_name != "" else "You",
	}
	if will_sell:
		listing["sell_at"] = now + randf_range(FLEA_MARKET_LISTING_SECONDS * 0.05, FLEA_MARKET_LISTING_SECONDS * 0.95)
	flea_market_listings.append(listing)
	toast_requested.emit("Listed %s for %d Rubles" % [str(item.get("name", "?")), price])
	save_game()
	return true

# Pulls a still-unsold listing of your own back into the Stash early.
func cancel_flea_listing(listing_id: int) -> bool:
	for i in range(flea_market_listings.size()):
		var l: Dictionary = flea_market_listings[i]
		if int(l.get("id", -1)) == listing_id and l.get("is_player", false):
			_add_to_stash(l["item"].duplicate(true))
			flea_market_listings.remove_at(i)
			save_game()
			return true
	return false

func buy_flea_listing(listing_id: int) -> bool:
	for i in range(flea_market_listings.size()):
		var l: Dictionary = flea_market_listings[i]
		if int(l.get("id", -1)) == listing_id and not l.get("is_player", false):
			var price: int = int(l.get("price", 0))
			if not spend_currency("rubles", price):
				toast_requested.emit("Not enough Rubles for that")
				return false
			_add_to_stash(l["item"].duplicate(true))
			flea_market_listings.remove_at(i)
			toast_requested.emit("Bought %s for %d Rubles" % [str(l["item"].get("name", "?")), price])
			save_game()
			return true
	return false

# Checked periodically (see _process below) and once on load, so sales
# and expirations that happened while the game was closed still resolve
# correctly using real elapsed time, not frames.
func _check_flea_market() -> void:
	var now := _flea_now()
	var changed := false
	var i := flea_market_listings.size() - 1
	while i >= 0:
		var l: Dictionary = flea_market_listings[i]
		if l.get("is_player", false):
			if l.get("will_sell", true) and l.has("sell_at") and now >= float(l.get("sell_at", 0.0)):
				var buyer: String = LEADERBOARD_NAMES[randi() % LEADERBOARD_NAMES.size()]
				var price: int = int(l.get("price", 0))
				var item_name: String = str(l["item"].get("name", "an item"))
				add_currency("rubles", price)
				send_mail(
					"Flea Market Sale",
					"%s bought your %s for %d Rubles. The Rubles have already been added to your balance." % [buyer, item_name, price],
				)
				flea_market_listings.remove_at(i)
				changed = true
			elif now >= float(l.get("expire_at", 0.0)):
				var item_name2: String = str(l["item"].get("name", "an item"))
				send_mail(
					"Flea Market Listing Expired",
					"Nobody bought your %s within 24 hours, so it's been returned to you." % item_name2,
					{"item": l["item"]},
				)
				flea_market_listings.remove_at(i)
				changed = true
		else:
			# Other players' listings also expire eventually (much slower
			# than yours) so the browse market actually cycles instead of
			# permanently freezing at whatever first filled it.
			if now >= float(l.get("expire_at", 0.0)):
				flea_market_listings.remove_at(i)
				changed = true
		i -= 1
	_ensure_other_flea_listings()
	if changed:
		flea_market_changed.emit()

# Real sellers don't all price rationally - most listings stay within
# the sane 0.5x-3x band get_flea_market_price_range() computes, but a
# slice of them go to an extreme in either direction: someone panic-
# selling for way under value, or someone testing the market with a
# delusional asking price nobody's going to pay. Keeps browsing the
# market interesting instead of every listing looking the same.
const FLEA_MARKET_STEAL_CHANCE := 0.07
const FLEA_MARKET_STEAL_MULT := 0.15
const FLEA_MARKET_DELUSIONAL_CHANCE := 0.06
const FLEA_MARKET_DELUSIONAL_MULT := 9.0

func _apply_seller_pricing_quirk(price: int) -> int:
	var roll := randf()
	if roll < FLEA_MARKET_STEAL_CHANCE:
		return max(1, int(price * FLEA_MARKET_STEAL_MULT))
	elif roll < FLEA_MARKET_STEAL_CHANCE + FLEA_MARKET_DELUSIONAL_CHANCE:
		return int(price * FLEA_MARKET_DELUSIONAL_MULT)
	return price

func _ensure_other_flea_listings() -> void:
	var other_count := 0
	for l in flea_market_listings:
		if not l.get("is_player", false):
			other_count += 1
	while other_count < FLEA_MARKET_OTHER_LISTING_TARGET:
		var picked: Dictionary = _roll_flea_market_item()
		if picked.is_empty():
			break
		var range_v := get_flea_market_price_range(picked)
		var price: int = randi_range(range_v.x, max(range_v.x + 1, range_v.y))
		price = _apply_seller_pricing_quirk(price)
		_flea_listing_counter += 1
		flea_market_listings.append({
			"id": _flea_listing_counter,
			"item": picked,
			"price": max(5, price),
			"listed_at": _flea_now(),
			"sell_at": 0.0,
			"expire_at": _flea_now() + randf_range(FLEA_MARKET_OTHER_MIN_SECONDS, FLEA_MARKET_OTHER_MAX_SECONDS),
			"is_player": false,
			"seller_name": LEADERBOARD_NAMES[randi() % LEADERBOARD_NAMES.size()],
		})
		other_count += 1

# Rolls a rarity using FLEA_MARKET_RARITY_WEIGHTS, then picks a random
# item of that rarity from the combined enemy-loot + loot-bag-gear pools
# (loot bag gear is what actually has Legendary/Mythic/Exotic entries -
# the enemy loot pool alone tops out at Epic, which is why the market
# used to never show anything above that).
func _roll_flea_market_item() -> Dictionary:
	var total_weight := 0
	for w in FLEA_MARKET_RARITY_WEIGHTS.values():
		total_weight += int(w)
	var roll := randi_range(1, total_weight)
	var chosen_rarity := "common"
	for rarity in FLEA_MARKET_RARITY_WEIGHTS.keys():
		roll -= int(FLEA_MARKET_RARITY_WEIGHTS[rarity])
		if roll <= 0:
			chosen_rarity = rarity
			break

	var candidates: Array = []
	for entry in ENEMY_LOOT_POOL:
		if entry.get("rarity", "common") == chosen_rarity:
			candidates.append(entry)
	for entry in LOOT_BAG_GEAR_POOL:
		if entry.get("rarity", "common") == chosen_rarity:
			candidates.append(entry)
	for entry in FLEA_MARKET_EXTRA_POOL:
		if entry.get("rarity", "common") == chosen_rarity:
			candidates.append(entry)
	# Also mix in Ammo (slot "ammo") so the market's "Ammo" browse category
	# (see FleaMarketPanel.gd BROWSE_CATEGORIES) actually has real "other
	# seller" listings to show, not just whatever ammo the player happens
	# to list themselves.
	for entry in AMMO_POOL:
		if entry.get("rarity", "common") == chosen_rarity:
			candidates.append(entry)
	if candidates.is_empty():
		return roll_enemy_loot()
	var picked: Dictionary = candidates[randi() % candidates.size()]
	if picked.get("consumable_type", "") == "ammo":
		return _stack_ammo(picked.duplicate(true))
	return finalize_rolled_item(picked.duplicate(true))

# --- Titles & Badges: cosmetic profile flair (shown on the Social
# screen), separate from the 100 gameplay Achievements. Titles can be
# swapped out once owned; badges are just earned and always displayed,
# same as achievements.
const TITLE_CATALOG := {
	"tech_test_veteran": {"name": "Tech Test Veteran", "color": Color(0.6, 0.85, 1.0, 1)},
	"alpha_tester": {"name": "Alpha Tester", "color": Color(1.0, 0.7, 0.3, 1)},
}
const BADGE_CATALOG := {
	"here_from_the_start": {"name": "I Was Here From The Start", "desc": "Played during the Tech Test, before Dead Sector was even in Alpha.", "icon": "star", "color": Color(0.6, 0.85, 1.0, 1)},
	"alpha_pioneer": {"name": "Alpha Pioneer", "desc": "Claimed the limited-time Alpha Rewards.", "icon": "star", "color": Color(1.0, 0.7, 0.3, 1)},
	"day_one": {"name": "Early Supporter", "desc": "Welcomed to Dead Sector with the very first care package.", "icon": "compass", "color": Color(0.7, 0.9, 0.6, 1)},
	"rank_1_champion": {"name": "Rank 1 Champion", "desc": "Finished a Leaderboard season in 1st place.", "icon": "star", "color": Color(1.0, 0.85, 0.3, 1)},
	"rank_2_elite": {"name": "Rank 2 Elite", "desc": "Finished a Leaderboard season in 2nd place.", "icon": "star", "color": Color(0.8, 0.85, 0.9, 1)},
	"rank_3_podium": {"name": "Rank 3 Podium", "desc": "Finished a Leaderboard season in 3rd place.", "icon": "star", "color": Color(0.8, 0.55, 0.3, 1)},
	"peak_of_the_sector": {"name": "Peak of the Sector", "desc": "Reached Syndicate 1 - the highest Rank in the game.", "icon": "bone_crown", "color": Color(1.0, 0.82, 0.35, 1)},
}
var owned_titles: Array = []
var owned_badges: Array = []
var equipped_title: String = ""

# --- Chat backgrounds: a purely cosmetic animated backdrop shown behind
# your own messages in Global Chat. Catalog-based so more can be added
# later - the first one is a Tech Test thank-you, gated behind actually
# having that title (not just owning the badge), same as any other
# exclusive cosmetic in this game.
var equipped_chat_background: String = ""
const CHAT_BACKGROUND_CATALOG := {
	"tech_test_prism": {
		"name": "Tech Test Prism",
		"desc": "A shifting gradient particle backdrop behind your Global Chat messages.",
		"gradient": [Color(0.55, 0.8, 1.0, 1), Color(0.8, 0.55, 1.0, 1), Color(1.0, 0.8, 0.5, 1)],
		"requires_title": "tech_test_veteran",
	},
}

func has_chat_background_unlocked(bg_id: String) -> bool:
	var data: Dictionary = CHAT_BACKGROUND_CATALOG.get(bg_id, {})
	var req_title: String = str(data.get("requires_title", ""))
	if req_title == "":
		return true
	return owned_titles.has(req_title)

# Badges worth calling out everywhere they appear: Tech Test/Alpha
# founder badges, Leaderboard podium finishes, and reaching the very
# top Rank. Sorted to the FRONT of any badge list they appear in, since
# these are also the ones that pulse - the display convention here is
# "earlier in the row = higher priority", so the eye-catching pulsing
# badges are never buried behind a wall of ordinary ones.
const PRIORITY_BADGE_IDS := ["here_from_the_start", "alpha_pioneer", "rank_1_champion", "rank_2_elite", "rank_3_podium", "peak_of_the_sector"]

func sort_badges_by_priority(badge_ids: Array) -> Array:
	var normal: Array = []
	var priority: Array = []
	for id in badge_ids:
		if PRIORITY_BADGE_IDS.has(id):
			priority.append(id)
		else:
			normal.append(id)
	return priority + normal

func grant_title(id: String) -> void:
	if not owned_titles.has(id):
		owned_titles.append(id)
		if equipped_title == "":
			equipped_title = id

func grant_badge(id: String) -> void:
	if not owned_badges.has(id):
		owned_badges.append(id)

func equip_title(id: String) -> void:
	if id == "" or owned_titles.has(id):
		equipped_title = id
		save_game()

# Defaults to true (not false) so a genuinely fresh install - no save file
# at all - never triggers this one-time "welcome back from the Tech Test"
# transition mail; load_game() explicitly overwrites this back to false
# for any save that already existed before this field did, preserving the
# one legitimate case: an actual pre-existing player catching up on it once.
var tech_test_mail_sent: bool = true

func _maybe_send_tech_test_mail() -> void:
	if tech_test_mail_sent:
		return
	tech_test_mail_sent = true
	var gear_list: Array = [
		{"name": "Tech Tester's Sidearm", "value": 400, "slot": "weapon", "stat_type": "fire_rate", "stat_value": 0.03, "icon_key": "pistol", "rarity": "legendary", "beta_only": true},
		{"name": "Veteran's Plate", "value": 450, "slot": "body", "stat_type": "max_health", "stat_value": 50.0, "icon_key": "chestplate", "rarity": "legendary", "beta_only": true},
		{"name": "Early Access Visor", "value": 500, "slot": "head", "stat_type": "vision_range", "stat_value": 40.0, "icon_key": "helmet", "rarity": "exotic", "beta_only": true},
		{"name": "Founder's Boots", "value": 380, "slot": "boots", "stat_type": "speed", "stat_value": 24.0, "icon_key": "boots", "rarity": "legendary", "beta_only": true},
	]
	send_mail(
		"From Tech Test to Alpha",
		"Everything before this point was the Tech Test - and you were here for every bit of it. Dead Sector is officially in Alpha now.\n\nAs a thank-you for testing the rough, early build with us: the 'Tech Test Veteran' title and the 'I Was Here From The Start' badge are yours, plus a real haul of gear and currency to bring you up to speed for what's next.",
		{"rubles": 400000, "artifacts": 400, "alloys": 400, "skill_points": 8, "title": "tech_test_veteran", "badge": "here_from_the_start", "gear_list": gear_list},
	)

# --- Free Starter Pack: a small no-cost bundle in the Store, available
# again every 5 real minutes (wall-clock, like the Flea Market and Trader
# rotation - keeps counting down even while you're not looking at the
# Store). Meant to be a steady trickle of Skill Points plus a little bit
# of everything else, not a serious gearing-up source.
const STARTER_PACK_COOLDOWN := 300.0 # 5 real minutes
var _last_starter_pack_claim: float = -STARTER_PACK_COOLDOWN

func starter_pack_available() -> bool:
	return _flea_now() - _last_starter_pack_claim >= STARTER_PACK_COOLDOWN

func starter_pack_seconds_left() -> float:
	return max(0.0, STARTER_PACK_COOLDOWN - (_flea_now() - _last_starter_pack_claim))

# --- Skill Point Packs: a direct Rubles -> Skill Points purchase in the
# Store, for players who'd rather spend currency than grind loot/mail for
# them. Deliberately not the most efficient way to get Skill Points
# (loot/mail/Battle Pass give better value) - this is the "I'm impatient"
# option, same role real-money packs play elsewhere in the Store.
const SKILL_POINT_PACKS := [
	{"id": "sp_small", "label": "Small Skill Point Pack", "amount": 5, "cost": 4000},
	{"id": "sp_medium", "label": "Medium Skill Point Pack", "amount": 15, "cost": 10000},
	{"id": "sp_large", "label": "Large Skill Point Pack", "amount": 40, "cost": 22000},
]

func purchase_skill_point_pack(pack_id: String) -> bool:
	var pack: Dictionary = {}
	for p in SKILL_POINT_PACKS:
		if p.get("id", "") == pack_id:
			pack = p
			break
	if pack.is_empty():
		return false
	var cost: int = int(pack.get("cost", 0))
	if rubles < cost:
		toast_requested.emit("Not enough Rubles")
		return false
	rubles -= cost
	add_currency("skill_points", int(pack.get("amount", 0)))
	save_game()
	return true

func claim_starter_pack() -> bool:
	if not starter_pack_available():
		return false
	_last_starter_pack_claim = _flea_now()
	add_currency("rubles", 1500)
	add_currency("skill_points", 2)
	_add_to_stash(finalize_rolled_item(ENEMY_LOOT_POOL[randi() % ENEMY_LOOT_POOL.size()].duplicate(true)))
	_add_to_stash(VALUABLES_POOL[randi() % VALUABLES_POOL.size()].duplicate(true))
	_add_to_stash(make_pet_egg("common"))
	toast_requested.emit("Starter Pack claimed! Come back in 5 minutes for another.")
	save_game()
	return true

# --- Alpha Rewards: a time-limited claim (not through Mail, so it can
# show its own countdown) for anyone playing during the Alpha window.
const ALPHA_REWARDS_DEADLINE := 1784937600.0 # 2026-07-25 00:00 UTC, ~2 weeks out
var alpha_rewards_claimed: bool = false

func alpha_rewards_available() -> bool:
	return _flea_now() < ALPHA_REWARDS_DEADLINE

func alpha_rewards_seconds_left() -> float:
	return max(0.0, ALPHA_REWARDS_DEADLINE - _flea_now())

func claim_alpha_rewards() -> bool:
	if alpha_rewards_claimed or not alpha_rewards_available():
		return false
	alpha_rewards_claimed = true
	grant_title("alpha_tester")
	grant_badge("alpha_pioneer")
	add_currency("rubles", 200000)
	add_currency("artifacts", 200)
	add_currency("alloys", 200)
	add_currency("skill_points", 15)
	_add_to_stash({"name": "Alpha Pioneer's Rig", "value": 500, "slot": "body", "stat_type": "speed", "stat_value": 22.0, "icon_key": "chestplate", "rarity": "legendary", "alpha_only": true})
	_add_to_stash({"name": "The Prototype", "value": 1200, "slot": "weapon", "stat_type": "damage", "stat_value": 26.0, "icon_key": "alpha_cannon", "rarity": "multiversal", "alpha_only": true, "desc": "Nobody outside the Alpha will ever see one of these fire. Pierces through multiple targets and arcs to a second one on every hit."})
	_add_to_stash(make_loot_bag("alpha"))
	toast_requested.emit("Alpha Rewards claimed!")
	save_game()
	return true

var feedback_submissions: Array = []
var has_seen_welcome: bool = false
# Deliberately NOT saved/loaded - resets every time the game process
# actually launches, unlike has_seen_welcome above. MainMenu.tscn gets
# fully reloaded (re-running _ready()) every time the player returns
# from Stash/Traders/Skill Tree, which used to retrigger the Update
# Spotlight popup on every single return trip instead of once per launch.
var has_shown_update_spotlight_this_session: bool = false

func submit_feedback(text: String) -> void:
	feedback_submissions.append({"text": text, "date": Time.get_date_string_from_system()})
	save_game()

# --- Backpack Storage: the equipped Backpack item's own internal
# storage, separate from the Stash and separate from carried Vicinity
# loot. A fixed 7x7 grid you can stash items into ahead of a raid -
# since it's just persistent state (not reset when a raid starts), it
# automatically comes with you everywhere, including into a raid. This
# is where the Graveyard Key has to sit to get through the Graveyard's
# gate - having it in the Stash instead doesn't count.
const BACKPACK_STORAGE_COLS := 7
const BACKPACK_STORAGE_ROWS := 7
var backpack_storage: Array = []

func _next_free_cell_backpack_storage(footprint: Vector2i = Vector2i(1, 1), ignore_item = null) -> Vector2i:
	var max_x: int = max(BACKPACK_STORAGE_COLS - footprint.x + 1, 1)
	var max_y: int = max(BACKPACK_STORAGE_ROWS - footprint.y + 1, 1)
	for y in range(max_y):
		for x in range(max_x):
			if not _footprint_overlaps(backpack_storage, x, y, footprint.x, footprint.y, ignore_item):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

# Returns false (and leaves the item untouched) if the 7x7 grid is full -
# callers should keep the item wherever it was instead of losing it.
func add_to_backpack_storage(item: Dictionary) -> bool:
	var footprint := get_item_footprint(item)
	var cell := _next_free_cell_backpack_storage(footprint)
	if cell.x < 0:
		toast_requested.emit("Backpack storage is full")
		return false
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	backpack_storage.append(item)
	save_game()
	return true

func move_backpack_storage_item_to_cell(index: int, x: int, y: int) -> void:
	if index < 0 or index >= backpack_storage.size():
		return
	var item: Dictionary = backpack_storage[index]
	var fp := get_item_footprint(item)
	x = clamp(x, 0, max(BACKPACK_STORAGE_COLS - fp.x, 0))
	y = clamp(y, 0, max(BACKPACK_STORAGE_ROWS - fp.y, 0))
	if _footprint_overlaps(backpack_storage, x, y, fp.x, fp.y, item):
		var fallback := _next_free_cell_backpack_storage(fp, item)
		if fallback.x >= 0:
			item["grid_x"] = fallback.x
			item["grid_y"] = fallback.y
		return
	item["grid_x"] = x
	item["grid_y"] = y

# Moves an item OUT of backpack storage and into the Stash (used when
# dragging out, or from the "Take Out" button in the Open popup).
func move_backpack_storage_item_to_stash(index: int) -> bool:
	if index < 0 or index >= backpack_storage.size():
		return false
	var item: Dictionary = backpack_storage[index]
	backpack_storage.remove_at(index)
	_add_to_stash(item)
	save_game()
	return true

# Moves an item OUT of the Stash and into Backpack Storage, auto-placed
# at the next free cell - the double-click counterpart to
# move_backpack_storage_item_to_stash() above (which does the same thing
# in reverse), for ammo/consumables (non-equippable, so double-click-to-
# equip doesn't apply to them) that a double-click in the Stash grid
# should route into the backpack instead of doing nothing.
func move_stash_item_to_backpack_storage(index: int) -> bool:
	if index < 0 or index >= stash_items.size():
		return false
	var item: Dictionary = stash_items[index]
	var fp := get_item_footprint(item)
	var cell := _next_free_cell_backpack_storage(fp)
	if cell.x < 0:
		toast_requested.emit("Backpack storage is full")
		return false
	stash_items.remove_at(index)
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	backpack_storage.append(item)
	save_game()
	return true

# Moves an item from the Stash into Backpack Storage at a specific dropped
# cell - falls back to the next free cell if that one's already occupied,
# instead of silently overlapping (and hiding) whatever's already there.
func move_stash_item_to_backpack_storage_cell(index: int, gx: int, gy: int) -> void:
	if index < 0 or index >= stash_items.size():
		return
	var item: Dictionary = stash_items[index]
	var fp := get_item_footprint(item)
	if _footprint_overlaps(backpack_storage, gx, gy, fp.x, fp.y):
		var cell := _next_free_cell_backpack_storage(fp)
		if cell.x < 0:
			toast_requested.emit("Backpack storage is full")
			return
		gx = cell.x
		gy = cell.y
	stash_items.remove_at(index)
	item["grid_x"] = gx
	item["grid_y"] = gy
	backpack_storage.append(item)
	save_game()

# Moves an item from Backpack Storage into the Stash at a specific dropped
# cell - same overlap-safe fallback as above, mirrored for the reverse
# direction.
func move_backpack_storage_item_to_stash_cell(index: int, gx: int, gy: int) -> void:
	if index < 0 or index >= backpack_storage.size():
		return
	var item: Dictionary = backpack_storage[index]
	var fp := get_item_footprint(item)
	if _footprint_overlaps(stash_items, gx, gy, fp.x, fp.y):
		var cell := _next_free_cell_in(stash_items, false, fp)
		gx = cell.x
		gy = cell.y
	backpack_storage.remove_at(index)
	item["grid_x"] = gx
	item["grid_y"] = gy
	stash_items.append(item)
	save_game()

func has_item_in_backpack_storage(predicate_key: String, predicate_value: String) -> bool:
	return _array_has_item(backpack_storage, predicate_key, predicate_value)

func _array_has_item(array: Array, predicate_key: String, predicate_value: String) -> bool:
	for it in array:
		if it != null and str(it.get(predicate_key, "")) == predicate_value:
			return true
	return false

# Items whose item_id appears here only "count" for whatever they unlock
# while sitting in Backpack Storage (see has_graveyard_key() below) - if
# one of these comes out of a Safe Pocket at the end of a run, it should
# land in Backpack Storage instead of the plain Stash so it keeps working
# immediately rather than silently stop counting until manually moved.
const BACKPACK_STORAGE_ONLY_ITEM_IDS := ["graveyard_key"]

const GRAVEYARD_KEY_ITEM := {
	"name": "Graveyard Key", "value": 0, "icon_key": "key", "rarity": "legendary",
	"item_id": "graveyard_key",
	"desc": "A cold iron key Midnight Bones handed you in the dark. Has to be in your Backpack Storage or a Safe Pocket - not just your Stash - to get through the Graveyard's gate.",
}

func grant_graveyard_key() -> void:
	if has_graveyard_key():
		return
	var key := GRAVEYARD_KEY_ITEM.duplicate(true)
	if not add_to_backpack_storage(key):
		# Backpack Storage was full - fall back to the Stash rather than
		# lose the key outright, with a clear nudge to move it over.
		_add_to_stash(key)
		toast_requested.emit("Got the Graveyard Key! Your Backpack Storage was full, so it's in your Stash for now - move it to Backpack Storage (or a Safe Pocket during a run) before heading to the Graveyard.")
	else:
		toast_requested.emit("Got the Graveyard Key! It's in your Backpack Storage.")
	save_game()

# --- Specialized Cases: Medical, Gun, Armor, and Key each get their own
# small dedicated storage grid, found as lootable case items and opened
# once (like Pet Case) to permanently unlock that category's own space,
# decluttering the main Stash/Backpack of one specific item type for good.
# One generalized set of functions below instead of 4 near-duplicated
# copies of the Backpack Storage pattern above.
const CASE_TYPES := ["medical", "gun", "armor", "key"]
const CASE_STORAGE_COLS := 4
const CASE_STORAGE_ROWS := 4

var unlocked_cases: Dictionary = {"medical": false, "gun": false, "armor": false, "key": false}
var medical_case_storage: Array = []
var gun_case_storage: Array = []
var armor_case_storage: Array = []
var key_case_storage: Array = []

func _case_storage(case_type: String) -> Array:
	match case_type:
		"medical": return medical_case_storage
		"gun": return gun_case_storage
		"armor": return armor_case_storage
		"key": return key_case_storage
	return []

# Public accessor for callers outside GameManager (InventoryGrid.gd, panel
# scripts) - _case_storage() above is this file's own internal shorthand.
func get_case_storage(case_type: String) -> Array:
	return _case_storage(case_type)

func _set_case_storage(case_type: String, arr: Array) -> void:
	match case_type:
		"medical": medical_case_storage = arr
		"gun": gun_case_storage = arr
		"armor": armor_case_storage = arr
		"key": key_case_storage = arr

func case_accepts_item(case_type: String, item: Dictionary) -> bool:
	var slot: String = item.get("slot", "")
	match case_type:
		"medical": return slot == "consumable"
		"gun": return slot == "weapon"
		"armor": return slot == "head" or slot == "body" or slot == "boots"
		"key": return slot == "key"
	return false

func unlock_case(case_type: String) -> void:
	if unlocked_cases.get(case_type, false):
		return
	unlocked_cases[case_type] = true
	toast_requested.emit("%s Case unlocked - it now has its own dedicated storage." % case_type.capitalize())
	save_game()

# Consumes the physical case item (a one-time unlock, not a reusable
# container like Pet Case) and unlocks that category's dedicated storage.
func open_case_item(index: int, source: String, case_type: String) -> void:
	var items: Array = stash_items if source == "stash" else carried_loot
	if index < 0 or index >= items.size():
		return
	items.remove_at(index)
	unlock_case(case_type)

func _next_free_case_cell(case_type: String, footprint: Vector2i = Vector2i(1, 1), ignore_item = null) -> Vector2i:
	var items := _case_storage(case_type)
	var max_x: int = max(CASE_STORAGE_COLS - footprint.x + 1, 1)
	var max_y: int = max(CASE_STORAGE_ROWS - footprint.y + 1, 1)
	for y in range(max_y):
		for x in range(max_x):
			if not _footprint_overlaps(items, x, y, footprint.x, footprint.y, ignore_item):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func move_stash_item_to_case_cell(case_type: String, index: int, gx: int, gy: int) -> void:
	if index < 0 or index >= stash_items.size():
		return
	var item: Dictionary = stash_items[index]
	if not case_accepts_item(case_type, item):
		toast_requested.emit("That doesn't belong in the %s Case" % case_type.capitalize())
		return
	var items := _case_storage(case_type)
	var fp := get_item_footprint(item)
	if _footprint_overlaps(items, gx, gy, fp.x, fp.y):
		var cell := _next_free_case_cell(case_type, fp)
		if cell.x < 0:
			toast_requested.emit("%s Case is full" % case_type.capitalize())
			return
		gx = cell.x
		gy = cell.y
	stash_items.remove_at(index)
	item["grid_x"] = gx
	item["grid_y"] = gy
	items.append(item)
	_set_case_storage(case_type, items)
	save_game()

func move_case_item_to_stash_cell(case_type: String, index: int, gx: int, gy: int) -> void:
	var items := _case_storage(case_type)
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
	var fp := get_item_footprint(item)
	if _footprint_overlaps(stash_items, gx, gy, fp.x, fp.y):
		var cell := _next_free_cell_in(stash_items, false, fp)
		gx = cell.x
		gy = cell.y
	items.remove_at(index)
	_set_case_storage(case_type, items)
	item["grid_x"] = gx
	item["grid_y"] = gy
	stash_items.append(item)
	save_game()

func move_case_item_to_cell(case_type: String, index: int, x: int, y: int) -> void:
	var items := _case_storage(case_type)
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
	var fp := get_item_footprint(item)
	x = clamp(x, 0, max(CASE_STORAGE_COLS - fp.x, 0))
	y = clamp(y, 0, max(CASE_STORAGE_ROWS - fp.y, 0))
	if _footprint_overlaps(items, x, y, fp.x, fp.y, item):
		var fallback := _next_free_case_cell(case_type, fp, item)
		if fallback.x >= 0:
			item["grid_x"] = fallback.x
			item["grid_y"] = fallback.y
		return
	item["grid_x"] = x
	item["grid_y"] = y

func unequip_to_case_cell(case_type: String, slot: String, gx: int, gy: int) -> void:
	if not equipped_items.has(slot):
		return
	var item = equipped_items[slot]
	if item == null:
		return
	if not case_accepts_item(case_type, item):
		toast_requested.emit("That doesn't belong in the %s Case" % case_type.capitalize())
		return
	var items := _case_storage(case_type)
	var fp := get_item_footprint(item)
	if _footprint_overlaps(items, gx, gy, fp.x, fp.y):
		var cell := _next_free_case_cell(case_type, fp)
		if cell.x < 0:
			toast_requested.emit("%s Case is full" % case_type.capitalize())
			return
		gx = cell.x
		gy = cell.y
	equipped_items[slot] = null
	item["grid_x"] = gx
	item["grid_y"] = gy
	items.append(item)
	_set_case_storage(case_type, items)
	equipped_changed.emit()
	save_game()

func _repair_case_storage_overlaps() -> void:
	for case_type in CASE_TYPES:
		var original: Array = _case_storage(case_type)
		var placed: Array = []
		var needs_fix: Array = []
		for it in original:
			var gx := int(it.get("grid_x", -1))
			var gy := int(it.get("grid_y", -1))
			var fp := get_item_footprint(it)
			var out_of_bounds: bool = gx < 0 or gy < 0 or gx + fp.x > CASE_STORAGE_COLS or gy + fp.y > CASE_STORAGE_ROWS
			if out_of_bounds or _footprint_overlaps(placed, gx, gy, fp.x, fp.y):
				needs_fix.append(it)
			else:
				placed.append(it)
		for it in needs_fix:
			var fp := get_item_footprint(it)
			var cell := _next_free_case_cell(case_type, fp)
			if cell.x >= 0:
				it["grid_x"] = cell.x
				it["grid_y"] = cell.y
			placed.append(it)
		_set_case_storage(case_type, placed)

# Recognizes the key whether it's sitting in Backpack Storage (the
# intended permanent home for it) or in a Safe Pocket - a pocket
# protects an item through death exactly like Backpack Storage does,
# so it counts as real inventory for this check too. Not the Stash
# itself, deliberately - see GRAVEYARD_KEY_ITEM's desc.
func has_graveyard_key() -> bool:
	return _array_has_item(backpack_storage, "item_id", "graveyard_key") or _array_has_item(safe_pockets, "item_id", "graveyard_key")

func equip_from_backpack_storage(index: int) -> void:
	if index < 0 or index >= backpack_storage.size():
		return
	var item: Dictionary = backpack_storage[index]
	var slot: String = item.get("slot", "")
	if not equipped_items.has(slot):
		return
	var current = equipped_items[slot]
	backpack_storage.remove_at(index)
	if current != null:
		var cell := _next_free_cell_backpack_storage()
		if cell.x >= 0:
			current["grid_x"] = cell.x
			current["grid_y"] = cell.y
			backpack_storage.append(current)
		else:
			_add_to_stash(current)
	equipped_items[slot] = item
	equipped_changed.emit()

# --- Mail ---
var mail_messages: Array = []
var _mail_counter: int = 0
var last_newsletter_day: int = -1
var welcome_mail_sent: bool = false
signal mail_received

# Without a cap this grows forever over a long-running save (social mail,
# daily newsletter, flea market notices...), with every mail op doing a
# linear scan over it. Only ever trims entries that are BOTH claimed and
# read, so a player who never checks their mail never silently loses
# unclaimed rewards - it's fine to briefly exceed the cap in that case.
const MAIL_CAP := 100

func send_mail(subject: String, body: String, rewards: Dictionary = {}) -> void:
	_mail_counter += 1
	mail_messages.push_front({
		"id": _mail_counter,
		"subject": subject,
		"body": body,
		"date": Time.get_date_string_from_system(),
		"rewards": rewards,
		"claimed": rewards.is_empty(),
		"read": false,
	})
	_trim_mail_history()
	toast_requested.emit("New mail: %s" % subject)
	mail_received.emit()
	save_game()

func _trim_mail_history() -> void:
	if mail_messages.size() <= MAIL_CAP:
		return
	# push_front means newest is index 0, oldest is at the end.
	var i := mail_messages.size() - 1
	while mail_messages.size() > MAIL_CAP and i >= 0:
		var m: Dictionary = mail_messages[i]
		if m.get("claimed", true) and m.get("read", false):
			mail_messages.remove_at(i)
		i -= 1

func claim_mail(mail_id: int) -> bool:
	for m in mail_messages:
		if int(m.get("id", -1)) == mail_id and not m.get("claimed", true):
			var rewards: Dictionary = m["rewards"]
			if rewards.has("rubles"):
				add_currency("rubles", int(rewards["rubles"]))
			if rewards.has("artifacts"):
				add_currency("artifacts", int(rewards["artifacts"]))
			if rewards.has("alloys"):
				add_currency("alloys", int(rewards["alloys"]))
			if rewards.has("skill_points"):
				add_currency("skill_points", int(rewards["skill_points"]))
			if rewards.has("item"):
				_add_to_stash(rewards["item"].duplicate(true))
			if rewards.has("gear"):
				_add_to_stash(rewards["gear"].duplicate(true))
			if rewards.has("gear_list"):
				for g in rewards["gear_list"]:
					_add_to_stash(g.duplicate(true))
			if rewards.has("title"):
				grant_title(str(rewards["title"]))
			if rewards.has("badge"):
				grant_badge(str(rewards["badge"]))
			m["claimed"] = true
			save_game()
			return true
	return false

func mark_mail_read(mail_id: int) -> void:
	for m in mail_messages:
		if int(m.get("id", -1)) == mail_id:
			m["read"] = true
			return

func unread_mail_count() -> int:
	var n := 0
	for m in mail_messages:
		if not m.get("read", false):
			n += 1
	return n

const NEWSLETTER_LINES := [
	"Word from the Sector: three new Loom-weaver sightings were reported near the Graveyard this week.",
	"Traders report Ruble prices holding steady across the board - good time to sell.",
	"Reminder: the Bloodline Gauntlet resets its leaderboard every season. Current top operatives are pulling serious numbers.",
	"Rumor from Boneclock: Rattles has been quieter than usual. Operatives are advised to stay sharp anyway.",
	"The Undertow's crate odds haven't changed, no matter what the forums say.",
	"Void Trench sightings of Rift Wraiths are up. Bring backup.",
	"Sprocket's been muttering about a new blueprint tier. No ETA yet.",
	"A friendly reminder from Echo: the Sector does not forgive, but it does occasionally reward.",
]

func _maybe_send_daily_newsletter() -> void:
	var today: int = int(_flea_now() / 86400.0)
	if today == last_newsletter_day:
		return
	last_newsletter_day = today
	var line: String = NEWSLETTER_LINES[randi() % NEWSLETTER_LINES.size()]
	send_mail(
		"The Daily Drop - Sector Newsletter",
		"%s\n\nThat's all for today, operative. Stay alive out there." % line,
		{"rubles": 25, "skill_points": 1},
	)

func _maybe_send_welcome_mail() -> void:
	if welcome_mail_sent:
		return
	welcome_mail_sent = true
	send_mail(
		"Welcome to Dead Sector",
		"Hey - welcome to Dead Sector! Glad to have you out here. Raid a Sector, loot what you can carry, and extract before your time runs out - everything you bring home is yours to keep and build on for next time.\n\nHere's a little something to help you gear up early: a stack of Rubles, some Artifacts and Alloys, and an Early Supporter badge for your profile. Good luck out there - the Sector doesn't forgive, but we're glad you're here anyway.",
		{"rubles": 3000, "artifacts": 5, "alloys": 5, "skill_points": 1, "badge": "day_one"},
	)

const SAVE_FORMAT_VERSION := 5
var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL := 5.0

func _process(delta: float) -> void:
	_trader_rotation_timer += delta
	if _trader_rotation_timer >= TRADER_ROTATION_INTERVAL:
		_trader_rotation_timer = 0.0
		_rotate_traders()
	_flea_market_timer += delta
	if _flea_market_timer >= FLEA_MARKET_CHECK_INTERVAL:
		_flea_market_timer = 0.0
		_check_flea_market()
		_maybe_send_daily_newsletter()
	_social_mail_timer += delta
	if _next_social_mail_delay <= 0.0:
		_next_social_mail_delay = randf_range(3600.0, 7200.0)
	if _social_mail_timer >= _next_social_mail_delay:
		_social_mail_timer = 0.0
		_next_social_mail_delay = randf_range(3600.0, 7200.0)
		_maybe_send_social_mail()
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()

func save_game() -> void:
	check_achievements()
	var data := {
		"save_format_version": SAVE_FORMAT_VERSION,
		"rubles": rubles, "junk": junk, "artifacts": artifacts, "alloys": alloys, "souls": souls, "blossoms": blossoms, "skill_points": skill_points, "stones": stones,
		"rank_points": rank_points,
		"arena_rank_points": arena_rank_points,
		"arena_reward_tiers_granted": arena_reward_tiers_granted,
		"last_starter_pack_claim": _last_starter_pack_claim,
		"leaderboard_season_start": leaderboard_season_start,
		"leaderboard_player_baseline": leaderboard_player_baseline,
		"blood_shards": blood_shards, "bloodline_tier": bloodline_tier, "bloodline_progress": bloodline_progress,
		"gauntlet_best_level": gauntlet_best_level, "engrams": engrams,
		"battle_pass_tier": battle_pass_tier, "battle_pass_progress": battle_pass_progress,
		"milestone_tier": milestone_tier, "milestone_progress": milestone_progress,
		"guild_honor": guild_honor, "guild_battle_pass_tier": guild_battle_pass_tier,
		"guild_battle_pass_progress": guild_battle_pass_progress, "last_clan_war_day": last_clan_war_day,
		"has_shown_chat_keybind_hint": has_shown_chat_keybind_hint,
		"monthly_pass_owned": monthly_pass_owned, "double_xp_owned": double_xp_owned,
		"fast_hatching_owned": fast_hatching_owned,
		"claimed_free_store_packs": claimed_free_store_packs,
		"stash_items": stash_items,
		"safe_pockets": safe_pockets,
		"equipped_items": equipped_items,
		"player_loadout_presets": player_loadout_presets,
		"player_guild_id": player_guild_id, "player_guild_name": player_guild_name,
		"player_guild_tag": player_guild_tag, "player_guild_is_custom": player_guild_is_custom,
		"prestige_level": prestige_level,
		"is_scav_run": is_scav_run,
		"saved_pmc_equipped": _saved_pmc_equipped,
		"arena_loadout_active": _arena_loadout_active,
		"saved_arena_equipped": _saved_arena_equipped,
		"saved_arena_pet": _saved_arena_pet,
		"upgrade_levels": _levels_of(upgrades),
		"hideout_upgrade_levels": _levels_of(hideout_upgrades),
		"quest_status": quest_status,
		"owned_skins": owned_skins,
		"equipped_skins": equipped_skins,
		"last_quote_index": last_quote_index,
		"character_created": character_created,
		"player_name": player_name,
		"player_build": player_build,
		"player_background": player_background,
		"player_hair_color_idx": player_hair_color_idx,
		"player_eye_color_idx": player_eye_color_idx,
		"player_mouth_style_idx": player_mouth_style_idx,
		"player_skin_color_idx": player_skin_color_idx,
		"player_particle_trail": player_particle_trail,
		"player_torso_style": player_torso_style,
		"player_glow_color_idx": player_glow_color_idx,
		"player_backpack_style": player_backpack_style,
		"player_trait": player_trait,
		"recruit_equipment": recruit_equipment,
		"owned_pets": owned_pets, "equipped_pet": equipped_pet,
		"owned_pet_instances": owned_pet_instances, "pet_instance_counter": _pet_instance_counter,
		"pet_eggs": pet_eggs, "salvaged_beasts_tickets": salvaged_beasts_tickets,
		"salvaged_beasts_tier": salvaged_beasts_tier, "salvaged_beasts_progress": salvaged_beasts_progress,
		"egg_hatching_slots": egg_hatching_slots,
		"bitcoin_gpu_slots": bitcoin_gpu_slots,
		"player_level": player_level, "player_score": player_score,
		"player_xp": player_xp,
		"player_bio": player_bio,
		"player_portrait_id": player_portrait_id,
		"stat_total_loot_collected": stat_total_loot_collected,
		"stat_total_sold": stat_total_sold,
		"stat_enemies_killed": stat_enemies_killed,
		"stat_deaths": stat_deaths,
		"stat_extractions": stat_extractions,
		"stat_scav_extractions": stat_scav_extractions,
		"stat_crates_opened": stat_crates_opened,
		"stat_blueprints_researched": stat_blueprints_researched,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"window_mode_setting": window_mode_setting,
		"vsync_enabled": vsync_enabled,
		"screen_shake_enabled": screen_shake_enabled,
		"keybinds": keybinds,
		"discovered_enemies": discovered_enemies, "seen_collectibles": seen_collectibles,
		"ghost_recruited": ghost_recruited,
		"graveyard_kills": graveyard_kills,
		"unlocked_achievements": unlocked_achievements,
		"stat_eggs_hatched": stat_eggs_hatched,
		"flea_market_listings": flea_market_listings,
		"flea_listing_counter": _flea_listing_counter,
		"mail_messages": mail_messages,
		"mail_counter": _mail_counter,
		"last_newsletter_day": last_newsletter_day,
		"welcome_mail_sent": welcome_mail_sent,
		"tech_test_mail_sent": tech_test_mail_sent,
		"alpha_rewards_claimed": alpha_rewards_claimed,
		"owned_titles": owned_titles,
		"owned_badges": owned_badges,
		"equipped_title": equipped_title,
		"equipped_chat_background": equipped_chat_background,
		"feedback_submissions": feedback_submissions,
		"backpack_storage": backpack_storage,
		"unlocked_cases": unlocked_cases,
		"medical_case_storage": medical_case_storage,
		"gun_case_storage": gun_case_storage,
		"armor_case_storage": armor_case_storage,
		"key_case_storage": key_case_storage,
		"has_seen_welcome": has_seen_welcome,
		"achievement_flag_multiversal_pull": achievement_flag_multiversal_pull,
		"achievement_flag_close_call": achievement_flag_close_call,
		"rose_talked_to": rose_talked_to,
	}
	# Write to a temp file first, then rotate it into place, rather than
	# truncating savegame.json directly - a crash/forced-close mid-write
	# used to be able to leave a half-written, unparseable save behind,
	# which load_game() then treated identically to "no save at all" and
	# silently wiped the player back to a blank slate. Keeping one rotated
	# backup generation also means a genuinely corrupted write still has
	# last session's known-good save to recover from.
	var tmp_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		toast_requested.emit("Save failed - could not write to disk")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		toast_requested.emit("Save failed - could not access save directory")
		return
	if dir.file_exists(SAVE_PATH.trim_prefix("user://")):
		if dir.file_exists(SAVE_BACKUP_PATH.trim_prefix("user://")):
			dir.remove(SAVE_BACKUP_PATH.trim_prefix("user://"))
		dir.rename(SAVE_PATH.trim_prefix("user://"), SAVE_BACKUP_PATH.trim_prefix("user://"))
	var err := dir.rename(tmp_path.trim_prefix("user://"), SAVE_PATH.trim_prefix("user://"))
	if err != OK:
		toast_requested.emit("Save failed - progress may not have been saved")

func _levels_of(source: Dictionary) -> Dictionary:
	var out := {}
	for key in source.keys():
		out[key] = int(source[key].get("level", 0))
	return out

func _try_load_save_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return null
	var text := f.get_as_text()
	f.close()
	if text == "":
		return null
	return JSON.parse_string(text)

func load_game() -> void:
	var primary_existed := FileAccess.file_exists(SAVE_PATH)
	var parsed = _try_load_save_file(SAVE_PATH)
	var used_backup := false
	if typeof(parsed) != TYPE_DICTIONARY:
		var backup_existed := FileAccess.file_exists(SAVE_BACKUP_PATH)
		parsed = _try_load_save_file(SAVE_BACKUP_PATH)
		if typeof(parsed) == TYPE_DICTIONARY:
			used_backup = true
		elif not primary_existed and not backup_existed:
			# Neither file exists anywhere - a genuinely new install, not
			# a failure. Nothing to warn about.
			return
		else:
			toast_requested.emit("Your save file couldn't be read, even from backup - starting fresh. Sorry about that.")
			return
	if used_backup:
		toast_requested.emit("Your main save couldn't be read, so your previous backup was restored instead - you may have lost a small amount of recent progress.")

	# NOTE: this used to unconditionally wipe any save with an older
	# save_format_version before loading anything - but that ran BEFORE
	# the quest_index/egg_hatching/fullscreen migration blocks further
	# down in this same function, making them permanently unreachable
	# dead code. Every field below already loads defensively via
	# parsed.get(key, current_default), and the migration blocks handle
	# the specific old field formats they're built for - between the
	# two, an older save now upgrades gracefully instead of being
	# deleted outright.

	rubles = int(parsed.get("rubles", rubles))
	junk = int(parsed.get("junk", junk))
	artifacts = int(parsed.get("artifacts", artifacts))
	alloys = int(parsed.get("alloys", alloys))
	skill_points = int(parsed.get("skill_points", skill_points))
	rank_points = int(parsed.get("rank_points", rank_points))
	arena_rank_points = int(parsed.get("arena_rank_points", arena_rank_points))
	# Absent on any save from before this field existed - defaults to -1,
	# which grant_arena_rank_points() reads as "not yet baselined" and
	# will resolve to the current tier with no retroactive payout, same
	# as any other pre-existing save that already reached that rank.
	arena_reward_tiers_granted = int(parsed.get("arena_reward_tiers_granted", -1))
	_last_starter_pack_claim = float(parsed.get("last_starter_pack_claim", _last_starter_pack_claim))
	leaderboard_season_start = float(parsed.get("leaderboard_season_start", 0.0))
	var loaded_baseline = parsed.get("leaderboard_player_baseline", null)
	if typeof(loaded_baseline) == TYPE_DICTIONARY:
		leaderboard_player_baseline = loaded_baseline
	souls = int(parsed.get("souls", souls))
	stones = int(parsed.get("stones", stones))
	blossoms = int(parsed.get("blossoms", blossoms))
	blood_shards = int(parsed.get("blood_shards", blood_shards))
	bloodline_tier = int(parsed.get("bloodline_tier", bloodline_tier))
	bloodline_progress = int(parsed.get("bloodline_progress", bloodline_progress))
	gauntlet_best_level = int(parsed.get("gauntlet_best_level", gauntlet_best_level))
	var loaded_engrams = parsed.get("engrams", null)
	if typeof(loaded_engrams) == TYPE_ARRAY:
		engrams = loaded_engrams
	battle_pass_tier = int(parsed.get("battle_pass_tier", 0))
	battle_pass_progress = int(parsed.get("battle_pass_progress", 0))
	milestone_tier = int(parsed.get("milestone_tier", 0))
	milestone_progress = int(parsed.get("milestone_progress", 0))
	guild_honor = int(parsed.get("guild_honor", 0))
	guild_battle_pass_tier = int(parsed.get("guild_battle_pass_tier", 0))
	guild_battle_pass_progress = int(parsed.get("guild_battle_pass_progress", 0))
	last_clan_war_day = int(parsed.get("last_clan_war_day", -1))
	has_shown_chat_keybind_hint = bool(parsed.get("has_shown_chat_keybind_hint", false))
	monthly_pass_owned = bool(parsed.get("monthly_pass_owned", false))
	double_xp_owned = bool(parsed.get("double_xp_owned", false))
	fast_hatching_owned = bool(parsed.get("fast_hatching_owned", false))
	var loaded_claimed_free_packs = parsed.get("claimed_free_store_packs", null)
	if typeof(loaded_claimed_free_packs) == TYPE_ARRAY:
		claimed_free_store_packs = loaded_claimed_free_packs

	var loaded_stash = parsed.get("stash_items", null)
	if typeof(loaded_stash) == TYPE_ARRAY:
		stash_items = loaded_stash

	var loaded_equipped = parsed.get("equipped_items", {})
	if typeof(loaded_equipped) == TYPE_DICTIONARY:
		for key in equipped_items.keys():
			if loaded_equipped.has(key):
				equipped_items[key] = loaded_equipped[key]

	var loaded_presets = parsed.get("player_loadout_presets", null)
	if typeof(loaded_presets) == TYPE_ARRAY:
		for i in range(min(loaded_presets.size(), player_loadout_presets.size())):
			player_loadout_presets[i] = loaded_presets[i]
	player_guild_id = String(parsed.get("player_guild_id", ""))
	player_guild_name = String(parsed.get("player_guild_name", ""))
	player_guild_tag = String(parsed.get("player_guild_tag", ""))
	player_guild_is_custom = bool(parsed.get("player_guild_is_custom", false))
	prestige_level = int(parsed.get("prestige_level", 0))

	is_scav_run = bool(parsed.get("is_scav_run", false))
	var loaded_saved_pmc = parsed.get("saved_pmc_equipped", null)
	if typeof(loaded_saved_pmc) == TYPE_DICTIONARY:
		_saved_pmc_equipped = loaded_saved_pmc
	_arena_loadout_active = bool(parsed.get("arena_loadout_active", false))
	var loaded_saved_arena = parsed.get("saved_arena_equipped", null)
	if typeof(loaded_saved_arena) == TYPE_DICTIONARY:
		_saved_arena_equipped = loaded_saved_arena
	_saved_arena_pet = String(parsed.get("saved_arena_pet", ""))
	# NOTE: recovery (restoring real gear/pet if a run was left active) is
	# applied much further down, after equipped_pet's normal load below -
	# otherwise that unconditional load would immediately clobber it back
	# to the temporary loadout's pet.
	var recovered_interrupted_run := false

	var loaded_upgrade_levels = parsed.get("upgrade_levels", {})
	if typeof(loaded_upgrade_levels) == TYPE_DICTIONARY:
		for key in upgrades.keys():
			if loaded_upgrade_levels.has(key):
				upgrades[key]["level"] = int(loaded_upgrade_levels[key])

	var loaded_hideout_levels = parsed.get("hideout_upgrade_levels", {})
	if typeof(loaded_hideout_levels) == TYPE_DICTIONARY:
		for key in hideout_upgrades.keys():
			if loaded_hideout_levels.has(key):
				hideout_upgrades[key]["level"] = int(loaded_hideout_levels[key])

	var loaded_quest_status = parsed.get("quest_status", null)
	if typeof(loaded_quest_status) == TYPE_DICTIONARY:
		quest_status = loaded_quest_status
	elif parsed.has("quest_index"):
		# Migrate an old save from the single-linear-quest system: every
		# quest before the old index is done, and the quest that was
		# "current" becomes active (or ready, if it was awaiting turn-in).
		# Nothing else becomes active since only one quest was ever
		# tracked at a time back then.
		var old_index := int(parsed.get("quest_index", 0))
		var old_ready := bool(parsed.get("quest_ready", false))
		quest_status = {}
		for i in range(QUEST_ORDER.size()):
			if i < old_index:
				quest_status[QUEST_ORDER[i]] = "done"
			elif i == old_index:
				quest_status[QUEST_ORDER[i]] = "ready" if old_ready else "active"

	var loaded_owned_skins = parsed.get("owned_skins", null)
	if typeof(loaded_owned_skins) == TYPE_DICTIONARY:
		owned_skins = loaded_owned_skins
	var loaded_equipped_skins = parsed.get("equipped_skins", null)
	if typeof(loaded_equipped_skins) == TYPE_DICTIONARY:
		equipped_skins = loaded_equipped_skins

	last_quote_index = int(parsed.get("last_quote_index", -1))
	character_created = bool(parsed.get("character_created", false))
	player_name = String(parsed.get("player_name", player_name))
	player_build = float(parsed.get("player_build", player_build))
	player_background = String(parsed.get("player_background", player_background))
	player_hair_color_idx = int(parsed.get("player_hair_color_idx", 0))
	player_eye_color_idx = int(parsed.get("player_eye_color_idx", 0))
	player_mouth_style_idx = int(parsed.get("player_mouth_style_idx", 0))
	player_skin_color_idx = int(parsed.get("player_skin_color_idx", 2))
	player_particle_trail = str(parsed.get("player_particle_trail", "none"))
	player_torso_style = String(parsed.get("player_torso_style", player_torso_style))
	player_glow_color_idx = int(parsed.get("player_glow_color_idx", 0))
	player_backpack_style = String(parsed.get("player_backpack_style", player_backpack_style))
	player_trait = String(parsed.get("player_trait", player_trait))
	var loaded_recruit_equipment = parsed.get("recruit_equipment", null)
	if typeof(loaded_recruit_equipment) == TYPE_DICTIONARY:
		for rid in recruit_equipment.keys():
			if loaded_recruit_equipment.has(rid) and typeof(loaded_recruit_equipment[rid]) == TYPE_DICTIONARY:
				for slot in recruit_equipment[rid].keys():
					if loaded_recruit_equipment[rid].has(slot):
						recruit_equipment[rid][slot] = loaded_recruit_equipment[rid][slot]

	var loaded_owned_pets = parsed.get("owned_pets", null)
	if typeof(loaded_owned_pets) == TYPE_ARRAY:
		owned_pets = loaded_owned_pets
	equipped_pet = String(parsed.get("equipped_pet", ""))
	var loaded_pet_instances = parsed.get("owned_pet_instances", null)
	if typeof(loaded_pet_instances) == TYPE_DICTIONARY:
		owned_pet_instances = loaded_pet_instances
	_pet_instance_counter = int(parsed.get("pet_instance_counter", _pet_instance_counter))
	var loaded_pet_eggs = parsed.get("pet_eggs", null)
	if typeof(loaded_pet_eggs) == TYPE_ARRAY:
		pet_eggs = loaded_pet_eggs
	salvaged_beasts_tickets = int(parsed.get("salvaged_beasts_tickets", salvaged_beasts_tickets))
	salvaged_beasts_tier = int(parsed.get("salvaged_beasts_tier", salvaged_beasts_tier))
	salvaged_beasts_progress = int(parsed.get("salvaged_beasts_progress", salvaged_beasts_progress))
	var loaded_hatching_slots = parsed.get("egg_hatching_slots", null)
	if typeof(loaded_hatching_slots) == TYPE_ARRAY:
		egg_hatching_slots = loaded_hatching_slots
	else:
		# Old saves stored a single hatch as a Dictionary under "egg_hatching" -
		# carry it over into the new slot array instead of losing it.
		var old_single_hatch = parsed.get("egg_hatching", null)
		if typeof(old_single_hatch) == TYPE_DICTIONARY and not old_single_hatch.is_empty():
			egg_hatching_slots = [old_single_hatch]

	var loaded_gpu_slots = parsed.get("bitcoin_gpu_slots", null)
	if typeof(loaded_gpu_slots) == TYPE_ARRAY:
		for i in range(min(loaded_gpu_slots.size(), bitcoin_gpu_slots.size())):
			bitcoin_gpu_slots[i] = loaded_gpu_slots[i]

	player_level = int(parsed.get("player_level", player_level))
	player_score = int(parsed.get("player_score", player_score))
	player_xp = int(parsed.get("player_xp", player_xp))
	player_bio = String(parsed.get("player_bio", player_bio))
	player_portrait_id = String(parsed.get("player_portrait_id", player_portrait_id))
	stat_total_loot_collected = int(parsed.get("stat_total_loot_collected", 0))
	stat_total_sold = int(parsed.get("stat_total_sold", 0))
	stat_enemies_killed = int(parsed.get("stat_enemies_killed", 0))
	stat_deaths = int(parsed.get("stat_deaths", 0))
	stat_extractions = int(parsed.get("stat_extractions", 0))
	stat_scav_extractions = int(parsed.get("stat_scav_extractions", 0))
	stat_crates_opened = int(parsed.get("stat_crates_opened", 0))
	stat_blueprints_researched = int(parsed.get("stat_blueprints_researched", 0))

	master_volume = float(parsed.get("master_volume", master_volume))
	music_volume = float(parsed.get("music_volume", music_volume))
	sfx_volume = float(parsed.get("sfx_volume", sfx_volume))
	if parsed.has("window_mode_setting"):
		window_mode_setting = str(parsed.get("window_mode_setting", window_mode_setting))
	elif parsed.has("fullscreen"):
		# Migrating an older save that only had the binary toggle.
		window_mode_setting = "fullscreen" if bool(parsed.get("fullscreen", false)) else "windowed"
	vsync_enabled = bool(parsed.get("vsync_enabled", vsync_enabled))
	screen_shake_enabled = bool(parsed.get("screen_shake_enabled", screen_shake_enabled))
	var loaded_discovered = parsed.get("discovered_enemies", null)
	if typeof(loaded_discovered) == TYPE_DICTIONARY:
		discovered_enemies = loaded_discovered
	var loaded_seen = parsed.get("seen_collectibles", null)
	if typeof(loaded_seen) == TYPE_DICTIONARY:
		seen_collectibles = loaded_seen
	ghost_recruited = bool(parsed.get("ghost_recruited", false))
	graveyard_kills = int(parsed.get("graveyard_kills", graveyard_kills))
	var loaded_achievements = parsed.get("unlocked_achievements", null)
	if typeof(loaded_achievements) == TYPE_DICTIONARY:
		unlocked_achievements = loaded_achievements
	stat_eggs_hatched = int(parsed.get("stat_eggs_hatched", 0))
	var loaded_flea = parsed.get("flea_market_listings", null)
	if typeof(loaded_flea) == TYPE_ARRAY:
		flea_market_listings = loaded_flea
	_flea_listing_counter = int(parsed.get("flea_listing_counter", 0))
	var loaded_mail = parsed.get("mail_messages", null)
	if typeof(loaded_mail) == TYPE_ARRAY:
		mail_messages = loaded_mail
	_mail_counter = int(parsed.get("mail_counter", 0))
	last_newsletter_day = int(parsed.get("last_newsletter_day", -1))
	welcome_mail_sent = bool(parsed.get("welcome_mail_sent", false))
	tech_test_mail_sent = bool(parsed.get("tech_test_mail_sent", false))
	alpha_rewards_claimed = bool(parsed.get("alpha_rewards_claimed", false))
	var loaded_titles = parsed.get("owned_titles", null)
	if typeof(loaded_titles) == TYPE_ARRAY:
		owned_titles = loaded_titles
	var loaded_badges = parsed.get("owned_badges", null)
	if typeof(loaded_badges) == TYPE_ARRAY:
		owned_badges = loaded_badges
	equipped_title = str(parsed.get("equipped_title", ""))
	equipped_chat_background = str(parsed.get("equipped_chat_background", ""))
	var loaded_feedback = parsed.get("feedback_submissions", null)
	if typeof(loaded_feedback) == TYPE_ARRAY:
		feedback_submissions = loaded_feedback
	var loaded_backpack_storage = parsed.get("backpack_storage", null)
	if typeof(loaded_backpack_storage) == TYPE_ARRAY:
		backpack_storage = loaded_backpack_storage
	var loaded_unlocked_cases = parsed.get("unlocked_cases", null)
	if typeof(loaded_unlocked_cases) == TYPE_DICTIONARY:
		for case_type in unlocked_cases.keys():
			if loaded_unlocked_cases.has(case_type):
				unlocked_cases[case_type] = bool(loaded_unlocked_cases[case_type])
	var loaded_medical_case = parsed.get("medical_case_storage", null)
	if typeof(loaded_medical_case) == TYPE_ARRAY:
		medical_case_storage = loaded_medical_case
	var loaded_gun_case = parsed.get("gun_case_storage", null)
	if typeof(loaded_gun_case) == TYPE_ARRAY:
		gun_case_storage = loaded_gun_case
	var loaded_armor_case = parsed.get("armor_case_storage", null)
	if typeof(loaded_armor_case) == TYPE_ARRAY:
		armor_case_storage = loaded_armor_case
	var loaded_key_case = parsed.get("key_case_storage", null)
	if typeof(loaded_key_case) == TYPE_ARRAY:
		key_case_storage = loaded_key_case
	# A Scav Run or Arena Loadout that was still active when the game last
	# closed (quit, crash, forced shutdown) never reached its normal
	# end_*_if_active() call, so the real gear/pet underneath is only
	# sitting in these backups. This is the only chance to give it back,
	# since a raid/arena match never survives a cold boot to begin with.
	# Runs here (rather than right after equipped_items loads above) so it
	# applies after equipped_pet's normal load, instead of being clobbered
	# by it.
	if is_scav_run and not _saved_pmc_equipped.is_empty():
		equipped_items = _saved_pmc_equipped.duplicate(true)
		is_scav_run = false
		_saved_pmc_equipped = {}
		recovered_interrupted_run = true
	if _arena_loadout_active and not _saved_arena_equipped.is_empty():
		equipped_items = _saved_arena_equipped.duplicate(true)
		equipped_pet = _saved_arena_pet
		_arena_loadout_active = false
		_saved_arena_equipped = {}
		_saved_arena_pet = ""
		recovered_interrupted_run = true
	var loaded_safe_pockets = parsed.get("safe_pockets", null)
	if typeof(loaded_safe_pockets) == TYPE_ARRAY:
		for i in range(min(loaded_safe_pockets.size(), safe_pockets.size())):
			safe_pockets[i] = loaded_safe_pockets[i]
		# A raid never survives a cold boot, so pockets still holding
		# something here means the game closed mid-run before end_run()
		# could bank them - drain them now the same way a normal
		# extraction/death would, instead of leaving them stuck in
		# limbo (or worse, silently lost).
		if safe_pockets.any(func(it): return it != null):
			_drain_safe_pockets_to_stash()
			recovered_interrupted_run = true
	has_seen_welcome = bool(parsed.get("has_seen_welcome", false))
	achievement_flag_multiversal_pull = bool(parsed.get("achievement_flag_multiversal_pull", false))
	achievement_flag_close_call = bool(parsed.get("achievement_flag_close_call", false))
	rose_talked_to = bool(parsed.get("rose_talked_to", false))
	var loaded_keybinds = parsed.get("keybinds", null)
	if typeof(loaded_keybinds) == TYPE_DICTIONARY:
		for action in KEYBIND_DEFAULTS.keys():
			if loaded_keybinds.has(action):
				keybinds[action] = int(loaded_keybinds[action])
	# Ammo rarity/slot fixed BEFORE the grid-overlap repair below - repair
	# can relocate items between stash_items/backpack_storage, and doing
	# that first left freshly-relocated items still holding their stale
	# rarity for one more save/load cycle before this function's next run
	# finally caught them too. Fixing the fields first means whichever
	# array an item ends up in after repair, it's already correct.
	_migrate_stale_ammo_items()
	_repair_overlapping_grid_items()
	_migrate_stash_eggs_to_hatchery()
	if recovered_interrupted_run:
		toast_requested.emit("Restored your real loadout after an interrupted run")
		save_game()

# Older saves (from before eggs started auto-depositing) can have Eggs
# still sitting in the Stash from before this change - sweep them into
# the Hatchery once, right after loading, so every save ends up in the
# same "eggs never sit in the Stash" state going forward.
# Ammo items saved from before the #52 recolor (commit 4e6ed64) still
# carry their old "slot": "consumable" / rarity ("uncommon" for Heavy,
# etc.) baked in - items already in a save were never retroactively
# touched by that change, only newly-created ones. Left alone, an old
# Heavy Ammo stack renders green (uncommon) forever instead of purple
# (epic), sitting right next to freshly-looted purple Heavy Ammo. Fixes
# the slot/rarity in place, once, on every load - amount/position are
# untouched, so nothing about what the player owns actually changes.
func _migrate_stale_ammo_items() -> void:
	var fixed := false
	for pool in [stash_items, backpack_storage, carried_loot]:
		for item in pool:
			if item.get("consumable_type", "") != "ammo":
				continue
			var canonical: Dictionary = {}
			for pool_item in AMMO_POOL:
				if pool_item.get("ammo_type", "") == item.get("ammo_type", ""):
					canonical = pool_item
					break
			if canonical.is_empty():
				continue
			if item.get("slot", "") != "ammo":
				item["slot"] = "ammo"
				fixed = true
			if item.get("rarity", "") != canonical.get("rarity", ""):
				item["rarity"] = canonical.get("rarity", "")
				fixed = true
	if fixed:
		save_game()

func _migrate_stash_eggs_to_hatchery() -> void:
	var moved := false
	var i := stash_items.size() - 1
	while i >= 0:
		if stash_items[i].get("slot", "") == "egg":
			pet_eggs.append(stash_items[i])
			stash_items.remove_at(i)
			moved = true
		i -= 1
	if moved:
		save_game()

# Older saves (from before the grid-overflow fix) can have multiple items
# sharing the exact same grid cell - most commonly everything piling up
# at (0,0). This finds and re-spreads any such overlaps into genuinely
# free cells, once, right after loading.
func _repair_overlapping_grid_items() -> void:
	_repair_grid_list(stash_items, false)
	_repair_grid_list(carried_loot, true)
	_repair_backpack_storage_overlaps()
	_repair_case_storage_overlaps()

# Same idea as _repair_grid_list, but backpack_storage's own free-cell
# finder (_next_free_cell_backpack_storage) reads the live backpack_storage
# array directly instead of taking one as a parameter, so this rebuilds it
# incrementally instead - each already-validated item goes back in before
# the next fix is looked up, so the finder only ever sees positions already
# confirmed clear. Needed once real (non-1x1) item footprints landed -
# without this, a save from before that change could have two items
# sitting at positions that only started overlapping once one of them
# grew past a single cell.
func _repair_backpack_storage_overlaps() -> void:
	# Unlike the stash/carried_loot grids, backpack storage has no overflow
	# concept (_next_free_cell_backpack_storage returns (-1,-1) when truly
	# full instead of extending downward), so both axes are a hard bound.
	var original: Array = backpack_storage
	var placed: Array = []
	var needs_fix: Array = []
	for it in original:
		var gx := int(it.get("grid_x", -1))
		var gy := int(it.get("grid_y", -1))
		var fp := get_item_footprint(it)
		var out_of_bounds: bool = gx < 0 or gy < 0 or gx + fp.x > BACKPACK_STORAGE_COLS or gy + fp.y > BACKPACK_STORAGE_ROWS
		if out_of_bounds or _footprint_overlaps(placed, gx, gy, fp.x, fp.y):
			needs_fix.append(it)
		else:
			placed.append(it)
	backpack_storage = placed
	for it in needs_fix:
		var fp := get_item_footprint(it)
		var cell := _next_free_cell_backpack_storage(fp)
		if cell.x >= 0:
			it["grid_x"] = cell.x
			it["grid_y"] = cell.y
		backpack_storage.append(it)

func _repair_grid_list(items: Array, is_backpack: bool) -> void:
	# Columns are a hard cap; rows legitimately are not (_next_free_cell_in
	# extends into invisible "overflow" rows on a full grid rather than
	# ever losing an item), so only the column bound is checked here.
	var cols: int = GRID_COLS if is_backpack else STASH_GRID_COLS
	var placed: Array = []
	var needs_fix: Array = []
	for it in items:
		var gx := int(it.get("grid_x", -1))
		var gy := int(it.get("grid_y", -1))
		var fp := get_item_footprint(it)
		var out_of_bounds: bool = gx < 0 or gy < 0 or gx + fp.x > cols
		if out_of_bounds or _footprint_overlaps(placed, gx, gy, fp.x, fp.y):
			needs_fix.append(it)
		else:
			placed.append(it)
	for it in needs_fix:
		var fp := get_item_footprint(it)
		var cell := _next_free_cell_in(placed, is_backpack, fp)
		it["grid_x"] = cell.x
		it["grid_y"] = cell.y
		placed.append(it)

# --- Crosshair cursor (used during gameplay; menus use the Jolt cursor) ---
var _crosshair_texture: ImageTexture
var _menu_cursor_texture: Texture2D

func set_crosshair_cursor() -> void:
	Input.set_custom_mouse_cursor(_crosshair_texture, Input.CURSOR_ARROW, Vector2(10, 10))

func set_default_cursor() -> void:
	if _menu_cursor_texture != null:
		Input.set_custom_mouse_cursor(_menu_cursor_texture, Input.CURSOR_ARROW, Vector2(8, 5))
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func _make_menu_cursor_texture() -> Texture2D:
	var path := "res://assets/cursor/menu_cursor.png"
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func _make_crosshair_texture() -> ImageTexture:
	# A clean white "gap cross" - four short thick dashes with an open
	# center, no dot. Slightly bigger than the old one, but still small
	# enough to stay precise.
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Color(1, 1, 1, 0.95)
	@warning_ignore("integer_division")
	var mid := size / 2
	var gap := 4
	var length := 5
	var thickness := 2
	@warning_ignore("integer_division")
	var half_thick := thickness / 2
	# Left and right horizontal dashes.
	for x in range(mid - gap - length, mid - gap):
		for t in range(-half_thick, thickness - half_thick):
			img.set_pixel(x, mid + t, c)
	for x in range(mid + gap, mid + gap + length):
		for t in range(-half_thick, thickness - half_thick):
			img.set_pixel(x, mid + t, c)
	# Top and bottom vertical dashes.
	for y in range(mid - gap - length, mid - gap):
		for t in range(-half_thick, thickness - half_thick):
			img.set_pixel(mid + t, y, c)
	for y in range(mid + gap, mid + gap + length):
		for t in range(-half_thick, thickness - half_thick):
			img.set_pixel(mid + t, y, c)
	img.set_pixel(mid, mid + gap + length + 1, Color(0.05, 0.05, 0.05, 0.35))
	return ImageTexture.create_from_image(img)

func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx2 := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx2, "SFX")
		AudioServer.set_bus_send(idx2, "Master")

func apply_settings() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume / 100.0))
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume / 100.0))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume / 100.0))
	match window_mode_setting:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"windowed_fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func add_loot(item: Dictionary) -> bool:
	if run_over:
		return false
	var merged := _try_merge_currency_item(carried_loot, item)
	if merged > 0:
		carried_value += merged
		record_loot_collected(merged)
		return true
	if _try_merge_grenade_stack(carried_loot, item):
		record_loot_collected(int(item.get("value", 0)))
		return true
	if _try_merge_ammo_stack(carried_loot, item):
		record_loot_collected(int(item.get("value", 0)))
		return true
	if is_carried_full():
		toast_requested.emit("Backpack is full")
		return false
	var cell := _next_free_cell_in(carried_loot, true, get_item_footprint(item))
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	carried_loot.append(item)
	carried_value += int(item.get("value", 0))
	record_loot_collected(int(item.get("value", 0)))
	if gauntlet_session_active:
		gauntlet_session_loot.append(item.duplicate(true))
	return true

# --- Vicinity: freshly-searched loot lands HERE first, not straight into
# the Backpack - a separate panel/column so the item's icon genuinely
# isn't visible anywhere until the search finishes. From there the player
# drags it into the Backpack, drags it onto a matching Equip slot, or
# clicks it to send it straight to the Backpack.
var vicinity_items: Array = []

var vicinity_origin: Vector2 = Vector2.ZERO
var vicinity_has_origin: bool = false
const VICINITY_LEASH_DISTANCE := 220.0

# Loot you walk away from isn't destroyed anymore - it's banked here at
# the position you left it, and restored back into vicinity_items if
# you wander back near that spot. Only cleared for real when you
# actually claim it into the Backpack or an equip slot.
var vicinity_stashed_pockets: Array = []

func add_to_vicinity(item: Dictionary, source_position = null) -> void:
	item["grid_x"] = vicinity_items.size()
	item["grid_y"] = 0
	vicinity_items.append(item)
	if source_position != null:
		vicinity_origin = source_position
		vicinity_has_origin = true
	vicinity_changed.emit()

# Vicinity represents what's immediately near you. Walking off doesn't
# destroy it anymore - it gets left behind at that spot (still inside
# its container, effectively) and comes back into view if you return.
func check_vicinity_leash(player_position: Vector2) -> void:
	if vicinity_items.is_empty() or not vicinity_has_origin:
		_maybe_restore_vicinity_pocket(player_position)
		return
	if player_position.distance_to(vicinity_origin) > VICINITY_LEASH_DISTANCE:
		vicinity_stashed_pockets.append({"position": vicinity_origin, "items": vicinity_items.duplicate(true)})
		vicinity_items.clear()
		vicinity_has_origin = false
		vicinity_changed.emit()

# Checks whether the player has wandered back near a pocket of loot
# they left behind earlier, and if so, brings it back into vicinity.
func _maybe_restore_vicinity_pocket(player_position: Vector2) -> void:
	for i in range(vicinity_stashed_pockets.size()):
		var pocket: Dictionary = vicinity_stashed_pockets[i]
		if player_position.distance_to(pocket["position"]) <= VICINITY_LEASH_DISTANCE * 0.6:
			vicinity_items = pocket["items"]
			_reindex_vicinity()
			vicinity_origin = pocket["position"]
			vicinity_has_origin = true
			vicinity_stashed_pockets.remove_at(i)
			vicinity_changed.emit()
			return

func _reindex_vicinity() -> void:
	for i in range(vicinity_items.size()):
		vicinity_items[i]["grid_x"] = i
		vicinity_items[i]["grid_y"] = 0

# Used when dropping a Vicinity tile onto the Backpack grid at a specific cell.
func drop_carried_to_vicinity(index: int, drop_position: Vector2) -> void:
	if index < 0 or index >= carried_loot.size():
		return
	var item: Dictionary = carried_loot[index]
	carried_loot.remove_at(index)
	add_to_vicinity(item, drop_position)
	toast_requested.emit("Dropped %s" % item.get("name", "Item"))

func drop_equipped_to_vicinity(equip_slot: String, drop_position: Vector2) -> void:
	var item = equipped_items.get(equip_slot)
	if item == null:
		return
	equipped_items[equip_slot] = null
	equipped_changed.emit()
	add_to_vicinity(item, drop_position)
	toast_requested.emit("Dropped %s" % item.get("name", "Item"))

func vicinity_claim_to_cell(index: int, gx: int, gy: int) -> void:
	if index < 0 or index >= vicinity_items.size():
		return
	var item: Dictionary = vicinity_items[index]
	var can_merge_currency: bool = _would_merge_currency(carried_loot, item)
	var can_merge_grenade: bool = item.get("consumable_type", "") == "grenade" and _would_merge_grenade(carried_loot, item)
	var can_merge_ammo: bool = _would_merge_ammo(carried_loot, item)
	if not can_merge_currency and not can_merge_grenade and not can_merge_ammo and is_carried_full():
		toast_requested.emit("Backpack is full")
		return
	vicinity_items.remove_at(index)
	_reindex_vicinity()
	var merged := _try_merge_currency_item(carried_loot, item)
	if merged > 0:
		carried_value += merged
		toast_requested.emit("Stowed %s" % item.get("name", "Item"))
		vicinity_changed.emit()
		return
	if _try_merge_grenade_stack(carried_loot, item):
		toast_requested.emit("Stowed %s" % item.get("name", "Item"))
		vicinity_changed.emit()
		return
	if _try_merge_ammo_stack(carried_loot, item):
		toast_requested.emit("Stowed %s" % item.get("name", "Item"))
		vicinity_changed.emit()
		return
	if _footprint_overlaps(carried_loot, gx, gy, get_item_footprint(item).x, get_item_footprint(item).y):
		var cell := _next_free_cell_in(carried_loot, true, get_item_footprint(item))
		gx = cell.x
		gy = cell.y
	item["grid_x"] = gx
	item["grid_y"] = gy
	carried_loot.append(item)
	carried_value += int(item.get("value", 0))
	toast_requested.emit("Stowed %s" % item.get("name", "Item"))
	vicinity_changed.emit()

# Used for a single click on a Vicinity tile - sends it to the next free
# Backpack cell without needing to drag.
func vicinity_claim_to_next_free(index: int) -> void:
	if index < 0 or index >= vicinity_items.size():
		return
	var item: Dictionary = vicinity_items[index]
	var can_merge_currency: bool = _would_merge_currency(carried_loot, item)
	var can_merge_grenade: bool = item.get("consumable_type", "") == "grenade" and _would_merge_grenade(carried_loot, item)
	var can_merge_ammo: bool = _would_merge_ammo(carried_loot, item)
	if not can_merge_currency and not can_merge_grenade and not can_merge_ammo and is_carried_full():
		toast_requested.emit("Backpack is full")
		return
	vicinity_items.remove_at(index)
	_reindex_vicinity()
	var merged := _try_merge_currency_item(carried_loot, item)
	if merged > 0:
		carried_value += merged
		toast_requested.emit("Stowed %s" % item.get("name", "Item"))
		vicinity_changed.emit()
		return
	if _try_merge_grenade_stack(carried_loot, item):
		toast_requested.emit("Stowed %s" % item.get("name", "Item"))
		vicinity_changed.emit()
		return
	if _try_merge_ammo_stack(carried_loot, item):
		toast_requested.emit("Stowed %s" % item.get("name", "Item"))
		vicinity_changed.emit()
		return
	var cell := _next_free_cell_in(carried_loot)
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	carried_loot.append(item)
	carried_value += int(item.get("value", 0))
	toast_requested.emit("Stowed %s" % item.get("name", "Item"))
	vicinity_changed.emit()

# Dragging a Vicinity tile straight onto a matching Equip slot.
func vicinity_equip(index: int) -> bool:
	if index < 0 or index >= vicinity_items.size():
		return false
	var item: Dictionary = vicinity_items[index]
	var slot: String = item.get("slot", "")
	if not equipped_items.has(slot):
		return false
	vicinity_items.remove_at(index)
	_reindex_vicinity()
	var current = equipped_items[slot]
	equipped_items[slot] = item
	if current != null:
		var cell := _next_free_cell_in(carried_loot)
		current["grid_x"] = cell.x
		current["grid_y"] = cell.y
		carried_loot.append(current)
		carried_value += int(current.get("value", 0))
	equipped_changed.emit()
	toast_requested.emit("Equipped %s" % item.get("name", "Item"))
	vicinity_changed.emit()
	return true

func vicinity_clear() -> void:
	vicinity_items.clear()
	vicinity_changed.emit()

# "Press F: Take All" - sweeps every item currently sitting in Vicinity
# straight into the Backpack in one go.
func vicinity_take_all() -> void:
	if vicinity_items.is_empty():
		return
	var left_behind := 0
	var taken := 0
	var i := 0
	while i < vicinity_items.size():
		var item: Dictionary = vicinity_items[i]
		var can_merge_currency: bool = _would_merge_currency(carried_loot, item)
		var can_merge_grenade: bool = item.get("consumable_type", "") == "grenade" and _would_merge_grenade(carried_loot, item)
		var can_merge_ammo: bool = _would_merge_ammo(carried_loot, item)
		if not can_merge_currency and not can_merge_grenade and not can_merge_ammo and is_carried_full():
			left_behind += 1
			i += 1
			continue
		vicinity_items.remove_at(i)
		taken += 1
		var merged := _try_merge_currency_item(carried_loot, item)
		if merged > 0:
			carried_value += merged
		elif _try_merge_grenade_stack(carried_loot, item):
			pass
		elif _try_merge_ammo_stack(carried_loot, item):
			pass
		else:
			var cell := _next_free_cell_in(carried_loot)
			item["grid_x"] = cell.x
			item["grid_y"] = cell.y
			carried_loot.append(item)
			carried_value += int(item.get("value", 0))
	_reindex_vicinity()
	vicinity_changed.emit()
	if left_behind > 0:
		toast_requested.emit("Backpack full - %d item(s) left in Vicinity" % left_behind)
	elif taken > 0:
		toast_requested.emit("Took all items into Backpack")

# --- Safe Pockets: accept ANY item (no slot-type restriction). Whatever's
# inside is banked straight to the Stash at the end of a run, win or lose.
func move_carried_to_pocket(carried_index: int, pocket_index: int) -> bool:
	if carried_index < 0 or carried_index >= carried_loot.size():
		return false
	if pocket_index < 0 or pocket_index >= safe_pockets.size():
		return false
	var item: Dictionary = carried_loot[carried_index]
	carried_loot.remove_at(carried_index)
	carried_value -= int(item.get("value", 0))
	var old = safe_pockets[pocket_index]
	safe_pockets[pocket_index] = item
	if old != null:
		var cell := _next_free_cell_in(carried_loot)
		old["grid_x"] = cell.x
		old["grid_y"] = cell.y
		carried_loot.append(old)
		carried_value += int(old.get("value", 0))
	pockets_changed.emit()
	return true

func move_vicinity_to_pocket(vicinity_index: int, pocket_index: int) -> bool:
	if vicinity_index < 0 or vicinity_index >= vicinity_items.size():
		return false
	if pocket_index < 0 or pocket_index >= safe_pockets.size():
		return false
	var item: Dictionary = vicinity_items[vicinity_index]
	vicinity_items.remove_at(vicinity_index)
	_reindex_vicinity()
	var old = safe_pockets[pocket_index]
	safe_pockets[pocket_index] = item
	if old != null:
		var cell := _next_free_cell_in(carried_loot)
		old["grid_x"] = cell.x
		old["grid_y"] = cell.y
		carried_loot.append(old)
		carried_value += int(old.get("value", 0))
	vicinity_changed.emit()
	pockets_changed.emit()
	return true

func remove_from_pocket(pocket_index: int) -> bool:
	if pocket_index < 0 or pocket_index >= safe_pockets.size():
		return false
	var item = safe_pockets[pocket_index]
	if item == null:
		return false
	safe_pockets[pocket_index] = null
	var cell := _next_free_cell_in(carried_loot)
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	carried_loot.append(item)
	carried_value += int(item.get("value", 0))
	pockets_changed.emit()
	return true

# Stash/Backpack Storage counterparts to move_carried_to_pocket() above -
# PocketSlot.gd only used to accept drops sourced from "carried"/
# "vicinity" (in-raid only), silently rejecting drags from the Stash
# screen's own grids entirely. A displaced item goes back to whichever
# container the new one came from, same rule the in-raid pair already
# follows for carried_loot.
func move_stash_to_pocket(stash_index: int, pocket_index: int) -> bool:
	if stash_index < 0 or stash_index >= stash_items.size():
		return false
	if pocket_index < 0 or pocket_index >= safe_pockets.size():
		return false
	var item: Dictionary = stash_items[stash_index]
	stash_items.remove_at(stash_index)
	var old = safe_pockets[pocket_index]
	safe_pockets[pocket_index] = item
	if old != null:
		_add_to_stash(old)
	pockets_changed.emit()
	save_game()
	return true

func move_backpack_storage_to_pocket(backpack_index: int, pocket_index: int) -> bool:
	if backpack_index < 0 or backpack_index >= backpack_storage.size():
		return false
	if pocket_index < 0 or pocket_index >= safe_pockets.size():
		return false
	var item: Dictionary = backpack_storage[backpack_index]
	backpack_storage.remove_at(backpack_index)
	var old = safe_pockets[pocket_index]
	safe_pockets[pocket_index] = item
	if old != null:
		if not add_to_backpack_storage(old):
			_add_to_stash(old)
	pockets_changed.emit()
	save_game()
	return true

# Public wrapper so UI code (search-in-progress tile) can preview where a
# new item will land in the Backpack grid without adding it yet.
func peek_next_carried_cell() -> Vector2i:
	return _next_free_cell_in(carried_loot)

# --- Search UX helpers: Chest/Corpse call these instead of emitting the
# signals directly, so GameManager "uses" its own signals (keeps the editor
# from flagging them as unused) and callers don't need signal-emit syntax. ---
func start_search(items: Array, duration: float) -> void:
	search_started.emit(items, duration)

func report_search_progress(pct: float) -> void:
	search_progress.emit(pct)

func finish_search() -> void:
	search_finished.emit()

func get_total_value() -> int:
	var total := 0
	for it in stash_items:
		total += int(it.get("value", 0))
	for slot in equipped_items:
		var item = equipped_items[slot]
		if item != null:
			total += int(item.get("value", 0))
	return total

# Sums the stat bonus of a given type across all currently equipped items,
# PLUS any attachments installed on the currently equipped weapon.
func get_equipped_bonus(stat_type: String) -> float:
	var total := get_pet_bonus(stat_type)
	const ARMOR_HEALTH_MULT := 1.5
	# Weapons were hitting far too hard across the board - halved right
	# at the source instead of editing every damage value in every loot
	# pool by hand, so Skill Tree/Hideout/pet damage bonuses (which
	# aren't "weapons") are untouched.
	const WEAPON_DAMAGE_MULT := 0.5
	for slot in equipped_items:
		var item = equipped_items[slot]
		if item != null:
			var is_armor_slot: bool = slot == "head" or slot == "body"
			var is_weapon_slot: bool = slot == "weapon"
			if item.get("stat_type", "") == stat_type:
				var v := float(item.get("stat_value", 0.0))
				if is_armor_slot and stat_type == "max_health":
					v *= ARMOR_HEALTH_MULT
				if is_weapon_slot and stat_type == "damage":
					v *= WEAPON_DAMAGE_MULT
				total += v
			if item.get("stat_type_2", "") == stat_type:
				var v2 := float(item.get("stat_value_2", 0.0))
				if is_armor_slot and stat_type == "max_health":
					v2 *= ARMOR_HEALTH_MULT
				if is_weapon_slot and stat_type == "damage":
					v2 *= WEAPON_DAMAGE_MULT
				total += v2
	var weapon = equipped_items.get("weapon")
	if weapon != null and weapon.has("attachments"):
		var attachments: Dictionary = weapon["attachments"]
		for key in attachments:
			var att = attachments[key]
			if att != null and att.get("stat_type", "") == stat_type:
				total += float(att.get("stat_value", 0.0))
	return total

# --- Free-form inventory grid helpers (Tarkov-style placement) ---
# Works for both the permanent Stash grid and the in-run Backpack grid.

func is_carried_full() -> bool:
	var rows := get_grid_rows() + int(get_upgrade_bonus("backpack_rows"))
	return carried_loot.size() >= GRID_COLS * rows

# Every item is a uniform 1x1 tile - the earlier variable-footprint
# ("Tarkov-style tetris") system has been reverted per feedback.
# --- Bloodline weapon type: which weapon icon_keys count as melee vs
# ranged. Drives both the player's left-click behavior (swing vs
# shoot) and the "MELEE WEAPON"/"PROJECTILE WEAPON" tag shown on every
# weapon drop, so it's always clear what a weapon actually does before
# you equip it.
const GAUNTLET_MELEE_WEAPON_KEYS := ["sword", "thorn"]

func is_gauntlet_item_melee(item: Dictionary) -> bool:
	if item.get("slot", "") != "weapon":
		return false
	return GAUNTLET_MELEE_WEAPON_KEYS.has(item.get("icon_key", ""))

func get_gauntlet_weapon_type_label(item: Dictionary) -> String:
	if item.get("slot", "") != "weapon":
		return ""
	return "MELEE WEAPON" if is_gauntlet_item_melee(item) else "PROJECTILE WEAPON"

func get_item_footprint(item: Dictionary) -> Vector2i:
	var slot: String = item.get("slot", "")
	if slot == "weapon":
		match item.get("icon_key", ""):
			"sniper":
				return Vector2i(3, 1)
			"rifle", "shotgun", "railgun":
				return Vector2i(2, 1)
			_:
				return Vector2i(1, 1)
	if slot == "body":
		return Vector2i(2, 2)
	return Vector2i(1, 1)

# Rotates an item 90 degrees (swaps its footprint width/height) if the
# rotated footprint actually fits at its current grid position without
# overlapping anything else. Square (1x1, 2x2) footprints are a no-op
# visually but the flag still flips harmlessly.
func rotate_item(index: int, source: String) -> bool:
	var items: Array = _get_grid_array(source)
	if items == null or index < 0 or index >= items.size():
		return false
	var it: Dictionary = items[index]
	var current_fp := get_item_footprint(it)
	if current_fp.x == current_fp.y:
		return false
	var new_rotated: bool = not it.get("rotated", false)
	var new_fp := Vector2i(current_fp.y, current_fp.x)
	var gx := int(it.get("grid_x", 0))
	var gy := int(it.get("grid_y", 0))
	if gx + new_fp.x > GRID_COLS:
		return false
	if _footprint_overlaps(items, gx, gy, new_fp.x, new_fp.y, it):
		return false
	it["rotated"] = new_rotated
	save_game()
	return true

func _get_grid_array(source: String) -> Variant:
	match source:
		"stash": return stash_items
		"carried": return carried_loot
		_: return null

# Checks whether a candidate rectangle (gx,gy)-(gx+fw,gy+fh) overlaps
# ANY existing item's own footprint - so a 1x1 search correctly avoids
# landing on top of, say, a 2x2 backpack, and vice versa.
func _footprint_overlaps(items: Array, gx: int, gy: int, fw: int, fh: int, ignore_item = null) -> bool:
	for it in items:
		if ignore_item != null and it == ignore_item:
			continue
		var ix := int(it.get("grid_x", -1))
		var iy := int(it.get("grid_y", -1))
		var ifp := get_item_footprint(it)
		if gx < ix + ifp.x and ix < gx + fw and gy < iy + ifp.y and iy < gy + fh:
			return true
	return false

func _cell_occupied(items: Array, gx: int, gy: int) -> bool:
	return _footprint_overlaps(items, gx, gy, 1, 1)

func _next_free_cell_in(items: Array, is_backpack: bool = true, footprint: Vector2i = Vector2i(1, 1), ignore_item = null) -> Vector2i:
	var rows: int
	var cols: int
	if is_backpack:
		rows = get_grid_rows() + int(get_upgrade_bonus("backpack_rows"))
		cols = GRID_COLS
	else:
		rows = get_stash_grid_rows()
		cols = STASH_GRID_COLS
	var max_x: int = max(cols - footprint.x + 1, 1)
	for y in range(max(rows - footprint.y + 1, 1)):
		for x in range(max_x):
			if not _footprint_overlaps(items, x, y, footprint.x, footprint.y, ignore_item):
				return Vector2i(x, y)
	# The visible grid is completely full. Rather than silently returning
	# an already-occupied cell (which used to stack items invisibly on
	# top of each other), keep extending downward into overflow rows
	# until a genuinely free cell is found. These extra rows just won't
	# be visible until the grid grows or something is cleared out - but
	# nothing is ever lost or overlapped.
	var overflow_y := rows
	for _iteration in range(100000):
		for x in range(max_x):
			if not _footprint_overlaps(items, x, overflow_y, footprint.x, footprint.y, ignore_item):
				return Vector2i(x, overflow_y)
		overflow_y += 1
	# Unreachable in any real scenario (would require ~800,000 items in
	# one grid) - only here so the parser can see every path returns.
	return Vector2i(0, overflow_y)

func _add_to_stash(item: Dictionary) -> void:
	# Eggs go straight to the Hatchery queue instead of taking up a Stash
	# tile - no more digging one out and right-clicking "Deposit to
	# Hatchery" by hand. This covers every source (raid loot, quests,
	# mail, crafting, Flea Market, the works) since they all funnel
	# through this one function.
	if item.get("slot", "") == "egg":
		add_pet_egg(item)
		return
	if _try_merge_currency_item(stash_items, item) > 0:
		return
	if _try_merge_grenade_stack(stash_items, item):
		return
	if _try_merge_ammo_stack(stash_items, item):
		return
	var footprint := get_item_footprint(item)
	var cell := _next_free_cell_in(stash_items, false, footprint)
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	stash_items.append(item)

# Re-lays out an item list into neat grid rows, grouped by rarity (best
# first) then slot - used by the "Sort" button in the Stash/Backpack.
const RARITY_SORT_ORDER := ["divine", "multiversal", "exotic", "mythic", "legendary", "epic", "rare", "uncommon", "common"]

func _sort_items_in_place(items: Array) -> void:
	items.sort_custom(func(a, b):
		var ra: int = RARITY_SORT_ORDER.find(a.get("rarity", "common"))
		var rb: int = RARITY_SORT_ORDER.find(b.get("rarity", "common"))
		if ra == -1: ra = RARITY_SORT_ORDER.size()
		if rb == -1: rb = RARITY_SORT_ORDER.size()
		if ra != rb:
			return ra < rb
		var sa: String = a.get("slot", "")
		var sb: String = b.get("slot", "")
		if sa != sb:
			return sa < sb
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	var is_backpack: bool = items == carried_loot
	var placed: Array = []
	for it in items:
		var fp := get_item_footprint(it)
		var cell := _next_free_cell_in(placed, is_backpack, fp)
		it["grid_x"] = cell.x
		it["grid_y"] = cell.y
		placed.append(it)

func sort_stash() -> void:
	_sort_items_in_place(stash_items)

func sort_carried() -> void:
	_sort_items_in_place(carried_loot)

# --- Filter: like Sort, but items matching the chosen category get
# pulled to the very front first, then everything else falls in behind
# using the normal rarity sort. One click, no extra steps.
const FILTER_CATEGORIES := [
	{"id": "weapon", "label": "Weapons", "icon_key": "pistol"},
	{"id": "head", "label": "Head", "icon_key": "helmet"},
	{"id": "body", "label": "Body Armor", "icon_key": "chestplate"},
	{"id": "boots", "label": "Boots", "icon_key": "boots"},
	{"id": "accessory", "label": "Accessories", "icon_key": "ring"},
	{"id": "backpack", "label": "Backpacks", "icon_key": "backpack"},
	{"id": "attachment", "label": "Attachments", "icon_key": "visor"},
	{"id": "consumable", "label": "Consumables", "icon_key": "medkit"},
	{"id": "ammo", "label": "Ammo", "icon_key": "ammo_medium"},
	{"id": "valuable", "label": "Valuables", "icon_key": "gpcoin"},
	{"id": "key", "label": "Keys", "icon_key": "key"},
	{"id": "blueprint", "label": "Blueprints", "icon_key": "blueprint"},
	{"id": "lootbag", "label": "Loot Bags", "icon_key": "lootbag"},
	{"id": "pet_case", "label": "Pet Cases", "icon_key": "pet_case"},
	{"id": "rarity", "label": "Rarity", "icon_key": "artifacts_item"},
]

func _item_matches_filter(item: Dictionary, filter_id: String) -> bool:
	var slot: String = item.get("slot", "")
	if filter_id == "attachment":
		return slot == "attachment" or slot == "helmet_attachment"
	return slot == filter_id

func filter_sort_stash(filter_id: String) -> void:
	if filter_id == "rarity":
		# Not a category to isolate like the others - just orders
		# everything best-to-worst rarity in one pass, item name as a
		# tiebreaker so it's stable/predictable rather than shuffling
		# same-rarity items around run to run.
		stash_items.sort_custom(func(a, b):
			var ra: int = RARITY_SORT_ORDER.find(a.get("rarity", "common"))
			var rb: int = RARITY_SORT_ORDER.find(b.get("rarity", "common"))
			if ra == -1: ra = RARITY_SORT_ORDER.size()
			if rb == -1: rb = RARITY_SORT_ORDER.size()
			if ra != rb:
				return ra < rb
			return String(a.get("name", "")) < String(b.get("name", ""))
		)
	else:
		stash_items.sort_custom(func(a, b):
			var a_match: bool = _item_matches_filter(a, filter_id)
			var b_match: bool = _item_matches_filter(b, filter_id)
			if a_match != b_match:
				return a_match
			var ra: int = RARITY_SORT_ORDER.find(a.get("rarity", "common"))
			var rb: int = RARITY_SORT_ORDER.find(b.get("rarity", "common"))
			if ra == -1: ra = RARITY_SORT_ORDER.size()
			if rb == -1: rb = RARITY_SORT_ORDER.size()
			if ra != rb:
				return ra < rb
			return String(a.get("name", "")) < String(b.get("name", ""))
		)
	var placed: Array = []
	for it in stash_items:
		var fp := get_item_footprint(it)
		var cell := _next_free_cell_in(placed, false, fp)
		it["grid_x"] = cell.x
		it["grid_y"] = cell.y
		placed.append(it)

func _move_item_in(items: Array, index: int, x: int, y: int) -> void:
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
	var fp := get_item_footprint(item)
	# Find every OTHER item whose footprint the target rectangle would
	# overlap. A clean swap only makes sense if there's exactly one and
	# it's the same size as the item being dragged - otherwise, moving
	# there would either overlap something or leave a gap, so instead
	# just find the nearest free spot rather than create a broken state.
	var blockers: Array = []
	for other in items:
		if other == item:
			continue
		var ox := int(other.get("grid_x", -1))
		var oy := int(other.get("grid_y", -1))
		var ofp := get_item_footprint(other)
		if x < ox + ofp.x and ox < x + fp.x and y < oy + ofp.y and oy < y + fp.y:
			blockers.append(other)
	if blockers.is_empty():
		item["grid_x"] = x
		item["grid_y"] = y
		return
	if blockers.size() == 1:
		var other: Dictionary = blockers[0]
		var ofp := get_item_footprint(other)
		if ofp == fp:
			other["grid_x"] = item.get("grid_x", 0)
			other["grid_y"] = item.get("grid_y", 0)
			item["grid_x"] = x
			item["grid_y"] = y
			return
	# Can't cleanly place or swap here - leave it where a valid spot is
	# instead of silently overlapping something. _move_item_in is shared
	# by both stash_items and carried_loot (different grid dimensions) -
	# this has to match whichever array was actually passed in, not
	# always assume Backpack.
	var fallback := _next_free_cell_in(items, items == carried_loot, fp, item)
	item["grid_x"] = fallback.x
	item["grid_y"] = fallback.y

func move_item_to_cell(index: int, x: int, y: int) -> void:
	_move_item_in(stash_items, index, x, y)

func move_carried_item_to_cell(index: int, x: int, y: int) -> void:
	_move_item_in(carried_loot, index, x, y)

# --- Equip / unequip: out-of-run (Stash, uses stash_items) ---

func equip_item(stash_index: int) -> void:
	if stash_index < 0 or stash_index >= stash_items.size():
		return
	var item: Dictionary = stash_items[stash_index]
	var slot: String = item.get("slot", "")
	if not equipped_items.has(slot):
		return
	var current = equipped_items[slot]
	stash_items.remove_at(stash_index)
	if current != null:
		_add_to_stash(current)
	equipped_items[slot] = item
	equipped_changed.emit()

func unequip_item(slot: String) -> void:
	if not equipped_items.has(slot):
		return
	var item = equipped_items[slot]
	if item == null:
		return
	equipped_items[slot] = null
	_add_to_stash(item)
	equipped_changed.emit()

# --- PMC Loadout Presets: save your currently equipped gear into one of
# a fixed 3 slots, then one-click re-equip it later - the permanent-gear
# equivalent of Arena's disposable loadout presets (which restore
# automatically after the match; this is real gear, so applying a
# preset here genuinely swaps what's in your Stash).
const LOADOUT_PRESET_SLOT_COUNT := 3
var player_loadout_presets: Array = [null, null, null]

func save_loadout_preset(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= LOADOUT_PRESET_SLOT_COUNT:
		return
	player_loadout_presets[slot_index] = equipped_items.duplicate(true)
	toast_requested.emit("Saved current gear as Loadout %d" % (slot_index + 1))
	save_game()

func delete_loadout_preset(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= LOADOUT_PRESET_SLOT_COUNT:
		return
	player_loadout_presets[slot_index] = null
	save_game()

# Matches two items ignoring their grid position, since the SAME item
# will almost always have moved since a preset was saved.
func _items_match_ignoring_position(a: Dictionary, b: Dictionary) -> bool:
	for key in b.keys():
		if key == "grid_x" or key == "grid_y":
			continue
		if not a.has(key) or a[key] != b[key]:
			return false
	for key in a.keys():
		if key == "grid_x" or key == "grid_y":
			continue
		if not b.has(key):
			return false
	return true

# Re-equips a saved loadout by finding each of its items in the Stash.
# A slot whose saved item can no longer be found there (sold, lost,
# already equipped elsewhere, etc.) is just left as currently equipped,
# with a toast naming what's missing rather than failing silently.
func apply_loadout_preset(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= LOADOUT_PRESET_SLOT_COUNT:
		return
	var preset = player_loadout_presets[slot_index]
	if preset == null:
		return
	var missing: Array = []
	for slot in preset.keys():
		var wanted = preset[slot]
		var current = equipped_items.get(slot)
		if wanted == null:
			if current != null:
				_add_to_stash(current)
				equipped_items[slot] = null
			continue
		if current != null and _items_match_ignoring_position(current, wanted):
			continue
		var found_index := -1
		for i in range(stash_items.size()):
			if _items_match_ignoring_position(stash_items[i], wanted):
				found_index = i
				break
		if found_index == -1:
			missing.append(str(wanted.get("name", "Item")))
			continue
		var found_item: Dictionary = stash_items[found_index]
		stash_items.remove_at(found_index)
		if current != null:
			_add_to_stash(current)
		equipped_items[slot] = found_item
	equipped_changed.emit()
	if missing.is_empty():
		toast_requested.emit("Loadout %d equipped" % (slot_index + 1))
	else:
		toast_requested.emit("Loadout %d equipped - couldn't find: %s" % [slot_index + 1, ", ".join(missing)])
	save_game()

# --- Guilds: simulated (client-side, matching the game's honest "no real
# netcode" design used everywhere else - Global Chat, Find a Team, the
# Leaderboard) - create your own or join one of a small fixed roster of
# simulated guilds. Membership unlocks the Guild chat channel, which
# otherwise shows a "create or join a guild" placeholder.
const GUILD_ROSTER := [
	{"id": "iron_wolves", "name": "Iron Wolves", "tag": "IW", "desc": "Raid hard, extract harder. No excuses."},
	{"id": "night_owls", "name": "Night Owls", "tag": "NO", "desc": "Mostly night raiders. We see you coming."},
	{"id": "scrap_kings", "name": "Scrap Kings", "tag": "SK", "desc": "We loot everything. Everything."},
	{"id": "the_extracted", "name": "The Extracted", "tag": "TEX", "desc": "Survivors only. We've all seen some things out there."},
]
var player_guild_id: String = ""
var player_guild_name: String = ""
var player_guild_tag: String = ""
var player_guild_is_custom: bool = false

func get_guild_roster_entry(guild_id: String) -> Dictionary:
	for g in GUILD_ROSTER:
		if g.get("id", "") == guild_id:
			return g
	return {}

func create_guild(guild_name: String) -> bool:
	var trimmed := guild_name.strip_edges()
	if trimmed == "":
		toast_requested.emit("Enter a guild name first")
		return false
	if trimmed.length() > 24:
		trimmed = trimmed.substr(0, 24)
	player_guild_id = "custom_" + trimmed.to_lower().replace(" ", "_")
	player_guild_name = trimmed
	player_guild_tag = trimmed.substr(0, 3).to_upper()
	player_guild_is_custom = true
	toast_requested.emit("Founded [%s] %s" % [player_guild_tag, player_guild_name])
	Sfx.play_coin_hover()
	save_game()
	return true

func join_guild(guild_id: String) -> bool:
	var g := get_guild_roster_entry(guild_id)
	if g.is_empty():
		return false
	player_guild_id = guild_id
	player_guild_name = str(g.get("name", ""))
	player_guild_tag = str(g.get("tag", ""))
	player_guild_is_custom = false
	toast_requested.emit("Joined [%s] %s" % [player_guild_tag, player_guild_name])
	Sfx.play_coin_hover()
	save_game()
	return true

func leave_guild() -> void:
	if player_guild_id == "":
		return
	toast_requested.emit("Left %s" % player_guild_name)
	Sfx.play_menu_confirm()
	player_guild_id = ""
	player_guild_name = ""
	player_guild_tag = ""
	player_guild_is_custom = false
	save_game()

# A believable simulated member roster drawn from the same name pool
# every other social feature uses (Global Chat, Find a Team, the
# Leaderboard) - seeded off the guild's own id so the SAME guild always
# shows the same roster without needing to persist a member list.
func get_guild_member_names(guild_id: String, count: int = 6) -> Array:
	if guild_id == "":
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(guild_id)
	var pool: Array = LEADERBOARD_NAMES.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, min(count, pool.size()))

# Roles within the simulated member list above - purely a display label,
# same seeded-by-index determinism as the roster itself (index 0 is
# always "Leader" for a given guild, index 1 always "Co-Leader", etc.),
# so revisiting the same guild always shows the same org chart.
func get_guild_member_role(index: int) -> String:
	if index == 0:
		return "Leader"
	elif index == 1:
		return "Co-Leader"
	return "Member"

# The player's own role: founding a guild makes you its Leader by
# definition (there's no one else who could be); joining one of the
# fixed preset guilds makes you a rank-and-file Member alongside its
# simulated roster, which already has its own Leader/Co-Leader per
# get_guild_member_role() above.
func get_player_guild_role() -> String:
	if player_guild_id == "":
		return ""
	return "Leader" if player_guild_is_custom else "Member"

# --- Clan Wars: a bigger, one-a-day guild-vs-guild battle. Unlocks daily
# at CLAN_WAR_UNLOCK_HOUR (real wall-clock time, not in-game time) and
# goes on cooldown for the rest of that calendar day once played -
# mirrors the day-index gate _maybe_send_daily_newsletter() already uses
# elsewhere, extended with an hour check since that one only ever needed
# day granularity.
const CLAN_WAR_UNLOCK_HOUR := 20  # 8 PM local time
const CLAN_WAR_TEAM_SIZE := 8
const CLAN_WAR_WIN_HONOR := 40
const CLAN_WAR_PARTICIPATION_HONOR := 15
var last_clan_war_day: int = -1
var is_clan_war: bool = false

func _current_day_index() -> int:
	return int(_flea_now() / 86400.0)

func _current_hour() -> int:
	return int(Time.get_datetime_dict_from_unix_time(_flea_now()).get("hour", 0))

func clan_war_available() -> bool:
	if player_guild_id == "":
		return false
	if _current_day_index() <= last_clan_war_day:
		return false
	return _current_hour() >= CLAN_WAR_UNLOCK_HOUR

# Status text for the Clan Wars button - three possible states: no
# guild yet, already fought today (waiting for tomorrow's unlock), or
# still waiting for today's unlock hour to arrive.
func clan_war_status_text() -> String:
	if player_guild_id == "":
		return "Join a guild to unlock Clan Wars"
	if _current_day_index() <= last_clan_war_day:
		return "Clan Wars: already fought today - resets at %d:00 PM" % (CLAN_WAR_UNLOCK_HOUR - 12)
	if _current_hour() < CLAN_WAR_UNLOCK_HOUR:
		return "Clan Wars: unlocks at %d:00 PM" % (CLAN_WAR_UNLOCK_HOUR - 12)
	return "Clan Wars: READY"

# Picks a rival guild from the fixed roster to fight - any preset guild
# other than the player's own (a custom guild never collides with the
# preset list at all, so every preset is fair game there).
func _pick_clan_war_rival_id() -> String:
	var candidates: Array = []
	for g in GUILD_ROSTER:
		if g.get("id", "") != player_guild_id:
			candidates.append(g.get("id", ""))
	if candidates.is_empty():
		return GUILD_ROSTER[0].get("id", "")
	return candidates[randi() % candidates.size()]

# Builds current_arena_match the same shape generate_arena_match() does
# (TheGrid.gd/ArenaAlly.gd don't need to know the difference), just
# rostered from guild members instead of the Arena leaderboard, and
# bigger - team_index/role metadata isn't needed here since ArenaAlly.gd
# only ever reads team1[team_index]["name"].
func generate_clan_war_match() -> void:
	var team_size := CLAN_WAR_TEAM_SIZE
	var team1 := [{
		"name": player_name if player_name != "" else "You", "portrait": player_portrait_id if player_portrait_id != "" else "portrait_1",
		"is_player": true, "level": player_level, "gear": equipped_items, "title": equipped_title, "badges": owned_badges,
		"arena_rank": get_arena_rank_display_name(), "arena_color": get_arena_rank_tier().get("color", Color.WHITE),
	}]
	for member_name in get_guild_member_names(player_guild_id, team_size - 1):
		team1.append({
			"name": member_name, "portrait": "portrait_1", "is_player": false,
			"level": player_level, "gear": {}, "title": "", "badges": [],
			"arena_rank": "Guildmate", "arena_color": Color(0.85, 0.65, 1.0, 1),
		})
	var rival_id := _pick_clan_war_rival_id()
	var rival: Dictionary = get_guild_roster_entry(rival_id)
	var team2 := []
	for member_name in get_guild_member_names(rival_id, team_size):
		team2.append({
			"name": member_name, "portrait": "portrait_1", "is_player": false,
			"level": player_level, "gear": {}, "title": "", "badges": [],
			"arena_rank": str(rival.get("tag", "?")), "arena_color": Color(0.9, 0.4, 0.4, 1),
		})
	current_arena_match = {"team_size": team_size, "team1": team1, "team2": team2, "rival_guild_name": rival.get("name", "Rival Guild")}
	is_arena_match = true
	is_clan_war = true
	last_clan_war_day = _current_day_index()
	save_game()

# --- Guild Battle Pass: a permanent (non-seasonal) tier track earned
# through Honor, same "flat cost per tier, hand-authored named rewards"
# shape as the Milestones track above - Honor comes from Clan Wars
# (win or lose, see end_run()) rather than raid/Arena activity, so it's
# a genuinely separate progression track, not just Milestones reskinned.
var guild_battle_pass_tier: int = 0
var guild_battle_pass_progress: int = 0
var guild_honor: int = 0
const GUILD_HONOR_PER_TIER := 60
const GUILD_BATTLE_PASS_MAX_TIER := 20

const GUILD_BATTLE_PASS_TIER_DATA := [
	{"name": "Guild Recruit", "type": "rubles", "amount": 200},
	{"name": "First Blood", "type": "xp", "amount": 200},
	{"name": "Squad Tactics", "type": "skill_points", "amount": 1},
	{"name": "Banner Bearer", "type": "rubles", "amount": 350},
	{"name": "War Footing", "type": "lootbag", "bag_tier": "common"},
	{"name": "Guild Regular", "type": "rubles", "amount": 500},
	{"name": "Line Holder", "type": "xp", "amount": 300},
	{"name": "War Veteran", "type": "skill_points", "amount": 1},
	{"name": "Guild Officer", "type": "rubles", "amount": 700},
	{"name": "Clan War Specialist", "type": "lootbag", "bag_tier": "rare"},
	{"name": "Frontline Regular", "type": "rubles", "amount": 900},
	{"name": "War Tactician", "type": "xp", "amount": 450},
	{"name": "Guild Champion", "type": "skill_points", "amount": 2},
	{"name": "Clan War Veteran", "type": "rubles", "amount": 1200},
	{"name": "Shield of the Guild", "type": "lootbag", "bag_tier": "rare"},
	{"name": "War Elite", "type": "rubles", "amount": 1500},
	{"name": "Guild Vanguard", "type": "xp", "amount": 600},
	{"name": "Clan War Legend", "type": "skill_points", "amount": 2},
	{"name": "Guild Hero", "type": "lootbag", "bag_tier": "epic"},
	{"name": "Founder's Honor", "type": "lootbag", "bag_tier": "legendary"},
]

func grant_guild_honor(amount: int) -> void:
	if amount <= 0:
		return
	add_currency("honor", amount)
	if guild_battle_pass_tier >= GUILD_BATTLE_PASS_MAX_TIER:
		return
	guild_battle_pass_progress += amount
	while guild_battle_pass_progress >= GUILD_HONOR_PER_TIER and guild_battle_pass_tier < GUILD_BATTLE_PASS_MAX_TIER:
		guild_battle_pass_progress -= GUILD_HONOR_PER_TIER
		_advance_guild_battle_pass_tier()

func _advance_guild_battle_pass_tier() -> void:
	guild_battle_pass_tier += 1
	var tier_data: Dictionary = GUILD_BATTLE_PASS_TIER_DATA[guild_battle_pass_tier - 1]
	match tier_data.get("type", ""):
		"rubles":
			add_currency("rubles", int(tier_data.get("amount", 0)))
		"xp":
			grant_xp(int(tier_data.get("amount", 0)))
		"skill_points":
			add_currency("skill_points", int(tier_data.get("amount", 0)))
		"lootbag":
			_add_to_stash(make_loot_bag(str(tier_data.get("bag_tier", "rare"))))
	toast_requested.emit("Guild tier reached: %s!" % str(tier_data.get("name", "Tier %d" % guild_battle_pass_tier)))

# --- Equip / unequip: mid-run (Backpack, uses carried_loot). Reverts on
# death via run_start_equipped_snapshot; becomes permanent on extraction. ---

func equip_from_carried(carried_index: int) -> void:
	if carried_index < 0 or carried_index >= carried_loot.size():
		return
	var item: Dictionary = carried_loot[carried_index]
	var slot: String = item.get("slot", "")
	if not equipped_items.has(slot):
		return
	var current = equipped_items[slot]
	carried_loot.remove_at(carried_index)
	carried_value -= int(item.get("value", 0))
	if current != null:
		var cell := _next_free_cell_in(carried_loot)
		current["grid_x"] = cell.x
		current["grid_y"] = cell.y
		carried_loot.append(current)
		carried_value += int(current.get("value", 0))
	equipped_items[slot] = item
	equipped_changed.emit()

func unequip_to_carried(slot: String) -> void:
	if not equipped_items.has(slot):
		return
	var item = equipped_items[slot]
	if item == null:
		return
	equipped_items[slot] = null
	var cell := _next_free_cell_in(carried_loot)
	item["grid_x"] = cell.x
	item["grid_y"] = cell.y
	carried_loot.append(item)
	carried_value += int(item.get("value", 0))
	equipped_changed.emit()

# Drag-out-of-doll variants: place the unequipped item at the EXACT cell
# the player dropped it on, instead of just the next free slot.
func unequip_to_stash_cell(slot: String, gx: int, gy: int) -> void:
	if not equipped_items.has(slot):
		return
	var item = equipped_items[slot]
	if item == null:
		return
	equipped_items[slot] = null
	if _footprint_overlaps(stash_items, gx, gy, get_item_footprint(item).x, get_item_footprint(item).y):
		var cell := _next_free_cell_in(stash_items, false, get_item_footprint(item))
		gx = cell.x
		gy = cell.y
	item["grid_x"] = gx
	item["grid_y"] = gy
	stash_items.append(item)
	equipped_changed.emit()

func unequip_to_carried_cell(slot: String, gx: int, gy: int) -> void:
	if not equipped_items.has(slot):
		return
	var item = equipped_items[slot]
	if item == null:
		return
	equipped_items[slot] = null
	if _footprint_overlaps(carried_loot, gx, gy, get_item_footprint(item).x, get_item_footprint(item).y):
		var cell := _next_free_cell_in(carried_loot, true, get_item_footprint(item))
		gx = cell.x
		gy = cell.y
	item["grid_x"] = gx
	item["grid_y"] = gy
	carried_loot.append(item)
	carried_value += int(item.get("value", 0))
	equipped_changed.emit()

func unequip_to_backpack_storage_cell(slot: String, gx: int, gy: int) -> void:
	if not equipped_items.has(slot):
		return
	var item = equipped_items[slot]
	if item == null:
		return
	var fp := get_item_footprint(item)
	if _footprint_overlaps(backpack_storage, gx, gy, fp.x, fp.y):
		var cell := _next_free_cell_backpack_storage(fp)
		if cell.x < 0:
			toast_requested.emit("Backpack storage is full")
			return
		gx = cell.x
		gy = cell.y
	equipped_items[slot] = null
	item["grid_x"] = gx
	item["grid_y"] = gy
	backpack_storage.append(item)
	equipped_changed.emit()

# --- The Wandering Ghost: a rare recruitable companion found drifting
# through raids (previously just atmosphere). Interact with him during
# a raid to get the option to recruit him - if he's still following
# you when you extract, he becomes a permanent Hideout resident from
# then on.
var ghost_recruited: bool = false
var rose_talked_to: bool = false
# Once-ever flag - the first time the ambient chat-ping popup fires, a
# toast also mentions the chat keybind, since GlobalChatBox (the real
# multi-channel chat) has zero on-screen affordance otherwise, unlike
# the Social button the ping popup itself points at.
var has_shown_chat_keybind_hint: bool = false
var raid_ghost_following: bool = false

# True while the player has the Tab inventory panel open in a raid -
# used to gate actions (like "F: Take All") that should only work
# while actually looking at the inventory, not any time loot is nearby.
var inventory_tab_open: bool = false

func discover_wandering_ghost() -> void:
	notify_event("find_wandering_ghost")

func recruit_wandering_ghost_for_raid() -> void:
	raid_ghost_following = true

func _check_ghost_extraction() -> void:
	if raid_ghost_following:
		raid_ghost_following = false
		if not ghost_recruited:
			ghost_recruited = true
			toast_requested.emit("The Ghost has followed you home - he's in the Hideout now.")
		notify_event("extract_with_ghost")

func end_run(success: bool, voluntary: bool = false) -> void:
	if run_over:
		return
	run_over = true
	if success:
		# Snapshot BEFORE any XP/currency grants below, so the rewards
		# screen can animate the Level bar filling from where it actually
		# started this raid rather than just snapping to the end state.
		var level_before := player_level
		var xp_before := player_xp
		# Anything left unclaimed in Vicinity still counts - you found it,
		# it just hadn't been dragged into the Backpack yet. carried_value
		# has to be updated here too, same as every other path that moves
		# an item into carried_loot - extraction XP, pet XP, Rank Points,
		# the 5000-loot achievement, and the rewards screen's "Rubles
		# Secured" figure are all computed from it further below.
		for item in vicinity_items:
			carried_loot.append(item)
			carried_value += int(item.get("value", 0))
		for item in carried_loot:
			_add_to_stash(item)
		if is_night_raid:
			notify_event("night_extract")
		if carried_value >= 5000:
			notify_event("extract_5000_loot")
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node != null and player_node.get("health") != null and int(player_node.health) < 50:
			notify_event("low_hp_extract")
			achievement_flag_close_call = true
		stat_extractions += 1
		if is_scav_run:
			stat_scav_extractions += 1
		grant_stones(ARENA_WIN_STONES if is_arena_match else EXTRACTION_STONES)
		if is_clan_war:
			grant_guild_honor(CLAN_WAR_WIN_HONOR)
		add_score(40)
		# "Split the loot" with your guild - simulated the same way every
		# other social feature is (no real other players), framed as your
		# own cut coming back rather than an actual shared pool. Isolated,
		# self-contained addition - deliberately not touching any of this
		# function's existing control flow given how sensitive it already is.
		if player_guild_id != "" and carried_value > 0:
			var guild_bonus: int = int(carried_value * 0.05)
			if guild_bonus > 0:
				add_currency("rubles", guild_bonus)
				toast_requested.emit("%s sent over %d Rubles as your cut from their own runs" % [player_guild_name, guild_bonus])
		# Extraction XP: bumped up across the board (was 20 base), plus a
		# real Night Raid bonus on top - night raids are riskier (worse
		# visibility, tougher odds) and should actually pay out more for
		# making it home, not just carry the same XP as a day raid.
		var extraction_xp: int = 45 + int(carried_value / 6.0)
		if is_night_raid:
			extraction_xp = int(extraction_xp * 1.5)
		grant_xp(extraction_xp)
		grant_pet_xp(20 + int(carried_value / 200.0))
		_check_ghost_extraction()
		_check_pacified_extraction()
		# Ranked: Rank Points only move on a successful Ranked extraction -
		# scaled a little by how much you walked out with, capped so one
		# huge haul can't skip multiple ranks in a single raid.
		var rank_index_before := get_rank_full_index()
		var rank_points_gained := 0
		if is_ranked_match:
			rank_points_gained = clampi(25 + int(carried_value / 40.0), 25, 150)
			rank_points += rank_points_gained
			if is_max_rank(get_rank_full_index()):
				grant_badge("peak_of_the_sector")
		var rank_index_after := get_rank_full_index()
		last_raid_rewards = {
			"loot_value": carried_value,
			"loot_items": carried_loot.duplicate(true),
			"quests": raid_quests_completed.duplicate(),
			"was_scav": is_scav_run,
			"is_ranked": is_ranked_match,
			"xp_gained": extraction_xp,
			"rank_points_gained": rank_points_gained,
			"rank_index_before": rank_index_before,
			"rank_index_after": rank_index_after,
			"level_before": level_before,
			"xp_before": xp_before,
			"level_after": player_level,
			"xp_after": player_xp,
		}
	else:
		stat_deaths += 1
		grant_xp(8)
		if is_clan_war:
			grant_guild_honor(CLAN_WAR_PARTICIPATION_HONOR)
		var dying_player = get_tree().get_first_node_in_group("player")
		last_death_info = {
			"attacker_name": "" if voluntary else (str(dying_player.get("last_attacker_name")) if dying_player != null and dying_player.get("last_attacker_name") != null else ""),
			"attacker_weapon": "" if voluntary else (str(dying_player.get("last_attacker_weapon")) if dying_player != null and dying_player.get("last_attacker_weapon") != null else ""),
			"loot_value": carried_value,
			"timed_out": run_timed_out,
			"voluntary_exit": voluntary,
		}
		# A death means you lose whatever you had equipped, full stop -
		# except Character Bound items (the Alpha/Tech Test exclusives),
		# which stay on you no matter what. Everything else still only
		# survives if it was already in the Stash or a Safe Pocket.
		# Arena is exempt entirely - it's a simulated match, not a real
		# raid, and losing there was never meant to cost your real loadout.
		if not is_arena_match:
			for slot in equipped_items.keys():
				var eq_item = equipped_items[slot]
				if eq_item != null and (eq_item.get("alpha_only", false) or eq_item.get("beta_only", false)):
					continue
				equipped_items[slot] = null
			equipped_changed.emit()
	# A Scav run's gear was never really "yours" - whatever happened to
	# it above, your actual PMC loadout comes back untouched now.
	end_scav_run_if_active()
	# Same idea for an Arena Loadout Preset, if one was applied - the
	# player's real gear/pet come back regardless of win or loss.
	end_arena_loadout_if_active()
	# Safe Pocket items always survive, win or lose. Most items land in
	# the Stash like anything else you extract with - but a couple (the
	# Graveyard Key so far) specifically need to be in Backpack Storage
	# to count for anything, so route those there instead, with the same
	# "fall back to Stash if full" safety net grant_graveyard_key() uses.
	_drain_safe_pockets_to_stash()
	run_ended.emit(success, carried_value)
	save_game()
	get_tree().paused = true
	# No lingering on-screen message before the fade for either outcome -
	# the dedicated Rewards/Death screens cover the summary now.
	await Transition.fade_out(0.6)
	get_tree().paused = false
	carried_loot.clear()
	vicinity_items.clear()
	vicinity_stashed_pockets.clear()
	vicinity_has_origin = false
	raid_ghost_following = false
	raid_pacified_pet_type = ""
	in_graveyard_run = false
	run_timed_out = false
	carried_value = 0
	run_over = false
	selected_recruit = ""
	var was_arena_match := is_arena_match
	is_arena_match = false
	is_clan_war = false
	var next_scene_path: String
	if was_arena_match:
		next_scene_path = "res://scenes/ArenaVictory.tscn" if success else "res://scenes/ArenaDefeat.tscn"
	else:
		next_scene_path = "res://scenes/RaidRewards.tscn" if success else "res://scenes/DeathScreen.tscn"
	get_tree().change_scene_to_packed(Transition.get_cached_scene(next_scene_path))
	await get_tree().process_frame
	Transition.fade_in(0.6)

# Safe Pocket items always survive, win or lose. Most items land in the
# Stash like anything else you extract with - but a couple (the Graveyard
# Key so far) specifically need to be in Backpack Storage to count for
# anything, so route those there instead, with the same "fall back to
# Stash if full" safety net grant_graveyard_key() uses. Also called from
# load_game() to recover pockets left stranded by a mid-raid quit/crash,
# since a raid never survives a cold boot to drain them the normal way.
func _drain_safe_pockets_to_stash() -> void:
	for item in safe_pockets:
		if item == null:
			continue
		if item.get("item_id", "") in BACKPACK_STORAGE_ONLY_ITEM_IDS:
			if not add_to_backpack_storage(item):
				_add_to_stash(item)
				toast_requested.emit("%s came back from your Safe Pocket, but Backpack Storage was full - it's in your Stash for now." % str(item.get("name", "Item")))
		else:
			_add_to_stash(item)
	safe_pockets = [null, null]
	pockets_changed.emit()
