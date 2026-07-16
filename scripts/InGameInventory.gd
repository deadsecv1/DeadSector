extends Control

# The in-run "TAB" screen: backpack grid (left, from GameManager.carried_loot)
# and character doll with equip slots (right). Mirrors Stash.gd but operates
# on carried_loot instead of stash_items, so equipping/unequipping takes
# effect immediately mid-run (Player listens for GameManager.equipped_changed).

const InventoryTileScene := preload("res://scenes/InventoryTile.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")
const RotatingGradientBorderScript := preload("res://scripts/RotatingGradientBorder.gd")
const TwinkleStarBorderScript := preload("res://scripts/TwinkleStarBorder.gd")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const DIVINE_GOLD := Color(1.0, 0.85, 0.2, 1.0)
const DIVINE_BLACK := Color(0.05, 0.05, 0.05, 1.0)
const CHROME_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const CHROME_BLACK := Color(0.05, 0.05, 0.05, 1.0)

@onready var backpack_grid = $VBox/Panels/BackpackPanel/GridScroll/BackpackGridArea
@onready var head_slot = $VBox/Panels/CharacterPanel/PortraitArea/HeadSlot
@onready var body_slot = $VBox/Panels/CharacterPanel/PortraitArea/BodySlot
@onready var weapon_slot = $VBox/Panels/CharacterPanel/PortraitArea/WeaponSlot
@onready var accessory_slot = $VBox/Panels/CharacterPanel/PortraitArea/AccessorySlot
@onready var boots_slot = $VBox/Panels/CharacterPanel/PortraitArea/BootsSlot
@onready var backpack_slot = $VBox/Panels/CharacterPanel/PortraitArea/BackpackSlot
@onready var helmet_attachment_slot = $VBox/Panels/CharacterPanel/PortraitArea/HelmetAttachmentSlot
@onready var sort_button: Button = $VBox/Panels/BackpackPanel/TitleRow/SortButton

signal item_context_menu_requested(index: int, source: String, item: Dictionary, at_position: Vector2)
signal equipped_context_menu_requested(slot_name: String, item: Dictionary, at_position: Vector2)
signal empty_slot_clicked(slot_name: String)

var slot_buttons: Dictionary = {}

func _ready() -> void:
	slot_buttons = {
		"head": head_slot,
		"body": body_slot,
		"weapon": weapon_slot,
		"accessory": accessory_slot,
		"boots": boots_slot,
		"backpack": backpack_slot,
		"helmet_attachment": helmet_attachment_slot,
	}
	backpack_grid.source = "carried"
	backpack_grid.recompute_size()
	backpack_grid.stash_controller = self
	sort_button.pressed.connect(func(): GameManager.sort_carried(); refresh())
	GameManager.vicinity_changed.connect(refresh)
	GameManager.equipped_changed.connect(refresh)
	GameManager.pockets_changed.connect(refresh)
	for key in slot_buttons.keys():
		var btn = slot_buttons[key]
		btn.source = "carried"
		btn.dropped.connect(refresh)
		btn.context_menu_requested.connect(func(slot_name, item, pos): equipped_context_menu_requested.emit(slot_name, item, pos))
		btn.pressed.connect(func():
			if btn.current_item == null:
				empty_slot_clicked.emit(key)
		)

func refresh() -> void:
	GameManager.cancel_gamepad_hold_if_within(backpack_grid)
	for child in backpack_grid.get_children():
		child.queue_free()

	for i in range(GameManager.carried_loot.size()):
		var item: Dictionary = GameManager.carried_loot[i]
		var tile = InventoryTileScene.instantiate()
		backpack_grid.add_child(tile)
		tile.setup(i, item, "carried")
		tile.context_menu_requested.connect(func(idx, src, it, pos): item_context_menu_requested.emit(idx, src, it, pos))

	for key in slot_buttons.keys():
		_update_slot_visual(slot_buttons[key], key, GameManager.equipped_items.get(key))

const EMPTY_SLOT_ICON := {
	"head": "helmet", "body": "chestplate", "weapon": "pistol", "boots": "boots",
	"backpack": "backpack", "accessory": "ring", "helmet_attachment": "visor",
}

const EMPTY_SLOT_HINT := {
	"head": "Find a helmet",
	"body": "Find body armor or a chestplate",
	"weapon": "Find a weapon",
	"boots": "Find a pair of boots",
	"backpack": "Find a backpack",
	"accessory": "Find a ring, watch, or other accessory",
	"helmet_attachment": "Find a visor, goggles, or headset",
}

func _update_slot_visual(btn, slot_key: String, item) -> void:
	for child in btn.get_children():
		child.queue_free()
	btn.clip_contents = true
	btn.current_item = item
	if item == null:
		btn.text = ""
		btn.tooltip_text = "%s slot - empty" % slot_key.capitalize()
		var empty_sb := StyleBoxFlat.new()
		empty_sb.bg_color = Color(0.08, 0.09, 0.09, 0.6)
		empty_sb.border_color = Color(1, 1, 1, 0.18)
		empty_sb.set_border_width_all(1)
		empty_sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", empty_sb)
		btn.add_theme_stylebox_override("hover", empty_sb)
		btn.add_theme_stylebox_override("pressed", empty_sb)
		btn.add_theme_stylebox_override("focus", empty_sb)

		var placeholder_icon = ItemIconScene.instantiate()
		placeholder_icon.icon_key = EMPTY_SLOT_ICON.get(slot_key, "generic")
		placeholder_icon.icon_color = Color(1, 1, 1, 0.16)
		placeholder_icon.anchor_right = 1.0
		placeholder_icon.anchor_bottom = 1.0
		placeholder_icon.offset_left = 8
		placeholder_icon.offset_top = 8
		placeholder_icon.offset_right = -8
		placeholder_icon.offset_bottom = -22
		placeholder_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(placeholder_icon)

		var label_lbl := Label.new()
		label_lbl.text = slot_key.capitalize()
		label_lbl.add_theme_font_size_override("font_size", 11)
		label_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		label_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_lbl.anchor_top = 1.0
		label_lbl.anchor_right = 1.0
		label_lbl.anchor_bottom = 1.0
		label_lbl.offset_top = -18
		label_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(label_lbl)
	else:
		btn.text = ""
		btn.tooltip_text = "%s" % item.get("name", "?")

		var rarity: String = item.get("rarity", "common")
		var rarity_color: Color = GameManager.get_rarity_color(rarity)
		var is_alpha_beta: bool = item.get("alpha_only", false) or item.get("beta_only", false)
		var icon_inset: float = 3.0

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.14, 0.13, 0.95)
		sb.border_color = Color(0, 0, 0, 0) if (rarity == "divine" or rarity == "multiversal" or is_alpha_beta) else rarity_color
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)

		if rarity == "divine":
			var flat_border := ColorRect.new()
			flat_border.color = DIVINE_GOLD
			flat_border.anchor_right = 1.0
			flat_border.anchor_bottom = 1.0
			flat_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(flat_border)
			var shimmer := Control.new()
			shimmer.anchor_right = 1.0
			shimmer.anchor_bottom = 1.0
			shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shimmer.set_script(RotatingGradientBorderScript)
			shimmer.gradient_colors = [Color(1.0, 0.85, 0.2, 0.3), Color(1.0, 0.62, 0.08, 0.2), Color(1.0, 0.95, 0.65, 0.3)]
			shimmer.rotate_speed = 0.35
			btn.add_child(shimmer)
			var gold_particles := Control.new()
			gold_particles.anchor_right = 1.0
			gold_particles.anchor_bottom = 1.0
			gold_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gold_particles.set_script(TooltipParticlesScript)
			gold_particles.particle_color = DIVINE_GOLD
			gold_particles.intensity = 24
			btn.add_child(gold_particles)
			var stars := Control.new()
			stars.anchor_right = 1.0
			stars.anchor_bottom = 1.0
			stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stars.set_script(TwinkleStarBorderScript)
			stars.star_color = DIVINE_GOLD
			stars.star_count = 4
			btn.add_child(stars)
		elif rarity == "multiversal":
			var border = GameManager.make_gradient_border("multiversal")
			if border != null:
				btn.add_child(border)
		elif is_alpha_beta:
			var rotating_bg := Control.new()
			rotating_bg.anchor_right = 1.0
			rotating_bg.anchor_bottom = 1.0
			rotating_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rotating_bg.set_script(RotatingGradientBorderScript)
			rotating_bg.gradient_colors = [Color(1, 1, 1, 0.3), Color(0.05, 0.05, 0.05, 0.3), Color(0.7, 0.7, 0.7, 0.3)]
			rotating_bg.rotate_speed = 0.5
			btn.add_child(rotating_bg)

		if rarity == "divine" or rarity == "multiversal" or is_alpha_beta:
			var slot_bg := ColorRect.new()
			slot_bg.color = Color(0.12, 0.14, 0.13, 0.95)
			slot_bg.anchor_right = 1.0
			slot_bg.anchor_bottom = 1.0
			slot_bg.offset_left = icon_inset
			slot_bg.offset_top = icon_inset
			slot_bg.offset_right = -icon_inset
			slot_bg.offset_bottom = -icon_inset
			slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(slot_bg)

		var icon = ItemIconScene.instantiate()
		icon.icon_key = item.get("icon_key", "generic")
		icon.icon_color = GameManager.get_display_color(item)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = icon_inset
		icon.offset_top = icon_inset
		icon.offset_right = -icon_inset
		icon.offset_bottom = -icon_inset
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_spin_for_item(item)
		btn.add_child(icon)

		if rarity == "divine":
			var trace := Control.new()
			trace.anchor_right = 1.0
			trace.anchor_bottom = 1.0
			trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trace.set_script(GlowTraceBorderScript)
			trace.trace_color = DIVINE_BLACK
			trace.trace_speed = 55.0
			trace.trace_segments = 8
			btn.add_child(trace)
			var black_particles := Control.new()
			black_particles.anchor_right = 1.0
			black_particles.anchor_bottom = 1.0
			black_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
			black_particles.set_script(TooltipParticlesScript)
			black_particles.particle_color = DIVINE_BLACK
			black_particles.intensity = 12
			btn.add_child(black_particles)
		elif rarity == "multiversal":
			var trace := Control.new()
			trace.anchor_right = 1.0
			trace.anchor_bottom = 1.0
			trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trace.set_script(GlowTraceBorderScript)
			trace.trace_color = GameManager.get_rarity_color("multiversal")
			trace.trace_speed = 55.0
			trace.trace_segments = 8
			btn.add_child(trace)
		elif is_alpha_beta:
			var trace := Control.new()
			trace.anchor_right = 1.0
			trace.anchor_bottom = 1.0
			trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trace.set_script(GlowTraceBorderScript)
			trace.trace_color = CHROME_WHITE
			trace.cycle_colors = [CHROME_WHITE, CHROME_BLACK]
			trace.cycle_speed = 0.35
			trace.trace_speed = 55.0
			trace.trace_segments = 8
			btn.add_child(trace)

