extends Control

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")

@onready var rank_list: VBoxContainer = $CenterCol/ContentRow/RankScroll/RankList
@onready var back_button: Button = $CenterCol/ButtonRow/BackButton
@onready var deploy_button: Button = $CenterCol/ButtonRow/DeployButton
@onready var sparkles_holder: Control = $Sparkles

@onready var your_rank_icon_holder: Control = $CenterCol/ContentRow/YourRankPanel/YourRankVBox/RankHeader/RankIconHolder
@onready var your_rank_name_label: Label = $CenterCol/ContentRow/YourRankPanel/YourRankVBox/RankHeader/RankNameLabel
@onready var your_rank_bar: ProgressBar = $CenterCol/ContentRow/YourRankPanel/YourRankVBox/RankBar
@onready var your_rank_progress_label: Label = $CenterCol/ContentRow/YourRankPanel/YourRankVBox/RankProgressLabel
@onready var your_rank_desc_label: Label = $CenterCol/ContentRow/YourRankPanel/YourRankVBox/RankDescLabel

func _ready() -> void:
	GameManager.set_default_cursor()
	back_button.pressed.connect(func(): Transition.change_scene("res://scenes/MainMenu.tscn"))
	deploy_button.pressed.connect(_on_deploy)

	var sparkles := Control.new()
	sparkles.anchor_right = 1.0
	sparkles.anchor_bottom = 1.0
	sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkles.set_script(TooltipParticlesScript)
	sparkles.particle_color = Color(0.6, 0.75, 1.0, 1)
	sparkles.intensity = 30
	sparkles_holder.add_child(sparkles)

	_build_ranks()
	_build_your_rank_panel()
	GameManager.focus_first_control(self)

func _build_ranks() -> void:
	for c in rank_list.get_children():
		c.queue_free()
	var current_tier_idx: int = GameManager.get_rank_tier_index(GameManager.get_rank_full_index())
	for i in range(GameManager.RANK_TIERS.size()):
		rank_list.add_child(_make_rank_row(GameManager.RANK_TIERS[i], i, i == current_tier_idx))

# The dedicated side panel: exact current rank (tier + sub-rank, e.g.
# "Scavenger 2"), a progress bar showing how far into it you are, and
# how many more Rank Points get you to the next one. Rank Points only
# move on a successful RANKED extraction - see GameManager.end_run().
func _build_your_rank_panel() -> void:
	var full_idx: int = GameManager.get_rank_full_index()
	var tier: Dictionary = GameManager.get_rank_tier(full_idx)
	var color: Color = tier.get("color", Color.WHITE)

	for c in your_rank_icon_holder.get_children():
		c.queue_free()
	var icon = SmallIconScene.instantiate()
	icon.icon_type = tier.get("icon", "star")
	icon.icon_bg = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	your_rank_icon_holder.add_child(icon)

	your_rank_name_label.text = GameManager.get_rank_display_name(full_idx)
	your_rank_name_label.add_theme_color_override("font_color", color)

	var progress := GameManager.get_rank_progress(full_idx)
	your_rank_bar.min_value = 0.0
	if GameManager.is_max_rank(full_idx):
		your_rank_bar.max_value = 1.0
		your_rank_bar.value = 1.0
		your_rank_progress_label.text = "MAX RANK"
	else:
		your_rank_bar.max_value = float(max(1, progress.y))
		your_rank_bar.value = float(progress.x)
		your_rank_progress_label.text = "%d / %d points to next rank" % [progress.x, progress.y]

	your_rank_desc_label.text = str(tier.get("desc", ""))

func _make_rank_row(rank: Dictionary, index: int, is_current: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)
	var sb := StyleBoxFlat.new()
	var rank_color: Color = rank.get("color", Color.WHITE)
	sb.bg_color = Color(rank_color.r * 0.22, rank_color.g * 0.22, rank_color.b * 0.22, 0.9) if is_current else Color(0.08, 0.08, 0.1, 0.85)
	sb.border_color = rank_color if is_current else Color(0.3, 0.3, 0.35, 0.7)
	sb.set_border_width_all(3 if is_current else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var icon = SmallIconScene.instantiate()
	icon.icon_type = rank.get("icon", "star")
	icon.icon_bg = Color(rank_color.r * 0.3, rank_color.g * 0.3, rank_color.b * 0.3, 1)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(text_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	text_col.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "%d. %s" % [index + 1, str(rank.get("label", "?"))]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", rank_color)
	name_row.add_child(name_lbl)
	if is_current:
		var current_lbl := Label.new()
		current_lbl.text = "YOUR TIER"
		current_lbl.add_theme_font_size_override("font_size", 11)
		current_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		name_row.add_child(current_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(rank.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.modulate = Color(1, 1, 1, 0.75)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_col.add_child(desc_lbl)

	return card

func _on_deploy() -> void:
	GameManager.is_ranked_match = true
	Transition.change_scene("res://scenes/PmcScavChoice.tscn")
