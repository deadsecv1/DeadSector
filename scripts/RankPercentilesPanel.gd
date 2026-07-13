extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var rank_list: VBoxContainer = $VBox/RankScroll/RankList
@onready var close_button: Button = $VBox/CloseButton
@onready var sparkles_holder: Control = $Sparkles

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

	var sparkles := Control.new()
	sparkles.anchor_right = 1.0
	sparkles.anchor_bottom = 1.0
	sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkles.set_script(TooltipParticlesScript)
	sparkles.particle_color = Color(0.6, 0.75, 1.0, 1)
	sparkles.intensity = 30
	sparkles_holder.add_child(sparkles)

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug as Flea Market/Mail - force the
	# designed centered layout back explicitly.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -340.0
	offset_top = -300.0
	offset_right = 340.0
	offset_bottom = 300.0
	_build_ranks()

func _build_ranks() -> void:
	for c in rank_list.get_children():
		c.queue_free()
	var current_idx: int = GameManager.get_rank_full_index()
	# Highest rank first reads better as a showcase list than starting
	# at the bottom.
	for i in range(GameManager.RANK_POINT_THRESHOLDS.size() - 1, -1, -1):
		rank_list.add_child(_make_rank_card(i, i == current_idx))

func _make_rank_card(full_idx: int, is_current: bool) -> Control:
	var tier: Dictionary = GameManager.get_rank_tier(full_idx)
	var color: Color = tier.get("color", Color.WHITE)
	var percent: float = GameManager.get_rank_population_percent(full_idx)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.9) if is_current else Color(0.08, 0.08, 0.1, 0.85)
	sb.border_color = color if is_current else Color(0.3, 0.3, 0.35, 0.7)
	sb.set_border_width_all(3 if is_current else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(40, 40)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon = SmallIconScene.instantiate()
	icon.icon_type = tier.get("icon", "star")
	icon.icon_bg = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(text_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	text_col.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = GameManager.get_rank_display_name(full_idx)
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", color)
	name_row.add_child(name_lbl)
	if is_current:
		var current_lbl := Label.new()
		current_lbl.text = "YOUR RANK"
		current_lbl.add_theme_font_size_override("font_size", 11)
		current_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		name_row.add_child(current_lbl)

	var percent_lbl := Label.new()
	percent_lbl.text = _percent_text(percent)
	percent_lbl.add_theme_font_size_override("font_size", 12)
	percent_lbl.modulate = Color(1, 1, 1, 0.8)
	text_col.add_child(percent_lbl)

	return card

# Reads naturally at both ends of the scale - "22.4% of operatives..."
# for the common ranks, "only 0.001% of operatives..." for the rare
# ones, instead of one flat phrasing that reads oddly for either end.
func _percent_text(percent: float) -> String:
	var num_text: String = ("%.3f" % percent) if percent < 0.1 else ("%.2f" % percent if percent < 1.0 else "%.1f" % percent)
	if percent < 0.05:
		return "Only %s%% of operatives ever reach this rank." % num_text
	elif percent < 1.0:
		return "A rare %s%% of operatives reach this rank." % num_text
	else:
		return "%s%% of operatives sit at this rank." % num_text
