extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# A purely cosmetic, simulated "looking for group" browser - same spirit
# as Global Chat's bot roster (this game has no real matchmaking backend
# to hook into), pulled from the same leaderboard bot pool so the same
# names/gear/ranks you see in chat and on the board show up here too.
# Groups spawn, gain/lose members, occasionally give up and vanish, and
# occasionally fill up and head out - the goal is a list that feels like
# it's alive and moving even if you just sit and watch it.

signal closed

const MAX_VISIBLE_GROUPS := 7
const TICK_SECONDS := 1.0
const GROUP_SIZE_WEIGHTS := [2, 2, 3, 4, 4]  # more small squads than big ones, weighted by repetition

@onready var group_list: VBoxContainer = $VBox/GroupScroll/GroupList
@onready var close_button: Button = $VBox/CloseButton

var _groups: Array = []          # Array of group Dictionaries (the data model)
var _rows: Dictionary = {}       # group id -> row node refs (Dictionary of Controls)
var _next_id: int = 1
var _tick_accum: float = 0.0
var _spawn_timer: float = 0.0
var _next_spawn_delay: float = 2.0

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	_clear_all()
	_next_spawn_delay = randf_range(1.0, 2.5)
	_spawn_timer = 0.0
	_tick_accum = 0.0
	for i in range(randi_range(3, 5)):
		_spawn_group()
	set_process(true)

func _exit_tree() -> void:
	set_process(false)

func _clear_all() -> void:
	for c in group_list.get_children():
		c.queue_free()
	_groups.clear()
	_rows.clear()

func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn_delay:
		_spawn_timer = 0.0
		_next_spawn_delay = randf_range(2.5, 6.0)
		if _groups.size() < MAX_VISIBLE_GROUPS:
			_spawn_group()

	_tick_accum += delta
	if _tick_accum >= TICK_SECONDS:
		_tick_accum -= TICK_SECONDS
		_tick()

# ------------------------------------------------------------------
# Simulation
# ------------------------------------------------------------------

func _tick() -> void:
	var to_remove: Array = []
	for g in _groups:
		if g["joining_countdown"] > 0:
			g["joining_countdown"] -= 1
			if g["joining_countdown"] <= 0:
				to_remove.append(g)
				if g.get("player_joined", false):
					GameManager.toast_requested.emit("Squad ready! Heading into %s..." % GameManager.MAP_CATALOG.get(g["map_id"], {}).get("name", "the Sector"))
				continue
			_refresh_row_status(g)
			continue

		# Not yet full - a small chance each second that someone joins
		# or (less often) someone leaves, and a much smaller chance the
		# whole thing just falls apart before it ever filled.
		var roll := randf()
		if roll < 0.16 and g["members"].size() < g["max"]:
			_group_gain_member(g)
			if g["members"].size() >= g["max"]:
				g["joining_countdown"] = 5
			_refresh_row(g)
		elif roll < 0.20 and g["members"].size() > 1:
			_group_lose_member(g)
			_refresh_row(g)
		elif roll < 0.225 and not g.get("player_joined", false):
			to_remove.append(g)

	for g in to_remove:
		_remove_group(g)

func _group_gain_member(g: Dictionary) -> void:
	var pool: Array = GameManager.get_ranked_leaderboard().filter(func(e): return not e.get("is_player", false))
	var existing_names: Array = g["members"].map(func(m): return m.get("name", ""))
	pool.shuffle()
	for cand in pool:
		if not existing_names.has(cand.get("name", "")):
			g["members"].append({"name": cand.get("name", "?"), "portrait": cand.get("portrait", "portrait_1")})
			return

func _group_lose_member(g: Dictionary) -> void:
	# Never removes the leader (index 0) or the player themselves.
	var removable: Array = []
	for i in range(1, g["members"].size()):
		if not g["members"][i].get("is_player", false):
			removable.append(i)
	if removable.is_empty():
		return
	g["members"].remove_at(removable[randi() % removable.size()])

func _spawn_group() -> void:
	var pool: Array = GameManager.get_ranked_leaderboard().filter(func(e): return not e.get("is_player", false))
	if pool.is_empty():
		return
	var leader: Dictionary = pool[randi() % pool.size()]
	var max_size: int = GROUP_SIZE_WEIGHTS[randi() % GROUP_SIZE_WEIGHTS.size()]
	var start_size: int = randi_range(1, max(1, max_size - 1))
	var map_ids: Array = GameManager.MAP_CATALOG.keys()
	var g := {
		"id": _next_id, "leader": leader, "map_id": map_ids[randi() % map_ids.size()],
		"max": max_size, "members": [{"name": leader.get("name", "?"), "portrait": leader.get("portrait", "portrait_1")}],
		"joining_countdown": 0, "player_joined": false,
	}
	_next_id += 1
	var pool2: Array = pool.duplicate()
	pool2.shuffle()
	for cand in pool2:
		if g["members"].size() >= start_size:
			break
		if cand.get("name", "") != leader.get("name", ""):
			g["members"].append({"name": cand.get("name", "?"), "portrait": cand.get("portrait", "portrait_1")})
	_groups.append(g)
	_add_row(g)

func _remove_group(g: Dictionary) -> void:
	var row: Dictionary = _rows.get(g["id"], {})
	if row.has("card") and is_instance_valid(row["card"]):
		group_list.remove_child(row["card"])
		row["card"].queue_free()
	_rows.erase(g["id"])
	_groups.erase(g)

func _on_join_pressed(group_id: int) -> void:
	var g: Dictionary = {}
	for candidate in _groups:
		if candidate["id"] == group_id:
			g = candidate
			break
	if g.is_empty() or g.get("player_joined", false) or g["members"].size() >= g["max"]:
		return
	g["player_joined"] = true
	g["members"].append({"name": GameManager.player_name if GameManager.player_name != "" else "You", "portrait": GameManager.player_portrait_id if GameManager.player_portrait_id != "" else "portrait_1", "is_player": true})
	Sfx.play_coin_hover()
	if g["members"].size() >= g["max"]:
		g["joining_countdown"] = 5
	_refresh_row(g)

# ------------------------------------------------------------------
# Row UI
# ------------------------------------------------------------------

func _add_row(g: Dictionary) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.09, 0.85)
	sb.border_color = Color(0.3, 0.3, 0.35, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Header: map icon + name (left), leader's Rank (right).
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var map_data: Dictionary = GameManager.MAP_CATALOG.get(g["map_id"], {})
	var map_icon_holder := Control.new()
	map_icon_holder.custom_minimum_size = Vector2(18, 18)
	var map_icon = ItemIconScene.instantiate()
	map_icon.icon_key = str(map_data.get("icon_key", "generic"))
	map_icon.icon_color = map_data.get("color", Color.WHITE)
	map_icon.anchor_right = 1.0
	map_icon.anchor_bottom = 1.0
	map_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_icon_holder.add_child(map_icon)
	header.add_child(map_icon_holder)

	var map_lbl := Label.new()
	map_lbl.text = str(map_data.get("name", "Unknown"))
	map_lbl.add_theme_font_size_override("font_size", 13)
	map_lbl.add_theme_color_override("font_color", map_data.get("color", Color.WHITE))
	header.add_child(map_lbl)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var leader: Dictionary = g["leader"]
	var rank_idx: int = int(leader.get("rank_full_idx", 0))
	var rank_tier: Dictionary = GameManager.get_rank_tier(rank_idx)
	var rank_lbl := Label.new()
	rank_lbl.text = GameManager.get_rank_display_name(rank_idx)
	rank_lbl.add_theme_font_size_override("font_size", 12)
	rank_lbl.add_theme_color_override("font_color", rank_tier.get("color", Color.WHITE))
	header.add_child(rank_lbl)

	# Squad name (left) + Level (right).
	var info_row := HBoxContainer.new()
	vbox.add_child(info_row)
	var name_lbl := Label.new()
	name_lbl.text = "%s's Squad" % str(leader.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1))
	info_row.add_child(name_lbl)
	var info_spacer := Control.new()
	info_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(info_spacer)
	var level_lbl := Label.new()
	level_lbl.text = "Level %d" % int(leader.get("level", 1))
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.modulate = Color(1, 1, 1, 0.75)
	info_row.add_child(level_lbl)

	# Member slots (left) + leader's loadout preview (right).
	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 4)
	vbox.add_child(mid_row)
	var member_holder := HBoxContainer.new()
	member_holder.add_theme_constant_override("separation", 3)
	mid_row.add_child(member_holder)
	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_row.add_child(mid_spacer)
	var loadout_holder := HBoxContainer.new()
	loadout_holder.add_theme_constant_override("separation", 3)
	mid_row.add_child(loadout_holder)
	var gear: Dictionary = leader.get("gear", {})
	var shown := 0
	for slot_name in gear:
		if shown >= 4:
			break
		var gitem = gear[slot_name]
		if gitem == null:
			continue
		var rarity: String = str(gitem.get("rarity", "common"))
		var slot_box := PanelContainer.new()
		slot_box.custom_minimum_size = Vector2(24, 24)
		var slot_sb := StyleBoxFlat.new()
		slot_sb.bg_color = Color(0.12, 0.12, 0.12, 0.9)
		slot_sb.border_color = GameManager.get_rarity_color(rarity)
		slot_sb.set_border_width_all(2)
		slot_sb.set_corner_radius_all(3)
		slot_box.add_theme_stylebox_override("panel", slot_sb)
		slot_box.tooltip_text = "%s (%s)" % [str(slot_name).capitalize(), GameManager.get_rarity_label(rarity)]
		var gicon = ItemIconScene.instantiate()
		gicon.icon_key = str(gitem.get("icon_key", "generic"))
		gicon.icon_color = GameManager.get_rarity_color(rarity)
		gicon.anchor_right = 1.0
		gicon.anchor_bottom = 1.0
		gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_box.add_child(gicon)
		loadout_holder.add_child(slot_box)
		shown += 1

	# Status text (left) + Join Group button (right).
	var status_row := HBoxContainer.new()
	vbox.add_child(status_row)
	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_lbl)
	var join_btn := Button.new()
	join_btn.text = "Join Group"
	join_btn.custom_minimum_size = Vector2(100, 28)
	join_btn.add_theme_font_size_override("font_size", 11)
	var gid: int = g["id"]
	join_btn.pressed.connect(func(): _on_join_pressed(gid))
	status_row.add_child(join_btn)

	group_list.add_child(card)
	_rows[g["id"]] = {"card": card, "member_holder": member_holder, "status_label": status_lbl, "join_button": join_btn}
	_refresh_row(g)

# Rebuilds just the member-slot icons (filled + empty) and the status
# row - called whenever a group's roster or countdown actually changes,
# not the whole card, so a full raid lobby list ticking every second
# doesn't mean rebuilding everything on screen every second.
func _refresh_row(g: Dictionary) -> void:
	var row = _rows.get(g["id"], null)
	if row == null:
		return
	var member_holder: HBoxContainer = row["member_holder"]
	for c in member_holder.get_children():
		member_holder.remove_child(c)
		c.queue_free()
	for i in range(g["max"]):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(20, 20)
		if i < g["members"].size():
			var m: Dictionary = g["members"][i]
			var portrait = PortraitScene.instantiate()
			portrait.trader_id = str(m.get("portrait", "portrait_1"))
			portrait.anchor_right = 1.0
			portrait.anchor_bottom = 1.0
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(portrait)
			slot.tooltip_text = str(m.get("name", "?")) + (" (You)" if m.get("is_player", false) else "")
		else:
			var empty := ColorRect.new()
			empty.color = Color(1, 1, 1, 0.08)
			empty.anchor_right = 1.0
			empty.anchor_bottom = 1.0
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(empty)
		member_holder.add_child(slot)
	_refresh_row_status(g)

func _refresh_row_status(g: Dictionary) -> void:
	var row = _rows.get(g["id"], null)
	if row == null:
		return
	var status_lbl: Label = row["status_label"]
	var join_btn: Button = row["join_button"]
	var current: int = g["members"].size()
	var maxc: int = g["max"]
	if g["joining_countdown"] > 0:
		status_lbl.text = "%d/%d - Joining raid in %d..." % [current, maxc, int(g["joining_countdown"])]
		status_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55, 1))
		join_btn.visible = false
	else:
		status_lbl.text = "%d/%d - Waiting for others to join..." % [current, maxc]
		status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		join_btn.visible = not g.get("player_joined", false) and current < maxc
