class_name PetTooltip
extends RefCounted

# Builds a rich hover tooltip for a pet - used by PetDollSlot and
# MyPetsPanel via _make_custom_tooltip() so Godot's built-in hover
# system displays it. Same manual-height-tracking technique as
# ItemTooltip.gd (Godot queries this Control's size to position the
# tooltip popup BEFORE it's in the scene tree, so Container auto-sizing
# hasn't run yet - tracking content_h ourselves avoids a big dead area
# below the real content).

const PANEL_WIDTH := 230.0
const TEXT_WIDTH := PANEL_WIDTH - 20.0

static func _line_height(font_size: int) -> float:
	return float(font_size) + 6.0

static func _wrapped_height(text: String, font_size: int, chars_per_line: float) -> float:
	var lines: int = max(1, ceili(float(text.length()) / chars_per_line))
	return float(lines) * _line_height(font_size)

# pet_id can be any equipped_pet value - premium/Bloodline/Loom-weaver
# pets (not instance-backed) get a simpler card; hatched/plushie/
# pacified pets get the full rundown (level, origin, rarity odds, aura).
static func build(pet_id: String) -> Control:
	var pet: Dictionary = GameManager.get_pet_data(pet_id)
	if pet.is_empty():
		return null
	var is_instance: bool = GameManager.owned_pet_instances.has(pet_id)
	var instance: Dictionary = GameManager.owned_pet_instances.get(pet_id, {})
	var rarity: String = str(instance.get("rarity", ""))
	var rarity_color: Color = GameManager.get_rarity_color(rarity) if rarity != "" else Color(0.85, 0.85, 0.85, 1)
	var pet_color: Color = pet.get("color", Color.WHITE)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.clip_contents = true
	var content_h: float = 8.0 + 8.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.97)
	style.border_color = rarity_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var icon = preload("res://scenes/ItemIcon.tscn").instantiate()
	icon.icon_key = pet.get("icon_key", "generic")
	icon.icon_color = pet_color
	icon.custom_minimum_size = Vector2(56, 44)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	content_h += 44.0 + 4.0

	var name_lbl := Label.new()
	name_lbl.text = GameManager.get_pet_display_name(pet_id) if is_instance else str(pet.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", pet_color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	content_h += _wrapped_height(name_lbl.text, 17, 15.0) + 4.0

	if not is_instance:
		# Premium/Bloodline/Loom-weaver pet - no level/rarity/origin to
		# show, just what it does.
		var stat_lbl := Label.new()
		stat_lbl.text = _pet_stat_text(pet, {})
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		stat_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
		stat_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
		vbox.add_child(stat_lbl)
		content_h += _wrapped_height(stat_lbl.text, 16, 26.0) + 4.0
		panel.custom_minimum_size.y = content_h
		return panel

	# Rarity + the actual odds of pulling it from a Plushie, so the
	# tooltip doubles as "here's how lucky this roll actually was."
	var chance: float = GameManager.PLUSHIE_PET_RARITY_WEIGHTS.get(rarity, 0.0)
	var rarity_lbl := Label.new()
	rarity_lbl.text = "%s  (%.2f%% chance)" % [GameManager.get_rarity_label(rarity).to_upper(), chance]
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 13)
	rarity_lbl.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(rarity_lbl)
	content_h += _line_height(13) + 4.0

	# Level + progress toward the next one (maxed pets just show MAX).
	var level: int = int(instance.get("level", 1))
	var level_lbl := Label.new()
	if level >= GameManager.PET_MAX_LEVEL:
		level_lbl.text = "Level %d (MAX)" % level
	else:
		var xp: int = int(instance.get("pet_xp", 0))
		var needed: int = GameManager.pet_xp_for_level(level)
		level_lbl.text = "Level %d  (%d / %d XP)" % [level, xp, needed]
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 13)
	level_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 1))
	vbox.add_child(level_lbl)
	content_h += _line_height(13) + 4.0

	# Stats: the pet's own base stat, plus its trait bonus (if it has
	# one) on a second line - matches what get_pet_bonus() actually
	# grants when this pet is equipped.
	var stat_lbl2 := Label.new()
	var trait_data := GameManager.get_trait_data(instance.get("trait", ""))
	stat_lbl2.text = _pet_stat_text(pet, trait_data)
	stat_lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl2.autowrap_mode = TextServer.AUTOWRAP_WORD
	stat_lbl2.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	stat_lbl2.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
	vbox.add_child(stat_lbl2)
	content_h += _wrapped_height(stat_lbl2.text, 16, 26.0) + 4.0

	# Aura - only Plushies (and any future trait with pet_aura) actually
	# have one, so this line only shows up when it's true.
	if trait_data.get("pet_aura", false):
		var aura_lbl := Label.new()
		aura_lbl.text = "Aura: a soft colored shimmer that follows it everywhere"
		aura_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aura_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		aura_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
		aura_lbl.add_theme_font_size_override("font_size", 12)
		aura_lbl.add_theme_color_override("font_color", pet_color)
		vbox.add_child(aura_lbl)
		content_h += _wrapped_height(aura_lbl.text, 12, 33.0) + 4.0

	# Origin: Rose's own Plushie pets always list "The Hideout" as their
	# found_map already (see give_plushie_to_rose()), so this reads
	# naturally as "met at Rose's" without needing a separate flag.
	var found_map: String = str(instance.get("found_map", "unknown"))
	var origin_lbl := Label.new()
	if found_map == "The Hideout":
		origin_lbl.text = "Met at The Hideout, from Rose"
	else:
		origin_lbl.text = "Met on %s" % found_map
	origin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	origin_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	origin_lbl.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	origin_lbl.add_theme_font_size_override("font_size", 12)
	origin_lbl.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(origin_lbl)
	content_h += _wrapped_height(origin_lbl.text, 12, 33.0) + 4.0

	panel.custom_minimum_size.y = content_h
	return panel

static func _pet_stat_text(pet: Dictionary, trait_data: Dictionary) -> String:
	var parts: Array = []
	var base_text := _format_stat(pet.get("stat_type", ""), pet.get("stat_value", 0.0))
	if base_text != "":
		parts.append(base_text)
	if not trait_data.is_empty():
		var t1 := _format_stat(trait_data.get("stat_type", ""), trait_data.get("stat_value", 0.0))
		if t1 != "":
			parts.append(t1)
		var t2 := _format_stat(trait_data.get("stat_type_2", ""), trait_data.get("stat_value_2", 0.0))
		if t2 != "":
			parts.append(t2)
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
		"ammo_reserve":
			return "+%s Reserve Ammo" % stat_value
		_:
			return ""
