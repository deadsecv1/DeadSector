extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed
signal guild_requested

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const PreviewScene := preload("res://scenes/CharacterPreview.tscn")
const TechTestTitleEffectScript := preload("res://scripts/TechTestTitleEffect.gd")
const PORTRAIT_CHOICES := ["portrait_1", "portrait_2", "portrait_3", "portrait_4", "portrait_5", "portrait_6"]

# --- Operative ID card visual language: dark steel cards with a hairline
# border, a warm accent reserved for the featured card + selection states,
# and muted labels for anything secondary. Mirrors the card technique
# already used for pet cells and achievement rows elsewhere in the game.
const CARD_BG := Color(0.11, 0.115, 0.12, 0.92)
const CARD_BORDER := Color(0.32, 0.34, 0.33, 0.55)
const CHIP_BG := Color(0.08, 0.085, 0.09, 0.9)
const ACCENT := Color(1.0, 0.8, 0.35, 1)
const MUTED := Color(1, 1, 1, 0.6)

@onready var profile_box: VBoxContainer = $Margin/VBox/Scroll/ProfileBox
@onready var close_button: Button = $Margin/VBox/CloseButton
@onready var guild_button: Button = $Margin/VBox/TitleRow/GuildButton
@onready var chat_bg_button: Button = $Margin/VBox/ChatBgButton

const CHAT_BG_ID := "tech_test_prism"

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	guild_button.pressed.connect(func(): guild_requested.emit())
	chat_bg_button.pressed.connect(_on_chat_bg_pressed)
	_refresh_chat_bg_button()
	_refresh_guild_button()
	_style_guild_button()

# Guild was sitting there with no stylebox of its own - just the bare
# default theme button, which reads as almost invisible against the
# TitleRow next to the big "SOCIAL" heading. Give it a real outline in
# its own accent color so it's obviously a clickable button.
func _style_guild_button() -> void:
	var guild_accent := Color(0.85, 0.65, 1.0, 1)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(guild_accent.r, guild_accent.g, guild_accent.b, 0.12)
	gsb.border_color = guild_accent
	gsb.set_border_width_all(2)
	gsb.set_corner_radius_all(5)
	guild_button.add_theme_stylebox_override("normal", gsb)
	var ghover_sb := gsb.duplicate()
	ghover_sb.bg_color = Color(guild_accent.r, guild_accent.g, guild_accent.b, 0.28)
	guild_button.add_theme_stylebox_override("hover", ghover_sb)
	var gpressed_sb := gsb.duplicate()
	gpressed_sb.bg_color = Color(guild_accent.r, guild_accent.g, guild_accent.b, 0.4)
	guild_button.add_theme_stylebox_override("pressed", gpressed_sb)
	guild_button.add_theme_color_override("font_color", guild_accent)

func _refresh_guild_button() -> void:
	if GameManager.player_guild_id != "":
		guild_button.text = "[%s] Guild" % GameManager.player_guild_tag
	else:
		guild_button.text = "Guild"

func _on_chat_bg_pressed() -> void:
	if not GameManager.has_chat_background_unlocked(CHAT_BG_ID):
		GameManager.toast_requested.emit("Unlocks with the Tech Test Veteran title")
		return
	if GameManager.equipped_chat_background == CHAT_BG_ID:
		GameManager.equipped_chat_background = ""
		GameManager.toast_requested.emit("Chat Background unequipped")
	else:
		GameManager.equipped_chat_background = CHAT_BG_ID
		GameManager.toast_requested.emit("Tech Test Prism equipped - shows behind your Global Chat messages")
	GameManager.save_game()
	_refresh_chat_bg_button()

func _refresh_chat_bg_button() -> void:
	var unlocked: bool = GameManager.has_chat_background_unlocked(CHAT_BG_ID)
	var equipped: bool = GameManager.equipped_chat_background == CHAT_BG_ID
	if not unlocked:
		chat_bg_button.text = "Chat Background: Locked (Tech Test Veteran)"
	elif equipped:
		chat_bg_button.text = "Chat Background: Tech Test Prism (equipped)"
	else:
		chat_bg_button.text = "Chat Background: Off (click to equip Tech Test Prism)"

func open() -> void:
	visible = true
	_refresh_guild_button()
	refresh()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func refresh() -> void:
	for c in profile_box.get_children():
		profile_box.remove_child(c)
		c.queue_free()
	profile_box.add_theme_constant_override("separation", 10)

	profile_box.add_child(_build_id_card())
	profile_box.add_child(_build_portrait_card())
	profile_box.add_child(_build_bio_card())
	profile_box.add_child(_build_squad_card())

# --- Card + style helpers ---------------------------------------------

func _make_card(border_color: Color = CARD_BORDER, border_width: int = 1) -> Dictionary:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)
	return {"card": card, "body": body}

func _eyebrow(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", ACCENT)
	return lbl

func _stat_chip(label_text: String, value_text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_BG
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	chip.add_child(v)

	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.clip_text = true
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", ACCENT)
	v.add_child(val_lbl)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = MUTED
	v.add_child(lbl)

	return chip

# --- Prestige: only ever built when GameManager.can_prestige() is true
# (Level MAX_LEVEL reached). Two-click confirm inline, rather than a
# whole separate popup, since this is far less severe/permanent-feeling
# than Delete Character - only level/XP reset, everything else is kept.

func _build_prestige_button() -> Button:
	var btn := Button.new()
	btn.text = "Prestige (reset Level, keep everything else)"
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 11)
	# GDScript lambda captures are by value AND reset to their original
	# captured snapshot on every separate invocation of the same connected
	# Callable - a plain `var confirming := false` reassigned inside this
	# lambda never sticks across repeated clicks (see CLAUDE.md's lambda-
	# capture note). Use a single-element Array as a mutable box instead,
	# same workaround already used in tests/test_gamepad_popup_close.gd.
	var confirming := [false]
	btn.pressed.connect(func():
		if not confirming[0]:
			confirming[0] = true
			btn.text = "Really Prestige? Click again to confirm"
			return
		GameManager.prestige()
		refresh()
	)
	return btn

# --- Operative ID card: portrait, build preview, name, level/XP, stats --

func _build_id_card() -> PanelContainer:
	var c := _make_card(ACCENT, 1)
	var card: PanelContainer = c["card"]
	var body: VBoxContainer = c["body"]

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	body.add_child(top_row)

	# Portrait, ringed in the accent color like a rarity frame.
	var portrait_box := PanelContainer.new()
	portrait_box.custom_minimum_size = Vector2(84, 84)
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(0.04, 0.04, 0.04, 1)
	ring_sb.border_color = ACCENT
	ring_sb.set_border_width_all(2)
	ring_sb.set_corner_radius_all(10)
	ring_sb.content_margin_left = 3
	ring_sb.content_margin_right = 3
	ring_sb.content_margin_top = 3
	ring_sb.content_margin_bottom = 3
	portrait_box.add_theme_stylebox_override("panel", ring_sb)
	var portrait = PortraitScene.instantiate()
	portrait.trader_id = GameManager.player_portrait_id
	portrait_box.add_child(portrait)
	top_row.add_child(portrait_box)

	# Build preview, in a plain steel frame - flavor, not the focal point.
	var preview_box := PanelContainer.new()
	preview_box.custom_minimum_size = Vector2(68, 84)
	var preview_sb := StyleBoxFlat.new()
	preview_sb.bg_color = Color(0.06, 0.065, 0.07, 1)
	preview_sb.border_color = CARD_BORDER
	preview_sb.set_border_width_all(1)
	preview_sb.set_corner_radius_all(8)
	preview_box.add_theme_stylebox_override("panel", preview_sb)
	var preview = PreviewScene.instantiate()
	preview.build = GameManager.player_build
	preview_box.add_child(preview)
	top_row.add_child(preview_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	top_row.add_child(info)

	info.add_child(_eyebrow("OPERATIVE"))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var name_edit := LineEdit.new()
	name_edit.text = GameManager.player_name
	name_edit.max_length = 20
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	var save_name_btn := Button.new()
	save_name_btn.text = "Save"
	save_name_btn.custom_minimum_size = Vector2(60, 0)
	save_name_btn.pressed.connect(func():
		var new_name := name_edit.text.strip_edges()
		if new_name != "":
			GameManager.player_name = new_name
			GameManager.save_game()
			GameManager.toast_requested.emit("Name updated")
	)
	name_row.add_child(save_name_btn)
	info.add_child(name_row)

	# Equipped title, if any - badges are always-on, but a title can be
	# swapped between whatever's been earned.
	if not GameManager.owned_titles.is_empty():
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		var title_data: Dictionary = GameManager.TITLE_CATALOG.get(GameManager.equipped_title, {})
		if GameManager.equipped_title == "tech_test_veteran":
			var fancy_title := Control.new()
			fancy_title.set_script(TechTestTitleEffectScript)
			title_row.add_child(fancy_title)
		else:
			var title_lbl := Label.new()
			title_lbl.text = str(title_data.get("name", "No Title Equipped"))
			title_lbl.add_theme_font_size_override("font_size", 12)
			title_lbl.add_theme_color_override("font_color", title_data.get("color", MUTED))
			title_row.add_child(title_lbl)
		if GameManager.owned_titles.size() > 1:
			var change_title_btn := Button.new()
			change_title_btn.text = "Change"
			change_title_btn.custom_minimum_size = Vector2(58, 22)
			change_title_btn.add_theme_font_size_override("font_size", 10)
			change_title_btn.pressed.connect(func():
				var idx: int = GameManager.owned_titles.find(GameManager.equipped_title)
				var next_idx: int = (idx + 1) % GameManager.owned_titles.size()
				GameManager.equip_title(GameManager.owned_titles[next_idx])
				refresh()
			)
			title_row.add_child(change_title_btn)
		info.add_child(title_row)

	var level_label := Label.new()
	level_label.text = "Level %d / %d" % [GameManager.player_level, GameManager.MAX_LEVEL]
	if GameManager.prestige_level > 0:
		level_label.text += "   ·   Prestige %d" % GameManager.prestige_level
	level_label.add_theme_font_size_override("font_size", 15)
	level_label.add_theme_color_override("font_color", ACCENT)
	info.add_child(level_label)

	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0.0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 14)
	if GameManager.player_level >= GameManager.MAX_LEVEL:
		xp_bar.max_value = 1.0
		xp_bar.value = 1.0
	else:
		var needed := GameManager.xp_needed_for_level(GameManager.player_level)
		xp_bar.max_value = float(needed)
		xp_bar.value = float(GameManager.player_xp)
	info.add_child(xp_bar)

	var xp_label := Label.new()
	if GameManager.player_level >= GameManager.MAX_LEVEL:
		xp_label.text = "MAX LEVEL"
	else:
		xp_label.text = "%d / %d XP" % [GameManager.player_xp, GameManager.xp_needed_for_level(GameManager.player_level)]
	xp_label.add_theme_font_size_override("font_size", 11)
	xp_label.modulate = MUTED
	info.add_child(xp_label)

	if GameManager.can_prestige():
		info.add_child(_build_prestige_button())

	# Quick-glance stat chips, pulled from the same lifetime stats the
	# full Character screen shows - a fast read without leaving Social.
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	var kd: float = float(GameManager.stat_enemies_killed) / float(max(1, GameManager.stat_deaths))
	stat_row.add_child(_stat_chip("KILLS", str(GameManager.stat_enemies_killed)))
	stat_row.add_child(_stat_chip("EXTRACTIONS", str(GameManager.stat_extractions)))
	stat_row.add_child(_stat_chip("K/D", "%.2f" % kd))
	stat_row.add_child(_stat_chip("RUBLES", str(GameManager.rubles)))
	body.add_child(stat_row)

	if not GameManager.owned_badges.is_empty():
		var badges_eyebrow := _eyebrow("BADGES")
		body.add_child(badges_eyebrow)
		var badges_row := HBoxContainer.new()
		badges_row.add_theme_constant_override("separation", 6)
		for badge_id in GameManager.sort_badges_by_priority(GameManager.owned_badges):
			var bdata: Dictionary = GameManager.BADGE_CATALOG.get(badge_id, {})
			var bcol: Color = bdata.get("color", ACCENT)
			var is_priority: bool = GameManager.PRIORITY_BADGE_IDS.has(badge_id)
			var badge_box := PanelContainer.new()
			badge_box.custom_minimum_size = Vector2(30, 30)
			badge_box.pivot_offset = Vector2(15, 15)
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color(bcol.r, bcol.g, bcol.b, 0.2)
			if is_priority:
				bsb.border_color = Color(1.0, 0.85, 0.35, 1)
				bsb.set_border_width_all(2)
			else:
				bsb.border_color = bcol
				bsb.set_border_width_all(1)
			bsb.set_corner_radius_all(15)
			badge_box.add_theme_stylebox_override("panel", bsb)
			var badge_icon = SmallIconScene.instantiate()
			badge_icon.icon_type = str(bdata.get("icon", "star"))
			badge_icon.icon_bg = Color(bcol.r, bcol.g, bcol.b, 0.25)
			badge_icon.anchor_right = 1.0
			badge_icon.anchor_bottom = 1.0
			badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_box.add_child(badge_icon)
			badge_box.tooltip_text = "%s\n%s" % [str(bdata.get("name", "?")), str(bdata.get("desc", ""))]
			if is_priority:
				var pulse_tw := badge_box.create_tween()
				pulse_tw.bind_node(badge_box)
				pulse_tw.set_loops()
				pulse_tw.tween_property(badge_box, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
				pulse_tw.tween_property(badge_box, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
			badges_row.add_child(badge_box)
		body.add_child(badges_row)

	return card

# --- Profile picture picker ---------------------------------------------

func _build_portrait_card() -> PanelContainer:
	var c := _make_card()
	var card: PanelContainer = c["card"]
	var body: VBoxContainer = c["body"]

	body.add_child(_eyebrow("PROFILE PICTURE"))

	var picker_row := HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", 8)
	for pid in PORTRAIT_CHOICES:
		var selected: bool = (pid == GameManager.player_portrait_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(42, 42)
		btn.clip_contents = true
		btn.toggle_mode = true
		btn.button_pressed = selected

		var normal_sb := StyleBoxFlat.new()
		normal_sb.bg_color = Color(0.04, 0.04, 0.04, 1)
		normal_sb.border_color = CARD_BORDER
		normal_sb.set_border_width_all(1)
		normal_sb.set_corner_radius_all(8)
		var selected_sb := normal_sb.duplicate()
		selected_sb.border_color = ACCENT
		selected_sb.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", normal_sb)
		btn.add_theme_stylebox_override("hover", normal_sb)
		btn.add_theme_stylebox_override("pressed", selected_sb)
		btn.add_theme_stylebox_override("hover_pressed", selected_sb)

		var mini_portrait = PortraitScene.instantiate()
		mini_portrait.anchor_left = 0.0
		mini_portrait.anchor_top = 0.0
		mini_portrait.anchor_right = 1.0
		mini_portrait.anchor_bottom = 1.0
		mini_portrait.trader_id = pid
		mini_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mini_portrait)
		btn.pressed.connect(func():
			GameManager.player_portrait_id = pid
			GameManager.save_game()
			refresh()
		)
		picker_row.add_child(btn)
	body.add_child(picker_row)

	return card

# --- Bio -----------------------------------------------------------------

func _build_bio_card() -> PanelContainer:
	var c := _make_card()
	var card: PanelContainer = c["card"]
	var body: VBoxContainer = c["body"]

	body.add_child(_eyebrow("BIO"))

	var bio_row := HBoxContainer.new()
	bio_row.add_theme_constant_override("separation", 6)
	var bio_edit := LineEdit.new()
	bio_edit.text = GameManager.player_bio
	bio_edit.max_length = 80
	bio_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bio_row.add_child(bio_edit)
	var save_bio_btn := Button.new()
	save_bio_btn.text = "Save"
	save_bio_btn.custom_minimum_size = Vector2(60, 0)
	save_bio_btn.pressed.connect(func():
		GameManager.player_bio = bio_edit.text.strip_edges()
		GameManager.save_game()
		GameManager.toast_requested.emit("Bio updated")
	)
	bio_row.add_child(save_bio_btn)
	body.add_child(bio_row)

	return card

# --- Friends & Squad ------------------------------------------------------

func _build_squad_card() -> PanelContainer:
	var c := _make_card()
	var card: PanelContainer = c["card"]
	var body: VBoxContainer = c["body"]

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	var icon = SmallIconScene.instantiate()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.icon_type = "squad"
	icon.icon_bg = Color(0.16, 0.18, 0.16, 1)
	header_row.add_child(icon)
	var friends_label := Label.new()
	friends_label.text = "Friends & Squad"
	friends_label.add_theme_font_size_override("font_size", 16)
	friends_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7, 1))
	header_row.add_child(friends_label)
	body.add_child(header_row)

	# Locked-feature banner, in place of the old paragraph of fine print -
	# a quick read instead of an essay on why it isn't here yet.
	var banner := PanelContainer.new()
	var banner_sb := StyleBoxFlat.new()
	banner_sb.bg_color = Color(0.05, 0.055, 0.05, 0.85)
	banner_sb.border_color = Color(0.6, 0.9, 0.7, 0.4)
	banner_sb.set_border_width_all(1)
	banner_sb.set_corner_radius_all(6)
	banner_sb.content_margin_left = 10
	banner_sb.content_margin_right = 10
	banner_sb.content_margin_top = 10
	banner_sb.content_margin_bottom = 10
	banner.add_theme_stylebox_override("panel", banner_sb)
	var banner_label := Label.new()
	banner_label.text = "MULTIPLAYER COMING SOON"
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 13)
	banner_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7, 1))
	banner.add_child(banner_label)
	body.add_child(banner)

	return card
