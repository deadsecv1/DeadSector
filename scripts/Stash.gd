extends Control

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

@onready var value_label: Label = $VBox/ValueLabel
@onready var sort_button: Button = $VBox/Panels/InventoryPanel/TitleRow/SortButton
@onready var filter_button: Button = $VBox/Panels/InventoryPanel/FilterRow/FilterButton
@onready var filter_popup: Panel = $FilterPopup
@onready var filter_grid: GridContainer = $FilterPopup/VBox/Grid
@onready var filter_cancel_button: Button = $FilterPopup/VBox/CancelButton
@onready var quick_sell_button: Button = $VBox/Panels/InventoryPanel/TitleRow/QuickSellButton
@onready var quick_sell_bar: PanelContainer = $VBox/Panels/InventoryPanel/QuickSellBar
@onready var quick_sell_status: Label = $VBox/Panels/InventoryPanel/QuickSellBar/QuickSellBarBox/QuickSellStatus
@onready var quick_sell_confirm: Button = $VBox/Panels/InventoryPanel/QuickSellBar/QuickSellBarBox/QuickSellConfirm
@onready var quick_sell_cancel: Button = $VBox/Panels/InventoryPanel/QuickSellBar/QuickSellBarBox/QuickSellCancel
@onready var inventory_grid = $VBox/Panels/InventoryPanel/GridScroll/InventoryGridArea
@onready var backpack_storage_grid = $VBox/Panels/BackpackStoragePanel/BackpackStorageGridArea
@onready var backpack_storage_popup = $BackpackStoragePopup
@onready var head_slot = $VBox/Panels/CharacterPanel/PortraitArea/HeadSlot
@onready var body_slot = $VBox/Panels/CharacterPanel/PortraitArea/BodySlot
@onready var weapon_slot = $VBox/Panels/CharacterPanel/PortraitArea/WeaponSlot
@onready var accessory_slot = $VBox/Panels/CharacterPanel/PortraitArea/AccessorySlot
@onready var boots_slot = $VBox/Panels/CharacterPanel/PortraitArea/BootsSlot
@onready var backpack_slot = $VBox/Panels/CharacterPanel/PortraitArea/BackpackSlot
@onready var helmet_attachment_slot = $VBox/Panels/CharacterPanel/PortraitArea/HelmetAttachmentSlot
@onready var hp_label: Label = $VBox/Panels/CharacterPanel/HPLabel
@onready var back_button: Button = $VBox/BackButton
@onready var item_context_menu = $ItemContextMenu
@onready var tag_edit_panel = $TagEditPanel
@onready var inspect_panel = $InspectPanel
@onready var skins_panel = $SkinsPanel
@onready var open_bag_panel = $OpenLootBagPanel
@onready var pet_case_panel = $PetCasePanel
@onready var attachments_panel = $AttachmentsPanel

var slot_buttons: Dictionary = {}
var quick_sell_mode: bool = false
var quick_sell_selected: Array = []

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if event is InputEventKey and event.keycode == GameManager.get_keybind("inventory") and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		GameManager.save_game()
		Transition.change_scene_instant(GameManager.stash_return_scene)
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		# _input() runs before any sub-panel's own _unhandled_input(), so
		# unconditionally consuming Escape here meant TagEditPanel/
		# InspectPanel/etc. never got a chance to close themselves -
		# Escape always exited the whole screen instead. Let it fall
		# through to their own handler when one of them is actually open.
		if _any_sub_panel_open():
			return
		get_viewport().set_input_as_handled()
		GameManager.save_game()
		Transition.change_scene_instant(GameManager.stash_return_scene)

func _any_sub_panel_open() -> bool:
	return tag_edit_panel.visible or inspect_panel.visible or skins_panel.visible \
		or open_bag_panel.visible or attachments_panel.visible or pet_case_panel.visible \
		or filter_popup.visible or backpack_storage_popup.visible

func _ready() -> void:
	GameManager.set_default_cursor()
	slot_buttons = {
		"head": head_slot,
		"body": body_slot,
		"weapon": weapon_slot,
		"accessory": accessory_slot,
		"boots": boots_slot,
		"backpack": backpack_slot,
		"helmet_attachment": helmet_attachment_slot,
	}
	back_button.pressed.connect(func():
		GameManager.save_game()
		Transition.change_scene_instant(GameManager.stash_return_scene)
	)
	sort_button.pressed.connect(func():
		# Quick Sell tracks stash_items indices while items are selected -
		# sorting reorders that same array out from under it, so a
		# confirmed sale could hit whatever item now sits at a stale
		# index instead of what was actually selected.
		if quick_sell_mode:
			GameManager.toast_requested.emit("Finish or cancel Quick Sell first")
			return
		GameManager.sort_stash()
		refresh()
	)
	# Double-click-to-equip (InventoryTile.gd) calls GameManager.equip_item()/
	# equip_from_carried() directly with no local refresh() of its own - every
	# OTHER way to equip from this screen (drag-drop, right-click menu) already
	# triggers a refresh via its own signal, but double-click was the one path
	# that fell through the cracks: GameManager's state updated correctly, but
	# this screen's grid never redrew, so stash_index on every remaining tile
	# drifted out of sync with the now-shifted stash_items array underneath it -
	# the next click on any tile could act on the wrong item or a stale index.
	# Listening here directly (same pattern as InGameInventory.gd) means ANY
	# equip/unequip, from anywhere, always keeps this screen in sync.
	GameManager.equipped_changed.connect(refresh)
	filter_button.pressed.connect(func(): filter_popup.visible = true)
	filter_cancel_button.pressed.connect(func(): filter_popup.visible = false)
	_build_filter_popup()
	quick_sell_button.pressed.connect(_on_toggle_quick_sell)
	quick_sell_confirm.pressed.connect(_on_confirm_quick_sell)
	quick_sell_cancel.pressed.connect(_on_cancel_quick_sell)
	item_context_menu.inspect_requested.connect(func(item): inspect_panel.open_for(item))
	item_context_menu.skins_requested.connect(func(item): skins_panel.open_for(item))
	item_context_menu.open_bag_requested.connect(func(index, source, item):
		if item.get("slot", "") == "pet_case":
			pet_case_panel.open()
		elif item.get("slot", "") == "backpack":
			backpack_storage_popup.open()
		else:
			open_bag_panel.open_for(index, source, item)
	)
	item_context_menu.deposit_egg_requested.connect(func(index, _source, _item):
		if GameManager.deposit_egg_from_stash(index):
			refresh()
			GameManager.toast_requested.emit("Egg moved to the Hatchery - head to Salvaged Beasts to start it hatching.")
		else:
			GameManager.toast_requested.emit("Couldn't deposit that egg")
	)
	item_context_menu.attachments_requested.connect(func(index, source, _item): attachments_panel.open_for(index, source))
	item_context_menu.rotate_requested.connect(func(index, source, _item):
		if GameManager.rotate_item(index, source):
			refresh()
		else:
			GameManager.toast_requested.emit("Can't rotate here - not enough room")
	)
	item_context_menu.tag_requested.connect(func(index, source, item): tag_edit_panel.open_for(index, source, item))
	tag_edit_panel.closed.connect(func(): tag_edit_panel.visible = false)
	tag_edit_panel.saved.connect(refresh)
	item_context_menu.equip_requested.connect(func(index, source, _item):
		if source == "stash":
			# Equipping removes the item from stash_items, shifting every
			# later index down by one - same stale-index risk as Sort.
			if quick_sell_mode:
				GameManager.toast_requested.emit("Finish or cancel Quick Sell first")
				return
			GameManager.equip_item(index)
		elif source == "carried":
			GameManager.equip_from_carried(index)
		elif source == "vicinity":
			GameManager.vicinity_equip(index)
		elif source == "backpack_storage":
			GameManager.equip_from_backpack_storage(index)
		refresh()
	)
	item_context_menu.unequip_requested.connect(func(slot_name: String):
		GameManager.unequip_item(slot_name)
		refresh()
	)
	# Heal/food items can be "Used" from the Stash too now - but there's
	# no live HP/Hunger to restore outside a raid (no Player instance
	# here), so this explains why rather than silently consuming a
	# valuable item for zero effect.
	item_context_menu.use_requested.connect(func(_index, source, item):
		if source != "stash":
			return
		var ctype: String = str(item.get("consumable_type", ""))
		if ctype == "heal":
			GameManager.toast_requested.emit("You're already at full health outside a raid - nothing to heal right now.")
		elif ctype == "food":
			GameManager.toast_requested.emit("You're not hungry outside a raid - nothing to restore right now.")
	)
	attachments_panel.closed.connect(func(): attachments_panel.visible = false; refresh())
	inspect_panel.closed.connect(func(): inspect_panel.visible = false)
	skins_panel.closed.connect(func(): skins_panel.visible = false)
	open_bag_panel.closed.connect(func(): open_bag_panel.visible = false)
	open_bag_panel.bag_opened.connect(refresh)
	pet_case_panel.closed.connect(func(): pet_case_panel.visible = false)
	item_context_menu_requested.connect(func(idx, src, item, pos): item_context_menu.open_for(idx, src, item, pos))
	inventory_grid.stash_controller = self
	inventory_grid.source = "stash"
	backpack_storage_grid.stash_controller = self
	backpack_storage_grid.source = "backpack_storage"
	backpack_storage_grid.recompute_size()
	backpack_storage_popup.closed.connect(func(): backpack_storage_popup.visible = false; refresh())
	for key in slot_buttons.keys():
		var btn = slot_buttons[key]
		btn.source = "stash"
		btn.dropped.connect(refresh)
		btn.context_menu_requested.connect(func(slot_name, item, pos): item_context_menu.open_for_equipped(slot_name, item, pos))
		btn.pressed.connect(func():
			if btn.current_item == null:
				GameManager.toast_requested.emit(EMPTY_SLOT_HINT.get(key, "Nothing equipped here yet"))
		)
	refresh()

signal item_context_menu_requested(index: int, source: String, item: Dictionary, at_position: Vector2)

func refresh() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	for i in range(GameManager.stash_items.size()):
		var item: Dictionary = GameManager.stash_items[i]
		var tile = InventoryTileScene.instantiate()
		inventory_grid.add_child(tile)
		tile.setup(i, item, "stash")
		tile.quick_sell_mode = quick_sell_mode
		tile.quick_sell_toggled.connect(_on_quick_sell_toggled)
		tile.context_menu_requested.connect(func(idx, src, it, pos): item_context_menu_requested.emit(idx, src, it, pos))
		if quick_sell_mode and quick_sell_selected.has(i):
			var highlight := ColorRect.new()
			highlight.color = Color(0.95, 0.85, 0.3, 0.35)
			highlight.anchor_right = 1.0
			highlight.anchor_bottom = 1.0
			highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(highlight)

	for key in slot_buttons.keys():
		_update_slot_visual(slot_buttons[key], key, GameManager.equipped_items.get(key))

	# Mirrors Player.gd's own max_health formula (base_max_health = 100
	# there) so this reads exactly what you'd actually have going into a
	# raid, updating live as gear changes.
	var max_health: int = 100 + int(GameManager.get_equipped_bonus("max_health") + GameManager.get_upgrade_bonus("max_health") + GameManager.get_hideout_bonus("max_health"))
	hp_label.text = "%d HP" % max_health

	for child in backpack_storage_grid.get_children():
		child.queue_free()
	for i in range(GameManager.backpack_storage.size()):
		var bp_item: Dictionary = GameManager.backpack_storage[i]
		var bp_tile = InventoryTileScene.instantiate()
		backpack_storage_grid.add_child(bp_tile)
		bp_tile.setup(i, bp_item, "backpack_storage")
		bp_tile.context_menu_requested.connect(func(idx, src, it, pos): item_context_menu_requested.emit(idx, src, it, pos))

	value_label.text = "Total Cost of Stash: %d Rubles" % GameManager.get_total_value()

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

		# Multiversal, Divine, and Alpha/Tech-Test items each draw their
		# own border effect as a child Control below instead of this
		# flat StyleBox border - same per-rarity system the Stash/
		# Backpack grid tiles use (see InventoryTile.gd) - this doll
		# slot just never got updated to match when that shipped.
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
		icon.icon_color = rarity_color
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

func _on_quick_sell_toggled(index: int) -> void:
	if quick_sell_selected.has(index):
		quick_sell_selected.erase(index)
	else:
		quick_sell_selected.append(index)
	_update_quick_sell_status()
	refresh()

func _on_toggle_quick_sell() -> void:
	quick_sell_mode = true
	quick_sell_selected = []
	quick_sell_bar.visible = true
	quick_sell_button.disabled = true
	_update_quick_sell_status()
	refresh()

func _on_cancel_quick_sell() -> void:
	quick_sell_mode = false
	quick_sell_selected = []
	quick_sell_bar.visible = false
	quick_sell_button.disabled = false
	refresh()

func _on_confirm_quick_sell() -> void:
	if quick_sell_selected.is_empty():
		GameManager.toast_requested.emit("No items selected")
		return
	var total := GameManager.quick_sell_items(quick_sell_selected)
	GameManager.toast_requested.emit("Sold %d item(s) for %d Rubles" % [quick_sell_selected.size(), total])
	quick_sell_mode = false
	quick_sell_selected = []
	quick_sell_bar.visible = false
	quick_sell_button.disabled = false
	refresh()

func _update_quick_sell_status() -> void:
	var total_value := 0
	for idx in quick_sell_selected:
		if idx >= 0 and idx < GameManager.stash_items.size():
			total_value += int(GameManager.stash_items[idx].get("value", 0))
	quick_sell_status.text = "Click items to select them for selling. Selected: %d (%d Rubles)" % [quick_sell_selected.size(), total_value]

func _build_filter_popup() -> void:
	for c in filter_grid.get_children():
		c.queue_free()
	for cat in GameManager.FILTER_CATEGORIES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(84, 46)
		btn.add_theme_font_size_override("font_size", 10)

		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 1)
		vb.anchor_right = 1.0
		vb.anchor_bottom = 1.0
		btn.add_child(vb)

		var icon_holder := Control.new()
		icon_holder.custom_minimum_size = Vector2(0, 18)
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon = ItemIconScene.instantiate()
		icon.icon_key = str(cat.get("icon_key", "generic"))
		icon.icon_color = Color(0.85, 0.8, 0.6, 1)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.offset_left = -9
		icon.offset_right = 9
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(icon)
		vb.add_child(icon_holder)

		var lbl := Label.new()
		lbl.text = str(cat.get("label", "?"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lbl)

		var filter_id: String = str(cat.get("id", ""))
		btn.pressed.connect(func():
			# Same stale-index risk as Sort - filtering reorders stash_items.
			if quick_sell_mode:
				GameManager.toast_requested.emit("Finish or cancel Quick Sell first")
				filter_popup.visible = false
				return
			GameManager.filter_sort_stash(filter_id)
			filter_popup.visible = false
			refresh()
		)
		filter_grid.add_child(btn)
