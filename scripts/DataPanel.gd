extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var enemies_tab: Button = $VBox/TabRow/EnemiesTab
@onready var collectibles_tab: Button = $VBox/TabRow/CollectiblesTab
@onready var maps_tab: Button = $VBox/TabRow/MapsTab
@onready var pets_tab: Button = $VBox/TabRow/PetsTab
@onready var contracts_tab: Button = $VBox/TabRow/ContractsTab
@onready var traders_tab: Button = $VBox/TabRow/TradersTab
@onready var weapons_tab: Button = $VBox/TabRow/WeaponsTab
@onready var armor_tab: Button = $VBox/TabRow/ArmorTab
@onready var keys_tab: Button = $VBox/TabRow/KeysTab
@onready var list: VBoxContainer = $VBox/ListScroll/List
@onready var close_button: Button = $VBox/CloseButton

var current_tab: String = "enemies"

# --- Universal Inspect: every row on every tab (enemies, collectibles,
# maps, pets, contracts, traders, weapons, keys) can be right-clicked
# for a small context menu with an Inspect option, which opens a big
# close-up popup - icon, rarity, full description, stats, and (for
# weapons) a preview of what the projectile actually looks like in a
# raid. Same right-click -> context menu -> action pattern as
# PlayerContextMenu.gd, reused here for data entries instead of players.
var context_menu: PanelContainer
var inspect_popup: PanelContainer = null
var _pending_inspect: Dictionary = {}
const MENU_SIZE := Vector2(120, 44)

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	close_button.pressed.connect(func(): closed.emit())
	enemies_tab.pressed.connect(func(): _switch_tab("enemies"))
	collectibles_tab.pressed.connect(func(): _switch_tab("collectibles"))
	maps_tab.pressed.connect(func(): _switch_tab("maps"))
	pets_tab.pressed.connect(func(): _switch_tab("pets"))
	contracts_tab.pressed.connect(func(): _switch_tab("contracts"))
	traders_tab.pressed.connect(func(): _switch_tab("traders"))
	weapons_tab.pressed.connect(func(): _switch_tab("weapons"))
	armor_tab.pressed.connect(func(): _switch_tab("armor"))
	keys_tab.pressed.connect(func(): _switch_tab("keys"))
	_build_context_menu()

func _input(event: InputEvent) -> void:
	if not context_menu.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not context_menu.get_global_rect().has_point(event.global_position):
			context_menu.visible = false

func open() -> void:
	visible = true
	_switch_tab("enemies")

func _switch_tab(tab: String) -> void:
	current_tab = tab
	enemies_tab.disabled = (tab == "enemies")
	collectibles_tab.disabled = (tab == "collectibles")
	maps_tab.disabled = (tab == "maps")
	pets_tab.disabled = (tab == "pets")
	contracts_tab.disabled = (tab == "contracts")
	traders_tab.disabled = (tab == "traders")
	weapons_tab.disabled = (tab == "weapons")
	armor_tab.disabled = (tab == "armor")
	keys_tab.disabled = (tab == "keys")
	refresh()

func refresh() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	match current_tab:
		"enemies":
			for id in GameManager.ENEMY_CATALOG.keys():
				list.add_child(_make_enemy_row(id))
		"collectibles":
			for id in GameManager.COLLECTIBLE_CATALOG.keys():
				list.add_child(_make_collectible_row(id))
		"pets":
			for id in GameManager.PET_CATALOG.keys():
				list.add_child(_make_pet_row(id, GameManager.PET_CATALOG[id]))
			for rarity in GameManager.EGG_PET_POOL.keys():
				for entry in GameManager.EGG_PET_POOL[rarity]:
					list.add_child(_make_pet_row(entry.get("id", ""), entry, rarity))
			list.add_child(_make_pet_row(GameManager.LOOM_WEAVER_PET_ID, GameManager.LOOM_WEAVER_PET_DATA))
			for entry in GameManager.GRAVEYARD_PACIFIED_POOL:
				list.add_child(_make_pet_row(entry.get("id", ""), entry, "legendary"))
		"maps":
			for id in GameManager.MAP_CATALOG.keys():
				list.add_child(_make_map_row(id))
		"contracts":
			for npc_id in ["echo", "warden", "tinkerer", "cartographer", "reaper"]:
				list.add_child(_make_npc_header_row(npc_id))
				for key in GameManager.QUEST_ORDER:
					if GameManager.QUEST_DATA.get(key, {}).get("npc", "") == npc_id:
						list.add_child(_make_contract_row(key))
		"traders":
			for id in GameManager.TRADER_CATALOG.keys():
				list.add_child(_make_trader_row(id))
		"weapons":
			for id in GameManager.WEAPON_CATALOG.keys():
				list.add_child(_make_weapon_row(id))
		"armor":
			for id in GameManager.ARMOR_CATALOG.keys():
				list.add_child(_make_armor_row(id))
		"keys":
			for id in GameManager.KEY_CATALOG.keys():
				list.add_child(_make_key_row(id))

func _make_row_base() -> Dictionary:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 76)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.08, 0.85)
	sb.border_color = Color(0.3, 0.3, 0.3, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	row.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)
	return {"row": row, "hbox": hbox}

func _make_enemy_row(id: String) -> Control:
	var data: Dictionary = GameManager.ENEMY_CATALOG[id]
	var discovered: bool = GameManager.discovered_enemies.has(id)
	var built := _make_row_base()
	var row: Control = built["row"]
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.05, 0.05, 0.05, 0.9) if not discovered else Color(0.15, 0.12, 0.05, 0.9)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	if discovered:
		var icon = ItemIconScene.instantiate()
		icon.icon_key = data.get("icon_key", "generic")
		icon.icon_color = Color(0.85, 0.75, 0.4, 1)
		icon.custom_minimum_size = Vector2(48, 48)
		icon_box.add_child(icon)
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 26)
		q.modulate = Color(1, 1, 1, 0.4)
		icon_box.add_child(q)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?")) if discovered else "???"
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1) if discovered else Color(1, 1, 1, 0.4))
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(data.get("desc", "")) if discovered else "Not yet encountered - kill one to unlock its entry."
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8) if discovered else Color(1, 1, 1, 0.45)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	if discovered:
		_wire_inspect(row, {
			"title": data.get("name", "?"), "title_color": Color(1, 1, 1, 1),
			"icon_key": data.get("icon_key", "generic"), "icon_color": Color(0.85, 0.75, 0.4, 1),
			"lines": [str(data.get("desc", ""))],
		})
	else:
		_wire_inspect(row, {
			"title": "???", "title_color": Color(1, 1, 1, 0.5), "locked": true,
			"locked_text": "Not yet encountered - kill one to unlock its entry.",
		})
	return row

func _make_pet_row(id: String, data: Dictionary, rarity: String = "") -> Control:
	var owned: bool
	if rarity == "":
		owned = GameManager.owned_pets.has(id)
	else:
		owned = false
		for instance in GameManager.owned_pet_instances.values():
			if instance.get("pet_type", "") == id:
				owned = true
				break

	var built := _make_row_base()
	var row: Control = built["row"]
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.05, 0.05, 0.05, 0.9) if not owned else Color(0.1, 0.12, 0.15, 0.9)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	if owned:
		var icon = ItemIconScene.instantiate()
		icon.icon_key = data.get("icon_key", "pet_dog")
		icon.icon_color = data.get("color", Color.WHITE)
		icon.custom_minimum_size = Vector2(48, 48)
		icon_box.add_child(icon)
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 26)
		q.modulate = Color(1, 1, 1, 0.4)
		icon_box.add_child(q)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?")) if owned else "???"
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", (data.get("color", Color.WHITE) if owned else Color(1, 1, 1, 0.4)))
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	if owned:
		var stat_bits: Array = []
		if data.get("stat_type", "") != "":
			stat_bits.append("+%s %s" % [str(data.get("stat_value", 0)), data.get("stat_type", "")])
		if rarity != "":
			stat_bits.append(GameManager.get_rarity_label(rarity))
		desc_lbl.text = "  //  ".join(stat_bits) if not stat_bits.is_empty() else "A loyal companion."
	else:
		desc_lbl.text = "Not yet obtained." if rarity == "" else "Hatch a %s Egg at Salvaged Beasts to unlock." % GameManager.get_rarity_label(rarity)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8) if owned else Color(1, 1, 1, 0.45)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	if owned:
		var stat_lines: Array = []
		if data.get("stat_type", "") != "":
			stat_lines.append("+%s %s" % [str(data.get("stat_value", 0)), data.get("stat_type", "")])
		if rarity != "":
			stat_lines.append(GameManager.get_rarity_label(rarity))
		if stat_lines.is_empty():
			stat_lines.append("A loyal companion.")
		_wire_inspect(row, {
			"title": data.get("name", "?"), "title_color": data.get("color", Color.WHITE),
			"icon_key": data.get("icon_key", "pet_dog"), "icon_color": data.get("color", Color.WHITE),
			"lines": stat_lines,
		})
	else:
		_wire_inspect(row, {
			"title": "???", "title_color": Color(1, 1, 1, 0.5), "locked": true,
			"locked_text": ("Not yet obtained." if rarity == "" else "Hatch a %s Egg at Salvaged Beasts to unlock." % GameManager.get_rarity_label(rarity)),
		})
	return row

func _make_collectible_row(id: String) -> Control:
	var data: Dictionary = GameManager.COLLECTIBLE_CATALOG[id]
	var built := _make_row_base()
	var row: Control = built["row"]
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	var col: Color = data.get("color", Color.WHITE)
	icon_sb.bg_color = Color(col.r, col.g, col.b, 0.2)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "generic")
	icon.icon_color = col
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", col)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(data.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	_wire_inspect(row, {
		"title": data.get("name", "?"), "title_color": col, "dot_color": col,
		"lines": [str(data.get("desc", ""))],
	})
	return row

func _make_map_row(id: String) -> Control:
	var data: Dictionary = GameManager.MAP_CATALOG[id]
	var built := _make_row_base()
	var row: Control = built["row"]
	row.custom_minimum_size = Vector2(0, 90)
	var hbox: HBoxContainer = built["hbox"]

	var map_color: Color = data.get("color", Color(0.6, 0.9, 0.7, 1))
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(70, 70)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(map_color.r, map_color.g, map_color.b, 0.18)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "generic")
	icon.icon_color = map_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", map_color)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(data.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	_wire_inspect(row, {
		"title": data.get("name", "?"), "title_color": map_color,
		"icon_key": data.get("icon_key", ""), "icon_color": map_color, "lines": [str(data.get("desc", ""))],
	})
	return row

func _make_npc_header_row(npc_id: String) -> Control:
	var data: Dictionary = GameManager.QUEST_NPC_CATALOG.get(npc_id, {})
	var lbl := Label.new()
	lbl.text = "%s - %s" % [data.get("name", npc_id), data.get("title", "")]
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", data.get("glow_color", Color.WHITE))
	return lbl

func _make_contract_row(key: String) -> Control:
	var data: Dictionary = GameManager.QUEST_DATA.get(key, {})
	var is_done: bool = GameManager.is_quest_done(key)
	var is_locked: bool = GameManager.is_quest_locked(key)
	var built := _make_row_base()
	var row: Control = built["row"]
	row.custom_minimum_size = Vector2(0, 64)
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(44, 44)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.05, 0.05, 0.05, 0.9) if is_locked else Color(0.15, 0.12, 0.05, 0.9)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	if not is_locked:
		var icon = ItemIconScene.instantiate()
		icon.icon_key = data.get("icon", "star")
		icon.icon_color = Color(0.85, 0.75, 0.4, 1) if not is_done else Color(0.5, 0.9, 0.5, 1)
		icon.custom_minimum_size = Vector2(38, 38)
		icon_box.add_child(icon)
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 20)
		q.modulate = Color(1, 1, 1, 0.4)
		icon_box.add_child(q)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("title", key)) if not is_locked else "???"
	name_lbl.add_theme_font_size_override("font_size", 14)
	if is_done:
		name_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
	elif is_locked:
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	if is_locked:
		desc_lbl.text = "Locked - complete an earlier contract to unlock."
	else:
		desc_lbl.text = "%s  (Reward: %s)%s" % [data.get("desc", ""), data.get("reward_text", ""), "  - DONE" if is_done else ""]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.75) if not is_locked else Color(1, 1, 1, 0.4)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	if is_locked:
		_wire_inspect(row, {
			"title": "???", "title_color": Color(1, 1, 1, 0.5), "locked": true,
			"locked_text": "Locked - complete an earlier contract to unlock.",
		})
	else:
		_wire_inspect(row, {
			"title": data.get("title", key), "title_color": Color(0.6, 0.9, 0.6, 1) if is_done else Color(1, 1, 1, 1),
			"icon_key": data.get("icon", "star"), "icon_color": Color(0.85, 0.75, 0.4, 1) if not is_done else Color(0.5, 0.9, 0.5, 1),
			"lines": [
				str(data.get("desc", "")),
				"Reward: %s" % str(data.get("reward_text", "")),
			] + (["Status: Complete"] if is_done else []),
		})
	return row

func _make_trader_row(id: String) -> Control:
	var data: Dictionary = GameManager.TRADER_CATALOG.get(id, {})
	var built := _make_row_base()
	var row: Control = built["row"]
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.15, 0.15, 0.1, 0.9)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "generic")
	icon.icon_color = Color(0.9, 0.8, 0.4, 1)
	icon.custom_minimum_size = Vector2(48, 48)
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1))
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	var currency_label: String = {"rubles": "Rubles", "junk": "Junk", "artifacts": "Artifacts", "alloys": "Alloys"}.get(data.get("currency", "rubles"), "Rubles")
	desc_lbl.text = "%s  //  Deals in %s" % [str(data.get("tagline", "")), currency_label]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	_wire_inspect(row, {
		"title": data.get("name", "?"), "title_color": Color(0.9, 0.8, 0.4, 1),
		"icon_key": data.get("icon_key", "generic"), "icon_color": Color(0.9, 0.8, 0.4, 1),
		"lines": [str(data.get("tagline", "")), "Deals in %s" % currency_label],
	})
	return row

# --- Weapons tab: every named gun in WEAPON_CATALOG, deduplicated to
# one entry per weapon (not one per rarity roll) - always shows its
# real icon and name, never a "?" placeholder, since this is a
# reference compendium rather than a discovery-gated bestiary.
func _make_weapon_row(id: String) -> Control:
	var data: Dictionary = GameManager.WEAPON_CATALOG[id]
	var rarity: String = data.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var built := _make_row_base()
	var row: Control = built["row"]
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
	icon_sb.border_color = rarity_color
	icon_sb.set_border_width_all(1)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "pistol")
	icon.icon_color = rarity_color
	icon.custom_minimum_size = Vector2(48, 48)
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_row.add_child(name_lbl)
	var rarity_lbl := Label.new()
	rarity_lbl.text = GameManager.get_rarity_label(rarity)
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.modulate = Color(1, 1, 1, 0.6)
	name_row.add_child(rarity_lbl)
	info.add_child(name_row)
	var desc_lbl := Label.new()
	desc_lbl.text = str(data.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	var stat_type: String = data.get("stat_type", "damage")
	var stat_line: String = "Fire Rate Bonus: %.3f" % float(data.get("stat_value", 0.0)) if stat_type == "fire_rate" else "Damage: %d" % int(data.get("stat_value", 0.0))
	_wire_inspect(row, {
		"title": data.get("name", "?"), "title_color": rarity_color,
		"icon_key": data.get("icon_key", "pistol"), "icon_color": rarity_color,
		"rarity_label": GameManager.get_rarity_label(rarity),
		"lines": [str(data.get("desc", "")), stat_line, "Value: %d Rubles" % int(data.get("value", 0))],
		"projectile_style": data.get("icon_key", "pistol"),
	})
	return row

# --- Armor tab: every named piece of gear across the head/body/boots/
# backpack/accessory/helmet_attachment slots, same treatment as the
# Weapons tab (deduplicated, always shows its real icon and name, no
# discovery-gating). Stat line reuses ItemTooltip's own stat formatter
# so the wording matches exactly what a hover tooltip shows in-raid.
func _make_armor_row(id: String) -> Control:
	var data: Dictionary = GameManager.ARMOR_CATALOG[id]
	var rarity: String = data.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var built := _make_row_base()
	var row: Control = built["row"]
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
	icon_sb.border_color = rarity_color
	icon_sb.set_border_width_all(1)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "chestplate")
	icon.icon_color = rarity_color
	icon.custom_minimum_size = Vector2(48, 48)
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_row.add_child(name_lbl)
	var slot_lbl := Label.new()
	slot_lbl.text = "%s  //  %s" % [str(data.get("slot", "")).capitalize(), GameManager.get_rarity_label(rarity)]
	slot_lbl.add_theme_font_size_override("font_size", 11)
	slot_lbl.modulate = Color(1, 1, 1, 0.6)
	name_row.add_child(slot_lbl)
	info.add_child(name_row)
	var desc_lbl := Label.new()
	desc_lbl.text = str(data.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	var stat_line: String = ItemTooltip._format_stat(str(data.get("stat_type", "")), data.get("stat_value", 0.0))
	_wire_inspect(row, {
		"title": data.get("name", "?"), "title_color": rarity_color,
		"icon_key": data.get("icon_key", "chestplate"), "icon_color": rarity_color,
		"rarity_label": "%s  //  %s" % [str(data.get("slot", "")).capitalize(), GameManager.get_rarity_label(rarity)],
		"lines": [str(data.get("desc", ""))] + ([stat_line] if stat_line != "" else []) + ["Value: %d Rubles" % int(data.get("value", 0))],
	})
	return row

# --- Keys tab: every real door key in the game, same treatment as
# weapons - full icon and name always visible, right-click to inspect.
func _make_key_row(id: String) -> Control:
	var data: Dictionary = GameManager.KEY_CATALOG[id]
	var rarity: String = data.get("rarity", "rare")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var built := _make_row_base()
	var row: Control = built["row"]
	var hbox: HBoxContainer = built["hbox"]

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
	icon_sb.border_color = rarity_color
	icon_sb.set_border_width_all(1)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "key")
	icon.icon_color = rarity_color
	icon.custom_minimum_size = Vector2(48, 48)
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(data.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.8)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	_wire_inspect(row, {
		"title": data.get("name", "?"), "title_color": rarity_color,
		"icon_key": data.get("icon_key", "key"), "icon_color": rarity_color,
		"rarity_label": GameManager.get_rarity_label(rarity),
		"lines": [str(data.get("desc", ""))],
	})
	return row

# =====================================================================
# --- Universal Inspect system ---------------------------------------
# Every row above ends by calling _wire_inspect() with a small
# "display entry" Dictionary. That's the only thing the popup below
# needs to know about - it doesn't care whether the entry came from
# the Enemies tab or the Weapons tab, which keeps this reusable across
# every tab in the panel (and any future one) for free.
#
# Display entry schema (all keys optional except "title"):
#   title: String, title_color: Color
#   icon_key: String (drawn via ItemIcon), icon_color: Color
#   dot_color: Color (used instead of icon_key for a plain color swatch)
#   rarity_label: String (shown as a small chip under the title)
#   lines: Array[String] (description + stat lines, one per row)
#   locked: bool, locked_text: String (shown instead of lines/icon)
#   projectile_style: String (icon_key whose Bullet.gd look gets
#     previewed - only set on weapon entries)
# =====================================================================

func _make_row_clickthrough(node: Control) -> void:
	if node is Button:
		return
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_make_row_clickthrough(child)

func _wire_inspect(row: Control, entry: Dictionary) -> void:
	_make_row_clickthrough(row)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_open_context_menu(entry, event.global_position)
	)

func _build_context_menu() -> void:
	context_menu = PanelContainer.new()
	context_menu.visible = false
	context_menu.z_index = 300
	context_menu.custom_minimum_size = MENU_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.98)
	sb.border_color = Color(0.9, 0.75, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	context_menu.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	context_menu.add_child(vbox)
	var btn := Button.new()
	btn.text = "Inspect"
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_inspect_pressed)
	vbox.add_child(btn)
	add_child(context_menu)

func _open_context_menu(entry: Dictionary, click_pos: Vector2) -> void:
	_pending_inspect = entry
	var vp := get_viewport_rect().size
	context_menu.global_position = Vector2(
		clamp(click_pos.x + 8.0, 0.0, max(0.0, vp.x - MENU_SIZE.x)),
		clamp(click_pos.y + 8.0, 0.0, max(0.0, vp.y - MENU_SIZE.y))
	)
	context_menu.visible = true

func _on_inspect_pressed() -> void:
	context_menu.visible = false
	_open_inspect_popup(_pending_inspect)

# The close-up popup: a bigger icon, the full rarity-colored name, a
# rarity chip if there is one, every description/stat line, and - for
# weapons - a small preview of what that weapon's projectile actually
# looks like in a raid, drawn with the exact same colors/scale Bullet.gd
# uses so it's not just a generic placeholder.
func _open_inspect_popup(entry: Dictionary) -> void:
	if inspect_popup != null and is_instance_valid(inspect_popup):
		inspect_popup.queue_free()
	inspect_popup = PanelContainer.new()
	inspect_popup.z_index = 310
	inspect_popup.custom_minimum_size = Vector2(340, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.98)
	sb.border_color = entry.get("title_color", Color(0.9, 0.75, 0.3, 1))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	inspect_popup.add_theme_stylebox_override("panel", sb)
	inspect_popup.anchor_left = 0.5
	inspect_popup.anchor_top = 0.5
	inspect_popup.anchor_right = 0.5
	inspect_popup.anchor_bottom = 0.5
	inspect_popup.offset_left = -175
	inspect_popup.offset_right = 175

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	inspect_popup.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(84, 84)
	var icon_sb := StyleBoxFlat.new()
	var tcol: Color = entry.get("title_color", Color.WHITE)
	icon_sb.bg_color = Color(tcol.r, tcol.g, tcol.b, 0.18)
	icon_sb.border_color = tcol
	icon_sb.set_border_width_all(1)
	icon_sb.set_corner_radius_all(6)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	if entry.has("dot_color"):
		var dot := ColorRect.new()
		dot.color = entry["dot_color"]
		dot.custom_minimum_size = Vector2(30, 30)
		dot.anchor_left = 0.5
		dot.anchor_top = 0.5
		dot.anchor_right = 0.5
		dot.anchor_bottom = 0.5
		dot.offset_left = -15
		dot.offset_top = -15
		dot.offset_right = 15
		dot.offset_bottom = 15
		icon_box.add_child(dot)
	elif str(entry.get("icon_key", "")) != "":
		var icon = ItemIconScene.instantiate()
		icon.icon_key = entry.get("icon_key", "generic")
		icon.icon_color = tcol
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.add_child(icon)
	header.add_child(icon_box)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_col)
	var title_lbl := Label.new()
	title_lbl.text = str(entry.get("title", "?"))
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_lbl.add_theme_color_override("font_color", tcol)
	name_col.add_child(title_lbl)
	if str(entry.get("rarity_label", "")) != "":
		var rarity_chip := Label.new()
		rarity_chip.text = str(entry["rarity_label"])
		rarity_chip.add_theme_font_size_override("font_size", 13)
		rarity_chip.modulate = Color(1, 1, 1, 0.7)
		name_col.add_child(rarity_chip)

	if entry.get("locked", false):
		var locked_lbl := Label.new()
		locked_lbl.text = str(entry.get("locked_text", "Not yet unlocked."))
		locked_lbl.add_theme_font_size_override("font_size", 13)
		locked_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		locked_lbl.modulate = Color(1, 1, 1, 0.6)
		vbox.add_child(locked_lbl)
	else:
		for line in entry.get("lines", []):
			var line_lbl := Label.new()
			line_lbl.text = str(line)
			line_lbl.add_theme_font_size_override("font_size", 13)
			line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			line_lbl.modulate = Color(1, 1, 1, 0.85)
			vbox.add_child(line_lbl)

	var projectile_style: String = str(entry.get("projectile_style", ""))
	if projectile_style != "":
		var proj_lbl := Label.new()
		proj_lbl.text = "Projectile"
		proj_lbl.add_theme_font_size_override("font_size", 12)
		proj_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
		vbox.add_child(proj_lbl)
		var proj_box := PanelContainer.new()
		proj_box.custom_minimum_size = Vector2(0, 46)
		var proj_sb := StyleBoxFlat.new()
		proj_sb.bg_color = Color(0.03, 0.03, 0.04, 0.9)
		proj_sb.set_corner_radius_all(6)
		proj_box.add_theme_stylebox_override("panel", proj_sb)
		proj_box.add_child(_build_projectile_preview(projectile_style))
		vbox.add_child(proj_box)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.pressed.connect(func():
		inspect_popup.visible = false
		inspect_popup.queue_free()
	)
	vbox.add_child(close_btn)

	add_child(inspect_popup)

# A static stand-in for the bullet each weapon style fires, matching
# Bullet.gd's own per-style modulate/scale so this is an honest preview
# of what you'll actually see in a raid, not a generic placeholder.
func _build_projectile_preview(style: String) -> Control:
	var preview_wrap := Control.new()
	preview_wrap.custom_minimum_size = Vector2(0, 46)
	preview_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_size := Vector2(22, 8)
	var color := Color(1, 1, 1, 1)
	match style:
		"rifle":
			color = Color(0.85, 0.85, 0.8, 1)
			base_size = Vector2(26, 7)
		"flamethrower":
			color = Color(1.0, 0.5, 0.15, 0.9)
			base_size = Vector2(34, 20)
		"thorn":
			color = Color(0.4, 0.85, 0.25, 1)
			base_size = Vector2(20, 7)
		"railgun":
			color = Color(1.0, 0.95, 0.35, 1)
			base_size = Vector2(38, 9)
		"sniper":
			color = Color(0.55, 0.85, 1.0, 1)
			base_size = Vector2(30, 7)
		"shotgun":
			color = Color(1.0, 0.8, 0.4, 1)
			base_size = Vector2(12, 6)
		"pistol":
			color = Color(1.0, 0.95, 0.75, 1)
			base_size = Vector2(18, 7)
		"alpha_cannon":
			color = Color(1.0, 0.85, 0.3, 1)
			base_size = Vector2(36, 16)
		_:
			color = Color(1, 1, 1, 1)
			base_size = Vector2(20, 8)

	var shape := ColorRect.new()
	shape.color = color
	shape.custom_minimum_size = base_size
	shape.anchor_left = 0.5
	shape.anchor_top = 0.5
	shape.anchor_right = 0.5
	shape.anchor_bottom = 0.5
	shape.offset_left = -base_size.x / 2.0
	shape.offset_top = -base_size.y / 2.0
	shape.offset_right = base_size.x / 2.0
	shape.offset_bottom = base_size.y / 2.0
	preview_wrap.add_child(shape)

	if style == "shotgun":
		# Shotguns fire 5 pellets in a spread, not one bullet - show
		# that instead of a single misleadingly-large pellet.
		shape.queue_free()
		for i in range(5):
			var pellet := ColorRect.new()
			pellet.color = color
			pellet.custom_minimum_size = Vector2(8, 8)
			pellet.anchor_left = 0.5
			pellet.anchor_top = 0.5
			pellet.anchor_right = 0.5
			pellet.anchor_bottom = 0.5
			var off_x: float = -60.0 + i * 30.0
			var off_y: float = (i - 2) * 4.0
			pellet.offset_left = off_x - 4
			pellet.offset_top = off_y - 4
			pellet.offset_right = off_x + 4
			pellet.offset_bottom = off_y + 4
			preview_wrap.add_child(pellet)

	return preview_wrap
