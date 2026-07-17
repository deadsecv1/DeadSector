extends Control

# Shown right after every SUCCESSFUL extraction, regular raids and Ranked
# raids alike - replaces the old "SUCCESSFULLY EXTRACTED / Secured X
# loot" message that used to just flash on the HUD. Reads everything it
# needs from GameManager.last_raid_rewards, a snapshot end_run() builds
# right before switching to this scene.

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")

# Both bars (Level XP and Rank Points) animate over this long per segment -
# slow enough to actually watch it climb instead of just snapping.
const BAR_FILL_DURATION := 1.6
const BAR_STEP_DURATION := 0.45

@onready var subtitle_label: Label = $Panel/VBox/Subtitle
@onready var rewards_list: VBoxContainer = $Panel/VBox/Scroll/RewardsList

@onready var xp_level_label: Label = $Panel/VBox/XpSection/XpVBox/XpHeader/XpLevelLabel
@onready var level_up_label: Label = $Panel/VBox/XpSection/XpVBox/LevelUpLabel
@onready var xp_bar: ProgressBar = $Panel/VBox/XpSection/XpVBox/XpBar
@onready var xp_progress_label: Label = $Panel/VBox/XpSection/XpVBox/XpProgressLabel

@onready var rank_section: PanelContainer = $Panel/VBox/RankSection
@onready var rank_icon_holder: Control = $Panel/VBox/RankSection/RankVBox/RankHeader/RankIconHolder
@onready var rank_name_label: Label = $Panel/VBox/RankSection/RankVBox/RankHeader/RankNameLabel
@onready var rank_up_label: Label = $Panel/VBox/RankSection/RankVBox/RankUpLabel
@onready var rank_bar: ProgressBar = $Panel/VBox/RankSection/RankVBox/RankBar
@onready var rank_progress_label: Label = $Panel/VBox/RankSection/RankVBox/RankProgressLabel

@onready var continue_button: Button = $Panel/VBox/ContinueButton
@onready var view_breakdown_button: Button = $Panel/VBox/ViewBreakdownButton
@onready var breakdown_panel = $PostRaidBreakdownPanel
@onready var sparkles_holder: Control = $Sparkles

# Tracked so _on_continue() can kill them outright if the player clicks
# through before an animation finishes - otherwise a still-pending
# tween_callback can fire after this whole scene (and everything it
# captured, including self) has already been freed by the scene change.
var _xp_tween: Tween
var _rank_tween: Tween

func _ready() -> void:
	GameManager.set_default_cursor()
	continue_button.pressed.connect(_on_continue)
	view_breakdown_button.pressed.connect(func(): breakdown_panel.open())
	breakdown_panel.closed.connect(func(): breakdown_panel.visible = false)
	var data: Dictionary = GameManager.last_raid_rewards
	var is_ranked: bool = bool(data.get("is_ranked", false))
	var was_scav: bool = bool(data.get("was_scav", false))

	var subtitle_parts: Array = []
	subtitle_parts.append("RANKED EXTRACTION" if is_ranked else "Extraction successful.")
	if was_scav:
		subtitle_parts.append("Scav Run")
	subtitle_label.text = " · ".join(subtitle_parts)

	Sfx.play_reveal()

	var sparkles := Control.new()
	sparkles.anchor_right = 1.0
	sparkles.anchor_bottom = 1.0
	sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkles.set_script(TooltipParticlesScript)
	sparkles.particle_color = Color(0.95, 0.8, 0.3, 1) if is_ranked else Color(0.5, 0.85, 0.6, 1)
	sparkles.intensity = 26
	sparkles_holder.add_child(sparkles)

	_build_rewards(data)
	_build_xp_section(data)
	rank_section.visible = is_ranked
	if is_ranked:
		_build_rank_section(data)
	# Shown after EVERY successful extraction - likely the single most
	# commonly-hit gamepad dead-end in the game if left unset, since a
	# gamepad player would land here with nothing focused.
	GameManager.focus_first_control(self)

func _build_rewards(data: Dictionary) -> void:
	for c in rewards_list.get_children():
		rewards_list.remove_child(c)
		c.queue_free()

	rewards_list.add_child(_make_reward_row("money", "Rubles Secured", "+%d" % int(data.get("loot_value", 0)), Color(0.95, 0.85, 0.4, 1)))

	var quests: Array = data.get("quests", [])
	if quests.is_empty():
		rewards_list.add_child(_make_reward_row("contact", "Quests Completed", "None this raid", Color(0.75, 0.75, 0.75, 1)))
	else:
		rewards_list.add_child(_make_reward_row("contact", "Quests Completed", str(quests.size()), Color(0.6, 0.9, 0.65, 1)))
		for quest_title in quests:
			var line := Label.new()
			line.text = "  •  %s" % str(quest_title)
			line.add_theme_font_size_override("font_size", 13)
			line.modulate = Color(1, 1, 1, 0.8)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD
			rewards_list.add_child(line)

	if bool(data.get("is_ranked", false)):
		rewards_list.add_child(_make_reward_row("bone_crown", "Rank Points", "+%d" % int(data.get("rank_points_gained", 0)), Color(0.95, 0.8, 0.3, 1)))

	var loot_items: Array = data.get("loot_items", [])
	rewards_list.add_child(_make_reward_row("gear", "Loot Found", str(loot_items.size()), Color(0.7, 0.85, 0.95, 1)))
	if not loot_items.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 3)
		for item in loot_items:
			grid.add_child(_make_small_loot_row(item))
		rewards_list.add_child(grid)

# A deliberately SMALL row per item (18px icon, one line of text) since
# a full raid's haul can be a lot of items - this is a quick scan list,
# not the full Stash-style inspector every other loot screen already is.
func _make_small_loot_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(18, 18)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = GameManager.get_rarity_color(item.get("rarity", "common"))
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	row.add_child(icon_box)

	var lbl := Label.new()
	lbl.text = str(item.get("name", "Item"))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", GameManager.get_rarity_color(item.get("rarity", "common")))
	lbl.clip_text = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	return row

func _make_reward_row(icon_type: String, label_text: String, value_text: String, value_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon = SmallIconScene.instantiate()
	icon.icon_type = icon_type
	icon.icon_bg = Color(value_color.r * 0.25, value_color.g * 0.25, value_color.b * 0.25, 1)
	icon.custom_minimum_size = Vector2(36, 36)
	row.add_child(icon)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", value_color)
	row.add_child(val)

	return row

# Always shown (regular AND Ranked raids both grant regular XP). Steps
# through any level-ups one at a time - each intermediate level fills
# quickly, and the FINAL segment (the level you actually end on) gets
# the full slow BAR_FILL_DURATION so it's easy to actually watch.
func _build_xp_section(data: Dictionary) -> void:
	var level_before: int = int(data.get("level_before", 1))
	var xp_before: int = int(data.get("xp_before", 0))
	var level_after: int = int(data.get("level_after", level_before))
	var xp_after: int = int(data.get("xp_after", xp_before))

	level_up_label.visible = false
	xp_level_label.text = "Level %d" % level_before
	var need_before := GameManager.xp_needed_for_level(level_before)
	xp_bar.min_value = 0.0
	xp_bar.max_value = float(max(1, need_before))
	xp_bar.value = float(xp_before)
	xp_progress_label.text = "%d / %d XP" % [xp_before, need_before]

	var tw := create_tween()
	_xp_tween = tw
	var lvl := level_before
	while lvl < level_after and lvl < GameManager.MAX_LEVEL:
		var this_level := lvl
		var need := GameManager.xp_needed_for_level(this_level)
		tw.tween_property(xp_bar, "value", float(need), BAR_FILL_DURATION if this_level == level_before else BAR_STEP_DURATION)
		tw.tween_callback(func():
			level_up_label.visible = true
			Sfx.play_reveal()
			var new_level := this_level + 1
			xp_level_label.text = "Level %d" % new_level
			if new_level >= GameManager.MAX_LEVEL:
				xp_bar.max_value = 1.0
				xp_bar.value = 1.0
				xp_progress_label.text = "MAX LEVEL"
			else:
				var new_need := GameManager.xp_needed_for_level(new_level)
				xp_bar.max_value = float(max(1, new_need))
				xp_bar.value = 0.0
				xp_progress_label.text = "%d / %d XP" % [0, new_need]
		)
		lvl += 1

	if level_after >= GameManager.MAX_LEVEL:
		return
	var final_need := GameManager.xp_needed_for_level(level_after)
	tw.tween_property(xp_bar, "value", float(xp_after), BAR_FILL_DURATION)
	tw.tween_callback(func():
		xp_progress_label.text = "%d / %d XP" % [xp_after, final_need]
	)

# Animates the rank progress bar filling from where it was before this
# extraction to where it is now. If the extraction pushed you into a new
# rank, the bar fills the OLD rank fully first, flashes "RANK UP!", then
# swaps the label/icon over and fills the NEW rank's own progress -
# rather than just snapping straight to the end state.
func _build_rank_section(data: Dictionary) -> void:
	var before_idx: int = int(data.get("rank_index_before", 0))
	var after_idx: int = int(data.get("rank_index_after", 0))
	_show_rank(before_idx)
	rank_up_label.visible = false

	var before_progress := GameManager.get_rank_progress(before_idx)
	rank_bar.min_value = 0.0
	rank_bar.max_value = float(max(1, before_progress.y))
	rank_bar.value = float(before_progress.x)
	rank_progress_label.text = "%d / %d to next rank" % [before_progress.x, before_progress.y]

	var tw := create_tween()
	_rank_tween = tw
	if after_idx > before_idx:
		tw.tween_property(rank_bar, "value", rank_bar.max_value, BAR_FILL_DURATION)
		tw.tween_callback(func():
			rank_up_label.visible = true
			Sfx.play_reveal()
			_show_rank(after_idx)
			var after_progress := GameManager.get_rank_progress(after_idx)
			rank_bar.max_value = float(max(1, after_progress.y))
			rank_bar.value = 0.0
			if GameManager.is_max_rank(after_idx):
				rank_progress_label.text = "MAX RANK"
			else:
				rank_progress_label.text = "%d / %d to next rank" % [after_progress.x, after_progress.y]
		)
		var after_progress_final := GameManager.get_rank_progress(after_idx)
		tw.tween_property(rank_bar, "value", float(after_progress_final.x), BAR_FILL_DURATION)
	else:
		tw.tween_property(rank_bar, "value", float(before_progress.x), BAR_FILL_DURATION)

func _show_rank(full_idx: int) -> void:
	for c in rank_icon_holder.get_children():
		c.queue_free()
	var tier: Dictionary = GameManager.get_rank_tier(full_idx)
	var color: Color = tier.get("color", Color.WHITE)
	var icon = SmallIconScene.instantiate()
	icon.icon_type = tier.get("icon", "star")
	icon.icon_bg = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	rank_icon_holder.add_child(icon)
	rank_name_label.text = GameManager.get_rank_display_name(full_idx)
	rank_name_label.add_theme_color_override("font_color", color)

func _on_continue() -> void:
	if _xp_tween != null and _xp_tween.is_valid():
		_xp_tween.kill()
	if _rank_tween != null and _rank_tween.is_valid():
		_rank_tween.kill()
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
