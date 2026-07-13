extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if detail_overlay.visible:
			_show_list()
		else:
			closed.emit()

@onready var list: VBoxContainer = $VBox/Scroll/List
@onready var close_button: Button = $VBox/CloseButton
@onready var main_vbox: VBoxContainer = $VBox
@onready var detail_overlay: Panel = $DetailOverlay
@onready var detail_subject: Label = $DetailOverlay/DetailVBox/DetailSubject
@onready var detail_date: Label = $DetailOverlay/DetailVBox/DetailDate
@onready var detail_body: Label = $DetailOverlay/DetailVBox/DetailScroll/DetailScrollContent/DetailBody
@onready var detail_reward_row: HBoxContainer = $DetailOverlay/DetailVBox/DetailScroll/DetailScrollContent/DetailRewardRow
@onready var detail_reward_icons: HBoxContainer = $DetailOverlay/DetailVBox/DetailScroll/DetailScrollContent/DetailRewardRow/DetailRewardIcons
@onready var detail_reward_label: Label = $DetailOverlay/DetailVBox/DetailScroll/DetailScrollContent/DetailRewardRow/DetailRewardLabel
@onready var detail_claim_row: HBoxContainer = $DetailOverlay/DetailVBox/DetailClaimRow
@onready var detail_claim_button: Button = $DetailOverlay/DetailVBox/DetailClaimRow/DetailClaimButton
@onready var claim_particles: CPUParticles2D = $DetailOverlay/DetailVBox/DetailClaimRow/DetailClaimButton/ClaimParticles
@onready var detail_back_button: Button = $DetailOverlay/DetailVBox/DetailBackButton

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")
const ItemTooltipHostScript := preload("res://scripts/ItemTooltipHost.gd")

var current_mail_id: int = -1

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	detail_overlay.visible = false
	close_button.pressed.connect(func(): closed.emit())
	detail_back_button.pressed.connect(_show_list)
	detail_claim_button.pressed.connect(func():
		GameManager.claim_mail(current_mail_id)
		claim_particles.restart()
		claim_particles.emitting = true
		Sfx.play_reveal()
		_show_detail(current_mail_id)
	)
	GameManager.mail_received.connect(func():
		if visible and not detail_overlay.visible:
			refresh()
	)

func open() -> void:
	visible = true
	_show_list()

func _show_list() -> void:
	detail_overlay.visible = false
	main_vbox.visible = true
	refresh()

func refresh() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	if GameManager.mail_messages.is_empty():
		var lbl := Label.new()
		lbl.text = "No mail yet."
		lbl.modulate = Color(1, 1, 1, 0.6)
		list.add_child(lbl)
		return
	for m in GameManager.mail_messages:
		list.add_child(_make_mail_row(m))

func _make_mail_row(m: Dictionary) -> Control:
	var is_read: bool = m.get("read", false)
	var has_unclaimed_reward: bool = not m.get("rewards", {}).is_empty() and not m.get("claimed", true)
	var mail_id: int = int(m.get("id", -1))

	# The click-catcher button needs to cover the WHOLE row, edge to edge -
	# but PanelContainer auto-insets every direct child by its stylebox's
	# content margins (same margins used to indent the label content), so
	# a button placed directly inside it loses the outer 14px/8px border
	# strip. Wrapping row + button as independent full-rect siblings under
	# a plain (non-Container) Control sidesteps that entirely.
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(0, 48)

	var row := PanelContainer.new()
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.1, 0.9) if is_read else Color(0.14, 0.12, 0.06, 0.95)
	sb.border_color = Color(0.9, 0.8, 0.4, 0.7) if not is_read else Color(0.35, 0.35, 0.4, 0.5)
	sb.set_border_width_all(1 if is_read else 2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)
	wrapper.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var subject_lbl := Label.new()
	subject_lbl.text = ("● " if not is_read else "") + str(m.get("subject", "?"))
	subject_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subject_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subject_lbl.clip_text = true
	subject_lbl.add_theme_font_size_override("font_size", 15)
	subject_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5, 1) if not is_read else Color(0.85, 0.85, 0.9, 1))
	hbox.add_child(subject_lbl)

	if has_unclaimed_reward:
		var reward_dot := Label.new()
		reward_dot.text = "GIFT"
		reward_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reward_dot.add_theme_font_size_override("font_size", 10)
		reward_dot.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
		hbox.add_child(reward_dot)

	var date_lbl := Label.new()
	date_lbl.text = str(m.get("date", ""))
	date_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date_lbl.add_theme_font_size_override("font_size", 11)
	date_lbl.modulate = Color(1, 1, 1, 0.5)
	hbox.add_child(date_lbl)

	var button := Button.new()
	button.flat = true
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_show_detail.bind(mail_id))
	wrapper.add_child(button)

	return wrapper

func _show_detail(mail_id: int) -> void:
	current_mail_id = mail_id
	GameManager.mark_mail_read(mail_id)
	var m: Dictionary = {}
	for entry in GameManager.mail_messages:
		if int(entry.get("id", -1)) == mail_id:
			m = entry
			break
	if m.is_empty():
		_show_list()
		return

	main_vbox.visible = false
	detail_overlay.visible = true

	detail_subject.text = str(m.get("subject", "?"))
	detail_date.text = str(m.get("date", ""))
	detail_body.text = str(m.get("body", ""))

	var rewards: Dictionary = m.get("rewards", {})
	var has_reward: bool = not rewards.is_empty()
	detail_reward_row.visible = has_reward
	detail_claim_row.visible = has_reward
	if has_reward:
		for c in detail_reward_icons.get_children():
			detail_reward_icons.remove_child(c)
			c.queue_free()

		# The Tech Test founder mail specifically gets a shiny tracing
		# border on its reward icons - matches the request for "alpha and
		# beta tester rewards" (Alpha Rewards screen covers the alpha side).
		var is_founder_mail: bool = str(m.get("subject", "")) == "From Tech Test to Alpha"

		var bits: Array = []
		if rewards.has("rubles"):
			bits.append("%d Rubles" % int(rewards["rubles"]))
			_add_reward_icon("rubles_item", Color(0.85, 0.75, 0.35, 1), is_founder_mail)
		if rewards.has("artifacts"):
			bits.append("%d Artifacts" % int(rewards["artifacts"]))
			_add_reward_icon("artifacts_item", Color(0.7, 0.6, 0.85, 1), is_founder_mail)
		if rewards.has("alloys"):
			bits.append("%d Alloys" % int(rewards["alloys"]))
			_add_reward_icon("alloys_item", Color(0.6, 0.8, 0.6, 1), is_founder_mail)
		if rewards.has("skill_points"):
			bits.append("%d Skill Point%s" % [int(rewards["skill_points"]), "" if int(rewards["skill_points"]) == 1 else "s"])
			_add_reward_icon("skill_points_item", Color(0.55, 0.78, 1.0, 1), is_founder_mail)
		if rewards.has("item"):
			var it: Dictionary = rewards["item"]
			bits.append(str(it.get("name", "an item")))
			_add_reward_icon(str(it.get("icon_key", "generic")), GameManager.get_rarity_color(str(it.get("rarity", "common"))), is_founder_mail, it)
		if rewards.has("gear"):
			var g: Dictionary = rewards["gear"]
			bits.append(str(g.get("name", "gear")))
			_add_reward_icon(str(g.get("icon_key", "generic")), GameManager.get_rarity_color(str(g.get("rarity", "common"))), is_founder_mail, g)
		if rewards.has("gear_list"):
			for g2 in rewards["gear_list"]:
				bits.append(str(g2.get("name", "gear")))
				_add_reward_icon(str(g2.get("icon_key", "generic")), GameManager.get_rarity_color(str(g2.get("rarity", "common"))), is_founder_mail, g2)
		if rewards.has("badge"):
			var badge_id: String = str(rewards["badge"])
			var bdata: Dictionary = GameManager.BADGE_CATALOG.get(badge_id, {})
			bits.append("%s badge" % str(bdata.get("name", badge_id)))
			_add_badge_reward_icon(badge_id)
		if rewards.has("title"):
			var title_id: String = str(rewards["title"])
			var tdata: Dictionary = GameManager.TITLE_CATALOG.get(title_id, {})
			bits.append("%s title" % str(tdata.get("name", title_id)))
			_add_badge_reward_icon("", title_id)
		detail_reward_label.text = "Attached: %s" % ", ".join(bits)
		var claimed: bool = m.get("claimed", true)
		detail_claim_button.visible = not claimed
		detail_claim_button.text = "Claim" if not claimed else "Claimed"
		detail_claim_button.disabled = claimed

func _add_reward_icon(icon_key: String, icon_color: Color, shiny: bool = false, item_data: Dictionary = {}) -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(28, 28)
	box.size = Vector2(28, 28)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon = ItemIconScene.instantiate()
	icon.icon_key = icon_key
	icon.icon_color = icon_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	if not item_data.is_empty():
		box.set_script(ItemTooltipHostScript)
		box.item = item_data
		box.mouse_filter = Control.MOUSE_FILTER_STOP
	if shiny:
		var trace := Control.new()
		trace.anchor_right = 1.0
		trace.anchor_bottom = 1.0
		trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trace.set_script(GlowTraceBorderScript)
		trace.trace_color = Color(icon_color.r, icon_color.g, icon_color.b, 1.0)
		trace.trace_speed = 60.0
		trace.trace_segments = 8
		box.add_child(trace)
	detail_reward_icons.add_child(box)

# Badges (and titles, reusing the same slot) shown the same small size
# as everything else in this row, using SmallIcon's icon set (compass,
# star, etc.) instead of ItemIcon's gear/currency set - and a plain
# tooltip with the name + description, same info the Social screen shows.
func _add_badge_reward_icon(badge_id: String, title_id: String = "") -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(28, 28)
	box.size = Vector2(28, 28)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon = SmallIconScene.instantiate()
	if title_id != "":
		var tdata: Dictionary = GameManager.TITLE_CATALOG.get(title_id, {})
		var tcolor: Color = tdata.get("color", Color.WHITE)
		icon.icon_type = "star"
		icon.icon_bg = Color(tcolor.r * 0.3, tcolor.g * 0.3, tcolor.b * 0.3, 1)
		box.tooltip_text = "%s\nTitle - equip it from the Social screen." % str(tdata.get("name", title_id))
	else:
		var bdata: Dictionary = GameManager.BADGE_CATALOG.get(badge_id, {})
		var bcolor: Color = bdata.get("color", Color.WHITE)
		icon.icon_type = str(bdata.get("icon", "star"))
		icon.icon_bg = Color(bcolor.r * 0.3, bcolor.g * 0.3, bcolor.b * 0.3, 1)
		box.tooltip_text = "%s\n%s" % [str(bdata.get("name", badge_id)), str(bdata.get("desc", ""))]
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	detail_reward_icons.add_child(box)
