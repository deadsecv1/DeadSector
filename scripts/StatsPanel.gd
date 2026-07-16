extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

# Mirrors Player.gd's base stat constants so this can be shown from the
# Main Menu without needing a live Player instance.
const BASE_SPEED := 220.0
const BASE_MAX_HEALTH := 100
const BASE_DAMAGE := 10
const BASE_SHOOT_COOLDOWN := 0.25
const BASE_VISION_RANGE := 460.0

@onready var header: VBoxContainer = $Margin/VBox/Header
@onready var content: VBoxContainer = $Margin/VBox/Scroll/Content
@onready var close_button: Button = $Margin/VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	_build_header()
	_build_content()

func _build_header() -> void:
	for c in header.get_children():
		c.queue_free()

	var name_label := Label.new()
	name_label.text = "%s - Level %d" % [GameManager.player_name, GameManager.player_level]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.35, 1))
	header.add_child(name_label)

	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0.0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 12)
	if GameManager.player_level >= GameManager.MAX_LEVEL:
		xp_bar.max_value = 1.0
		xp_bar.value = 1.0
	else:
		var needed := GameManager.xp_needed_for_level(GameManager.player_level)
		xp_bar.max_value = float(needed)
		xp_bar.value = float(GameManager.player_xp)
	header.add_child(xp_bar)

func _build_content() -> void:
	for c in content.get_children():
		c.queue_free()

	var speed: float = BASE_SPEED + GameManager.get_upgrade_bonus("speed") + GameManager.get_hideout_bonus("speed") + GameManager.get_equipped_bonus("speed")
	var max_health: float = BASE_MAX_HEALTH + GameManager.get_upgrade_bonus("max_health") + GameManager.get_hideout_bonus("max_health") + GameManager.get_equipped_bonus("max_health")
	var damage: float = BASE_DAMAGE + GameManager.get_upgrade_bonus("damage") + GameManager.get_hideout_bonus("damage") + GameManager.get_equipped_bonus("damage")
	var fire_rate: float = max(0.08, BASE_SHOOT_COOLDOWN - GameManager.get_upgrade_bonus("fire_rate") - GameManager.get_equipped_bonus("fire_rate"))

	_section("COMBAT")
	_row("Move Speed", "%d" % speed)
	_row("Max Health", "%d" % max_health)
	_row("Damage", "%d" % damage)
	_row("Shot Cooldown", "%.2fs" % fire_rate)

	# Everything that was missing from this screen before - some of
	# these (Armor, Ammo Reserve) are new gear stats; the rest already
	# existed on items and Skill Tree nodes but were never actually
	# shown anywhere on the Character screen.
	var vision_range: float = BASE_VISION_RANGE + GameManager.get_upgrade_bonus("vision_range") + GameManager.get_equipped_bonus("vision_range")
	var reload_speed: float = GameManager.get_upgrade_bonus("reload_speed") + GameManager.get_hideout_bonus("reload_speed") + GameManager.get_equipped_bonus("reload_speed")
	var health_regen: float = GameManager.get_upgrade_bonus("health_regen") + GameManager.get_hideout_bonus("health_regen") + GameManager.get_equipped_bonus("health_regen")
	var crit_chance: float = GameManager.get_upgrade_bonus("crit_chance") + GameManager.get_equipped_bonus("crit_chance")
	var loot_sense: float = GameManager.get_upgrade_bonus("loot_sense") + GameManager.get_equipped_bonus("loot_sense")
	var armor: float = clamp(GameManager.get_equipped_bonus("armor"), 0.0, 60.0)
	var ammo_reserve: float = GameManager.get_upgrade_bonus("ammo_reserve") + GameManager.get_equipped_bonus("ammo_reserve")

	_section("UTILITY")
	_row("Vision Range", "%d" % vision_range)
	_row("Reload Speed", "-%.2fs" % reload_speed)
	_row("Health Regen", "%.1f HP/s" % health_regen)
	_row("Crit Chance", "%.1f%%" % (crit_chance * 100.0))
	_row("Loot Sense", "%.1f%%" % (loot_sense * 100.0))
	_row("Armor", "%.0f%%" % armor)
	_row("Ammo Reserve Bonus", "+%d" % int(ammo_reserve))

	_section("LIFETIME STATS")
	_row("Total Loot Collected", "%d Rubles worth" % GameManager.stat_total_loot_collected)
	_row("Total Sold to Traders", "%d" % GameManager.stat_total_sold)
	_row("Enemies Killed", str(GameManager.stat_enemies_killed))
	_row("Deaths", str(GameManager.stat_deaths))
	var kd: float = float(GameManager.stat_enemies_killed) / float(max(1, GameManager.stat_deaths))
	_row("K/D Ratio", "%.2f" % kd)
	_row("Successful Extractions", str(GameManager.stat_extractions))

	_section("CURRENCIES")
	_row("Rubles", str(GameManager.rubles))
	_row("Junk", str(GameManager.junk))
	_row("Artifacts", str(GameManager.artifacts))
	_row("Alloys", str(GameManager.alloys))

	_section("SKILL TREE")
	var maxed := 0
	var total_levels := 0
	for key in GameManager.upgrades:
		var u: Dictionary = GameManager.upgrades[key]
		total_levels += int(u.get("level", 0))
		if int(u.get("level", 0)) >= int(u.get("max_level", 0)):
			maxed += 1
	_row("Nodes Maxed", "%d / %d" % [maxed, GameManager.upgrades.size()])
	_row("Total Levels Invested", str(total_levels))

	_section("HIDEOUT GYM")
	for key in GameManager.hideout_upgrades:
		var hu: Dictionary = GameManager.hideout_upgrades[key]
		_row(str(hu.get("label", key)), "Lv %d / %d" % [int(hu.get("level", 0)), int(hu.get("max_level", 0))])

	_section("GEAR")
	var filled := 0
	for slot in GameManager.equipped_items:
		if GameManager.equipped_items[slot] != null:
			filled += 1
	_row("Equipped Slots", "%d / %d" % [filled, GameManager.equipped_items.size()])
	_row("Stash Value", "%d Rubles" % GameManager.get_total_value())

	_section("QUESTS")
	if GameManager.all_quests_done():
		_row("Progress", "All contracts complete")
	else:
		var done := 0
		for key in GameManager.QUEST_DATA.keys():
			if GameManager.is_quest_done(key):
				done += 1
		_row("Completed", "%d / %d" % [done, GameManager.QUEST_DATA.size()])
		_row("Active Contracts", "%d / %d" % [GameManager.active_quest_count(), GameManager.MAX_ACTIVE_QUESTS])

func _section(title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.3, 1))
	content.add_child(lbl)

func _row(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
	hbox.add_child(val)
	content.add_child(hbox)
