extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")

# White/black "chrome" palette for this screen's alpha-flair accents (icon
# backgrounds, sparkles, trace, title glow) - kept local to this file and
# separate from the shared MULTIVERSAL_GRADIENT (which Stash/Traders/
# tooltips/everywhere else still uses untouched), so this reskin only
# affects Alpha Rewards.
const CHROME_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const CHROME_BLACK := Color(0.05, 0.05, 0.05, 1.0)
const CHROME_GRADIENT := [
	Color(1.0, 1.0, 1.0, 0.95), Color(0.05, 0.05, 0.05, 0.95), Color(0.95, 0.95, 0.95, 0.9),
	Color(0.03, 0.03, 0.03, 0.95), Color(1.0, 1.0, 1.0, 0.95),
]

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var title_row: Control = $VBox/TitleRow
@onready var countdown_label: Label = $VBox/CountdownLabel
@onready var reward_grid: GridContainer = $VBox/RewardGrid
@onready var status_label: Label = $VBox/StatusLabel
@onready var claim_button: Button = $VBox/ClaimButton
@onready var claim_particles: CPUParticles2D = $VBox/ClaimButton/ClaimParticles
@onready var close_button: Button = $VBox/CloseButton
@onready var sparkles_holder: Control = $Sparkles

var title_pulse: float = 0.0

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	claim_button.pressed.connect(func():
		if GameManager.claim_alpha_rewards():
			Sfx.play_reveal()
			claim_particles.color = CHROME_WHITE
			claim_particles.restart()
			claim_particles.emitting = true
			refresh()
	)

	# White/black ambient sparkle field behind everything, alternating
	# per-particle - the same particle system item tooltips use for
	# Exotic/Multiversal gear, dialed up and recolored for this screen's
	# own black-and-white identity instead of the shared gold.
	var sparkles := Control.new()
	sparkles.anchor_right = 1.0
	sparkles.anchor_bottom = 1.0
	sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkles.set_script(TooltipParticlesScript)
	sparkles.gradient_colors = [CHROME_WHITE, CHROME_BLACK]
	sparkles.intensity = 40
	sparkles_holder.add_child(sparkles)

	_build_title()

func open() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_update_countdown()
	title_pulse += delta * 1.6
	title_row.queue_redraw()

func _update_countdown() -> void:
	if not GameManager.alpha_rewards_available():
		countdown_label.text = "This offer has ended."
		return
	var secs := int(GameManager.alpha_rewards_seconds_left())
	var days := int(secs / 86400.0)
	var hours := int(secs / 3600.0) % 24
	var mins := int(secs / 60.0) % 60
	if days > 0:
		countdown_label.text = "Offer ends in %d days, %d hours" % [days, hours]
	else:
		countdown_label.text = "Offer ends in %d hours, %d minutes - don't miss it!" % [hours, mins]
	countdown_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35, 1) if days == 0 else Color(1, 0.7, 0.5, 1))

func _build_title() -> void:
	for c in title_row.get_children():
		c.queue_free()
	if not title_row.draw.is_connected(_draw_title):
		title_row.draw.connect(_draw_title)

func _draw_title() -> void:
	var font := ThemeDB.fallback_font
	var text := "ALPHA REWARDS"
	var font_size := 34
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2((title_row.size.x - text_size.x) / 2.0, title_row.size.y * 0.62)
	var glow: float = 0.5 + 0.5 * sin(title_pulse)
	# Layered glow passes behind the text for a soft bloom - each pass
	# drawn slightly further out in a different direction so they
	# actually accumulate into a soft halo instead of stacking as one
	# identical, wasted draw call on top of itself.
	var glow_dirs := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]
	for i in range(3):
		var off: float = 1.5 + float(i) * 1.2 + glow * 2.0
		title_row.draw_string(font, pos + glow_dirs[i] * off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.10 + glow * 0.05))
	title_row.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 1))
	var underline_w: float = text_size.x * (0.3 + glow * 0.7)
	title_row.draw_line(Vector2(title_row.size.x / 2.0 - underline_w / 2.0, pos.y + 8), Vector2(title_row.size.x / 2.0 + underline_w / 2.0, pos.y + 8), Color(1.0, 1.0, 1.0, 0.8), 2.0)

func refresh() -> void:
	_update_countdown()
	for c in reward_grid.get_children():
		reward_grid.remove_child(c)
		c.queue_free()

	if GameManager.alpha_rewards_claimed:
		status_label.text = "Claimed! Here's everything you got:"
		claim_button.visible = false
		_add_reward_card("star", "Alpha Pioneer", "Badge - Claimed", Color(1.0, 0.7, 0.3, 1), true)
		_add_item_reward_card("rubles_item", "200,000", "Rubles - Claimed", Color(0.85, 0.75, 0.35, 1))
		_add_item_reward_card("artifacts_item", "200", "Artifacts - Claimed", Color(0.7, 0.6, 0.85, 1))
		_add_item_reward_card("alloys_item", "200", "Alloys - Claimed", Color(0.6, 0.8, 0.6, 1))
		_add_item_reward_card("skill_points_item", "15", "Skill Points - Claimed", Color(0.55, 0.78, 1.0, 1))
		_add_item_reward_card("chestplate", "Alpha Pioneer's Rig", "Legendary - Claimed", GameManager.get_rarity_color("legendary"), "legendary")
		_add_item_reward_card("alpha_cannon", "The Prototype", "Multiversal - Claimed", GameManager.get_rarity_color("multiversal"), "multiversal")
		_add_item_reward_card("lootbag", "Exclusive Alpha Chest", "Claimed", GameManager.get_rarity_color("multiversal"), "multiversal")
	elif not GameManager.alpha_rewards_available():
		status_label.text = "This limited-time offer has ended."
		claim_button.visible = false
	else:
		status_label.text = "Everything below is yours the moment you claim."
		claim_button.visible = true
		_add_reward_card("star", "Alpha Pioneer", "Badge", Color(1.0, 0.7, 0.3, 1), false)
		_add_item_reward_card("rubles_item", "200,000", "Rubles", Color(0.85, 0.75, 0.35, 1))
		_add_item_reward_card("artifacts_item", "200", "Artifacts", Color(0.7, 0.6, 0.85, 1))
		_add_item_reward_card("alloys_item", "200", "Alloys", Color(0.6, 0.8, 0.6, 1))
		_add_item_reward_card("skill_points_item", "15", "Skill Points", Color(0.55, 0.78, 1.0, 1))
		_add_item_reward_card("chestplate", "Alpha Pioneer's Rig", "Legendary Gear", GameManager.get_rarity_color("legendary"), "legendary")
		_add_item_reward_card("alpha_cannon", "The Prototype", "Multiversal Weapon", GameManager.get_rarity_color("multiversal"), "multiversal")
		_add_item_reward_card("lootbag", "Exclusive Alpha Chest", "20 items, heavy rare+", GameManager.get_rarity_color("multiversal"), "multiversal")

func _add_reward_card(icon_type: String, label_text: String, sub_text: String, color: Color, claimed: bool) -> void:
	var card := _make_card_shell(color)
	var icon = SmallIconScene.instantiate()
	icon.icon_type = icon_type
	icon.icon_bg = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.get_node("VBox").add_child(icon)
	card.get_node("VBox").move_child(icon, 0)
	_finish_card(card, label_text, sub_text, color, claimed)

func _add_item_reward_card(icon_key: String, label_text: String, sub_text: String, color: Color, rarity_for_border = false) -> void:
	var gradient_rarity: String = ""
	if typeof(rarity_for_border) == TYPE_STRING:
		gradient_rarity = rarity_for_border
	var card := _make_card_shell(color)

	if gradient_rarity != "":
		# _make_card_shell() already added its own rarity-colored trace as
		# the card's first child (see below) - remove it before adding the
		# white/black replacement, otherwise the old gold trace would just
		# keep running underneath/alongside the new one.
		var old_trace: Node = card.get_child(0)
		card.remove_child(old_trace)
		old_trace.queue_free()

		# Card border: was a flat rarity-colored line drawn by the panel's
		# own StyleBoxFlat - swapped for a clean white border (same width
		# Skill Points' card uses, just white instead of blue) so these 3
		# specific items read clearly as bordered cards at a glance, on
		# top of the white/black gradient ring and dual trace underneath.
		var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
		if sb != null:
			sb.border_color = Color(1, 1, 1, 0.9)
			sb.set_border_width_all(2)
		var card_ring := Control.new()
		card_ring.anchor_right = 1.0
		card_ring.anchor_bottom = 1.0
		card_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_ring.clip_contents = true
		card.add_child(card_ring)
		card.move_child(card_ring, 0)
		var card_border := _make_chrome_gradient_border()
		card_ring.add_child(card_border)
		var card_bg := ColorRect.new()
		card_bg.color = Color(0.08, 0.08, 0.08, 0.97)
		card_bg.anchor_right = 1.0
		card_bg.anchor_bottom = 1.0
		card_bg.offset_left = 3
		card_bg.offset_top = 3
		card_bg.offset_right = -3
		card_bg.offset_bottom = -3
		card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_ring.add_child(card_bg)
		_add_dual_trace(card, 60.0, 14, 1.5)

		# A concentrated white/black particle field local to just this
		# card, on top of the screen-wide ambient sparkle field, so these
		# two specific items get extra visible flair.
		var local_sparkles := Control.new()
		local_sparkles.anchor_right = 1.0
		local_sparkles.anchor_bottom = 1.0
		local_sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		local_sparkles.set_script(TooltipParticlesScript)
		local_sparkles.gradient_colors = [CHROME_WHITE, CHROME_BLACK]
		local_sparkles.intensity = 16
		card.add_child(local_sparkles)
		card.move_child(local_sparkles, 1)

	var icon_box := Control.new()
	var box_size: float = 50.0 if gradient_rarity != "" else 44.0
	icon_box.custom_minimum_size = Vector2(box_size, box_size)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The gradient now fills the WHOLE icon box - not a ring around the
	# edge, the gradient itself is the background the icon sits on - in
	# this screen's own white/black chrome instead of the item's actual
	# rarity color/gradient (which stay untouched everywhere else - the
	# Stash, Traders, tooltips, and so on). The dual white/black trace on
	# top gives it real, visible motion rather than a static tint alone.
	if gradient_rarity != "":
		icon_box.clip_contents = true
		var border := _make_chrome_gradient_border()
		icon_box.add_child(border)
		_add_dual_trace(icon_box, 50.0, 10, 1.5)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = icon_key
	icon.icon_color = color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	if gradient_rarity != "":
		icon.offset_left = 7
		icon.offset_top = 7
		icon.offset_right = -7
		icon.offset_bottom = -7
		icon.spin = true
	icon_box.add_child(icon)
	card.get_node("VBox").add_child(icon_box)
	card.get_node("VBox").move_child(icon_box, 0)
	_finish_card(card, label_text, sub_text, color, false)

# Two looping trace lines instead of one - white going one way around the
# perimeter, black going the other (a negative trace_speed just reverses
# direction in GlowTraceBorder's own perimeter-walk math) - so both colors
# are visibly in motion at once rather than a single-color trail.
func _add_dual_trace(target: Control, speed: float, segments: int, width: float) -> void:
	var trace_white := Control.new()
	trace_white.anchor_right = 1.0
	trace_white.anchor_bottom = 1.0
	trace_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace_white.set_script(GlowTraceBorderScript)
	trace_white.trace_color = CHROME_WHITE
	trace_white.trace_speed = speed
	trace_white.trace_segments = segments
	trace_white.trace_width = width
	target.add_child(trace_white)
	var trace_black := Control.new()
	trace_black.anchor_right = 1.0
	trace_black.anchor_bottom = 1.0
	trace_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace_black.set_script(GlowTraceBorderScript)
	trace_black.trace_color = CHROME_BLACK
	trace_black.trace_speed = -speed
	trace_black.trace_segments = segments
	trace_black.trace_width = width
	target.add_child(trace_black)


# Builds a full-fill white/black gradient TextureRect for this screen's
# own icon backgrounds - same correct anchoring technique as
# GameManager.make_gradient_border() (expand_mode + a full-rect preset
# set AFTER the texture is assigned, since this gets parented after
# creation - skipping either one renders at the raw 128x128 texture size
# instead of filling whatever box it ends up in), just with a local
# white/black palette instead of a shared rarity color.
func _make_chrome_gradient_border() -> TextureRect:
	var grad := Gradient.new()
	for i in range(CHROME_GRADIENT.size()):
		grad.add_point(float(i) / float(CHROME_GRADIENT.size() - 1), CHROME_GRADIENT[i])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(1, 1)
	grad_tex.width = 128
	grad_tex.height = 128
	var rect := TextureRect.new()
	rect.texture = grad_tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.clip_contents = true
	return rect

func _make_card_shell(color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(132, 108)
	card.size = Vector2(132, 108)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.08, 0.92)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = Color(color.r, color.g, color.b, 1.0)
	trace.trace_speed = 60.0
	card.add_child(trace)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)
	reward_grid.add_child(card)
	return card

func _finish_card(card: PanelContainer, label_text: String, sub_text: String, color: Color, claimed: bool) -> void:
	var vbox: VBoxContainer = card.get_node("VBox")
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", color)
	vbox.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = ("Claimed - " + sub_text) if claimed else sub_text
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = Color(0.6, 1, 0.65, 1) if claimed else Color(1, 1, 1, 0.65)
	vbox.add_child(sub_lbl)
