extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

signal closed
signal battle_pass_requested

const ACCENT := Color(0.85, 0.65, 1.0, 1)
const CARD_BG := Color(0.09, 0.08, 0.11, 0.92)
const CARD_BORDER := Color(0.4, 0.32, 0.5, 0.55)
const MUTED := Color(1, 1, 1, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var body: VBoxContainer = $VBox/Scroll/Body
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug as Flea Market/Mail - force the
	# designed centered layout back explicitly.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -230.0
	offset_top = -220.0
	offset_right = 230.0
	offset_bottom = 220.0
	refresh()
	GameManager.focus_first_control(self)

func refresh() -> void:
	for c in body.get_children():
		c.queue_free()
	if GameManager.player_guild_id != "":
		body.add_child(_build_membership_view())
	else:
		body.add_child(_build_roster_picker())
		body.add_child(_build_create_form())

func _make_card() -> Dictionary:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	return {"card": card, "body": inner}

func _build_membership_view() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var c := _make_card()
	var card: PanelContainer = c["card"]
	var inner: VBoxContainer = c["body"]

	var header := Label.new()
	header.text = "[%s] %s" % [GameManager.player_guild_tag, GameManager.player_guild_name]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", ACCENT)
	inner.add_child(header)

	if not GameManager.player_guild_is_custom:
		var g := GameManager.get_guild_roster_entry(GameManager.player_guild_id)
		var desc := Label.new()
		desc.text = str(g.get("desc", ""))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.add_theme_font_size_override("font_size", 11)
		desc.modulate = MUTED
		inner.add_child(desc)

	vbox.add_child(card)

	var roster_eyebrow := Label.new()
	roster_eyebrow.text = "MEMBERS"
	roster_eyebrow.add_theme_font_size_override("font_size", 11)
	roster_eyebrow.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(roster_eyebrow)

	var names: Array = GameManager.get_guild_member_names(GameManager.player_guild_id)
	var you_label := "%s (You)" % (GameManager.player_name if GameManager.player_name != "" else "You")
	vbox.add_child(_member_row(you_label, GameManager.get_player_guild_role(), true))
	for i in range(names.size()):
		vbox.add_child(_member_row(str(names[i]), GameManager.get_guild_member_role(i), false))

	vbox.add_child(_build_clan_wars_card())
	vbox.add_child(_build_battle_pass_card())
	vbox.add_child(_build_social_place_button())

	var leave_button := Button.new()
	leave_button.text = "Leave Guild"
	leave_button.custom_minimum_size = Vector2(0, 36)
	leave_button.pressed.connect(func():
		GameManager.leave_guild()
		refresh()
	)
	vbox.add_child(leave_button)

	return vbox

func _member_row(member_name: String, role: String, is_you: bool) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.07, 0.85)
	sb.border_color = ACCENT if is_you else CARD_BORDER
	sb.set_border_width_all(2 if is_you else 1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	var lbl := Label.new()
	lbl.text = member_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	if is_you:
		lbl.add_theme_color_override("font_color", ACCENT)
	hbox.add_child(lbl)

	if role != "":
		var role_lbl := Label.new()
		role_lbl.text = role
		role_lbl.add_theme_font_size_override("font_size", 11)
		role_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1) if role != "Member" else MUTED)
		hbox.add_child(role_lbl)

	return row

# --- Clan Wars: a daily-gated, bigger guild-vs-guild battle. Reuses the
# exact same Arena battle flow (ArenaLoadoutChoice -> TheGrid ->
# ArenaVictory/Defeat) via GameManager.generate_clan_war_match(), which
# sets is_arena_match/is_clan_war and rosters both sides from guild
# member names instead of the Arena leaderboard.
func _build_clan_wars_card() -> Control:
	var c := _make_card()
	var card: PanelContainer = c["card"]
	var inner: VBoxContainer = c["body"]

	var eyebrow := Label.new()
	eyebrow.text = "CLAN WARS"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", ACCENT)
	inner.add_child(eyebrow)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	var status_lbl := Label.new()
	status_lbl.text = GameManager.clan_war_status_text()
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(status_lbl)

	var available := GameManager.clan_war_available()
	var start_button := Button.new()
	start_button.text = "Fight" if available else "Locked"
	start_button.disabled = not available
	start_button.custom_minimum_size = Vector2(70, 32)
	start_button.pressed.connect(func():
		GameManager.generate_clan_war_match()
		Transition.change_scene("res://scenes/ArenaLoadoutChoice.tscn")
	)
	row.add_child(start_button)

	return card

# --- Guild Battle Pass: a permanent tier track earned through Clan War
# Honor (win or lose - see GameManager.end_run()). Same visual shape as
# the tier progress row on the Milestones panel, condensed to fit here.
func _build_battle_pass_card() -> Control:
	var c := _make_card()
	var card: PanelContainer = c["card"]
	var inner: VBoxContainer = c["body"]

	var eyebrow := Label.new()
	eyebrow.text = "GUILD BATTLE PASS"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", ACCENT)
	inner.add_child(eyebrow)

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 8)
	inner.add_child(tier_row)

	var tier_lbl := Label.new()
	tier_lbl.text = "Tier %d / %d" % [GameManager.guild_battle_pass_tier, GameManager.GUILD_BATTLE_PASS_MAX_TIER]
	tier_lbl.custom_minimum_size = Vector2(90, 0)
	tier_lbl.add_theme_font_size_override("font_size", 12)
	tier_row.add_child(tier_lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.max_value = GameManager.GUILD_HONOR_PER_TIER
	bar.value = GameManager.guild_battle_pass_progress
	tier_row.add_child(bar)

	var open_button := Button.new()
	open_button.text = "View Rewards"
	open_button.custom_minimum_size = Vector2(0, 30)
	open_button.pressed.connect(func():
		battle_pass_requested.emit()
	)
	inner.add_child(open_button)

	return card

func _build_social_place_button() -> Button:
	var btn := Button.new()
	btn.text = "Visit Guild Hall"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(func():
		Transition.change_scene("res://scenes/GuildSocialPlace.tscn")
	)
	return btn

func _build_roster_picker() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var eyebrow := Label.new()
	eyebrow.text = "JOIN A GUILD"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(eyebrow)

	for g in GameManager.GUILD_ROSTER:
		var c := _make_card()
		var card: PanelContainer = c["card"]
		var inner: VBoxContainer = c["body"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		inner.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = "[%s] %s" % [str(g.get("tag", "")), str(g.get("name", ""))]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", ACCENT)
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(g.get("desc", ""))
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.modulate = MUTED
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.add_child(desc_lbl)

		var join_button := Button.new()
		join_button.text = "Join"
		join_button.custom_minimum_size = Vector2(60, 32)
		var guild_id: String = str(g.get("id", ""))
		join_button.pressed.connect(func():
			GameManager.join_guild(guild_id)
			refresh()
		)
		row.add_child(join_button)

		vbox.add_child(card)

	return vbox

func _build_create_form() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var eyebrow := Label.new()
	eyebrow.text = "OR FOUND YOUR OWN"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(eyebrow)

	var c := _make_card()
	var card: PanelContainer = c["card"]
	var inner: VBoxContainer = c["body"]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Guild name..."
	name_edit.max_length = 24
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_edit)

	var create_button := Button.new()
	create_button.text = "Found"
	create_button.custom_minimum_size = Vector2(70, 32)
	create_button.pressed.connect(func():
		if GameManager.create_guild(name_edit.text):
			refresh()
	)
	row.add_child(create_button)

	vbox.add_child(card)
	return vbox
