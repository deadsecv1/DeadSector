class_name ItemTooltip
extends RefCounted

# Builds a rich hover tooltip (icon + name + slot + stat + value) for an
# item dictionary. Used by InventoryTile and EquipSlot via
# _make_custom_tooltip() so Godot's built-in hover system displays it.
#
# Godot queries this Control's size to position/size the tooltip popup
# BEFORE it's actually in the scene tree, which means Container-based
# auto-sizing (which needs live font/theme metrics to know how tall
# word-wrapped text will be) hasn't run yet - it was falling back to a
# much bigger default, leaving a large dead area below the real content.
# Fixed by estimating each line's wrapped height ourselves as we build
# and setting a matching custom_minimum_size.y explicitly, instead of
# leaving it at 0 and hoping auto-sizing resolves in time.

const PANEL_WIDTH := 220.0
const TEXT_WIDTH := PANEL_WIDTH - 20.0 # minus left/right content margins

static func _line_height(font_size: int) -> float:
	return float(font_size) + 6.0

static func _wrapped_height(text: String, font_size: int, chars_per_line: float) -> float:
	var lines: int = max(1, ceili(float(text.length()) / chars_per_line))
	return float(lines) * _line_height(font_size)

static func build(item: Dictionary) -> Control:
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var gradient_colors: Array = GameManager.get_gradient_colors(rarity)
	var is_top_tier: bool = gradient_colors.size() > 0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.clip_contents = true
	# Running total of the actual content height, in the same order it
	# gets added below - this becomes the panel's real minimum height.
	var content_h: float = 8.0 + 8.0 # top + bottom content_margin

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.08, 0.97)
	style.border_color = rarity_color if not is_top_tier else gradient_colors[0]
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	# Drifting sparkle background - Exotic/Multiversal get noticeably more
	# particles and use the item's real gradient colors, everything else
	# gets a subtle sprinkle in the rarity color.
	var particles := Control.new()
	particles.anchor_right = 1.0
	particles.anchor_bottom = 1.0
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particles.set_script(load("res://scripts/TooltipParticles.gd"))
	particles.particle_color = rarity_color
	particles.gradient_colors = gradient_colors
	particles.intensity = 22 if is_top_tier else 6
	panel.add_child(particles)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var icon = preload("res://scenes/ItemIcon.tscn").instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = Color(0.9, 0.9, 0.9, 1)
	icon.custom_minimum_size = Vector2(56, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	content_h += 48.0 + 4.0

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", rarity_color if not is_top_tier else gradient_colors[1])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	content_h += _wrapped_height(name_lbl.text, 18, 15.0) + 4.0

	var rarity_lbl := Label.new()
	rarity_lbl.text = GameManager.get_rarity_label(rarity).to_upper()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 15 if is_top_tier else 13)
	rarity_lbl.add_theme_color_override("font_color", rarity_color if not is_top_tier else gradient_colors[2])
	vbox.add_child(rarity_lbl)
	content_h += _line_height(15 if is_top_tier else 13) + 4.0

	var slot_lbl := Label.new()
	slot_lbl.text = "[%s]" % str(item.get("slot", "")).capitalize()
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(slot_lbl)
	content_h += _line_height(13) + 4.0

	var stat_lbl := Label.new()
	stat_lbl.text = _stat_text(item)
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
	vbox.add_child(stat_lbl)
	content_h += _wrapped_height(stat_lbl.text, 16, 26.0) + 4.0

	# What this item actually does beyond the raw stat number - a real
	# one-liner for both weapons (poison/chill/pierce/burn/spread) and
	# armor (what that slot is good for), plus a callout if a weapon is
	# rare enough to fire the multi-projectile burst.
	var item_slot: String = item.get("slot", "")
	if item_slot == "weapon":
		var effect_text: String = GameManager.get_weapon_effect_text(str(item.get("icon_key", "")))
		if effect_text != "":
			var effect_lbl := Label.new()
			effect_lbl.text = effect_text
			effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			effect_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
			effect_lbl.add_theme_font_size_override("font_size", 12)
			effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
			vbox.add_child(effect_lbl)
			content_h += _wrapped_height(effect_text, 12, 33.0) + 4.0
		if rarity in ["exotic", "multiversal", "divine"]:
			var burst_lbl := Label.new()
			burst_lbl.text = "Fires a 3-5 shot burst instead of one round."
			burst_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			burst_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			burst_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
			burst_lbl.add_theme_font_size_override("font_size", 12)
			burst_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1))
			vbox.add_child(burst_lbl)
			content_h += _wrapped_height(burst_lbl.text, 12, 33.0) + 4.0
	elif item_slot in ["head", "body", "boots", "backpack", "accessory"]:
		var armor_effect_text: String = GameManager.get_armor_effect_text(item_slot, str(item.get("stat_type", "")))
		if armor_effect_text != "":
			var armor_effect_lbl := Label.new()
			armor_effect_lbl.text = armor_effect_text
			armor_effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			armor_effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			armor_effect_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
			armor_effect_lbl.add_theme_font_size_override("font_size", 12)
			armor_effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
			vbox.add_child(armor_effect_lbl)
			content_h += _wrapped_height(armor_effect_text, 12, 33.0) + 4.0

	var desc_text: String = str(item.get("desc", ""))
	if desc_text != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc_text
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.modulate = Color(1, 1, 1, 0.75)
		vbox.add_child(desc_lbl)
		content_h += _wrapped_height(desc_text, 11, 36.0) + 4.0

	var value_lbl := Label.new()
	value_lbl.text = "Value: %d" % int(item.get("value", 0))
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(value_lbl)
	content_h += _line_height(13) + 4.0

	var event_tag: String = str(item.get("event_tag", ""))
	if event_tag != "":
		var event_lbl := Label.new()
		event_lbl.text = "Obtained during the %s" % event_tag
		event_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		event_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
		event_lbl.add_theme_font_size_override("font_size", 11)
		event_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.75, 1))
		vbox.add_child(event_lbl)
		content_h += _wrapped_height(event_lbl.text, 11, 36.0) + 4.0

	if item.get("alpha_only", false) or item.get("beta_only", false):
		var excl_lbl := Label.new()
		excl_lbl.text = "ALPHA EXCLUSIVE" if item.get("alpha_only", false) else "TECH TEST EXCLUSIVE"
		excl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		excl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		excl_lbl.add_theme_font_size_override("font_size", 11)
		excl_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35, 1))
		vbox.add_child(excl_lbl)
		content_h += _line_height(11) + 4.0

		var bound_lbl := Label.new()
		bound_lbl.text = "CHARACTER BOUND"
		bound_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bound_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		bound_lbl.add_theme_font_size_override("font_size", 11)
		bound_lbl.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0, 1))
		vbox.add_child(bound_lbl)
		content_h += _line_height(11) + 4.0

	# A little breathing room, then lock in the real computed height so
	# Godot's tooltip popup sizes itself to this instead of guessing.
	panel.custom_minimum_size.y = content_h + 6.0
	return panel

static func _stat_text(item: Dictionary) -> String:
	var parts: Array = []
	var primary := _format_stat(item.get("stat_type", ""), item.get("stat_value", 0.0))
	if primary != "":
		parts.append(primary)
	var secondary := _format_stat(item.get("stat_type_2", ""), item.get("stat_value_2", 0.0))
	if secondary != "":
		parts.append(secondary)
	return ", ".join(parts)

static func _format_stat(stat_type: String, stat_value) -> String:
	match stat_type:
		"speed":
			return "+%s Speed" % stat_value
		"max_health":
			return "+%s Health" % stat_value
		"damage":
			return "+%s Damage" % stat_value
		"fire_rate":
			return "+%s Fire Rate" % stat_value
		"loot_sense":
			return "+%s%% Loot Sense" % snapped(float(stat_value) * 100.0, 0.1)
		"crit_chance":
			return "+%s%% Crit Chance" % snapped(float(stat_value) * 100.0, 0.1)
		"vision_range":
			return "+%s Vision Range" % stat_value
		"reload_speed":
			return "+%ss Reload Speed" % stat_value
		"health_regen":
			return "+%s HP/s Regen" % stat_value
		"armor":
			return "+%s%% Armor" % stat_value
		"ammo_reserve":
			return "+%s Reserve Ammo" % stat_value
		_:
			return ""
