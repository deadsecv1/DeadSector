extends Control

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# A real branching Skill Tree layout with 12 nodes radiating from a
# central Hub. Scroll wheel zooms in/out (centered on the tree, not the
# mouse - simple and predictable) since the full tree is bigger than
# fits on screen at 1:1. Click and drag (left or right mouse button) on
# empty canvas space pans the view around in any direction.

const HUB_POS := Vector2(500, 280)
const CANVAS_SIZE := Vector2(1100, 650)

const NODE_POS := {
	"max_health": Vector2(280, 380),
	"health_regen": Vector2(140, 440),
	"speed": Vector2(500, 140),
	"vision_range": Vector2(500, 45),
	"damage": Vector2(720, 380),
	"fire_rate": Vector2(860, 440),
	"stash_grid": Vector2(500, 460),
	"reload_speed": Vector2(170, 160),
	"loot_sense": Vector2(830, 160),
	"search_speed": Vector2(350, 520),
	"ammo_reserve": Vector2(650, 520),
	"grenade_power": Vector2(900, 320),
	"xp_boost": Vector2(60, 280),
	"currency_boost": Vector2(1020, 200),
	"extraction_speed": Vector2(500, 580),
	"crit_chance": Vector2(760, 560),
	"backpack_rows": Vector2(240, 560),
	"stealth": Vector2(140, 320),
	"melee_damage": Vector2(960, 470),
	"market_discount": Vector2(960, 100),
	"pet_bond": Vector2(60, 500),
}

const NODE_ORDER := [
	"max_health", "health_regen", "speed", "vision_range", "damage",
	"fire_rate", "stash_grid", "reload_speed", "loot_sense", "search_speed",
	"ammo_reserve", "grenade_power", "xp_boost", "currency_boost",
	"extraction_speed", "crit_chance", "backpack_rows",
	"stealth", "melee_damage", "market_discount", "pet_bond",
]

# Which node's line feeds INTO this one ("hub" = connects straight to the
# center). Purely visual grouping into branches.
const NODE_PARENT := {
	"max_health": "hub",
	"health_regen": "max_health",
	"speed": "hub",
	"vision_range": "speed",
	"damage": "hub",
	"fire_rate": "damage",
	"stash_grid": "hub",
	"reload_speed": "hub",
	"loot_sense": "hub",
	"search_speed": "hub",
	"ammo_reserve": "hub",
	"grenade_power": "damage",
	"xp_boost": "hub",
	"currency_boost": "loot_sense",
	"extraction_speed": "stash_grid",
	"crit_chance": "ammo_reserve",
	"backpack_rows": "search_speed",
	"stealth": "xp_boost",
	"melee_damage": "grenade_power",
	"market_discount": "loot_sense",
	"pet_bond": "health_regen",
}

const NODE_SIZE := 68.0
const MIN_ZOOM := 0.4
const MAX_ZOOM := 1.6
const DEFAULT_ZOOM := 0.85

# A relevant icon per node so each upgrade reads at a glance instead of
# needing to actually parse the small label text - reuses SmallIcon's
# existing icon set (built for Quest/Roadmap rows) rather than adding
# new art.
const NODE_ICON := {
	"max_health": "medical", "health_regen": "medical", "speed": "vehicle",
	"vision_range": "compass", "damage": "combat", "fire_rate": "combat",
	"stash_grid": "gear", "reload_speed": "tech", "loot_sense": "money",
	"search_speed": "compass", "ammo_reserve": "combat", "grenade_power": "skull",
	"xp_boost": "star", "currency_boost": "money", "extraction_speed": "vehicle",
	"crit_chance": "combat", "backpack_rows": "gear", "stealth": "stealth",
	"melee_damage": "combat", "market_discount": "money", "pet_bond": "recruits",
}

@onready var artifacts_label: Label = $VBox/ArtifactsLabel
@onready var canvas_wrap: Control = $VBox/CanvasWrap
@onready var tree_canvas: Control = $VBox/CanvasWrap/TreeCanvas
@onready var back_button: Button = $VBox/BackButton
@onready var detail_panel: PanelContainer = $VBox/DetailPanel
@onready var detail_title: Label = $VBox/DetailPanel/Margin/VBox/DetailTitle
@onready var detail_desc: Label = $VBox/DetailPanel/Margin/VBox/DetailDesc
@onready var detail_button: Button = $VBox/DetailPanel/Margin/VBox/DetailButton
@onready var detail_skill_point_button: Button = $VBox/DetailPanel/Margin/VBox/DetailSkillPointButton

var selected_key: String = ""
var pan_offset: Vector2 = Vector2.ZERO
var _panning: bool = false

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _ready() -> void:
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MainMenu.tscn"))
	detail_button.pressed.connect(_on_detail_buy)
	detail_skill_point_button.pressed.connect(_on_detail_buy_with_skill_points)
	tree_canvas.draw.connect(_draw_connectors)
	tree_canvas.custom_minimum_size = CANVAS_SIZE
	tree_canvas.size = CANVAS_SIZE
	tree_canvas.pivot_offset = CANVAS_SIZE / 2.0
	tree_canvas.scale = Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM)
	canvas_wrap.resized.connect(_center_canvas)
	_center_canvas()
	_build_nodes()
	refresh()

# The canvas is much bigger than the space it renders in (that's the
# point - zoom lets you see all of it) - scale alone doesn't change how
# much layout space Godot reserves, so centering has to be done by hand
# instead of relying on a CenterContainer (which was pushing the Detail
# panel and Back button off-screen). pan_offset lets the player drag the
# view around on top of that base centering.
func _center_canvas() -> void:
	tree_canvas.position = canvas_wrap.size / 2.0 - CANVAS_SIZE / 2.0 + pan_offset

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.12)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT:
			# Left-click drag pans same as right-click - this only ever
			# reaches _unhandled_input on empty canvas space to begin
			# with, since clicking an actual node button consumes the
			# press before it gets here, so this can't fight node selection.
			_panning = event.pressed
	elif event is InputEventMouseMotion and _panning:
		pan_offset += event.relative
		_center_canvas()

func _zoom(factor: float) -> void:
	var new_scale: float = clamp(tree_canvas.scale.x * factor, MIN_ZOOM, MAX_ZOOM)
	tree_canvas.scale = Vector2(new_scale, new_scale)

func _process(_delta: float) -> void:
	tree_canvas.queue_redraw()

func refresh() -> void:
	artifacts_label.text = "Artifacts: %d   |   Skill Points: %d" % [GameManager.artifacts, GameManager.skill_points]
	for key in NODE_ORDER:
		_update_node_visual(key)
	if selected_key != "":
		_show_detail(selected_key)
	tree_canvas.queue_redraw()

func _build_nodes() -> void:
	for key in NODE_ORDER:
		var pos: Vector2 = NODE_POS[key]
		var btn := Button.new()
		btn.name = "Node_%s" % key
		btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		btn.position = pos - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		btn.text = ""
		btn.pressed.connect(_on_node_pressed.bind(key))

		var icon = SmallIconScene.instantiate()
		icon.name = "Icon"
		icon.icon_type = NODE_ICON.get(key, "star")
		icon.custom_minimum_size = Vector2(26, 26)
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.offset_left = -13
		icon.offset_right = 13
		icon.offset_top = 6
		icon.offset_bottom = 32
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		var lvl_label := Label.new()
		lvl_label.name = "LevelLabel"
		lvl_label.anchor_left = 0.0
		lvl_label.anchor_right = 1.0
		lvl_label.offset_top = 34
		lvl_label.offset_bottom = NODE_SIZE - 4
		lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lvl_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lvl_label.add_theme_font_size_override("font_size", 12)
		lvl_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lvl_label.add_theme_constant_override("outline_size", 3)
		btn.add_child(lvl_label)

		tree_canvas.add_child(btn)

func _update_node_visual(key: String) -> void:
	var btn: Button = tree_canvas.get_node("Node_%s" % key)
	var lvl_label: Label = btn.get_node("LevelLabel")
	var u: Dictionary = GameManager.upgrades[key]
	var level := int(u.get("level", 0))
	var max_level := int(u.get("max_level", 0))
	lvl_label.text = "%s\n%d/%d" % [u.get("label", key), level, max_level]

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(NODE_SIZE / 2.0))
	sb.set_border_width_all(3)
	if level >= max_level:
		sb.bg_color = Color(0.32, 0.26, 0.08, 1)
		sb.border_color = Color(1.0, 0.8, 0.3, 1)
	elif GameManager.can_afford_upgrade(key):
		sb.bg_color = Color(0.09, 0.24, 0.13, 1)
		sb.border_color = Color(0.4, 0.9, 0.5, 1)
	elif level > 0:
		sb.bg_color = Color(0.13, 0.17, 0.23, 1)
		sb.border_color = Color(0.5, 0.6, 0.75, 1)
	else:
		sb.bg_color = Color(0.1, 0.1, 0.12, 1)
		sb.border_color = Color(0.32, 0.32, 0.36, 1)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)

	var cost_text := "MAXED" if level >= max_level else "%d Artifacts or %d Skill Point to level up" % [GameManager.get_upgrade_cost(key), GameManager.SKILL_POINT_COST_PER_LEVEL]
	btn.tooltip_text = "%s\n%s\n%s" % [u.get("label", key), u.get("desc", ""), cost_text]

func _on_node_pressed(key: String) -> void:
	selected_key = key
	_show_detail(key)

func _show_detail(key: String) -> void:
	var u: Dictionary = GameManager.upgrades[key]
	var level := int(u.get("level", 0))
	var max_level := int(u.get("max_level", 0))
	detail_panel.visible = true
	detail_title.text = "%s  (Lv %d/%d)" % [u.get("label", key), level, max_level]
	detail_desc.text = u.get("desc", "")
	if level >= max_level:
		detail_button.text = "MAXED"
		detail_button.disabled = true
		detail_skill_point_button.visible = false
	else:
		detail_button.text = "Upgrade - %d Artifacts" % GameManager.get_upgrade_cost(key)
		detail_button.disabled = not GameManager.can_afford_upgrade(key)
		detail_skill_point_button.visible = true
		detail_skill_point_button.text = "Upgrade with %d Skill Point (have %d)" % [GameManager.SKILL_POINT_COST_PER_LEVEL, GameManager.skill_points]
		detail_skill_point_button.disabled = not GameManager.can_afford_upgrade_with_skill_points(key)

func _on_detail_buy() -> void:
	if selected_key == "":
		return
	GameManager.purchase_upgrade(selected_key)
	refresh()

func _on_detail_buy_with_skill_points() -> void:
	if selected_key == "":
		return
	if GameManager.purchase_upgrade_with_skill_points(selected_key):
		Sfx.play_reveal()
	refresh()

func _draw_connectors() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for key in NODE_ORDER:
		var parent_key: String = NODE_PARENT.get(key, "hub")
		var from: Vector2 = HUB_POS if parent_key == "hub" else NODE_POS.get(parent_key, HUB_POS)
		var to: Vector2 = NODE_POS[key]
		var u: Dictionary = GameManager.upgrades[key]
		var level := int(u.get("level", 0))
		var max_level := int(u.get("max_level", 0))
		if level >= max_level and max_level > 0:
			tree_canvas.draw_line(from, to, Color(1.0, 0.85, 0.35, 0.9), 4.0)
		elif level > 0:
			tree_canvas.draw_line(from, to, Color(0.45, 0.85, 0.55, 0.9), 3.0)
		else:
			tree_canvas.draw_line(from, to, Color(1, 1, 1, 0.18), 3.0)
	# A slow ambient pulse on the hub - a small living detail instead of a
	# static circle, reinforcing that this is the "core" everything else
	# branches from.
	var pulse: float = 0.5 + 0.5 * sin(t * 1.6)
	tree_canvas.draw_circle(HUB_POS, 30.0 + pulse * 4.0, Color(0.35, 0.55, 0.85, 0.10 + pulse * 0.08))
	tree_canvas.draw_circle(HUB_POS, 24.0, Color(0.16, 0.22, 0.3, 1))
	tree_canvas.draw_arc(HUB_POS, 24.0, 0.0, TAU, 32, Color(0.55, 0.75, 0.95, 0.7 + pulse * 0.3), 3.0, true)
