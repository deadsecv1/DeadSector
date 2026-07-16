extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

const SECTION_LIVE := "LIVE NOW"
const SECTION_UPCOMING := "COMING SOON"

const ROADMAP := [
	# --- Live now - actually shipped, in the order it landed. ---
	{"section": SECTION_LIVE, "date": "Jun 30", "title": "Spectral Tide Event", "desc": "A 200-tier Battle Pass, the new Souls currency, and the Commune wave-survival mode.", "icon": "event"},
	{"section": SECTION_LIVE, "date": "Jul 03", "title": "Bloodline Event", "desc": "A full 5-level side-scroller Gauntlet, Justin's Decompilation Rig for deciphering Engrams, a 200-tier reward track, and the Leaderboard.", "icon": "boss"},
	{"section": SECTION_LIVE, "date": "Jul 05", "title": "Dynamic Weather", "desc": "An occasional rain shower rolls in, roughly once every 2-4 raids, changing the mood without overcomplicating visibility.", "icon": "stealth"},
	{"section": SECTION_LIVE, "date": "Jul 08", "title": "Salvaged Beasts Event", "desc": "Hatch Pet Eggs dropped by enemies into companions that fight alongside you, with their own 200-tier Tickets progression track and a dedicated Egg Hatchery.", "icon": "event"},
	{"section": SECTION_LIVE, "date": "Jul 11", "title": "Alpha Rewards", "desc": "A limited-time thank-you claim for anyone playing during the Alpha window - exclusive gear, a title, and a badge that isn't obtainable any other way.", "icon": "star"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "Skill Points", "desc": "A new currency for the Skill Tree, earned from loot, mail, the Battle Pass, and a free 5-minute Starter Pack in the Store - a second way to grow besides Artifacts.", "icon": "gear"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "Character Creation Overhaul", "desc": "Skin color, more clothing silhouettes, a real happy expression, and a cosmetic Particle Trail (dust, shadow smoke, or static) that actually follows you in raids and the Hideout.", "icon": "star"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "A Living Flea Market", "desc": "Listings now rotate on their own random timers instead of sitting static, and the item pool actually includes Legendary through Exotic tiers, not just Common/Uncommon.", "icon": "money"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "Weapons & Keys Compendium", "desc": "The Data screen now has full Weapons and Keys tabs - every gun and key in the game, each with a right-click Inspect for a close-up, full stats, and a preview of its actual projectile.", "icon": "gear"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "100 New Flea Market Listings", "desc": "A hundred new named items now circulate through other players' Flea Market listings, priced the way real people actually price things - most fair, some a steal, a few delusional.", "icon": "money"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "Divine Rarity", "desc": "A new rarity above Multiversal - a 0.01% roll from the Undertow's crates, with 5 items built around the flashiest effects already in the game.", "icon": "star"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "A Real Ammo System", "desc": "Light, Medium, and Heavy Ammo, tied to specific weapon types, dropped by enemies and containers - running dry mid-raid no longer means you're done shooting.", "icon": "gear"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "Rose & Plushies", "desc": "A new Hideout NPC with her own Lore. Plushies are a new universal drop - hand her one and she'll turn it into a real, equippable pet with a guaranteed Plushie Buff.", "icon": "recruits"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "Case Tagging", "desc": "Name and color-code your Loot Bags and Pet Cases so you can tell them apart at a glance in the Stash.", "icon": "gear"},
	{"section": SECTION_LIVE, "date": "Jul 12", "title": "Draggable Windows", "desc": "Every popup window in the game can now be repositioned by its edges - Stash, Traders, Leaderboard, Mail, Global Chat, and everywhere else.", "icon": "compass"},
	{"section": SECTION_LIVE, "date": "Jul 14", "title": "Prestige System", "desc": "Once you hit the level cap, reset back to Level 1 in exchange for a real Rubles and Skill Point bonus - a fresh climb with a reward for reaching the top.", "icon": "star"},
	{"section": SECTION_LIVE, "date": "Jul 14", "title": "Deeper Inventory Overhaul", "desc": "Items now have real footprints in the grid - a sniper takes 3 tiles, body armor takes a 2x2 block, a pistol still fits in one. Specialized Cases (Medical, Gun, Armor, Key) are a rare find that permanently unlock their own dedicated sub-grid, decluttering your main Stash for good.", "icon": "gear"},
	{"section": SECTION_LIVE, "date": "Jul 14", "title": "Clan System", "desc": "Your guildmates now actually share your Hideout - a couple of them wander the place with you between raids. Extract with anything worth carrying and one of them sends over a real cut of Rubles from their own runs.", "icon": "gear"},
	{"section": SECTION_LIVE, "date": "Jul 14", "title": "New Map: The Foundry", "desc": "A gutted industrial furnace complex - genuinely tight corridors this time, not just an open industrial theme. Unlocks at Level 40, with the best salvage in the Sector waiting at the end of the most dangerous one.", "icon": "key"},
	{"section": SECTION_LIVE, "date": "Jul 16", "title": "Weapon & Armor Durability", "desc": "Gear wears down with use - worn weapons and armor lose effectiveness, and a broken weapon can't fire at all. Torque, a new Repairman in the Hideout, fixes anything below full durability for Rubles.", "icon": "gear"},
	# --- Coming soon. ---
	{"section": SECTION_UPCOMING, "date": "Jul 18", "title": "Weekly Events", "desc": "Rotating modifiers - double loot weekends, blackout raids, and more.", "icon": "event"},
	{"section": SECTION_UPCOMING, "date": "Jul 26", "title": "New Trader: The Fence", "desc": "A black-market dealer selling rare gear nobody asks questions about.", "icon": "money"},
	{"section": SECTION_UPCOMING, "date": "Aug 04", "title": "PvP Extraction Mode", "desc": "Other squads are in the sector too. Not everyone's a raider.", "icon": "combat"},
	{"section": SECTION_UPCOMING, "date": "Sep 01", "title": "New Boss: The Warden", "desc": "A second boss guarding a vault deep in a new district.", "icon": "boss"},
	{"section": SECTION_UPCOMING, "date": "Sep 12", "title": "Vehicle Extraction", "desc": "Hot-wire a car and drive out instead of waiting on a chopper.", "icon": "vehicle"},
	{"section": SECTION_UPCOMING, "date": "Oct 09", "title": "Blood Moon Event", "desc": "A limited-time raid where everything - loot AND enemies - doubles.", "icon": "boss"},
	{"section": SECTION_UPCOMING, "date": "Oct 20", "title": "Combat Roll / Dash", "desc": "A directional dodge with a brief invincibility window - a new defensive option in every raid.", "icon": "combat"},
	{"section": SECTION_UPCOMING, "date": "TBD", "title": "1.0 Release", "desc": "The Alpha tag comes off. Everything above ships together as the real launch.", "icon": "star"},
]

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var close_button: Button = $Margin/VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	_build_list()

func _build_list() -> void:
	for c in list.get_children():
		c.queue_free()
	var current_section := ""
	for entry in ROADMAP:
		var section: String = entry.get("section", "")
		if section != current_section:
			current_section = section
			list.add_child(_make_section_header(section))
		list.add_child(_make_row(entry))

func _make_section_header(section: String) -> Control:
	var lbl := Label.new()
	lbl.text = section
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6, 1) if section == SECTION_LIVE else Color(0.7, 0.75, 0.85, 1))
	return lbl

func _make_row(entry: Dictionary) -> Control:
	var is_live: bool = entry.get("section", "") == SECTION_LIVE
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 66)
	var sb := StyleBoxFlat.new()
	if is_live:
		sb.bg_color = Color(0.06, 0.16, 0.08, 0.8)
		sb.border_color = Color(0.5, 0.95, 0.6, 0.75)
		sb.set_border_width_all(1)
	else:
		sb.bg_color = Color(0.09, 0.1, 0.09, 0.7)
	sb.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var icon = SmallIconScene.instantiate()
	icon.icon_type = entry.get("icon", "star")
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var date_lbl := Label.new()
	date_lbl.text = entry.get("date", "")
	date_lbl.custom_minimum_size = Vector2(56, 0)
	date_lbl.add_theme_font_size_override("font_size", 13)
	date_lbl.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6, 1) if is_live else Color(1, 0.55, 0.3, 1))
	hbox.add_child(date_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	var title_lbl := Label.new()
	title_lbl.text = entry.get("title", "")
	title_lbl.add_theme_font_size_override("font_size", 16)
	if is_live:
		title_lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.85, 1))
	title_row.add_child(title_lbl)
	if is_live:
		var live_tag := Label.new()
		live_tag.text = "LIVE"
		live_tag.add_theme_font_size_override("font_size", 10)
		live_tag.add_theme_color_override("font_color", Color(0.06, 0.16, 0.08, 1))
		var tag_bg := PanelContainer.new()
		var tag_sb := StyleBoxFlat.new()
		tag_sb.bg_color = Color(0.5, 0.95, 0.6, 1)
		tag_sb.set_corner_radius_all(4)
		tag_sb.content_margin_left = 6
		tag_sb.content_margin_right = 6
		tag_sb.content_margin_top = 1
		tag_sb.content_margin_bottom = 1
		tag_bg.add_theme_stylebox_override("panel", tag_sb)
		tag_bg.add_child(live_tag)
		title_row.add_child(tag_bg)
	info.add_child(title_row)
	var desc_lbl := Label.new()
	desc_lbl.text = entry.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.75)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	return row

func open() -> void:
	visible = true
	GameManager.focus_first_control(self)
