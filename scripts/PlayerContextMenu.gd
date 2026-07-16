extends Control

# Reusable "click a player" system: a small context menu (Info / Add
# Friend / Invite to Party / Whisper / Block) and the resulting Info
# profile popup (level, title, badges, equipped gear, K/D). Instantiate
# once as a full-rect child of any panel and call open_for(entry,
# click_pos) whenever the person clicks a name or portrait.
#
# Positioning and closing both mirror ItemContextMenu.gd (the Stash's
# item context menu) exactly, since that one already gets this right:
# absolute viewport-space positioning (not local-to-some-nested-Control
# math, which is what made the old version open up nowhere near the
# cursor), and closing on a click outside the menu's own rect instead of
# on mouse-exit (which was closing the menu the instant you tried to
# move toward it).

const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

const MENU_SIZE := Vector2(160, 190)

var context_menu: PanelContainer
var profile_popup: PanelContainer = null
var context_entry: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_context_menu()

func _input(event: InputEvent) -> void:
	if not context_menu.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not context_menu.get_global_rect().has_point(event.global_position):
			context_menu.visible = false

func open_for(entry: Dictionary, click_pos: Vector2) -> void:
	context_entry = entry
	var vp := get_viewport_rect().size
	context_menu.global_position = Vector2(
		clamp(click_pos.x + 12.0, 0.0, max(0.0, vp.x - MENU_SIZE.x)),
		clamp(click_pos.y + 12.0, 0.0, max(0.0, vp.y - MENU_SIZE.y))
	)
	context_menu.visible = true
	GameManager.focus_first_control(context_menu)

func _build_context_menu() -> void:
	context_menu = PanelContainer.new()
	context_menu.visible = false
	context_menu.z_index = 300
	context_menu.custom_minimum_size = MENU_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.98)
	sb.border_color = Color(0.9, 0.75, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	context_menu.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	context_menu.add_child(vbox)

	var options := [
		["Info", "_on_context_info"],
		["Add Friend", "_on_context_unavailable"],
		["Invite to Party", "_on_context_unavailable"],
		["Whisper", "_on_context_unavailable"],
		["Block", "_on_context_unavailable"],
	]
	for opt in options:
		var btn := Button.new()
		btn.text = opt[0]
		btn.flat = true
		btn.custom_minimum_size = Vector2(0, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(Callable(self, opt[1]))
		vbox.add_child(btn)

	add_child(context_menu)

func _on_context_unavailable() -> void:
	context_menu.visible = false
	GameManager.toast_requested.emit("Multiplayer's coming soon - friends, parties, whispers, and blocking will work once it's live.")

func _on_context_info() -> void:
	context_menu.visible = false
	_open_profile_popup(context_entry)

# --- Info popup: a full simulated profile - level, title, badges,
# equipped gear (with rarity color), and a KD read-out.
func _open_profile_popup(entry: Dictionary) -> void:
	if profile_popup != null and is_instance_valid(profile_popup):
		profile_popup.queue_free()
	profile_popup = PanelContainer.new()
	profile_popup.z_index = 310
	profile_popup.custom_minimum_size = Vector2(320, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.98)
	sb.border_color = Color(0.9, 0.75, 0.3, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	profile_popup.add_theme_stylebox_override("panel", sb)
	profile_popup.anchor_left = 0.5
	profile_popup.anchor_top = 0.5
	profile_popup.anchor_right = 0.5
	profile_popup.anchor_bottom = 0.5
	profile_popup.offset_left = -160
	profile_popup.offset_right = 160

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	profile_popup.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)
	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(64, 64)
	var portrait = PortraitScene.instantiate()
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.trader_id = str(entry.get("portrait", "portrait_1"))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	header.add_child(portrait_box)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_col)
	var name_lbl := Label.new()
	name_lbl.text = str(entry.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1))
	name_col.add_child(name_lbl)
	var title_text: String = str(entry.get("title", ""))
	if title_text != "":
		var title_lbl := Label.new()
		title_lbl.text = title_text
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.modulate = Color(0.75, 0.85, 1.0, 1)
		name_col.add_child(title_lbl)
	var level_lbl := Label.new()
	level_lbl.text = "Level %d" % int(entry.get("level", 1))
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.modulate = Color(1, 1, 1, 0.7)
	name_col.add_child(level_lbl)
	var device_lbl := Label.new()
	device_lbl.text = "On: Controller" if _is_on_gamepad(str(entry.get("name", "?"))) else "On: Keyboard & Mouse"
	device_lbl.add_theme_font_size_override("font_size", 11)
	device_lbl.modulate = Color(0.75, 0.8, 0.9, 0.85)
	name_col.add_child(device_lbl)

	var kills: int = int(entry.get("kills", 0))
	var deaths: int = max(1, int(entry.get("deaths", 1)))
	var kd_lbl := Label.new()
	kd_lbl.text = "K/D: %d / %d  (%.2f)" % [kills, deaths, float(kills) / float(deaths)]
	kd_lbl.add_theme_font_size_override("font_size", 13)
	kd_lbl.modulate = Color(0.7, 0.9, 0.7, 1)
	vbox.add_child(kd_lbl)

	var pets_lbl := Label.new()
	pets_lbl.text = "Pets Owned: %d" % int(entry.get("pets", 0))
	pets_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(pets_lbl)

	var badges: Array = entry.get("badges", [])
	if not badges.is_empty():
		var badge_lbl := Label.new()
		badge_lbl.text = "Badges"
		badge_lbl.add_theme_font_size_override("font_size", 13)
		badge_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1))
		vbox.add_child(badge_lbl)
		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 6)
		vbox.add_child(badge_row)
		for badge_id in GameManager.sort_badges_by_priority(badges):
			var bdata: Dictionary = GameManager.BADGE_CATALOG.get(badge_id, {})
			var bcol: Color = bdata.get("color", Color.WHITE)
			var is_priority: bool = GameManager.PRIORITY_BADGE_IDS.has(badge_id)
			var badge_box := PanelContainer.new()
			badge_box.custom_minimum_size = Vector2(28, 28)
			badge_box.pivot_offset = Vector2(14, 14)
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color(bcol.r, bcol.g, bcol.b, 0.2)
			if is_priority:
				bsb.border_color = Color(1.0, 0.85, 0.35, 1)
				bsb.set_border_width_all(2)
			else:
				bsb.border_color = bcol
				bsb.set_border_width_all(1)
			bsb.set_corner_radius_all(14)
			badge_box.add_theme_stylebox_override("panel", bsb)
			var bicon = SmallIconScene.instantiate()
			bicon.icon_type = bdata.get("icon", "star")
			bicon.icon_bg = bcol * 0.3
			bicon.anchor_right = 1.0
			bicon.anchor_bottom = 1.0
			bicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_box.add_child(bicon)
			badge_box.tooltip_text = str(bdata.get("name", badge_id))
			if is_priority:
				var pulse_tw := badge_box.create_tween()
				pulse_tw.bind_node(badge_box)
				pulse_tw.set_loops()
				pulse_tw.tween_property(badge_box, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
				pulse_tw.tween_property(badge_box, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
			badge_row.add_child(badge_box)

	var gear: Dictionary = entry.get("gear", {})
	if not gear.is_empty():
		var gear_lbl := Label.new()
		gear_lbl.text = "Equipped Gear"
		gear_lbl.add_theme_font_size_override("font_size", 13)
		gear_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1))
		vbox.add_child(gear_lbl)
		var gear_grid := GridContainer.new()
		gear_grid.columns = 6
		gear_grid.add_theme_constant_override("h_separation", 4)
		gear_grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(gear_grid)
		for slot in gear:
			var item = gear[slot]
			if item == null:
				continue
			var rarity: String = str(item.get("rarity", "common"))
			var slot_box := PanelContainer.new()
			slot_box.custom_minimum_size = Vector2(38, 38)
			var slot_sb := StyleBoxFlat.new()
			slot_sb.bg_color = Color(0.12, 0.12, 0.12, 0.9)
			slot_sb.border_color = GameManager.get_rarity_color(rarity)
			slot_sb.set_border_width_all(2)
			slot_sb.set_corner_radius_all(4)
			slot_box.add_theme_stylebox_override("panel", slot_sb)
			slot_box.tooltip_text = "%s (%s)" % [str(slot).capitalize(), GameManager.get_rarity_label(rarity)]
			var gicon = ItemIconScene.instantiate()
			gicon.icon_key = str(item.get("icon_key", "generic"))
			gicon.icon_color = GameManager.get_rarity_color(rarity)
			gicon.anchor_right = 1.0
			gicon.anchor_bottom = 1.0
			gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_box.add_child(gicon)
			gear_grid.add_child(slot_box)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.pressed.connect(func():
		profile_popup.visible = false
		profile_popup.queue_free()
	)
	vbox.add_child(close_btn)

	add_child(profile_popup)
	GameManager.focus_first_control(profile_popup)

# Multiplayer's simulated client-side (see CLAUDE.md's design philosophy
# note) - there's no real second player actually reporting an input
# device, so this is just a stable per-name coin flip rather than a
# fresh random roll every time the same profile is opened again.
func _is_on_gamepad(player_name: String) -> bool:
	return hash(player_name) % 2 == 0
