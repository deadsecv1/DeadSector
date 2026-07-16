extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed
signal rewards_requested
signal ranks_requested

const CATEGORY_LABELS := {"score": "Score", "kills": "Kills", "pets": "Pets Owned", "stash_worth": "Stash Worth", "extractions": "Extractions", "level": "Level", "arena": "Arena"}
const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

@onready var list: VBoxContainer = $VBox/ListScroll/List
@onready var list_scroll: ScrollContainer = $VBox/ListScroll
@onready var tab_row: HBoxContainer = $VBox/TabRow
@onready var rewards_button: Button = $VBox/TitleRow/RewardsButton
@onready var ranks_button: Button = $VBox/TitleRow/RanksButton
@onready var close_button: Button = $VBox/CloseButton

var current_category: String = "score"
var tab_buttons: Dictionary = {}

# --- Context menu (right side popup: Info / Add Friend / Invite to
# Party / Whisper / Block) and the Info profile popup, both built once
# and reused/repositioned rather than rebuilt per click.
var context_menu: PanelContainer
var context_entry: Dictionary = {}
var profile_popup: PanelContainer

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	rewards_button.pressed.connect(func(): rewards_requested.emit())
	ranks_button.pressed.connect(func(): ranks_requested.emit())
	for category in GameManager.LEADERBOARD_CATEGORIES:
		var btn := Button.new()
		btn.text = CATEGORY_LABELS.get(category, category.capitalize())
		btn.custom_minimum_size = Vector2(86, 34)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): _switch_category(category))
		tab_row.add_child(btn)
		tab_buttons[category] = btn
	var ranked_tab_btn := Button.new()
	ranked_tab_btn.text = "Ranked"
	ranked_tab_btn.custom_minimum_size = Vector2(86, 34)
	ranked_tab_btn.add_theme_font_size_override("font_size", 12)
	ranked_tab_btn.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3, 1))
	ranked_tab_btn.add_theme_color_override("font_disabled_color", Color(0.95, 0.8, 0.3, 1))
	ranked_tab_btn.pressed.connect(func(): _switch_category("ranked"))
	tab_row.add_child(ranked_tab_btn)
	tab_buttons["ranked"] = ranked_tab_btn
	_build_context_menu()

func open() -> void:
	visible = true
	_switch_category("score")
	GameManager.focus_first_control(self)

func _switch_category(category: String) -> void:
	current_category = category
	for cat in tab_buttons:
		tab_buttons[cat].disabled = (cat == category)
	refresh()

func refresh() -> void:
	if context_menu != null:
		context_menu.visible = false
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var player_row: Control = null
	if current_category == "ranked":
		var ranked_entries := GameManager.get_ranked_leaderboard()
		for i in range(ranked_entries.size()):
			var row := _make_ranked_row(ranked_entries[i], i + 1)
			list.add_child(row)
			if ranked_entries[i].get("is_player", false):
				player_row = row
		_scroll_to_row(player_row)
		return
	var entries := GameManager.get_leaderboard(current_category)
	for i in range(entries.size()):
		var row := _make_row(entries[i], i + 1)
		list.add_child(row)
		if entries[i].get("is_player", false):
			player_row = row
	_scroll_to_row(player_row)

# Your own row is highlighted, but that's no use if it's scrolled off
# the bottom of a long list and never actually seen - center it in
# view the moment the list refreshes.
func _scroll_to_row(row: Control) -> void:
	if row == null:
		return
	await get_tree().process_frame
	var target: float = row.position.y - (list_scroll.size.y / 2.0) + (row.size.y / 2.0)
	list_scroll.scroll_vertical = int(clamp(target, 0, max(0, list.size.y - list_scroll.size.y)))

func _make_row(entry: Dictionary, rank: int) -> Control:
	var is_player: bool = entry.get("is_player", false)
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 44)
	# flat still applies to every other row (no default button chrome
	# competing with the list's own dark background), but Godot doesn't
	# actually draw a flat button's stylebox override at all - it was
	# quietly no-opping the whole point of this being your own row: the
	# gold background/border below was configured correctly the entire
	# time, it just never rendered.
	row.flat = not is_player
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	# Your own row gets a much stronger highlight than before - a solid,
	# saturated gold background and a thicker border, so it actually
	# jumps out while scanning a long list instead of blending in.
	sb.bg_color = Color(0.6, 0.46, 0.08, 0.85) if is_player else Color(0.1, 0.1, 0.1, 0.6)
	sb.border_color = Color(1.0, 0.85, 0.35, 1) if is_player else Color(0.3, 0.3, 0.3, 0.5)
	sb.set_border_width_all(3 if is_player else 1)
	sb.set_corner_radius_all(4)
	row.add_theme_stylebox_override("normal", sb)
	row.add_theme_stylebox_override("hover", sb)
	row.add_theme_stylebox_override("pressed", sb)
	row.pressed.connect(func(): _open_context_menu(entry, rank, get_global_mouse_position()))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 8
	hbox.offset_right = -8
	row.add_child(hbox)

	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.custom_minimum_size = Vector2(40, 0)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", 14)
	rank_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1) if rank <= 3 else Color(1, 1, 1, 0.7))
	hbox.add_child(rank_lbl)

	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(34, 34)
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait = PortraitScene.instantiate()
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.trader_id = str(entry.get("portrait", "portrait_1"))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	hbox.add_child(portrait_box)

	var name_lbl := Label.new()
	name_lbl.text = str(entry.get("name", "?")) + ("  (You)" if is_player else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1) if is_player else Color(1, 1, 1, 0.85))
	hbox.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = "%d" % int(entry.get("value", 0))
	value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 14)
	value_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	hbox.add_child(value_lbl)

	return row

# Same row shell as _make_row (same context-menu-on-click, same
# highlight-if-you), but the trailing column is the actual rank icon +
# display name (e.g. "Scavenger 2") instead of a bare number - this is
# the whole point of a Ranked-specific tab.
func _make_ranked_row(entry: Dictionary, rank: int) -> Control:
	var is_player: bool = entry.get("is_player", false)
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.flat = not is_player
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	# Your own row gets a much stronger highlight than before - a solid,
	# saturated gold background and a thicker border, so it actually
	# jumps out while scanning a long list instead of blending in.
	sb.bg_color = Color(0.6, 0.46, 0.08, 0.85) if is_player else Color(0.1, 0.1, 0.1, 0.6)
	sb.border_color = Color(1.0, 0.85, 0.35, 1) if is_player else Color(0.3, 0.3, 0.3, 0.5)
	sb.set_border_width_all(3 if is_player else 1)
	sb.set_corner_radius_all(4)
	row.add_theme_stylebox_override("normal", sb)
	row.add_theme_stylebox_override("hover", sb)
	row.add_theme_stylebox_override("pressed", sb)
	row.pressed.connect(func(): _open_context_menu(entry, rank, get_global_mouse_position()))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 8
	hbox.offset_right = -8
	row.add_child(hbox)

	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.custom_minimum_size = Vector2(40, 0)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", 14)
	rank_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1) if rank <= 3 else Color(1, 1, 1, 0.7))
	hbox.add_child(rank_lbl)

	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(34, 34)
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait = PortraitScene.instantiate()
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.trader_id = str(entry.get("portrait", "portrait_1"))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	hbox.add_child(portrait_box)

	var name_lbl := Label.new()
	name_lbl.text = str(entry.get("name", "?")) + ("  (You)" if is_player else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1) if is_player else Color(1, 1, 1, 0.85))
	hbox.add_child(name_lbl)

	var rank_full_idx: int = int(entry.get("rank_full_idx", 0))
	var tier: Dictionary = GameManager.get_rank_tier(rank_full_idx)
	var tier_color: Color = tier.get("color", Color.WHITE)

	var rank_icon_box := Control.new()
	rank_icon_box.custom_minimum_size = Vector2(26, 26)
	var rank_icon = SmallIconScene.instantiate()
	rank_icon.icon_type = tier.get("icon", "star")
	rank_icon.icon_bg = Color(tier_color.r * 0.3, tier_color.g * 0.3, tier_color.b * 0.3, 1)
	rank_icon.anchor_right = 1.0
	rank_icon.anchor_bottom = 1.0
	rank_icon_box.add_child(rank_icon)
	hbox.add_child(rank_icon_box)

	var rank_name_lbl := Label.new()
	rank_name_lbl.text = GameManager.get_rank_display_name(rank_full_idx)
	rank_name_lbl.custom_minimum_size = Vector2(90, 0)
	rank_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_name_lbl.add_theme_font_size_override("font_size", 13)
	rank_name_lbl.add_theme_color_override("font_color", tier_color)
	hbox.add_child(rank_name_lbl)

	var points_lbl := Label.new()
	points_lbl.text = "%d pts" % int(entry.get("value", 0))
	points_lbl.custom_minimum_size = Vector2(64, 0)
	points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points_lbl.add_theme_font_size_override("font_size", 13)
	points_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	hbox.add_child(points_lbl)

	return row

# --- Right-click-style context menu (Info / Add Friend / Invite to
# Party / Whisper / Block), opened on a left-click on any row since
# these are Buttons (not raw rows), matching how the row itself is
# already the clickable element.
func _build_context_menu() -> void:
	context_menu = PanelContainer.new()
	context_menu.visible = false
	context_menu.z_index = 300
	context_menu.custom_minimum_size = Vector2(160, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.98)
	sb.border_color = Color(0.9, 0.75, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	context_menu.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	context_menu.add_child(vbox)

	var options := [
		["Info", "_on_context_info"],
		["Add Friend", "_on_context_unavailable"],
		["Invite to Party", "_on_context_unavailable"],
		["Whisper", "_on_context_unavailable"],
		["Block", "_on_context_unavailable"],
	]
	for opt in options:
		var btn := Button.new()
		btn.text = opt[0]
		btn.flat = true
		btn.custom_minimum_size = Vector2(0, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(Callable(self, opt[1]))
		vbox.add_child(btn)

	add_child(context_menu)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif context_menu != null and context_menu.visible and event is InputEventMouseButton and event.pressed:
		if not context_menu.get_global_rect().has_point(event.global_position):
			context_menu.visible = false

func _open_context_menu(entry: Dictionary, _rank: int, click_pos: Vector2) -> void:
	context_entry = entry
	var vp := get_viewport_rect().size
	var menu_size := Vector2(160, 190)
	context_menu.global_position = Vector2(
		clamp(click_pos.x + 12.0, 0.0, max(0.0, vp.x - menu_size.x)),
		clamp(click_pos.y + 12.0, 0.0, max(0.0, vp.y - menu_size.y))
	)
	context_menu.visible = true
	GameManager.focus_first_control(context_menu)

func _on_context_unavailable() -> void:
	context_menu.visible = false
	GameManager.toast_requested.emit("Multiplayer's coming soon - friends, parties, whispers, and blocking will work once it's live.")

func _on_context_info() -> void:
	context_menu.visible = false
	_open_profile_popup(context_entry)

# --- Info popup: a full simulated profile - level, title, badges,
# equipped gear (with rarity color), and a KD read-out.
func _open_profile_popup(entry: Dictionary) -> void:
	if profile_popup != null and is_instance_valid(profile_popup):
		profile_popup.queue_free()
	profile_popup = PanelContainer.new()
	profile_popup.z_index = 310
	profile_popup.custom_minimum_size = Vector2(320, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.98)
	sb.border_color = Color(0.9, 0.75, 0.3, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	profile_popup.add_theme_stylebox_override("panel", sb)
	profile_popup.anchor_left = 0.5
	profile_popup.anchor_top = 0.5
	profile_popup.anchor_right = 0.5
	profile_popup.anchor_bottom = 0.5
	profile_popup.offset_left = -160
	profile_popup.offset_right = 160

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	profile_popup.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)
	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(64, 64)
	var portrait = PortraitScene.instantiate()
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.trader_id = str(entry.get("portrait", "portrait_1"))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	header.add_child(portrait_box)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_col)
	var name_lbl := Label.new()
	name_lbl.text = str(entry.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1))
	name_col.add_child(name_lbl)
	var title_text: String = str(entry.get("title", ""))
	if title_text != "":
		var title_lbl := Label.new()
		title_lbl.text = title_text
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.modulate = Color(0.75, 0.85, 1.0, 1)
		name_col.add_child(title_lbl)
	var level_lbl := Label.new()
	level_lbl.text = "Level %d" % int(entry.get("level", 1))
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.modulate = Color(1, 1, 1, 0.7)
	name_col.add_child(level_lbl)

	var kills: int = int(entry.get("kills", 0))
	var deaths: int = max(1, int(entry.get("deaths", 1)))
	var kd_lbl := Label.new()
	kd_lbl.text = "K/D: %d / %d  (%.2f)" % [kills, deaths, float(kills) / float(deaths)]
	kd_lbl.add_theme_font_size_override("font_size", 13)
	kd_lbl.modulate = Color(0.7, 0.9, 0.7, 1)
	vbox.add_child(kd_lbl)

	var pets_lbl := Label.new()
	pets_lbl.text = "Pets Owned: %d" % int(entry.get("pets", 0))
	pets_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(pets_lbl)

	var badges: Array = entry.get("badges", [])
	if not badges.is_empty():
		var badge_lbl := Label.new()
		badge_lbl.text = "Badges"
		badge_lbl.add_theme_font_size_override("font_size", 13)
		badge_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1))
		vbox.add_child(badge_lbl)
		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 6)
		vbox.add_child(badge_row)
		for badge_id in GameManager.sort_badges_by_priority(badges):
			var bdata: Dictionary = GameManager.BADGE_CATALOG.get(badge_id, {})
			var bcol: Color = bdata.get("color", Color.WHITE)
			var is_priority: bool = GameManager.PRIORITY_BADGE_IDS.has(badge_id)
			var badge_box := PanelContainer.new()
			badge_box.custom_minimum_size = Vector2(28, 28)
			badge_box.pivot_offset = Vector2(14, 14)
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color(bcol.r, bcol.g, bcol.b, 0.2)
			if is_priority:
				bsb.border_color = Color(1.0, 0.85, 0.35, 1)
				bsb.set_border_width_all(2)
			else:
				bsb.border_color = bcol
				bsb.set_border_width_all(1)
			bsb.set_corner_radius_all(14)
			badge_box.add_theme_stylebox_override("panel", bsb)
			var bicon = SmallIconScene.instantiate()
			bicon.icon_type = bdata.get("icon", "star")
			bicon.icon_bg = bcol * 0.3
			bicon.anchor_right = 1.0
			bicon.anchor_bottom = 1.0
			bicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_box.add_child(bicon)
			badge_box.tooltip_text = str(bdata.get("name", badge_id))
			if is_priority:
				var pulse_tw := badge_box.create_tween()
				pulse_tw.bind_node(badge_box)
				pulse_tw.set_loops()
				pulse_tw.tween_property(badge_box, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
				pulse_tw.tween_property(badge_box, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
			badge_row.add_child(badge_box)

	var gear: Dictionary = entry.get("gear", {})
	if not gear.is_empty():
		var gear_lbl := Label.new()
		gear_lbl.text = "Equipped Gear"
		gear_lbl.add_theme_font_size_override("font_size", 13)
		gear_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1))
		vbox.add_child(gear_lbl)
		var gear_grid := GridContainer.new()
		gear_grid.columns = 6
		gear_grid.add_theme_constant_override("h_separation", 4)
		gear_grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(gear_grid)
		for slot in gear:
			var item = gear[slot]
			if item == null:
				continue
			var rarity: String = str(item.get("rarity", "common"))
			var slot_box := PanelContainer.new()
			slot_box.custom_minimum_size = Vector2(38, 38)
			var slot_sb := StyleBoxFlat.new()
			slot_sb.bg_color = Color(0.12, 0.12, 0.12, 0.9)
			slot_sb.border_color = GameManager.get_rarity_color(rarity)
			slot_sb.set_border_width_all(2)
			slot_sb.set_corner_radius_all(4)
			slot_box.add_theme_stylebox_override("panel", slot_sb)
			slot_box.tooltip_text = "%s (%s)" % [str(slot).capitalize(), GameManager.get_rarity_label(rarity)]
			var gicon = ItemIconScene.instantiate()
			gicon.icon_key = str(item.get("icon_key", "generic"))
			gicon.icon_color = GameManager.get_rarity_color(rarity)
			gicon.anchor_right = 1.0
			gicon.anchor_bottom = 1.0
			gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_box.add_child(gicon)
			gear_grid.add_child(slot_box)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.pressed.connect(func():
		profile_popup.visible = false
		profile_popup.queue_free()
	)
	vbox.add_child(close_btn)

	add_child(profile_popup)
