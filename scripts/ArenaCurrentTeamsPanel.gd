extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# Shows both rosters for the current Arena match (GameManager.
# current_arena_match, rolled by Matchmake) - Team 1 in blue (always
# the player's own team), Team 2 in red, each member's Arena Rank,
# level, equipped gear, and title/badges. Opened from Lilly, inside
# The Grid.

signal closed

@onready var team1_list: VBoxContainer = $VBox/TeamsRow/Team1Col/Team1Scroll/Team1List
@onready var team2_list: VBoxContainer = $VBox/TeamsRow/Team2Col/Team2Scroll/Team2List
@onready var close_button: Button = $VBox/CloseButton

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
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -320.0
	offset_top = -260.0
	offset_right = 320.0
	offset_bottom = 260.0
	refresh()

func refresh() -> void:
	for c in team1_list.get_children():
		c.queue_free()
	for c in team2_list.get_children():
		c.queue_free()
	var match_data: Dictionary = GameManager.current_arena_match
	for member in match_data.get("team1", []):
		team1_list.add_child(_make_member_card(member, Color(0.35, 0.55, 0.95, 1)))
	for member in match_data.get("team2", []):
		team2_list.add_child(_make_member_card(member, Color(0.95, 0.35, 0.3, 1)))

func _make_member_card(member: Dictionary, team_color: Color) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	sb.border_color = team_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(36, 36)
	var portrait = PortraitScene.instantiate()
	portrait.trader_id = str(member.get("portrait", "portrait_1"))
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait_box.add_child(portrait)
	header.add_child(portrait_box)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_col)
	var name_lbl := Label.new()
	name_lbl.text = str(member.get("name", "?")) + (" (You)" if member.get("is_player", false) else "")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_col.add_child(name_lbl)
	var rank_lbl := Label.new()
	rank_lbl.text = "%s  •  Level %d" % [str(member.get("arena_rank", "?")), int(member.get("level", 1))]
	rank_lbl.add_theme_font_size_override("font_size", 11)
	rank_lbl.add_theme_color_override("font_color", member.get("arena_color", Color.WHITE))
	name_col.add_child(rank_lbl)

	var title_text: String = str(member.get("title", ""))
	if title_text != "":
		var title_lbl := Label.new()
		title_lbl.text = title_text
		title_lbl.add_theme_font_size_override("font_size", 10)
		title_lbl.modulate = Color(0.75, 0.85, 1.0, 1)
		vbox.add_child(title_lbl)

	var gear: Dictionary = member.get("gear", {})
	var shown := 0
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 3)
	for slot_name in gear:
		if shown >= 6:
			break
		var gitem = gear[slot_name]
		if gitem == null:
			continue
		var rarity: String = str(gitem.get("rarity", "common"))
		var slot_box := PanelContainer.new()
		slot_box.custom_minimum_size = Vector2(22, 22)
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
		gear_row.add_child(slot_box)
		shown += 1
	if shown > 0:
		vbox.add_child(gear_row)

	var badges: Array = member.get("badges", [])
	if not badges.is_empty():
		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 3)
		for badge_id in GameManager.sort_badges_by_priority(badges).slice(0, 6):
			var bdata: Dictionary = GameManager.BADGE_CATALOG.get(badge_id, {})
			var bcol: Color = bdata.get("color", Color.WHITE)
			var badge_box := PanelContainer.new()
			badge_box.custom_minimum_size = Vector2(20, 20)
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color(bcol.r, bcol.g, bcol.b, 0.2)
			bsb.border_color = bcol
			bsb.set_border_width_all(1)
			bsb.set_corner_radius_all(10)
			badge_box.add_theme_stylebox_override("panel", bsb)
			var bicon = SmallIconScene.instantiate()
			bicon.icon_type = bdata.get("icon", "star")
			bicon.icon_bg = bcol * 0.3
			bicon.anchor_right = 1.0
			bicon.anchor_bottom = 1.0
			bicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_box.add_child(bicon)
			badge_box.tooltip_text = str(bdata.get("name", badge_id))
			badge_row.add_child(badge_box)
		vbox.add_child(badge_row)

	return card
